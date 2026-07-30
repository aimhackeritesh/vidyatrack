/**
 * The school settings registry — the single source of truth for every
 * school-variable behaviour in VidyaTrack.
 *
 * Storage stays the existing `school_settings` table (key/value TEXT, RLS'd), so
 * this file adds *meaning* on top of it: types, defaults, labels, validation and
 * a catalog UIs can render. Adding new per-school variability should cost one
 * entry here — not a migration and not an app release.
 *
 * Deliberately framework-free (no Nest imports) so it can be unit-tested and
 * imported from scripts. Validation returns a result; callers raise the HTTP
 * error.
 */

export type SettingType = 'int' | 'bool' | 'string' | 'enum' | 'time' | 'json' | 'color';

export type SettingCategory =
  | 'academic'
  | 'attendance'
  | 'fees'
  | 'timetable'
  | 'grading'
  | 'branding'
  | 'locale'
  | 'features';

export type SettingDef = {
  /** Namespaced key, e.g. 'timetable.periods_per_day'. */
  key: string;
  type: SettingType;
  /** Stored (string) form of the default; typed on read. */
  default: string;
  label: string;
  description: string;
  category: SettingCategory;
  /** 'admin' = the school can self-serve it; 'superadmin' = platform owner only. */
  editableBy: 'superadmin' | 'admin';
  enumValues?: string[];
  min?: number;
  max?: number;
  /**
   * An older un-namespaced key that may still hold this value in live data.
   * Read as a fallback when the namespaced key has no row; writes always use
   * the namespaced key, so a school migrates the first time it's edited.
   */
  legacyKey?: string;
  /**
   * Whether a consumer actually reads this setting in the current release.
   * Settings ship declared-but-unwired on purpose (the data model is ready
   * before the UI is), and editing surfaces should say so rather than let the
   * owner change a value and wonder why nothing happened.
   */
  consumed: boolean;
};

export const SETTINGS_REGISTRY: readonly SettingDef[] = [
  // ── Academic ───────────────────────────────────────────────────────────────
  {
    key: 'academic.year_start_month',
    type: 'int',
    default: '4',
    min: 1,
    max: 12,
    label: 'Academic year starts in',
    description: 'Month the school session begins (4 = April, the Indian norm). Used for invoice labels and yearly reports.',
    category: 'academic',
    editableBy: 'admin',
    consumed: false,
  },
  {
    key: 'academic.working_days',
    type: 'json',
    default: '["mon","tue","wed","thu","fri","sat"]',
    label: 'Working days',
    description: 'Days the school runs. Drives the timetable day tabs and the attendance-percentage denominator.',
    category: 'academic',
    editableBy: 'admin',
    consumed: true,
  },

  // ── Timetable ──────────────────────────────────────────────────────────────
  {
    key: 'timetable.periods_per_day',
    type: 'int',
    default: '8',
    min: 4,
    max: 12,
    label: 'Periods per day',
    description: 'How many teaching periods the timetable grid offers each day.',
    category: 'timetable',
    editableBy: 'admin',
    consumed: true,
  },

  // ── Attendance ─────────────────────────────────────────────────────────────
  {
    key: 'attendance.defaulter_threshold',
    type: 'int',
    default: '75',
    min: 40,
    max: 95,
    label: 'Defaulter threshold (%)',
    description: 'Students below this attendance percentage appear in the defaulters report.',
    category: 'attendance',
    editableBy: 'admin',
    consumed: true,
  },
  {
    key: 'attendance.mode',
    type: 'enum',
    default: 'daily',
    enumValues: ['daily', 'per_period'],
    label: 'Attendance mode',
    description: 'Daily marking, or once per period. Per-period marking is not yet built in the app — the setting exists so the data model is ready.',
    category: 'attendance',
    editableBy: 'superadmin',
    consumed: false,
  },

  // ── Fees ───────────────────────────────────────────────────────────────────
  {
    key: 'fees.due_date_day',
    type: 'int',
    default: '10',
    min: 1,
    max: 28,
    legacyKey: 'due_date_day',
    label: 'Fee due date (day of month)',
    description: 'Day of the month generated invoices fall due. Capped at 28 so every month behaves the same.',
    category: 'fees',
    editableBy: 'admin',
    consumed: true,
  },
  {
    key: 'fees.late_fine_per_day',
    type: 'int',
    default: '0',
    min: 0,
    max: 10000,
    label: 'Late fine per day (₹)',
    description: 'Suggested fine per day overdue. 0 disables late fines entirely.',
    category: 'fees',
    editableBy: 'admin',
    consumed: false,
  },
  {
    key: 'fees.invoice_prefix',
    type: 'string',
    default: 'INV',
    label: 'Invoice number prefix',
    description: 'Shown on invoices and receipts, e.g. INV-2026-0001.',
    category: 'fees',
    editableBy: 'admin',
    consumed: false,
  },

  // ── Grading ────────────────────────────────────────────────────────────────
  {
    key: 'grading.scheme',
    type: 'enum',
    default: 'percent',
    enumValues: ['percent', 'grade', 'both'],
    label: 'Show results as',
    description: 'Whether exam results display percentages, letter grades, or both.',
    category: 'grading',
    editableBy: 'admin',
    consumed: false,
  },
  {
    key: 'grading.bands',
    type: 'json',
    default: '{"A":90,"B":75,"C":60,"D":40}',
    label: 'Grade bands',
    description: 'Minimum percentage for each letter grade, used when results show grades.',
    category: 'grading',
    editableBy: 'admin',
    consumed: false,
  },

  // ── Locale ─────────────────────────────────────────────────────────────────
  {
    key: 'locale.language',
    type: 'enum',
    default: 'en',
    enumValues: ['en', 'hi'],
    label: 'Default language',
    description: 'Language the app opens in for this school. Users can still override it on their profile.',
    category: 'locale',
    editableBy: 'superadmin',
    consumed: false,
  },

  // ── Branding ───────────────────────────────────────────────────────────────
  {
    key: 'branding.primary_color',
    type: 'color',
    default: '#1E88E5',
    label: 'Accent colour',
    description: "Hex colour used for the app's accents, e.g. #1E88E5.",
    category: 'branding',
    editableBy: 'admin',
    consumed: false,
  },
  {
    key: 'branding.show_logo',
    type: 'bool',
    default: 'true',
    label: 'Show school logo',
    description: "Display the school's logo in the app bar (uses the logo on the school profile).",
    category: 'branding',
    editableBy: 'admin',
    consumed: false,
  },

  // ── Feature flags ──────────────────────────────────────────────────────────
  {
    key: 'features.online_payments',
    type: 'bool',
    default: 'true',
    label: 'Online fee payments',
    description: 'Show Pay Now on parent dues. Payments currently run through a mock gateway.',
    category: 'features',
    editableBy: 'superadmin',
    consumed: false,
  },
  {
    key: 'features.materials',
    type: 'bool',
    default: 'true',
    label: 'Study material',
    description: 'Enable study-material upload and download.',
    category: 'features',
    editableBy: 'superadmin',
    consumed: false,
  },
  {
    key: 'features.polls',
    type: 'bool',
    default: 'false',
    label: 'Polls',
    description: 'Enable polls. Not yet built — reserved.',
    category: 'features',
    editableBy: 'superadmin',
    consumed: false,
  },
] as const;

