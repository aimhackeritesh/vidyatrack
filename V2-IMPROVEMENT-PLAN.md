# VidyaTrack v2 — Improvement & Completion Plan
**For: Claude Code** | **Date: June 2026** | **Supersedes nothing — extends PRD v1.0**

## How to use this document (instructions to Claude Code)
1. Read this entire file before writing code. Then execute **phase by phase, in order** (Phase 0 → 5). Do not start a phase until the previous phase's acceptance checklist passes.
2. **Zero dead buttons rule:** every tappable element listed in Section 5 must perform its named action. If a feature cannot be completed in the current phase, the button must not exist on screen yet (hide it) — never ship a button that does nothing. No "TODO", no empty `onPressed: () {}`.
3. After every phase: run `flutter analyze` (0 errors), run all tests, build a debug APK, and print a manual test checklist for the human to verify on a real device.
4. Maintain a `FEATURE_STATUS.md` in the repo root: a table of every screen/button → status (working / hidden / pending) updated each phase.
5. Use the existing repo. Refactor, don't rewrite from scratch, unless a file is unsalvageable.

---

## 1. Current state (observed from the v1 APK — screenshots reviewed)

### Confirmed bugs (fix in Phase 0)
| # | Bug | Evidence | Likely cause / fix direction |
|---|---|---|---|
| B1 | Home screen renders **Academics + Account sections and FAB multiple times** (duplicated blocks stacked vertically) | Screenshot 1 | Widget tree built inside a loop / ListView.builder over wrong list, or sections added per-rebuild. Home must be ONE `CustomScrollView`/`SingleChildScrollView` with each section exactly once. FAB belongs in `Scaffold.floatingActionButton`, not inside the scroll list. |
| B2 | **Student Attendance chart y-axis garbled** — labels overprinted/stacked on top of each other on the left edge | Screenshots 1, 3 | fl_chart `leftTitles` misconfigured: no `interval`, `reservedSize` too small, or rendering every double value. Fix: compute `maxY` from data (min 100 for %), set `interval` (e.g. 20), `reservedSize: 36`, format as integers `0/20/40/60/80/100`. X-axis: max 7 labels, `dd MMM` two-line style as designed. |
| B3 | Chart shows wrong data shape — attendance should be a **percentage (0–100%) per day**, not raw counts that spike randomly | Screenshot 3 | Backend must return `[{date, present, total, pct}]` from a summary query; app plots `pct`. Days with no session = gap or 0 with grey marker, not interpolated. |
| B4 | **FAB overlaps Daily Revenue rows** (Amount Received value hidden behind FAB) | Screenshot 3 | Add bottom padding to scroll content = FAB size + 24px (`padding: EdgeInsets.only(bottom: 96)`), and right-padding on revenue rows; FAB must be a proper Scaffold FAB so it floats above content predictably. |
| B5 | **Attendance roster empty — "Class 2 - Section B, 0 students"** | Screenshot 4 | Either students API returns empty (no seed data / wrong section_id mapping) or app isn't calling it. Fix the `GET /sections/:id/students` flow end-to-end + add seed data + show explicit empty state: "No students enrolled in this section yet. [Add Students]" (admin only). Submit button must be disabled when roster is empty. |
| B6 | **Most buttons do nothing** (tiles, quick links, drawer items) | User report | Phase 1–4 wire every route per Section 5. Until wired, hide. |
| B7 | Daily Revenue is all ₹0 with **no way to enter revenue** | Screenshots + user report | Build the manual revenue/fee-collection entry flows (Section 6). |
| B8 | Single interface for everyone — **no role separation** | User report | Implement role-based routing (Section 3). |

### What seems OK (keep)
- Visual language (lavender bg, pastel tiles, bottom nav, FAB speed-dial in screenshot 2) matches the target design — keep and reuse these widgets.
- School-code app bar, notification bell placement, Quick Links row.

---

## 2. Product clarifications & new requirements (from founder)

