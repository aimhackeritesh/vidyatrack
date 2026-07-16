import { Body, Controller, Get, Patch, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { SchoolsService } from './schools.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { Roles, RolesGuard } from '../common/guards/roles.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('schools')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('schools')
export class SchoolsController {
  constructor(private readonly svc: SchoolsService) {}
  @Get('profile') @Roles('admin', 'teacher', 'parent', 'student') getProfile(@CurrentUser() u: any) { return this.svc.getProfile(u.schoolId); }
  @Patch('profile') @Roles('admin') updateProfile(@CurrentUser() u: any, @Body() dto: any) { return this.svc.updateProfile(u.schoolId, dto); }
}
