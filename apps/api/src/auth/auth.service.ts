import {
  BadRequestException, Injectable, NotFoundException,
  UnauthorizedException, Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import * as argon2 from 'argon2';
import { v4 as uuidv4 } from 'uuid';
import { Redis } from 'ioredis';
import { InjectRedis } from '../common/redis/redis.provider';
import { TenantDb } from '../common/database/tenant-db.service';
import { SendOtpDto, VerifyOtpDto, LoginPasswordDto, RefreshTokenDto, ChangePasswordDto } from './dto/auth.dto';

const OTP_TTL = 300;         // 5 minutes
const OTP_MAX_PER_HOUR = 5;

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly db: TenantDb,
    private readonly jwtSvc: JwtService,
    private readonly cfg: ConfigService,
    @InjectRedis() private readonly redis: Redis,
  ) {}

  // ─── OTP flow ──────────────────────────────────────────────────────────────

  async sendOtp(dto: SendOtpDto): Promise<{ message: string }> {
    const school = await this.findSchool(dto.schoolCode);
    const user = await this.findOrCreateUser(school.id, dto.phone);

    const hourKey = `otp_limit:${dto.phone}`;
    const count = await this.redis.incr(hourKey);
    if (count === 1) await this.redis.expire(hourKey, 3600);
    if (count > OTP_MAX_PER_HOUR) throw new BadRequestException('OTP limit exceeded. Try after an hour.');

    const otp = this.generateOtp();
    await this.redis.setex(`otp:${dto.phone}`, OTP_TTL, otp);

    // In dev: log OTP; in prod: fire SMS via provider
    if (this.cfg.get('NODE_ENV') !== 'production') {
      this.logger.log(`[DEV OTP] ${dto.phone} → ${otp}`);
    } else {
      await this.dispatchSms(dto.phone, otp);
    }

    return { message: 'OTP sent successfully' };
  }

  async verifyOtp(dto: VerifyOtpDto): Promise<any> {
    const school = await this.findSchool(dto.schoolCode);
    const stored = await this.redis.get(`otp:${dto.phone}`);
    if (!stored || stored !== dto.otp) throw new UnauthorizedException('Invalid or expired OTP');

    await this.redis.del(`otp:${dto.phone}`);

    const [user] = await this.db.query(`SELECT * FROM users WHERE phone=$1`, [dto.phone]);
    if (!user) throw new UnauthorizedException('User not found');
    return this.buildAuthResponse(user, school.id);
  }

  async loginPassword(dto: LoginPasswordDto): Promise<any> {
    const school = await this.findSchool(dto.schoolCode);

    // Resolve the user by login ID (STU-/PAR- generated accounts, scoped to the
    // school) or by phone (parents/staff).
    let user: any;
    if (dto.loginId) {
      [user] = await this.db.query(
        `SELECT u.* FROM users u JOIN user_roles ur ON ur.user_id=u.id
         WHERE ur.school_id=$1 AND u.login_id=$2 LIMIT 1`,
        [school.id, dto.loginId],
      );
    } else if (dto.phone) {
      [user] = await this.db.query(`SELECT * FROM users WHERE phone=$1`, [dto.phone]);
    } else {
      throw new BadRequestException('Provide a phone number or login ID');
    }

    if (!user || !user.password_hash) throw new UnauthorizedException('Invalid credentials');
    const valid = await argon2.verify(user.password_hash, dto.password);
    if (!valid) throw new UnauthorizedException('Invalid credentials');

    return this.buildAuthResponse(user, school.id);
  }

  async refreshTokens(dto: RefreshTokenDto): Promise<any> {
    try {
      const payload = this.jwtSvc.verify(dto.refreshToken, {
        secret: this.cfg.get('JWT_REFRESH_SECRET'),
      });
      return this.issueTokens(payload.sub, payload.schoolId, payload.role, payload.userRoleId);
    } catch {
      throw new UnauthorizedException('Invalid refresh token');
    }
  }

  async selectRole(userId: string, userRoleId: string): Promise<any> {
    const [ur] = await this.db.query(
      `SELECT ur.*, s.code as school_code, s.name as school_name
       FROM user_roles ur JOIN schools s ON s.id=ur.school_id
       WHERE ur.id=$1 AND ur.user_id=$2`,
      [userRoleId, userId],
    );
    if (!ur) throw new ForbiddenException('Role not found');
    const [user] = await this.db.query(`SELECT must_change_password FROM users WHERE id=$1`, [userId]);
    return {
      ...(await this.issueTokens(userId, ur.school_id, ur.role, ur.id)),
      mustChangePassword: user?.must_change_password === true,
    };
  }

  async changePassword(userId: string, dto: ChangePasswordDto): Promise<{ message: string }> {
    const [user] = await this.db.query(`SELECT * FROM users WHERE id=$1`, [userId]);
    if (!user || !user.password_hash) throw new BadRequestException('Password not set');
    const valid = await argon2.verify(user.password_hash, dto.oldPassword);
    if (!valid) throw new UnauthorizedException('Old password incorrect');
    const hash = await argon2.hash(dto.newPassword);
    // Clears the forced-change flag set on generated credentials.
    await this.db.query(`UPDATE users SET password_hash=$1, must_change_password=false, updated_at=NOW() WHERE id=$2`, [hash, userId]);
    return { message: 'Password changed' };
  }

  // ─── helpers ───────────────────────────────────────────────────────────────

  private async findSchool(code: string) {
    const [school] = await this.db.query(`SELECT * FROM schools WHERE code=$1 AND status='active'`, [code]);
    if (!school) throw new NotFoundException('School not found or inactive');
    return school;
  }

  private async findOrCreateUser(schoolId: string, phone: string) {
    const [existing] = await this.db.query(`SELECT * FROM users WHERE phone=$1`, [phone]);
    if (existing) return existing;
    const id = uuidv4();
    await this.db.query(
      `INSERT INTO users(id,phone,name,status) VALUES($1,$2,'New User','active')`,
      [id, phone],
    );
    return { id, phone };
  }

  private async buildAuthResponse(user: any, schoolId: string) {
    const roles = await this.db.query(
      `SELECT ur.*, s.name as school_name, s.code as school_code
       FROM user_roles ur JOIN schools s ON s.id=ur.school_id
       WHERE ur.user_id=$1 AND ur.school_id=$2`,
      [user.id, schoolId],
    );

    const mustChangePassword = user.must_change_password === true;

    if (roles.length === 0) throw new UnauthorizedException('No role assigned at this school');
    if (roles.length === 1) {
      return {
        requiresRoleSelection: false,
        ...(await this.issueTokens(user.id, schoolId, roles[0].role, roles[0].id)),
        mustChangePassword,
        user: this.sanitizeUser(user),
      };
    }

    // multiple roles — client must call /auth/select-role
    return {
      requiresRoleSelection: true,
      userId: user.id,
      roles: roles.map((r) => ({ id: r.id, role: r.role, schoolName: r.school_name })),
      mustChangePassword,
      user: this.sanitizeUser(user),
    };
  }

  private async issueTokens(userId: string, schoolId: string, role: string, userRoleId: string) {
    const payload = { sub: userId, schoolId, role, userRoleId };
    const accessToken = this.jwtSvc.sign(payload, {
      secret: this.cfg.get('JWT_SECRET'),
      expiresIn: this.cfg.get('JWT_EXPIRES_IN') || '15m',
    });
    const refreshToken = this.jwtSvc.sign(payload, {
      secret: this.cfg.get('JWT_REFRESH_SECRET'),
      expiresIn: this.cfg.get('JWT_REFRESH_EXPIRES_IN') || '30d',
    });
    return { accessToken, refreshToken, role, schoolId, userRoleId };
  }

  private sanitizeUser(u: any) {
    return { id: u.id, name: u.name, phone: u.phone, email: u.email, photoUrl: u.photo_url };
  }

  private generateOtp(): string {
    return String(Math.floor(100000 + Math.random() * 900000));
  }

  private async dispatchSms(phone: string, otp: string) {
    // TODO: integrate MSG91 / Gupshup with DLT template
    this.logger.log(`SMS dispatch to ${phone}: Your VidyaTrack OTP is ${otp}. Valid 5 min.`);
  }
}

// missing import fix
import { ForbiddenException } from '@nestjs/common';
