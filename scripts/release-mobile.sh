#!/usr/bin/env bash
# One-command mobile release.
#   ./scripts/release-mobile.sh 1.0.1            → build AAB + APK, tag, draft GitHub release
#   ./scripts/release-mobile.sh 1.0.1 --publish  → also publish the release
#
# Requires: apps/mobile/android/key.properties (upload keystore) and `gh` authenticated.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:?usage: release-mobile.sh <version> [--publish]}"
PUBLISH="${2:-}"
API_URL="${API_URL:-https://api-production-28467.up.railway.app/api/v1}"
export PATH="$PATH:$HOME/development/flutter/bin"

echo "▸ Releasing v$VERSION against $API_URL"

[ -f apps/mobile/android/key.properties ] || {
  echo "✗ apps/mobile/android/key.properties missing — release would be debug-signed. Aborting."; exit 1; }

cd apps/mobile

# Version: pubspec is the source of truth (versionCode = the +N build number)
BUILD=$(grep -E '^version:' pubspec.yaml | sed -E 's/.*\+([0-9]+).*/\1/')
NEXT=$((BUILD + 1))
sed -i '' -E "s/^version: .*/version: ${VERSION}+${NEXT}/" pubspec.yaml
echo "▸ pubspec version -> ${VERSION}+${NEXT}"

echo "▸ Gates"
flutter analyze  # must be 0 errors/warnings
flutter test

echo "▸ Building"
flutter build appbundle --release --dart-define=API_URL="$API_URL"
flutter build apk       --release --dart-define=API_URL="$API_URL"

AAB=build/app/outputs/bundle/release/app-release.aab
APK=build/app/outputs/flutter-apk/app-release.apk

# Fail loudly if it somehow got debug-signed
JBR="/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin"
if [ -x "$JBR/jarsigner" ]; then
  "$JBR/jarsigner" -verify -certs "$AAB" | grep -q "Android Debug" && {
    echo "✗ AAB is DEBUG signed — do not upload"; exit 1; }
  echo "▸ signature OK (not debug)"
fi

cd ../..
cp "apps/mobile/$APK" "/tmp/vidyatrack-${VERSION}.apk"

NOTES="Release v${VERSION}

Install the APK below on Android, or use the Play Store listing.
Demo: school code VDTRK2627DEMO01, password Demo@1234 (admin 9999900001 / teacher ...02 / parent ...03)."

if [ "$PUBLISH" = "--publish" ]; then
  gh release create "v${VERSION}" "/tmp/vidyatrack-${VERSION}.apk" --title "VidyaTrack v${VERSION}" --notes "$NOTES"
else
  gh release create "v${VERSION}" "/tmp/vidyatrack-${VERSION}.apk" --title "VidyaTrack v${VERSION}" --notes "$NOTES" --draft
  echo "▸ DRAFT release created (re-run with --publish, or publish from the GitHub UI)"
fi

echo "✓ Done. Upload this to Play Console:"
echo "   apps/mobile/$AAB"
