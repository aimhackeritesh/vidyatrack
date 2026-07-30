import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { TenantDb } from '../common/database/tenant-db.service';
import { SchoolConfigService } from '../config/school-config.service';
import { v4 as uuidv4 } from 'uuid';
import { SubmitAttendanceDto, GetAttendanceQuery } from './dto/attendance.dto';

@Injectable()
export class AttendanceService {
  constructor(
    private readonly db: TenantDb,
    private readonly config: SchoolConfigService,
  ) {}

  /** One student's daily statuses + monthly stats. Used by parent/student calendars. */
  async getStudentMonth(schoolId: string, user: any, studentId: string, month?: string) {
    await this.assertStudentAccess(schoolId, user, studentId);
    // month = 'YYYY-MM'; default current month.
    const monthStart = month ? `${month}-01` : null;
    const records = await this.db.query(
      `SELECT to_char(ses.date,'YYYY-MM-DD') as date, ar.status, ar.remark
       FROM attendance_records ar
       JOIN attendance_sessions ses ON ses.id=ar.session_id
       WHERE ar.student_id=$1 AND ses.school_id=$2
         AND ($3::date IS NULL OR (ses.date >= $3::date AND ses.date < ($3::date + INTERVAL '1 month')))
       ORDER BY ses.date`,
      [studentId, schoolId, monthStart],
    );
    const holidays = await this.db.query(
      `SELECT to_char(date,'YYYY-MM-DD') as date, name FROM holidays
       WHERE school_id=$1
         AND ($2::date IS NULL OR (date >= $2::date AND date < ($2::date + INTERVAL '1 month')))
       ORDER BY date`,
      [schoolId, monthStart],
    );
    const count = (s: string) => records.filter((r: any) => r.status === s).length;
    const present = count('present');
    const late = count('late');
    const total = records.length;
    const pct = total > 0 ? Math.round(((present + late) / total) * 1000) / 10 : 0;
    return {
      studentId,
      month: month ?? null,
      records,
      holidays,
      summary: { present, absent: count('absent'), late, leave: count('leave'), total, pct },
    };
  }

  /** Resolve the caller's own student (student role) or first child (parent role). */
  async getMyMonth(schoolId: string, user: any, month?: string) {
    let studentId: string | undefined;
    if (user.role === 'student') {
      const [r] = await this.db.query(`SELECT linked_entity_id FROM user_roles WHERE id=$1`, [user.userRoleId]);
      studentId = r?.linked_entity_id;
    } else if (user.role === 'parent') {
      const [r] = await this.db.query(
        `SELECT id FROM students WHERE school_id=$1 AND guardian_user_id=$2 AND status='active' ORDER BY created_at LIMIT 1`,
        [schoolId, user.id],
      );
      studentId = r?.id;
    }
    if (!studentId) throw new NotFoundException('No linked student found');
    return this.getStudentMonth(schoolId, user, studentId, month);
  }

  // ── Holiday calendar ─────────────────────────────────────────────────────────
  async setHoliday(schoolId: string, date: string, name: string) {
    const id = uuidv4();
    await this.db.query(
      `INSERT INTO holidays(id,school_id,date,name) VALUES($1,$2,$3,$4)
       ON CONFLICT(school_id,date) DO UPDATE SET name=EXCLUDED.name`,
      [id, schoolId, date, name],
    );
    return { date, name };
  }

  listHolidays(schoolId: string, from?: string, to?: string) {
    const params: any[] = [schoolId];
    let where = 'school_id=$1';
    if (from) { params.push(from); where += ` AND date >= $${params.length}`; }
    if (to) { params.push(to); where += ` AND date <= $${params.length}`; }
    return this.db.query(`SELECT id,to_char(date,'YYYY-MM-DD') as date,name FROM holidays WHERE ${where} ORDER BY date`, params);
  }

  async deleteHoliday(schoolId: string, id: string) {
    await this.db.query(`DELETE FROM holidays WHERE id=$1 AND school_id=$2`, [id, schoolId]);
    return { id };
  }

