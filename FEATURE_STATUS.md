# VidyaTrack — Feature / Button Status

> Per V2 plan rule #4: every screen/button → status. Updated each phase.
> **Legend:** ✅ working · 🟡 pending (planned later phase; reachable but lands on an informative "coming soon" placeholder) · 🔒 hidden (not shown on screen yet) · 🐞 was a bug, now fixed

**Current state:** Phase 0 ✅, Phase 1 ✅, Phase 2 (credentials ✅, attendance-history ✅; edit-UI/bulk-import/holidays/reports remain), Phase 3 (revenue-v2 ✅, comms ✅; push/uploads remain), Phase 4 (academics homework/material/results ✅, super-admin platform ✅; report-center remains), Phase 5 not started, **V3 ✅ complete** (see below). Every backend change verified live; `flutter analyze` = 0 errors/warnings; `next build` clean; RLS isolation 5/5.

## V3 — Timetable, Syllabus, Study Material, Fees, Super-Admin ✅ (2026-07-16, verified live)

| Item | Status | Notes |
|---|---|---|
| **Shared: file upload** | ✅ | `POST /uploads` (local disk, S3-adapter-ready `StorageService`), 15MB/MIME-limited; served at `/uploads/*` |
| **Shared: payment gateway** | ✅ | `PaymentGateway` interface — `MockGateway` (default, `PAYMENT_MODE=mock`) + `RazorpayGateway` (real HMAC, `PAYMENT_MODE=razorpay`) |
| **Timetable — admin sets, all roles view** | ✅ | `POST/GET/DELETE /academics/timetable*`; `EditTimetableScreen` (admin), `TimetableViewScreen` (parent/student/teacher); wired to parent/student home tiles + Academics grid "Class Routine" |
| **Syllabus — admin/teacher set, all roles view** | ✅ | `POST/GET/DELETE /academics/syllabus*`; `SyllabusScreen` (view+edit, topic checklist + file); wired to parent/student home + Academics grid |
| **Study Material — upload + browse** | ✅ | Upload now accepts a real `fileUrl` from `/uploads`; `/academics/materials/my` for parent/student; `StudyMaterialScreen`; wired to parent/student/teacher |
| **Fees — admin sets structure** | ✅ | `POST/PUT/DELETE /fees/heads`; `FeeStructureScreen`, entry: admin Account grid "Fee Structure" |
| **Fees — invoice generation** | ✅ | `POST /fees/invoices/generate` (idempotent, quarterly/annual prorated, one-time-only-once); triggered from `FeeStructureScreen` |
| **Fees — parent sees pending dues** | ✅ | `GET /fees/my-dues` (ownership-scoped — **closed a real cross-child data leak** in the pre-existing `/fees/dues`); replaces the parent Fees tab placeholder with `ParentFeesScreen` |
| **Fees — parent pays online** | ✅ | `POST /fees/pay/order` + `/pay/verify` (server-verified, idempotent on `gateway_payment_id`, amount clamped to balance); `InvoiceDetailScreen` "Pay Now" (mock-mode simulated checkout); `GET /fees/receipt/:id` |
| **Super-admin — analytics** | ✅ | `GET /superadmin/analytics` (schools/students/users-by-role/online fee volume/invoices-this-month) + per-school `/stats`; web Analytics tab with recharts bar |
| **Super-admin — plan & feature flags** | ✅ | `schools.plan_expires_at`, `school_settings` key/value table; web "Plan & Flags" modal per school |
| **Super-admin — broadcast** | ✅ | `POST /superadmin/broadcast` (schools × roles → notifications); web Broadcast tab, verified "7 users across 1 school" live |
| **Super-admin — audit viewer** | ✅ | `GET /superadmin/audit`; web Audit Log tab with school filter |
| **Parent: Apply Leave entry** | ✅ | New tile on parent home resolves own child via `/fees/my-dues`, reuses existing `ApplyLeaveScreen(studentId:)` |
| **Bugs found & fixed during V3 verification** | 🐞→✅ | (1) `recomputeInvoiceStatus` CASE/enum cast — broke every payment collection, not just online; (2) `superadmin.broadcast` enum=text comparison; (3) `fees.generateInvoices` passed a date string where `audit_logs.entity_id` (uuid) was expected |

## Phase 4 (part) — Academics ✅ (verified live)

