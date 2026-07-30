# Changelog

All notable changes to VidyaTrack. Format loosely follows Keep a Changelog.

## [Unreleased] — V4.0: The School Configuration System (2026-07-30)

First phase of [V4-PLAN.md](V4-PLAN.md) (workstream B1–B4). School-variable behaviour becomes **typed data instead of code**: a registry in the API, one bootstrap call for clients, and the previously-hardcoded consumers migrated onto it. Adding new per-school variability now costs one registry entry.

### Added
- **`apps/api/src/config/settings-registry.ts`** — 16 typed settings (`int`/`bool`/`string`/`enum`/`time`/`json`/`color`) with defaults, labels, help text, category, `editableBy`, and range/enum validation. Framework-free so it's unit-testable and script-importable.
- **`SchoolConfigService`** — merges registry defaults with a school's `school_settings` overrides into one typed object plus a `version` hash. Redis-cached per school (5 min TTL, invalidated on write); cache read/write failures degrade to a Postgres read rather than a 500. Reads go through `TenantDb`, so RLS governs them like every other query. No schema change.
- **`GET /schools/config`** (admin/teacher/parent/student) — the client bootstrap: complete typed config + `version`, one round-trip, no per-screen setting lookups.
- **`GET /superadmin/settings-registry`** — the catalog, so the console (V4.1) renders types/labels/ranges from the API instead of hardcoding them.
- **`GET /superadmin/schools/:id/config`** — a school's effective config as its apps see it.
- Mobile: `SchoolConfig` model + `schoolConfigProvider` (fetch on login and app start, SharedPreferences-cached against `version`, last-known-config fallback when offline) and `schoolConfigValueProvider` for a synchronous read that falls back to registry defaults — config never blocks or breaks a screen.
- 5 unit tests covering config parsing, defaults, working-day mapping, wrong-typed values, and cache round-trip/corruption.

### Changed
- **Settings writes are now validated.** `PATCH /superadmin/schools/:id/settings` 400s on an unknown key or an out-of-range/ill-typed value; before, any key/value was accepted, so a typo'd key silently did nothing forever. Values are canonicalised on write (`#ab12cd` → `#AB12CD`, `yes` → `true`).
- **Consumers migrated off hardcoded values:** invoice due date (`fees.due_date_day`), defaulters threshold (`attendance.defaulter_threshold`, 4 sites incl. the mobile default), timetable periods (`timetable.periods_per_day`, was `List.generate(8, …)`), and timetable day tabs (`academic.working_days`, was a fixed Mon–Sat × 6).
- `GET /attendance/defaulters` without a `threshold` param now uses the school's configured threshold instead of a hardcoded 75. An explicit param still wins.
- The timetable editor's `_editSlot` takes the day as a parameter rather than reading `_selectedDay`, so the day written always matches the day displayed once working days are configurable.
- The defaulters dropdown folds the school's configured threshold into its preset options — a configured value like 65 isn't in `[60,70,75,80,90]`, and `DropdownButton` asserts when `value` isn't among `items`.

### Fixed (found by verifying live, not by compiling)
- **Defaulters report red-screened on every row.** `defaulters_screen.dart` cast `pct` with `as num?`, but that column is a Postgres `ROUND(…)::NUMERIC`, which node-postgres returns as a **String** to preserve precision → `type 'String' is not a subtype of type 'num?' in type cast`. Latent since the screen shipped: the seeded demo data has no student below 75%, so the list was always empty and the cast never executed. Raising `attendance.defaulter_threshold` to 90 made 138 rows reachable and the screen crashed instantly. Now `double.tryParse`, matching the correct idiom already used in `attendance_chart_card.dart:54`. Checked the other four `as num` sites in the app: only this one reads a NUMERIC column — `my_attendance_screen.dart:69` reads a JS-computed number and is safe.

