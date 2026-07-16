import { Injectable } from '@nestjs/common';
import { TenantDb } from '../common/database/tenant-db.service';

@Injectable()
export class UsersService {
  constructor(private readonly db: TenantDb) {}

  async getNotifications(userId: string, schoolId: string, page = 1) {
    const limit = 20; const offset = (page - 1) * limit;
    return this.db.query(
      `SELECT * FROM notifications WHERE user_id=$1 AND school_id=$2 ORDER BY created_at DESC LIMIT $3 OFFSET $4`,
      [userId, schoolId, limit, offset],
    );
  }

  async markRead(userId: string, notificationId: string) {
    await this.db.query(`UPDATE notifications SET read_at=NOW() WHERE id=$1 AND user_id=$2`, [notificationId, userId]);
    return { message: 'Marked read' };
  }

  async unreadCount(userId: string, schoolId: string) {
    const [r] = await this.db.query(
      `SELECT COUNT(*) as count FROM notifications WHERE user_id=$1 AND school_id=$2 AND read_at IS NULL`,
      [userId, schoolId],
    );
    return { count: parseInt(r.count) };
  }
}
