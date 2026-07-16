import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { TenantDb } from '../common/database/tenant-db.service';
import { v4 as uuidv4 } from 'uuid';

@Injectable()
export class AcademicsService {
  constructor(private readonly db: TenantDb) {}

  // ── Homework ─────────────────────────────────────────────────────────────────
  async createHomework(schoolId: string, userId: string, data: any) {
    const id = uuidv4();
    await this.db.query(
      `INSERT INTO homework(id,school_id,section_id,subject,title,description,attachments,due_date,created_by)
       VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
      [id, schoolId, data.sectionId, data.subject ?? 'General', data.title, data.description ?? null,
       JSON.stringify(data.attachments ?? []), data.dueDate ?? null, userId],
    );
    return { id };
  }

  listHomeworkForSection(schoolId: string, sectionId: string) {
    return this.db.query(
      `SELECT h.*, u.name as created_by_name FROM homework h LEFT JOIN users u ON u.id=h.created_by
       WHERE h.school_id=$1 AND h.section_id=$2 ORDER BY h.created_at DESC`,
      [schoolId, sectionId],
    );
  }

  async listHomeworkForViewer(schoolId: string, user: any) {
    const sectionId = await this.viewerSectionId(schoolId, user);
    if (!sectionId) return [];
    return this.listHomeworkForSection(schoolId, sectionId);
  }

  // ── Study material ───────────────────────────────────────────────────────────
  async createMaterial(schoolId: string, userId: string, data: any) {
    const id = uuidv4();
    await this.db.query(
      `INSERT INTO study_materials(id,school_id,class_id,subject,title,file_url,type,created_by)
       VALUES($1,$2,$3,$4,$5,$6,$7,$8)`,
      [id, schoolId, data.classId ?? null, data.subject ?? 'General', data.title, data.fileUrl ?? null, data.type ?? 'link', userId],
    );
    return { id };
  }

  listMaterials(schoolId: string, classId?: string, subject?: string) {
    const params: any[] = [schoolId];
    let where = 'm.school_id=$1';
    if (classId) { params.push(classId); where += ` AND m.class_id=$${params.length}`; }
    if (subject) { params.push(subject); where += ` AND m.subject=$${params.length}`; }
    return this.db.query(
      `SELECT m.*, c.name as class_name, u.name as created_by_name
       FROM study_materials m LEFT JOIN classes c ON c.id=m.class_id LEFT JOIN users u ON u.id=m.created_by
       WHERE ${where} ORDER BY m.created_at DESC`,
      params,
    );
  }

  async listMaterialsForViewer(schoolId: string, user: any) {
    const classId = await this.viewerClassId(schoolId, user);
    if (!classId) return [];
    return this.listMaterials(schoolId, classId);
  }

  async deleteMaterial(schoolId: string, userId: string, role: string, id: string) {
    const [row] = await this.db.query(`SELECT created_by FROM study_materials WHERE id=$1 AND school_id=$2`, [id, schoolId]);
    if (!row) throw new NotFoundException('Material not found');
    if (role !== 'admin' && row.created_by !== userId) throw new ForbiddenException('Not your upload');
    await this.db.query(`DELETE FROM study_materials WHERE id=$1 AND school_id=$2`, [id, schoolId]);
    return { message: 'Deleted' };
  }

  // ── Exams & results ──────────────────────────────────────────────────────────
  async createExam(schoolId: string, data: any) {
    const id = uuidv4();
    await this.db.query(
      `INSERT INTO exams(id,school_id,name,term,class_id) VALUES($1,$2,$3,$4,$5)`,
      [id, schoolId, data.name, data.term ?? null, data.classId ?? null],
    );
    return { id };
  }

  listExams(schoolId: string, classId?: string) {
    const params: any[] = [schoolId];
    let where = 'school_id=$1';
    if (classId) { params.push(classId); where += ` AND (class_id=$${params.length} OR class_id IS NULL)`; }
    return this.db.query(`SELECT * FROM exams WHERE ${where} ORDER BY created_at DESC`, params);
  }

  /** Bulk marks entry: records = [{studentId, subject, marks, maxMarks, grade}]. */
  async enterResults(schoolId: string, examId: string, records: any[]) {
    const [exam] = await this.db.query(`SELECT id FROM exams WHERE id=$1 AND school_id=$2`, [examId, schoolId]);
    if (!exam) throw new NotFoundException('Exam not found');
    if (!records?.length) return { count: 0 };
    for (const r of records) {
      await this.db.query(
        `INSERT INTO exam_results(id,exam_id,student_id,subject,marks,max_marks,grade)
         VALUES($1,$2,$3,$4,$5,$6,$7)
         ON CONFLICT(exam_id,student_id,subject) DO UPDATE SET marks=EXCLUDED.marks, max_marks=EXCLUDED.max_marks, grade=EXCLUDED.grade`,
        [uuidv4(), examId, r.studentId, r.subject, r.marks ?? null, r.maxMarks ?? 100, r.grade ?? null],
      );
    }
    return { count: records.length };
  }

  async getStudentResults(schoolId: string, user: any, studentId: string, examId?: string) {
    await this.assertStudentAccess(schoolId, user, studentId);
    const params: any[] = [studentId];
    let where = 'er.student_id=$1';
    if (examId) { params.push(examId); where += ` AND er.exam_id=$${params.length}`; }
    return this.db.query(
      `SELECT er.*, e.name as exam_name, e.term FROM exam_results er
       JOIN exams e ON e.id=er.exam_id
       WHERE ${where} AND e.school_id=$${params.length + 1}
       ORDER BY e.created_at DESC, er.subject`,
      [...params, schoolId],
    );
  }

  async getMyResults(schoolId: string, user: any, examId?: string) {
    const studentId = await this.viewerStudentId(schoolId, user);
    if (!studentId) throw new NotFoundException('No linked student');
    return this.getStudentResults(schoolId, user, studentId, examId);
  }

  // ── Timetable ────────────────────────────────────────────────────────────────
  async upsertTimetableSlot(schoolId: string, data: any) {
    const [row] = await this.db.query(
      `INSERT INTO timetable_slots(id,school_id,section_id,day,period_no,subject,teacher_id,start_time,end_time)
       VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9)
       ON CONFLICT(school_id,section_id,day,period_no)
       DO UPDATE SET subject=EXCLUDED.subject, teacher_id=EXCLUDED.teacher_id, start_time=EXCLUDED.start_time, end_time=EXCLUDED.end_time
       RETURNING id`,
      [uuidv4(), schoolId, data.sectionId, data.day, data.periodNo, data.subject,
       data.teacherId ?? null, data.startTime, data.endTime],
    );
    return { id: row.id };
  }

  /** Replaces a section's whole week in one go (admin edits the grid then saves once). */
  async bulkSetTimetable(schoolId: string, sectionId: string, slots: any[]) {
    await this.db.query(`DELETE FROM timetable_slots WHERE school_id=$1 AND section_id=$2`, [schoolId, sectionId]);
    for (const s of slots ?? []) {
      await this.db.query(
        `INSERT INTO timetable_slots(id,school_id,section_id,day,period_no,subject,teacher_id,start_time,end_time)
         VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
        [uuidv4(), schoolId, sectionId, s.day, s.periodNo, s.subject, s.teacherId ?? null, s.startTime, s.endTime],
      );
    }
    return { count: slots?.length ?? 0 };
  }

  listTimetable(schoolId: string, sectionId: string) {
    return this.db.query(
      `SELECT ts.*, u.name as teacher_name
       FROM timetable_slots ts
       LEFT JOIN teachers t ON t.id = ts.teacher_id
       LEFT JOIN users u ON u.id = t.user_id
       WHERE ts.school_id=$1 AND ts.section_id=$2
       ORDER BY ts.day, ts.period_no`,
      [schoolId, sectionId],
    );
  }

  async listTimetableForViewer(schoolId: string, user: any) {
    const sectionId = await this.viewerSectionId(schoolId, user);
    if (!sectionId) return [];
    return this.listTimetable(schoolId, sectionId);
  }

  /** Teacher's own periods across every section they teach. */
  async listTimetableForTeacher(schoolId: string, userId: string) {
    const [t] = await this.db.query(`SELECT id FROM teachers WHERE school_id=$1 AND user_id=$2`, [schoolId, userId]);
    if (!t) return [];
    return this.db.query(
      `SELECT ts.*, s.name as section_name, c.name as class_name
       FROM timetable_slots ts
       JOIN sections s ON s.id = ts.section_id
       JOIN classes c ON c.id = s.class_id
       WHERE ts.school_id=$1 AND ts.teacher_id=$2
       ORDER BY ts.day, ts.period_no`,
      [schoolId, t.id],
    );
  }

  async deleteTimetableSlot(schoolId: string, id: string) {
    const res = await this.db.query(`DELETE FROM timetable_slots WHERE id=$1 AND school_id=$2 RETURNING id`, [id, schoolId]);
    if (!res.length) throw new NotFoundException('Slot not found');
    return { message: 'Deleted' };
  }

  // ── Syllabus ─────────────────────────────────────────────────────────────────
  async upsertSyllabus(schoolId: string, data: any) {
    const [row] = await this.db.query(
      `INSERT INTO syllabus(id,school_id,class_id,subject,file_url,topics_json)
       VALUES($1,$2,$3,$4,$5,$6)
       ON CONFLICT(school_id,class_id,subject)
       DO UPDATE SET file_url=EXCLUDED.file_url, topics_json=EXCLUDED.topics_json
       RETURNING id`,
      [uuidv4(), schoolId, data.classId, data.subject, data.fileUrl ?? null, JSON.stringify(data.topics ?? [])],
    );
    return { id: row.id };
  }

  listSyllabus(schoolId: string, classId?: string) {
    const params: any[] = [schoolId];
    let where = 'school_id=$1';
    if (classId) { params.push(classId); where += ` AND class_id=$${params.length}`; }
    return this.db.query(`SELECT * FROM syllabus WHERE ${where} ORDER BY subject`, params);
  }

  async listSyllabusForViewer(schoolId: string, user: any) {
    const classId = await this.viewerClassId(schoolId, user);
    if (!classId) return [];
    return this.listSyllabus(schoolId, classId);
  }

  async deleteSyllabus(schoolId: string, id: string) {
    const res = await this.db.query(`DELETE FROM syllabus WHERE id=$1 AND school_id=$2 RETURNING id`, [id, schoolId]);
    if (!res.length) throw new NotFoundException('Syllabus entry not found');
    return { message: 'Deleted' };
  }

  // ── helpers ──────────────────────────────────────────────────────────────────
  private async viewerStudentId(schoolId: string, user: any): Promise<string | undefined> {
    if (user.role === 'student') {
      const [r] = await this.db.query(`SELECT linked_entity_id FROM user_roles WHERE id=$1`, [user.userRoleId]);
      return r?.linked_entity_id;
    }
    if (user.role === 'parent') {
      const [r] = await this.db.query(
        `SELECT id FROM students WHERE school_id=$1 AND guardian_user_id=$2 AND status='active' ORDER BY created_at LIMIT 1`,
        [schoolId, user.id],
      );
      return r?.id;
    }
    return undefined;
  }

  private async viewerSectionId(schoolId: string, user: any): Promise<string | undefined> {
    const studentId = await this.viewerStudentId(schoolId, user);
    if (!studentId) return undefined;
    const [r] = await this.db.query(`SELECT section_id FROM students WHERE id=$1 AND school_id=$2`, [studentId, schoolId]);
    return r?.section_id;
  }

  private async viewerClassId(schoolId: string, user: any): Promise<string | undefined> {
    const sectionId = await this.viewerSectionId(schoolId, user);
    if (!sectionId) return undefined;
    const [r] = await this.db.query(`SELECT class_id FROM sections WHERE id=$1 AND school_id=$2`, [sectionId, schoolId]);
    return r?.class_id;
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
      if (!r) throw new ForbiddenException('Not allowed');
      return;
    }
    throw new ForbiddenException('Not allowed');
  }
}
