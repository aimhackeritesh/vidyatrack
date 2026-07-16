# VidyaTrack — V3 Master Plan

> **Goal of V3:** Make *every button function* for **parents**, give **admin/principal** full control over Timetable, Syllabus, Study Material and **Fee structure**, let **parents view pending fees and pay in-app**, and add **hardcore super-admin** capabilities.
>
> **Guiding rule (carried from V2):** Zero dead buttons. Every screen/button lands on a real, working destination or an explicit, honest "coming soon". Every backend change is verified live against Postgres before it is called done. Every phase updates `FEATURE_STATUS.md` + `CHANGELOG.md`.

**Status legend:** ✅ done · 🟡 planned this version · 🔒 hidden/deferred · 🐞 bug→fix

---

## 0. Where V3 starts (current reality)

**Good news — the data model is already there.** The Postgres schema (`apps/api/src/database/schema.sql`) already defines the tables V3 needs; they are just not wired to endpoints or UI:

| Table | Exists? | Endpoints? | Flutter UI? |
|---|---|---|---|
| `timetable_slots` (section·day·period·subject·teacher·time) | ✅ | ❌ none | ❌ none |
| `syllabus` (class·subject·topics_json·file_url) | ✅ | ❌ none | ❌ none |
| `study_materials` (class·subject·title·file_url·type) | ✅ | ✅ POST/GET (no upload) | ❌ no dedicated screen |
| `fee_heads` (name·amount·frequency·class_id) | ✅ | ✅ **read-only** GET | ❌ none |
| `fee_invoices` (student·month·due·status) | ✅ | ✅ GET dues | 🟡 parent tab is placeholder |
| `fee_payments` (invoice·amount·mode·fine·discount) | ✅ | ✅ POST (manual cash) | ✅ admin only |

**The gaps V3 fills:**
1. **Fees are not *settable*** — `fee_heads` has no create/edit/delete endpoint; there is no invoice **generation** (no way to turn fee heads into monthly invoices per student); there is no **online payment** (`payment_mode_enum` has `'online'` but nothing issues/verifies a gateway order); the parent **Fees tab is still a placeholder**.
2. **Timetable & Syllabus** have zero endpoints and zero screens.
3. **Study Material** has no file **upload** and no **parent/student browse** screen.
4. **Super-admin** can create/suspend schools but has **no platform analytics, billing/plan control, feature flags, or broadcast**.
5. Several parent-facing buttons still land on placeholders.

**Environment notes (from V2):**
- Flutter SDK installed at `~/development/flutter` (3.44.2 / Dart 3.12.2). `flutter analyze` must stay at **0 errors/warnings**.
- API runs `node apps/api/dist/src/main` with `DATABASE_URL=vidyatrack_app@localhost`, `REDIS_URL=localhost`. Entry is `dist/src/main`, **not** `dist/main`.
- Web (super-admin) runs `npm run dev --workspace=apps/web` on :3001.
- Dev OTP is logged to API console.
- RLS multi-tenancy: every new table/policy must respect `current_user_role()='superadmin'` bypass. RLS isolation e2e (`test/rls-isolation.e2e-spec.ts`) must stay green.

---

## 1. V3 scope — the six workstreams

| # | Workstream | Who it serves | Headline outcome |
|---|---|---|---|
| **A** | Timetable | Admin sets · Parent/Student/Teacher view | Weekly grid per section, editable by admin, visible to all |
| **B** | Syllabus | Admin/Teacher set · Parent/Student view | Per class+subject syllabus with topics & optional file |
| **C** | Study Material | Teacher/Admin upload · Parent/Student browse & download | Real file upload + browsable, filterable library |
| **D** | Fees (the big one) | Admin/Principal set structure · Parent view dues & **pay online** | Fee heads → auto invoices → parent sees pending → pays via gateway → receipt |
| **E** | Super-Admin power-ups | Platform owner | Analytics, plan/billing, feature flags, broadcast, audit viewer |
| **F** | "Every button works" sweep | Parent (primary) + all roles | Audit + wire every remaining placeholder button |

Shared infrastructure built once and reused by C & D: **File storage service** and **Payment gateway service**.

---

## 2. Shared infrastructure (build first — A/B/C/D depend on it)

### 2.1 File storage service (`apps/api/src/common/storage/`)
- Abstraction `StorageService` with one implementation for local dev (`uploads/` served by API static route) and a swappable S3/Cloudinary adapter behind the same interface.
- `POST /uploads` (multipart, `@Roles('admin','teacher','superadmin')`) → returns `{ url, type, size }`. Enforces max size (e.g. 15 MB), allowed MIME (pdf/jpg/png/docx), virus-safe filename, per-school folder key.
- Used by Study Material (C), Syllabus files (B), and later circular uploads.
- Flutter: reusable `FilePickerUploader` widget (uses `file_picker` package) → uploads → returns URL to embed.

