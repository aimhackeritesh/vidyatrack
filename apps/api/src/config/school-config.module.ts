import { Module } from '@nestjs/common';
import { SchoolConfigService } from './school-config.service';

/**
 * Named SchoolConfigModule, not ConfigModule — `@nestjs/config`'s ConfigModule is
 * already imported globally in app.module.ts and the collision would be a trap.
 *
 * TenantDb (DatabaseModule) and REDIS_CLIENT (RedisModule) are both @Global, so
 * this module only needs to provide and export the service.
 */
@Module({
  providers: [SchoolConfigService],
  exports: [SchoolConfigService],
})
export class SchoolConfigModule {}
