# VidyaTrack — M0 Setup Guide

## Prerequisites
- Node.js 20+, npm 10+
- Docker + Docker Compose
- Flutter 3.22+ (for mobile development)
- Android Studio or VS Code with Flutter plugin

---

## 1. Clone & install root deps
```bash
git init
git add .
git commit -m "M0: initial scaffold"
npm install   # installs API + web workspaces
```

---

## 2. Start infrastructure (Postgres + Redis)
```bash
docker compose up postgres redis -d
# On first boot Postgres auto-runs, in order:
#   01_schema.sql    — tables, functions, RLS policies
#   02_rls-setup.sql — the least-privilege `vidyatrack_app` role + grants
```

> Applying to an **already-initialised** database (init scripts only run on an
> empty volume)? Run the role/policy setup once by hand:
> ```bash
> docker exec -i vidyatrack-postgres psql -U vidyatrack -d vidyatrack \
>   < apps/api/src/database/rls-setup.sql
> ```

---

## 3. Configure API environment
```bash
cp apps/api/.env.example apps/api/.env
# Edit apps/api/.env — set JWT secrets at minimum
```

The API uses two database connections:
- `DATABASE_URL` → `vidyatrack_app` (NOSUPERUSER / NOBYPASSRLS) — the runtime
  role, so Postgres Row-Level Security is actually enforced on every request.
- `DATABASE_ADMIN_URL` → `vidyatrack` (superuser) — used only by `npm run seed`
  and migrations, which must bypass RLS to write tenant rows / run DDL.

---

## 4. Seed demo data
```bash
cd apps/api
npm install
npm run seed
```

Output:
```
✅  Demo seed complete
   School Code : VDTRK2627DEMO01
   Admin       : phone=9999900001  password=Demo@1234
   Teacher     : phone=9999900002  password=Demo@1234
   Parent      : phone=9999900003  password=Demo@1234
```

---

## 5. Start API in dev mode
```bash
npm run api          # from monorepo root
# or:
cd apps/api && npm run start:dev
```
API: http://localhost:3000  
Swagger docs: http://localhost:3000/api/docs

---

## 6. Run Flutter app
```bash
cd apps/mobile
flutter pub get
flutter run          # connects to http://10.0.2.2:3000 (Android emulator)
                     # use --dart-define=API_URL=http://<your-ip>:3000/api/v1 for real device
```

**Demo login:**
1. School Code: `VDTRK2627DEMO01`
2. Phone: `9999900001`
3. OTP: check API console log — e.g. `[DEV OTP] 9999900001 → 482931`

---

## 7. Start web admin (optional)
```bash
npm run web   # from monorepo root — opens on http://localhost:3001
```

---

## 8. Run full stack with Docker
```bash
docker compose up --build
```

---

## 9. Run tests
```bash
# API unit tests
cd apps/api && npm test

# RLS isolation e2e (requires running Postgres + a vidyatrack_test database)
cd apps/api
docker exec -i vidyatrack-postgres psql -U vidyatrack -d postgres \
  -c 'CREATE DATABASE vidyatrack_test;'
docker exec -i vidyatrack-postgres psql -U vidyatrack -d vidyatrack_test \
  < src/database/schema.sql
docker exec -i vidyatrack-postgres psql -U vidyatrack -d vidyatrack_test \
  < src/database/rls-setup.sql
npm run test:e2e
# Connects as vidyatrack_app (RLS enforced) and asserts cross-tenant isolation.
# Override targets with TEST_DATABASE_URL / TEST_DATABASE_ADMIN_URL if needed.

# Flutter
cd apps/mobile && flutter test
```

---

## Architecture at a glance

```
monorepo/
├── apps/
│   ├── api/        NestJS + TypeORM + PostgreSQL 16 (RLS)
│   ├── mobile/     Flutter 3.22 — Android-first, offline-capable
│   └── web/        Next.js 14 — Super-admin panel
├── docker-compose.yml
└── .github/workflows/ci.yml
```

### Key API endpoints (v1)
| Method | Path | Description |
|--------|------|-------------|
| POST | /auth/send-otp | Send OTP to phone |
| POST | /auth/verify-otp | Verify OTP → JWT |
| POST | /auth/login-password | Password fallback |
| POST | /auth/refresh | Refresh access token |
| GET | /schools/profile | School details |
| GET | /classes | List classes |
| GET | /classes/sections | List sections |
| GET | /students | List students (filterable) |
| GET | /students/search | Global search |
| POST | /attendance/sessions | **Bulk submit attendance (60-student single call)** |
| GET | /attendance/section | Roster with attendance status |
| GET | /attendance/dashboard | 7-day chart data |
| GET | /fees/daily-revenue | Daily revenue summary |
| POST | /fees/payments | Record payment |
| POST | /notifications/notices | Send notice |

### Multi-tenancy
Each authenticated request runs inside one transaction-bound connection opened
by `TenantContextInterceptor`, which sets `app.current_school_id` /
`app.current_role` (via `set_config(..., true)`) on that exact connection.
`TenantDb` then routes every query in the request onto it through
`AsyncLocalStorage`, so the session variables and the data queries can never
drift onto different pooled connections.

Because the runtime connects as the non-superuser `vidyatrack_app` role, the RLS
policies are actually enforced (a superuser would silently bypass them). Tables
with a `school_id` column filter by `school_id = current_school_id()`; child
tables without one (`attendance_records`, `exam_results`, `poll_votes`) derive
their tenant from the parent row. Policies + role live in
`src/database/rls-setup.sql`; cross-tenant leakage is tested in
`test/rls-isolation.e2e-spec.ts`.

### Offline attendance
The Flutter app uses SQLite (sqflite) as an offline queue.  
Submissions made without connectivity are stored locally and synced on reconnect.  
Sync status is shown in the attendance screen ("3 pending uploads").

---

## M1 → M5 roadmap
See `PRD-school-attendance-app.md` for the full milestone plan.  
Next up: finish Fees UI, Homework, Study Material, Notices, Leave Management.