| Item | Status | Notes |
|---|---|---|
| Homework create + view (student/parent) | ✅ | `/academics/homework*`; Assign Homework + Homework list screens |
| Study material upload + list | ✅ | `/academics/materials` |
| Exams + bulk marks + report card | ✅ | `/academics/results*`; Results screen (grouped by exam, %) |
| **Super-admin platform (create/manage schools)** | ✅ verified live | `SuperAdminModule` + RLS bypass (isolation test 5/5 green); Next.js dashboard **builds clean** |
| Syllabus/timetable CRUD | ✅ | done in V3 (see V3 section above) |
| Report center | 🟡 | follow-up |


## Phase 3 (part) — Revenue v2 manual control ✅ (verified live)

| Item | Status | Notes |
|---|---|---|
| Add Other Income | ✅ | `POST /fees/income`; reflects in Daily Revenue immediately |
| Add Expense | ✅ | `POST /fees/expenses` |
| Void payment/income/expense | ✅ | `POST /fees/void` (reason, audit), invoice status recomputed |
| Corrected Total Revenue formula | ✅ | `received + back_due + fine − expense` (plan §6); voided excluded |
| Today's Revenue detail screen | ✅ | tap Daily Revenue card → summary + add/void entries |
| Revenue range series (graph) | ✅ backend | `GET /fees/revenue-range`; Flutter graph screen 🟡 follow-up |
| **Comms: notices/circulars/messages + fan-out** | ✅ verified live | feed the notification center; Create Notice screen + FAB/Quick Links wired |
| **Suggestions inbox + reply** | ✅ verified live | admin screen; reply notifies sender |
| **Leave apply / approvals + notify** | ✅ verified live | Apply Leave (teacher) + Leave Approvals (admin) screens |
| Notification FCM push + deep-link nav | 🟡 | follow-up (deep-link data stored on each row) |
| Circular file upload, contact directory, parent apply-leave | 🟡 | follow-up |


## Phase 2 (part) — Student lifecycle & credentials ✅ (verified live)

| Item | Status | Notes |
|---|---|---|
| Add Student (auto STU-/PAR- logins + temp passwords) | ✅ | `POST /students` transaction; sibling reuse by phone; auto admission no |
| Credential Slip (Copy / Share, one-time) | ✅ | Flutter screen; share via WhatsApp/any app |
| Login by ID + School Code + password | ✅ | `loginId` on `/auth/login-password` |
| Forced first-login password change | ✅ | `must_change_password` flag → splash + force-change screen; clears on change |
| Deactivate student (soft, reason, audit) | ✅ | `POST /students/:id/deactivate` |
| Reset credentials (fresh slip) | ✅ | `POST /students/:id/reset-credentials` |
| Add Student entry points | ✅ | FAB on class/section picker + empty-roster button |
| **Parent/student monthly attendance + %** | ✅ verified live | `/attendance/me` + `/attendance/student/:id` (ownership enforced); MyAttendanceScreen wired to parent Attendance tab + student "My Attendance" |
| **Bulk CSV import (savepoint-isolated + batch credentials)** | ✅ verified live + **Flutter UI** | `POST /students/bulk-import`; BulkImportScreen (paste CSV) wired from Add Student |
| **Holiday calendar** | ✅ verified live + **Flutter UI** | `GET/POST/DELETE /attendance/holidays`; HolidayCalendarScreen wired from attendance picker |
| **Defaulters report (<threshold%)** | ✅ verified live | `/attendance/defaulters`; Defaulters screen wired to "Generate Report" |
| Edit student UI / monthly register PDF | 🟡 | follow-up |


---

## Phase 0 — Stabilization (bugs B1–B5)

| Bug | Item | Status | Notes |
|-----|------|--------|-------|
| B1 | Home renders each section exactly once | ✅ | one `CustomScrollView` → one `Column`; FAB moved out of the scroll body |
| B2 | Chart y-axis | 🐞→✅ | `interval:20, reservedSize:36`, integer labels `0/20/40/60/80/100`; grid aligned |
| B3 | Chart plots % per day | 🐞→✅ | backend returns `pct`; no-session days skipped; verified pct 87.5–90% live |
| B4 | FAB overlap | 🐞→✅ | real `Scaffold.floatingActionButton` + Overlay/LayerLink speed-dial |
| B5 | Empty roster | 🐞→✅ | seed fixed (all 6 sections = 40, verified via API); empty-state + disabled Submit |

## Phase 1 — Roles & navigation

