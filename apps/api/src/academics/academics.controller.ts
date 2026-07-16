import { Body, Controller, Delete, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { AcademicsService } from './academics.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { Roles, RolesGuard } from '../common/guards/roles.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('academics')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('academics')
export class AcademicsController {
  constructor(private readonly svc: AcademicsService) {}

  // Homework
  @Post('homework') @Roles('admin', 'teacher') @ApiOperation({ summary: 'Create homework for a section' })
  createHomework(@CurrentUser() u: any, @Body() dto: any) { return this.svc.createHomework(u.schoolId, u.id, dto); }
  @Get('homework') @Roles('admin', 'teacher') homeworkForSection(@CurrentUser() u: any, @Query('sectionId') sectionId: string) { return this.svc.listHomeworkForSection(u.schoolId, sectionId); }
  @Get('homework/my') @Roles('student', 'parent') myHomework(@CurrentUser() u: any) { return this.svc.listHomeworkForViewer(u.schoolId, u); }

  // Study material
  @Post('materials') @Roles('admin', 'teacher') createMaterial(@CurrentUser() u: any, @Body() dto: any) { return this.svc.createMaterial(u.schoolId, u.id, dto); }
  @Get('materials') @Roles('admin', 'teacher', 'student', 'parent') materials(@CurrentUser() u: any, @Query('classId') classId?: string, @Query('subject') subject?: string) { return this.svc.listMaterials(u.schoolId, classId, subject); }
  @Get('materials/my') @Roles('student', 'parent') myMaterials(@CurrentUser() u: any) { return this.svc.listMaterialsForViewer(u.schoolId, u); }
  @Delete('materials/:id') @Roles('admin', 'teacher') deleteMaterial(@CurrentUser() u: any, @Param('id') id: string) { return this.svc.deleteMaterial(u.schoolId, u.id, u.role, id); }

  // Exams & results
  @Post('exams') @Roles('admin', 'teacher') createExam(@CurrentUser() u: any, @Body() dto: any) { return this.svc.createExam(u.schoolId, dto); }
  @Get('exams') @Roles('admin', 'teacher', 'student', 'parent') exams(@CurrentUser() u: any, @Query('classId') classId?: string) { return this.svc.listExams(u.schoolId, classId); }
  @Post('results') @Roles('admin', 'teacher') @ApiOperation({ summary: 'Bulk marks entry for an exam' })
  enterResults(@CurrentUser() u: any, @Body() dto: any) { return this.svc.enterResults(u.schoolId, dto.examId, dto.records); }
  @Get('results/my') @Roles('student', 'parent') myResults(@CurrentUser() u: any, @Query('examId') examId?: string) { return this.svc.getMyResults(u.schoolId, u, examId); }
  @Get('results/student/:studentId') @Roles('admin', 'teacher', 'student', 'parent') studentResults(@CurrentUser() u: any, @Param('studentId') studentId: string, @Query('examId') examId?: string) { return this.svc.getStudentResults(u.schoolId, u, studentId, examId); }

  // Timetable
  @Post('timetable') @Roles('admin') @ApiOperation({ summary: 'Upsert one timetable slot' })
  upsertTimetableSlot(@CurrentUser() u: any, @Body() dto: any) { return this.svc.upsertTimetableSlot(u.schoolId, dto); }

  @Post('timetable/bulk') @Roles('admin') @ApiOperation({ summary: "Replace a section's whole week in one save" })
  bulkSetTimetable(@CurrentUser() u: any, @Body() dto: any) { return this.svc.bulkSetTimetable(u.schoolId, dto.sectionId, dto.slots); }

  @Get('timetable') @Roles('admin', 'teacher') timetable(@CurrentUser() u: any, @Query('sectionId') sectionId: string) { return this.svc.listTimetable(u.schoolId, sectionId); }
  @Get('timetable/my') @Roles('student', 'parent') myTimetable(@CurrentUser() u: any) { return this.svc.listTimetableForViewer(u.schoolId, u); }
  @Get('timetable/my-teaching') @Roles('teacher') myTeachingTimetable(@CurrentUser() u: any) { return this.svc.listTimetableForTeacher(u.schoolId, u.id); }
  @Delete('timetable/:id') @Roles('admin') deleteTimetableSlot(@CurrentUser() u: any, @Param('id') id: string) { return this.svc.deleteTimetableSlot(u.schoolId, id); }

  // Syllabus
  @Post('syllabus') @Roles('admin', 'teacher') @ApiOperation({ summary: 'Upsert syllabus for a class+subject' })
  upsertSyllabus(@CurrentUser() u: any, @Body() dto: any) { return this.svc.upsertSyllabus(u.schoolId, dto); }
  @Get('syllabus') @Roles('admin', 'teacher', 'student', 'parent') syllabus(@CurrentUser() u: any, @Query('classId') classId?: string) { return this.svc.listSyllabus(u.schoolId, classId); }
  @Get('syllabus/my') @Roles('student', 'parent') mySyllabus(@CurrentUser() u: any) { return this.svc.listSyllabusForViewer(u.schoolId, u); }
  @Delete('syllabus/:id') @Roles('admin') deleteSyllabus(@CurrentUser() u: any, @Param('id') id: string) { return this.svc.deleteSyllabus(u.schoolId, id); }
}
