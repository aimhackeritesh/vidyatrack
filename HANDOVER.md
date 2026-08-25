# VidyaTrack — Handover

> **Read this first.** One document to orient anyone — a collaborator, a fresh AI session, or future-you in three months — on what VidyaTrack is, where it lives, how to run it, what's true, what's deferred, and what to do next.
>
> **Last updated:** 2026-07-30 · **State:** V1–V3 built, deployed live, V4 planned (not started).

---

## 1. What this is

A full-stack, multi-tenant school management platform for small Indian schools (Tier 2/3, ~100–500 students) that currently run on WhatsApp groups, paper registers, and a fee notebook.

Four user roles in one mobile app (admin/principal, teacher, parent, student), plus a separate web console for the platform owner to manage multiple schools.

**Three deployables:**

| App | Stack | Where it runs |
|---|---|---|
| `apps/api` | NestJS + TypeORM + PostgreSQL 16 (RLS) + Redis/BullMQ | Railway |
| `apps/mobile` | Flutter (Android-first), Riverpod, go_router | Sideloaded APK (GitHub Release) |
| `apps/web` | Next.js 14, Tailwind, Recharts | Vercel |

npm workspaces monorepo (`apps/api`, `apps/web`); Flutter is outside the npm workspace.

---

## 2. Status at a glance — it's live

