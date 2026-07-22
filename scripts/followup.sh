#!/usr/bin/env bash
# followup.sh -- log a follow-up / callback on a Missed Emergency Incident.
#
# Missed 111 calls are "never auto-closed": a human must call the person back and record
# the outcome. This appends one auditable record per attempt to followups.ndjson. The
# dashboard DERIVES each incident's open/closed state from these records (it never mutates
# the incident log), so history is never lost and the same incident can have several attempts.
#
# Usage: followup.sh <incident_id> <operator_ext> <outcome> [note]
#   outcome:
#     safe       -> reached them, they are OK        (CLOSES the follow-up)
#     escalated  -> handed to ERT / authorities      (CLOSES the follow-up)
#     noanswer   -> could not reach them, will retry  (stays OPEN, logs an attempt)
#     needshelp  -> reached them, they need help      (stays OPEN + urgent until escalated)
set -euo pipefail

INCIDENT_ID="${1:?incident_id required}"
OPERATOR="${2:?operator ext required}"
OUTCOME="${3:?outcome required}"
NOTE="${4:-}"

case "$OUTCOME" in
  safe|escalated|noanswer|needshelp) ;;
  *) echo "bad outcome '$OUTCOME' (want: safe|escalated|noanswer|needshelp)" >&2; exit 2 ;;
esac
# incident ids look like ERT-20260707-0007 -- keep it strict.
case "$INCIDENT_ID" in *[!A-Za-z0-9-]*) echo "bad incident_id" >&2; exit 2 ;; esac

STORE_DIR="/var/lib/upes-ecs/incidents"
mkdir -p "$STORE_DIR"
TS="$(date +%Y-%m-%dT%H:%M:%S%z)"

# NDJSON safety: strip quotes/newlines/backslashes from the free-text note and bound its length.
NOTE_CLEAN="$(printf '%s' "$NOTE" | tr -d '\r\n"\\' | cut -c1-200)"

if [ "$OUTCOME" = "safe" ] || [ "$OUTCOME" = "escalated" ]; then CLOSED=true; else CLOSED=false; fi

printf '{"incident_id":"%s","datetime":"%s","operator":"%s","outcome":"%s","closed":%s,"note":"%s"}\n' \
  "$INCIDENT_ID" "$TS" "$OPERATOR" "$OUTCOME" "$CLOSED" "$NOTE_CLEAN" \
  >> "$STORE_DIR/followups.ndjson"

logger -t upes-ecs "FOLLOWUP ${INCIDENT_ID} by=${OPERATOR} outcome=${OUTCOME} closed=${CLOSED}"
echo "logged followup ${INCIDENT_ID} outcome=${OUTCOME} closed=${CLOSED}"