1. **Three+ distinct in-app experiences**: Admin (principal), Teacher, Parent, Student — different home screens, different bottom navs, different permissions. One codebase, role decided at login.
2. **Admin can manually add/adjust revenue daily** — not just via student fee receipts. Admin records: fee collections, *other income* entries (e.g., admission form sales, donations), expenses, and can **edit/correct today's entries** (with audit log). Dashboard graph and Daily Revenue card must reflect these immediately.
3. **Teachers and Admin** can: add/remove (deactivate) students, upload study material, and mark daily attendance. (Removal by teacher = request → admin approves; admin removes directly. Hard delete never — soft `status=inactive`.)
4. **Parents**: receive ALL relevant notifications (absence, notices, homework, fee due, results), and can view their child's full attendance history and stats.
5. **Auto-generated credentials**: when a student is added, the system **immediately generates a Student login ID + temporary password AND a Parent login ID + temporary password**, shown on screen + shareable as a credential slip (text/WhatsApp share + printable PDF). First login forces password change; "Change Password" works from Profile thereafter. ID format: `STU-{admission_no}` and `PAR-{admission_no}` (unique per school; login = School Code + ID + password, OR phone+OTP for parents).
6. **Attendance visibility**: every stakeholder can view attendance appropriate to their role — admin: whole school; teacher: their sections; parent/student: own/child — calendar view + monthly % + history list.
7. **Super-admin (platform owner = founder)**: separate web access to create schools, create the school's first admin (principal) account, suspend schools, see per-school usage. Principal gets **Admin** role only within their school.
8. **Scale-ready niceties** (include now, small effort): pagination everywhere, pull-to-refresh, skeleton loaders, empty states with action hints, error toasts with retry, date pickers default to today, Hindi-ready strings file, analytics events on every primary action.

---

## 3. Role-based architecture (Phase 1)

### 3.1 Auth & session
- Login screen: School Code + (Login ID + Password) OR (Phone + OTP). Response returns `{user, roles[]}`.
- If multiple roles/children → role picker screen; persist last choice.
- JWT contains `user_id, school_id, role, entity_id` (teacher_id/student_id/parent link). Refresh token rotation. Logout clears local DB cache.
- Forced password change flag `must_change_password=true` for generated credentials.
- Route guard: a single `RoleGate(allowed: [...])` widget + backend guard decorator on every endpoint. **Every endpoint must declare allowed roles — deny by default.**

### 3.2 App shell per role (Flutter: one app, four shells)
| Role | Bottom nav tabs | Home content |
|---|---|---|
| **Admin** | Home · Attendance · Account · Profile | Charts (student+teacher attendance), Quick Links, Daily Revenue card, Academics grid, Account grid, FAB comms menu |
| **Teacher** | Home · Attendance · Academics · Profile | My classes today, "Mark Attendance" CTA per section, my timetable, recent notices, FAB (Message Parent, Homework, Material) |
| **Parent** | Home · Attendance · Fees · Profile | Child card (switcher if multiple), today's status (Present/Absent), notifications feed, homework due, notices, fees due banner |
| **Student** | Home · Homework · Results · Profile | Today timetable, homework due, study material shortcuts, my attendance % |

Implementation: `HomeRouter` reads role → returns `AdminShell()/TeacherShell()/ParentShell()/StudentShell()`. Shared widgets live in `/lib/shared/widgets`.

---

## 4. Student lifecycle & credentials (Phase 2 — high priority)

### Add Student (Admin; Teacher = same form, lands as "pending" until admin approves — config flag, default ON for admin-only)
Form: name*, class+section*, roll no, admission no* (auto-suggest next), DOB, gender, guardian name*, guardian phone*, photo (optional, compressed client-side), admission date (default today), fee plan (pick fee heads).

On save, backend transaction:
1. Create `students` row (status=active).
2. Create student user: `login_id = STU-{admission_no}`, password = random 8-char (readable, no ambiguous chars), `must_change_password=true`.
3. Create/attach parent user keyed by guardian phone (if a parent user with that phone exists in this school, link the new child to it; else create `PAR-{admission_no}` + temp password).
4. Return credentials **once** in the response → app shows **Credential Slip screen**: school name, student name, class, both login IDs + temp passwords, app download note. Buttons: [Share on WhatsApp] [Share as PDF] [Copy] [Done]. Also stored event in audit log (without plaintext password — passwords hashed at rest; slip is the one-time view; provide "Reset password" action that regenerates + reshows slip).

### Other flows
- **Edit student** (admin): all fields; section transfer keeps attendance history.
- **Remove student**: admin → "Deactivate" with reason (TC issued / left). Teacher → "Request removal" → admin Approvals inbox. Deactivated students excluded from rosters & invoices, retained in history/reports.
- **Bulk import** (admin, web + app): CSV template (name, class, section, roll, admission_no, guardian name, phone, DOB) → validate → preview errors → import → downloadable credential sheet (CSV/PDF) for the whole batch.
- **Reset password** (admin for anyone; self via old password; parent via OTP).

Acceptance: add a student end-to-end on device → log out → log in as that student with slip credentials → forced password change → student home loads. Same for parent.

---

