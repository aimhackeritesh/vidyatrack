# VidyaTrack — Deployment Plan V1

> **Goal:** Get VidyaTrack live on the public internet — the NestJS API and Next.js super-admin console hosted and reachable over HTTPS, a production PostgreSQL + Redis behind them, and an Android APK that talks to the deployed API (sideload-distributed). This is a **first real deployment for demo/portfolio use**, not a Play-Store / paying-customers launch — those are called out separately as "later, not V1".
>
> **Method (carried from the build phases):** plan first, harden the code, provision infra, deploy, verify **live** at each step, document. Nothing is "done" until it's confirmed working against the deployed environment.

**Status legend:** ✅ done · 🟡 this deploy · 🔒 deferred (post-V1) · ⛔ blocker (must fix before deploy)

---

## 0. What "deployed V1" means (scope)

**In scope:**
- API live at `https://<api-domain>` over HTTPS, connected to managed Postgres + Redis.
- Web super-admin console live at `https://<web-domain>`, pointed at the deployed API.
- Production database with schema + RLS applied, and a **production-safe bootstrap** (one super-admin account — NOT the demo seed that wipes/creates 240 fake students).
- A release APK built against the **production API URL**, installable via a download link.
- Password-based login as the primary auth path (see §4 — OTP has no SMS provider).

**Explicitly NOT in scope for V1 (deferred):**
- 🔒 Play Store / App Store listing (needs a real signing key, $25 Google account, privacy policy, store assets).
- 🔒 Real SMS OTP (needs a paid MSG91/Twilio account).
- 🔒 Real payment gateway (Razorpay removed — no merchant account; mock flow stays).
- 🔒 Durable file storage on cloud object store (see §4 — decision).
- 🔒 Custom domains if we accept the platforms' default subdomains for V1.
- 🔒 Sentry / analytics / automated backups (nice-to-have, not blocking).

---

## 1. Current-state audit — what's ready vs. what breaks a deploy

Grounded in the actual code, not assumptions.

### ✅ Already deploy-friendly
- API reads `PORT`, `DATABASE_URL`, `DATABASE_ADMIN_URL`, `REDIS_URL`, `JWT_*`, `CORS_ORIGIN` from env — no hardcoded hosts in app code.
- API binds `0.0.0.0` implicitly via Nest's `listen(port)`.
- CORS is already env-driven: `origin: process.env.CORS_ORIGIN || '*'` — just needs the env set in prod.
- Web console reads `NEXT_PUBLIC_API_URL` at build time — clean for Vercel.
- Mobile reads `API_URL` via `--dart-define` (compile-time) — clean, just needs the prod URL baked in at build.
- Multi-tenancy/RLS is env-agnostic; `schema.sql` + `rls-setup.sql` are idempotent and re-runnable against any Postgres.
- `.env.example` exists and is committed (no secrets in git).
- CI already lints/builds/tests all three apps on push.

### ⛔ Blockers — must fix before deploy (code hardening, Phase D0)

| # | Issue | Why it breaks | Fix |
|---|---|---|---|
| B1 | **API Dockerfile `CMD ["node", "dist/main"]`** | The real entry is `dist/src/main.js` (Nest compiles `src/` into `dist/src/`). Container starts, immediately crashes "cannot find module". | Change CMD to `dist/src/main.js`. |
| B2 | **API Dockerfile `npm ci` with no lockfile** | Build context is `apps/api/`, which has **no `package-lock.json`** (workspaces hoist it to repo root). `npm ci` hard-fails without a lockfile. | Rework the API build to install from the workspace root, or generate a standalone lockfile for `apps/api`. (Root-context Dockerfile is cleaner.) |
| B3 | **Web Dockerfile expects `.next/standalone` + `server.js`** | There is **no `next.config.js`**, so Next never emits standalone output → those paths don't exist → container build/run fails. | Add `next.config.js` with `output: 'standalone'`. (Or skip Docker for web entirely and deploy on Vercel, which needs neither — see §3.) |
| B4 | **DB init only runs on a fresh Docker volume** | `schema.sql`/`rls-setup.sql` are mounted into `docker-entrypoint-initdb.d`, which only executes on first boot of an empty Postgres volume. **Managed Postgres never runs them.** | Add an explicit, idempotent "apply schema + RLS" deploy step/script run once against the managed DB. |
| B5 | **The `vidyatrack_app` DB role must exist on the target DB** | RLS is only enforced because the app connects as a non-superuser role created by `rls-setup.sql`. If it's missing, the app can't connect at all. | Ensure `rls-setup.sql` runs on the prod DB (part of B4). **Pick a Postgres host that allows `CREATE ROLE`** (see §3 — this rules out some serverless PG). |
| B6 | **No production bootstrap; `seed.ts` is demo-only** | `npm run seed` **wipes** and inserts 240 fake students + demo school. Running it in prod = garbage data. Not running anything = no super-admin, no way to create the first school. | Add a `bootstrap:prod` script that creates **only** the founder super-admin (idempotent, no demo data). |

