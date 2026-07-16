#!/usr/bin/env bash
# Print the current dev OTP for a phone (read from Redis). No SMS is sent in dev.
# Usage: ./dev-otp.sh [phone]   (default 9999900001 = demo admin)
PHONE="${1:-9999900001}"
OTP=$(docker exec vidyatrack-redis redis-cli GET "otp:${PHONE}" 2>/dev/null)
if [ -z "$OTP" ] || [ "$OTP" = "(nil)" ]; then
  echo "No active OTP for ${PHONE}. Tap 'Send OTP' in the app first (codes expire after 5 min)."
else
  echo "OTP for ${PHONE}: ${OTP}"
fi
