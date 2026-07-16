#!/usr/bin/env bash
set -euo pipefail

API_URL="${API_URL:-http://192.168.1.5:3000/api/v1}"
MODE="${MODE:-debug}"   # debug = native arm64 (no AOT); release = needs amd64 container

echo "==> Flutter version"
flutter --version

if [ ! -d android ]; then
  echo "==> Scaffolding Android platform (flutter create)"
  flutter create . --platforms=android --org com.vidyatrack --project-name vidyatrack
else
  echo "==> android/ already scaffolded, skipping flutter create"
fi

echo "==> Resolving dependencies (pub get)"
flutter pub get

echo "==> Building ${MODE} APK with API_URL=${API_URL}  EXTRA=${EXTRA_ARGS:-}"
flutter build apk --${MODE} ${EXTRA_ARGS:-} --dart-define=API_URL="${API_URL}"

echo "==> Build complete"
ls -la build/app/outputs/flutter-apk/
