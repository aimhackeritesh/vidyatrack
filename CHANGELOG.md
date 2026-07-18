# Changelog

All notable changes to VidyaTrack. Format loosely follows Keep a Changelog.

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
