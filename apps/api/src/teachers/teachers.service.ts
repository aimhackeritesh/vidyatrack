import { Injectable } from '@nestjs/common';
import { TenantDb } from '../common/database/tenant-db.service';
import { v4 as uuidv4 } from 'uuid';
import * as argon2 from 'argon2';

@Injectable()
export class TeachersService {
  constructor(private readonly db: TenantDb) {}

  list(schoolId: string) {
    return this.db.query(
      `SELECT t.*,u.name,u.phone,u.email,u.photo_url FROM teachers t JOIN users u ON u.id=t.user_id WHERE t.school_id=$1 AND t.status='active' ORDER BY u.name`,
      [schoolId],
    );
  }

  async create(schoolId: string, data: any) {
    const uid = uuidv4(); const tid = uuidv4();
    const hash = await argon2.hash(data.password || 'Welcome@1234');
    await this.db.query(`INSERT INTO users(id,phone,name,email,password_hash,status) VALUES($1,$2,$3,$4,$5,'active') ON CONFLICT(phone) DO NOTHING`, [uid, data.phone, data.name, data.email, hash]);
    const [user] = await this.db.query(`SELECT id FROM users WHERE phone=$1`, [data.phone]);
    await this.db.query(`INSERT INTO teachers(id,school_id,user_id,employee_code,designation,subjects) VALUES($1,$2,$3,$4,$5,$6) ON CONFLICT(school_id,user_id) DO NOTHING`, [tid, schoolId, user.id, data.employeeCode, data.designation, data.subjects]);
    const [t] = await this.db.query(`SELECT id FROM teachers WHERE school_id=$1 AND user_id=$2`, [schoolId, user.id]);
    await this.db.query(`INSERT INTO user_roles(id,user_id,school_id,role,linked_entity_id) VALUES($1,$2,$3,'teacher',$4) ON CONFLICT DO NOTHING`, [uuidv4(), user.id, schoolId, t.id]);
    return t;
  }
}