  // ── Defaulters report (< threshold %) ────────────────────────────────────────
  /**
   * `threshold` omitted means "use this school's configured threshold"
   * (`attendance.defaulter_threshold`), not a hardcoded 75.
   */
  async getDefaulters(schoolId: string, threshold?: number, month?: string) {
    const effectiveThreshold = threshold ?? (await this.config.getInt(schoolId, 'attendance.defaulter_threshold'));
    const monthStart = month ? `${month}-01` : null;
    return this.db.query(
      `SELECT s.id, s.name, s.roll_no, sec.name AS section, c.name AS class,
              COUNT(*) FILTER (WHERE ar.status IN ('present','late')) AS present,
              COUNT(*) AS total,
              ROUND(COUNT(*) FILTER (WHERE ar.status IN ('present','late'))::NUMERIC / NULLIF(COUNT(*),0) * 100, 1) AS pct
       FROM students s
       JOIN sections sec ON sec.id=s.section_id
       JOIN classes c ON c.id=sec.class_id
       JOIN attendance_records ar ON ar.student_id=s.id
       JOIN attendance_sessions ses ON ses.id=ar.session_id
       WHERE s.school_id=$1 AND s.status='active'
         AND ($3::date IS NULL OR (ses.date >= $3::date AND ses.date < ($3::date + INTERVAL '1 month')))
       GROUP BY s.id, s.name, s.roll_no, sec.name, c.name
       HAVING ROUND(COUNT(*) FILTER (WHERE ar.status IN ('present','late'))::NUMERIC / NULLIF(COUNT(*),0) * 100, 1) < $2
       ORDER BY pct ASC, c.name, sec.name, s.roll_no`,
      [schoolId, effectiveThreshold, monthStart],
    );
  }

  private async assertStudentAccess(schoolId: string, user: any, studentId: string) {
    if (user.role === 'admin' || user.role === 'teacher') return;
    if (user.role === 'parent') {
      const [r] = await this.db.query(`SELECT 1 FROM students WHERE id=$1 AND school_id=$2 AND guardian_user_id=$3`, [studentId, schoolId, user.id]);
      if (!r) throw new ForbiddenException('Not your child');
      return;
    }
    if (user.role === 'student') {
      const [r] = await this.db.query(`SELECT 1 FROM user_roles WHERE id=$1 AND linked_entity_id=$2`, [user.userRoleId, studentId]);
      if (!r) throw new ForbiddenException('You can only view your own attendance');
      return;
    }
    throw new ForbiddenException('Not allowed');
  }

  async submitAttendance(userId: string, schoolId: string, role: string, dto: SubmitAttendanceDto) {
    const session = dto.session ?? 'full_day';

    // Idempotent: upsert session row
    const sessionId = uuidv4();
    const [existing] = await this.db.query(
      `SELECT id, locked_at, marked_by FROM attendance_sessions
       WHERE school_id=$1 AND section_id=$2 AND date=$3 AND session=$4`,
      [schoolId, dto.sectionId, dto.date, session],
    );

    if (existing) {
      // Only original marker (same day) or admin can update
      const isToday = existing.marked_at && new Date(existing.marked_at).toDateString() === new Date(dto.date).toDateString();
      const isLocked = !!existing.locked_at;
      if (isLocked && role !== 'admin') throw new ForbiddenException('Attendance is locked. Only admin can edit.');
      if (!isToday && role !== 'admin') throw new ForbiddenException('Can only edit today\'s attendance. Contact admin for past edits.');
    } else {
      await this.db.query(
        `INSERT INTO attendance_sessions(id,school_id,section_id,date,session,marked_by,marked_at)
         VALUES($1,$2,$3,$4,$5,$6,NOW())`,
        [sessionId, schoolId, dto.sectionId, dto.date, session, userId],
      );
    }

    const sid = existing?.id ?? sessionId;

    // Bulk upsert records
    if (dto.records.length === 0) throw new BadRequestException('No records provided');

    const values = dto.records
      .map((_, i) => `($${i * 4 + 1},$${i * 4 + 2},$${i * 4 + 3},$${i * 4 + 4})`)
      .join(',');
    const params: any[] = [];
    for (const r of dto.records) {
      params.push(uuidv4(), sid, r.studentId, r.status);
    }

    await this.db.query(
      `INSERT INTO attendance_records(id,session_id,student_id,status)
       VALUES ${values}
       ON CONFLICT(session_id,student_id) DO UPDATE SET status=EXCLUDED.status, updated_at=NOW()`,
      params,
    );

    // Update summary
    await this.refreshSummary(schoolId, dto.sectionId, dto.date);

    // Queue absence notifications (handled by background job)
    const absentStudents = dto.records.filter((r) => r.status === 'absent').map((r) => r.studentId);
    if (absentStudents.length) {
      // Enqueue via BullMQ (simplified: log for now)
      console.log(`[NOTIFY] Absence alerts for students: ${absentStudents.join(',')}`);
    }

    return { message: 'Attendance submitted', sessionId: sid, count: dto.records.length };
  }