### 🟡 Should fix for a real (even demo) deploy

| # | Issue | Fix |
|---|---|---|
| S1 | **CORS defaults to `*`** | Set `CORS_ORIGIN=https://<web-domain>` in prod API env. |
| S2 | **No `/health` endpoint** | Most PaaS want a health check for zero-downtime deploys. Add a tiny `GET /api/v1/health` (returns 200 + DB ping). Fallback: point health checks at `/api/docs`. |
| S3 | **Swagger open at `/api/docs` in prod** | Gate `SwaggerModule.setup` behind `NODE_ENV !== 'production'` (or leave it — low risk for a portfolio demo, but flag it). |
| S4 | **File uploads go to local disk** (`useStaticAssets(cwd/uploads)`) | On a container platform the disk is **ephemeral** — uploaded study material/syllabus files vanish on redeploy and don't work across >1 instance. Decision in §4. |
| S5 | **Mobile APK is debug-signed + points at LAN IP** | Rebuild release APK with `--dart-define=API_URL=https://<api-domain>/api/v1`. Debug signing is fine for sideload; a real upload key is a Play-Store concern (deferred). |
| S6 | **Secrets are dev values** | Generate fresh strong `JWT_SECRET` / `JWT_REFRESH_SECRET` (≥32 chars) for prod; never reuse the committed dev ones. |

---

## 2. Target architecture (V1)

```
                     ┌────────────────────────┐
   Android APK  ───► │  API (NestJS)          │ ◄─── Web console (Next.js)
   (sideloaded,      │  HTTPS, container host │      (Vercel, HTTPS)
    baked prod URL)  └───────┬───────┬────────┘
                             │       │
                   ┌─────────▼──┐  ┌─▼──────────┐
                   │ PostgreSQL │  │  Redis     │
                   │ 16 + RLS   │  │ (OTP/BullMQ│
                   │ (managed)  │  │  /sessions)│
                   └────────────┘  └────────────┘
```

Two DB roles on the same Postgres instance (unchanged from local):
- `DATABASE_ADMIN_URL` → the provider's superuser/owner role — used **once** to apply schema + RLS + bootstrap, and by any future migrations.
- `DATABASE_URL` → `vidyatrack_app` (NOSUPERUSER/NOBYPASSRLS) — the **runtime** connection, so RLS is actually enforced.

---

## 3. Hosting stack — recommendation + rationale

**Recommended: Railway (Postgres + Redis + API) + Vercel (web) + sideloaded APK.**

| Piece | Recommended | Why / rationale | Alternatives |
|---|---|---|---|
| Postgres | **Railway Postgres** | Gives a **full superuser**, so `CREATE ROLE vidyatrack_app` + `ALTER DEFAULT PRIVILEGES` from `rls-setup.sql` just work. Serverless PG (Supabase/Neon) restrict roles and layer their own — the RLS two-role design fights their conventions. Same platform as the API = one private network, no egress fees. | Render PG, Fly PG, self-managed |
| Redis | **Railway Redis** | Same platform/network as API; trivial to attach. Needed for OTP store + BullMQ. | Upstash (serverless, generous free tier) |
| API | **Railway service** (Docker) | Deploys the fixed API Dockerfile straight from GitHub; private networking to PG/Redis; env-var UI; auto TLS on a `*.up.railway.app` domain. | Render, Fly.io |
| Web | **Vercel** | Next.js's native host — **no Dockerfile needed** (sidesteps B3 entirely), instant deploys from GitHub, free hobby tier, auto HTTPS. | Railway (needs B3 fix), Netlify |
| APK | **Sideload** (host the file / GitHub Release) | Already proven this session. No store account, no review. | Play Store (deferred) |
| File storage | **Decision — see §4** | Local disk is ephemeral on Railway. | Cloudflare R2, AWS S3 |

