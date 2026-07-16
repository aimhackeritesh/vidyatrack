import { Injectable, NotFoundException } from '@nestjs/common';
import { TenantDb } from '../common/database/tenant-db.service';
import { v4 as uuidv4 } from 'uuid';
import { randomInt } from 'crypto';
import * as argon2 from 'argon2';

// Readable 8-char temp password — excludes ambiguous chars (0/O, 1/I/l).
const PW_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
function genPassword(len = 8): string {
  let out = '';
  for (let i = 0; i < len; i++) out += PW_CHARS[randomInt(PW_CHARS.length)];
  return out;
}

export interface IssuedCredential {
  loginId: string;
  password: string | null; // null when an existing parent account was reused
  reused?: boolean;
}

@Injectable()
export class StudentsService {
  constructor(private readonly db: TenantDb) {}

  async list(schoolId: string, query: any) {
    const { sectionId, search, page = 1, limit = 40, status = 'active' } = query;
    const offset = (page - 1) * limit;
    const params: any[] = [schoolId];
    let where = `s.school_id=$1`;
    if (status !== 'all') { params.push(status); where += ` AND s.status=$${params.length}`; }
    if (sectionId) { params.push(sectionId); where += ` AND s.section_id=$${params.length}`; }
    if (search) { params.push(`%${search}%`); where += ` AND (s.name ILIKE $${params.length} OR s.admission_no ILIKE $${params.length} OR s.roll_no::TEXT ILIKE $${params.length})`; }
    params.push(limit, offset);
    return this.db.query(
      `SELECT s.*, sec.name as section_name, c.name as class_name
       FROM students s JOIN sections sec ON sec.id=s.section_id JOIN classes c ON c.id=sec.class_id
       WHERE ${where} ORDER BY s.roll_no LIMIT $${params.length - 1} OFFSET $${params.length}`,
      params,
    );
  }

  async findById(schoolId: string, id: string) {
    const [s] = await this.db.query(
      `SELECT s.*, sec.name as section_name, c.name as class_name,
              u.name as guardian_name, u.phone as guardian_phone
       FROM students s
       JOIN sections sec ON sec.id=s.section_id JOIN classes c ON c.id=sec.class_id
       LEFT JOIN users u ON u.id=s.guardian_user_id
       WHERE s.id=$1 AND s.school_id=$2`,
      [id, schoolId],
    );
    if (!s) throw new NotFoundException('Student not found');
    return s;
  }

  /**
   * Create a student and, in the same request transaction, auto-provision a
   * Student login (STU-{admission_no}) and a Parent login (PAR-{admission_no}).
   * Returns the one-time plaintext credentials so the app can show a slip.
   * Passwords are stored hashed; the audit log never records the plaintext.
   */
  async create(schoolId: string, actorId: string, data: any) {
    const admissionNo = (data.admissionNo && String(data.admissionNo).trim()) || (await this.nextAdmissionNo(schoolId));

    const studentId = uuidv4();
    await this.db.query(
      `INSERT INTO students(id,school_id,section_id,admission_no,roll_no,name,dob,gender,status,admission_date)
       VALUES($1,$2,$3,$4,$5,$6,$7,$8,'active',COALESCE($9,CURRENT_DATE))`,
      [studentId, schoolId, data.sectionId, admissionNo, data.rollNo ?? null, data.name, data.dob ?? null, data.gender ?? null, data.admissionDate ?? null],
    );

    // ----- Student login -----
    const studentLoginId = `STU-${admissionNo}`;
    const studentPw = genPassword();
    const studentUserId = uuidv4();
    await this.db.query(
      `INSERT INTO users(id,login_id,password_hash,name,must_change_password,status)
       VALUES($1,$2,$3,$4,true,'active')`,
      [studentUserId, studentLoginId, await argon2.hash(studentPw), data.name],
    );
    await this.db.query(
      `INSERT INTO user_roles(id,user_id,school_id,role,linked_entity_id) VALUES($1,$2,$3,'student',$4)`,
      [uuidv4(), studentUserId, schoolId, studentId],
    );
    const studentCred: IssuedCredential = { loginId: studentLoginId, password: studentPw };

    // ----- Parent login (reuse if a parent with this phone already exists here) -----
    let parentUserId: string | null = null;
    let parentCred: IssuedCredential;
    const guardianPhone = data.guardianPhone ? String(data.guardianPhone).trim() : null;

    let existingParent: any = null;
    if (guardianPhone) {
      [existingParent] = await this.db.query(
        `SELECT u.id, u.login_id FROM users u
         JOIN user_roles ur ON ur.user_id=u.id
         WHERE ur.school_id=$1 AND ur.role='parent' AND u.phone=$2 LIMIT 1`,
        [schoolId, guardianPhone],
      );
    }

    if (existingParent) {
      // Link the new child to the existing parent (relationship lives on students.guardian_user_id).
      parentUserId = existingParent.id;
      parentCred = { loginId: existingParent.login_id ?? `PAR-${guardianPhone}`, password: null, reused: true };
    } else {
      const parentLoginId = `PAR-${admissionNo}`;
      const parentPw = genPassword();
      parentUserId = uuidv4();
      await this.db.query(
        `INSERT INTO users(id,phone,login_id,password_hash,name,must_change_password,status)
         VALUES($1,$2,$3,$4,$5,true,'active')`,
        [parentUserId, guardianPhone, parentLoginId, await argon2.hash(parentPw), data.guardianName ?? `${data.name}'s Guardian`],
      );
      await this.db.query(
        `INSERT INTO user_roles(id,user_id,school_id,role,linked_entity_id) VALUES($1,$2,$3,'parent',$4)`,
        [uuidv4(), parentUserId, schoolId, studentId],
      );
      parentCred = { loginId: parentLoginId, password: parentPw };
    }

    await this.db.query(`UPDATE students SET guardian_user_id=$1 WHERE id=$2`, [parentUserId, studentId]);

    await this.audit(schoolId, actorId, 'student.create', studentId, { admissionNo, studentLoginId, parentLoginId: parentCred.loginId });

    const student = await this.findById(schoolId, studentId);
    return { student, credentials: { student: studentCred, parent: parentCred } };
  }

