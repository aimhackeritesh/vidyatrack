# VidyaTrack — Operations Runbook

> How to deploy, roll back, migrate, reset, rotate, release, and debug the live system. Written to be followed under pressure. Commands here were verified against the actual CLIs (v: `railway` 5.27, `vercel` 56.3, `gh` 2.96).
>
> Orientation: [HANDOVER.md](HANDOVER.md) · Session rules: [CLAUDE.md](CLAUDE.md)

---

## 1. Live inventory

| Component | Host | Identity | Notes |
|---|---|---|---|
| API | Railway project `vidyatrack`, service `api` | — | Docker build, root context, `apps/api/Dockerfile`; healthcheck `/api/v1/health` |
| Postgres 16 | Railway service `Postgres` | volume-backed, 500 MB tier | private host `postgres.railway.internal:5432/railway`; public proxy for admin ops |
| Redis | Railway service `Redis` | — | OTP store, BullMQ |
| Web console | Vercel project `vidyatrack-web` | — | Next.js; `NEXT_PUBLIC_API_URL` baked at build time |
| Android APK | GitHub Releases | tag `v1.0.0-deploy` | debug-signed (sideload only) |

**URLs:** API https://api-production-28467.up.railway.app · web https://vidyatrack-web.vercel.app

**Health check (do this first, always):**
```bash
curl -s https://api-production-28467.up.railway.app/api/v1/health
```
Expect `{"status":"ok","db":"up",…}`. `"db":"down"` = API is up but Postgres is unreachable → §8.

---

## 2. Deploy

**API — deploys automatically on push to `main`** (Railway watches the repo). To watch or force:
```bash
cd "/Users/riteshkumar/schoolplix app"
railway logs --service api            # build + runtime logs
railway redeploy --service api        # re-run the LATEST deployment (not a rollback)
```

**Web console — auto-deploys on push to `main`.** Manual:
```bash
cd apps/web
vercel --prod --yes
```

> ⚠️ `NEXT_PUBLIC_*` vars are **inlined at build time**. Changing `NEXT_PUBLIC_API_URL` requires a rebuild, not just a var change.

**After any API env-var change**, Railway restarts the service automatically — confirm with the health check.

---

## 3. Rollback

**Web (fast, reliable):**
```bash
vercel rollback <deployment-url-or-id>   # from `vercel ls`
vercel rollback status
```

**API:** the CLI's `redeploy` only re-runs the *latest* deployment, so a true rollback is a **dashboard action**: Railway → project `vidyatrack` → service `api` → Deployments → pick a previous successful build → Redeploy. Alternative (git-based): `git revert <bad-commit> && git push` and let auto-deploy carry it.

**Last resort:** `railway down` removes the most recent deployment — leaves the service without a running instance. Only if a bad build must be stopped immediately and you'll redeploy right after.

---

## 4. Database: apply schema / migrate

Schema changes live in `apps/api/src/database/schema.sql` (+ `rls-setup.sql`). Both are idempotent and re-runnable. `apply-db.js` creates the `vidyatrack_app` role first, then applies both in order.

**Against production:**
```bash
# Get the public (proxy) admin connection string from Railway:
railway variables --service Postgres --json    # use DATABASE_PUBLIC_URL

cd apps/api
DATABASE_ADMIN_URL="postgresql://…public-proxy…" npm run db:apply
```

**Against local:**
```bash
cd apps/api && npm run db:apply     # reads apps/api/.env
```

**After any schema/policy change, re-verify tenancy:**
```bash
cd apps/api && npm run test:e2e -- rls-isolation   # must be 5/5
```

> Two connections by design: `DATABASE_ADMIN_URL` (superuser — DDL, role creation, seeds) and `DATABASE_URL` (`vidyatrack_app`, `NOSUPERUSER`/`NOBYPASSRLS` — the runtime, so RLS actually binds). Don't point the API at the admin URL; it would silently bypass every tenant policy.

---

## 5. Credentials & secrets

**Where they live:** Railway service-variable UI only (`JWT_SECRET`, `JWT_REFRESH_SECRET`, `DATABASE_URL` containing the `vidyatrack_app` password). Not in the repo, not in these docs.

**Read them:** `railway variables --service api`

**Rotate JWT secrets** (invalidates all existing sessions — everyone re-logs in):
```bash
railway variables --service api \
  --set "JWT_SECRET=$(openssl rand -hex 32)" \
  --set "JWT_REFRESH_SECRET=$(openssl rand -hex 32)"
```

**Rotate the app DB-role password** (two steps — must be done together or the API loses its DB):
1. `ALTER ROLE vidyatrack_app PASSWORD '<new>'` via the admin/public connection.
2. Update `DATABASE_URL` on the `api` service with the same password.

