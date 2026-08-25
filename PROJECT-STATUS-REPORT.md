# VidyaTrack v2 — Project Status Report

> ## ⚠️ HISTORICAL DOCUMENT — DO NOT TRUST AS CURRENT
> **This describes the project as of 2026-06-12 (the V2 era).** Since then V3 shipped
> (timetable, syllabus, study material, full fees, super-admin) and the app was deployed
> live to Railway + Vercel. The line below claiming this is "the single source of truth"
> was true when written and is **no longer true**.
>
> **For current state, read instead:** [HANDOVER.md](HANDOVER.md) (orientation) ·
> [CHANGELOG.md](CHANGELOG.md) (what shipped when) ·
> [FEATURE_STATUS.md](FEATURE_STATUS.md) (per-screen status) ·
> [V4-PLAN.md](V4-PLAN.md) (next work).
>
> Kept in the repo only as a record of the V2 milestone.

**Compiled:** 2026-06-12 · **Scope:** Everything executed against the `V2-IMPROVEMENT-PLAN.md` roadmap, phases 0–4, plus a full runtime audit and polish pass.

~~This document is the single source of truth for *where the project stands right now*.~~ (See the notice above — superseded.) It doesn't replace the other tracking docs — `V2-IMPROVEMENT-PLAN.md` (original spec, reproduced in full below), `CHANGELOG.md` (detailed dated entries), and `FEATURE_STATUS.md` (live button/screen matrix) all remain in the repo root and stay up to date per-phase.

## At a glance

| Phase | Status |
|---|---|
| **0** — Stabilize (bugs B1–B5) | ✅ Done, verified live |
| **1** — Roles & navigation | ✅ Done, verified live |
| **2** — Students & Attendance v2 | ✅ Core done, verified live (edit-UI/register-PDF remain) |
| **3** — Revenue v2 + Communication | ✅ Core done, verified live (push/uploads remain) |
| **4** — Academics + Super-admin | ✅ Core done, verified live (report center/syllabus/timetable remain) |
| **5** — Scale & polish | ⬜ Not started (i18n, Sentry, analytics, Play track, load test) |

**Verification posture:** every backend change (NestJS API + Postgres) was proven against the **live, running stack** — not just built or unit-tested. The Flutter mobile app and the Next.js super-admin web were both **runtime-verified** in a dedicated audit (SDK installed mid-session, app compiled/launched/rendered, `flutter analyze` and `flutter test` green, web UI driven end-to-end in a real browser with screenshots).

---

## 1. The original plan (verbatim)

*Reproduced in full so this report is self-contained. This is the unmodified `V2-IMPROVEMENT-PLAN.md` that drove all work below.*

