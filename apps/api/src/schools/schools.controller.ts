import { Body, Controller, Get, Patch, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { SchoolsService } from './schools.service';
import { SchoolConfigService } from '../config/school-config.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { Roles, RolesGuard } from '../common/guards/roles.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('schools')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('schools')
export class SchoolsController {
  constructor(
    private readonly svc: SchoolsService,
    private readonly config: SchoolConfigService,
  ) {}
  @Get('profile') @Roles('admin', 'teacher', 'parent', 'student') getProfile(@CurrentUser() u: any) { return this.svc.getProfile(u.schoolId); }
  @Patch('profile') @Roles('admin') updateProfile(@CurrentUser() u: any, @Body() dto: any) { return this.svc.updateProfile(u.schoolId, dto); }

  /**
   * The client config bootstrap: registry defaults with this school's overrides
   * applied, in one round-trip. Clients cache it against `version` and re-fetch
   * on app start rather than looking settings up per screen.
   */
  @Get('config')
  @Roles('admin', 'teacher', 'parent', 'student')
  @ApiOperation({ summary: "This school's effective settings (defaults + overrides) and a version hash" })
  getConfig(@CurrentUser() u: any) { return this.config.resolve(u.schoolId); }
}