  /**
   * Bulk import students (CSV parsed to rows on the client). Each row is wrapped
   * in a SAVEPOINT so one bad row doesn't abort the whole batch; returns the
   * generated credentials for the successes and per-row errors for the rest.
   * Row shape: { name, class, section, rollNo?, admissionNo?, gender?, guardianName?, guardianPhone?, dob? }
   */
  async bulkImport(schoolId: string, actorId: string, rows: any[], dryRun = false) {
    if (!Array.isArray(rows) || !rows.length) return { imported: 0, failed: 0, credentials: [], errors: [] };
    const credentials: any[] = [];
    const errors: any[] = [];
    const processedAdmissions = new Set<string>();

    for (let i = 0; i < rows.length; i++) {
      const row = rows[i] ?? {};
      const sp = `sp_${i}`;
      await this.db.query(`SAVEPOINT ${sp}`);
      
      const rawName = row.student_name ?? row.name;
      const name = rawName ? String(rawName).trim() : '';
      const className = row.class ? String(row.class).trim() : '';
      const sectionName = row.section ? String(row.section).trim() : '';
      const gender = row.gender ? String(row.gender).trim().toUpperCase() : null;
      const dob = row.dob ? String(row.dob).trim() : null;
      const guardianName = (row.parent_name ?? row.guardianName) ? String(row.parent_name ?? row.guardianName).trim() : '';
      const guardianPhone = (row.parent_phone ?? row.guardianPhone) ? String(row.parent_phone ?? row.guardianPhone).trim() : '';
      const admissionNo = (row.admissionNo ?? row.admission_no) ? String(row.admissionNo ?? row.admission_no).trim() : null;
      const rollNo = (row.rollNo ?? row.roll_no) ? Number(row.rollNo ?? row.roll_no) : null;

      try {
        if (!name) throw new Error('Missing student name');
        if (!className) throw new Error('Missing class');
        if (!sectionName) throw new Error('Missing section');
        if (!guardianName) throw new Error('Missing parent/guardian name');
        if (!guardianPhone) throw new Error('Missing parent/guardian phone');

        if (admissionNo) {
          if (processedAdmissions.has(admissionNo)) {
            throw new Error(`Duplicate admission number "${admissionNo}" in CSV`);
          }
          processedAdmissions.add(admissionNo);

          // Check if admission number already exists in DB
          const [exists] = await this.db.query(
            `SELECT 1 FROM students WHERE school_id=$1 AND admission_no=$2 LIMIT 1`,
            [schoolId, admissionNo]
          );
          if (exists) {
            throw new Error(`Admission number "${admissionNo}" already exists in the school`);
          }
        }

        const sectionId = await this.resolveSection(schoolId, className, sectionName);
        if (!sectionId) throw new Error(`Class "${className}" / Section "${sectionName}" not found`);

        const r = await this.create(schoolId, actorId, {
          name,
          sectionId,
          rollNo,
          admissionNo,
          gender,
          dob,
          guardianName,
          guardianPhone,
        });

        if (dryRun) {
          // Roll back to savepoint to ensure no data is saved, but validation is recorded
          await this.db.query(`ROLLBACK TO SAVEPOINT ${sp}`);
        } else {
          await this.db.query(`RELEASE SAVEPOINT ${sp}`);
        }

        credentials.push({
          row: i + 1,
          name: r.student.name,
          admissionNo: r.student.admission_no,
          student: r.credentials.student,
          parent: r.credentials.parent,
        });
      } catch (e: any) {
        await this.db.query(`ROLLBACK TO SAVEPOINT ${sp}`);
        errors.push({
          row: i + 1,
          name: name || 'Row ' + (i + 1),
          error: e?.message ?? 'failed',
        });
      }
    }
    return {
      imported: dryRun ? 0 : credentials.length,
      previewCount: dryRun ? credentials.length : 0,
      failed: errors.length,
      credentials,
      errors,
    };
  }

