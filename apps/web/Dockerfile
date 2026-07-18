# VidyaTrack super-admin web console image.
# Build from the REPO ROOT so the npm-workspace lockfile is in context:
#   docker build -f apps/web/Dockerfile --build-arg NEXT_PUBLIC_API_URL=... .
# NOTE: production web is deployed on Vercel (which ignores this Dockerfile);
# this exists so `docker compose` and CI can build the full stack.

# ── Build stage ──────────────────────────────────────────────────────────────
FROM node:20-alpine AS builder
WORKDIR /app

COPY package.json package-lock.json ./
COPY apps/api/package.json ./apps/api/
COPY apps/web/package.json ./apps/web/
RUN npm ci

COPY apps/web ./apps/web

# NEXT_PUBLIC_* vars are inlined at build time, so the API URL must be present now.
ARG NEXT_PUBLIC_API_URL=http://localhost:3000/api/v1
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
RUN npm run build --workspace=apps/web

# ── Runtime stage ────────────────────────────────────────────────────────────
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production

# `output: 'standalone'` with the workspace tracing root recreates the monorepo
# layout under standalone/, so server.js lands at apps/web/server.js.
COPY --from=builder /app/apps/web/.next/standalone ./
COPY --from=builder /app/apps/web/.next/static ./apps/web/.next/static

EXPOSE 3000
USER node
CMD ["node", "apps/web/server.js"]