  async getSectionAttendance(schoolId: string, sectionId: string, date: string) {
    const [session] = await this.db.query(
      `SELECT * FROM attendance_sessions WHERE school_id=$1 AND section_id=$2 AND date=$3 AND session='full_day'`,
      [schoolId, sectionId, date],
    );

    const students = await this.db.query(
      `SELECT s.id, s.name, s.roll_no, s.admission_no, s.photo_url,
              ar.status, ar.remark
       FROM students s
       LEFT JOIN attendance_records ar ON ar.student_id=s.id AND ar.session_id=$1
       WHERE s.section_id=$2 AND s.status='active'
       ORDER BY s.roll_no`,
      [session?.id ?? null, sectionId],
    );

    return { session, students };
  }

  async getAdminReport(schoolId: string, query: GetAttendanceQuery) {
    const from = query.fromDate ?? query.date ?? new Date().toISOString().split('T')[0];
    const to = query.toDate ?? query.date ?? from;

    const rows = await this.db.query(
      `SELECT das.date, das.section_id, sec.name as section_name, c.name as class_name,
              das.total_students, das.present, das.absent, das.late, das.on_leave,
              ROUND(das.present::NUMERIC/NULLIF(das.total_students,0)*100,1) as pct
       FROM daily_attendance_summary das
       JOIN sections sec ON sec.id=das.section_id
       JOIN classes c ON c.id=sec.class_id
       WHERE das.school_id=$1 AND das.date BETWEEN $2 AND $3
       ${query.sectionId ? 'AND das.section_id=$4' : ''}
       ORDER BY das.date DESC, c.order_no, sec.name`,
      query.sectionId ? [schoolId, from, to, query.sectionId] : [schoolId, from, to],
    );

    return rows;
  }

  async getDashboardChart(schoolId: string): Promise<{ studentAttendance: any[]; teacherAttendance: any[] }> {
    const studentAttendance = await this.db.query(
      `SELECT date, SUM(present) as present, SUM(total_students) as total,
              ROUND(SUM(present)::NUMERIC/NULLIF(SUM(total_students),0)*100,1) as pct
       FROM daily_attendance_summary
       WHERE school_id=$1 AND date >= CURRENT_DATE - INTERVAL '6 days'
       GROUP BY date ORDER BY date`,
      [schoolId],
    );

    const teacherAttendance = await this.db.query(
      `SELECT date, COUNT(*) FILTER(WHERE status='present') as present, COUNT(*) as total,
              ROUND(COUNT(*) FILTER(WHERE status='present')::NUMERIC/NULLIF(COUNT(*),0)*100,1) as pct
       FROM teacher_attendance
       WHERE school_id=$1 AND date >= CURRENT_DATE - INTERVAL '6 days'
       GROUP BY date ORDER BY date`,
      [schoolId],
    );

    return { studentAttendance, teacherAttendance };
  }

