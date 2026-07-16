import { Body, Controller, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { SuperAdminService } from './superadmin.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { Roles, RolesGuard } from '../common/guards/roles.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('superadmin')
@Controller('superadmin')
export class SuperAdminController {
  constructor(private readonly svc: SuperAdminService) {}

  @Post('login')
  @ApiOperation({ summary: 'Platform owner login (separate auth realm)' })
  login(@Body() dto: any) { return this.svc.login(dto.email, dto.password); }

  @Get('schools')
  @UseGuards(JwtAuthGuard, RolesGuard) @Roles('superadmin') @ApiBearerAuth()
  schools() { return this.svc.listSchools(); }

  @Post('schools')
  @UseGuards(JwtAuthGuard, RolesGuard) @Roles('superadmin') @ApiBearerAuth()
  @ApiOperation({ summary: 'Create a school + its first Admin (principal); returns a credential slip' })
  createSchool(@CurrentUser() u: any, @Body() dto: any) { return this.svc.createSchool(u.id, dto); }

  @Post('schools/:id/suspend')
  @UseGuards(JwtAuthGuard, RolesGuard) @Roles('superadmin') @ApiBearerAuth()
  suspend(@CurrentUser() u: any, @Param('id') id: string) { return this.svc.setStatus(u.id, id, 'suspended'); }

  @Post('schools/:id/activate')
  @UseGuards(JwtAuthGuard, RolesGuard) @Roles('superadmin') @ApiBearerAuth()
  activate(@CurrentUser() u: any, @Param('id') id: string) { return this.svc.setStatus(u.id, id, 'active'); }

  @Patch('schools/:id/limits')
  @UseGuards(JwtAuthGuard, RolesGuard) @Roles('superadmin') @ApiBearerAuth()
  limits(@CurrentUser() u: any, @Param('id') id: string, @Body() dto: any) { return this.svc.setLimits(u.id, id, dto); }

  @Post('schools/:id/reset-principal')
  @UseGuards(JwtAuthGuard, RolesGuard) @Roles('superadmin') @ApiBearerAuth()
  resetPrincipal(@CurrentUser() u: any, @Param('id') id: string) { return this.svc.resetPrincipal(u.id, id); }

  @Get('analytics')
  @UseGuards(JwtAuthGuard, RolesGuard) @Roles('superadmin') @ApiBearerAuth()
  @ApiOperation({ summary: 'Platform-wide totals: schools, students, users by role, online fee volume, invoices this month' })
  analytics() { return this.svc.getAnalytics(); }

  @Get('schools/:id/stats')
  @UseGuards(JwtAuthGuard, RolesGuard) @Roles('superadmin') @ApiBearerAuth()
  schoolStats(@Param('id') id: string) { return this.svc.getSchoolStats(id); }

  @Get('schools/:id/settings')
  @UseGuards(JwtAuthGuard, RolesGuard) @Roles('superadmin') @ApiBearerAuth()
  getSettings(@Param('id') id: string) { return this.svc.getSchoolSettings(id); }

  @Patch('schools/:id/settings')
  @UseGuards(JwtAuthGuard, RolesGuard) @Roles('superadmin') @ApiBearerAuth()
  @ApiOperation({ summary: 'Toggle a per-school feature flag / fee rule, e.g. {key:"online_payments",value:"true"}' })
  setSetting(@CurrentUser() u: any, @Param('id') id: string, @Body() dto: any) { return this.svc.setSchoolSetting(u.id, id, dto.key, dto.value); }

  @Post('broadcast')
  @UseGuards(JwtAuthGuard, RolesGuard) @Roles('superadmin') @ApiBearerAuth()
  @ApiOperation({ summary: 'Fan a platform notice out to chosen schools (or all) and roles' })
  broadcast(@CurrentUser() u: any, @Body() dto: any) { return this.svc.broadcast(u.id, dto); }

  @Get('audit')
  @UseGuards(JwtAuthGuard, RolesGuard) @Roles('superadmin') @ApiBearerAuth()
  audit(@Query('schoolId') schoolId?: string, @Query('limit') limit?: string) { return this.svc.listAudit(schoolId, limit ? Number(limit) : undefined); }
}
