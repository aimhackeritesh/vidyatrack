import { CallHandler, ExecutionContext, Injectable, NestInterceptor } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { Observable, from, lastValueFrom } from 'rxjs';
import { tenantAls } from './tenant-context';

/**
 * For authenticated requests, opens a single transaction-bound connection, sets
 * the RLS session variables on it, and runs the whole handler against that
 * connection via AsyncLocalStorage. Commits on success, rolls back on error.
 *
 * This is what makes RLS sound: the GUC and the data queries share one
 * connection, instead of the GUC being set on an arbitrary pooled connection
 * that the handler's queries might never touch.
 *
 * Public routes (no req.user) pass straight through on the pool.
 */
@Injectable()
export class TenantContextInterceptor implements NestInterceptor {
  constructor(@InjectDataSource() private readonly dataSource: DataSource) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const req = context.switchToHttp().getRequest();
    const user = req?.user;
    // Platform owner: open a context flagged superadmin (no school) so the RLS
    // superadmin bypass lets them read/write across every tenant.
    if (user?.role === 'superadmin') return from(this.runInTenantContext('', 'superadmin', next));
    if (!user?.schoolId) return next.handle();
    return from(this.runInTenantContext(user.schoolId, user.role, next));
  }

  private async runInTenantContext(
    schoolId: string,
    role: string,
    next: CallHandler,
  ): Promise<any> {
    const qr = this.dataSource.createQueryRunner();
    await qr.connect();
    await qr.startTransaction();
    try {
      // set_config(..., is_local => true) == SET LOCAL, scoped to this tx.
      await qr.query(`SELECT set_config('app.current_school_id', $1, true)`, [schoolId]);
      await qr.query(`SELECT set_config('app.current_role', $1, true)`, [role ?? '']);

      const result = await tenantAls.run({ queryRunner: qr }, () =>
        lastValueFrom(next.handle()),
      );

      await qr.commitTransaction();
      return result;
    } catch (err) {
      await qr.rollbackTransaction();
      throw err;
    } finally {
      await qr.release();
    }
  }
}
