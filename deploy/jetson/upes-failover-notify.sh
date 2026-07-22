#!/usr/bin/env bash
#
# upes-failover-notify.sh -- keepalived notify hook (notify_master/backup/fault).
#
# keepalived calls this with the new state name as $1 (MASTER|BACKUP|FAULT), and
# usually appends its own args (type, name, state) -- we only use the first token.
# Intentionally minimal and no-op-friendly: it must NEVER fail in a way that could
# disrupt VRRP. It just logs + timestamps a state file the Console/ops can read.
#
set -uo pipefail

STATE="${1:-UNKNOWN}"
STATE_DIR="/var/lib/upes-ecs/ha"
STATE_FILE="${STATE_DIR}/state"
LOG_FILE="${STATE_DIR}/failover.log"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
HOST="$(hostname 2>/dev/null || echo unknown)"

# Best-effort dir create; never abort on failure.
mkdir -p "$STATE_DIR" 2>/dev/null || true

# Record current state (single line, easy to read/parse).
printf '%s %s %s\n' "$TS" "$HOST" "$STATE" > "$STATE_FILE" 2>/dev/null || true
printf '%s %s -> %s\n' "$TS" "$HOST" "$STATE" >> "$LOG_FILE" 2>/dev/null || true

# Syslog so it lands in journalctl alongside keepalived.
logger -t upes-ha "VRRP state change on ${HOST}: ${STATE}" 2>/dev/null || true

# When we BECOME master it is worth nudging Asterisk to (re)qualify/registrations
# so contacts converge quickly. Safe no-op if asterisk is not reachable.
if [ "$STATE" = "MASTER" ]; then
  asterisk -rx "pjsip qualify" >/dev/null 2>&1 || true
fi

exit 0
