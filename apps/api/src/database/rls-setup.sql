-- VidyaTrack — RLS roles, grants, and tenant-isolation policies.
--
-- Idempotent: safe to run repeatedly against any VidyaTrack database
-- (main, test, or a freshly-initialised one). schema.sql must have run first.
--
-- It does three things:
--   1. Creates the least-privilege application role `vidyatrack_app`
--      (NOSUPERUSER / NOBYPASSRLS) so row-level security is actually enforced.
--   2. Grants that role the runtime privileges it needs (DML + function exec).
--   3. (Re)creates the per-tenant isolation policies, including the child
--      tables that derive their tenant from a parent row.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Application role
-- ─────────────────────────────────────────────────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'vidyatrack_app') THEN
    CREATE ROLE vidyatrack_app LOGIN PASSWORD 'vidyatrack_app'
      NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Grants (per-database; the role itself is cluster-wide)
-- ─────────────────────────────────────────────────────────────────────────────
GRANT USAGE ON SCHEMA public TO vidyatrack_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO vidyatrack_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO vidyatrack_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO vidyatrack_app;

-- Future objects created by the admin/owner role inherit the same grants.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO vidyatrack_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO vidyatrack_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT EXECUTE ON FUNCTIONS TO vidyatrack_app;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Tenant-isolation policies
-- ─────────────────────────────────────────────────────────────────────────────

-- 3a. Tables that carry school_id directly.
DO $$
DECLARE tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'classes','sections','students','teachers',
    'attendance_sessions','teacher_attendance','attendance_change_requests',
    'fee_heads','fee_invoices','fee_payments','expenses',
    'homework','study_materials','syllabus','timetable_slots',
    'exams','notices','circulars','messages',
    'suggestions','leave_requests','polls',
    'gallery_albums','gallery_photos','notifications',
    'daily_attendance_summary','daily_revenue_summary'
  ] LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', tbl);
    EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', tbl);
    EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON %I', tbl);
    -- superadmin (platform owner) bypass; regular tenant roles fall through to
    -- the school_id check, so cross-tenant isolation is unchanged.
    EXECUTE format(
      $p$CREATE POLICY tenant_isolation ON %I
         USING (school_id = current_school_id() OR current_user_role() = 'superadmin')
         WITH CHECK (school_id = current_school_id() OR current_user_role() = 'superadmin')$p$,
      tbl
    );
  END LOOP;
END $$;

-- 3b. Child tables without a school_id column: derive the tenant from the
--     parent row so inserts/reads stay scoped without a denormalised column.
ALTER TABLE attendance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_records FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON attendance_records;
CREATE POLICY tenant_isolation ON attendance_records
  USING (current_user_role() = 'superadmin' OR EXISTS (SELECT 1 FROM attendance_sessions p
                 WHERE p.id = attendance_records.session_id
                   AND p.school_id = current_school_id()))
  WITH CHECK (current_user_role() = 'superadmin' OR EXISTS (SELECT 1 FROM attendance_sessions p
                 WHERE p.id = attendance_records.session_id
                   AND p.school_id = current_school_id()));

ALTER TABLE exam_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_results FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON exam_results;
CREATE POLICY tenant_isolation ON exam_results
  USING (current_user_role() = 'superadmin' OR EXISTS (SELECT 1 FROM exams p
                 WHERE p.id = exam_results.exam_id
                   AND p.school_id = current_school_id()))
  WITH CHECK (current_user_role() = 'superadmin' OR EXISTS (SELECT 1 FROM exams p
                 WHERE p.id = exam_results.exam_id
                   AND p.school_id = current_school_id()));

ALTER TABLE poll_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE poll_votes FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON poll_votes;
CREATE POLICY tenant_isolation ON poll_votes
  USING (EXISTS (SELECT 1 FROM polls p
                 WHERE p.id = poll_votes.poll_id
                   AND p.school_id = current_school_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM polls p
                 WHERE p.id = poll_votes.poll_id
                   AND p.school_id = current_school_id()));

-- 3c. audit_logs: tenant policy with a superadmin bypass.
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS audit_tenant ON audit_logs;
CREATE POLICY audit_tenant ON audit_logs
  USING (school_id = current_school_id() OR current_user_role() = 'superadmin');
