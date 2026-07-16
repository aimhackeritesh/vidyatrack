import { BadRequestException, ForbiddenException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { TenantDb } from '../common/database/tenant-db.service';
import { v4 as uuidv4 } from 'uuid';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(private readonly db: TenantDb) {}

  // ── Notices ─────────────────────────────────────────────────────────────────
  async sendNotice(schoolId: string, senderId: string, data: any) {
    const id = uuidv4();
    const audience = data.audience ?? 'all';
    await this.db.query(
      `INSERT INTO notices(id,school_id,audience,audience_ref_id,title,body,attachment_url,publish_at,created_by)
       VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
      [id, schoolId, audience, data.audienceRefId ?? null, data.title, data.body, data.attachmentUrl ?? null, data.publishAt ?? new Date(), senderId],
    );
    await this.fanOut(schoolId, audience, data.audienceRefId, {
      title: data.title, body: data.body, type: 'notice', data: { entity: 'notice', id },
    });
    return { id };
  }

  getNotices(schoolId: string, page = 1) {
    const limit = 20; const offset = (page - 1) * limit;
    return this.db.query(
      `SELECT n.*,u.name as created_by_name FROM notices n LEFT JOIN users u ON u.id=n.created_by
       WHERE n.school_id=$1 AND (n.publish_at IS NULL OR n.publish_at <= NOW())
       ORDER BY n.created_at DESC LIMIT $2 OFFSET $3`,
      [schoolId, limit, offset],
    );
  }

  // ── Circulars ───────────────────────────────────────────────────────────────
  async createCircular(schoolId: string, senderId: string, data: any) {
    if (!data.fileUrl) throw new BadRequestException('A file is required for a circular');
    const id = uuidv4();
    const audience = data.audience ?? 'all';
    await this.db.query(
      `INSERT INTO circulars(id,school_id,title,file_url,audience,created_by) VALUES($1,$2,$3,$4,$5,$6)`,
      [id, schoolId, data.title, data.fileUrl, audience, senderId],
    );
    await this.fanOut(schoolId, audience, null, {
      title: `Circular: ${data.title}`, body: 'A new circular has been published.', type: 'circular', data: { entity: 'circular', id },
    });
    return { id };
  }

  listCirculars(schoolId: string, page = 1) {
    const limit = 20; const offset = (page - 1) * limit;
    return this.db.query(
      `SELECT * FROM circulars WHERE school_id=$1 ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
      [schoolId, limit, offset],
    );
  }

  // ── Messages (broadcast) ──────────────────────────────────────────────────────
  async sendMessage(schoolId: string, senderId: string, data: any) {
    const id = uuidv4();
    // recipientType maps to an audience for fan-out: all_parents/teachers/students/section/all
    const map: Record<string, string> = {
      all_parents: 'parents', all_teachers: 'teachers', all_students: 'students', section: 'section', all: 'all',
    };
    const audience = map[data.recipientType] ?? 'all';
    await this.db.query(
      `INSERT INTO messages(id,school_id,sender_id,recipient_type,recipient_id,body,channel,status)
       VALUES($1,$2,$3,$4,$5,$6,$7,'sent')`,
      [id, schoolId, senderId, data.recipientType ?? 'all', data.recipientId ?? null, data.body, data.channel ?? 'push'],
    );
    const count = await this.fanOut(schoolId, audience, data.recipientId, {
      title: data.title ?? 'Message from school', body: data.body, type: 'message', data: { entity: 'message', id },
    });
    if (data.smsToggle) this.logger.log(`[SMS] message ${id} would be sent to ${count} recipients`);
    return { id, delivered: count };
  }

  // ── Suggestions ────────────────────────────────────────────────────────────
  async submitSuggestion(schoolId: string, userId: string, body: string) {
    if (!body || !body.trim()) throw new BadRequestException('Suggestion cannot be empty');
    const id = uuidv4();
    await this.db.query(`INSERT INTO suggestions(id,school_id,from_user_id,body) VALUES($1,$2,$3,$4)`, [id, schoolId, userId, body]);
    return { id };
  }

  listSuggestions(schoolId: string, status = 'open') {
    const params: any[] = [schoolId];
    let where = 's.school_id=$1';
    if (status !== 'all') { params.push(status); where += ` AND s.status=$${params.length}`; }
    return this.db.query(
      `SELECT s.*, u.name as from_name FROM suggestions s LEFT JOIN users u ON u.id=s.from_user_id
       WHERE ${where} ORDER BY s.created_at DESC`,
      params,
    );
  }

  async replySuggestion(schoolId: string, adminId: string, id: string, reply: string) {
    const [s] = await this.db.query(`SELECT * FROM suggestions WHERE id=$1 AND school_id=$2`, [id, schoolId]);
    if (!s) throw new NotFoundException('Suggestion not found');
    await this.db.query(
      `UPDATE suggestions SET reply=$3, replied_by=$4, status='closed' WHERE id=$1 AND school_id=$2`,
      [id, schoolId, reply, adminId],
    );
    if (s.from_user_id) {
      await this.insertNotifications(schoolId, [s.from_user_id], {
        title: 'Reply to your suggestion', body: reply, type: 'suggestion_reply', data: { entity: 'suggestion', id },
      });
    }
    return { id };
  }

  // ── Leave requests ───────────────────────────────────────────────────────────
  async applyLeave(schoolId: string, user: any, data: any) {
    let applicantType: 'teacher' | 'student';
    let applicantId: string;
    if (user.role === 'teacher') {
      applicantType = 'teacher';
      applicantId = await this.entityForRole(user.userRoleId);
    } else if (user.role === 'student') {
      applicantType = 'student';
      applicantId = await this.entityForRole(user.userRoleId);
    } else if (user.role === 'parent') {
      applicantType = 'student';
      applicantId = data.studentId;
      const [child] = await this.db.query(`SELECT id FROM students WHERE id=$1 AND guardian_user_id=$2`, [applicantId, user.id]);
      if (!child) throw new ForbiddenException('Not your child');
    } else {
      throw new ForbiddenException('This role cannot apply for leave');
    }
    if (!applicantId) throw new BadRequestException('Could not resolve applicant');

    const id = uuidv4();
    await this.db.query(
      `INSERT INTO leave_requests(id,school_id,applicant_type,applicant_id,from_date,to_date,reason)
       VALUES($1,$2,$3,$4,$5,$6,$7)`,
      [id, schoolId, applicantType, applicantId, data.fromDate, data.toDate, data.reason ?? null],
    );
    return { id };
  }

  listLeaves(schoolId: string, status = 'pending') {
    const params: any[] = [schoolId];
    let where = 'lr.school_id=$1';
    if (status !== 'all') { params.push(status); where += ` AND lr.status=$${params.length}`; }
    return this.db.query(
      `SELECT lr.*,
              CASE WHEN lr.applicant_type='teacher' THEN tu.name ELSE s.name END AS applicant_name
       FROM leave_requests lr
       LEFT JOIN teachers t ON lr.applicant_type='teacher' AND t.id=lr.applicant_id
       LEFT JOIN users tu ON tu.id=t.user_id
       LEFT JOIN students s ON lr.applicant_type='student' AND s.id=lr.applicant_id
       WHERE ${where} ORDER BY lr.created_at DESC`,
      params,
    );
  }

  async actLeave(schoolId: string, adminId: string, id: string, approve: boolean, note?: string) {
    const [lr] = await this.db.query(`SELECT * FROM leave_requests WHERE id=$1 AND school_id=$2`, [id, schoolId]);
    if (!lr) throw new NotFoundException('Leave request not found');
    if (lr.status !== 'pending') throw new BadRequestException('Already actioned');

    const status = approve ? 'approved' : 'rejected';
    await this.db.query(
      `UPDATE leave_requests SET status=$3, acted_by=$4, acted_at=NOW() WHERE id=$1 AND school_id=$2`,
      [id, schoolId, status, adminId],
    );

    // Notify the applicant (and a student's guardian).
    const targets = await this.usersForApplicant(schoolId, lr.applicant_type, lr.applicant_id);
    if (targets.length) {
      await this.insertNotifications(schoolId, targets, {
        title: `Leave ${status}`,
        body: `Your leave request (${lr.from_date} → ${lr.to_date}) was ${status}.${note ? ' Note: ' + note : ''}`,
        type: 'leave_status', data: { entity: 'leave', id },
      });
    }
    return { id, status };
  }

  // ── Fan-out core ─────────────────────────────────────────────────────────────
  private async fanOut(
    schoolId: string,
    audience: string,
    refId: string | null | undefined,
    payload: { title: string; body: string; type: string; data?: any },
  ): Promise<number> {
    const userIds = await this.resolveAudience(schoolId, audience, refId);
    await this.insertNotifications(schoolId, userIds, payload);
    this.logger.log(`[FANOUT] ${payload.type} → ${audience} (${userIds.length} users)`);
    return userIds.length;
  }

  private async resolveAudience(schoolId: string, audience: string, refId?: string | null): Promise<string[]> {
    let rows: any[] = [];
    switch (audience) {
      case 'teachers':
        rows = await this.db.query(`SELECT user_id FROM user_roles WHERE school_id=$1 AND role='teacher'`, [schoolId]);
        break;
      case 'parents':
        rows = await this.db.query(`SELECT user_id FROM user_roles WHERE school_id=$1 AND role='parent'`, [schoolId]);
        break;
      case 'students':
        rows = await this.db.query(`SELECT user_id FROM user_roles WHERE school_id=$1 AND role='student'`, [schoolId]);
        break;
      case 'section':
        rows = await this.db.query(
          `SELECT user_id FROM user_roles
             WHERE school_id=$1 AND role='student'
               AND linked_entity_id IN (SELECT id FROM students WHERE section_id=$2)
           UNION
           SELECT guardian_user_id AS user_id FROM students
             WHERE school_id=$1 AND section_id=$2 AND guardian_user_id IS NOT NULL`,
          [schoolId, refId],
        );
        break;
      case 'all':
      default:
        rows = await this.db.query(
          `SELECT DISTINCT user_id FROM user_roles WHERE school_id=$1 AND role IN ('admin','teacher','parent','student')`,
          [schoolId],
        );
    }
    return rows.map((r) => r.user_id).filter(Boolean);
  }

  private async insertNotifications(
    schoolId: string,
    userIds: string[],
    payload: { title: string; body: string; type: string; data?: any },
  ) {
    if (!userIds.length) return;
    const rowsSql: string[] = [];
    const params: any[] = [];
    for (const uid of userIds) {
      const b = params.length;
      rowsSql.push(`($${b + 1},$${b + 2},$${b + 3},$${b + 4},$${b + 5},$${b + 6},$${b + 7})`);
      params.push(uuidv4(), schoolId, uid, payload.title, payload.body, payload.type, JSON.stringify(payload.data ?? {}));
    }
    await this.db.query(
      `INSERT INTO notifications(id,school_id,user_id,title,body,type,data) VALUES ${rowsSql.join(',')}`,
      params,
    );
  }

  private async entityForRole(userRoleId: string): Promise<string> {
    const [r] = await this.db.query(`SELECT linked_entity_id FROM user_roles WHERE id=$1`, [userRoleId]);
    return r?.linked_entity_id;
  }

  private async usersForApplicant(schoolId: string, type: string, applicantId: string): Promise<string[]> {
    if (type === 'teacher') {
      const rows = await this.db.query(`SELECT user_id FROM teachers WHERE id=$1 AND school_id=$2`, [applicantId, schoolId]);
      return rows.map((r: any) => r.user_id).filter(Boolean);
    }
    // student: notify the student account + their guardian
    const rows = await this.db.query(
      `SELECT user_id FROM user_roles WHERE school_id=$1 AND role='student' AND linked_entity_id=$2
       UNION
       SELECT guardian_user_id AS user_id FROM students WHERE id=$2 AND guardian_user_id IS NOT NULL`,
      [schoolId, applicantId],
    );
    return rows.map((r: any) => r.user_id).filter(Boolean);
  }
}
