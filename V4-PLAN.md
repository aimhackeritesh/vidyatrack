# VidyaTrack — V4 Master Plan: Differentiation, Experience & the Configuration System

> **Goal of V4:** Turn a deployed, working product into a product people can *find, try, adopt, and run without hand-holding* — and give the platform owner a real operations console so any school's setup can be inspected and changed remotely without code changes or DB surgery. Three experiences, in priority order:
> 1. **Customer experience** — a school evaluating VidyaTrack can go from "heard about it" to "trying it with real-feeling data" in under two minutes, with zero signup friction.
> 2. **User experience** — admins, teachers, and parents get an app that adapts to *their school's* rules (periods, fees, fines, grading, language, branding) instead of forcing our defaults on them.
> 3. **Owner experience** — the platform owner (you) can onboard, configure, support, and debug any school from the web console: view any school as its admin, change any setting, reset any credential, export any data — all audit-logged.
>
> **Method (house rules, unchanged since V2):** plan → build → **verify live** → document. Zero dead buttons. Every backend change proven against a running system before it's called done. `flutter analyze` 0 errors/warnings, `next build` clean, RLS isolation e2e green after every schema change. `FEATURE_STATUS.md` + `CHANGELOG.md` updated per phase.

**Status legend:** ✅ done · 🟡 this version · 🔒 deferred (post-V4) · ⛔ decision needed

---

## 1. Positioning — how VidyaTrack wins against competitors

### 1.1 The landscape (Indian school-management, Tier 2/3 segment)

| Competitor class | Examples | Their weakness we exploit |
|---|---|---|
| Big-school ERPs | Entab, Fedena, NLET | Priced and designed for large private schools; months-long onboarding; need trained operators; English-first |
| Teacher-first apps | Teachmint, Classplus | Built around coaching/tuition classes, not school administration; fees/attendance are afterthoughts; aggressive upselling |
| Local/legacy desktop software | countless regional vendors | Windows-only, no parent app, no cloud, data locked in |
| WhatsApp + paper (the real competitor) | — | Free and familiar — but no records, no fee tracking, no history |

**The actual buyer** is a principal/owner of a 100–500 student school who currently runs the school on WhatsApp groups, paper registers, and a fee notebook. They will not sit through a sales demo, will not read a manual, and their parents may not have email addresses.

### 1.2 Our differentiation wedges — each backed by a shipped or V4 feature

| Wedge (the claim) | What backs it |
|---|---|
| **"Try it before you talk to anyone"** | One-tap demo mode on the app's login screen + public landing page with QR code → installed and exploring seeded data in <2 min (V4 §A). Competitors gate demos behind sales calls. |
| **"No email addresses needed"** | Already shipped: credential-slip provisioning (STU-/PAR- login IDs + temp passwords, shareable via WhatsApp). Parents in this segment often have no email — most competitors assume one. Lean into this in all marketing copy. |
| **"Works when the network doesn't"** | Already shipped: offline attendance queue with sync. Extend the story (V4 §D). |
| **"Speaks your language"** | Hindi UI toggle (V4 §E). Teachmint has this; the big ERPs largely don't. |
| **"Set up in one morning, not one semester"** | Guided setup checklist for a new school (V4 §D) + super-admin creates a school + principal slip in one action (already shipped). |
| **"It adapts to your school, not the reverse"** | The V4 Configuration System (§3) — periods per day, fee/fine rules, attendance thresholds, grading display, branding, language — all per-school, changeable remotely, no app update needed. This is the moat: variability handled as data, not code forks. |
| **"Your data is yours"** | CSV export of students/attendance/fees from the console (V4 §C). Legacy vendors hold data hostage; we make leaving easy, which paradoxically builds trust to stay. |