## 5. THE BUTTON MAP — every tappable element and its required action
*(Claude Code: this section is the contract. Implement exactly; hide what's not yet built.)*

### 5.1 Admin
**App bar:** hamburger → drawer; bell → Notifications screen (list, read/unread, tap → deep link to item).
**Drawer:** Home→home; Live Class→list of links (P2, hide v2.0); Gallery (P2, hide); Polls (P2, hide); About Us→static; Support→FAQ + contact (mailto/tel); Rate us→Play Store intent; Privacy Policy / T&C→webview; Logout→confirm dialog→login.
**Charts:** tap Student chart→Attendance Reports (school view); tap Teacher chart→Teacher Attendance screen.
**Quick Links:** Student Search→search screen→student profile; Suggestion→suggestions inbox (list+reply); Generate Report→Report Center; Notice→create/list notices; Leave→approvals queue (approve/reject with note→notifies applicant).
**Daily Revenue card:** tap anywhere→Today's Revenue detail (Section 6); each row optional drill-down to its entries.
**Academics grid:** Study Material→browse by class/subject + [Upload] ; Class Routine→timetable viewer + [Edit] (admin); Home Work→list by section + detail; Result→exams list→marks entry grid / report card view; Attendance→same as bottom tab; Syllabus→per class list + [Upload].
**Account grid:** Total Revenue→range report (today/week/month/custom; chart + table); Student Wise Report→per-student dues/paid list, tap→ledger; Expenses→list + [Add Expense]; Generate Report→Report Center (pick type+range→async generate→notification when ready→open/share PDF/CSV).
**FAB speed-dial:** Message to Parent/Student/Teacher→compose (audience picker: all/class/section/individual; channel: push, +SMS toggle)→send→delivery report; Suggestions→same inbox; Contact Directory→staff list (tap-to-call); Notify Student / Notify Faculty→template picker→one-tap broadcast; Circular→upload PDF/image + audience→publish.
**Bottom nav:** Home; Attendance→Class&Section select→roster (mark/edit, admin can edit past days w/ audit); Account→Account grid screen; Profile→school profile (editable: logo, principal, address, email) + Change Password + Logout.

### 5.2 Teacher
Home cards: each of "My sections today" → [Mark Attendance] → roster; timetable→read-only; notices→detail.
Attendance tab: own sections only; today default; past = view-only (mark window: same-day, config).
Academics tab: Homework [list/create for own sections], Study Material [browse/upload own subjects], Results [enter marks for assigned exams], Syllabus [view].
FAB: Message to Parent (own sections), Create Homework, Upload Material, Apply Leave (form→status tracker).
Profile: my details, my attendance summary, Change Password, Logout.

### 5.3 Parent
Home: child switcher (if >1); today's attendance status chip; feed of notifications (absence, notice, homework, fee, result — tap→detail).
Attendance tab: month calendar (P/A/L/Leave/Holiday color dots) + % stats + history list; month picker.
Fees tab: current dues, invoice list, payment history, receipt PDF download/share. ([Pay online] hidden until gateway phase.)
Profile: child info (read-only), guardian phone (editable via OTP), Apply Leave for child (→ teacher/admin approval), Suggestion box, Change Password, Logout.

### 5.4 Student
Home: timetable today, homework due list (tap→detail→[Mark as done]); material shortcuts.
Homework tab: pending/done filter. Results tab: exam list→marks card. Profile: my attendance %, syllabus, Change Password, Logout.

---

## 6. Revenue module v2 (Phase 3) — manual control for Admin

### Entry types (all tenant-scoped, all audit-logged)
1. **Fee collection** (existing): search student→dues→record payment (cash/UPI ref/cheque) + fine + discount→receipt no→PDF receipt share.
2. **Other income** (NEW): [Add Income] → category (Admission forms / Donation / Transport / Uniform-Books / Other+free text), amount, note, date (default today) → appears in Amount Received + Total.
3. **Expense**: category, amount, note, date.
4. **Adjustment/Correction** (NEW): admin can edit or void any of today's entries; past entries → "Adjustment entry" (delta + reason) rather than silent edit. Every change writes `audit_log(actor, before, after, reason, ts)`.

### Daily Revenue card (live) definitions — implement exactly
- Amount Received = today's fee payments (principal) + other income
- Back Due Received = portion of today's payments applied to previous months' dues
- Fine Received = sum of fine fields today
- Expense = today's expenses
- Discount = sum of discounts today (red)
- **Total Revenue = Amount Received + Back Due Received + Fine Received − Expense** (Discount shown, not subtracted from received cash; document this rule in code comments and on the report footer).

### Revenue graph (replaces broken chart where relevant)
- `GET /reports/revenue-daily?from&to` → `[{date, received, expense, net}]` from a `daily_revenue_summary` table updated transactionally on every entry (no nightly-only jobs — admin must see instant effect).
- Account→Total Revenue screen: bar/line for range + totals table + export.

Acceptance: add ₹500 other income → Daily Revenue card updates within one refresh; void it → returns to previous; audit log shows both.

---

## 7. Attendance module v2 (Phase 2)
- Roster: list students (photo initial, roll, name), ALL default **Present**; tap cycles P→A→L(eave)→Late; long-press for remark. Header counters P/A live; **All P / All A** set all (as in current UI). Search filters list. Submit = ONE bulk call `POST /attendance/sessions {section_id, date, records[]}` (idempotency key). Disabled if 0 students (B5).
- Offline: roster cached; submissions queue with visible badge "Pending sync (1)"; sync on connectivity; conflict = last-write-wins per (student,date).
- After submit: enqueue parent notifications for Absent/Late only.
- Holiday calendar (admin sets) → those dates excluded from % and marked grey.
- Reports: school day view (per class %), defaulters (<75% configurable), monthly register (matrix student×day) exportable PDF/CSV; parent/student calendar view.
- Teacher attendance: admin marks staff list daily OR teacher self check-in (flag, default admin-marks).

---

## 8. Notifications (Phase 3)
- In-app notification center (bell) for ALL roles; unread badge; types: absence, notice, circular, homework, result published, fee due (auto on invoice due-3 days), leave status, message.
- FCM push for each; tap → deep link to the exact screen. Store `notifications` rows server-side; mark-read sync.
- SMS optional per send (admin toggle; show credits remaining — super-admin sets credits).

---

## 9. Super-admin (Phase 4 — Next.js web, minimal but real)
- Login (separate auth realm). Dashboard: schools list (status, students count, last activity).
- [Create School]: name, city, principal name+phone+email → generates School Code + principal Admin credentials slip.
- Per school: suspend/activate, reset principal password, set plan limits (max students, SMS credits), usage stats (DAU, attendance coverage %).
- Impersonate (read-only) for support — audit-logged. No cross-school data mixing anywhere else; keep the RLS isolation test green.

---

## 10. Phase plan & acceptance checklists

### Phase 0 — Stabilize (bugs B1–B5) 
Fix duplicate home sections; FAB to Scaffold; chart axis + % data; bottom padding; roster fetch + seed script (`npm run seed:demo` creates 1 school, 3 classes×2 sections, 40 students each, 5 teachers, 1 month of attendance+fees). ✅ when: home renders each section once on 3 screen sizes; chart shows 7 labeled days 0–100%; Class 2-B shows 40 students; submit works.

### Phase 1 — Roles & navigation
Role-based login/JWT/guards; 4 shells; wire ALL drawer/static buttons; Notifications screen skeleton; hide unbuilt features. ✅ when: logging in as each seeded role lands on its own shell; FEATURE_STATUS.md has zero "dead" buttons.

### Phase 2 — Students & Attendance v2
Section 4 + Section 7 complete incl. credential slips, bulk import, calendar views, offline queue. ✅ when: acceptance flows in §4 and §7 pass on device.

### Phase 3 — Revenue v2 + Communication + Notifications
Section 6 + messaging/notice/circular/suggestions/leave + notification center w/ deep links. ✅ when: §6 acceptance passes; a notice sent by admin appears on parent device push + bell within 30s.

### Phase 4 — Academics completion + Super-admin web
Homework/material/results/syllabus/timetable full CRUD per role matrix; report center async PDFs; super-admin per §9. ✅ when: teacher uploads PDF visible to student; marks entered → parent sees report card; founder creates a 2nd school and isolation test passes.

### Phase 5 — Scale & polish
Hindi strings, pagination+skeletons everywhere, Sentry, analytics events, app size check (<30MB), Play internal track build, load test attendance submit (500 concurrent sections).

---

## 11. Engineering ground rules for Claude Code
- State management: Riverpod (or keep existing if Bloc — be consistent). Repository pattern: UI → provider → repo → (local cache, API).
- Charts: fl_chart with explicit `minY:0, maxY:100, interval:20, reservedSize:36`; never auto-titles.
- Every list: pull-to-refresh + pagination + empty state widget + error+retry widget (make these 3 shared components first).
- All money in paise (int) server-side; format ₹ on client.
- Dates: store UTC, display Asia/Kolkata; "today" = school local date.
- Write tests: unit (revenue math §6, attendance %), API e2e (auth/roles/RLS isolation), and golden test for the home dashboard to catch duplicate-section regressions (B1).
- Conventional commits; one PR per phase; update FEATURE_STATUS.md + CHANGELOG each PR.