### Notes / found while building
- The registry ships 16 settings but only **4 are consumed** in this phase (working days, periods/day, defaulter threshold, fee due date). Each entry carries a `consumed` flag, surfaced in the catalog, so the V4.1 console can badge the rest rather than let the owner change a value and wonder why nothing happened. `grading.*`, `features.*`, `branding.*`, `locale.language` and `fees.late_fine_per_day` have **no consumer anywhere in the codebase yet** — they land in V4.3/V4.4.
- **Legacy key migration:** the one pre-V4 setting was stored un-namespaced as `due_date_day`, not `fees.due_date_day` as V4-PLAN §3.2 assumed. `SettingDef.legacyKey` reads the old row as a fallback (namespaced wins), so live schools keep their setting with no data surgery, and the next edit rewrites it under the registry key.
- `academic.working_days` does **not** feed the attendance-percentage denominator as V4-PLAN §3.2 claims — that percentage is computed from the `attendance_sessions` rows that exist, not from a working-days calendar. Only the timetable day tabs consume it. Left as-is (correct behaviour); noted so the plan isn't trusted over the code.
- `AttendanceService.exportDefaultersCsv` and `exportRegisterCsv` are **unreachable dead code** — no controller route, no client caller. So V4-PLAN G11 ("no data export anywhere") is right from a user's point of view; V4.3/C4 should wire these rather than write new ones.
- `ValidationResult` is a flat `{ok, value?, error?}` rather than a discriminated union because `apps/api` compiles with `strictNullChecks: false`, under which `if (!result.ok)` doesn't narrow a `{ok:true}|{ok:false}` union.
- The new module is `SchoolConfigModule`, not `ConfigModule` — `@nestjs/config`'s `ConfigModule` is already imported globally in `app.module.ts`.

### Verified live (local API + Docker Postgres/Redis, real HTTP calls)
- `GET /schools/config` returns all 16 settings correctly typed (ints as ints, `academic.working_days` as an array, `grading.bands` as an object) plus a version hash.
- `PATCH timetable.periods_per_day=6` → the next `GET /schools/config` reports 6 and a new version hash (cache invalidation works, no restart needed).
- Validation: unknown key → 400 with a pointer to the registry; `periods_per_day=99` (max 12) → 400; `show_logo=maybe` → 400; `primary_color=blue` → 400; `#ab12cd` → 200 stored as `#AB12CD`. Config unchanged after every rejected write.
- **Real consumer, invoices:** `fees.due_date_day=5` → generating 2026-09 produced 240 invoices all due 2026-09-05; `=20` → 2026-10 produced 240 all due 2026-10-20.
- **Real consumer, defaulters:** with the setting at 90 the no-param report returned 138 students (matching an explicit `?threshold=90`); at 50 it returned 0 (matching `?threshold=50`). An explicit param still overrides the setting.
- **Legacy fallback:** no rows → 10 (default); a bare `due_date_day=20` row only → 20; then a namespaced write of 5 → 5, with the legacy row left untouched.
- Roles: parent gets 200 on `/schools/config`; a school admin gets 403 on both superadmin settings endpoints; no token gets 401. Every write wrote a `settings.update` audit row with the canonicalised key and value.
- **On a real Android emulator** (Pixel-class 1080×2424, debug build against the local API): logged in as the demo admin, opened the timetable editor for Class 1 / Section A. With `periods_per_day=6` the editor rendered periods 1–6; after setting `=10` and `academic.working_days=["mon","wed","fri"]` and restarting the *same binary*, it rendered periods 1–10 with day tabs Mon/Wed/Fri instead of Mon–Sat. With `defaulter_threshold=90` the defaulters screen opened on "Below 90% · 138 students" — matching the API exactly — and listed rows at 85.2%.
- Gates: `npm run build` (api) clean · `next build` (web) clean · RLS isolation e2e **5/5** · `flutter analyze` **0 errors / 0 warnings** (11 expected infos) · `flutter test` **9/9**.