  private async refreshSummary(schoolId: string, sectionId: string, date: string) {
    const [counts] = await this.db.query(
      `SELECT
         COUNT(*) FILTER(WHERE ar.status='present') as present,
         COUNT(*) FILTER(WHERE ar.status='absent') as absent,
         COUNT(*) FILTER(WHERE ar.status='late') as late,
         COUNT(*) FILTER(WHERE ar.status='leave') as on_leave,
         COUNT(s.id) as total
       FROM students s
       LEFT JOIN attendance_records ar ON ar.student_id=s.id
         AND ar.session_id=(SELECT id FROM attendance_sessions
                            WHERE school_id=$1 AND section_id=$2 AND date=$3 AND session='full_day')
       WHERE s.section_id=$2 AND s.status='active'`,
      [schoolId, sectionId, date],
    );

    await this.db.query(
      `INSERT INTO daily_attendance_summary(id,school_id,section_id,date,total_students,present,absent,late,on_leave,updated_at)
       VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,NOW())
       ON CONFLICT(school_id,section_id,date) DO UPDATE SET
         total_students=$5,present=$6,absent=$7,late=$8,on_leave=$9,updated_at=NOW()`,
      [uuidv4(), schoolId, sectionId, date,
       counts.total, counts.present, counts.absent, counts.late, counts.on_leave],
    );
  }

  async exportDefaultersCsv(schoolId: string, threshold?: number, month?: string): Promise<string> {
    const list = await this.getDefaulters(schoolId, threshold, month);
    let csv = 'Class,Section,Roll No,Admission No,Student Name,Attendance %,Absent Days,Total Days\n';
    for (const row of list) {
      csv += `"${row.class}","${row.section}",${row.roll_no ?? ''},"${row.admission_no}","${row.name}",${row.pct},${row.absent_count},${row.total}\n`;
    }
    return csv;
  }

  async getRegisterReport(schoolId: string, filters: { classId?: string; sectionId: string; month: string }) {
    const { sectionId, month } = filters;
    const monthStart = `${month}-01`;

    const year = Number(month.split('-')[0]);
    const monthNum = Number(month.split('-')[1]);
    const totalDays = new Date(year, monthNum, 0).getDate();

    const studentsList = await this.db.query(
      `SELECT id, name, roll_no, admission_no FROM students
       WHERE section_id = $1 AND school_id = $2 AND status = 'active'
       ORDER BY roll_no, name`,
      [sectionId, schoolId]
    );

    const attendanceRecords = await this.db.query(
      `SELECT ar.student_id, to_char(ses.date, 'DD')::integer AS day, ar.status
       FROM attendance_records ar
       JOIN attendance_sessions ses ON ses.id = ar.session_id
       WHERE ses.section_id = $1 AND ses.school_id = $2
         AND ses.date >= $3::date AND ses.date < ($3::date + INTERVAL '1 month')`,
      [sectionId, schoolId, monthStart]
    );

    const holidaysList = await this.db.query(
      `SELECT to_char(date, 'DD')::integer AS day FROM holidays
       WHERE school_id = $1
         AND date >= $2::date AND date < ($2::date + INTERVAL '1 month')`,
      [schoolId, monthStart]
    );

    const holidayDays = new Set(holidaysList.map((h: any) => h.day));

    const recordMap = new Map<string, string>();
    for (const r of attendanceRecords) {
      recordMap.set(`${r.student_id}-${r.day}`, r.status);
    }

    const students = studentsList.map((s: any) => {
      const dailyAttendance: Record<number, string> = {};
      let presentCount = 0;
      let absentCount = 0;
      let lateCount = 0;
      let leaveCount = 0;

      for (let day = 1; day <= totalDays; day++) {
        const dateObj = new Date(year, monthNum - 1, day);
        const dayOfWeek = dateObj.getDay(); // 0 = Sun
        
        let status = '-';
        if (dayOfWeek === 0) {
          status = 'W'; // Weekend
        } else if (holidayDays.has(day)) {
          status = 'H'; // Holiday
        } else {
          const recStatus = recordMap.get(`${s.id}-${day}`);
          if (recStatus) {
            if (recStatus === 'present') {
              status = 'P';
              presentCount++;
            } else if (recStatus === 'absent') {
              status = 'A';
              absentCount++;
            } else if (recStatus === 'late') {
              status = 'L';
              lateCount++;
            } else if (recStatus === 'leave') {
              status = 'V';
              leaveCount++;
            }
          }
        }
        dailyAttendance[day] = status;
      }

      const total = presentCount + absentCount + lateCount + leaveCount;
      const pct = total > 0 ? Math.round(((presentCount + lateCount) / total) * 1000) / 10 : 0;

      return {
        id: s.id,
        name: s.name,
        rollNo: s.roll_no,
        admissionNo: s.admission_no,
        attendance: dailyAttendance,
        summary: { present: presentCount, absent: absentCount, late: lateCount, leave: leaveCount, total, pct }
      };
    });

    const days = Array.from({ length: totalDays }, (_, i) => i + 1);

    return { days, students };
  }