### 2.2 Payment gateway service (`apps/api/src/fees/payment/`)
- **Provider: Razorpay** (India-standard; UPI/card/netbanking) behind a `PaymentGateway` interface so it can be mocked.
- **Sandbox/mock mode toggle** (`PAYMENT_MODE=mock|razorpay`). In `mock` mode (default for this demo, since no live merchant keys), the "gateway" auto-confirms after a simulated delay so the full parent-pays flow is demonstrable end-to-end without real money. In `razorpay` mode it uses test keys.
- Flow: `create order` → client opens checkout → gateway callback/**webhook** → **server-side signature verification** → record `fee_payment(mode='online')` → recompute invoice status → notify parent + refresh daily revenue.
- **Never trust the client**: payment is only marked paid after server verifies the webhook/signature.

---

## 3. Workstream A — Timetable

**Backend** (`apps/api/src/academics/` — extend, table `timetable_slots` exists):
- `POST /academics/timetable` `@Roles('admin')` — upsert one slot `{sectionId, day(1–7), periodNo, subject, teacherId?, startTime, endTime}`. Respects `UNIQUE(school,section,day,period)`.
- `POST /academics/timetable/bulk` — replace a section's whole week in one transaction (admin edits the grid then saves once).
- `GET /academics/timetable?sectionId=` `@Roles('admin','teacher')` — full grid for a section.
- `GET /academics/timetable/my` `@Roles('student','parent')` — resolves viewer → their (child's) section → grid. Reuse the section-resolution helper already used by homework `/my`.
- `DELETE /academics/timetable/:id` `@Roles('admin')`.
- Validation: no overlapping periods for the same section; warn (not block) on teacher double-booking across sections.

**Flutter:**
- `TimetableGridScreen` (view) — Mon–Sat columns × periods, subject + teacher + time chips. Parent/Student read-only; wired to **parent home "Timetable" tile** + **student home Timetable tile** (currently placeholders 🟡→✅).
- `EditTimetableScreen` (admin) — pick class→section, tap a cell → subject/teacher/time editor → Save (bulk). Entry: admin Academics grid "Timetable" tile.
- Teacher: read-only "My Timetable" (their periods) on teacher home.

---

## 4. Workstream B — Syllabus

**Backend** (table `syllabus` exists, `UNIQUE(school,class,subject)`):
- `POST /academics/syllabus` `@Roles('admin','teacher')` — upsert `{classId, subject, topicsJson?, fileUrl?}`. `topicsJson` = ordered list of units/topics with optional "done" flag for progress tracking.
- `GET /academics/syllabus?classId=` `@Roles(all)`.
- `GET /academics/syllabus/my` `@Roles('student','parent')` → viewer's class.
- `DELETE /academics/syllabus/:id` `@Roles('admin')`.

**Flutter:**
- `SyllabusScreen` (view) — per subject, expandable topic list + "Download syllabus" if file. Wired to parent/student home "Syllabus" tile.
- `EditSyllabusScreen` (admin/teacher) — pick class+subject, add/reorder topics, attach file via `FilePickerUploader`. Entry: Academics grid "Syllabus".

---

## 5. Workstream C — Study Material

**Backend** (endpoints exist; add upload + scope):
- Keep `POST /academics/materials` but accept an **uploaded `fileUrl`** from §2.1 (or an external link). Add `type` detection.
- `GET /academics/materials?classId=&subject=` — already public to all roles; add subject filter + newest-first + created-by name.
- `GET /academics/materials/my` `@Roles('student','parent')` → materials for viewer's class (so parents don't need to know classId).
- `DELETE /academics/materials/:id` `@Roles('admin','teacher')` (own or admin).

**Flutter:**
- `StudyMaterialScreen` (browse) — filter by subject, cards with type icon (pdf/img/link), tap → open/download (`url_launcher`/in-app viewer). Wired to **parent home "Study Material" tile** + student home + teacher.
- `UploadMaterialScreen` (teacher/admin) — title, subject, class, pick file or paste link → upload. Entry: teacher home "Material" (currently 🟡) + Academics grid.

---

## 6. Workstream D — Fees (headline feature)

This is the deepest workstream. Split into four sub-parts.

### D1 — Admin/Principal sets the fee structure
Table `fee_heads` exists (name·amount·frequency·class_id, `class_id NULL = all classes`). Add write endpoints:
- `POST /fees/heads` `@Roles('admin')` — create head `{name, amount, frequency, classId?}`.
- `PUT /fees/heads/:id` / `DELETE /fees/heads/:id` `@Roles('admin')`.
- `GET /fees/heads` already exists (list).
- **Flutter `FeeStructureScreen`** (admin) — list heads grouped by class, add/edit/delete, set monthly/quarterly/annual/one-time amount. Entry: admin Account grid "Fee Structure" tile.

### D2 — Invoice generation (turn structure into per-student dues)
No generator exists today. Add:
- `POST /fees/invoices/generate` `@Roles('admin')` `{month, classId?}` — for each active student in scope, sum applicable `fee_heads` (class-specific + all-class, prorated by frequency for that month) → create/refresh a `fee_invoice` for that `month`. Idempotent (skip if already generated; recompute due if heads changed and invoice still pending). Runs in a transaction; returns counts.
- **Optional automation:** a BullMQ monthly cron that auto-generates on the 1st (reuse existing Redis/BullMQ). Behind a school setting `auto_invoice=true`.
- Set `due_date` from a school-level rule (e.g. 10th of month) and flip `pending→overdue` via a daily job.

### D3 — Parent views pending fees
- `GET /fees/dues?studentId=` exists but is **school-scoped** — must **scope to the parent's own child** (ownership check, like attendance `/me`). Add `GET /fees/my-dues` `@Roles('parent','student')` → resolves child → outstanding invoices with `{month, due, paid, balance, status, dueDate}` + total outstanding.
- **Flutter `ParentFeesScreen`** — replaces the placeholder **parent Fees tab**. Shows total outstanding banner, list of invoices (paid/partial/pending/overdue chips), tap invoice → detail (heads breakdown + payment history) → **Pay Now** button. Also shows past receipts.

### D4 — Parent pays in-app (online)
Using §2.2 gateway:
- `POST /fees/pay/order` `@Roles('parent')` `{invoiceId, amount}` — server creates a gateway order (amount = balance), returns `{orderId, key, ...}`. Validates amount ≤ balance, ownership.
- Client opens Razorpay checkout (Flutter `razorpay_flutter`), or in **mock mode** a simulated confirm screen.
- `POST /fees/pay/webhook` (public, signature-verified) **or** `POST /fees/pay/verify` `{orderId, paymentId, signature}` — server verifies signature → inserts `fee_payment(mode='online', received_by=NULL)` → `recomputeInvoiceStatus` → `refreshRevenueSummary` → notify parent ("Payment received ₹X") + admin. **Idempotent** on gateway payment id.
- Receipt: `GET /fees/receipt/:paymentId` → printable receipt (reuse `receipt_no`); "Download receipt" in parent app.
- **Admin sees online payments** flow into the existing Today's Revenue / Daily Revenue automatically (mode `online`).

**Money-safety rules (must hold):**
- Payment recorded only after **server-side** verification.
- Idempotent by gateway payment id (no double credit on webhook retries).
- Amount clamped to invoice balance; overpayment rejected.
- All amounts in paise internally where the gateway requires; store rupees in `NUMERIC(10,2)` as today.
- Every write audited (`audit` helper already in `fees.service`).

---

## 7. Workstream E — Super-Admin power-ups

Extend `apps/api/src/superadmin/` + Next.js `apps/web`:
- **Platform analytics** `GET /superadmin/analytics` — total schools/active/suspended, total students, total users by role, MRR-ish (sum online fee volume), attendance-marked-today count, invoices generated/paid this month. Dashboard cards + a simple trend chart on the web.
- **Per-school drill-down** `GET /superadmin/schools/:id/stats` — students, revenue, last-active, storage used.
- **Plan / billing control** — add `schools.plan` (`free|standard|pro`) + `max_students` (exists) + `plan_expires_at`; endpoints to change plan; enforce limits (block add-student over `max_students`, already have the column).
- **Feature flags** — `school_settings` table (`key,value` per school) so super-admin can toggle features (online_payments, auto_invoice, materials, etc.) per school. App reads flags at login (`/auth/session` bootstrap) and hides gated UI.
- **Broadcast** — `POST /superadmin/broadcast` → fan-out a platform notice to chosen schools/roles (reuse `NotificationsService.fanOut`).
- **Audit log viewer** — `GET /superadmin/audit?schoolId=` paged read of `audit_logs`.
- Web UI: add Analytics, School detail, Plans, Flags, Broadcast, Audit pages to the existing dashboard (`next build` must stay clean).

---

## 8. Workstream F — "Every button works" sweep (parent-first)

Audit pass after A–D land. Produce/refresh the button matrix in `FEATURE_STATUS.md`. Targets:
- **Parent home tiles:** Attendance ✅, Fees 🟡→✅ (D3/D4), Homework 🟡→✅ (exists, wire tile), Results 🟡→✅ (exists), **Timetable** →✅ (A), **Syllabus** →✅ (B), **Study Material** →✅ (C), Notices ✅.
- **Parent apply-leave** entry (backend exists from V2, add parent UI).
- **Contact directory** (call/message class teacher) — backend list + parent UI.
- Student home tiles (timetable/homework/material/attendance/results/syllabus) all →✅.
- Teacher home: Material upload, My Timetable →✅.
- Kill any remaining `() {}` / "coming soon" that now has a real destination.

---

## 9. Schema deltas (migrations)

Most tables exist; deltas are additive (append to `schema.sql` + apply live, keep RLS + superadmin bypass):
1. `school_settings(school_id, key, value, PRIMARY KEY(school_id,key))` — feature flags + fee rules (due_date_day, auto_invoice). RLS + bypass.
2. `schools`: add `plan TEXT DEFAULT 'free'`, `plan_expires_at DATE` (`max_students` already exists).
3. `fee_payments`: add `gateway_order_id TEXT`, `gateway_payment_id TEXT UNIQUE` (idempotency), keep `mode='online'`.
4. `study_materials`/`syllabus`: `file_url` already present — no change; ensure `created_by` populated.
5. Indexes: `fee_invoices(student_id, status)`, `timetable_slots(section_id, day)`, `study_materials(school_id, class_id, subject)`.
6. New enum value already present (`payment_mode_enum` has `'online'`).

All migrations verified by re-applying `schema.sql` to the running dev DB and re-running the RLS isolation e2e.

---

## 10. Execution order & phasing

| Phase | Deliverable | Depends on | Verify |
|---|---|---|---|
| **V3.0** | Shared infra: StorageService + `/uploads`; PaymentGateway (mock) skeleton; schema deltas applied | — | upload a file, RLS e2e green |
| **V3.1** | **Timetable** (A) full stack | V3.0 | admin sets grid → parent/student see it (live) |
| **V3.2** | **Syllabus** (B) + **Study Material** (C) full stack | V3.0 | teacher upload → parent downloads (live) |
| **V3.3** | **Fees D1+D2** — set structure + generate invoices | schema | heads→invoices per student (live, counts checked in Postgres) |
| **V3.4** | **Fees D3** — parent sees pending dues | D2 | parent `/my-dues` shows own child only; 403 cross-child |
| **V3.5** | **Fees D4** — online pay (mock) end-to-end + receipt | D3, gateway | pay flow → invoice paid → revenue updates → receipt (live) |
| **V3.6** | **Super-admin** power-ups (E) | analytics needs data from D | web build clean, analytics reflect live data |
| **V3.7** | **Button sweep** (F) + polish, i18n stubs, `flutter analyze` 0, docs | all | manual pass on each role; matrix in FEATURE_STATUS.md |

Each phase: backend first (verify live) → Flutter (analyze clean) → update `FEATURE_STATUS.md` + `CHANGELOG.md` → mark ✅.

---

## 11. Definition of Done for V3
- Parent can, in-app: see timetable, syllabus, study material (download), see pending fees for their child, and pay online with a receipt — **every button on the parent shell reaches a real screen**.
- Admin/Principal can: set fee heads per class, generate invoices, edit timetable, manage syllabus/material.
- Super-admin has analytics + plan/flags/broadcast/audit.
- `flutter analyze` = 0 errors/warnings; `next build` clean; API builds; RLS isolation e2e green; payment flow idempotent & server-verified.
- `FEATURE_STATUS.md` shows **no 🟡 on the parent shell**; `CHANGELOG.md` updated.

---

## 12. Decisions (confirmed 2026-07-16)
1. ✅ **Payment provider** → **Razorpay**, integration built real but **mock mode is the default** (auto-confirms, no live keys needed). Flip `PAYMENT_MODE=razorpay` + test keys later without rework.
2. ✅ **File storage** → **local disk** served by API for dev, behind a `StorageService` interface with an **S3 adapter ready** to swap in.
3. **Invoice generation** → **manual button** first, **monthly BullMQ cron** as opt-in (`auto_invoice` flag).
4. **Due date rule** → configurable per school (`due_date_day`, default 10th).

> Nothing above is executed yet — this file is the plan. On approval we start at **V3.0 (shared infra + schema deltas)** and proceed phase by phase, verifying each live before moving on.
