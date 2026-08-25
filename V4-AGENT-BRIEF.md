# V4 Implementation Agent — Brief

> **Purpose:** everything an implementing agent needs to execute [V4-PLAN.md](V4-PLAN.md) starting cold, with no access to the conversations that produced it. Written for a capable coding agent (Opus-class) working in this repo.

---

## Mission

Implement V4 of VidyaTrack: **make the product differentiated, easy to try, and configurable per school**, per the spec in [V4-PLAN.md](V4-PLAN.md).

The single highest-leverage piece is the **School Configuration System** (V4-PLAN §3): a typed settings registry that turns per-school variability (periods per day, fee fines, attendance thresholds, grading display, branding, language, feature flags) into **data instead of code**. Everything else in V4 either consumes it or clears a path to users.

**Do not** re-plan. The plan is agreed. Execute it, flag genuine problems you find, and ask when a decision is actually the owner's.

---

## Read first, in this order

1. **[CLAUDE.md](CLAUDE.md)** — house rules, environment facts, traps. Non-negotiable.
2. **[HANDOVER.md](HANDOVER.md)** — project orientation, what's shipped vs deferred, known traps in detail.
3. **[V4-PLAN.md](V4-PLAN.md)** — the spec you're implementing. §2 is a verified gap audit; §3 is the config system; §4 the workstreams; §5 the phases; §6 guardrails; §7 open decisions.
4. **[OPERATIONS.md](OPERATIONS.md)** — runbook, if you need to touch prod, the DB, or a release.
5. **[FEATURE_STATUS.md](FEATURE_STATUS.md)** — current per-screen/button state, so you know what already exists before building anything.

Skim, don't memorize: `CHANGELOG.md` (history + past bugs — genuinely useful), `DEPLOYMENT-PLAN-V1.md` (how prod was built). Ignore `PROJECT-STATUS-REPORT.md` — it's stale and self-describes as authoritative; it isn't.

---

## Working agreement

**The loop that has worked for every prior version of this project — keep it:**

```
plan the phase → build backend → VERIFY LIVE with real HTTP calls
  → build UI → analyze/build clean → update docs → commit → next phase
```

**Hard gates before any phase is "done":**
- Real HTTP verification against a running API (curl or equivalent) — **compiling is not verifying**. Most historical bugs in this codebase compiled cleanly and passed local tests.
- `cd apps/mobile && flutter analyze` → **0 errors, 0 warnings** (~11 pre-existing infos are expected; see traps).
- `cd apps/mobile && flutter test` → passing.
- `cd apps/api && npm run build` → clean.
- `cd apps/web && npm run build` (or `npm run web:build`) → clean.
- **After any schema or RLS-policy change:** `cd apps/api && npm run test:e2e -- rls-isolation` → **5/5**.
- Zero dead buttons: every new screen/button reaches a real destination.

**Per-phase close:** update `CHANGELOG.md` and `FEATURE_STATUS.md`, then commit with a descriptive message. **Ask the owner before pushing** unless they've said to push freely.

---

## Phase order and per-phase acceptance

Follow V4-PLAN §5. Condensed, with the acceptance test that matters most for each:

| Phase | Build | Prove it by |
|---|---|---|
| **V4.0** | Settings registry, `SchoolConfigService`, `GET /schools/config`, migrate hardcoded consumers, Flutter config provider | Set `timetable.periods_per_day` to 6 for the demo school → the timetable editor renders 6 periods (not 8) after app restart. Change `attendance.defaulter_threshold` → defaulters report changes. |
| **V4.1** | Typed console settings editor, mobile School Settings screen, **impersonation**, school detail page, reset-any-user | Owner impersonates the demo school → sees that school's admin data; an audit row is written; a non-superadmin calling the mint endpoint gets 403; reset a teacher's password → they can log in with the new slip. |
| **V4.2** | Public landing page, console moved to `/console`, one-tap demo login, demo auto-reset (cron + button) | Cold-visitor path works end to end: landing page → APK link → install → tap "Explore as Parent" → dashboard, no typing. Reset endpoint 400s for any school code that isn't the demo's. |
| **V4.3** | CSV exports, last-login tracking, setup checklist, branding, empty-state sweep, notification deep links | Create a fresh school via the console → its admin home shows the checklist → steps tick as data is added. Export opens in a spreadsheet with correct rows. Tapping a notification lands on the right screen. |
| **V4.4** | i18n scaffolding + Hindi for the parent/teacher core | Set demo school `locale.language=hi` → parent home renders Hindi on the emulator; English default unaffected. **Have the owner review the Hindi ARB file before shipping** — they're the native speaker. |
| **V4.5** | Sentry, uptime check, release script, extend OPERATIONS.md | A deliberately-thrown test exception appears in Sentry from both API and Flutter; `release-apk.sh` produces an installable APK attached to a release. Needs owner accounts (V4-PLAN §7). |
| **V4.6** | Sweep: FEATURE_STATUS matrix, CHANGELOG, README, full-stack smoke test | Cold-device end-to-end pass against prod; every V4 button reaches a real destination. |

