import { Inject, Injectable, Logger } from '@nestjs/common';
import { Redis } from 'ioredis';
import { createHash } from 'crypto';
import { TenantDb } from '../common/database/tenant-db.service';
import { REDIS_CLIENT } from '../common/redis/redis.module';
import {
  LEGACY_KEY_MAP,
  SETTINGS_REGISTRY,
  SettingDef,
  coerceSetting,
  getSettingDef,
} from './settings-registry';

export type ResolvedConfig = {
  /** Typed setting values, keyed by registry key. Always complete — defaults fill the gaps. */
  settings: Record<string, unknown>;
  /** Stable hash of `settings`; clients cache against it and skip re-parsing when unchanged. */
  version: string;
};

const CACHE_PREFIX = 'school_config:';
const CACHE_TTL_SECONDS = 300;

/**
 * Resolves a school's effective configuration: registry defaults with that
 * school's `school_settings` overrides applied on top.
 *
 * Reads go through TenantDb, so RLS governs them exactly like every other query
 * — a school role can only ever resolve its own school, and a superadmin context
 * can cross tenants. The Redis layer is a cache only: keyed per school and
 * strictly optional, so a Redis outage degrades to a DB read rather than a 500.
 *
 * Unknown keys sitting in the table are ignored on read (forward-compatible with
 * older/newer deployments); writes are validated against the registry.
 */
@Injectable()
export class SchoolConfigService {
  private readonly logger = new Logger(SchoolConfigService.name);

  constructor(
    private readonly db: TenantDb,
    @Inject(REDIS_CLIENT) private readonly redis: Redis,
  ) {}

  /** Full effective config for a school, plus a version hash. */
  async resolve(schoolId: string): Promise<ResolvedConfig> {
    const overrides = await this.loadOverrides(schoolId);
    const settings: Record<string, unknown> = {};

    for (const def of SETTINGS_REGISTRY) {
      const stored = this.pickStored(def, overrides);
      settings[def.key] = coerceSetting(def, stored ?? def.default);
    }

    return { settings, version: hashSettings(settings) };
  }

  /** One typed setting. Cheap — `resolve` is cached, so this is a map lookup in the common case. */
  async get<T = unknown>(schoolId: string, key: string): Promise<T> {
    const def = getSettingDef(key);
    if (!def) throw new Error(`Unknown setting key: ${key} (add it to settings-registry.ts)`);
    const { settings } = await this.resolve(schoolId);
    return settings[key] as T;
  }

  async getInt(schoolId: string, key: string): Promise<number> {
    return this.get<number>(schoolId, key);
  }

  async getBool(schoolId: string, key: string): Promise<boolean> {
    return this.get<boolean>(schoolId, key);
  }

  /** Drop a school's cached overrides. Call after any settings write. */
  async invalidate(schoolId: string): Promise<void> {
    try {
      await this.redis.del(CACHE_PREFIX + schoolId);
    } catch (err) {
      this.logger.warn(`Config cache invalidate failed for ${schoolId}: ${(err as Error).message}`);
    }
  }

  /** The catalog UIs render from, so no client hardcodes labels, types or ranges. */
  getRegistry(): readonly SettingDef[] {
    return SETTINGS_REGISTRY;
  }

  /**
   * Raw override rows for a school, Redis-cached. Cache misses and Redis errors
   * both fall through to Postgres — never fatal.
   */
  private async loadOverrides(schoolId: string): Promise<Record<string, string>> {
    const cacheKey = CACHE_PREFIX + schoolId;
    try {
      const cached = await this.redis.get(cacheKey);
      if (cached) return JSON.parse(cached) as Record<string, string>;
    } catch (err) {
      this.logger.warn(`Config cache read failed for ${schoolId}: ${(err as Error).message}`);
    }

    const rows: { key: string; value: string }[] = await this.db.query(
      `SELECT key, value FROM school_settings WHERE school_id=$1`,
      [schoolId],
    );
    const overrides = Object.fromEntries(rows.map((r) => [r.key, r.value]));

    try {
      await this.redis.set(cacheKey, JSON.stringify(overrides), 'EX', CACHE_TTL_SECONDS);
    } catch (err) {
      this.logger.warn(`Config cache write failed for ${schoolId}: ${(err as Error).message}`);
    }
    return overrides;
  }

  /**
   * Namespaced key wins; an un-namespaced legacy row is honoured as a fallback so
   * schools configured before the registry existed keep their setting until the
   * next edit rewrites it under the new key.
   */
  private pickStored(def: SettingDef, overrides: Record<string, string>): string | undefined {
    const direct = overrides[def.key];
    if (direct !== undefined) return direct;
    if (def.legacyKey && overrides[def.legacyKey] !== undefined) return overrides[def.legacyKey];
    return undefined;
  }
}

/** Order-independent hash of the resolved values, so the version only moves when a value does. */
function hashSettings(settings: Record<string, unknown>): string {
  const canonical = Object.keys(settings)
    .sort()
    .map((k) => `${k}=${JSON.stringify(settings[k])}`)
    .join('\n');
  return createHash('sha1').update(canonical).digest('hex').slice(0, 12);
}

/** Re-exported so consumers can log/report which legacy keys are still in play. */
export const legacyKeys = () => [...LEGACY_KEY_MAP.keys()];
