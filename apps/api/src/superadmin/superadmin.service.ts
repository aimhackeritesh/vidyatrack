import { BadRequestException, Injectable, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { TenantDb } from '../common/database/tenant-db.service';
import { SchoolConfigService } from '../config/school-config.service';
import { getSettingDef, validateSetting } from '../config/settings-registry';
import { v4 as uuidv4 } from 'uuid';
import { randomInt } from 'crypto';
import * as argon2 from 'argon2';

const PW_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
const CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
function gen(chars: string, len: number): string {
  let out = '';
  for (let i = 0; i < len; i++) out += chars[randomInt(chars.length)];
  return out;
}

@Injectable()
export class SuperAdminService {
  constructor(
    private readonly db: TenantDb,
    private readonly jwt: JwtService,
    private readonly cfg: ConfigService,
    private readonly schoolConfig: SchoolConfigService,
  ) {}

  async login(email: string, password: string) {
    const [user] = await this.db.query(`SELECT * FROM users WHERE email=$1 AND is_superadmin=true`, [email]);
    if (!user || !user.password_hash) throw new UnauthorizedException('Invalid credentials');
    const ok = await argon2.verify(user.password_hash, password);
    if (!ok) throw new UnauthorizedException('Invalid credentials');
    const accessToken = this.jwt.sign(
      { sub: user.id, role: 'superadmin' },
      { secret: this.cfg.get('JWT_SECRET'), expiresIn: this.cfg.get('JWT_EXPIRES_IN') || '60m' },
    );
    return { accessToken, user: { id: user.id, name: user.name, email: user.email } };
  }

  async listSchools() {
    return this.db.query(
      `SELECT s.id, s.code, s.name, s.city, s.state, s.plan, s.status, s.sms_credits, s.max_students, s.created_at,
              (SELECT COUNT(*) FROM students st WHERE st.school_id=s.id AND st.status='active') AS student_count,
              (SELECT COUNT(*) FROM teachers t WHERE t.school_id=s.id AND t.status='active') AS teacher_count,
              (SELECT MAX(date) FROM daily_attendance_summary das WHERE das.school_id=s.id) AS last_attendance
       FROM schools s ORDER BY s.created_at DESC`,
    );
  }

  async createSchool(actorId: string, data: any) {
    if (!data.name || !data.principalName || !data.phone) {
      throw new BadRequestException('name, principalName and phone are required');
    }
    const [existing] = await this.db.query(`SELECT id FROM users WHERE phone=$1`, [data.phone]);
    if (existing) throw new BadRequestException('A user with this phone already exists');

    const code = await this.uniqueCode();
    const schoolId = uuidv4();
    await this.db.query(
      `INSERT INTO schools(id,code,name,principal_name,email,phone,city,state,academic_year_start,plan,status,max_students,sms_credits)
       VALUES($1,$2,$3,$4,$5,$6,$7,$8,CURRENT_DATE,$9,'active',$10,$11)`,
      [schoolId, code, data.name, data.principalName, data.email ?? null, data.phone, data.city ?? null, data.state ?? null,
       data.plan ?? 'starter', data.maxStudents ?? 500, data.smsCredits ?? 100],
    );

    const tempPw = gen(PW_CHARS, 8);
    const userId = uuidv4();
    await this.db.query(
      `INSERT INTO users(id,phone,email,password_hash,name,must_change_password,status)
       VALUES($1,$2,$3,$4,$5,true,'active')`,
      [userId, data.phone, data.email ?? null, await argon2.hash(tempPw), data.principalName],
    );
    await this.db.query(
      `INSERT INTO user_roles(id,user_id,school_id,role) VALUES($1,$2,$3,'admin')`,
      [uuidv4(), userId, schoolId],
    );
    await this.audit(schoolId, actorId, 'school.create', schoolId, { code, principalPhone: data.phone });

    return { schoolId, schoolCode: code, principal: { name: data.principalName, phone: data.phone, tempPassword: tempPw } };
  }

  async setStatus(actorId: string, schoolId: string, status: 'active' | 'suspended') {
    const [s] = await this.db.query(`SELECT id FROM schools WHERE id=$1`, [schoolId]);
    if (!s) throw new NotFoundException('School not found');
    await this.db.query(`UPDATE schools SET status=$2, updated_at=NOW() WHERE id=$1`, [schoolId, status]);
    await this.audit(schoolId, actorId, `school.${status}`, schoolId, {});
    return { id: schoolId, status };
  }

  async setLimits(actorId: string, schoolId: string, data: any) {
    const sets: string[] = [];
    const params: any[] = [schoolId];
    for (const [col, key] of [['plan', 'plan'], ['max_students', 'maxStudents'], ['sms_credits', 'smsCredits'], ['plan_expires_at', 'planExpiresAt']]) {
      if (data[key] !== undefined) { params.push(data[key]); sets.push(`${col}=$${params.length}`); }
    }
    if (!sets.length) throw new BadRequestException('Nothing to update');
    await this.db.query(`UPDATE schools SET ${sets.join(',')}, updated_at=NOW() WHERE id=$1`, params);
    await this.audit(schoolId, actorId, 'school.limits', schoolId, data);
    return { id: schoolId };
  }

  // ── Platform analytics (V3.6) ────────────────────────────────────────────────
  async getAnalytics() {
    const [schoolCounts] = await this.db.query(
      `SELECT COUNT(*) AS total,
              COUNT(*) FILTER (WHERE status='active') AS active,
              COUNT(*) FILTER (WHERE status='suspended') AS suspended
       FROM schools`,
    );
    const [studentCount] = await this.db.query(`SELECT COUNT(*) AS total FROM students WHERE status='active'`);
    const usersByRole = await this.db.query(
      `SELECT role, COUNT(DISTINCT user_id) AS count FROM user_roles GROUP BY role ORDER BY role`,
    );
    const [onlineFeeVolume] = await this.db.query(
      `SELECT COALESCE(SUM(amount),0) AS total FROM fee_payments WHERE mode='online' AND voided_at IS NULL`,
    );
    const [attendanceToday] = await this.db.query(
      `SELECT COUNT(DISTINCT school_id) AS schools_marked FROM attendance_sessions WHERE date=CURRENT_DATE`,
    );
    const [invoicesThisMonth] = await this.db.query(
      `SELECT COUNT(*) AS total, COUNT(*) FILTER (WHERE status='paid') AS paid
       FROM fee_invoices WHERE month = date_trunc('month', CURRENT_DATE)::date`,
    );
    return {
      schools: schoolCounts,
      activeStudents: Number(studentCount.total),
      usersByRole,
      onlineFeeVolume: Number(onlineFeeVolume.total),
      schoolsMarkedAttendanceToday: Number(attendanceToday.schools_marked),
      invoicesThisMonth,
    };
  }

  async getSchoolStats(schoolId: string) {
    const [school] = await this.db.query(`SELECT * FROM schools WHERE id=$1`, [schoolId]);
    if (!school) throw new NotFoundException('School not found');
    const [students] = await this.db.query(`SELECT COUNT(*) AS total FROM students WHERE school_id=$1 AND status='active'`, [schoolId]);
    const [revenue] = await this.db.query(`SELECT * FROM daily_revenue_summary WHERE school_id=$1`, [schoolId]);
    const [lastActive] = await this.db.query(
      `SELECT GREATEST(
         (SELECT MAX(date) FROM daily_attendance_summary WHERE school_id=$1),
         (SELECT MAX(created_at)::date FROM audit_logs WHERE school_id=$1)
       ) AS last_active`,
      [schoolId],
    );
    return { school, activeStudents: Number(students.total), revenue: revenue ?? null, lastActive: lastActive?.last_active ?? null };
  }

  // ── School settings (registry-backed) ────────────────────────────────────────
  /** Raw stored overrides for a school. Effective values come from `getSchoolConfig`. */
  async getSchoolSettings(schoolId: string) {
    return this.db.query(`SELECT key, value FROM school_settings WHERE school_id=$1 ORDER BY key`, [schoolId]);
  }

  /** The catalog the console renders its typed editor from. */
  getSettingsRegistry() {
    return this.schoolConfig.getRegistry();
  }

  /** What the school's apps actually resolve — defaults with overrides applied. */
  getSchoolConfig(schoolId: string) {
    return this.schoolConfig.resolve(schoolId);
  }

  /**
   * Writes one setting after validating it against the registry. Before V4 any
   * key/value was accepted, so a typo'd key silently did nothing forever; now an
   * unknown key or out-of-range value is a 400. Legacy un-namespaced rows stay
   * readable (see SchoolConfigService) but new writes always use the registry key.
   */
  async setSchoolSetting(actorId: string, schoolId: string, key: string, value: string) {
    if (!key) throw new BadRequestException('key is required');

    const def = getSettingDef(key);
    if (!def) {
      throw new BadRequestException(
        `Unknown setting '${key}'. Call GET /superadmin/settings-registry for the valid keys.`,
      );
    }
    const result = validateSetting(def, value);
    if (!result.ok) throw new BadRequestException(result.error);

    await this.db.query(
      `INSERT INTO school_settings(school_id,key,value,updated_at) VALUES($1,$2,$3,NOW())
       ON CONFLICT(school_id,key) DO UPDATE SET value=EXCLUDED.value, updated_at=NOW()`,
      [schoolId, def.key, result.value],
    );
    await this.schoolConfig.invalidate(schoolId);
    await this.audit(schoolId, actorId, 'settings.update', schoolId, { key: def.key, value: result.value });
    return { key: def.key, value: result.value };
  }

  // ── Broadcast ─────────────────────────────────────────────────────────────────
  /** Fan a platform notice out to chosen schools (or all active) and roles. */
  async broadcast(actorId: string, data: any) {
    const { title, body, schoolIds, roles } = data;
    if (!title || !body) throw new BadRequestException('title and body are required');
    const targetSchools = schoolIds?.length ? schoolIds : (await this.db.query(`SELECT id FROM schools WHERE status='active'`)).map((s: any) => s.id);
    const targetRoles = roles?.length ? roles : ['admin', 'teacher', 'parent', 'student'];

    let notified = 0;
    for (const schoolId of targetSchools) {
      const users = await this.db.query(
        `SELECT DISTINCT user_id FROM user_roles WHERE school_id=$1 AND role::text = ANY($2::text[])`,
        [schoolId, targetRoles],
      );
      for (const u of users) {
        await this.db.query(
          `INSERT INTO notifications(id,school_id,user_id,title,body,type,data) VALUES($1,$2,$3,$4,$5,'platform_broadcast',$6)`,
          [uuidv4(), schoolId, u.user_id, title, body, JSON.stringify({ from: 'superadmin' })],
        );
        notified++;
      }
      await this.audit(schoolId, actorId, 'broadcast.send', schoolId, { title, roles: targetRoles });
    }
    return { schoolsTargeted: targetSchools.length, usersNotified: notified };
  }

  // ── Audit log viewer ──────────────────────────────────────────────────────────
  async listAudit(schoolId?: string, limit = 100) {
    const params: any[] = [];
    let where = '1=1';
    if (schoolId) { params.push(schoolId); where += ` AND school_id=$${params.length}`; }
    params.push(Math.min(limit, 500));
    return this.db.query(
      `SELECT a.*, u.name as user_name, s.code as school_code
       FROM audit_logs a LEFT JOIN users u ON u.id=a.user_id LEFT JOIN schools s ON s.id=a.school_id
       WHERE ${where} ORDER BY a.created_at DESC LIMIT $${params.length}`,
      params,
    );
  }

  /** Regenerate the principal (first admin) password and return a fresh slip. */
  async resetPrincipal(actorId: string, schoolId: string) {
    const [admin] = await this.db.query(
      `SELECT u.id, u.name, u.phone FROM users u
       JOIN user_roles ur ON ur.user_id=u.id
       WHERE ur.school_id=$1 AND ur.role='admin' ORDER BY ur.created_at LIMIT 1`,
      [schoolId],
    );
    if (!admin) throw new NotFoundException('No principal/admin found for this school');
    const tempPw = gen(PW_CHARS, 8);
    await this.db.query(
      `UPDATE users SET password_hash=$2, must_change_password=true, updated_at=NOW() WHERE id=$1`,
      [admin.id, await argon2.hash(tempPw)],
    );
    await this.audit(schoolId, actorId, 'school.reset_principal', schoolId, {});
    const [school] = await this.db.query(`SELECT code FROM schools WHERE id=$1`, [schoolId]);
    return { schoolCode: school?.code, principal: { name: admin.name, phone: admin.phone, tempPassword: tempPw } };
  }

  // helpers
  private async uniqueCode(): Promise<string> {
    for (let i = 0; i < 10; i++) {
      const code = `VDTRK${gen(CODE_CHARS, 6)}`;
      const [exists] = await this.db.query(`SELECT 1 FROM schools WHERE code=$1`, [code]);
      if (!exists) return code;
    }
    throw new BadRequestException('Could not generate a unique school code');
  }

  private async audit(schoolId: string, actorId: string, action: string, entityId: string, payload: any) {
    await this.db.query(
      `INSERT INTO audit_logs(id,school_id,user_id,action,entity,entity_id,payload) VALUES($1,$2,$3,$4,'school',$5,$6)`,
      [uuidv4(), schoolId, actorId, action, entityId, JSON.stringify(payload)],
    );
  }
}
