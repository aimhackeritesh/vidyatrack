import { Body, Controller, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { StudentsService } from './students.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { Roles, RolesGuard } from '../common/guards/roles.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('students')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('students')
export class StudentsController {
  constructor(private readonly svc: StudentsService) {}
  @Get() @Roles('admin', 'teacher') list(@CurrentUser() u: any, @Query() q: any) { return this.svc.list(u.schoolId, q); }
  @Get('search') @Roles('admin', 'teacher') search(@CurrentUser() u: any, @Query('q') q: string) { return this.svc.search(u.schoolId, q); }
  @Get(':id') @Roles('admin', 'teacher') get(@CurrentUser() u: any, @Param('id') id: string) { return this.svc.findById(u.schoolId, id); }

  @Post()
  @Roles('admin', 'teacher')
  @ApiOperation({ summary: 'Create a student; auto-generates Student + Parent logins and returns one-time credentials' })
  create(@CurrentUser() u: any, @Body() dto: any) { return this.svc.create(u.schoolId, u.id, dto); }

  @Patch(':id') @Roles('admin') update(@CurrentUser() u: any, @Param('id') id: string, @Body() dto: any) { return this.svc.update(u.schoolId, u.id, id, dto); }

  @Post(':id/deactivate')
  @Roles('admin')
  @ApiOperation({ summary: 'Soft-remove a student (status=inactive) with a reason' })
  deactivate(@CurrentUser() u: any, @Param('id') id: string, @Body('reason') reason: string) { return this.svc.deactivate(u.schoolId, u.id, id, reason ?? ''); }

  @Post(':id/reset-credentials')
  @Roles('admin')
  @ApiOperation({ summary: 'Regenerate Student/Parent temp passwords and return a fresh credential slip' })
  reset(@CurrentUser() u: any, @Param('id') id: string) { return this.svc.resetCredentials(u.schoolId, u.id, id); }

  @Post('bulk-import')
  @Roles('admin')
  @ApiOperation({ summary: 'Bulk-create students from parsed CSV rows; returns batch credentials + per-row errors' })
  bulkImport(@CurrentUser() u: any, @Body() dto: any) { return this.svc.bulkImport(u.schoolId, u.id, dto.rows, dto.dryRun); }
}