Each phase is independently shippable. Don't start the next until the current one's gates are green.

---

## Guardrails — the ways this can go wrong

**Product/scope:**
- **Don't re-add Razorpay or any real payment gateway.** There's no merchant account. `MockGateway` is a deliberate decision, and the `PaymentGateway` interface is the seam for later.
- **Don't build the deferred list** (V4-PLAN §9): live classes, transport/hostel/library/payroll, per-period attendance UI, Play Store work. Scope discipline is part of the plan.
- **If you find yourself hardcoding something that varies by school — stop and add a registry entry instead.** That's the whole point of V4.

**Data/safety:**
- **Never run `npm run seed` against production** except through the demo-scoped reset path you build in V4.2 (with its guardrail refusing non-demo school codes). The seed **wipes** tenant data and resets the super-admin password.
- **Any new tenant table needs an RLS policy** with the superadmin bypass, and the isolation e2e must stay green. RLS is the tenancy boundary — not application code.
- **Ownership checks are server-side.** Parent/student endpoints must resolve the caller's own entity (`assertStudentAccess` pattern); never trust a client-supplied `studentId`. A real cross-child data leak was fixed this way in V3 — don't reintroduce it.
- **Impersonation (V4.1) is security-sensitive.** Short-lived token, `impersonated_by` in the claims, every mint and use audit-logged, superadmin-only, and it must still go through normal RLS — no bypass shortcuts.

**Technical traps** (full list in CLAUDE.md — these bite hardest):
- Docker builds use the **repo root** as context; `npm ci` inside `apps/api`/`apps/web` fails (no lockfile there).
- Postgres won't infer enum casts in a `CASE` → `(CASE … END)::invoice_status_enum`; same for `role::text = ANY($1::text[])`.
- `audit_logs.entity_id` is a UUID — a non-UUID string 500s and rolls back the entire request transaction.
- **Do not** migrate `DropdownButtonFormField.value` → `initialValue`; it breaks programmatic reset.
- `NEXT_PUBLIC_*` is inlined at build time — changing it needs a rebuild.
- Nest entry is `dist/src/main.js`, not `dist/main`.

---

## Decisions that belong to the owner, not you

Ask; don't assume:
1. Anything requiring a **new paid or personal account** (Sentry, UptimeRobot, domain, Play Store, SMS provider, payment merchant). V4-PLAN §7 has the pending four — **V4.0–V4.3 need none of them**, so start there and ask in parallel.
2. **Hindi translation wording** — draft it, but the owner reviews before it ships.
3. **Pushing to `main`** and cutting releases (the repo is public and used as a portfolio piece — README/CHANGELOG accuracy matters).
4. Any deviation from V4-PLAN's scope, or anything that would change the public demo's credentials or reset behavior.

---

## How to report progress

- **Say what you verified, not just what you wrote.** "Set periods to 6, restarted the app, editor shows 6" beats "implemented config system."
- **Surface bugs you find in existing code** rather than silently patching around them — that's how the enum-cast, role-ordering, and ownership-leak bugs got properly fixed in earlier versions. Note them in CHANGELOG under the phase that found them.
- **If a gate fails, stop and fix it.** Don't proceed with a red `flutter analyze` or a failing RLS test.
- **If the plan turns out wrong** about the codebase (V4-PLAN §2's audit was verified at planning time, but code moves), say so explicitly and propose the correction before implementing something different.

---

## Definition of done (V4)

From V4-PLAN §8 — all of these, demonstrably:

- A stranger with the landing-page link reaches a working, seeded app in **under two minutes without typing credentials** (phone via APK, or web console demo).
- **Two schools configured differently** (periods, fines, thresholds, branding, language) produce **different behavior from the same binaries** — prove it with side-by-side screenshots.
- From the console alone the owner can: create a school → impersonate its admin → fix its data → change any setting → reset any user's credentials → export its data → and see **every one of those actions in the audit log**.
- A new real school's admin can self-onboard via the setup checklist with no instructions.
- Prod errors surface in Sentry; downtime alerts the owner; a mobile release is one script.
- All house gates green; `CHANGELOG.md`, `FEATURE_STATUS.md`, `README.md`, and `OPERATIONS.md` current.

---

## Kickoff prompt (paste this to start)

```
Implement V4 of VidyaTrack.

Read, in order: CLAUDE.md, HANDOVER.md, V4-PLAN.md, V4-AGENT-BRIEF.md, FEATURE_STATUS.md.
Then execute V4-PLAN.md phase by phase starting with V4.0 (the School Configuration
System), following the working agreement and gates in V4-AGENT-BRIEF.md.

Verify every backend change live with real HTTP calls before touching UI. Keep
`flutter analyze` at 0 errors/warnings and the RLS isolation e2e at 5/5. Update
CHANGELOG.md and FEATURE_STATUS.md at each phase close, and ask me before pushing.

Start by confirming the V4-PLAN §2 gap audit still matches the code, then report your
plan for V4.0 before writing it.
```