**Cost:** Vercel hobby = free. Railway = usage-based, ~$5/mo Hobby covers PG + Redis + one small API service for a low-traffic demo. Total ≈ **$5/mo**.

> This is a recommendation, not locked. Swappable — the code hardening in Phase D0 is host-agnostic, so we can change hosts without redoing D0.

---

## 4. Decisions — CONFIRMED (2026-07-18)

1. ✅ **Hosting stack** → **Railway** (Postgres + Redis + API) + **Vercel** (web console) + sideloaded APK.
2. ✅ **Login strategy for V1** → **Password login only.** School code + phone/login-ID + password is the path; the OTP button will be de-emphasized/hidden in the deployed mobile build so users don't hit a dead SMS flow. Real SMS OTP is deferred.
3. ✅ **File storage** → **Ephemeral** (local disk) for V1. Uploads work for the demo, lost on redeploy; documented. R2/S3 is a clean post-V1 follow-up via the existing `StorageService` seam.
4. ✅ **Domains** → platform subdomains (`*.up.railway.app`, `*.vercel.app`) for V1. Custom domain can front them later without an app rebuild.

---

## 5. Phased execution plan

Each phase verified live before the next.

### Phase D0 — Code hardening ✅ COMPLETE (2026-07-18, verified in real containers)
Fixed every ⛔ blocker and the 🟡 items. All in-repo, no cloud account needed.

- [x] **D0.1** ✅ API Dockerfile: `CMD node apps/api/dist/src/main.js` (B1), root build context using the workspace lockfile (B2), non-root `node` user, `.dockerignore` added (keeps the 2.5GB mobile build out of context).
- [x] **D0.2** ✅ `apps/web/next.config.js` with `output: 'standalone'` + `outputFileTracingRoot` (B3); web Dockerfile reworked to root context.
- [x] **D0.3** ✅ `GET /api/v1/health` → `{status:'ok', db:'up'}` after a `SELECT 1` (public, no auth). **Verified 200 in-container.**
- [x] **D0.4** ✅ Swagger gated behind `NODE_ENV !== 'production'`. **Verified /api/docs → 404 in a prod container.**
- [x] **D0.5** ✅ `npm run db:apply` (`scripts/apply-db.js`, plain node + pg, SSL-aware) applies schema.sql + rls-setup.sql idempotently (B4/B5). **Verified idempotent re-run against local DB.**
- [x] **D0.6** ✅ `npm run bootstrap:prod` (`scripts/bootstrap-prod.js`) upserts ONLY the founder super-admin from env, refuses weak/missing password (B6). **Verified: creates/resets, super-admin login 201, refuses empty password.**
- [x] **D0.7** ✅ `apps/api/.env.production.example` documents every prod var; `CORS_ORIGIN` wired through docker-compose + main.ts. Fixed the `start` npm script (was pointing at the wrong entry too).
- [x] **D0.8** ✅ Built **both** images from the repo root; ran the API image in production mode against Postgres/Redis → health 200, super-admin + parent login work, Swagger off, non-root. Ran the web image → serves the console (200) with the baked API URL. RLS isolation e2e still 5/5.
- **Result:** the fixed Dockerfiles are proven in real containers before any cloud spend. Ready for D1.

### Phase D1 — Provision infra (needs your Railway account)
- [ ] **D1.1** Create Railway project; add Postgres + Redis plugins.
- [ ] **D1.2** Apply `schema.sql` + `rls-setup.sql` to the Railway Postgres via `DATABASE_ADMIN_URL` (D0.5 script). Confirm the `vidyatrack_app` role exists and RLS policies are present.
- [ ] **D1.3** Run `bootstrap:prod` to create the founder super-admin.
- **Verify:** connect as `vidyatrack_app` and confirm a no-context query returns 0 rows (RLS deny-by-default holds on prod).

