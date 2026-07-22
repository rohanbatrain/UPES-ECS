#!/usr/bin/env bash
#
# upes-mdns-failover.sh -- keepalived notify hook for the NO-VIP / mDNS variant.
#
# keepalived's generic `notify` calls this with:  $1=type(INSTANCE|GROUP)  $2=name
# $3=STATE(MASTER|BACKUP|FAULT)  $4=priority. We drive the mDNS publisher from STATE:
#
#   MASTER        -> start upes-mdns.service (this node publishes upes-ecs.local -> its
#                    own IP) and nudge Asterisk to re-qualify so contacts converge.
#   BACKUP|FAULT  -> stop upes-mdns.service (withdraw the name; the new MASTER owns it).
#
# Because keepalived elects exactly one MASTER, exactly one node publishes the name,
# which is what prevents split-brain. This hook is deliberately no-op-friendly: it
# must NEVER fail in a way that could disturb VRRP.
#
set -uo pipefail

# Be robust to how we're invoked: prefer the documented $3, but also scan every arg
# for a recognised state token (so a single-arg call like ".../hook MASTER" also works).
STATE=""
for a in "$@"; do
  case "$a" in
    MASTER|BACKUP|FAULT|STOP) STATE="$a" ;;
  esac
done
[ -n "$STATE" ] || STATE="${3:-${1:-UNKNOWN}}"

STATE_DIR="/var/lib/upes-ecs/ha"
STATE_FILE="${STATE_DIR}/state"
LOG_FILE="${STATE_DIR}/failover.log"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
HOST="$(hostname 2>/dev/null || echo unknown)"

mkdir -p "$STATE_DIR" 2>/dev/null || true

case "$STATE" in
  MASTER)
    # Become the name owner: start publishing upes-ecs.local -> our own IP.
    systemctl start upes-mdns 2>/dev/null || true
    # Nudge Asterisk to (re)qualify so contacts/registrations converge quickly.
    asterisk -rx "pjsip qualify" >/dev/null 2>&1 || true
    ;;
  BACKUP|FAULT|STOP)
    # Not the name owner (any more): withdraw the record so the MASTER owns it alone.
    systemctl stop upes-mdns 2>/dev/null || true
    ;;
  *)
    : # unknown state -- record it below but take no publish action
    ;;
esac

# Record + log the transition (single-line state file the Console/ops can read).
printf '%s %s %s\n' "$TS" "$HOST" "$STATE" > "$STATE_FILE" 2>/dev/null || true
printf '%s %s -> %s\n' "$TS" "$HOST" "$STATE" >> "$LOG_FILE" 2>/dev/null || true
logger -t upes-ha-mdns "VRRP state change on ${HOST}: ${STATE}" 2>/dev/null || true

exit 0
