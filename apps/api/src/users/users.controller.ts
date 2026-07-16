import { Controller, Get, Param, Patch, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { UsersService } from './users.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { Roles, RolesGuard } from '../common/guards/roles.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

const ALL_ROLES = ['admin', 'teacher', 'parent', 'student'];

@ApiTags('users')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('users')
export class UsersController {
  constructor(private readonly svc: UsersService) {}
  // Every signed-in role has their own notification inbox.
  @Get('notifications') @Roles(...ALL_ROLES) notifications(@CurrentUser() u: any, @Query('page') page = 1) { return this.svc.getNotifications(u.id, u.schoolId, page); }
  @Get('notifications/unread-count') @Roles(...ALL_ROLES) unread(@CurrentUser() u: any) { return this.svc.unreadCount(u.id, u.schoolId); }
  @Patch('notifications/:id/read') @Roles(...ALL_ROLES) markRead(@CurrentUser() u: any, @Param('id') id: string) { return this.svc.markRead(u.id, id); }
}
