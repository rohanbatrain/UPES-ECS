#!/usr/bin/env bash
#
# run-foreground.sh -- start the three UPES-ECS components in the FOREGROUND,
# without launchd. Use this to debug, or on a box where LaunchAgents are not
# desired. Ctrl-C stops everything cleanly.
#
# It is installed next to macos.env by install-macos.sh (both land in
# /opt/upes-ecs). It sources macos.env for the resolved paths.
#
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$DIR/macos.env"
[ -f "$ENV_FILE" ] || { echo "ERROR: $ENV_FILE not found -- run install-macos.sh first" >&2; exit 1; }
# shellcheck source=/dev/null
. "$ENV_FILE"

export PATH="$BREW_PREFIX/bin:$BREW_PREFIX/sbin:$PATH"

PIDS=()
cleanup() {
  echo
  echo "== stopping UPES-ECS (foreground) =="
  for pid in "${PIDS[@]:-}"; do
    if [ -n "$pid" ]; then kill "$pid" 2>/dev/null || true; fi
  done
  # Ask asterisk to stop its own daemon if we started one in the background.
  "$ASTERISK_BIN" -rx "core stop now" >/dev/null 2>&1 || true
}
trap cleanup INT TERM EXIT

echo "== UPES-ECS foreground =="
echo "   brew prefix : $BREW_PREFIX"
echo "   LAN IP      : $LAN_IP   (Console http://$LAN_IP:8080)"

# 1) Asterisk (background daemon; -U current user is implicit).
echo "== starting asterisk =="
"$ASTERISK_BIN" -f -C "$ASTETC/asterisk.conf" &
PIDS+=("$!")
sleep 2

# 2) FastAPI status API on :8090.
echo "== starting API (:8090) =="
"$VENV/bin/python3" "$UPES_OPT/api/upes_api.py" &
PIDS+=("$!")

# 3) Console static server + /api proxy on :8080.
echo "== starting Console (:8080) =="
"$VENV/bin/python3" "$UPES_OPT/serve-console.py" &
PIDS+=("$!")

echo "== all started -- Ctrl-C to stop =="
wait
