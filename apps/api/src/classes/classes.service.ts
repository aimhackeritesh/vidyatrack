import { Injectable } from '@nestjs/common';
import { TenantDb } from '../common/database/tenant-db.service';
import { v4 as uuidv4 } from 'uuid';

@Injectable()
export class ClassesService {
  constructor(private readonly db: TenantDb) {}

  listClasses(schoolId: string) {
    return this.db.query(`SELECT * FROM classes WHERE school_id=$1 ORDER BY order_no`, [schoolId]);
  }

  async listSections(schoolId: string, classId?: string) {
    if (classId) return this.db.query(`SELECT s.*, c.name as class_name FROM sections s JOIN classes c ON c.id=s.class_id WHERE s.school_id=$1 AND s.class_id=$2 ORDER BY s.name`, [schoolId, classId]);
    return this.db.query(`SELECT s.*, c.name as class_name FROM sections s JOIN classes c ON c.id=s.class_id WHERE s.school_id=$1 ORDER BY c.order_no, s.name`, [schoolId]);
  }

  async createClass(schoolId: string, name: string, orderNo = 0) {
    const id = uuidv4();
    await this.db.query(`INSERT INTO classes(id,school_id,name,order_no) VALUES($1,$2,$3,$4) ON CONFLICT(school_id,name) DO NOTHING`, [id, schoolId, name, orderNo]);
    const [cls] = await this.db.query(`SELECT * FROM classes WHERE school_id=$1 AND name=$2`, [schoolId, name]);
    return cls;
  }

  async createSection(schoolId: string, classId: string, name: string) {
    const id = uuidv4();
    await this.db.query(`INSERT INTO sections(id,class_id,school_id,name) VALUES($1,$2,$3,$4) ON CONFLICT(class_id,name) DO NOTHING`, [id, classId, schoolId, name]);
    const [sec] = await this.db.query(`SELECT * FROM sections WHERE class_id=$1 AND name=$2`, [classId, name]);
    return sec;
  }
}