> `ALTER ROLE` is a utility statement — **no bind parameters**. Inline the value (use a hex-only password so it's injection-safe).
>
> Note the default password for `vidyatrack_app` is hardcoded in the public `rls-setup.sql` (fine for local dev). Production was rotated off it — keep it that way.

**Bootstrap / reset the super-admin** (creates only the platform owner, no demo data):
```bash
cd apps/api
DATABASE_ADMIN_URL="…" SUPER_ADMIN_PASSWORD='<strong>' npm run bootstrap:prod
```

---

## 6. The demo school

Public demo data lives under school code `VDTRK2627DEMO01`. Anyone with the app can mutate it.

**Reseed it** (⚠️ **wipes that school's tenant data**, recreates 3 classes × 2 sections × 40 students, ~1 month of attendance, fees/payments — and **resets `founder@vidyatrack.in`'s password to `Demo@1234`**):
```bash
cd apps/api
DATABASE_ADMIN_URL="…public-proxy…" npm run seed
```

> 🚨 **Never run `npm run seed` against production expecting it to be additive.** It is destructive and hardcoded to the demo school code. If a real school ever exists in that database, confirm the seed's scope before running it. V4 §A3 adds a demo-scoped reset endpoint with a guardrail that refuses any other school code — prefer that once it exists.

---

## 7. Mobile release

The APK bakes its API URL at **compile time** (`AppConstants.apiBaseUrl` ← `--dart-define=API_URL`), so a new URL means a new build.

```bash
export PATH="$PATH:$HOME/development/flutter/bin"
cd apps/mobile
flutter analyze                        # must be 0 errors/warnings
flutter test                           # 4/4
flutter build apk --release --dart-define=API_URL=https://api-production-28467.up.railway.app/api/v1

gh release create vX.Y.Z \
  build/app/outputs/flutter-apk/app-release.apk \
  --title "VidyaTrack vX.Y.Z" --notes "…"
```

**Installing on the emulator:** uninstall first if the previous build had a different signature or baked URL —
```bash
adb -s emulator-5554 uninstall com.vidyatrack.vidyatrack
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-release.apk
```

**Serving to a physical phone over Wi-Fi:** `./serve-apk.sh` prints a LAN URL + QR-able link (phone must be on the same network).

> APKs are **debug-signed** — fine for sideloading, not Play-Store publishable. A real upload key is a Play Store prerequisite (deferred).

---

## 8. Troubleshooting

| Symptom | Likely cause | Action |
|---|---|---|
| Health returns `"db":"down"` | Postgres asleep/restarting, or `DATABASE_URL` wrong after a rotation | `railway logs --service api`; check `Postgres` service is Online; verify `DATABASE_URL` password matches the role |
| API 500s on a write, then data missing | A failed statement rolled back the whole request transaction (by design) | Read `railway logs --service api` for the actual Postgres error — usually a type mismatch (enum cast, UUID column) |
| Web console loads but every call fails | CORS, or `NEXT_PUBLIC_API_URL` stale | API's `CORS_ORIGIN` must equal the Vercel origin exactly (no trailing slash); rebuild web if the URL changed |
| App logs in but shows no data | Tenant context/RLS — token's school has no data, or a new table lacks a policy | Re-run RLS e2e; check the table has `tenant_isolation` with the superadmin bypass |
| Parent sees another child's data | Ownership check missing on a new endpoint | Endpoints must resolve the caller's entity server-side (`assertStudentAccess`), never trust a client `studentId` |
| Login works locally, 401 in prod | JWT secrets differ / were rotated | Everyone must re-login after a rotation; confirm both secrets are set |
| Docker build fails on `npm ci` | Built with `apps/api` as context instead of repo root | Build from root: `docker build -f apps/api/Dockerfile .` |
| Uploaded file 404s after a deploy | Expected — uploads are ephemeral on Railway | Deferred by design; durable storage needs the S3/R2 driver (stub exists) |

**Log access:** `railway logs --service api` (add `--json` for machine-readable). Vercel: `vercel logs <url>` or the dashboard.

---

## 9. Known operational gaps (accepted, not forgotten)

| Gap | Risk | Mitigation / when to fix |
|---|---|---|
| **No error tracking** | A prod exception is invisible unless someone reads Railway logs | Sentry — V4 §F1 (free tier, ~10 min) |
| **No uptime alerting** | Downtime discovered by a user, not by you | UptimeRobot on `/api/v1/health` — V4 §F2 |
| **No automated DB backups** | Railway's volume is the only copy | Enable Railway backups, or a scheduled `pg_dump`. **Do this before a real school onboards.** |
| **Ephemeral uploads** | Study material/syllabus files vanish on redeploy | Acceptable for demo; S3/R2 driver before real use |
| **Single environment** | Schema changes go straight at prod | A staging Railway environment before real users |
| **Public demo is mutable** | Demo data degrades over time | V4 §A3 nightly reset |
| **Debug-signed APK** | Not Play-Store publishable | Real signing key when publishing |

---

## 10. Routine checks

**Weekly:** health endpoint · `railway logs --service api` scanned for repeated errors · demo login still works (all three roles) · Railway usage/billing.

**Before showing the project to anyone:** health check, web console login, and one mobile login — takes 60 seconds and catches a sleeping DB or expired state.

**Before onboarding a real school:** DB backups enabled · durable file storage · error tracking · a staging environment · and reconsider the mutable public demo sharing a database with real tenant data.
