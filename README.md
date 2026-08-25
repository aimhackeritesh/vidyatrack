# VidyaTrack

A full-stack, multi-tenant school management platform — Flutter mobile app, NestJS API, and a Next.js super-admin console, backed by PostgreSQL with Row-Level Security for tenant isolation.

Built for small Indian schools (Tier 2/3) that need digital attendance, fees, and parent communication without the overhead of enterprise school-ERP software.

## 🚀 Live demo

| Piece | Link |
|---|---|
| **Super-admin web console** | https://vidyatrack-web.vercel.app |
| **API health** | https://api-production-28467.up.railway.app/api/v1/health |
| **Android app (APK)** | See the latest [GitHub Release](https://github.com/aimhackeritesh/vidyatrack/releases) |

**Demo credentials** (this is a public demo with seeded fake data — it may be reset periodically):

- **Web console** (super-admin): `founder@vidyatrack.in` / `Demo@1234`
- **Mobile app**: School Code `VDTRK2627DEMO01`, password `Demo@1234` for all — Admin phone `9999900001`, Teacher `9999900002`, Parent `9999900003`.

> Deployed on Railway (API + Postgres + Redis) and Vercel (web). Login is password-based in this deployment (SMS OTP isn't wired). Uploaded files are ephemeral, and the in-app fee payment uses a mock gateway (no real money).

## What it does

**For a single school** (admin / teacher / parent / student roles):
- Attendance — bulk daily marking, offline queue with sync, monthly registers, holiday calendar, defaulters report
- Fees — admin-defined fee structure (per-class, monthly/quarterly/annual/one-time), idempotent monthly invoice generation, parent-facing pending-dues view, in-app online payment with server-verified gateway callbacks and receipts
- Academics — homework, study material (file upload), syllabus tracking, exam results/report cards, class timetable
- Communication — notices, circulars, leave applications with approval workflow, suggestions inbox, in-app notification fan-out
- Student lifecycle — credential provisioning (auto-generated login IDs for students/parents), bulk CSV import, forced first-login password change

**Platform layer** (super-admin, cross-school):
- Create/suspend schools, reset principal credentials, set per-school plans and student limits
- Cross-tenant analytics (active students, revenue, users by role, invoice completion)
- Per-school feature flags
- Broadcast notices across chosen schools/roles
- Audit log of every platform-level action

## Architecture

```
apps/
├── api/      NestJS + TypeORM + PostgreSQL 16, Redis/BullMQ    → REST API
├── mobile/   Flutter (Android-first)                            → student/parent/teacher/admin app
└── web/      Next.js 14                                         → super-admin console
```

**Multi-tenancy is enforced at the database, not just the application.** Every authenticated request runs inside a single transaction-bound Postgres connection (`TenantContextInterceptor`) with `app.current_school_id` / `app.current_role` set via `set_config()`. All queries for that request are routed onto that exact connection via `AsyncLocalStorage`, so tenant context can never drift onto a different pooled connection. The API connects as a non-superuser role (`vidyatrack_app`, `NOSUPERUSER`/`NOBYPASSRLS`), so Postgres Row-Level Security policies are actually enforced — not just decorative. Cross-tenant isolation is covered by an automated e2e suite (`apps/api/test/rls-isolation.e2e-spec.ts`).

**Payments are idempotent and server-verified.** The client never determines whether a payment succeeded — a `PaymentGateway` interface abstracts the provider, with a `MockGateway` behind it that simulates a real gateway's order → verify round-trip for local demo (no merchant account required), and a unique constraint on the gateway's payment ID makes webhook retries safe. A real provider (Razorpay, Stripe, etc.) plugs into the same interface later without touching any other code. Invoice generation is similarly idempotent: re-running it for a month only touches invoices still in `pending` status.

## Tech stack

| Layer | Stack |
|---|---|
| Mobile | Flutter, Riverpod, go_router, Dio |
| API | NestJS, TypeORM, PostgreSQL 16 (RLS), Redis + BullMQ, JWT auth, Argon2 |
| Web | Next.js 14, Tailwind, Recharts |
| Infra | Docker Compose, GitHub Actions CI |

## Getting started

See [SETUP.md](SETUP.md) for full local setup (Docker Postgres/Redis, seeding demo data, running each app). Short version:

```bash
docker compose up postgres redis -d
npm install
cp apps/api/.env.example apps/api/.env   # set JWT secrets
cd apps/api && npm run seed && cd ../..
npm run api    # API on :3000, Swagger at /api/docs
npm run web    # super-admin console on :3001
```

Demo school code `VDTRK2627DEMO01`, all demo accounts use password `Demo@1234` (see `apps/api/src/database/seed.ts` for phone numbers per role).

## Project docs

**Start here if you're picking the project up:**
- [HANDOVER.md](HANDOVER.md) — orientation: current state, access, architecture, known traps, what's next
- [OPERATIONS.md](OPERATIONS.md) — runbook: deploy, rollback, DB apply, demo reset, releases, troubleshooting
- [SETUP.md](SETUP.md) — full local development setup

**History and status:**
- [CHANGELOG.md](CHANGELOG.md) — what shipped, in what order, including bugs caught during live verification
- [FEATURE_STATUS.md](FEATURE_STATUS.md) — per-screen/button status across every role
- [DEPLOYMENT-PLAN-V1.md](DEPLOYMENT-PLAN-V1.md) — how the live deployment was done, and what was deferred

**Roadmap:**
- [V4-PLAN.md](V4-PLAN.md) — next version: per-school configuration system, instant-demo access, owner console v2, Hindi
- [V4-AGENT-BRIEF.md](V4-AGENT-BRIEF.md) — implementation brief for the V4 work
- [V3-PLAN.md](V3-PLAN.md) · [V2-IMPROVEMENT-PLAN.md](V2-IMPROVEMENT-PLAN.md) — prior version specs (historical)
