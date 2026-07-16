import { IsArray, IsDateString, IsEnum, IsNotEmpty, IsOptional, IsString, IsUUID, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export enum AttendanceStatus {
  PRESENT = 'present',
  ABSENT = 'absent',
  LATE = 'late',
  LEAVE = 'leave',
  HOLIDAY = 'holiday',
}

export class AttendanceRecordDto {
  @ApiProperty() @IsUUID() studentId: string;
  @ApiProperty({ enum: AttendanceStatus }) @IsEnum(AttendanceStatus) status: AttendanceStatus;
  @ApiPropertyOptional() @IsOptional() @IsString() remark?: string;
}

export class SubmitAttendanceDto {
  @ApiProperty() @IsUUID() sectionId: string;
  @ApiProperty({ example: '2026-06-11' }) @IsDateString() date: string;
  @ApiPropertyOptional({ enum: ['full_day', 'period'], default: 'full_day' })
  @IsOptional() @IsEnum(['full_day', 'period']) session?: string;

  @ApiProperty({ type: [AttendanceRecordDto] })
  @IsArray() @ValidateNested({ each: true }) @Type(() => AttendanceRecordDto)
  records: AttendanceRecordDto[];
}

export class GetAttendanceQuery {
  @ApiPropertyOptional() @IsOptional() @IsUUID() sectionId?: string;
  @ApiPropertyOptional() @IsOptional() @IsDateString() date?: string;
  @ApiPropertyOptional() @IsOptional() @IsDateString() fromDate?: string;
  @ApiPropertyOptional() @IsOptional() @IsDateString() toDate?: string;
}
