-- VidyaTrack — Full PostgreSQL Schema with Row-Level Security
-- Run once against a fresh database

-- ─────────────────────────────────────────────
-- Extensions
-- ─────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ─────────────────────────────────────────────
-- Enums
-- ─────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE user_role_enum AS ENUM ('admin','teacher','parent','student','superadmin');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE school_plan_enum AS ENUM ('trial','starter','growth','enterprise');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE school_status_enum AS ENUM ('active','suspended','cancelled');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE attendance_status_enum AS ENUM ('present','absent','late','leave','holiday');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE attendance_session_type AS ENUM ('full_day','period');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE payment_mode_enum AS ENUM ('cash','upi','cheque','bank','online');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE fee_frequency_enum AS ENUM ('monthly','quarterly','annual','one_time');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE invoice_status_enum AS ENUM ('pending','partial','paid','overdue','waived');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE leave_status_enum AS ENUM ('pending','approved','rejected');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE applicant_type_enum AS ENUM ('teacher','student');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE notice_audience_enum AS ENUM ('all','teachers','parents','students','section');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE notification_channel_enum AS ENUM ('push','sms','whatsapp','in_app');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE student_status_enum AS ENUM ('active','inactive','transferred','alumni');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ─────────────────────────────────────────────
-- Global tables (no school_id, not tenant-scoped)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS schools (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code            VARCHAR(20) UNIQUE NOT NULL,        -- e.g. VDTRK2627AGS01
  name            TEXT NOT NULL,
  logo_url        TEXT,
  principal_name  TEXT,
  email           TEXT,
  phone           VARCHAR(15),
  address         TEXT,
  city            TEXT,
  state           TEXT,
  academic_year_start DATE,
  plan            school_plan_enum NOT NULL DEFAULT 'trial',
  status          school_status_enum NOT NULL DEFAULT 'active',
  sms_credits     INTEGER NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS users (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  phone           VARCHAR(15) UNIQUE,                 -- nullable: students log in by login_id, not phone
  login_id        VARCHAR(30),                        -- e.g. STU-2026001 / PAR-2026001 (unique within a school)
  email           TEXT,
  password_hash   TEXT,
  name            TEXT NOT NULL,
  photo_url       TEXT,
  must_change_password BOOLEAN NOT NULL DEFAULT false,
  status          VARCHAR(20) NOT NULL DEFAULT 'active',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_users_login_id ON users(login_id);

-- Idempotent upgrades for databases created before the columns above existed.
ALTER TABLE users ALTER COLUMN phone DROP NOT NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS login_id VARCHAR(30);
ALTER TABLE users ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN NOT NULL DEFAULT false;

-- Maps a user to a school + role (one user can have many rows here)
CREATE TABLE IF NOT EXISTS user_roles (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  school_id         UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  role              user_role_enum NOT NULL,
  linked_entity_id  UUID,    -- teacher_id or student_id depending on role
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, school_id, role)
);

-- OTP store (lives in Redis but schema documented here)
-- Redis key: otp:{phone} → {otp, attempts, created_at}  TTL=300s

-- ─────────────────────────────────────────────
-- Tenant tables (all have school_id)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS classes (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id   UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,                   -- "Nursery", "1", "10", "12"
  order_no    INTEGER NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(school_id, name)
);

CREATE TABLE IF NOT EXISTS sections (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  class_id    UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
  school_id   UUID NOT NULL,
  name        TEXT NOT NULL,                   -- "A", "B", "C"
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(class_id, name)
);

CREATE TABLE IF NOT EXISTS students (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id       UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  section_id      UUID NOT NULL REFERENCES sections(id),
  admission_no    TEXT NOT NULL,
  roll_no         INTEGER,
  name            TEXT NOT NULL,
  dob             DATE,
  gender          CHAR(1),                     -- M / F / O
  guardian_user_id UUID REFERENCES users(id),
  photo_url       TEXT,
  status          student_status_enum NOT NULL DEFAULT 'active',
  admission_date  DATE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(school_id, admission_no)
);

CREATE TABLE IF NOT EXISTS teachers (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id       UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES users(id),
  employee_code   TEXT,
  designation     TEXT,
  subjects        TEXT[],
  status          VARCHAR(20) NOT NULL DEFAULT 'active',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(school_id, user_id)
);

-- ─── Attendance ──────────────────────────────
CREATE TABLE IF NOT EXISTS attendance_sessions (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id   UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  section_id  UUID NOT NULL REFERENCES sections(id),
  date        DATE NOT NULL,
  session     attendance_session_type NOT NULL DEFAULT 'full_day',
  marked_by   UUID REFERENCES users(id),
  marked_at   TIMESTAMPTZ,
  locked_at   TIMESTAMPTZ,          -- null = editable by marker; set = admin-only
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(school_id, section_id, date, session)
);

CREATE TABLE IF NOT EXISTS attendance_records (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id  UUID NOT NULL REFERENCES attendance_sessions(id) ON DELETE CASCADE,
  student_id  UUID NOT NULL REFERENCES students(id),
  status      attendance_status_enum NOT NULL DEFAULT 'present',
  remark      TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(session_id, student_id)
);

CREATE TABLE IF NOT EXISTS teacher_attendance (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id   UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  teacher_id  UUID NOT NULL REFERENCES teachers(id),
  date        DATE NOT NULL,
  status      attendance_status_enum NOT NULL DEFAULT 'present',
  marked_by   UUID REFERENCES users(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(school_id, teacher_id, date)
);

-- ─── Fees ────────────────────────────────────
CREATE TABLE IF NOT EXISTS fee_heads (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id   UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  amount      NUMERIC(10,2) NOT NULL DEFAULT 0,
  frequency   fee_frequency_enum NOT NULL DEFAULT 'monthly',
  class_id    UUID REFERENCES classes(id),    -- null = all classes
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS fee_invoices (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id   UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  student_id  UUID NOT NULL REFERENCES students(id),
  month       DATE NOT NULL,                   -- first day of the billing month
  due_amount  NUMERIC(10,2) NOT NULL DEFAULT 0,
  due_date    DATE,
  status      invoice_status_enum NOT NULL DEFAULT 'pending',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS fee_payments (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  invoice_id      UUID NOT NULL REFERENCES fee_invoices(id),
  school_id       UUID NOT NULL,
  amount          NUMERIC(10,2) NOT NULL,
  mode            payment_mode_enum NOT NULL DEFAULT 'cash',
  fine            NUMERIC(10,2) NOT NULL DEFAULT 0,
  discount        NUMERIC(10,2) NOT NULL DEFAULT 0,
  received_by     UUID REFERENCES users(id),
  receipt_no      TEXT,
  paid_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS expenses (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id   UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  category    TEXT NOT NULL,
  amount      NUMERIC(10,2) NOT NULL,
  note        TEXT,
  spent_by    UUID REFERENCES users(id),
  date        DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── Academics ───────────────────────────────
CREATE TABLE IF NOT EXISTS homework (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id   UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  section_id  UUID NOT NULL REFERENCES sections(id),
  subject     TEXT NOT NULL,
  title       TEXT NOT NULL,
  description TEXT,
  attachments JSONB NOT NULL DEFAULT '[]',
  due_date    DATE,
  created_by  UUID REFERENCES users(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS study_materials (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id   UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  class_id    UUID REFERENCES classes(id),
  subject     TEXT NOT NULL,
  title       TEXT NOT NULL,
  file_url    TEXT,
  type        VARCHAR(20),                     -- pdf / image / link
  created_by  UUID REFERENCES users(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS syllabus (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id   UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  class_id    UUID REFERENCES classes(id),
  subject     TEXT NOT NULL,
  file_url    TEXT,
  topics_json JSONB,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(school_id, class_id, subject)
);

CREATE TABLE IF NOT EXISTS timetable_slots (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id   UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  section_id  UUID NOT NULL REFERENCES sections(id),
  day         SMALLINT NOT NULL,               -- 1=Mon…7=Sun
  period_no   SMALLINT NOT NULL,
  subject     TEXT NOT NULL,
  teacher_id  UUID REFERENCES teachers(id),
  start_time  TIME NOT NULL,
  end_time    TIME NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(school_id, section_id, day, period_no)
);

CREATE TABLE IF NOT EXISTS exams (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id   UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  term        TEXT,
  class_id    UUID REFERENCES classes(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS exam_results (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  exam_id     UUID NOT NULL REFERENCES exams(id) ON DELETE CASCADE,
  student_id  UUID NOT NULL REFERENCES students(id),
  subject     TEXT NOT NULL,
  marks       NUMERIC(6,2),
  max_marks   NUMERIC(6,2) NOT NULL DEFAULT 100,
  grade       VARCHAR(5),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(exam_id, student_id, subject)
);

-- ─── Communication ───────────────────────────
CREATE TABLE IF NOT EXISTS notices (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id       UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  audience        notice_audience_enum NOT NULL DEFAULT 'all',
  audience_ref_id UUID,                        -- section_id when audience=section
  title           TEXT NOT NULL,
  body            TEXT NOT NULL,
  attachment_url  TEXT,
  publish_at      TIMESTAMPTZ,
  created_by      UUID REFERENCES users(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS circulars (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id   UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  title       TEXT NOT NULL,
  file_url    TEXT NOT NULL,
  audience    notice_audience_enum NOT NULL DEFAULT 'all',
  created_by  UUID REFERENCES users(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS messages (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id       UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  sender_id       UUID REFERENCES users(id),
  recipient_type  TEXT NOT NULL,               -- all_parents / section / individual
  recipient_id    UUID,
  body            TEXT NOT NULL,
  channel         notification_channel_enum NOT NULL DEFAULT 'push',
  status          VARCHAR(20) NOT NULL DEFAULT 'queued',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS suggestions (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id       UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  from_user_id    UUID REFERENCES users(id),
  body            TEXT NOT NULL,
  status          VARCHAR(20) NOT NULL DEFAULT 'open',
  reply           TEXT,
  replied_by      UUID REFERENCES users(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS leave_requests (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id       UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  applicant_type  applicant_type_enum NOT NULL,
  applicant_id    UUID NOT NULL,
  from_date       DATE NOT NULL,
  to_date         DATE NOT NULL,
  reason          TEXT,
  status          leave_status_enum NOT NULL DEFAULT 'pending',
  acted_by        UUID REFERENCES users(id),
  acted_at        TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS polls (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id   UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  question    TEXT NOT NULL,
  options     JSONB NOT NULL DEFAULT '[]',
  audience    notice_audience_enum NOT NULL DEFAULT 'all',
  expires_at  TIMESTAMPTZ,
  created_by  UUID REFERENCES users(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS poll_votes (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  poll_id     UUID NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES users(id),
  option_idx  SMALLINT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(poll_id, user_id)
);

CREATE TABLE IF NOT EXISTS gallery_albums (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id   UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  title       TEXT NOT NULL,
  cover_url   TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS gallery_photos (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  album_id    UUID NOT NULL REFERENCES gallery_albums(id) ON DELETE CASCADE,
  school_id   UUID NOT NULL,
  url         TEXT NOT NULL,
  caption     TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS notifications (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id   UUID NOT NULL,
  user_id     UUID NOT NULL REFERENCES users(id),
  title       TEXT NOT NULL,
  body        TEXT NOT NULL,
  type        TEXT NOT NULL,
  data        JSONB,
  read_at     TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── Audit log ───────────────────────────────
CREATE TABLE IF NOT EXISTS audit_logs (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id   UUID,
  user_id     UUID REFERENCES users(id),
  action      TEXT NOT NULL,
  entity      TEXT NOT NULL,
  entity_id   UUID,
  payload     JSONB,
  ip          TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── Summary/precomputed tables ──────────────
CREATE TABLE IF NOT EXISTS daily_attendance_summary (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id       UUID NOT NULL,
  section_id      UUID,
  date            DATE NOT NULL,
  total_students  INTEGER NOT NULL DEFAULT 0,
  present         INTEGER NOT NULL DEFAULT 0,
  absent          INTEGER NOT NULL DEFAULT 0,
  late            INTEGER NOT NULL DEFAULT 0,
  on_leave        INTEGER NOT NULL DEFAULT 0,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(school_id, section_id, date)
);

CREATE TABLE IF NOT EXISTS daily_revenue_summary (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id       UUID NOT NULL UNIQUE,       -- one row per school, refreshed daily
  date            DATE NOT NULL DEFAULT CURRENT_DATE,
  total_revenue   NUMERIC(12,2) NOT NULL DEFAULT 0,
  amount_received NUMERIC(12,2) NOT NULL DEFAULT 0,
  back_due        NUMERIC(12,2) NOT NULL DEFAULT 0,
  fine_received   NUMERIC(12,2) NOT NULL DEFAULT 0,
  expense         NUMERIC(12,2) NOT NULL DEFAULT 0,
  discount        NUMERIC(12,2) NOT NULL DEFAULT 0,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- Indexes
-- ─────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_user_roles_school_user ON user_roles(school_id, user_id);
CREATE INDEX IF NOT EXISTS idx_students_school ON students(school_id);
CREATE INDEX IF NOT EXISTS idx_students_section ON students(section_id);
CREATE INDEX IF NOT EXISTS idx_att_sessions_school_date ON attendance_sessions(school_id, date);
CREATE INDEX IF NOT EXISTS idx_att_records_session ON attendance_records(session_id);
CREATE INDEX IF NOT EXISTS idx_att_records_student ON attendance_records(student_id);
CREATE INDEX IF NOT EXISTS idx_fee_invoices_school_student ON fee_invoices(school_id, student_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_school ON audit_logs(school_id, created_at DESC);

-- ─────────────────────────────────────────────
-- Row-Level Security
-- ─────────────────────────────────────────────
-- App user: vidyatrack_app (non-superuser) runs all queries

-- Helper function: current tenant from session variable
CREATE OR REPLACE FUNCTION current_school_id() RETURNS UUID AS $$
  SELECT NULLIF(current_setting('app.current_school_id', true), '')::UUID;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION current_user_role() RETURNS TEXT AS $$
  SELECT NULLIF(current_setting('app.current_role', true), '');
$$ LANGUAGE sql STABLE;

-- Enable RLS on every tenant table
DO $$
DECLARE tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'classes','sections','students','teachers',
    'attendance_sessions','attendance_records','teacher_attendance',
    'fee_heads','fee_invoices','fee_payments','expenses',
    'homework','study_materials','syllabus','timetable_slots',
    'exams','exam_results','notices','circulars','messages',
    'suggestions','leave_requests','polls','poll_votes',
    'gallery_albums','gallery_photos','notifications',
    'daily_attendance_summary','daily_revenue_summary'
  ] LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', tbl);
    -- bypass for superuser sessions (migrations, seeds)
    EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', tbl);
  END LOOP;
END $$;

-- Generic tenant policy macro — only tables that carry school_id directly.
-- (attendance_records, exam_results and poll_votes have no school_id column;
--  they get parent-derived policies below.)
DO $$
DECLARE tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'classes','sections','students','teachers',
    'attendance_sessions','teacher_attendance',
    'fee_heads','fee_invoices','fee_payments','expenses',
    'homework','study_materials','syllabus','timetable_slots',
    'exams','notices','circulars','messages',
    'suggestions','leave_requests','polls',
    'gallery_albums','gallery_photos','notifications',
    'daily_attendance_summary','daily_revenue_summary'
  ] LOOP
    EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON %I', tbl);
    EXECUTE format(
      $p$CREATE POLICY tenant_isolation ON %I
         USING (school_id = current_school_id())
         WITH CHECK (school_id = current_school_id())$p$,
      tbl
    );
  END LOOP;
END $$;

-- Child tables without a school_id column: derive the tenant from the parent.
DROP POLICY IF EXISTS tenant_isolation ON attendance_records;
CREATE POLICY tenant_isolation ON attendance_records
  USING (EXISTS (SELECT 1 FROM attendance_sessions p
                 WHERE p.id = attendance_records.session_id
                   AND p.school_id = current_school_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM attendance_sessions p
                 WHERE p.id = attendance_records.session_id
                   AND p.school_id = current_school_id()));

DROP POLICY IF EXISTS tenant_isolation ON exam_results;
CREATE POLICY tenant_isolation ON exam_results
  USING (EXISTS (SELECT 1 FROM exams p
                 WHERE p.id = exam_results.exam_id
                   AND p.school_id = current_school_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM exams p
                 WHERE p.id = exam_results.exam_id
                   AND p.school_id = current_school_id()));

DROP POLICY IF EXISTS tenant_isolation ON poll_votes;
CREATE POLICY tenant_isolation ON poll_votes
  USING (EXISTS (SELECT 1 FROM polls p
                 WHERE p.id = poll_votes.poll_id
                   AND p.school_id = current_school_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM polls p
                 WHERE p.id = poll_votes.poll_id
                   AND p.school_id = current_school_id()));

-- audit_logs: tenant policy with superadmin bypass
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS audit_tenant ON audit_logs;
CREATE POLICY audit_tenant ON audit_logs
  USING (school_id = current_school_id() OR current_user_role() = 'superadmin');

-- ─────────────────────────────────────────────
-- Revenue summary refresh function
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION refresh_daily_revenue(p_school_id UUID) RETURNS VOID AS $$
DECLARE
  v_received   NUMERIC;
  v_back_due   NUMERIC;
  v_fine       NUMERIC;
  v_discount   NUMERIC;
  v_expense    NUMERIC;
BEGIN
  SELECT
    COALESCE(SUM(fp.amount),0),
    COALESCE(SUM(CASE WHEN fi.month < DATE_TRUNC('month', NOW()) THEN fp.amount ELSE 0 END),0),
    COALESCE(SUM(fp.fine),0),
    COALESCE(SUM(fp.discount),0)
  INTO v_received, v_back_due, v_fine, v_discount
  FROM fee_payments fp
  JOIN fee_invoices fi ON fi.id = fp.invoice_id
  WHERE fp.school_id = p_school_id
    AND fp.paid_at::DATE = CURRENT_DATE;

  SELECT COALESCE(SUM(amount),0)
  INTO v_expense
  FROM expenses
  WHERE school_id = p_school_id AND date = CURRENT_DATE;

  INSERT INTO daily_revenue_summary(school_id, date, amount_received, back_due, fine_received, discount, expense, total_revenue, updated_at)
  VALUES(p_school_id, CURRENT_DATE, v_received, v_back_due, v_fine, v_discount, v_expense, v_received + v_fine - v_discount, NOW())
  ON CONFLICT(school_id) DO UPDATE SET
    date = CURRENT_DATE,
    amount_received = EXCLUDED.amount_received,
    back_due        = EXCLUDED.back_due,
    fine_received   = EXCLUDED.fine_received,
    discount        = EXCLUDED.discount,
    expense         = EXCLUDED.expense,
    total_revenue   = EXCLUDED.total_revenue,
    updated_at      = NOW();
END;
$$ LANGUAGE plpgsql;

-- ─────────────────────────────────────────────
-- Phase 3 — Revenue v2 (manual income, voids, corrected daily formula)
-- ─────────────────────────────────────────────

-- Non-fee income (admission forms, donations, etc.)
CREATE TABLE IF NOT EXISTS other_income (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id   UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  category    TEXT NOT NULL,
  amount      NUMERIC(12,2) NOT NULL,
  note        TEXT,
  received_by UUID REFERENCES users(id),
  date        DATE NOT NULL DEFAULT CURRENT_DATE,
  voided_at   TIMESTAMPTZ,
  void_reason TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Void support on existing money entries (never hard-delete an entry).
ALTER TABLE fee_payments ADD COLUMN IF NOT EXISTS voided_at   TIMESTAMPTZ;
ALTER TABLE fee_payments ADD COLUMN IF NOT EXISTS void_reason TEXT;
ALTER TABLE expenses     ADD COLUMN IF NOT EXISTS voided_at   TIMESTAMPTZ;
ALTER TABLE expenses     ADD COLUMN IF NOT EXISTS void_reason TEXT;

-- RLS for other_income (tenant isolation, like the other money tables).
ALTER TABLE other_income ENABLE ROW LEVEL SECURITY;
ALTER TABLE other_income FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON other_income;
CREATE POLICY tenant_isolation ON other_income
  USING (school_id = current_school_id())
  WITH CHECK (school_id = current_school_id());
GRANT SELECT, INSERT, UPDATE, DELETE ON other_income TO vidyatrack_app;

-- Corrected daily revenue: matches the v2 plan §6 definitions.
--   Amount Received   = today's CURRENT/forward fee payments + other income  (NOT back-due, to avoid double counting)
--   Back Due Received = today's payments applied to previous-month invoices
--   Fine / Discount   = today's fine / discount fields (discount shown, not subtracted from cash)
--   Expense           = today's expenses
--   Total Revenue     = Amount Received + Back Due Received + Fine Received − Expense
-- Voided rows are excluded everywhere.
CREATE OR REPLACE FUNCTION refresh_daily_revenue(p_school_id UUID) RETURNS VOID AS $$
DECLARE
  v_fee_current NUMERIC;
  v_back_due    NUMERIC;
  v_fine        NUMERIC;
  v_discount    NUMERIC;
  v_other       NUMERIC;
  v_expense     NUMERIC;
  v_received    NUMERIC;
BEGIN
  SELECT
    COALESCE(SUM(CASE WHEN fi.month >= DATE_TRUNC('month', CURRENT_DATE) THEN fp.amount ELSE 0 END),0),
    COALESCE(SUM(CASE WHEN fi.month <  DATE_TRUNC('month', CURRENT_DATE) THEN fp.amount ELSE 0 END),0),
    COALESCE(SUM(fp.fine),0),
    COALESCE(SUM(fp.discount),0)
  INTO v_fee_current, v_back_due, v_fine, v_discount
  FROM fee_payments fp
  JOIN fee_invoices fi ON fi.id = fp.invoice_id
  WHERE fp.school_id = p_school_id
    AND fp.paid_at::DATE = CURRENT_DATE
    AND fp.voided_at IS NULL;

  SELECT COALESCE(SUM(amount),0) INTO v_other
  FROM other_income
  WHERE school_id = p_school_id AND date = CURRENT_DATE AND voided_at IS NULL;

  SELECT COALESCE(SUM(amount),0) INTO v_expense
  FROM expenses
  WHERE school_id = p_school_id AND date = CURRENT_DATE AND voided_at IS NULL;

  v_received := v_fee_current + v_other;

  INSERT INTO daily_revenue_summary(school_id, date, amount_received, back_due, fine_received, discount, expense, total_revenue, updated_at)
  VALUES(p_school_id, CURRENT_DATE, v_received, v_back_due, v_fine, v_discount, v_expense,
         v_received + v_back_due + v_fine - v_expense, NOW())
  ON CONFLICT(school_id) DO UPDATE SET
    date = CURRENT_DATE,
    amount_received = EXCLUDED.amount_received,
    back_due        = EXCLUDED.back_due,
    fine_received   = EXCLUDED.fine_received,
    discount        = EXCLUDED.discount,
    expense         = EXCLUDED.expense,
    total_revenue   = EXCLUDED.total_revenue,
    updated_at      = NOW();
END;
$$ LANGUAGE plpgsql;

-- ─────────────────────────────────────────────
-- Phase 2 — Holiday calendar (excluded from attendance %)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS holidays (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id   UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  date        DATE NOT NULL,
  name        TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(school_id, date)
);
ALTER TABLE holidays ENABLE ROW LEVEL SECURITY;
ALTER TABLE holidays FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON holidays;
CREATE POLICY tenant_isolation ON holidays
  USING (school_id = current_school_id() OR current_user_role() = 'superadmin')
  WITH CHECK (school_id = current_school_id() OR current_user_role() = 'superadmin');
GRANT SELECT, INSERT, UPDATE, DELETE ON holidays TO vidyatrack_app;

-- ─────────────────────────────────────────────
-- Phase 4 — Super-admin (platform owner)
-- ─────────────────────────────────────────────
ALTER TABLE users   ADD COLUMN IF NOT EXISTS is_superadmin BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS max_students  INTEGER;

-- Re-create tenant policies WITH a superadmin read/write bypass. Regular tenant
-- sessions set app.current_role to admin/teacher/etc → the bypass is false, so
-- isolation is unchanged (the RLS isolation test stays green). Only a session
-- that sets app.current_role='superadmin' (platform owner) sees across schools.
DO $$
DECLARE tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'classes','sections','students','teachers',
    'attendance_sessions','teacher_attendance',
    'fee_heads','fee_invoices','fee_payments','expenses','other_income',
    'homework','study_materials','syllabus','timetable_slots',
    'exams','notices','circulars','messages',
    'suggestions','leave_requests','polls',
    'gallery_albums','gallery_photos','notifications',
    'daily_attendance_summary','daily_revenue_summary'
  ] LOOP
    EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON %I', tbl);
    EXECUTE format(
      $p$CREATE POLICY tenant_isolation ON %I
         USING (school_id = current_school_id() OR current_user_role() = 'superadmin')
         WITH CHECK (school_id = current_school_id() OR current_user_role() = 'superadmin')$p$,
      tbl
    );
  END LOOP;
END $$;

-- Child tables (no school_id column): add the same superadmin bypass.
DROP POLICY IF EXISTS tenant_isolation ON attendance_records;
CREATE POLICY tenant_isolation ON attendance_records
  USING (current_user_role() = 'superadmin' OR EXISTS (SELECT 1 FROM attendance_sessions p
         WHERE p.id = attendance_records.session_id AND p.school_id = current_school_id()))
  WITH CHECK (current_user_role() = 'superadmin' OR EXISTS (SELECT 1 FROM attendance_sessions p
         WHERE p.id = attendance_records.session_id AND p.school_id = current_school_id()));

DROP POLICY IF EXISTS tenant_isolation ON exam_results;
CREATE POLICY tenant_isolation ON exam_results
  USING (current_user_role() = 'superadmin' OR EXISTS (SELECT 1 FROM exams p
         WHERE p.id = exam_results.exam_id AND p.school_id = current_school_id()))
  WITH CHECK (current_user_role() = 'superadmin' OR EXISTS (SELECT 1 FROM exams p
         WHERE p.id = exam_results.exam_id AND p.school_id = current_school_id()));

-- ─────────────────────────────────────────────
-- Phase 2 — Teacher correction approval flow
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS attendance_change_requests (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id       UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  teacher_id      UUID NOT NULL REFERENCES teachers(id),
  date            DATE NOT NULL,
  requested_status attendance_status_enum NOT NULL,
  reason          TEXT,
  status          leave_status_enum NOT NULL DEFAULT 'pending',
  acted_by        UUID REFERENCES users(id),
  acted_at        TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_pending_corrections ON attendance_change_requests(school_id, teacher_id, date) WHERE status = 'pending';

-- RLS
ALTER TABLE attendance_change_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_change_requests FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON attendance_change_requests;
CREATE POLICY tenant_isolation ON attendance_change_requests
  USING (school_id = current_school_id() OR current_user_role() = 'superadmin')
  WITH CHECK (school_id = current_school_id() OR current_user_role() = 'superadmin');
GRANT SELECT, INSERT, UPDATE, DELETE ON attendance_change_requests TO vidyatrack_app;

-- ─────────────────────────────────────────────
-- V3.0 — Shared infra + super-admin power-ups
-- ─────────────────────────────────────────────

-- Per-school feature flags + fee/invoice rules (key/value, e.g. online_payments=true, due_date_day=10)
CREATE TABLE IF NOT EXISTS school_settings (
  school_id   UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  key         TEXT NOT NULL,
  value       TEXT NOT NULL,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY(school_id, key)
);
ALTER TABLE school_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_settings FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON school_settings;
CREATE POLICY tenant_isolation ON school_settings
  USING (school_id = current_school_id() OR current_user_role() = 'superadmin')
  WITH CHECK (school_id = current_school_id() OR current_user_role() = 'superadmin');
GRANT SELECT, INSERT, UPDATE, DELETE ON school_settings TO vidyatrack_app;

-- Plan expiry (plan tier itself already exists: schools.plan school_plan_enum)
ALTER TABLE schools ADD COLUMN IF NOT EXISTS plan_expires_at DATE;

-- Online payment gateway linkage + idempotency on fee_payments
ALTER TABLE fee_payments ADD COLUMN IF NOT EXISTS gateway_order_id TEXT;
ALTER TABLE fee_payments ADD COLUMN IF NOT EXISTS gateway_payment_id TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS idx_fee_payments_gateway_payment_id
  ON fee_payments(gateway_payment_id) WHERE gateway_payment_id IS NOT NULL;

-- Indexes for V3 query paths
CREATE INDEX IF NOT EXISTS idx_fee_invoices_student_status ON fee_invoices(student_id, status);
CREATE INDEX IF NOT EXISTS idx_timetable_slots_section_day ON timetable_slots(section_id, day);
CREATE INDEX IF NOT EXISTS idx_study_materials_school_class_subject ON study_materials(school_id, class_id, subject);

-- One invoice per student per billing month — makes invoice generation idempotent.
CREATE UNIQUE INDEX IF NOT EXISTS idx_fee_invoices_student_month ON fee_invoices(school_id, student_id, month);

