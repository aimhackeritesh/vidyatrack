# VidyaTrack API image.
# Build from the REPO ROOT so the npm-workspace lockfile is in context:
#   docker build -f apps/api/Dockerfile -t vidyatrack-api .
# (docker-compose and Railway are configured to do this.)

# ── Build stage ──────────────────────────────────────────────────────────────
FROM node:20-alpine AS builder
WORKDIR /app

# argon2 is a native module — needs a toolchain to compile on alpine/musl.
RUN apk add --no-cache python3 make g++

# Install against the workspace lockfile (deps hoist to the root node_modules).
COPY package.json package-lock.json ./
COPY apps/api/package.json ./apps/api/
COPY apps/web/package.json ./apps/web/
RUN npm ci

# Build only the API.
COPY apps/api ./apps/api
RUN npm run build --workspace=apps/api

# Drop dev dependencies (keeps compiled native binaries like argon2).
RUN npm prune --omit=dev

# ── Runtime stage ────────────────────────────────────────────────────────────
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/apps/api/dist ./apps/api/dist
COPY --from=builder /app/apps/api/package.json ./apps/api/
# schema.sql / rls-setup.sql ship in the image so the DB-apply step can run from it.
COPY --from=builder /app/apps/api/src/database ./apps/api/src/database
COPY --from=builder /app/package.json ./

# Uploads are ephemeral (V1) but the runtime user must be able to write here.
RUN mkdir -p /app/uploads && chown -R node:node /app/uploads

EXPOSE 3000
USER node

# Nest compiles src/ into dist/src, so the real entry is dist/src/main.js.
CMD ["node", "apps/api/dist/src/main.js"]
