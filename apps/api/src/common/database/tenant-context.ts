import { AsyncLocalStorage } from 'node:async_hooks';
import { QueryRunner } from 'typeorm';

export interface TenantStore {
  queryRunner: QueryRunner;
}

// Holds the per-request, GUC-bound QueryRunner that TenantContextInterceptor
// opens, so TenantDb can route every query in the request onto that same
// connection (where app.current_school_id / app.current_role are set).
export const tenantAls = new AsyncLocalStorage<TenantStore>();
