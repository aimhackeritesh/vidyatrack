import { Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { tenantAls } from './tenant-context';

/**
 * Tenant-aware database access. When a request is running inside the
 * TenantContextInterceptor's transaction, queries run on that connection — the
 * one with app.current_school_id / app.current_role set, so Postgres RLS
 * enforces tenant isolation. Outside a tenant context (e.g. the public auth
 * endpoints, which only touch non-tenant tables) it falls back to the pool.
 *
 * Drop-in replacement for the bits of DataSource the services use: `.query()`.
 */
@Injectable()
export class TenantDb {
  constructor(@InjectDataSource() private readonly dataSource: DataSource) {}

  query<T = any>(sql: string, params?: any[]): Promise<T> {
    const runner = tenantAls.getStore()?.queryRunner;
    return (runner ?? this.dataSource).query(sql, params);
  }
}