  async exportRegisterCsv(schoolId: string, filters: { classId?: string; sectionId: string; month: string }): Promise<string> {
    const data = await this.getRegisterReport(schoolId, filters);
    let csv = 'Roll No,Admission No,Student Name,' + data.days.join(',') + ',Present,Absent,Late,Leave,%\n';
    for (const s of data.students) {
      const dailyVals = data.days.map(d => s.attendance[d] ?? '-').join(',');
      csv += `${s.rollNo ?? ''},"${s.admissionNo}","${s.name}",${dailyVals},${s.summary.present},${s.summary.absent},${s.summary.late},${s.summary.leave},${s.summary.pct}\n`;
    }
    return csv;
  }

  async renderRegisterHtml(schoolId: string, filters: { classId?: string; sectionId: string; month: string }): Promise<string> {
    const data = await this.getRegisterReport(schoolId, filters);
    
    const [sec] = await this.db.query(
      `SELECT sec.name as section_name, c.name as class_name
       FROM sections sec JOIN classes c ON c.id=sec.class_id
       WHERE sec.id=$1 AND sec.school_id=$2`,
      [filters.sectionId, schoolId]
    );
    
    const className = sec?.class_name ?? '';
    const sectionName = sec?.section_name ?? '';
    
    let html = `<!DOCTYPE html>
<html>
<head>
  <title>Attendance Register — ${className}-${sectionName} — ${filters.month}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; margin: 20px; color: #333; }
    h1 { font-size: 20px; margin-bottom: 5px; }
    h2 { font-size: 14px; font-weight: normal; color: #666; margin-top: 0; margin-bottom: 20px; }
    table { width: 100%; border-collapse: collapse; font-size: 10px; page-break-inside: avoid; }
    th, td { border: 1px solid #ddd; padding: 4px; text-align: center; }
    th { background-color: #f2f2f2; font-weight: bold; }
    .student-name { text-align: left; font-weight: 500; font-size: 11px; white-space: nowrap; }
    .weekend { background-color: #f9f9f9; color: #aaa; }
    .holiday { background-color: #ffe6e6; color: #d9534f; font-weight: bold; }
    .present { color: #5cb85c; font-weight: bold; }
    .absent { color: #d9534f; font-weight: bold; }
    .late { color: #f0ad4e; font-weight: bold; }
    .leave { color: #5bc0de; font-weight: bold; }
    @media print {
      @page { size: A4 landscape; margin: 10mm; }
      body { margin: 0; }
    }
  </style>
</head>
<body>
  <h1>Attendance Register</h1>
  <h2>Class: <strong>${className} - ${sectionName}</strong> &nbsp;|&nbsp; Month: <strong>${filters.month}</strong></h2>
  <table>
    <thead>
      <tr>
        <th>Roll</th>
        <th>Name</th>
        ${data.days.map(d => `<th>${d}</th>`).join('')}
        <th>P</th>
        <th>A</th>
        <th>L</th>
        <th>V</th>
        <th>%</th>
      </tr>
    </thead>
    <tbody>`;

    for (const s of data.students) {
      html += `<tr>
        <td>${s.rollNo ?? ''}</td>
        <td class="student-name">${s.name}</td>`;
      for (const d of data.days) {
        const val = s.attendance[d] ?? '-';
        let cls = '';
        if (val === 'W') cls = 'class="weekend"';
        else if (val === 'H') cls = 'class="holiday"';
        else if (val === 'P') cls = 'class="present"';
        else if (val === 'A') cls = 'class="absent"';
        else if (val === 'L') cls = 'class="late"';
        else if (val === 'V') cls = 'class="leave"';
        
        html += `<td ${cls}>${val}</td>`;
      }
      html += `<td>${s.summary.present}</td>
        <td>${s.summary.absent}</td>
        <td>${s.summary.late}</td>
        <td>${s.summary.leave}</td>
        <td style="font-weight: bold;">${s.summary.pct}%</td>
      </tr>`;
    }

    html += `</tbody>
  </table>
  <div style="margin-top: 15px; font-size: 9px; color: #777;">
    <strong>Legend:</strong> P = Present | A = Absent | L = Late | V = Leave | H = Holiday | W = Weekend
  </div>
</body>
</html>`;
    return html;
  }

