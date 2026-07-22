#!/usr/bin/env bash
#
# run-foreground.sh -- non-systemd launcher for UPES-ECS on Linux.
#
# Installed to /opt/upes-ecs/run-foreground.sh by install-linux.sh when the host
# has NO pid1 systemd (containers, minimal WSL). It starts Asterisk (foreground
# under its own supervision), the status API (venv), and the Console server, then
# tails them and cleans up on Ctrl-C. Everything logs to /var/log/upes-ecs/.
#
set -euo pipefail

VENV=/opt/upes-ecs/venv
LOGDIR=/var/log/upes-ecs
mkdir -p "$LOGDIR"

[ "$(id -u)" -eq 0 ] || { echo "run as root (sudo)"; exit 1; }

PIDS=()
cleanup() {
  echo ""
  echo "== stopping UPES-ECS =="
  for p in "${PIDS[@]:-}"; do
    [ -n "${p:-}" ] || continue
    kill "$p" 2>/dev/null || true
  done
  asterisk -rx 'core stop now' >/dev/null 2>&1 || true
  exit 0
}
trap cleanup INT TERM

echo "== starting Asterisk =="
if asterisk -rx 'core show version' >/dev/null 2>&1; then
  echo "  asterisk already running"
else
  # -U/-G run as the asterisk user; drop to background daemon then supervise via CLI.
  asterisk -g -U asterisk -G asterisk >>"$LOGDIR/asterisk.out" 2>&1 || \
    asterisk -g >>"$LOGDIR/asterisk.out" 2>&1 || true
  # Wait for the CLI socket.
  for _ in $(seq 1 15); do
    asterisk -rx 'core show version' >/dev/null 2>&1 && break
    sleep 1
  done
fi

echo "== starting status API (:8090) =="
"$VENV/bin/python" /opt/upes-ecs/api/upes_api.py >>"$LOGDIR/upes-api.out" 2>&1 &
PIDS+=($!)

echo "== starting Console (:8080) =="
UPES_CONSOLE_ROOT=/opt/upes-ecs/console \
UPES_CONSOLE_PORT=8080 \
UPES_API_BASE=http://127.0.0.1:8090 \
  /usr/bin/python3 /opt/upes-ecs/serve-console.py >>"$LOGDIR/serve-console.out" 2>&1 &
PIDS+=($!)

sleep 2
echo "-------------------------------------------------------------------"
echo "  UPES-ECS running (foreground). Logs in $LOGDIR/"
echo "    Console: http://0.0.0.0:8080    API: http://127.0.0.1:8090/health"
echo "  Press Ctrl-C to stop."
# Wait on the API/Console children; if either dies, keep the script alive so the
# operator sees it (Asterisk supervises itself).
wait