  private async resolveSection(schoolId: string, className: any, sectionName: any): Promise<string | undefined> {
    const [r] = await this.db.query(
      `SELECT sec.id FROM sections sec JOIN classes c ON c.id=sec.class_id
       WHERE c.school_id=$1 AND c.name=$2 AND sec.name=$3`,
      [schoolId, String(className ?? '').trim(), String(sectionName ?? '').trim()],
    );
    return r?.id;
  }

  async update(schoolId: string, actorId: string, id: string, data: any) {
    const student = await this.findById(schoolId, id); // throws NotFoundException if doesn't exist

    // 1. Update demographics and section/class
    const allowed = ['name', 'dob', 'gender', 'section_id', 'roll_no', 'photo_url', 'status'];
    const updateData = { ...data };

    // Map camelCase keys if provided
    if (data.sectionId !== undefined) updateData.section_id = data.sectionId;
    if (data.rollNo !== undefined) updateData.roll_no = data.rollNo;

    const keys = Object.keys(updateData).filter((k) => allowed.includes(k));
    if (keys.length) {
      const sets = keys.map((k, i) => `${k}=$${i + 3}`).join(',');
      const vals = keys.map((k) => updateData[k]);
      await this.db.query(
        `UPDATE students SET ${sets},updated_at=NOW() WHERE id=$1 AND school_id=$2`,
        [id, schoolId, ...vals]
      );
    }

    // 2. Update parent/guardian details
    const guardianPhone = data.guardianPhone ? String(data.guardianPhone).trim() : null;
    const guardianName = data.guardianName ? String(data.guardianName).trim() : null;

    if (guardianPhone || guardianName) {
      let linkedParentId = student.guardian_user_id;

      if (guardianPhone) {
        // Check if another parent with this phone already exists in this school
        const [existingParent] = await this.db.query(
          `SELECT u.id FROM users u
           JOIN user_roles ur ON ur.user_id=u.id
           WHERE ur.school_id=$1 AND ur.role='parent' AND u.phone=$2 LIMIT 1`,
          [schoolId, guardianPhone]
        );

        if (existingParent) {
          // Sibling parent account reuse: link the student to the existing parent user
          if (existingParent.id !== linkedParentId) {
            await this.db.query(
              `UPDATE students SET guardian_user_id=$1, updated_at=NOW() WHERE id=$2 AND school_id=$3`,
              [existingParent.id, id, schoolId]
            );
            linkedParentId = existingParent.id;
          }
          if (guardianName) {
            await this.db.query(
              `UPDATE users SET name=$1, updated_at=NOW() WHERE id=$2`,
              [guardianName, linkedParentId]
            );
          }
        } else {
          // No other parent exists with this phone.
          if (linkedParentId) {
            // Update the existing linked parent user
            const sets: string[] = [];
            const params: any[] = [];
            if (guardianPhone) {
              sets.push(`phone=$${sets.length + 1}`);
              params.push(guardianPhone);
            }
            if (guardianName) {
              sets.push(`name=$${sets.length + 1}`);
              params.push(guardianName);
            }
            params.push(linkedParentId);
            await this.db.query(
              `UPDATE users SET ${sets.join(',')}, updated_at=NOW() WHERE id=$${params.length}`,
              params
            );
          } else {
            // Create a new parent user and link them
            const parentLoginId = `PAR-${student.admission_no}`;
            const parentPw = genPassword();
            const newParentId = uuidv4();
            await this.db.query(
              `INSERT INTO users(id,phone,login_id,password_hash,name,must_change_password,status)
               VALUES($1,$2,$3,$4,$5,true,'active')`,
              [newParentId, guardianPhone, parentLoginId, await argon2.hash(parentPw), guardianName ?? `${student.name}'s Guardian`]
            );
            await this.db.query(
              `INSERT INTO user_roles(id,user_id,school_id,role,linked_entity_id) VALUES($1,$2,$3,'parent',$4)`,
              [uuidv4(), newParentId, schoolId, id]
            );
            await this.db.query(
              `UPDATE students SET guardian_user_id=$1, updated_at=NOW() WHERE id=$2 AND school_id=$3`,
              [newParentId, id, schoolId]
            );
          }
        }
      } else if (guardianName && linkedParentId) {
        // Only guardianName is provided, update name of linked parent
        await this.db.query(
          `UPDATE users SET name=$1, updated_at=NOW() WHERE id=$2`,
          [guardianName, linkedParentId]
        );
      }
    }

    // 3. Audit logging
    await this.audit(schoolId, actorId, 'student.update', id, {
      updatedFields: Object.keys(data),
      data: { ...data, password: null }
    });

    return this.findById(schoolId, id);
  }

