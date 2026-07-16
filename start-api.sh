#!/usr/bin/env bash
# Restart the VidyaTrack API on the host (talks to the Dockerized Postgres/Redis).
# Use this if the API stops (e.g. after the Mac sleeps) and the app can't connect.
set -euo pipefail
cd "$(dirname "$0")/apps/api"

# Make sure infra is up
docker compose -f ../../docker-compose.yml up -d postgres redis >/dev/null 2>&1 || true

# Kill any stale API on :3000
if lsof -nP -tiTCP:3000 -sTCP:LISTEN >/dev/null 2>&1; then
  kill "$(lsof -nP -tiTCP:3000 -sTCP:LISTEN)" 2>/dev/null || true
  sleep 1
fi

echo "Starting API on http://0.0.0.0:3000 (logs: /tmp/vidyatrack-api.log)"
nohup node --enable-source-maps dist/src/main.js > /tmp/vidyatrack-api.log 2>&1 &
echo "PID $!  — waiting for readiness..."
i=0
until curl -sf http://localhost:3000/api/docs >/dev/null 2>&1; do
  i=$((i+1)); [ $i -gt 40 ] && { echo "FAILED — see /tmp/vidyatrack-api.log"; exit 1; }
  sleep 1
done
echo "API ready: http://192.168.1.5:3000/api/v1  (Swagger: http://localhost:3000/api/docs)"
