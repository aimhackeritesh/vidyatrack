import { Module } from '@nestjs/common';
import { AttendanceController } from './attendance.controller';
import { AttendanceService } from './attendance.service';
import { SchoolConfigModule } from '../config/school-config.module';

@Module({ imports: [SchoolConfigModule], controllers: [AttendanceController], providers: [AttendanceService] })
export class AttendanceModule {}
