# VidyaTrack — instructions for Claude Code sessions

Multi-tenant school management platform. npm-workspaces monorepo: `apps/api` (NestJS + PostgreSQL 16 with RLS + Redis), `apps/mobile` (Flutter, Android-first), `apps/web` (Next.js 14 super-admin console). **Deployed live.** Full orientation in [HANDOVER.md](HANDOVER.md); runbook in [OPERATIONS.md](OPERATIONS.md); next work in [V4-PLAN.md](V4-PLAN.md).

## House rules (non-negotiable — these were earned, not invented)

1. **Verify live, not just compiled.** Backend changes are proven with real HTTP calls against a running API *before* touching UI. Most real bugs in this project's history compiled cleanly and passed local tests.
2. **Zero dead buttons.** A screen either works or isn't reachable. No `() {}` handlers; unbuilt destinations get an honest "coming soon" screen.
3. **Gates before calling anything done:** `flutter analyze` = 0 errors/warnings (infos OK) · `next build` clean · `npm run build` (api) clean · RLS isolation e2e 5/5 (`cd apps/api && npm run test:e2e -- rls-isolation`) after *any* schema/policy change.
4. **Docs per phase:** update `CHANGELOG.md` + `FEATURE_STATUS.md` when a phase closes. Commit per logical phase.
5. **Ask before committing/pushing** unless the user explicitly asked. Never force-push `main`.
6. **New school-variable behavior goes in the settings registry** (V4 §3), never hardcoded.

## Environment facts

- **Local API:** `./start-api.sh` → :3000. Entry is `dist/src/main.js` (**not** `dist/main`). Swagger at `/api/docs` (dev only — gated behind `NODE_ENV !== 'production'`).
- **Local infra:** `docker compose up postgres redis -d`. DB apply: `cd apps/api && npm run db:apply`. Demo seed: `npm run seed`.
- **Flutter:** SDK at `~/development/flutter` (not on default PATH — `export PATH="$PATH:$HOME/development/flutter/bin"`). Emulator AVD `Pixel_9a`, 1080×2424.
- **Prod:** API `https://api-production-28467.up.railway.app` · web `https://vidyatrack-web.vercel.app` · repo `github.com/aimhackeritesh/vidyatrack`.
- **CLIs authenticated:** `gh`, `railway` (project `vidyatrack`; services `api`/`Postgres`/`Redis`), `vercel` (project `vidyatrack-web`).
- **Demo creds** (public/safe): school `VDTRK2627DEMO01`, pw `Demo@1234` — admin `9999900001`, teacher `9999900002`, parent `9999900003`; super-admin `founder@vidyatrack.in` / `Demo@1234`.
- **Prod secrets live only in Railway's env UI** — never in the repo, never in docs. Rotate rather than hunt.

## Traps — do not relearn these

- **Docker builds use the repo root as context.** `apps/api`/`apps/web` have no lockfile (hoisted to root), so `npm ci` inside them fails.
- **`schema.sql` GRANTs to `vidyatrack_app` before that role exists** — `apply-db.js` creates it first. Only fails on a genuinely fresh DB.
- **Postgres won't infer enum casts in `CASE`** → `(CASE … END)::invoice_status_enum`. Same for `role::text = ANY($1::text[])`.
- **`audit_logs.entity_id` is UUID** — passing a non-UUID string 500s and rolls back the whole transaction.
- **Do NOT migrate `DropdownButtonFormField.value` → `initialValue`.** Breaks programmatic reset. ~11 analyzer infos are expected.
- **Never run `npm run seed` against production** outside a demo-school-scoped path — it wipes tenant data, recreates 240 fake students, and resets the super-admin password.
- **Don't re-add Razorpay or any real payment gateway** unless the user confirms they now have a merchant account. `MockGateway` is deliberate.
- **UI automation:** Flutter web (CanvasKit) needs a synthetic Tab keypress before its semantics tree exists (then `input[aria-label=…]` works). `adb input` tap coords need scaling by screenshot→device ratio (~2.7× on Pixel 9a).

## Architecture invariants

- **RLS is the tenancy boundary.** Each request runs in one transaction-bound connection with `app.current_school_id`/`app.current_role` set via `set_config()`, routed through `AsyncLocalStorage` (`TenantContextInterceptor` + `TenantDb`). The API connects as non-superuser `vidyatrack_app` so policies actually bind. **Any new tenant table needs an RLS policy + superadmin bypass**, and the isolation e2e must stay green.
- **Payments are server-verified and idempotent.** Client never decides success; unique index on `fee_payments.gateway_payment_id` makes retries safe.
- **Ownership checks are explicit.** Parent/student endpoints resolve the caller's own entity server-side (`assertStudentAccess`); never trust a client-supplied `studentId`.