| Piece | URL | Verified |
|---|---|---|
| **API** | https://api-production-28467.up.railway.app | `/api/v1/health` → `{"status":"ok","db":"up"}` |
| **Web console** | https://vidyatrack-web.vercel.app | 200 |
| **Android APK** | [Release v1.0.0-deploy](https://github.com/aimhackeritesh/vidyatrack/releases/tag/v1.0.0-deploy) | Installed + logged in on emulator against live API |
| **Repo** | https://github.com/aimhackeritesh/vidyatrack (public) | branch `main`, latest `ab54c49` |

**Demo credentials** (public, seeded fake data — safe to share):
- Mobile app: school code `VDTRK2627DEMO01`, password `Demo@1234` — admin `9999900001`, teacher `9999900002`, parent `9999900003`
- Web console (super-admin): `founder@vidyatrack.in` / `Demo@1234`

Login is **password-only** in this deployment (no SMS provider wired). Fee payment uses a **mock gateway** (no merchant account). Uploaded files are **ephemeral** (lost on redeploy).

---

## 3. Document map — what to read for what

| Doc | Use it for | Trust |
|---|---|---|
| **HANDOVER.md** (this) | Orientation, access, traps, next steps | ✅ current |
| **[CLAUDE.md](CLAUDE.md)** | Rules + env facts auto-loaded into Claude Code sessions | ✅ current |
| **[OPERATIONS.md](OPERATIONS.md)** | Runbook: deploy, rollback, DB apply, demo reset, releases, troubleshooting | ✅ current |
| **[V4-PLAN.md](V4-PLAN.md)** | **The next body of work** — differentiation, config system, UX. Not started. | ✅ current spec |
| **[V4-AGENT-BRIEF.md](V4-AGENT-BRIEF.md)** | Kickoff instructions for the agent implementing V4 | ✅ current |
| **[README.md](README.md)** | Public-facing pitch + live demo links (this is what recruiters/visitors see) | ✅ current |
| **[SETUP.md](SETUP.md)** | Full local dev setup, step by step | ✅ current |
| **[CHANGELOG.md](CHANGELOG.md)** | What shipped when, **including bugs found during live verification** — the most useful history | ✅ current |
| **[FEATURE_STATUS.md](FEATURE_STATUS.md)** | Per-screen/per-button status matrix across all roles | ✅ current |
| **[DEPLOYMENT-PLAN-V1.md](DEPLOYMENT-PLAN-V1.md)** | How the deploy was done + what was deferred and why | ✅ current |
| [V3-PLAN.md](V3-PLAN.md), [V2-IMPROVEMENT-PLAN.md](V2-IMPROVEMENT-PLAN.md) | Historical specs for prior versions | 📁 historical |
| [PROJECT-STATUS-REPORT.md](PROJECT-STATUS-REPORT.md) | ⚠️ **Stale** (June 12, V2-era). It calls itself "single source of truth" — it is no longer. Use CHANGELOG + FEATURE_STATUS instead. | ⚠️ stale |

---

## 4. Access & accounts

**Already authenticated on this Mac** (no re-auth needed unless tokens expire):

| Tool | Account | Used for |
|---|---|---|
| `gh` | `aimhackeritesh` | repo, releases |
| `railway` | `RITESH3545KUMAR@GMAIL.COM` | API + Postgres + Redis (project `vidyatrack`, services: `api`, `Postgres`, `Redis`) |
| `vercel` | `aimhackeritesh` | web console (project `vidyatrack-web`) |

**Where secrets live:** production `JWT_SECRET`, `JWT_REFRESH_SECRET`, and the `vidyatrack_app` DB password exist **only** in Railway's service-variable UI. They are deliberately **not** in the repo and not in any doc. If you need them, read them from Railway; if they're lost, rotate (see OPERATIONS.md §5) rather than hunting.

**Not set up (deliberate):** Sentry, uptime monitoring, automated DB backups, Play Store account, custom domain. See §7.

---

## 5. Run it locally (short version)

Full detail in [SETUP.md](SETUP.md). Fast path:

```bash
docker compose up postgres redis -d      # Postgres 16 + Redis
npm install
cp apps/api/.env.example apps/api/.env   # then set JWT secrets
cd apps/api && npm run db:apply && npm run seed && cd ../..
npm run api                              # API :3000 (Swagger /api/docs in dev)
npm run web                              # console :3001
```

Mobile:
```bash
cd apps/mobile && flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:3000/api/v1   # Android emulator
```

`./start-api.sh` restarts a built API against the Docker DB (useful after a Mac sleep). Note the entry is `dist/src/main.js`, **not** `dist/main`.

---

## 6. Architecture — the two things that actually matter

**1. Multi-tenancy is enforced by the database, not the application code.**
Every authenticated request opens one transaction-bound Postgres connection, sets `app.current_school_id` / `app.current_role` on it via `set_config()`, and routes every query for that request onto that exact connection through `AsyncLocalStorage` (`TenantContextInterceptor` + `TenantDb`). The API connects as `vidyatrack_app` — `NOSUPERUSER`/`NOBYPASSRLS` — so Row-Level Security policies are genuinely enforced (a superuser would silently bypass them). A super-admin request opens a context flagged `superadmin`, which the policies allow to cross tenants.

Consequence: **if you add a tenant table, it needs an RLS policy**, and `apps/api/test/rls-isolation.e2e-spec.ts` must stay green (5/5). That test is the guard on the whole model.

**2. Payments are server-verified and idempotent.**
The client never decides whether a payment succeeded. A `PaymentGateway` interface abstracts the provider; `MockGateway` simulates the order→verify round-trip (no merchant account needed). A unique index on `fee_payments.gateway_payment_id` makes retries safe. A real provider plugs into the same interface without touching `FeesService`.

---

## 7. What's shipped vs. deferred

**Shipped and working** (see FEATURE_STATUS.md for the button-level matrix): attendance (bulk marking, offline queue, holidays, defaulters), fees (admin-set structure → idempotent invoice generation → parent dues → mock online payment → receipts), academics (homework, study material with upload, syllabus, timetable, exam results), communication (notices, circulars, leave workflow, suggestions, notification fan-out), student lifecycle (credential slips, bulk CSV import, forced password change), and the super-admin platform layer (create/suspend schools, analytics, feature flags, broadcast, audit log).

**Deferred, with reasons:**

| Deferred | Why | Unblocked by |
|---|---|---|
| Real SMS OTP | No paid SMS account; login is password-only | MSG91/Twilio account |
| Real payment gateway | No merchant account (Razorpay was removed) | Merchant account |
| Durable file uploads | Ephemeral local disk on Railway; `S3StorageDriver` is a throwing stub | R2/S3 bucket + ~1h work |
| Play Store listing | $25 + review + privacy policy + signing key | A real school committing |
| Sentry / uptime / backups | Free accounts, not yet created | 10 min signup each (V4 §F) |
| Custom domain | Platform subdomains work fine for now | ~₹800/yr |

---

## 8. Known traps — hard-won, don't relearn these

1. **`dist/src/main.js`, not `dist/main`** — Nest compiles `src/` into `dist/src/`. This broke the first Docker image.
2. **Docker builds must use the repo root as context.** `apps/api` and `apps/web` have no lockfile (npm workspaces hoist it to root), so `npm ci` inside them hard-fails. Both Dockerfiles build from root; `.dockerignore` keeps the 2.5 GB mobile build dir out.
3. **`schema.sql` GRANTs to `vidyatrack_app` before the role exists.** `apply-db.js` creates the role first. This only fails on a *truly fresh* database — it passed locally for months because the role already existed.
4. **Postgres won't infer enum casts in a `CASE`.** Use `(CASE … END)::invoice_status_enum`. Same for `role::text = ANY(...)`. Both caused real 500s.
5. **`audit_logs.entity_id` is a UUID** — passing a date string 500s (and rolls back the whole transaction, which is how a batch of 80 invoice inserts silently vanished once).
6. **Don't "fix" `DropdownButtonFormField.value` → `initialValue`.** The deprecation warnings are intentional; migrating breaks programmatic reset. ~11 analyzer infos are expected and fine.
7. **`flutter analyze` must be 0 errors/warnings** (infos OK). Web support wasn't in the repo originally — added via `flutter create . --platforms=web`.
8. **CanvasKit/emulator UI automation:** Flutter web needs a synthetic Tab keypress before its real semantics tree exists (then `input[aria-label=…]` works). On the Android emulator, `adb input` tap coordinates must be scaled by screenshot→device ratio (~2.7× on the Pixel 9a at 1080×2424).
9. **Never run the demo seed against production** outside a demo-school-scoped path — `seed.ts` **wipes** the school's tenant data and recreates 240 fake students. Also note it resets `founder@vidyatrack.in`'s password to `Demo@1234`.
10. **Verify live, not just compiled.** Every bug in traps 3–5 compiled cleanly and passed local tests. The house rule "backend verified with real HTTP calls before touching UI" exists because it kept working.

---

## 9. What to do next

**[V4-PLAN.md](V4-PLAN.md) is the next body of work.** It's a complete spec; nothing in it has been started. Headline of it:

- **The School Configuration System** — a typed settings registry making per-school behavior (periods/day, fee fines, attendance thresholds, grading display, branding, language) data instead of code. Audit confirmed the `school_settings` table exists but only **one** setting is consumed anywhere; the rest is hardcoded. This is both the owner-experience win and the competitive moat.
- **Instant access** — a public landing page (today the Vercel root is an admin login form), one-tap in-app demo login, nightly demo reset.
- **Owner console v2** — impersonation ("manage as this school's admin"), per-school detail page, reset any user's credentials, CSV export.
- **UX** — new-school setup checklist, per-school branding, empty-state sweep, notification deep links.
- **Hindi (i18n)** for the parent/teacher core.
- **Reliability** — Sentry, uptime check, one-command release script.

Six phases (V4.0–V4.6), config system first. To start: hand [V4-AGENT-BRIEF.md](V4-AGENT-BRIEF.md) to the implementing agent.

**Four small decisions** are pending in V4-PLAN §7 (Sentry account, UptimeRobot, Play Store timing, custom domain). Phases V4.0–V4.3 need none of them, so work can start before deciding.

---

## 10. How this project has been built (working style that worked)

Each version followed the same loop, and it's worth keeping:

**Plan in a `.md` first → build backend → verify live with real HTTP calls → build UI → `flutter analyze`/`next build` clean → update CHANGELOG + FEATURE_STATUS → commit per phase.**

Two rules did most of the heavy lifting:
- **Zero dead buttons** — a screen either works or isn't reachable. No `() {}` handlers.
- **Live verification is the definition of done** — every significant bug in §8 passed compilation and local tests before a real environment caught it.

History: V1 (M0 scaffold + core modules) → V2 (roles, credentials, attendance v2, revenue, comms) → V3 (timetable, syllabus, material, fees end-to-end, super-admin) → V1 deploy (Railway + Vercel + APK) → V4 planned.
