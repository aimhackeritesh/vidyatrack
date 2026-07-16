#!/usr/bin/env bash
# Serve the built APK over your Wi-Fi so the phone can download it.
# Phone must be on the same network as this Mac.
set -euo pipefail
cd "$(dirname "$0")"

APK_DIR="apps/mobile/build/app/outputs/flutter-apk"
APK="$APK_DIR/app-release.apk"
PORT=8000
IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo 127.0.0.1)"

if [ ! -f "$APK" ]; then
  echo "APK not found at $APK — build it first."
  exit 1
fi

echo "================================================================"
echo " On your Android phone (same Wi-Fi), open this URL in Chrome:"
echo
echo "     http://${IP}:${PORT}/app-release.apk"
echo
echo " Then tap the downloaded file to install."
echo " (You'll be asked to allow 'Install from unknown sources'.)"
echo " Press Ctrl+C here when the download is done."
echo "================================================================"
cd "$APK_DIR"
exec python3 -m http.server "$PORT"
