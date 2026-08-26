# Meshcast Clone — Feature Analysis & Build Plan

**Status:** analysis + plan only. No implementation started.
**Target being analysed:** `meshcast.app`
**Date:** 2026-08-26

---

## 0. Read this first — three corrections to the brief

**0.1 The video shows one tool out of ~20.** The transcript ("prints a thin shell that
wraps tight around your model, so you use way less silicone") describes exactly one
generator: the **Adaptive Silicone Mold Maker** (`/adaptive-silicone`). Meshcast is not a
one-tool site. It is a *suite* of parametric 3D generators (molds, cutters, lithophanes,
nameplates, keychains, planters, trays, compression dies, mesh repair) wrapped in a
freemium download-quota business. If we build only the shell tool we have ~5% of the
product. This plan covers the whole thing but sequences the shell tool first, because it is
the hook.

**0.2 "Free" is the funnel, not the model.** The tool is free to *use*; the **download** is
metered. Free account = a small weekly STL allowance (their published figure has moved
between "3 per week" and "5 per day" — they tune it). Pro = **$20/month**, unlimited
downloads, no watermark, commercial rights *while subscribed*. Founder = **$349 lifetime**.
Any clone that does not gate downloads has copied the product and not the business.

**0.3 Scope of what we can legally copy.** Mold-generation geometry is standard
computational-geometry work — offset surfaces, CSG, draft analysis — and is fair to
reimplement. What is **not** ours to take: the Meshcast name and brand, their page copy and
marketing text, their screenshots and renders, their curated design library, and their
guide articles. We reimplement the *mechanism* and write our own copy. I have written this
plan on that basis; flagging it once and moving on.

**0.4 A research limitation, stated plainly.** `meshcast.app` is blocked by this
environment's network egress proxy, so I could not load the pages or inspect their
JavaScript bundle directly. Everything below is reconstructed from indexed page content
(titles, descriptions, guide text) plus the video transcript. It is accurate on *what the
features are and what the parameters are called*. It is my engineering inference on *how
they are implemented* — I could not read their WASM module. If you unblock the domain (or
paste the page HTML / a HAR file), I can tighten Section 3 from "how I would build it" to
"how they built it" in about an hour.

---

## 1. Complete feature inventory

### 1.1 Mold generators (the core product)

| Tool | Route | What it produces |
|---|---|---|
| **Adaptive Silicone Mold Maker** | `/adaptive-silicone` | Offset shell that follows the model's true silhouette at a fixed gap, split into **2, 3 or 4 wedges** that clamp together, plus a shrink-compensated **master positive**. Pour silicone into the gap, peel the shell, keep the flexible one-piece mold. **This is the video.** |
| **Silicone Mold Maker** | `/silicone-mold` | The classic rectangular **formwork box** version — printed housing walls + master positive. Cheaper compute, wastes more silicone. |
| **Mold Generator** | `/mold` | Direct **two-part rigid mold** from any STL: parting line, alignment keys, pour hole. Cast wax/soap/resin/plaster/concrete straight into the print. |
| **Candle Mold Maker** | `/candle-mold` | Two-part mold tuned for wax (wick channel, seam seal). |
| **Vase Mold Generator** | `/vase-mold` | Silicone mold for hollow planters/pots — needs an inner core as well as an outer shell. |
| **Multi-Cavity Tray Mold** | `/ice-cube-tray-mold` | N×M cavity array for ice, chocolate, gummies, wax melts. |
| **Compression Mold** | (newer) | Die + piston, deep charge chamber sized for **melted print waste**, with a calculator that says whether your shred fits in one press or needs a top-up round. |
| **Packaging / press molds** | — | Mentioned in their tool list; same pipeline, different presets. |

### 1.2 Shape designers (feed the mold generators)

Nine parametric templates, each shaped from a handful of sliders and sent **into the
matching mold generator with one click**: candle, vase, bowl, cup, bottle, soap bar,
pendant, wall panel, wave-art panel. Plus a **Tray Designer** (round / oval / rectangular /
pill, with a real recess) and a **Photo Candle Designer** (photo → relief on a candle body,
previewed with blended relief + backlit shading).

This "designer → generator handoff" matters: it means a user with **no 3D model at all**
can still reach a download. It roughly doubles the addressable audience.

### 1.3 Non-mold generators (SEO and top-of-funnel)

- **Cookie / Clay Cutter** (`/cutter`) — upload PNG, JPG or SVG silhouette → print-ready cutter STL.
- **Lithophane** (`/lithophane`) — photo → backlit relief print.
- **Keychain** (`/keychain`) — type text, pick shape + font → STL or 3MF.
- **Nameplate / Name Sign** (`/nameplate`) — bold initial + flowing script name, desk plate.
- **Planter** (`/planter`) — any STL → auto-orient, hollow, drill planting hole + drainage.
- **Embosser, texture roller, golf-ball stencil, SVG→STL** — small tools, cheap to build, each its own search landing page.
- **STL Repair / AI Mesh Fixer** (`/optimize`) — diagnoses non-manifold edges, holes, degenerate faces, flipped normals, duplicate vertices; auto-repairs. Positioned explicitly at people bringing meshes out of AI 3D generators.

### 1.4 Cross-cutting product features

- **Upload formats:** STL, OBJ, 3MF. **Export:** watertight STL or 3MF, slicer-ready.
- **Runs client-side.** "Most generators run entirely in your browser through WebAssembly, so your file never leaves your device." This is both a performance choice and a privacy sales pitch.
- **Parametric by construction.** "You set real millimetre values and the geometry is computed the same way every time, watertight by construction." No mesh-hacking, no repair-after-the-fact.
- **Rejection + self-serve repair.** Models get rejected (not watertight, couldn't process, repair budget exceeded, too large, too small, empty half) and the rejection dialog offers **"Fix it for me"**, which rebuilds the model as a clean solid *and generates in the same click*.
- **Pre-print validation:** air-trap detection and cast-release checks — "spot if a pocket will trap air or if a wedge cannot release in the direction it is being pulled, **before you print rather than after**."
- **Designs library** (Pro) — curated ready-to-print designs, each printability-checked, with commercial license.
- **Community gallery** (`/community`) — real prints from users; entry via tagging their handles on Instagram/TikTok.
- **Guides** (`/guides`) — a large SEO content farm: "moldboxer alternative", "free mold making software", "STL to mold", "silicone ice cubes", "plaster cracking", "why was my model rejected". Every guide funnels into a tool.
- **Changelog** (`/changelog`) — every user-visible change, shipped publicly. Cheap trust signal.
- **Localization** — tier cards, plan comparison table and FAQ translate per visitor language **without changing the page URL** (so: cookie/header-driven locale, not path-based i18n).
- **Referral tracking** — `?ref=` params in creator links, heavy Instagram/TikTok distribution.

### 1.5 Monetization

| Tier | Price | Grants |
|---|---|---|
| Anonymous | free | Generate and preview. Download blocked. |
| Free account | free | Small recurring STL allowance across all tools + one-time signup bonus. Watermarked. |
| **Pro** | **$20/mo** | Unlimited downloads, unlimited generations, every tool, no watermark, commercial rights while subscribed. |
| **Founder** | **$349 once** | Lifetime, commercial rights, every future tool, no subscription. |

---

## 2. System architecture

```
┌──────────────────────── BROWSER ────────────────────────┐
│  Next.js (App Router, TS, Tailwind)                     │
│  ┌─────────────┐  ┌──────────────────────────────────┐  │
│  │ Param panel │  │ three.js / react-three-fiber      │  │
│  │ (mm values) │◄─┤ viewer: model, shell, seam gizmo, │  │
│  └──────┬──────┘  │ draft heatmap, section cut        │  │
│         │         └──────────────────────────────────┘  │
│         ▼                                                │
│  ┌──────────────── Web Worker ────────────────────────┐ │
│  │  GEOMETRY KERNEL (WASM, Rust or C++)               │ │
│  │  ingest → validate → repair → SDF → offset →       │ │
│  │  marching cubes → CSG (manifold-3d) → split →      │ │
│  │  checks → STL/3MF encode                           │ │
│  └────────────────────────────────────────────────────┘ │
└───────────────┬──────────────────────────┬───────────────┘
                │ params + result hash     │ (large meshes only)
                ▼                          ▼
┌──────────── API (NestJS + Postgres + Redis) ─────────────┐
│ auth · entitlements · download-token issue & quota debit │
│ Stripe webhooks · designs library · community · CMS/i18n │
│ BullMQ queue → server-side geometry workers (same WASM)  │
└──────────────────────────────────────────────────────────┘
                                           ▼
                            S3 / R2: uploads, results, gallery
```

**Why hybrid and not pure client-side:** their privacy claim ("your file never leaves your
device") is real and worth matching, but a 40 MB scanned mesh at 512³ SDF resolution will
kill a mid-range phone. Run client-side by default; fall back to a queued server worker
running the *same* WASM binary when the mesh exceeds a complexity budget or the device
reports low memory. One kernel, two hosts — never two implementations.

---

## 3. The geometry, in detail

This is the part that is actually hard. Everything else in this plan is standard SaaS work.

### 3.1 Ingest and validation

1. **Parse** — STL (binary + ASCII), OBJ, 3MF (zip + XML, with transform matrices applied).
2. **Weld** — spatial-hash merge of vertices within epsilon; drop degenerate triangles (zero area, repeated indices).
3. **Diagnose** — per-edge face count (manifold ⇔ every edge has exactly 2), boundary-loop extraction, consistent-orientation check via BFS with flip propagation, signed-volume sign test, connected-component count, self-intersection test, bbox sanity (too small / too large).
4. **Report** — map each defect to their user-facing error strings: *not watertight, couldn't process this model, repair budget, too large, too small, empty half*. "Empty half" is specific: it means the chosen parting plane produced a half with no cavity, i.e. a bad seam, not a bad mesh.
5. **"Fix it for me"** — the escape hatch, and the single highest-leverage UX feature on the site. Do **not** try to repair topologically. Instead: compute a **generalized winding number** field (Jacobson et al.) over a narrow-band voxel grid, threshold at 0.5, and re-extract with marching cubes / surface nets. That converts *any* garbage soup — flipped normals, holes, self-intersections, loose shells — into a guaranteed watertight solid in one step. Accept the small loss of sharp features; the user gets a print instead of an error.

### 3.2 Adaptive silicone shell — the hero algorithm

Given master mesh `M`, silicone gap `g` (default ~8–12 mm), shell wall `t` (~2.5 mm),
wedge count `N` ∈ {2,3,4}:

1. **Shrink compensation.** Scale `M` by `1/(1−s)` where `s` is the shrink of the *final cast material* (silicone shrink + resin shrink stack). Expose as a material dropdown with a mm readout, not a raw percentage.
2. **Voxelize** `M` into a narrow-band grid, longest axis ~256–384 cells (adaptive: keep total band voxels under a fixed budget).
3. **Signed distance field.** Exact distance in the narrow band via triangle-to-point queries in a BVH; propagate outward with fast sweeping / EDT. Sign from the winding number so it survives imperfect input.
4. **Two isosurfaces.** Extract `S_in = iso(d = g)` and `S_out = iso(d = g + t)` with surface nets (smoother than plain marching cubes, fewer triangles).
5. **Shell solid** `= S_out − S_in` (CSG difference). *This is the whole trick from the video* — because both surfaces are offsets of the model's own SDF, the shell hugs the silhouette instead of boxing it.
6. **Silicone volume readout.** Count voxels where `0 < d < g`, times voxel volume → ml, → grams at silicone density, → **cost**, and show it **beside the equivalent bounding-box mold volume**. Their entire pitch is "way less silicone"; the savings number must be on screen, live, as the user drags the gap slider. Build this in Phase 1, not later.
7. **Base.** Cut flat at the master's foot plane; add a base plate with either a **pin + socket** (master prints separately, press-fits onto a peg) or **merge to base** (master fused on, no pin, no gap). Both modes are named in their UI.
8. **Base rib auto-open.** If the master's maximum radius *above* the foot exceeds its radius *at* the foot, the base ring must split sideways too — otherwise the walls cannot lift off. Detect by comparing radial silhouette profiles; when triggered, split the base rib and warn that the bottom seal is now looser (their locked-settings mode keeps the tighter seal instead).
9. **Wedge split.** Cut the shell with `N` half-space planes through the vertical axis. Do **not** use naive 360/N azimuths — search azimuth offset (e.g. 64 candidate rotations) minimising total undercut area across all wedges, so seams land on the silhouette's widest points.
10. **Cast-release check.** For each wedge with outward pull direction `d`, test every inner-surface triangle: `dot(n, d) ≥ sin(draft_min)`. Violations = the wedge is locked. Surface as a red heatmap on the offending faces plus a concrete suggestion ("4 wedges instead of 3", "rotate seams 22°").
11. **Air-trap check.** Flood-fill the gap volume from the pour spout in the pour orientation. Any disconnected pocket, or any local maximum in `+z` not reachable by rising air, is a trap → auto-place a 0.8 mm vent riser to the top surface.
12. **Seam features.** Along each cut plane: a mating flange with alignment pins/sockets (with print clearance ~0.15 mm), plus zip-tie or clip slots. The flange doubles as the leak seal.
13. **Pour spout.** A half-cone carved into each of the two wedges adjacent to one seam, parameterised by *position along that seam only* — it can slide, it cannot leave the seam, because each half carries one side of the hole. That constraint is a UI invariant, enforce it in the slider domain.
14. **Export.** Master + N wedges, each pre-oriented flat-face-down for printing, laid out on a virtual bed, as one 3MF (multi-object) or a zip of STLs.

### 3.3 Two-part rigid mold (`/mold`)

1. Shrink-compensate, then **choose the parting plane**: default to the plane maximising projected silhouette area (equivalently, minimising undercut area) — sample ~200 directions on a hemisphere and score each. Then let the user **drag it**, which is exactly what they do: *"the parting plane is yours to drag; you drag the seam so the model's widest silhouette sits on it and both halves pull free."*
2. **Undercut + draft preview.** Two passes: (a) per-face `dot(n, ±d)` vs the minimum draft angle; (b) a visibility raster — render a depth map from `+d` and `−d`; any face that is not a first hit is occluded, i.e. a true undercut. Colour-map both. *"If a surface leans back over the seam, that's an undercut."*
3. **Block** = model bbox + wall thickness, split by the parting plane into A and B.
4. **Cavity** = block_half − dilate(model, fit clearance). Clearance is a user setting, defaulting ~0.15 mm, described as "adjust if your printer runs tight".
5. **Seam treatment**, user's choice:
   - **Tongue and groove** for liquids (wax, resin): offset the parting-plane cross-section polygon inward, extrude ±h, union onto A / subtract from B.
   - **Registration pins** for rigid casts: conical pins with lead-in chamfers.
6. **Pour holes — 1 to 4.** First hole at the global high point of the cavity; the rest at the next local maxima in the pour direction, "which is where air gets trapped when a long or branched shape fills through a single spout". Size is user-set.
7. **Vents** at remaining local maxima; clamp features, flat feet, embossed A/B labels.

### 3.4 The other generators (specs, compressed)

- **Formwork box** (`/silicone-mold`): §3.3's block, but the cavity is the master + gap, and the box is walls-only with a lift-off lid. Simpler than adaptive; keep both, since adaptive costs more print time and users pick per job.
- **Vase mold**: outer shell **and** an inner core, joined by bridges at the rim; core release needs its own draft check.
- **Multi-cavity tray**: single cavity → tapered for release → arrayed N×M → subtracted from a tray blank with rim and pour channel; per-cavity volume readout.
- **Compression mold**: die body + piston with a running clearance, deep charge chamber. The calculator is `cavity_volume × material_density ÷ shred_bulk_density` → charge height vs chamber height → "one press" or "needs a top-up round".
- **Cutter** (`/cutter`): raster → luma threshold (or SVG path parse) → marching squares → Douglas–Peucker simplify → Clipper2 offset for the blade → extrude a tapered edge profile + rim + optional internal imprint ribs.
- **Lithophane**: grayscale → `thickness = t_min + (1 − luma^γ)(t_max − t_min)` → grid mesh + frame; flat / curved / cylindrical / nightlight variants.
- **Keychain / nameplate**: opentype.js glyph outlines → polygon union (essential for script fonts, whose glyphs overlap) → extrude onto a base plate + ring hole.
- **Planter**: PCA auto-orient → hollow by inward SDF offset → drill planting bore + drainage holes → optional saucer.
- **Optimize**: §3.1 repair ladder + quadric decimation (meshoptimizer WASM) with a target-triangle slider and a live before/after diff.

---

## 4. Recommended stack

| Layer | Choice | Why |
|---|---|---|
| Web app | **Next.js 15 App Router + TypeScript + Tailwind** | Matches `apps/web` skills already in the team; best-in-class for the SEO surface (30+ landing/guide pages) this product lives on. |
| 3D viewer | **three.js + react-three-fiber + drei** | Custom drag gizmo for the parting plane; section-cut via clipping planes. |
| CSG | **manifold-3d (WASM)** | Fast, genuinely robust boolean kernel, guaranteed-manifold output, Emscripten build, MIT-ish. Almost certainly what they use. |
| SDF / voxel / isosurface | **Custom Rust → wasm-bindgen** (`fast_surface_nets`, BVH triangle queries, winding numbers) | The offset-shell path is the perf-critical inner loop; JS will not do it at interactive rates. |
| Threading | Web Worker + SharedArrayBuffer, `COOP`/`COEP` headers | Note: cross-origin isolation breaks some third-party embeds — decide before shipping ads/widgets. |
| Server geometry | Same WASM under Node, **BullMQ + Redis** queue | One kernel, two hosts. Never fork the implementation. |
| API | **NestJS + PostgreSQL** | Direct reuse of VidyaTrack patterns (guards, interceptors, migrations). No RLS needed — single-tenant SaaS. |
| Payments | **Stripe** (Checkout + Billing Portal + webhooks) | Global $ pricing, subscription + one-time (Founder) in one integration. |
| Storage | S3 / Cloudflare R2 | Only used on the server-side fallback path and for library/gallery assets. |
| Fonts/vector | opentype.js, Clipper2-wasm | Text and cutter tools. |

---

## 5. Backend surface

**Data model (core tables):** `users` · `sessions` · `subscriptions` (Stripe id, tier, status, current_period_end, lifetime flag) · `entitlements` (derived tier, watermark_free, commercial_rights, quota_per_period, period) · `download_grants` (user, tool, params_hash, token, issued_at, consumed_at) · `quota_ledger` (append-only debits, one row per download — this is the audit trail) · `generations` (telemetry: tool, params, mesh stats, duration, outcome, rejection reason) · `designs` (curated library) · `design_downloads` · `gallery_submissions` (+ moderation state) · `guides` (MDX or CMS-backed) · `translations` · `changelog_entries` · `referrals`.

**Endpoints:**
- `POST /auth/magic-link`, `POST /auth/verify`, OAuth callbacks
- `GET  /me/entitlements` → tier, remaining downloads, period reset time
- `POST /downloads/grant` → body `{tool, paramsHash, meshStats}`; server checks quota, writes a ledger row, returns a short-TTL signed token
- `POST /downloads/consume` → redeems token; for watermark-free tiers may return a server-generated file instead
- `POST /jobs/generate` + `GET /jobs/:id` → server-side fallback path
- `POST /stripe/webhook` → subscription lifecycle → entitlements
- `GET /designs`, `GET /designs/:id/download` (Pro-gated)
- `POST /gallery/submissions`, `GET /gallery`
- `GET /guides`, `GET /guides/:slug`, `GET /changelog`
- `GET /i18n/:locale` (locale from cookie/`Accept-Language`, **URL unchanged**)

**The gating decision that matters:** geometry runs client-side, so the *file* is already on
the user's machine before any paywall. Therefore gate the **download action**, not the
computation — the button calls `/downloads/grant`, which debits quota server-side and
returns a token. This is honest, matches their behaviour, and is unspoofable enough
(someone determined can pull the buffer out of memory; that is true of Meshcast too, and it
does not matter — the paying customer is buying convenience and commercial rights, not DRM).

**Watermarking (free tier):** emboss a small mark on a non-functional face — the outside of
the shell, the underside of the base — never inside the cavity, which would transfer to the
cast. Also stamp 3MF metadata.

---

## 6. Phased roadmap

| Phase | Scope | Effort (1 strong full-stack + graphics dev) |
|---|---|---|
| **0 — Spike** | Unblock and capture the real site. Node CLI proving the whole chain on 20 messy test meshes: STL in → repair → SDF → offset shell → 2 wedges → STL out. **No UI.** Gate: it survives all 20, including AI-generated garbage. | 1 week |
| **1 — Adaptive shell MVP** | The video's tool, in the browser. Upload, viewer, gap/wall/wedge params, seam drag, spout slider, **live silicone-volume-vs-box savings readout**, release + air-trap checks, master + wedges export. No accounts. | 3–4 weeks |
| **2 — Business layer** | Auth, entitlements, quota ledger, Stripe (Pro $20/mo + Founder one-time), watermark, download-token flow, pricing page. | 2–3 weeks |
| **3 — Mold family** | `/mold` two-part rigid, `/silicone-mold` formwork box, tray/multi-cavity, candle, vase (with inner core), compression die. Plus the nine shape designers and the **one-click designer → generator handoff**. | 4–5 weeks |
| **4 — Light tools** | Cutter, lithophane, keychain, nameplate, planter, SVG→STL, embosser. Individually cheap, collectively the SEO engine. | 2–3 weeks |
| **5 — Repair** | `/optimize` as a standalone page **and** as "Fix it for me" wired into every rejection dialog in the app. | 2 weeks |
| **6 — Content & community** | Guides/MDX pipeline, per-locale translation without URL change, designs library, community gallery + moderation, public changelog, referral params. | Ongoing, start in parallel from Phase 2 |

**Realistic totals:** ~4.5 months solo, ~2.5–3 months with two devs (one owning the WASM
kernel, one owning app + backend + content). Phase 0 and 1 are the risk; Phases 2–6 are
well-understood work.

---

## 7. Risks

1. **Robust CSG on user meshes is the whole project.** Mitigation is architectural, not
   heroic: make the voxel/SDF path the *default*, not the fallback. Anything that goes
   through an SDF re-extraction is watertight by construction, and booleans on watertight
   input rarely fail. Accept slight feature softening as the price.
2. **Performance budget.** A 512³ dense grid is 134M voxels — impossible in a tab. Narrow-band
   only, adaptive resolution, Rust/WASM, worker threads. Target: first preview < 3 s, final
   geometry < 15 s on a mid-range laptop. Instrument and enforce it from Phase 1.
3. **Cross-origin isolation.** SharedArrayBuffer needs COOP/COEP, which breaks many
   third-party embeds. Decide early whether the marketing pages and the app share an origin.
4. **Print-fit tolerances are empirical, not theoretical.** Clearances, pin fits, seam seals
   only get validated by printing. Budget a printer, silicone, and a test matrix — this is
   the same "verify live, not just compiled" rule we already run on VidyaTrack, and it
   applies harder here because the failure mode is a customer's wasted 6-hour print.
5. **Content volume is a real cost.** 30+ guides and landing pages, translated. That is a
   writer's job, sustained, not a sprint.
6. **IP.** Reimplement mechanisms; write our own copy, brand, renders, and library. See §0.3.

---

## 8. Immediate next steps

1. **Decide where this lives.** It is a completely separate product from VidyaTrack —
   different domain, different stack, different customers. Recommendation: **a new
   repository**. This plan sits on `claude/meshcast-feature-analysis-nth2ml` only because
   that is the branch this session was assigned.
2. **Unblock `meshcast.app`** for this environment, or send page HTML / a HAR capture. That
   upgrades Section 3 from informed inference to verified fact and will change some
   parameter defaults.
3. **Confirm the business shape** — same $20/$349 pricing, or different for an India-first
   launch? This changes the Stripe vs domestic-gateway decision in Phase 2.
4. **Green-light Phase 0.** One week, no UI, one CLI, twenty ugly meshes. If the kernel
   holds, everything after it is ordinary engineering. If it does not, we find out for the
   cost of a week instead of a quarter.
