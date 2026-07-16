import { IsString, IsNotEmpty, IsOptional, Length, Matches } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class SendOtpDto {
  @ApiProperty({ example: 'VDTRK2627DEMO01' })
  @IsString() @IsNotEmpty()
  schoolCode: string;

  @ApiProperty({ example: '9999900001' })
  @IsString() @Length(10, 15)
  @Matches(/^[6-9]\d{9}$/, { message: 'Invalid Indian mobile number' })
  phone: string;
}

export class VerifyOtpDto extends SendOtpDto {
  @ApiProperty({ example: '123456' })
  @IsString() @Length(6, 6)
  otp: string;
}

export class LoginPasswordDto {
  @ApiProperty() @IsString() @IsNotEmpty() schoolCode: string;
  // One of phone (parents/staff) or loginId (STU-/PAR- generated accounts).
  @ApiPropertyOptional() @IsOptional() @IsString() @Length(10, 15) phone?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() loginId?: string;
  @ApiProperty() @IsString() @IsNotEmpty() password: string;
}

export class RefreshTokenDto {
  @ApiProperty() @IsString() @IsNotEmpty() refreshToken: string;
}

export class ChangePasswordDto {
  @ApiProperty() @IsString() @IsNotEmpty() oldPassword: string;
  @ApiProperty() @IsString() @Length(8, 64) newPassword: string;
}

export class SelectRoleDto {
  @ApiProperty() @IsString() @IsNotEmpty() userRoleId: string;
}
