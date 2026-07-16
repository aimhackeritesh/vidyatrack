import { Injectable, NotFoundException } from '@nestjs/common';
import { TenantDb } from '../common/database/tenant-db.service';

@Injectable()
export class SchoolsService {
  constructor(private readonly db: TenantDb) {}

  async getProfile(schoolId: string) {
    const [s] = await this.db.query(`SELECT * FROM schools WHERE id=$1`, [schoolId]);
    if (!s) throw new NotFoundException('School not found');
    return s;
  }

  async updateProfile(schoolId: string, data: any) {
    const allowed = ['name','principal_name','email','phone','address','city','state','logo_url'];
    const sets = Object.keys(data).filter(k => allowed.includes(k)).map((k,i) => `${k}=$${i+2}`).join(',');
    if (!sets) return this.getProfile(schoolId);
    const vals = Object.keys(data).filter(k => allowed.includes(k)).map(k => data[k]);
    await this.db.query(`UPDATE schools SET ${sets},updated_at=NOW() WHERE id=$1`, [schoolId, ...vals]);
    return this.getProfile(schoolId);
  }
}
