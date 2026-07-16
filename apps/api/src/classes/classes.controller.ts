import { Body, Controller, Get, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { ClassesService } from './classes.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { Roles, RolesGuard } from '../common/guards/roles.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('classes')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('classes')
export class ClassesController {
  constructor(private readonly svc: ClassesService) {}
  @Get() @Roles('admin', 'teacher') list(@CurrentUser() u: any) { return this.svc.listClasses(u.schoolId); }
  @Get('sections') @Roles('admin', 'teacher') sections(@CurrentUser() u: any, @Query('classId') cid?: string) { return this.svc.listSections(u.schoolId, cid); }
  @Post() @Roles('admin') create(@CurrentUser() u: any, @Body() b: any) { return this.svc.createClass(u.schoolId, b.name, b.orderNo); }
  @Post('sections') @Roles('admin') createSection(@CurrentUser() u: any, @Body() b: any) { return this.svc.createSection(u.schoolId, b.classId, b.name); }
}