  // ── Teacher Attendance Correction Approval Flow ─────────────────────────────
  async createCorrectionRequest(schoolId: string, userId: string, date: string, requestedStatus: string, reason: string) {
    const [t] = await this.db.query(
      `SELECT id FROM teachers WHERE school_id=$1 AND user_id=$2 AND status='active'`,
      [schoolId, userId]
    );
    if (!t) throw new ForbiddenException('Only active teachers can request corrections');

    const id = uuidv4();
    await this.db.query(
      `INSERT INTO attendance_change_requests(id, school_id, teacher_id, date, requested_status, reason, status)
       VALUES($1, $2, $3, $4, $5, $6, 'pending')`,
      [id, schoolId, t.id, date, requestedStatus, reason]
    );

    await this.audit(schoolId, userId, 'teacher.correction_request.create', id, { date, requestedStatus });
    return { id, message: 'Correction request submitted' };
  }

  async listCorrectionRequests(schoolId: string, status?: string) {
    const params: any[] = [schoolId];
    let where = `r.school_id=$1`;
    if (status) {
      params.push(status);
      where += ` AND r.status=$${params.length}`;
    }
    return this.db.query(
      `SELECT r.*, t.employee_code, u.name as teacher_name, u.phone as teacher_phone
       FROM attendance_change_requests r
       JOIN teachers t ON t.id = r.teacher_id
       JOIN users u ON u.id = t.user_id
       WHERE ${where}
       ORDER BY r.created_at DESC`,
      params
    );
  }

  async listMyCorrectionRequests(schoolId: string, userId: string) {
    const [t] = await this.db.query(
      `SELECT id FROM teachers WHERE school_id=$1 AND user_id=$2`,
      [schoolId, userId]
    );
    if (!t) return [];

    return this.db.query(
      `SELECT r.*, u.name as teacher_name
       FROM attendance_change_requests r
       JOIN teachers t ON t.id = r.teacher_id
       JOIN users u ON u.id = t.user_id
       WHERE r.school_id = $1 AND r.teacher_id = $2
       ORDER BY r.created_at DESC`,
      [schoolId, t.id]
    );
  }

  async actOnCorrectionRequest(schoolId: string, actorId: string, requestId: string, status: string, note?: string) {
    const [req] = await this.db.query(
      `SELECT * FROM attendance_change_requests WHERE id = $1 AND school_id = $2`,
      [requestId, schoolId]
    );
    if (!req) throw new NotFoundException('Correction request not found');
    if (req.status !== 'pending') throw new BadRequestException('Request is already resolved');

    if (status !== 'approved' && status !== 'rejected') {
      throw new BadRequestException('Invalid status. Must be approved or rejected');
    }

    await this.db.query(
      `UPDATE attendance_change_requests
       SET status = $1, acted_by = $2, acted_at = NOW()
       WHERE id = $3 AND school_id = $4`,
      [status, actorId, requestId, schoolId]
    );

    if (status === 'approved') {
      await this.db.query(
        `INSERT INTO teacher_attendance(id, school_id, teacher_id, date, status, marked_by)
         VALUES($1, $2, $3, $4, $5, $6)
         ON CONFLICT(school_id, teacher_id, date) DO UPDATE SET status = EXCLUDED.status`,
        [uuidv4(), schoolId, req.teacher_id, req.date, req.requested_status, actorId]
      );
    }

    await this.audit(schoolId, actorId, `teacher.correction_request.${status}`, requestId, { note });
    return { id: requestId, status };
  }

  private async audit(schoolId: string, actorId: string, action: string, entityId: string, payload: any) {
    await this.db.query(
      `INSERT INTO audit_logs(id,school_id,user_id,action,entity,entity_id,payload) VALUES($1,$2,$3,$4,'attendance',$5,$6)`,
      [uuidv4(), schoolId, actorId, action, entityId, JSON.stringify(payload)],
    );
  }
}
