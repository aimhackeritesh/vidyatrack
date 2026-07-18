#!/usr/bin/env node
/**
 * Production bootstrap — create (or reset) ONLY the platform super-admin.
 *
 * Unlike `npm run seed` (which WIPES and inserts 240 demo students + a demo
 * school), this touches nothing tenant-related. It just ensures one super-admin
 * account exists so you can log into the web console and create the first real
 * school. Idempotent: re-running resets the password to the env value.
 *
 * Connects with DATABASE_ADMIN_URL (superuser). Run AFTER apply-db.js.
 *
 * Env:
 *   SUPER_ADMIN_EMAIL     (default: founder@vidyatrack.in)
 *   SUPER_ADMIN_PASSWORD  (required — no default, so prod never gets a weak one)
 *   SUPER_ADMIN_NAME      (default: Platform Owner)
 *
 * Usage (from apps/api):
 *   SUPER_ADMIN_PASSWORD='...' node scripts/bootstrap-prod.js
 */
const { Client } = require('pg');
const argon2 = require('argon2');
const { randomUUID } = require('crypto');
try { require('dotenv').config(); } catch { /* dotenv optional */ }

function sslFor(url) {
  if (/localhost|127\.0\.0\.1|@postgres[:/]/.test(url)) return false;
  return { rejectUnauthorized: false };
}

async function main() {
  const url = process.env.DATABASE_ADMIN_URL || process.env.DATABASE_URL;
  if (!url) { console.error('✗ DATABASE_ADMIN_URL is required.'); process.exit(1); }

  const email = process.env.SUPER_ADMIN_EMAIL || 'founder@vidyatrack.in';
  const password = process.env.SUPER_ADMIN_PASSWORD;
  const name = process.env.SUPER_ADMIN_NAME || 'Platform Owner';
  if (!password) {
    console.error('✗ SUPER_ADMIN_PASSWORD is required (refusing to bootstrap a super-admin with no/weak password).');
    process.exit(1);
  }
  if (password.length < 8) {
    console.error('✗ SUPER_ADMIN_PASSWORD must be at least 8 characters.');
    process.exit(1);
  }

  const hash = await argon2.hash(password);
  const client = new Client({ connectionString: url, ssl: sslFor(url) });
  await client.connect();
  try {
    const { rows } = await client.query('SELECT id FROM users WHERE email=$1', [email]);
    if (rows.length === 0) {
      await client.query(
        `INSERT INTO users(id,email,password_hash,name,is_superadmin,status)
         VALUES($1,$2,$3,$4,true,'active')`,
        [randomUUID(), email, hash, name],
      );
      console.log(`✓ Created super-admin ${email}`);
    } else {
      await client.query(
        'UPDATE users SET password_hash=$2, is_superadmin=true, name=$3, updated_at=NOW() WHERE id=$1',
        [rows[0].id, hash, name],
      );
      console.log(`✓ Reset existing super-admin ${email}`);
    }
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error('\n✗ bootstrap-prod failed:', err.message);
  process.exit(1);
});
