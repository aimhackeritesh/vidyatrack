#!/usr/bin/env node
/**
 * Apply the database schema + RLS setup to a target Postgres.
 *
 * The canonical "migrate the production DB" step. Idempotent — safe to re-run.
 * Runs schema.sql (tables, functions, tenant policies) then rls-setup.sql
 * (the least-privilege `vidyatrack_app` role + grants). Both are written to be
 * re-runnable, so this can bring a fresh managed Postgres (Railway/RDS/etc.)
 * to the current schema, or upgrade an existing one.
 *
 * Connects with DATABASE_ADMIN_URL (the superuser/owner role) — required,
 * because creating the app role and DDL both need elevated privileges.
 *
 * Usage (from apps/api, with env set or a .env present):
 *   node scripts/apply-db.js
 *   DATABASE_ADMIN_URL=postgres://... node scripts/apply-db.js   # e.g. remote Railway DB
 */
const fs = require('fs');
const path = require('path');
const { Client } = require('pg');
try { require('dotenv').config(); } catch { /* dotenv optional */ }

function sslFor(url) {
  // Managed Postgres (Railway, RDS, etc.) needs TLS; local docker does not.
  if (/localhost|127\.0\.0\.1|@postgres[:/]/.test(url)) return false;
  return { rejectUnauthorized: false };
}

async function main() {
  const url = process.env.DATABASE_ADMIN_URL || process.env.DATABASE_URL;
  if (!url) {
    console.error('✗ DATABASE_ADMIN_URL (or DATABASE_URL) is required.');
    process.exit(1);
  }
  const dir = path.join(__dirname, '..', 'src', 'database');
  const files = ['schema.sql', 'rls-setup.sql'];

  const client = new Client({ connectionString: url, ssl: sslFor(url) });
  await client.connect();
  try {
    for (const file of files) {
      const sql = fs.readFileSync(path.join(dir, file), 'utf8');
      process.stdout.write(`Applying ${file} … `);
      await client.query(sql);
      console.log('✓');
    }
    console.log('Database is up to date.');
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error('\n✗ apply-db failed:', err.message);
  process.exit(1);
});