### Phase D2 — Deploy API (Railway)
- [ ] **D2.1** Add the API service from the GitHub repo (Docker build), set all prod env vars (both DB URLs, Redis URL, fresh JWT secrets, `CORS_ORIGIN`, `NODE_ENV=production`, `APP_URL`).
- [ ] **D2.2** Deploy; watch logs for clean boot.
- **Verify:** `curl https://<api>/api/v1/health` → 200; super-admin login via API returns a token; RLS still enforced (a tenant token can't see another school).

### Phase D3 — Deploy web console (Vercel)
- [ ] **D3.1** Import the repo into Vercel, root = `apps/web`, set `NEXT_PUBLIC_API_URL=https://<api>/api/v1`.
- [ ] **D3.2** Deploy; then set the API's `CORS_ORIGIN` to the Vercel URL and redeploy the API.
- **Verify:** open the Vercel URL, log in as super-admin, load Analytics/Schools/Broadcast/Audit against the live API — end-to-end in the browser.

### Phase D4 — Build & distribute the Android app
- [ ] **D4.1** Rebuild release APK: `flutter build apk --release --dart-define=API_URL=https://<api>/api/v1`.
- [ ] **D4.2** Host it (GitHub Release on the repo is cleanest for a resume link) and produce a download link.
- **Verify:** install on the Pixel 9a emulator (and/or a real phone), confirm it logs in and loads data **against the deployed API**, not localhost.

### Phase D5 — Hardening & verification pass
- [ ] **D5.1** Security sanity: CORS locked to web origin, Swagger off in prod, no dev secrets in use, `.env` not in git.
- [ ] **D5.2** Smoke test the critical flows on prod: super-admin creates a school → principal logs in (forced password change) → sees only their school (RLS) → sets fee structure → generates invoices → parent sees dues → mock "Pay Now" → receipt.
- [ ] **D5.3** Update `README.md` with live URLs + a "Live Demo" section (super-admin creds are safe to show for a demo school; note it's a demo).
- [ ] **D5.4** Update `CHANGELOG.md` + project memory with the deploy.
- **Verify:** the whole thing works from a cold browser/phone with no local services running.

---

## 6. Requirements checklist (what you need to provide / have)

**Accounts:**
- [ ] Railway account (GitHub sign-in; Hobby plan ~$5/mo for PG+Redis+API).
- [ ] Vercel account (free hobby; GitHub sign-in).
- [ ] GitHub — ✅ already set up (`aimhackeritesh/vidyatrack`), repo is public, `gh` authed.

**Tooling on this Mac:**
- [ ] Railway CLI (`brew install railway`) — optional but makes DB-apply/env scripting easier. Can also do everything in the Railway web UI.
- [ ] `psql` client to apply schema to the remote DB (or run the apply script through the Railway CLI / a one-off container).
- [ ] Docker — ✅ present. Flutter — ✅ present. Node/npm — ✅ present.

**Decisions (from §4):**
- [ ] Confirm hosting stack.
- [ ] OTP strategy (recommend: password-login only for V1).
- [ ] File storage (recommend: ephemeral for V1).
- [ ] Domains (recommend: platform subdomains for V1).

**Secrets to generate (not commit):**
- [ ] `JWT_SECRET`, `JWT_REFRESH_SECRET` (fresh, ≥32 chars).
- [ ] Founder super-admin email + strong password for `bootstrap:prod`.

---

## 7. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Managed Postgres won't allow `CREATE ROLE` → RLS design breaks | Chose Railway specifically because it gives superuser. Verified in D1.2 before deploying the API. |
| Ephemeral disk loses uploaded files | Accepted for V1 demo (§4); documented; R2/S3 is a clean follow-up via the existing driver seam. |
| Monorepo Docker build complexity (B2) | Fixed in D0.1 with a root-context build; verified locally in D0.8 before any cloud spend. |
| Redis cold start / connection limits on hobby tier | Low traffic demo; BullMQ + OTP are lightweight. Upstash is a drop-in fallback. |
| Baked API URL in APK means re-build on API domain change | Use a stable domain from the start (Railway subdomain is stable); custom domain can front it later without a rebuild if we point it early. |
| Someone finds the public demo super-admin creds | It's a demo school; no real data; note it in README. Rotate if abused. |

## 8. Definition of done (V1)
- `https://<api>/api/v1/health` returns 200 from anywhere.
- Web console loads and logs in against the live API over HTTPS.
- APK installs and works against the live API (no localhost).
- Prod DB has schema + RLS + exactly one super-admin, no demo garbage.
- CORS locked, Swagger off in prod, fresh secrets, RLS re-verified on prod.
- README shows the live URLs and how to try it.

---

## 9. Immediate next step
Start **Phase D0** (code hardening) now — it's fully in-repo, needs no accounts, and unblocks everything. In parallel, you decide §4 (hosting confirm + the three toggles) so D1 can start the moment D0 is verified.
