import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { NotificationsService } from './notifications.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { Roles, RolesGuard } from '../common/guards/roles.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

const ALL = ['admin', 'teacher', 'parent', 'student'];

@ApiTags('notifications')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly svc: NotificationsService) {}

  // Notices
  @Post('notices') @Roles('admin') send(@CurrentUser() u: any, @Body() dto: any) { return this.svc.sendNotice(u.schoolId, u.id, dto); }
  @Get('notices') @Roles(...ALL) list(@CurrentUser() u: any, @Query('page') page = 1) { return this.svc.getNotices(u.schoolId, page); }

  // Circulars
  @Post('circulars') @Roles('admin') @ApiOperation({ summary: 'Publish a circular (PDF/image) to an audience' })
  createCircular(@CurrentUser() u: any, @Body() dto: any) { return this.svc.createCircular(u.schoolId, u.id, dto); }
  @Get('circulars') @Roles(...ALL) listCirculars(@CurrentUser() u: any, @Query('page') page = 1) { return this.svc.listCirculars(u.schoolId, page); }

  // Messages (broadcast → notification fan-out)
  @Post('messages') @Roles('admin') @ApiOperation({ summary: 'Broadcast a message to an audience' })
  sendMessage(@CurrentUser() u: any, @Body() dto: any) { return this.svc.sendMessage(u.schoolId, u.id, dto); }

  // Suggestions
  @Post('suggestions') @Roles(...ALL) suggest(@CurrentUser() u: any, @Body('body') body: string) { return this.svc.submitSuggestion(u.schoolId, u.id, body); }
  @Get('suggestions') @Roles('admin') suggestions(@CurrentUser() u: any, @Query('status') status = 'open') { return this.svc.listSuggestions(u.schoolId, status); }
  @Post('suggestions/:id/reply') @Roles('admin') replySuggestion(@CurrentUser() u: any, @Param('id') id: string, @Body('reply') reply: string) { return this.svc.replySuggestion(u.schoolId, u.id, id, reply); }

  // Leave requests
  @Post('leave') @Roles('teacher', 'parent', 'student') @ApiOperation({ summary: 'Apply for leave (teacher self, parent for child, student self)' })
  applyLeave(@CurrentUser() u: any, @Body() dto: any) { return this.svc.applyLeave(u.schoolId, u, dto); }
  @Get('leave') @Roles('admin') leaves(@CurrentUser() u: any, @Query('status') status = 'pending') { return this.svc.listLeaves(u.schoolId, status); }
  @Post('leave/:id/act') @Roles('admin') @ApiOperation({ summary: 'Approve/reject a leave request (notifies the applicant)' })
  actLeave(@CurrentUser() u: any, @Param('id') id: string, @Body() dto: any) { return this.svc.actLeave(u.schoolId, u.id, id, dto.approve === true, dto.note); }
}