## [v1.0.0-deploy] — First live deployment (2026-07-18)

Full plan in `DEPLOYMENT-PLAN-V1.md`. The API, super-admin web console, Postgres, and Redis are now live on the public internet; the Android app is a downloadable GitHub Release built against the deployed API.

**Live:** API https://api-production-28467.up.railway.app · web https://vidyatrack-web.vercel.app · APK [v1.0.0-deploy release](https://github.com/aimhackeritesh/vidyatrack/releases/tag/v1.0.0-deploy)

### Added
- `GET /api/v1/health` (DB ping) for platform health checks.
- `apps/api/scripts/apply-db.js` (idempotent schema+RLS apply against any managed Postgres) and `scripts/bootstrap-prod.js` (creates only the founder super-admin — no demo data), both plain node+pg so they run without the full Nest build.
- `railway.json` (build/healthcheck config), `.dockerignore`, `apps/web/next.config.js` (`output: 'standalone'`), `.env.production.example`.
- Mobile: password-only login screen (School Code + phone-or-login-ID + password), replacing the OTP flow that has no SMS provider in this deployment. Default `API_URL` now points at the deployed API.
- README "🚀 Live demo" section with URLs and credentials.

### Fixed (found by actually deploying, not local testing)
- **Both Dockerfiles were broken.** API `CMD` pointed at `dist/main` — the real compiled entry is `dist/src/main.js`. Both API and web Dockerfiles ran `npm ci` inside `apps/api`/`apps/web`, which have no lockfile (workspaces hoist it to the repo root) — `npm ci` hard-fails without one. Reworked both to build from the repo root.
- Web Dockerfile expected `.next/standalone`, which Next never emitted without `output: 'standalone'` in `next.config.js` (the file didn't exist).
- `apply-db.js`: `schema.sql` GRANTs privileges to `vidyatrack_app` before `rls-setup.sql` creates that role. Worked locally only because the role already existed from a prior run — failed outright on a truly fresh Railway Postgres ("role vidyatrack_app does not exist"). Now creates the role first.
- Swagger was reachable in prod by default; gated behind `NODE_ENV !== 'production'`.
- The `vidyatrack_app` DB password defaulted to a value committed in `rls-setup.sql` (fine for local dev, not for a public database) — rotated to a strong random value for the deployed instance.

### Verified live (against the actual deployed infra, not local)
- RLS deny-by-default holds on the Railway Postgres: connecting as `vidyatrack_app` with no tenant context returns 0 rows.
- Cross-origin login from the Vercel web console to the Railway API returns 201 with the correct `Access-Control-Allow-Origin`; an untrusted origin does not get its own origin reflected back (browser blocks it).
- Full round trip on a real Android emulator: uninstalled the old local-URL build, installed the release APK built against the live API, filled the new password-login form via `adb input`, logged in as the demo parent, and the Parent Dashboard rendered live from Railway — every V3 tile present, zero local services running.
- Swagger off, `/.env` unreachable, fresh JWT secrets, prod DB has exactly the demo school (240 students) + one super-admin, no leftover local-only state.

## [Unreleased] — Removed the Razorpay integration (2026-07-18)

No merchant account available yet, so the real-gateway code path was unused and untestable. Removed `RazorpayGateway`, the `razorpay` npm dependency, and the `PAYMENT_MODE` env-var branching in `PaymentModule` (now always resolves to `MockGateway`). The `PaymentGateway` interface is unchanged — a real provider still plugs in later without touching `FeesService` or any controller. Mock-mode online payment (order → verify → receipt) is unaffected and re-verified live after the change. Cleaned up leftover `RAZORPAY_*`/`PAYMENT_MODE` entries from `.env`.

## [Unreleased] — V3: Timetable, Syllabus, Study Material, Fees, Super-Admin (2026-07-16)

Every button now works for parents and admins across timetable, syllabus, study material, and fees — including admin-set fee structure, invoice generation, and parent-facing online payment. All changes verified live against Postgres; `flutter analyze` 0 errors/warnings; `next build` clean; RLS isolation 5/5.

### Added — shared infra
- **File uploads**: `StorageService` (local-disk driver, S3-adapter-ready) behind a `POST /uploads` endpoint, served at `/uploads/*`. 15MB limit, MIME whitelist.
- **Payment gateway**: `PaymentGateway` interface with `MockGateway` (default, `PAYMENT_MODE=mock`, simulates a real order→verify round-trip with no live keys) and `RazorpayGateway` (real HMAC order/verify, `PAYMENT_MODE=razorpay`).

### Added — Timetable (admin sets, all roles view)
- `POST/GET/DELETE /academics/timetable*` (single-slot upsert, bulk weekly replace, section view, viewer `/my`, teacher `/my-teaching`).
- Flutter: `EditTimetableScreen` (admin grid editor), `TimetableViewScreen` (read-only, day-tab list); wired to parent/student home tiles, teacher/admin Academics grid "Class Routine".

### Added — Syllabus & Study Material
- `POST/GET/DELETE /academics/syllabus*` (topics checklist + optional file), `/academics/materials/my` + delete.
- Flutter: `SyllabusScreen`, `StudyMaterialScreen` (browse + role-gated upload via the new `FileUploadField`); wired to parent/student/teacher/admin.

### Added — Fees (headline feature)
- **Structure**: `POST/PUT/DELETE /fees/heads`.
- **Invoice generation**: `POST /fees/invoices/generate` — idempotent (unique `school_id,student_id,month` index), quarterly/annual heads prorated evenly, one-time heads billed only on a student's first-ever invoice.
- **Parent dues**: `GET /fees/my-dues` — ownership-scoped, resolves the caller's own child server-side.
- **Online payment**: `POST /fees/pay/order` + `/pay/verify` (server-verified, idempotent on `gateway_payment_id`, amount clamped to remaining balance) + `GET /fees/receipt/:id`. Payment/admin notifications fan out on success.
- Flutter: `FeeStructureScreen` (+ Generate Invoices dialog), `ParentFeesScreen` (replaces the old placeholder Fees tab), `InvoiceDetailScreen` with mock-mode "Pay Now".

### Added — Super-Admin
- `GET /superadmin/analytics` (schools/students/users-by-role/online fee volume/invoices-this-month), `/schools/:id/stats`.
- `school_settings` key/value table for per-school feature flags; `GET/PATCH /superadmin/schools/:id/settings`.
- `POST /superadmin/broadcast` (schools × roles fan-out), `GET /superadmin/audit`.
- Next.js web: tabbed dashboard (Schools / Analytics / Broadcast / Audit Log) + a "Plan & Flags" modal per school; `next build` clean, all four tabs verified live in-browser.

### Added — button sweep
- Parent home: added Timetable, Study Material, Syllabus, and Apply Leave tiles (resolves the caller's child via `/fees/my-dues` before navigating).
- Admin Account grid: wired Total Revenue and Generate Report tiles (previously dead).

### Fixed (bugs caught during live verification, not pre-existing test coverage)
- `recomputeInvoiceStatus`: a bare `CASE ... THEN 'paid' ...` UPDATE against an enum column failed with "column is of type invoice_status_enum but expression is of type text" — Postgres doesn't infer the cast from a subquery-only CASE. Cast the whole expression: `(CASE ... END)::invoice_status_enum`. This is the shared status-recompute used by **both** admin cash collection and the new online-payment path — a real, previously-untriggered bug.
- `superadmin.broadcast`: `role = ANY($2::text[])` against a `user_role_enum` column — fixed with `role::text = ANY(...)`.
- `fees.generateInvoices` audit call passed the billing month string where `audit_logs.entity_id` (uuid) was expected — passed `null` instead and moved the month into the payload.
- **Security**: `/fees/dues?studentId=` allowed any authenticated parent to view any student's dues by ID — added ownership enforcement (`assertStudentAccess`), verified a cross-child request now returns 403.

### Verified live
- Timetable: bulk-set → admin/parent/teacher views all correct, role rejection.
- Syllabus/Study Material: upload → attach → parent `/my` sees it, role rejection.
- Fees: head CRUD, invoice generation idempotency + proration math confirmed against seed data (Postgres-level), parent `/my-dues` ownership scoping, full mock pay flow (order → verify → idempotent re-verify → receipt), overpay/already-paid rejection, revenue + notification propagation.
- Super-admin: analytics/stats/settings/broadcast/audit all exercised through the actual browser UI (not just curl), including a live "Sent to 7 users across 1 school" broadcast.
- RLS isolation e2e 5/5 green after every schema change.

---

## [Unreleased] — Flutter verification & polish (2026-06-12)

Flutter SDK installed (3.44.2) and the app **runtime-verified** end-to-end.

### Verified
- `flutter analyze`: **58 issues → 6** (0 errors, 0 warnings; the 6 remaining are intentional `DropdownButtonFormField.value` deprecations left un-migrated to avoid a controlled-reset regression).
- `flutter test`: **4/4 pass** (added `homePathForRole` logic tests, `ComingSoonScreen` + `LoginScreen` render tests, replacing the broken default template test).
- `flutter run -d web-server`: **compiled + launched + rendered** the login screen (screenshot evidence in audit).

### Fixed
- SDK-skew build errors: `CardTheme`→`CardThemeData`, stale `widget_test` `MyApp` reference.
- Migrated all `Color.withOpacity()` → `.withValues(alpha:)` (18 call sites); applied `dart fix` for `prefer_const`/unused/`!` (22 fixes); removed dead imports.

### Added — mobile (backend was already live-verified)
- **Holiday Calendar** admin screen (add via date picker / list / delete) — wired from the attendance class/section picker app bar.
- **Bulk Import** admin screen (paste CSV → per-row results + batch credentials + errors) — wired from the Add Student app bar.

---

## [Unreleased] — v2 Phase 2/4 (part): Bulk import, holidays, defaulters (2026-06-12)

### Added — backend (verified live)
- **Bulk student import** `POST /students/bulk-import` (admin): each CSV row wrapped in a `SAVEPOINT` so a bad row fails in isolation; returns batch credentials for successes + per-row errors. (2 imported, 1 bad row reported cleanly.)
- **Holiday calendar** `holidays` table + `GET/POST/DELETE /attendance/holidays` (admin write, all read).
- **Defaulters report** `GET /attendance/defaulters?threshold=&month=` (admin/teacher) — students below a % threshold, sorted ascending. (138 below 90% on the demo.)

### Added — mobile
- **Defaulters** report screen (threshold selector) wired to the admin "Generate Report" quick link. (Bulk-import & holiday-admin UIs are backend-ready — Flutter wiring is a follow-up.)

### Verified live
- Bulk import isolation (good rows succeed, bad row errors). Holiday add/list. Defaulters list. Teacher **403** on add-holiday; parent **403** on defaulters.

---

## [Unreleased] — v2 Phase 4 (part): Super-admin platform (2026-06-12)

Platform owner (founder) can onboard and manage schools.

### Added — backend (new `SuperAdminModule`, verified live)
- **Superadmin auth realm**: `is_superadmin` flag on users; `POST /superadmin/login` issues a school-less JWT (`role=superadmin`).
- **RLS superadmin bypass**: tenant policies now `... OR current_user_role()='superadmin'`; the interceptor opens a `current_role='superadmin'` context for platform requests. Regular tenants are unaffected — **the RLS isolation e2e test still passes (5/5)**.
- `GET /superadmin/schools` (with live student/teacher counts), `POST /superadmin/schools` (create school + principal Admin → credential slip), `suspend`/`activate`, `PATCH .../limits` (plan/max-students/SMS credits), `reset-principal`. All audit-logged.
- Demo super-admin seeded: `founder@vidyatrack.in` / `Demo@1234`.

### Added — web (Next.js, **builds clean**)
- Super-admin dashboard: login, schools table + totals, Create School modal, suspend/activate, reset-principal, one-time credential slip modal.

### Verified live (Phase 4 §9 acceptance)
- Founder logs in → lists demo school (240 students) → creates a 2nd school + principal slip → new principal logs in (forced password change) → **sees 0 students, not the demo's 240** (isolation holds). Regular admin **403** on `/superadmin/*`.

---

## [Unreleased] — v2 Phase 4 (part): Academics — homework / material / results (2026-06-12)

### Added — backend (new `AcademicsModule`, verified live)
- **Homework**: `POST /academics/homework` (admin/teacher), `GET /academics/homework` (by section), `GET /academics/homework/my` (student/parent → their section).
- **Study material**: `POST /academics/materials`, `GET /academics/materials?classId`.
- **Exams & results**: `POST /academics/exams`, `GET /academics/exams`, `POST /academics/results` (bulk marks, upsert), `GET /academics/results/my` and `GET /academics/results/student/:id` (ownership-enforced).

### Added — mobile
- **Homework** list (student/parent), **Results** report card (grouped by exam, %), **Assign Homework** (teacher, class/section picker). Wired to student Homework/Results tabs, parent Homework/Results tiles, and the teacher home "Assign Homework".

### Verified live (Phase 4 academics acceptance)
- Teacher assigns homework → parent sees it. Teacher enters marks → parent sees the report card (Maths 92, Science 85). Material upload → visible. Parent **403** on create-homework and enter-results.

---

## [Unreleased] — v2 Phase 2 (part): Attendance v2 — student/parent history (2026-06-12)

### Added (verified live)
- **`GET /attendance/me`** (parent/student → own/child) and **`GET /attendance/student/:id`** (admin/teacher any; parent/student ownership-enforced) → daily statuses + monthly summary (present/absent/late/leave + %).
- Mobile **My Attendance** screen: month switcher, big % card, P/A/L/Leave counts, per-day status list. Wired to the **parent Attendance tab** and the **student "My Attendance"** tile (replacing placeholders).

### Verified live
- Parent sees their child's month (90.9% = present 9 + late 1 of 11). Parent viewing a non-child → 403; admin → `/me` → 403.

---

## [Unreleased] — v2 Phase 3 (part): Communication suite (2026-06-12)

Notices, circulars, messages, suggestions and leave — all feeding the Phase-1 notification center.

### Added — backend (verified live)
- **Notification fan-out**: resolves an audience (all / parents / teachers / students / section) to user IDs and inserts `notifications` rows — so notices/circulars/messages light up the bell + notification center.
- **Notices** (`POST/GET /notifications/notices`) now fan out. **Circulars** (`POST/GET /notifications/circulars`). **Messages** broadcast (`POST /notifications/messages`).
- **Suggestions** inbox: `GET /notifications/suggestions`, `POST /notifications/suggestions/:id/reply` (notifies the sender).
- **Leave**: `POST /notifications/leave` (teacher self / parent-for-child with ownership check / student), `GET /notifications/leave` (admin queue), `POST /notifications/leave/:id/act` (approve/reject → notifies applicant + guardian).

### Added — mobile
- Admin screens: **Create Notice**, **Leave Approvals**, **Suggestions Inbox**; **Apply Leave** (teacher). Wired into Quick Links (Notice/Suggestion/Leave), the comms FAB (Message/Notify → Notice with preset audience, Suggestions), and the teacher home.

### Verified live (Phase 3 acceptance)
- Admin notice to parents → parent unread 0→1 and appears in their notification center. Parent **403** on sending. Parent applies leave → admin queue → approve → applicant notified (1→2). Suggestion → admin reply → sender notified (2→3).
- FCM push delivery + deep-link navigation are a follow-up (deep-link `data` is already stored on each notification row).

---

## [Unreleased] — v2 Phase 3 (part): Revenue v2 — manual control (2026-06-12)

Admin can record and correct revenue daily; the Daily Revenue card reflects it immediately.

### Added — backend (verified live)
- **`other_income`** table + `voided_at`/`void_reason` on `fee_payments` and `expenses` (folded into `schema.sql`, applied to dev DB).
- **`POST /fees/income`** (other income), **`POST /fees/void`** (`{kind: payment|income|expense, id, reason}`), **`GET /fees/today`** (today's entries for the void UI), **`GET /fees/revenue-range?from&to`** (per-day received/expense/net series for the graph). All admin-only, audit-logged.
- **Corrected `refresh_daily_revenue`** to the plan §6 definition: `Total = Amount Received + Back Due Received + Fine − Expense`, with Amount Received = current/forward fee payments **+ other income** (back-due no longer double-counted), discount shown not subtracted, voided rows excluded. (Old buggy total 73,500 → correct 71,800 on the demo.)

### Added — mobile
- **Today's Revenue** screen (tap the Daily Revenue card): live summary + Add Income / Add Expense + per-entry **Void** with reason; voided rows struck through.

### Verified live (§6 acceptance)
- Add ₹500 other income → Daily Revenue updates within one refresh; void → returns to previous; audit log shows both. Expense add/void reverts. Parent/teacher are **403** on admin-only revenue endpoints.

---

## [Unreleased] — v2 Phase 2 (part): Student lifecycle & credentials (2026-06-12)

Auto-provisioned logins for every new student + parent, with forced first-login password change.

### Added — backend (all verified live)
- **Schema**: `users.phone` now nullable; new `users.login_id` and `users.must_change_password` (+ index). Idempotent migration applied to the dev DB and folded into `schema.sql`.
- **`POST /students`** now runs an atomic, in-transaction provisioning: creates the student, a Student login (`STU-{admission_no}`) and a Parent login (`PAR-{admission_no}`) with readable 8-char temp passwords and `must_change_password=true`, links siblings to an existing parent (by phone) instead of duplicating, and returns the one-time credentials. Auto-suggests the next admission number.
- **`POST /students/:id/deactivate`** (soft remove, reason logged) and **`POST /students/:id/reset-credentials`** (regenerates a fresh slip). All audit-logged **without** plaintext passwords.
- **Login by ID**: `POST /auth/login-password` accepts `loginId` (scoped to the school) or `phone`; responses include `mustChangePassword`. Changing the password clears the flag.

### Added — mobile
- **Add Student** form (class/section, guardian, DOB, gender, auto admission no) → **Credential Slip** screen (Student + Parent IDs/passwords, Copy + Share, one-time warning).
- **Forced password-change** screen on first login (enforced from splash via a stored flag) and a real **Login with ID & Password** flow.
- Entry points: "Add Student" FAB on the class/section picker and on the empty-roster state.

### Verified live
- Add student → log in as the generated **STU-** and **PAR-** accounts → `mustChangePassword=true` → change password → flag clears. Sibling reuse, reset, deactivate, audit-no-plaintext, and teacher-403-on-deactivate all confirmed.

### Not yet (Phase 2 remainder)
- Edit-student UI, bulk CSV import, parent/student attendance calendar, holiday calendar, attendance reports/registers, teacher "request removal" → admin approvals.

---

## [Unreleased] — v2 Phase 1: Roles & navigation (2026-06-12)

Role-separated app + authoritative backend role gating.

### Added
- **Backend role guards (deny by default)** — `RolesGuard` + `@Roles()` applied to every controller/endpoint with explicit allowed roles; superadmin excluded from in-app endpoints. **Verified live**: admin/teacher reach the section roster (200), parent blocked (403), unauthenticated 401.
- **Four role shells** (`RoleShell` + `homePathForRole`): Admin · Teacher · Parent · Student, each with its own bottom navigation (§3.2). New `StudentHomeScreen`, `AccountScreen`, `AcademicsScreen`.
- **`RoleGate`** UI guard widget (defence in depth) on admin/teacher-only screens.
- **Notification center** (`/notifications`) shared by all roles: list, unread indicator, tap-to-mark-read, pull-to-refresh, empty/error states. App-bar bell wired on every home.
- **Change Password** wired to `/auth/change-password` from Profile (**verified live**: change succeeds, wrong old password → 401).
- Shared `ComingSoonScreen` placeholder so every not-yet-built destination is informative, not dead.

### Changed
- Drawer: wired About (dialog), Support (mailto), Rate (Play Store), Privacy/T&C (url_launcher), Logout (confirmation dialog); hid Phase-2 items (Live Class, Gallery, Polls).
- Teacher/Parent homes: removed their own bottom navs (the shell owns it) and the admin drawer; wired all previously-dead tiles.
- Quick Links and Academics/Account grid tiles now navigate (to placeholders) instead of no-op.
- Attendance marking is now a top-level `/attendance/mark` route reachable from any role's picker.

### Result
- **Zero dead buttons** across the mobile app (`() {}` handlers eliminated).

---

## [Unreleased] — v2 Phase 0: Stabilization (2026-06-12)

Fixes the five confirmed v1 bugs (B1–B5) and adds the demo dataset so every Phase 0 screen has data.

### Fixed
- **B2** Attendance chart y-axis no longer overprints — `leftTitles` uses `interval:20`, `reservedSize:36`, integer labels `0/20/40/60/80/100`; grid lines aligned to the same 20-step interval. (`apps/mobile/lib/features/home/widgets/attendance_chart_card.dart`)
- **B3** Chart plots attendance percentage per day; days with no session are skipped instead of forced to `0` (removes misleading dips). Backend already returned `{date,present,total,pct}`.
- **B4** Communication FAB is now a proper `Scaffold.floatingActionButton`; the speed-dial menu + scrim render via the root `Overlay` anchored with a `LayerLink`, so it no longer overlaps the Daily Revenue rows. (`comm_speed_dial.dart`, `admin_home_screen.dart`)
- **B5** Empty attendance roster: new demo seed populates all sections (root cause was data, not code). Marking screen shows an explicit empty state and disables Submit when there are 0 students; added an error+retry state. (`attendance_marking_screen.dart`)
- **B1** Confirmed home renders each section exactly once (no regression); FAB moved out of the scroll body.

### Changed
- **Demo seed rewritten** (`apps/api/src/database/seed.ts`): 1 school, 3 classes × 2 sections, **40 students each (240 total)**, **5 teachers**, ~1 month of daily attendance (sessions + records + `daily_attendance_summary`) and teacher attendance, fee heads/invoices/payments dated today, and an expense — so the dashboard charts and Daily Revenue card show real data. Seed is re-runnable (wipes the demo school first).
- Added `seed:demo` npm script (alias of `seed`).

### Ops / DB
- Re-applied `schema.sql` to the running dev database to install the missing `refresh_daily_revenue(uuid)` function (the Docker volume predated it). The function call in the seed/fees service now casts `$1::uuid`.

### Verified live (Postgres via docker-compose)
- All 6 sections = 40 active students (Class 2-B, the screenshot case, = 40).
- Dashboard chart query returns pct 87.5–90.0 over the last working days (Sundays skipped).
- `daily_revenue_summary`: received ₹73,600 · back-due ₹27,600 · fine ₹200 · discount ₹300 · expense ₹2,000.

### Not verified
- Flutter app was **not compiled** (Flutter SDK not installed in this environment). Mobile changes are code-level and need an on-device pass: `flutter analyze`, build a debug APK, and manually check the home dashboard, chart axis, FAB behaviour, and the empty-roster flow.