### 1.3 What we deliberately do NOT compete on (V4 scope discipline)
- 🔒 Live classes / video / LMS content (Teachmint's turf; different product)
- 🔒 Transport/GPS, hostel, library, HR/payroll modules (big-ERP feature bloat; revisit only on real demand)
- 🔒 Real payment processing (still no merchant account — mock gateway stays; interface is ready when that changes)

---

## 2. Current-state audit — what V4 builds on

**Live today:** API + Postgres (RLS) + Redis on Railway; super-admin console on Vercel; release APK on GitHub Releases; password-only login; demo school seeded (240 students). All verified end-to-end.

**Foundations that make V4 cheap:**
- `school_settings` table (key/value per school, RLS'd, superadmin-bypass) — **exists but nearly unused**: only `due_date_day` is read anywhere. The console can set raw key/values blind (no types, no validation, no catalog).
- Role/guard system, notification fan-out, audit log, BullMQ — all reusable.
- Credential slips, bulk import, holiday calendar — onboarding building blocks already shipped.

**Gaps V4 closes (verified in code, not guessed):**
| # | Gap | Where |
|---|---|---|
| G1 | Settings have no registry: no types, labels, validation, defaults, or catalog — raw text key/value only | `superadmin.service.ts` settings methods |
| G2 | Only ONE setting is consumed (`due_date_day` in `fees.service.ts`); everything else that varies by school is hardcoded: timetable periods (8), defaulter threshold (75%), attendance % formula inputs, currency display, branding | grep-verified |
| G3 | The mobile app never fetches school config — nothing to fetch | no `/config` endpoint exists |
| G4 | No way for the owner to act *as* a school: no impersonation, no per-school detail page (console is modals over a table), no credential reset for arbitrary users (only principal) | `apps/web/src/app/page.tsx` (single 489-line file), `superadmin.controller.ts` |
| G5 | No public landing page — the Vercel root IS the super-admin login. A curious visitor hits an admin login form | `apps/web/src/app/page.tsx` |
| G6 | No in-app demo entry — a prospect must type a school code + phone + password from the README | `login_screen.dart` |
| G7 | Public demo school degrades: anyone can mutate it; no auto-reset | — |
| G8 | New (non-demo) school starts at zero with no guidance: empty screens, no checklist, admin must discover Add Student etc. | admin home |
| G9 | English-only UI | all Flutter strings inline |
| G10 | No error tracking in prod (a crashed request is invisible unless we read Railway logs); no uptime alerting | — |
| G11 | No data export anywhere | — |
| G12 | Console file is monolithic (489 lines, one route) — will not survive V4 additions without a split | `apps/web/src/app/page.tsx` |

---

## 3. Centerpiece: the School Configuration System ("config over code")

**Principle:** every school-variable behavior becomes a **typed, registered, per-school setting** with a default — resolved server-side, delivered to clients in one bootstrap call, editable by the right role, and audit-logged. Future variability then costs *one registry entry*, not a schema migration or app release. This is both the owner-experience win (change anything remotely) and the differentiation moat (§1.2).

### 3.1 The settings registry (code, not DB)
A single source of truth in the API: `apps/api/src/config/settings-registry.ts`

```ts
type SettingDef = {
  key: string;                 // 'timetable.periods_per_day'
  type: 'int' | 'bool' | 'string' | 'enum' | 'time' | 'json' | 'color';
  default: string;             // stored form; typed on read
  label: string;               // human name for UIs
  description: string;         // help text for UIs
  category: 'academic' | 'attendance' | 'fees' | 'timetable' | 'branding' | 'locale' | 'features';
  editableBy: 'superadmin' | 'admin';   // school admin can edit, or owner-only
  enumValues?: string[];
  min?: number; max?: number;  // validation for int/time
};
```

Storage stays the existing `school_settings` table (no schema change) — the registry adds meaning, validation, and defaults on top. Unknown keys in the table are ignored on read (forward-compatible); writes are validated against the registry (no more typo'd keys silently doing nothing).

### 3.2 V4 initial registry (the settings that actually vary between Indian schools)

| Key | Type | Default | Consumed by |
|---|---|---|---|
| `academic.year_start_month` | int 1–12 | 4 (April) | invoice generation labels, reports |
| `academic.working_days` | json | Mon–Sat | timetable day tabs, attendance % denominator |
| `timetable.periods_per_day` | int 4–12 | 8 | timetable editor + views (currently hardcoded 8) |
| `attendance.defaulter_threshold` | int 40–95 | 75 | defaulters report (currently hardcoded default) |
| `attendance.mode` | enum daily/per-period | daily | attendance UI (per-period 🔒 post-V4; setting ships now so data model is ready) |
| `fees.due_date_day` | int 1–28 | 10 | invoice generation (already consumed — migrate to registry) |
| `fees.late_fine_per_day` | int ≥0 | 0 | dues display + collection (fine suggestion) |
| `fees.invoice_prefix` | string | INV | receipts/invoices display |
| `grading.scheme` | enum percent/grade/both | percent | results screen display |
| `grading.bands` | json | A≥90, B≥75… | results screen when grades shown |
| `locale.language` | enum en/hi | en | app UI language default (§E) |
| `branding.primary_color` | color | #1E88E5 | app theme accent per school |
| `branding.show_logo` | bool | true | app bar logo (uses existing `schools.logo_url`) |
| `features.online_payments` | bool | true | hide/show Pay Now (mock) |
| `features.materials` / `features.polls` / … | bool | true/false | feature gating (flags already envisioned in V3, now enforced) |

### 3.3 Resolution & delivery
- **`GET /schools/config`** (any authenticated school role): merges registry defaults + that school's overrides → one typed JSON object. Cached in the Flutter app at login (SharedPreferences) with a version/etag; re-fetched on app start. **One round-trip, no per-screen setting lookups.**
- **API-side consumption**: a small `SchoolConfigService` (registry + cached `school_settings` reads) replaces the ad-hoc `getSetting()` in `fees.service.ts`; attendance/timetable/academics services read through it.
- **Client-side consumption**: a `SchoolConfig` provider in Flutter; screens read `config.periodsPerDay` etc. Migrating the four currently-hardcoded consumers (G2) proves the pipeline end-to-end.

### 3.4 Editing surfaces
- **Super-admin console** (owner): full typed settings form per school — grouped by category, rendered from `GET /superadmin/settings-registry` (labels/types/help served by the API so the console never hardcodes the catalog). Every write audit-logged (already is).
- **Mobile admin** (principal): a "School Settings" screen showing only `editableBy: 'admin'` settings — the school can self-serve the safe subset (fine rules, thresholds, branding color); platform-level ones (feature flags, language rollout) stay owner-only.

---

## 4. Workstreams

### A — Instant access: landing page + one-tap demo (customer experience)
The funnel today is: find GitHub → read README → download APK → type 3 credentials. V4 funnel: scan QR / click link → app installs → tap "Explore as Principal" → browsing seeded data.

- **A1. Public landing page** at `vidyatrack-web.vercel.app/` — product one-pager: the §1.2 wedges as copy, screenshots, APK download button + QR code, "Try the web console" and per-role demo credentials shown inline. The super-admin console moves to `/console` (Next.js route split fixes G12 at the same time: `page.tsx` → `app/console/` with components extracted).
- **A2. One-tap demo on mobile login**: an "Explore the demo" section with three buttons (Principal / Teacher / Parent) that log into the demo school with the seeded credentials — no typing. Visually separated from the real login so actual users aren't confused.
- **A3. Demo school auto-reset**: nightly BullMQ cron calling the existing seed logic for `VDTRK2627DEMO01` only, so public mutations don't rot the demo (G7). Also exposed as a "Reset demo now" button in the console (owner experience). Guardrail: reset endpoint refuses to run for any school code other than the demo's.
- **A4. Demo-mode banner** in-app ("You're exploring demo data — resets nightly") so prospects know it's safe to touch everything.

### B — The Configuration System (§3) (user + owner experience)
- **B1.** Settings registry + `SchoolConfigService` + validation on write (G1).
- **B2.** `GET /schools/config` + registry-catalog endpoint for UIs (G3).
- **B3.** Migrate all hardcoded consumers: periods/day, defaulter threshold, due-date day, working days, fee fine, grading display, feature flags → registry-driven (G2).
- **B4.** Flutter `SchoolConfig` provider + bootstrap fetch + the four consumer screens reading it.
- **B5.** Mobile "School Settings" screen (admin-editable subset).
- **B6.** Console typed settings editor (replaces the raw key/value modal).

### C — Owner console v2 (my experience)
- **C1. Impersonation — "Manage as school admin"**: `POST /superadmin/schools/:id/impersonate` mints a short-lived (30 min) admin-scoped JWT for that school, `impersonated_by` claim included, every use audit-logged, banner shown in console while active. This single feature is the answer to "access or change details for any school according to their requirements" — you see exactly what the school's admin sees and can fix their data with their own tools. Web console gains a school-scoped admin view (roster, fees, notices) rendered against the normal school APIs using the impersonation token — no new backend surface beyond the mint endpoint, so RLS still governs everything.
- **C2. School detail page** (console route `/console/schools/[id]`): tabs — Overview (stats, last-active), Settings (B6), Users (list, **reset any user's credentials**, not just principal), Data (exports, C4), Audit (existing log filtered to the school). Replaces the modal pile (G4/G12).
- **C3. User management endpoints**: `GET /superadmin/schools/:id/users`, `POST /superadmin/users/:id/reset-password` (slip-style temp password + forced change — reuses the students reset pattern).
- **C4. Data export**: `GET /superadmin/schools/:id/export?entity=students|attendance|fees` → CSV. Also school-admin variant for their own school (differentiation wedge, G11).
- **C5. Ops touches**: "Reset demo" button (A3), platform announcement banner (reuse broadcast), last-login tracking (`users.last_login_at`, set on login) surfaced in Users tab + analytics.

### D — Mobile UX polish & new-school onboarding (user experience)
- **D1. Setup checklist** on admin home for schools with no students: a dismissible card — "① Add classes & sections → ② Add teachers → ③ Add students (or import CSV) → ④ Set your fee structure → ⑤ Set the timetable" — each step deep-links to the existing screen and shows live done/undone state from real counts (G8). Cheap, because every destination already exists.
- **D2. Branding**: app bar shows the school's logo + `branding.primary_color` accent (from config). Small change, large perceived-ownership effect for principals.
- **D3. Empty-state sweep**: every list screen's empty state gains a one-line explanation + action button (roster → Add Student, materials → Upload, etc.). Several exist; make it universal.
- **D4. Notification deep links**: tapping a notification routes to its entity (fee → invoice, leave → approvals, homework → list) — the `data` payloads were stored for exactly this since V2.
- **D5. Fee UX detail**: dues screen shows late-fine line when `fees.late_fine_per_day` > 0; receipts show `fees.invoice_prefix`.

### E — Hindi (i18n) (user experience, differentiation)
- **E1.** Flutter `intl`/ARB scaffolding; extract strings from the highest-traffic parent/teacher screens first (login, home tiles, attendance, fees, notifications) — not a big-bang extraction.
- **E2.** `locale.language` config default per school + in-app override toggle on Profile.
- **E3.** Hindi translations for the extracted set (Hinglish-pragmatic where a pure-Hindi term would be unnatural — e.g. "Fees" stays "Fees").
- Scope honesty: V4 ships the parent/teacher core in Hindi; admin/analytics screens 🔒 follow post-V4.

### F — Reliability & release ops (my experience, ongoing)
- **F1. Sentry** (free tier): API (`@sentry/nestjs`) + Flutter (`sentry_flutter`), DSNs via env, off in local dev. Crashes become visible without reading Railway logs (G10). ⛔ needs a Sentry account.
- **F2. Uptime check** on `/api/v1/health` (UptimeRobot free). ⛔ needs an account; 5-minute setup, doc it in the plan's runbook section.
- **F3. Release script**: `scripts/release-apk.sh` — version bump, `flutter build apk --release` with prod API URL, `gh release create vX.Y.Z`, so every future mobile update is one command (you said you'll be updating many things later — this is that path).
- **F4. Runbook** — `OPERATIONS.md` **already exists** (written during handover: deploy/rollback, DB apply, demo reset, credential rotation, mobile release, troubleshooting, known gaps). V4's job is to *extend* it as new surfaces land: the demo-reset endpoint (A3), impersonation (C1), exports (C4), Sentry/uptime (F1–F2), and the release script (F3).

---

## 5. Phased execution (for the implementing agent)

Order chosen so the config system (highest leverage, most shared plumbing) lands first, and each phase is independently shippable + verifiable live.

| Phase | Delivers | Key verify gates (live, not just compiled) |
|---|---|---|
| **V4.0** | B1–B4: registry, `SchoolConfigService`, `/schools/config`, hardcoded-consumer migration, Flutter config provider | Change `timetable.periods_per_day` to 6 via console API → timetable editor shows 6 periods after app restart; defaulter threshold change alters report; RLS e2e green; `flutter analyze` 0 |
| **V4.1** | B5–B6 + C1–C3: typed console editor, mobile School Settings, impersonation, school detail page, user reset | Owner impersonates demo school → sees admin data; audit row written; non-superadmin cannot mint (403); reset a teacher's password → login with slip works; old modals removed (no dead paths) |
| **V4.2** | A1–A4: landing page, console moved to `/console`, one-tap demo login, demo auto-reset cron + button | Cold visitor flow: landing page renders (Vercel), QR/APK link works, demo buttons log in on emulator; cron visibly resets a mutation; reset endpoint 400s for a non-demo school code |
| **V4.3** | C4–C5 + D1–D5: exports, last-login, setup checklist, branding, empty states, deep links | Fresh school (created via console) shows checklist; steps tick as data is added; CSV export opens in Numbers/Sheets with correct rows; notification tap lands on the right screen |
| **V4.4** | E1–E3: i18n core in Hindi | Set demo school `locale.language=hi` → parent home renders Hindi on emulator; English default untouched; analyze 0 |
| **V4.5** | F1–F4: Sentry, uptime, release script, OPERATIONS.md | Forced test exception appears in Sentry (API + Flutter); `release-apk.sh` produces an installable release attached to a draft GH release |
| **V4.6** | Sweep: FEATURE_STATUS matrix refresh, CHANGELOG, README (landing URL, new screenshots), memory update, full-stack smoke test | Every V4 button reaches a real destination; cold-device end-to-end pass against prod |

---

## 6. Guardrails & context for the implementing agent (read first)

**Non-negotiable working rules (proven across V2–V3–deploy):**
1. Backend first, **verify live** with real HTTP calls against a running API before touching Flutter. Compilation is not verification.
2. `flutter analyze` = 0 errors/warnings; `next build` clean; RLS isolation e2e (`apps/api/test/rls-isolation.e2e-spec.ts`) green after any schema/policy change.
3. Zero dead buttons — a V4 screen either works or isn't reachable.
4. Update `FEATURE_STATUS.md` + `CHANGELOG.md` at each phase close; commit per phase with descriptive messages; push only after phase verify gates pass.
5. **Never** run the demo seed against prod outside the demo-school-scoped reset path. Never re-add Razorpay/any real gateway (no merchant account). Don't "upgrade" `DropdownButtonFormField.value` → `initialValue` (breaks programmatic reset — known trap).
6. New settings go through the registry — if you find yourself hardcoding a school-variable value, stop and add a registry entry instead.

**Environment facts:**
- Live API `https://api-production-28467.up.railway.app` (Railway project `vidyatrack`; API/PG/Redis; deploys on push to `main` via root-context `apps/api/Dockerfile`; `railway` CLI authed). Web on Vercel project `vidyatrack-web` (`vercel` CLI authed; `NEXT_PUBLIC_API_URL` env set). Repo `github.com/aimhackeritesh/vidyatrack` (`gh` authed).
- Local dev: `./start-api.sh` (API on :3000, entry `dist/src/main.js`), Docker PG/Redis via compose, seed = `npm run seed` (apps/api), Flutter SDK at `~/development/flutter`, emulator AVD `Pixel_9a` (tap coordinates must be scaled to 1080×2424).
- Demo credentials: school `VDTRK2627DEMO01`, `Demo@1234` — admin 9999900001, teacher 9999900002, parent 9999900003; super-admin `founder@vidyatrack.in`/`Demo@1234`.
- Key files: settings storage `school_settings` (schema.sql); current raw settings endpoints in `superadmin.{controller,service}.ts`; the one consumed setting in `fees.service.ts:getSetting`; console monolith `apps/web/src/app/page.tsx`; mobile constants `apps/mobile/lib/core/constants/app_constants.dart`; DB scripts `apps/api/scripts/{apply-db,bootstrap-prod}.js`.

---

## 7. Decisions needed before/while executing (⛔)

| # | Decision | Recommendation |
|---|---|---|
| 1 | Sentry account (free) for F1 | Yes — 10 min signup, transforms prod debuggability |
| 2 | UptimeRobot (free) for F2 | Yes — trivial |
| 3 | Play Store now? ($25 one-time + review + privacy policy page) | Not in V4 — landing page + QR + GitHub Release covers evaluation; revisit when a real school commits |
| 4 | Custom domain (~₹800/yr) for the landing page | Nice-to-have; landing ships on vercel.app first, domain can front it later without rework |
| 5 | Durable uploads (R2/S3) — still ephemeral | Stays 🔒 unless a real school onboards; driver seam is ready |
| 6 | Hindi translation review | Agent drafts; you (Hindi speaker) review the ARB file before V4.4 ships |

## 8. Definition of done (V4)
- A stranger with the landing-page link reaches a working, seeded app in under two minutes without typing credentials, on phone (APK) or web (console demo).
- Two schools with different settings (periods, fines, thresholds, branding, language) demonstrably get different app behavior from the same binaries — proven by configuring a second test school differently and screenshotting both.
- You can, from the console alone: create a school, impersonate its admin, fix its data, change any of its settings, reset any of its users' credentials, export its data, and see every one of those actions in the audit log.
- A new real school's admin can self-onboard via the checklist without instructions.
- Prod errors surface in Sentry; downtime alerts you; a mobile release is one script.
- All house verification gates green; docs + memory current.

## 9. Post-V4 backlog (explicitly deferred, in rough priority)
🔒 Per-period attendance mode (setting ships in V4, UI later) · real SMS OTP · real payment gateway · Play Store listing · durable uploads · report-card PDF templates per school · contact directory · FCM push (deep-link payloads already stored) · admin/analytics screens in Hindi · multi-child parent switcher · staging environment.
