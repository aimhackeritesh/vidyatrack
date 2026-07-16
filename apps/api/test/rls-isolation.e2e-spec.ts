/**
 * RLS isolation test — verifies that one school can NEVER read another school's
 * data once a tenant context is set, and that with no context the database
 * denies everything by default.
 *
 * Two connections are used, mirroring production:
 *   - `admin`: the superuser role. Bypasses RLS — used only to seed/clean.
 *   - `app`:   the least-privilege `vidyatrack_app` role (NOSUPERUSER /
 *              NOBYPASSRLS). RLS is enforced for it, so this is what the
 *              assertions run against.
 *
 * Prereq: a `vidyatrack_test` database loaded with schema.sql + rls-setup.sql.
 *   docker exec -i vidyatrack-postgres psql -U vidyatrack -d postgres \
 *     -c 'CREATE DATABASE vidyatrack_test;'
 *   docker exec -i vidyatrack-postgres psql -U vidyatrack -d vidyatrack_test \
 *     < src/database/schema.sql
 *   docker exec -i vidyatrack-postgres psql -U vidyatrack -d vidyatrack_test \
 *     < src/database/rls-setup.sql
 *
 * Run: npm run test:e2e
 */
import { DataSource, EntityManager } from 'typeorm';
import { v4 as uuidv4 } from 'uuid';

const ADMIN_URL =
  process.env.TEST_DATABASE_ADMIN_URL ??
  'postgresql://vidyatrack:vidyatrack@localhost:5432/vidyatrack_test';
const APP_URL =
  process.env.TEST_DATABASE_URL ??
  'postgresql://vidyatrack_app:vidyatrack_app@localhost:5432/vidyatrack_test';

describe('RLS — Cross-tenant data isolation', () => {
  jest.setTimeout(30000);

  let admin: DataSource; // superuser — bypasses RLS, used to seed/clean
  let app: DataSource; // least-privilege — RLS enforced, used for assertions

  let schoolAId: string;
  let schoolBId: string;
  let sectionAId: string;
  let sectionBId: string;

  // Bind the per-transaction RLS session variables. set_config(..., true) is the
  // SET LOCAL equivalent that takes the GUC name as a literal — so the reserved
  // word `current_role` parses cleanly — and binds the value as a parameter.
  async function setTenant(em: EntityManager, schoolId: string) {
    await em.query(`SELECT set_config('app.current_school_id', $1, true)`, [schoolId]);
    await em.query(`SELECT set_config('app.current_role', 'admin', true)`);
  }

  // FK-safe teardown limited to this test's two schools.
  async function wipeTestData(ds: DataSource) {
    const codes = ['TESTA001', 'TESTB001'];
    const scope = `school_id IN (SELECT id FROM schools WHERE code = ANY($1))`;
    await ds.query(`DELETE FROM students WHERE ${scope}`, [codes]);
    await ds.query(`DELETE FROM sections WHERE ${scope}`, [codes]);
    await ds.query(`DELETE FROM classes  WHERE ${scope}`, [codes]);
    await ds.query(`DELETE FROM schools  WHERE code = ANY($1)`, [codes]);
  }

  beforeAll(async () => {
    admin = await new DataSource({
      type: 'postgres', url: ADMIN_URL, synchronize: false, logging: false, entities: [],
    }).initialize();
    app = await new DataSource({
      type: 'postgres', url: APP_URL, synchronize: false, logging: false, entities: [],
    }).initialize();

    await wipeTestData(admin); // clean any leftovers from a prior failed run

    schoolAId = uuidv4();
    schoolBId = uuidv4();
    await admin.query(`INSERT INTO schools(id,code,name,plan,status) VALUES($1,'TESTA001','School A','trial','active')`, [schoolAId]);
    await admin.query(`INSERT INTO schools(id,code,name,plan,status) VALUES($1,'TESTB001','School B','trial','active')`, [schoolBId]);

    const classAId = uuidv4();
    const classBId = uuidv4();
    await admin.query(`INSERT INTO classes(id,school_id,name,order_no) VALUES($1,$2,'5',0)`, [classAId, schoolAId]);
    await admin.query(`INSERT INTO classes(id,school_id,name,order_no) VALUES($1,$2,'5',0)`, [classBId, schoolBId]);

    sectionAId = uuidv4();
    sectionBId = uuidv4();
    await admin.query(`INSERT INTO sections(id,class_id,school_id,name) VALUES($1,$2,$3,'A')`, [sectionAId, classAId, schoolAId]);
    await admin.query(`INSERT INTO sections(id,class_id,school_id,name) VALUES($1,$2,$3,'A')`, [sectionBId, classBId, schoolBId]);

    await admin.query(`INSERT INTO students(id,school_id,section_id,admission_no,name,status) VALUES($1,$2,$3,'A001','Student of A','active')`, [uuidv4(), schoolAId, sectionAId]);
    await admin.query(`INSERT INTO students(id,school_id,section_id,admission_no,name,status) VALUES($1,$2,$3,'B001','Student of B','active')`, [uuidv4(), schoolBId, sectionBId]);
  });

  afterAll(async () => {
    if (admin?.isInitialized) {
      await wipeTestData(admin);
      await admin.destroy();
    }
    if (app?.isInitialized) await app.destroy();
  });

  test('School A context sees only School A students', async () => {
    await app.transaction(async (em) => {
      await setTenant(em, schoolAId);
      const rows = await em.query(`SELECT * FROM students`);
      expect(rows.length).toBe(1);
      expect(rows[0].name).toBe('Student of A');
      expect(rows[0].school_id).toBe(schoolAId);
    });
  });

  test('School B context sees only School B students', async () => {
    await app.transaction(async (em) => {
      await setTenant(em, schoolBId);
      const rows = await em.query(`SELECT * FROM students`);
      expect(rows.length).toBe(1);
      expect(rows[0].name).toBe('Student of B');
      expect(rows[0].school_id).toBe(schoolBId);
    });
  });

  test('School A cannot read School B sections', async () => {
    await app.transaction(async (em) => {
      await setTenant(em, schoolAId);
      const rows = await em.query(`SELECT * FROM sections WHERE id = $1`, [sectionBId]);
      expect(rows.length).toBe(0); // RLS blocks it
    });
  });

  test('No tenant context → zero rows returned (deny by default)', async () => {
    await app.transaction(async (em) => {
      // intentionally do NOT set app.current_school_id
      const rows = await em.query(`SELECT * FROM students`);
      expect(rows.length).toBe(0);
    });
  });

  test('Admin (superuser) connection bypasses RLS — sees both schools', async () => {
    const rows = await admin.query(
      `SELECT * FROM students WHERE school_id IN ($1,$2)`,
      [schoolAId, schoolBId],
    );
    expect(rows.length).toBe(2);
  });
});
