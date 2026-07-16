import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { TenantDb } from '../common/database/tenant-db.service';

export interface JwtPayload {
  sub: string;
  schoolId: string;
  role: string;
  userRoleId: string;
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(cfg: ConfigService, private readonly db: TenantDb) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: cfg.get('JWT_SECRET') || 'default_secret',
    });
  }

  async validate(payload: JwtPayload) {
    // The RLS session variables are set per-request by TenantContextInterceptor,
    // on the same connection the handler's queries run on. Here we only resolve
    // the user (the users table is not tenant-scoped).
    const [user] = await this.db.query(`SELECT id, name, phone, email, photo_url, status FROM users WHERE id=$1`, [payload.sub]);
    if (!user || user.status !== 'active') throw new UnauthorizedException('User not active');
    return { ...user, schoolId: payload.schoolId, role: payload.role, userRoleId: payload.userRoleId };
  }
}