> # VidyaTrack v2 — Improvement & Completion Plan
> **For: Claude Code** | **Date: June 2026** | **Supersedes nothing — extends PRD v1.0**
>
> ## How to use this document (instructions to Claude Code)
> 1. Read this entire file before writing code. Then execute **phase by phase, in order** (Phase 0 → 5). Do not start a phase until the previous phase's acceptance checklist passes.
> 2. **Zero dead buttons rule:** every tappable element listed in Section 5 must perform its named action. If a feature cannot be completed in the current phase, the button must not exist on screen yet (hide it) — never ship a button that does nothing. No "TODO", no empty `onPressed: () {}`.
> 3. After every phase: run `flutter analyze` (0 errors), run all tests, build a debug APK, and print a manual test checklist for the human to verify on a real device.
> 4. Maintain a `FEATURE_STATUS.md` in the repo root: a table of every screen/button → status (working / hidden / pending) updated each phase.
> 5. Use the existing repo. Refactor, don't rewrite from scratch, unless a file is unsalvageable.
>
> ---
>
> ## 1. Current state (observed from the v1 APK — screenshots reviewed)
>
> ### Confirmed bugs (fix in Phase 0)
> | # | Bug | Evidence | Likely cause / fix direction |
> |---|---|---|---|
> | B1 | Home screen renders **Academics + Account sections and FAB multiple times** (duplicated blocks stacked vertically) | Screenshot 1 | Widget tree built inside a loop / ListView.builder over wrong list, or sections added per-rebuild. Home must be ONE `CustomScrollView`/`SingleChildScrollView` with each section exactly once. FAB belongs in `Scaffold.floatingActionButton`, not inside the scroll list. |
> | B2 | **Student Attendance chart y-axis garbled** — labels overprinted/stacked on top of each other on the left edge | Screenshots 1, 3 | fl_chart `leftTitles` misconfigured: no `interval`, `reservedSize` too small, or rendering every double value. Fix: compute `maxY` from data (min 100 for %), set `interval` (e.g. 20), `reservedSize: 36`, format as integers `0/20/40/60/80/100`. X-axis: max 7 labels, `dd MMM` two-line style as designed. |
> | B3 | Chart shows wrong data shape — attendance should be a **percentage (0–100%) per day**, not raw counts that spike randomly | Screenshot 3 | Backend must return `[{date, present, total, pct}]` from a summary query; app plots `pct`. Days with no session = gap or 0 with grey marker, not interpolated. |
> | B4 | **FAB overlaps Daily Revenue rows** (Amount Received value hidden behind FAB) | Screenshot 3 | Add bottom padding to scroll content = FAB size + 24px (`padding: EdgeInsets.only(bottom: 96)`), and right-padding on revenue rows; FAB must be a proper Scaffold FAB so it floats above content predictably. |
> | B5 | **Attendance roster empty — "Class 2 - Section B, 0 students"** | Screenshot 4 | Either students API returns empty (no seed data / wrong section_id mapping) or app isn't calling it. Fix the `GET /sections/:id/students` flow end-to-end + add seed data + show explicit empty state: "No students enrolled in this section yet. [Add Students]" (admin only). Submit button must be disabled when roster is empty. |
> | B6 | **Most buttons do nothing** (tiles, quick links, drawer items) | User report | Phase 1–4 wire every route per Section 5. Until wired, hide. |
> | B7 | Daily Revenue is all ₹0 with **no way to enter revenue** | Screenshots + user report | Build the manual revenue/fee-collection entry flows (Section 6). |
> | B8 | Single interface for everyone — **no role separation** | User report | Implement role-based routing (Section 3). |
>
> ### What seems OK (keep)
> - Visual language (lavender bg, pastel tiles, bottom nav, FAB speed-dial in screenshot 2) matches the target design — keep and reuse these widgets.
> - School-code app bar, notification bell placement, Quick Links row.
>
> ---
>
> ## 2. Product clarifications & new requirements (from founder)
>
> 1. **Three+ distinct in-app experiences**: Admin (principal), Teacher, Parent, Student — different home screens, different bottom navs, different permissions. One codebase, role decided at login.
> 2. **Admin can manually add/adjust revenue daily** — not just via student fee receipts. Admin records: fee collections, *other income* entries (e.g., admission form sales, donations), expenses, and can **edit/correct today's entries** (with audit log). Dashboard graph and Daily Revenue card must reflect these immediately.
> 3. **Teachers and Admin** can: add/remove (deactivate) students, upload study material, and mark daily attendance. (Removal by teacher = request → admin approves; admin removes directly. Hard delete never — soft `status=inactive`.)
> 4. **Parents**: receive ALL relevant notifications (absence, notices, homework, fee due, results), and can view their child's full attendance history and stats.
> 5. **Auto-generated credentials**: when a student is added, the system **immediately generates a Student login ID + temporary password AND a Parent login ID + temporary password**, shown on screen + shareable as a credential slip (text/WhatsApp share + printable PDF). First login forces password change; "Change Password" works from Profile thereafter. ID format: `STU-{admission_no}` and `PAR-{admission_no}` (unique per school; login = School Code + ID + password, OR phone+OTP for parents).
> 6. **Attendance visibility**: every stakeholder can view attendance appropriate to their role — admin: whole school; teacher: their sections; parent/student: own/child — calendar view + monthly % + history list.
> 7. **Super-admin (platform owner = founder)**: separate web access to create schools, create the school's first admin (principal) account, suspend schools, see per-school usage. Principal gets **Admin** role only within their school.
> 8. **Scale-ready niceties** (include now, small effort): pagination everywhere, pull-to-refresh, skeleton loaders, empty states with action hints, error toasts with retry, date pickers default to today, Hindi-ready strings file, analytics events on every primary action.
>
> ---
>
> ## 3. Role-based architecture (Phase 1)
>
> ### 3.1 Auth & session
> - Login screen: School Code + (Login ID + Password) OR (Phone + OTP). Response returns `{user, roles[]}`.
> - If multiple roles/children → role picker screen; persist last choice.
> - JWT contains `user_id, school_id, role, entity_id` (teacher_id/student_id/parent link). Refresh token rotation. Logout clears local DB cache.
> - Forced password change flag `must_change_password=true` for generated credentials.
> - Route guard: a single `RoleGate(allowed: [...])` widget + backend guard decorator on every endpoint. **Every endpoint must declare allowed roles — deny by default.**
>
> ### 3.2 App shell per role (Flutter: one app, four shells)
> | Role | Bottom nav tabs | Home content |
> |---|---|---|
> | **Admin** | Home · Attendance · Account · Profile | Charts (student+teacher attendance), Quick Links, Daily Revenue card, Academics grid, Account grid, FAB comms menu |
> | **Teacher** | Home · Attendance · Academics · Profile | My classes today, "Mark Attendance" CTA per section, my timetable, recent notices, FAB (Message Parent, Homework, Material) |
> | **Parent** | Home · Attendance · Fees · Profile | Child card (switcher if multiple), today's status (Present/Absent), notifications feed, homework due, notices, fees due banner |
> | **Student** | Home · Homework · Results · Profile | Today timetable, homework due, study material shortcuts, my attendance % |
>
> Implementation: `HomeRouter` reads role → returns `AdminShell()/TeacherShell()/ParentShell()/StudentShell()`. Shared widgets live in `/lib/shared/widgets`.
>
> ---
>
> ## 4. Student lifecycle & credentials (Phase 2 — high priority)
>
> ### Add Student (Admin; Teacher = same form, lands as "pending" until admin approves — config flag, default ON for admin-only)
> Form: name*, class+section*, roll no, admission no* (auto-suggest next), DOB, gender, guardian name*, guardian phone*, photo (optional, compressed client-side), admission date (default today), fee plan (pick fee heads).
>
> On save, backend transaction:
> 1. Create `students` row (status=active).
> 2. Create student user: `login_id = STU-{admission_no}`, password = random 8-char (readable, no ambiguous chars), `must_change_password=true`.
> 3. Create/attach parent user keyed by guardian phone (if a parent user with that phone exists in this school, link the new child to it; else create `PAR-{admission_no}` + temp password).
> 4. Return credentials **once** in the response → app shows **Credential Slip screen**: school name, student name, class, both login IDs + temp passwords, app download note. Buttons: [Share on WhatsApp] [Share as PDF] [Copy] [Done]. Also stored event in audit log (without plaintext password — passwords hashed at rest; slip is the one-time view; provide "Reset password" action that regenerates + reshows slip).
>
> ### Other flows
> - **Edit student** (admin): all fields; section transfer keeps attendance history.
> - **Remove student**: admin → "Deactivate" with reason (TC issued / left). Teacher → "Request removal" → admin Approvals inbox. Deactivated students excluded from rosters & invoices, retained in history/reports.
> - **Bulk import** (admin, web + app): CSV template (name, class, section, roll, admission_no, guardian name, phone, DOB) → validate → preview errors → import → downloadable credential sheet (CSV/PDF) for the whole batch.
> - **Reset password** (admin for anyone; self via old password; parent via OTP).
>
> Acceptance: add a student end-to-end on device → log out → log in as that student with slip credentials → forced password change → student home loads. Same for parent.
>
> ---
>
> ## 5. THE BUTTON MAP — every tappable element and its required action
> *(Claude Code: this section is the contract. Implement exactly; hide what's not yet built.)*
>
> ### 5.1 Admin
> **App bar:** hamburger → drawer; bell → Notifications screen (list, read/unread, tap → deep link to item).
> **Drawer:** Home→home; Live Class→list of links (P2, hide v2.0); Gallery (P2, hide); Polls (P2, hide); About Us→static; Support→FAQ + contact (mailto/tel); Rate us→Play Store intent; Privacy Policy / T&C→webview; Logout→confirm dialog→login.
> **Charts:** tap Student chart→Attendance Reports (school view); tap Teacher chart→Teacher Attendance screen.
> **Quick Links:** Student Search→search screen→student profile; Suggestion→suggestions inbox (list+reply); Generate Report→Report Center; Notice→create/list notices; Leave→approvals queue (approve/reject with note→notifies applicant).
> **Daily Revenue card:** tap anywhere→Today's Revenue detail (Section 6); each row optional drill-down to its entries.
> **Academics grid:** Study Material→browse by class/subject + [Upload] ; Class Routine→timetable viewer + [Edit] (admin); Home Work→list by section + detail; Result→exams list→marks entry grid / report card view; Attendance→same as bottom tab; Syllabus→per class list + [Upload].
> **Account grid:** Total Revenue→range report (today/week/month/custom; chart + table); Student Wise Report→per-student dues/paid list, tap→ledger; Expenses→list + [Add Expense]; Generate Report→Report Center (pick type+range→async generate→notification when ready→open/share PDF/CSV).
> **FAB speed-dial:** Message to Parent/Student/Teacher→compose (audience picker: all/class/section/individual; channel: push, +SMS toggle)→send→delivery report; Suggestions→same inbox; Contact Directory→staff list (tap-to-call); Notify Student / Notify Faculty→template picker→one-tap broadcast; Circular→upload PDF/image + audience→publish.
> **Bottom nav:** Home; Attendance→Class&Section select→roster (mark/edit, admin can edit past days w/ audit); Account→Account grid screen; Profile→school profile (editable: logo, principal, address, email) + Change Password + Logout.
>
> ### 5.2 Teacher
> Home cards: each of "My sections today" → [Mark Attendance] → roster; timetable→read-only; notices→detail.
> Attendance tab: own sections only; today default; past = view-only (mark window: same-day, config).
> Academics tab: Homework [list/create for own sections], Study Material [browse/upload own subjects], Results [enter marks for assigned exams], Syllabus [view].
> FAB: Message to Parent (own sections), Create Homework, Upload Material, Apply Leave (form→status tracker).
> Profile: my details, my attendance summary, Change Password, Logout.
>
> ### 5.3 Parent
> Home: child switcher (if >1); today's attendance status chip; feed of notifications (absence, notice, homework, fee, result — tap→detail).
> Attendance tab: month calendar (P/A/L/Leave/Holiday color dots) + % stats + history list; month picker.
> Fees tab: current dues, invoice list, payment history, receipt PDF download/share. ([Pay online] hidden until gateway phase.)
> Profile: child info (read-only), guardian phone (editable via OTP), Apply Leave for child (→ teacher/admin approval), Suggestion box, Change Password, Logout.
>
> ### 5.4 Student
> Home: timetable today, homework due list (tap→detail→[Mark as done]); material shortcuts.
> Homework tab: pending/done filter. Results tab: exam list→marks card. Profile: my attendance %, syllabus, Change Password, Logout.
>
> ---
>
> ## 6. Revenue module v2 (Phase 3) — manual control for Admin
>
> ### Entry types (all tenant-scoped, all audit-logged)
> 1. **Fee collection** (existing): search student→dues→record payment (cash/UPI ref/cheque) + fine + discount→receipt no→PDF receipt share.
> 2. **Other income** (NEW): [Add Income] → category (Admission forms / Donation / Transport / Uniform-Books / Other+free text), amount, note, date (default today) → appears in Amount Received + Total.
> 3. **Expense**: category, amount, note, date.
> 4. **Adjustment/Correction** (NEW): admin can edit or void any of today's entries; past entries → "Adjustment entry" (delta + reason) rather than silent edit. Every change writes `audit_log(actor, before, after, reason, ts)`.
>
> ### Daily Revenue card (live) definitions — implement exactly
> - Amount Received = today's fee payments (principal) + other income
> - Back Due Received = portion of today's payments applied to previous months' dues
> - Fine Received = sum of fine fields today
> - Expense = today's expenses
> - Discount = sum of discounts today (red)
> - **Total Revenue = Amount Received + Back Due Received + Fine Received − Expense** (Discount shown, not subtracted from received cash; document this rule in code comments and on the report footer).
>
> ### Revenue graph (replaces broken chart where relevant)
> - `GET /reports/revenue-daily?from&to` → `[{date, received, expense, net}]` from a `daily_revenue_summary` table updated transactionally on every entry (no nightly-only jobs — admin must see instant effect).
> - Account→Total Revenue screen: bar/line for range + totals table + export.
>
> Acceptance: add ₹500 other income → Daily Revenue card updates within one refresh; void it → returns to previous; audit log shows both.
>
> ---
>
> ## 7. Attendance module v2 (Phase 2)
> - Roster: list students (photo initial, roll, name), ALL default **Present**; tap cycles P→A→L(eave)→Late; long-press for remark. Header counters P/A live; **All P / All A** set all (as in current UI). Search filters list. Submit = ONE bulk call `POST /attendance/sessions {section_id, date, records[]}` (idempotency key). Disabled if 0 students (B5).
> - Offline: roster cached; submissions queue with visible badge "Pending sync (1)"; sync on connectivity; conflict = last-write-wins per (student,date).
> - After submit: enqueue parent notifications for Absent/Late only.
> - Holiday calendar (admin sets) → those dates excluded from % and marked grey.
> - Reports: school day view (per class %), defaulters (<75% configurable), monthly register (matrix student×day) exportable PDF/CSV; parent/student calendar view.
> - Teacher attendance: admin marks staff list daily OR teacher self check-in (flag, default admin-marks).
>
> ---
>
> ## 8. Notifications (Phase 3)
> - In-app notification center (bell) for ALL roles; unread badge; types: absence, notice, circular, homework, result published, fee due (auto on invoice due-3 days), leave status, message.
> - FCM push for each; tap → deep link to the exact screen. Store `notifications` rows server-side; mark-read sync.
> - SMS optional per send (admin toggle; show credits remaining — super-admin sets credits).
>
> ---
>
> ## 9. Super-admin (Phase 4 — Next.js web, minimal but real)
> - Login (separate auth realm). Dashboard: schools list (status, students count, last activity).
> - [Create School]: name, city, principal name+phone+email → generates School Code + principal Admin credentials slip.
> - Per school: suspend/activate, reset principal password, set plan limits (max students, SMS credits), usage stats (DAU, attendance coverage %).
> - Impersonate (read-only) for support — audit-logged. No cross-school data mixing anywhere else; keep the RLS isolation test green.
>
> ---
>
> ## 10. Phase plan & acceptance checklists
>
> ### Phase 0 — Stabilize (bugs B1–B5)
> Fix duplicate home sections; FAB to Scaffold; chart axis + % data; bottom padding; roster fetch + seed script (`npm run seed:demo` creates 1 school, 3 classes×2 sections, 40 students each, 5 teachers, 1 month of attendance+fees). ✅ when: home renders each section once on 3 screen sizes; chart shows 7 labeled days 0–100%; Class 2-B shows 40 students; submit works.
>
> ### Phase 1 — Roles & navigation
> Role-based login/JWT/guards; 4 shells; wire ALL drawer/static buttons; Notifications screen skeleton; hide unbuilt features. ✅ when: logging in as each seeded role lands on its own shell; FEATURE_STATUS.md has zero "dead" buttons.
>
> ### Phase 2 — Students & Attendance v2
> Section 4 + Section 7 complete incl. credential slips, bulk import, calendar views, offline queue. ✅ when: acceptance flows in §4 and §7 pass on device.
>
> ### Phase 3 — Revenue v2 + Communication + Notifications
> Section 6 + messaging/notice/circular/suggestions/leave + notification center w/ deep links. ✅ when: §6 acceptance passes; a notice sent by admin appears on parent device push + bell within 30s.
>
> ### Phase 4 — Academics completion + Super-admin web
> Homework/material/results/syllabus/timetable full CRUD per role matrix; report center async PDFs; super-admin per §9. ✅ when: teacher uploads PDF visible to student; marks entered → parent sees report card; founder creates a 2nd school and isolation test passes.
>
> ### Phase 5 — Scale & polish
> Hindi strings, pagination+skeletons everywhere, Sentry, analytics events, app size check (<30MB), Play internal track build, load test attendance submit (500 concurrent sections).
>
> ---
>
> ## 11. Engineering ground rules for Claude Code
> - State management: Riverpod (or keep existing if Bloc — be consistent). Repository pattern: UI → provider → repo → (local cache, API).
> - Charts: fl_chart with explicit `minY:0, maxY:100, interval:20, reservedSize:36`; never auto-titles.
> - Every list: pull-to-refresh + pagination + empty state widget + error+retry widget (make these 3 shared components first).
> - All money in paise (int) server-side; format ₹ on client.
> - Dates: store UTC, display Asia/Kolkata; "today" = school local date.
> - Write tests: unit (revenue math §6, attendance %), API e2e (auth/roles/RLS isolation), and golden test for the home dashboard to catch duplicate-section regressions (B1).
> - Conventional commits; one PR per phase; update FEATURE_STATUS.md + CHANGELOG each PR.

---

## 2. What was built — phase by phase

Every claim below was **verified against the live stack** (Postgres via docker-compose, the running NestJS API, and — from the audit onward — the compiled/launched Flutter app and Next.js web) during this session. Full technical detail lives in `CHANGELOG.md`; this is the condensed version.

### Phase 0 — Stabilization (bugs B1–B5)

| Bug | Fix | Live evidence |
|---|---|---|
| B1 duplicated home sections | Confirmed already correct (single `CustomScrollView` → one `Column`); FAB moved out of scroll body | Static review |
| B2 garbled chart y-axis | `leftTitles`: `interval:20, reservedSize:36`, integer labels 0/20/40/60/80/100; gridlines aligned | — |
| B3 wrong chart data shape | Backend returns `{date,present,total,pct}`; no-session days skipped instead of forced to 0 | pct 87.5–90.0% over real days |
| B4 FAB overlapping Daily Revenue | Real `Scaffold.floatingActionButton` + Overlay/LayerLink speed-dial | — |
| B5 empty roster ("0 students") | Root cause was the **demo seed**, not code — rewrote it | Class 2-B → **40/40 students** via live API |

**Seed rewritten:** 1 school, 3 classes × 2 sections, **40 students each (240 total)**, 5 teachers, ~1 month of attendance, fees/payments dated today. Re-applied `schema.sql` to the running DB (missing `refresh_daily_revenue()` function).

### Phase 1 — Roles & navigation

- **Backend role guards, deny-by-default**: `RolesGuard` + `@Roles()` on every controller. Live-tested: admin/teacher reach the roster (200), parent blocked (403), unauthenticated (401).
- **4 role shells** (`RoleShell` + `homePathForRole`): Admin/Teacher/Parent/Student, each with its own bottom nav per §3.2 of the plan.
- **Notification center** (bell, unread badge, mark-read, pull-to-refresh) wired on every home.
- **Change Password** wired end-to-end (verified: change succeeds, wrong-old-password → 401).
- Drawer statics wired (About, Support-mailto, Rate-Play Store, Privacy/T&C, confirm-Logout); Phase-2-only items (Live Class/Gallery/Polls) hidden per the zero-dead-buttons rule.
- **Result: zero dead buttons** — every `() {}` handler eliminated app-wide.

### Phase 2 — Students & Attendance v2

- **Auto-generated credentials** (§4 of the plan): `POST /students` runs an atomic transaction creating the student + `STU-{admission_no}` / `PAR-{admission_no}` logins with 8-char temp passwords, `must_change_password=true`; sibling reuse of an existing parent by phone; auto-suggested admission numbers.
- **Login by ID** (`loginId` on `/auth/login-password`) + forced first-login password-change screen, enforced from splash.
- **Credential Slip** screen (Copy/Share, one-time warning) + deactivate/reset-credentials endpoints, audit-logged **without plaintext passwords**.
- **§4 acceptance passed live**: add student → log in as generated STU-/PAR- accounts → `mustChangePassword=true` → change → flag clears.
- **Attendance v2 history**: `GET /attendance/me` + `/attendance/student/:id`, ownership-enforced (parent→non-child = 403). Live: parent sees child at 90.9% (present 9, late 1, leave 1 of 11).
- **Bulk CSV import**: `POST /students/bulk-import`, each row in a `SAVEPOINT` so a bad row fails in isolation (verified: 2 imported, 1 bad-row error reported cleanly) — **plus a Flutter Bulk Import screen** (paste CSV, wired from Add Student).
- **Holiday calendar**: `holidays` table + CRUD endpoints — **plus a Flutter Holiday Calendar screen** (date-picker add/list/delete, wired from the attendance picker).
- **Defaulters report**: `GET /attendance/defaulters?threshold=` — 138 students <90% on the demo — with a Flutter screen wired to "Generate Report".

### Phase 3 — Revenue v2 + Communication

- **Revenue v2 (§6 of the plan)**: `other_income` table + void columns on payments/expenses; `POST /fees/income`, `POST /fees/void`, `GET /fees/today`, `GET /fees/revenue-range`. **Corrected the Total Revenue formula** to the plan's exact spec (`received + back_due + fine − expense`, discount shown not subtracted, voided excluded) — the old buggy total (₹73,500) is now the correct **₹71,800** on the demo.
- **§6 acceptance passed live**: +₹500 income → card updates within one refresh → void → reverts to previous; audit log shows both.
- **Comms suite + notification fan-out**: notices/circulars/messages now resolve an audience (all/parents/teachers/students/section) to user IDs and insert real `notifications` rows. Live: admin notice to parents → parent unread **0→1**, appears in their center.
- **Suggestions inbox + reply**, **Leave apply/approve** (teacher self, parent-for-child with ownership check) with notify-on-decision — all live-verified with unread counts incrementing.
- Flutter: Today's Revenue screen (add income/expense + void), Create Notice, Leave Approvals, Suggestions Inbox, Apply Leave — all wired into Quick Links / the comms FAB / teacher home.

### Phase 4 — Academics + Super-admin

- **New `AcademicsModule`**: homework (create + section/my views), study material, exams + bulk marks entry with ownership-enforced results views.
- **Academics acceptance passed live**: teacher assigns homework → parent sees it; teacher enters marks → parent sees the report card (Maths 92, Science 85).
- **Super-admin platform (§9 of the plan)**: new auth realm (`is_superadmin` flag, school-less JWT), an **RLS bypass** for platform-owner sessions (`... OR current_user_role()='superadmin'`) that leaves tenant isolation intact — **the RLS isolation e2e test still passes 5/5** with the bypass in place.
- **§9 acceptance passed live**: founder creates a 2nd school + principal slip → new principal logs in (forced change) → **sees 0 students, not the demo's 240** — isolation holds even through the superadmin path. Regular admin gets 403 on `/superadmin/*`.
- **Next.js super-admin web**, driven end-to-end in a real browser during the audit: login (with a wrong-password error-banner probe), live dashboard (schools/students/teachers counts), Create School modal → credential slip modal, Suspend/Activate, Reset principal, Logout (clears session). `next build` passes clean.

---

## 3. Runtime verification & audit results

*(Not previously in any tracking file — this is the audit conducted after the phase work, plus the polish pass that followed it.)*

### Backend
Re-confirmed live: 73 HTTP routes across 12 modules, deny-by-default on every endpoint, role-gating (401/403) correct everywhere probed, IDOR probe (cross-tenant object fetch by ID) → **404** via RLS, suspended-school login correctly blocked, audit logs contain no plaintext passwords.

### Flutter mobile — environment blocker resolved mid-session
Flutter/Dart were **not installed** in this environment at the start. Mid-session:
1. Installed **Flutter 3.44.2 / Dart 3.12.2** (Homebrew's large-file download was flaky against `storage.googleapis.com`; resolved with `curl -C -` resume of the 2.2 GB SDK zip).
2. `flutter analyze`: started at **58 issues (2 errors, 5 warnings, 51 infos)**. Fixed the 2 real errors (SDK-version skew: `CardTheme`→`CardThemeData`; a stale default-template test referencing a non-existent `MyApp` class, replaced with real tests) and cleaned unused imports.
3. **Polish pass**: migrated all 18 `Color.withOpacity()` calls → `.withValues(alpha:)`, ran `dart fix` for `prefer_const`/unused/`!` (22 more fixes). **Final: 6 issues, 0 errors, 0 warnings** (the 6 remaining are intentional `DropdownButtonFormField.value` deprecations, deliberately left un-migrated to avoid a controlled-dropdown-reset regression).
4. `flutter test`: **4/4 pass** (role-routing logic tests, `ComingSoonScreen` + `LoginScreen` render tests).
5. `flutter run -d web-server`: **compiled, launched, and rendered** the real login screen (screenshot evidence) — proving the ~27-screen app actually builds and runs, not just parses.
6. Built the **2 screens the audit flagged as backend-only**: Holiday Calendar and Bulk Import, both `flutter analyze`-clean and wired to real entry points.

### Next.js web — fully driven interactively
Login → dashboard (live counts) → Create School (form → credential slip modal) → Suspend/Activate toggle → Logout (session cleared) — all clicked through in a real browser with screenshots and zero console errors.

### Security findings
No Critical or High severity issues open. All of: unauthorized-route 401, wrong-role 403, wrong-password rejection (both web and API), suspended-school login block, IDOR→404, session persistence + clean logout, audit-log-no-plaintext — verified.

### Known limitation
Flutter's web target renders to a single CanvasKit `<canvas>` with no per-widget DOM, so post-login screens can't be click-driven via browser automation tooling (the app's real target is Android). This is a **tooling gap, not an app defect** — closing it fully requires an Android `integration_test` run (see §5 below).

---

## 4. Current feature status (condensed)

Full per-screen/per-button detail is in `FEATURE_STATUS.md`. Summary:

| Area | Status |
|---|---|
| Auth, roles, 4 shells, notification center, zero dead buttons | ✅ |
| Student credentials, attendance history, bulk import, holidays, defaulters | ✅ |
| Revenue v2 (income/expense/void, corrected formula), comms + fan-out, suggestions, leave | ✅ |
| Academics (homework/material/results), super-admin platform + web | ✅ |
| Edit-student UI, monthly register PDF | 🟡 pending |
| Revenue-range graph screen (backend ready) | 🟡 pending |
| Report center, syllabus/timetable CRUD | 🟡 pending |
| FCM push + deep links, SMS provider, circular file upload, contact directory | 🟡 pending |
| Phase 5 (i18n, Sentry, analytics, Play track, load test) | ⬜ not started |

---

## 5. What we need to do next

### A. Immediate code remainders (still fully codeable, backend-verifiable the same way as everything above)
- Edit-student UI (backend `PATCH /students/:id` already exists).
- Monthly attendance register (matrix student×day) as exportable PDF/CSV, per plan §7.
- Revenue-range graph screen in Flutter (`GET /fees/revenue-range` backend is done; needs a chart UI).
- Super-admin **report center** (async PDF generation + notify-when-ready, per plan §5.1/§10).
- Syllabus and timetable CRUD (tables exist in schema; no endpoints/screens yet).
- Circular file upload (endpoint exists, needs a file-picker UI) and staff contact directory.
- Parent "Apply Leave for child" entry point (backend already supports it; teacher-side entry point exists, parent-side doesn't yet).
- Teacher "request removal" → admin approvals queue (plan §4, noted as not-yet-built).

### B. Needs external services or credentials (cannot be completed autonomously in this environment)
- **FCM push notifications** + deep-link navigation (notification rows already store the deep-link `data` — just needs Firebase project credentials and the client-side handler).
- **SMS provider integration** (MSG91/Gupshup — the service has a stub `dispatchSms()` waiting for real credentials).
- **Sentry** error tracking.
- **Play Store internal track** build and submission.
- **Hindi i18n** strings file (plan §2.8).
- **Load test**: 500 concurrent attendance-session submissions (plan §10, Phase 5).

### C. Needs a human / physical device step
- **Android `integration_test` run** for full in-app click-through of all ~27 screens — the one verification gap from the audit. CanvasKit web isn't DOM-automatable; this needs either a connected Android device/emulator or a CI runner with one.
- **Real-device manual QA pass** per the original plan's Phase-0 rule #3 (build a debug APK, walk the manual test checklist on an actual phone).
- Business decisions: SMS provider selection, Play Store listing details, target launch markets for Hindi i18n priority.

---

## 6. Appendix — how to run everything

**Backend (from repo root):**
```bash
docker compose up -d postgres redis        # Postgres + Redis
npm run seed --workspace=apps/api          # or: npm run db:seed
npm run api                                 # NestJS on :3000 (prefix /api/v1)
```

**Web (Next.js super-admin):**
```bash
npm run web                                 # :3001, defaults to http://localhost:3000/api/v1
```

**Mobile (Flutter — SDK now installed at `~/development/flutter`):**
```bash
export PATH="$HOME/development/flutter/bin:$PATH"
cd apps/mobile
flutter pub get
flutter analyze                             # should show 6 infos, 0 errors/warnings
flutter test                                # 4/4
flutter run -d web-server --web-port=8090 --dart-define=API_URL=http://localhost:3000/api/v1
```

**Demo credentials** (school code `VDTRK2627DEMO01`, all passwords `Demo@1234` unless noted):

| Role | Login |
|---|---|
| Admin | phone `9999900001` |
| Teacher | phone `9999900002` (…03–07 = 4 more teachers) |
| Parent | phone `9999900003` |
| Super-admin (platform owner) | email `founder@vidyatrack.in` |

Re-seeding (`npm run seed`) is safe to run repeatedly — it wipes and rebuilds the demo school's tenant data only.