const BY_KEY: ReadonlyMap<string, SettingDef> = new Map(SETTINGS_REGISTRY.map((d) => [d.key, d]));

export const getSettingDef = (key: string): SettingDef | undefined => BY_KEY.get(key);

/** Registry entries carrying a legacy key, for the read-time fallback. */
export const LEGACY_KEY_MAP: ReadonlyMap<string, SettingDef> = new Map(
  SETTINGS_REGISTRY.filter((d) => d.legacyKey).map((d) => [d.legacyKey as string, d]),
);

/**
 * Flat rather than a discriminated union on purpose: this package compiles with
 * `strictNullChecks: false`, under which `if (!result.ok)` does not narrow a
 * `{ok:true}|{ok:false}` union and every caller fails to typecheck.
 */
export type ValidationResult = { ok: boolean; value?: string; error?: string };

const BOOL_TRUE = ['true', '1', 'yes', 'on'];
const BOOL_FALSE = ['false', '0', 'no', 'off'];
const TIME_RE = /^([01]\d|2[0-3]):([0-5]\d)$/;
const COLOR_RE = /^#[0-9a-fA-F]{6}$/;

/**
 * Validates a raw (string-ish) value against its registry definition and returns
 * the canonical stored form. This is what stops a typo'd key or an out-of-range
 * number from being written and silently doing nothing.
 */
export function validateSetting(def: SettingDef, raw: unknown): ValidationResult {
  if (raw === null || raw === undefined) return { ok: false, error: `${def.key}: value is required` };
  const value = typeof raw === 'string' ? raw.trim() : JSON.stringify(raw);

  switch (def.type) {
    case 'int': {
      if (!/^-?\d+$/.test(value)) return { ok: false, error: `${def.key}: must be a whole number` };
      const n = Number(value);
      if (def.min !== undefined && n < def.min) return { ok: false, error: `${def.key}: must be at least ${def.min}` };
      if (def.max !== undefined && n > def.max) return { ok: false, error: `${def.key}: must be at most ${def.max}` };
      return { ok: true, value: String(n) };
    }
    case 'bool': {
      const lower = value.toLowerCase();
      if (BOOL_TRUE.includes(lower)) return { ok: true, value: 'true' };
      if (BOOL_FALSE.includes(lower)) return { ok: true, value: 'false' };
      return { ok: false, error: `${def.key}: must be true or false` };
    }
    case 'enum': {
      if (!def.enumValues?.includes(value)) {
        return { ok: false, error: `${def.key}: must be one of ${def.enumValues?.join(', ')}` };
      }
      return { ok: true, value };
    }
    case 'time': {
      if (!TIME_RE.test(value)) return { ok: false, error: `${def.key}: must be a 24-hour time like 09:30` };
      return { ok: true, value };
    }
    case 'color': {
      if (!COLOR_RE.test(value)) return { ok: false, error: `${def.key}: must be a hex colour like #1E88E5` };
      return { ok: true, value: value.toUpperCase() };
    }
    case 'json': {
      try {
        JSON.parse(value);
      } catch {
        return { ok: false, error: `${def.key}: must be valid JSON` };
      }
      return { ok: true, value };
    }
    case 'string': {
      if (!value.length) return { ok: false, error: `${def.key}: must not be empty` };
      if (value.length > 200) return { ok: false, error: `${def.key}: must be 200 characters or fewer` };
      return { ok: true, value };
    }
  }
}

/** Turns a stored string into its typed JS value. Falls back to the default if a stored row is corrupt. */
export function coerceSetting(def: SettingDef, stored: string): unknown {
  const parse = (v: string): unknown => {
    switch (def.type) {
      case 'int':
        return Number(v);
      case 'bool':
        return BOOL_TRUE.includes(v.toLowerCase());
      case 'json':
        return JSON.parse(v);
      default:
        return v;
    }
  };
  try {
    return parse(stored);
  } catch {
    return parse(def.default);
  }
}