| Item | Status | Notes |
|---|---|---|
| Role-based routing (`homePathForRole`) | ✅ | splash / OTP / role-picker route admin·teacher·parent·**student** to their own shell |
| 4 app shells with distinct bottom navs | ✅ | `RoleShell`: Admin (Home·Attendance·Account·Profile), Teacher (Home·Attendance·Academics·Profile), Parent (Home·Attendance·Fees·Profile), Student (Home·Homework·Results·Profile) |
| `RoleGate` UI guard | ✅ | wraps admin Account & teacher Academics screens |
| **Backend role guards (deny by default)** | ✅ **verified live** | `RolesGuard` + `@Roles()` on every controller. Tested: admin/teacher reach roster (200), parent blocked (403), no-token 401 |
| Notifications center + bell | ✅ | `/notifications` screen (list, unread dot, tap-to-read, pull-to-refresh, empty/error states); bell wired on every home |
| Static drawer buttons | ✅ | About (dialog), Support (mailto), Rate (Play Store), Privacy/T&C (url_launcher), Logout (confirm dialog) |
| Change Password | ✅ **verified live** | Profile dialog → `/auth/change-password` (change works, wrong-old → 401) |
| Zero dead buttons | ✅ | no `() {}` handlers remain; unbuilt destinations land on "coming soon" |

### Admin shell

| Screen / Button | Status | Action |
|---|---|---|
| App bar bell | ✅ | → Notifications |
| Student / Teacher attendance charts | ✅ | render pct 0–100 (last 7 days) |
| Daily Revenue card | ✅ | live figures from `daily_revenue_summary` |
| Quick Links (Search/Suggestion/Report/Notice/Leave) | 🟡 | placeholder → Phase 3–4 |
| Academics grid tiles | ✅ (V3) | Study Material, Class Routine, Syllabus wired; Home Work/Result/Attendance still 🟡 (redundant with bottom-nav, out of V3 scope) |
| Account grid tiles | ✅ (V3) | Total Revenue, Fee Structure, Generate Report wired; Student Wise Report/Expenses still 🟡 |
| Comms FAB (speed-dial) | 🟡 | opens; each item shows "coming in a later update" toast → follow-up |
| Bottom nav: Home·Attendance·Account·Profile | ✅ | all 4 land on real screens |
| Drawer: Home/About/Support/Rate/Privacy/T&C/Logout | ✅ | wired |
| Drawer: Live Class / Gallery / Polls | 🔒 | hidden (follow-up) |
| Attendance roster (mark, all-P/A, search, submit, empty-state) | ✅ | bulk submit + offline queue |

### Teacher shell
| Item | Status | Notes |
|---|---|---|
| Home cards: Mark Attendance | ✅ | → attendance tab |
| Home cards: Assign Homework, Study Material (V3), Apply Leave | ✅ | all wired |
| Academics tab: Class Routine (My Timetable), Study Material, Syllabus | ✅ (V3) | |
| Bottom nav: Home·Attendance·Academics·Profile | ✅ | Academics shows the academics grid |

### Parent shell
| Item | Status | Notes |
|---|---|---|
| Home tiles: Attendance, Timetable (V3), Fee Status (V3), Homework, Results, Study Material (V3), Syllabus (V3), Notices, Apply Leave (V3) | ✅ | **every parent home tile now lands on a real screen** |
| Bottom nav: Home·Attendance·Fees·Profile | ✅ | Fees tab now `ParentFeesScreen` (V3) — pending dues + Pay Now, no longer a placeholder |

### Student shell
| Item | Status | Notes |
|---|---|---|
| Home tiles: Today's Timetable, Homework Due, Study Material, Syllabus (all V3), My Attendance | ✅ | |
| Bottom nav: Home·Homework·Results·Profile | ✅ | |

### Shared
| Item | Status |
|---|---|
| Profile (school info, Change Password ✅, Logout ✅) | ✅ |
| Super-admin web | 🔒 not built — Phase 4 |

---

## Pending phases (not started)
- Phases 0–4 and V3 are all complete (see sections above — this list is historical and outdated as of V3).
- **Phase 5** — i18n (Hindi), pagination/skeletons everywhere, Sentry, analytics, Play track.
- **V3 follow-ups** — report center, contact directory, FCM push + deep links, circular file upload, exam-creation admin UI, expense-list UI.

## Known follow-ups
- `refresh_daily_revenue()` total formula matches the Phase-3 spec.
- `/fees/dues` (parent) is now ownership-scoped (fixed in V3.4 — was previously open to any studentId); `/students/:id` still school-scoped only, not yet ownership-checked for parent callers.
- Teacher "request removal" / admin approvals, and teacher-added-student "pending" flag — Phase 2.
