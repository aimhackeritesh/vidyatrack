import { Global, Module } from '@nestjs/common';
import { APP_INTERCEPTOR } from '@nestjs/core';
import { TenantDb } from './tenant-db.service';
import { TenantContextInterceptor } from './tenant.interceptor';

/**
 * Wires up tenant-aware DB access app-wide: the TenantDb wrapper that services
 * inject, plus the global interceptor that binds an RLS session to each
 * authenticated request.
 */
@Global()
@Module({
  providers: [
    TenantDb,
    { provide: APP_INTERCEPTOR, useClass: TenantContextInterceptor },
  ],
  exports: [TenantDb],
})
export class DatabaseModule {}