  /** Soft-remove: never hard delete. Excluded from rosters/invoices, kept in history. */
  async deactivate(schoolId: string, actorId: string, id: string, reason: string) {
    await this.findById(schoolId, id); // 404 if missing
    await this.db.query(`UPDATE students SET status='inactive',updated_at=NOW() WHERE id=$1 AND school_id=$2`, [id, schoolId]);
    await this.audit(schoolId, actorId, 'student.deactivate', id, { reason });
    return { message: 'Student deactivated', id };
  }

  /** Admin reset: regenerate the student's (and linked parent's) temp passwords. */
  async resetCredentials(schoolId: string, actorId: string, id: string) {
    const student = await this.findById(schoolId, id);
    const studentPw = genPassword();
    await this.db.query(
      `UPDATE users SET password_hash=$1, must_change_password=true, updated_at=NOW()
       WHERE id=(SELECT user_id FROM user_roles WHERE school_id=$2 AND role='student' AND linked_entity_id=$3)`,
      [await argon2.hash(studentPw), schoolId, id],
    );
    const [studentUser] = await this.db.query(
      `SELECT u.login_id FROM users u JOIN user_roles ur ON ur.user_id=u.id
       WHERE ur.school_id=$1 AND ur.role='student' AND ur.linked_entity_id=$2`,
      [schoolId, id],
    );

    let parentCred: IssuedCredential | null = null;
    if (student.guardian_user_id) {
      const parentPw = genPassword();
      await this.db.query(
        `UPDATE users SET password_hash=$1, must_change_password=true, updated_at=NOW() WHERE id=$2`,
        [await argon2.hash(parentPw), student.guardian_user_id],
      );
      const [pu] = await this.db.query(`SELECT login_id FROM users WHERE id=$1`, [student.guardian_user_id]);
      parentCred = { loginId: pu?.login_id ?? '', password: parentPw };
    }

    await this.audit(schoolId, actorId, 'student.reset_credentials', id, {});
    return {
      student: this.cleanStudentName(student),
      credentials: {
        student: { loginId: studentUser?.login_id ?? '', password: studentPw } as IssuedCredential,
        parent: parentCred,
      },
    };
  }

  async search(schoolId: string, q: string) {
    return this.db.query(
      `SELECT s.id,s.name,s.admission_no,s.roll_no,s.photo_url,sec.name as section,c.name as class
       FROM students s JOIN sections sec ON sec.id=s.section_id JOIN classes c ON c.id=sec.class_id
       WHERE s.school_id=$1 AND s.status='active' AND (s.name ILIKE $2 OR s.admission_no ILIKE $2 OR s.roll_no::TEXT=$3)
       LIMIT 20`,
      [schoolId, `%${q}%`, q],
    );
  }

  // ----- helpers -----
  private async nextAdmissionNo(schoolId: string): Promise<string> {
    const [{ next }] = await this.db.query(
      `SELECT COALESCE(MAX(CASE WHEN admission_no ~ '^[0-9]+$' THEN admission_no::BIGINT END),0)+1 AS next
       FROM students WHERE school_id=$1`,
      [schoolId],
    );
    return String(next);
  }

  private cleanStudentName(s: any) {
    return { id: s.id, name: s.name, admission_no: s.admission_no, class_name: s.class_name, section_name: s.section_name };
  }

  private async audit(schoolId: string, actorId: string, action: string, entityId: string, payload: any) {
    await this.db.query(
      `INSERT INTO audit_logs(id,school_id,user_id,action,entity,entity_id,payload) VALUES($1,$2,$3,$4,'student',$5,$6)`,
      [uuidv4(), schoolId, actorId, action, entityId, JSON.stringify(payload)],
    );
  }
}
