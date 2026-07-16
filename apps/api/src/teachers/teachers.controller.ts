import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { TeachersService } from './teachers.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { Roles, RolesGuard } from '../common/guards/roles.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('teachers')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('teachers')
export class TeachersController {
  constructor(private readonly svc: TeachersService) {}
  // Staff directory is visible to admin + teachers (tap-to-call); editing is admin-only.
  @Get() @Roles('admin', 'teacher') list(@CurrentUser() u: any) { return this.svc.list(u.schoolId); }
  @Post() @Roles('admin') create(@CurrentUser() u: any, @Body() dto: any) { return this.svc.create(u.schoolId, dto); }
}
