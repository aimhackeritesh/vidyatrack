import { Body, Controller, Delete, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { AttendanceService } from './attendance.service';
import { SubmitAttendanceDto, GetAttendanceQuery } from './dto/attendance.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { Roles, RolesGuard } from '../common/guards/roles.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('attendance')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('attendance')
export class AttendanceController {
  constructor(private readonly svc: AttendanceService) {}

  @Post('sessions')
  @Roles('admin', 'teacher')
  @ApiOperation({ summary: 'Bulk submit attendance for a section (single call for all students)' })
  submit(@CurrentUser() user: any, @Body() dto: SubmitAttendanceDto) {
    return this.svc.submitAttendance(user.id, user.schoolId, user.role, dto);
  }

  @Get('section')
  @Roles('admin', 'teacher')
  @ApiOperation({ summary: 'Get student roster with attendance status for a section+date' })
  getSectionAttendance(
    @CurrentUser() user: any,
    @Query('sectionId') sectionId: string,
    @Query('date') date: string,
  ) {
    return this.svc.getSectionAttendance(user.schoolId, sectionId, date);
  }

  @Get('report')
  @Roles('admin', 'teacher')
  @ApiOperation({ summary: 'Admin/teacher: attendance report with filters' })
  report(@CurrentUser() user: any, @Query() q: GetAttendanceQuery) {
    return this.svc.getAdminReport(user.schoolId, q);
  }

  @Get('dashboard')
  @Roles('admin')
  @ApiOperation({ summary: 'Last-7-days chart data for admin dashboard' })
  dashboard(@CurrentUser() user: any) {
    return this.svc.getDashboardChart(user.schoolId);
  }

  @Get('me')
  @Roles('parent', 'student')
  @ApiOperation({ summary: "Caller's own/child monthly attendance (calendar + %)" })
  myMonth(@CurrentUser() user: any, @Query('month') month?: string) {
    return this.svc.getMyMonth(user.schoolId, user, month);
  }

  @Get('student/:studentId')
  @Roles('admin', 'teacher', 'parent', 'student')
  @ApiOperation({ summary: "A student's monthly attendance (ownership enforced for parent/student)" })
  studentMonth(@CurrentUser() user: any, @Param('studentId') studentId: string, @Query('month') month?: string) {
    return this.svc.getStudentMonth(user.schoolId, user, studentId, month);
  }

  // ── Holidays ──
  @Get('holidays')
  @Roles('admin', 'teacher', 'parent', 'student')
  holidays(@CurrentUser() u: any, @Query('from') from?: string, @Query('to') to?: string) {
    return this.svc.listHolidays(u.schoolId, from, to);
  }

  @Post('holidays')
  @Roles('admin')
  @ApiOperation({ summary: 'Mark a date as a holiday (excluded from attendance %)' })
  setHoliday(@CurrentUser() u: any, @Body() dto: any) { return this.svc.setHoliday(u.schoolId, dto.date, dto.name); }

  @Delete('holidays/:id')
  @Roles('admin')
  deleteHoliday(@CurrentUser() u: any, @Param('id') id: string) { return this.svc.deleteHoliday(u.schoolId, id); }

  // ── Defaulters report ──
  @Get('defaulters')
  @Roles('admin', 'teacher')
  @ApiOperation({ summary: 'Students below an attendance threshold (default 75%)' })
  defaulters(@CurrentUser() u: any, @Query('threshold') threshold?: string, @Query('month') month?: string) {
    return this.svc.getDefaulters(u.schoolId, threshold ? Number(threshold) : 75, month);
  }
}
