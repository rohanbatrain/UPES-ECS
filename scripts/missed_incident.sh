#!/usr/bin/env bash
# missed_incident.sh — record a Missed Emergency Incident and raise a dashboard flag.
# Called from the dialplan after emergency voicemail (or on early hangup).
#
# Usage: missed_incident.sh <incident_id> <caller_num> <caller_name> <severity> <status>
#   status: pending | pending-novm
#
# Writes a JSON line to the incident store and a flag file the Health Dashboard reads.
set -euo pipefail

INCIDENT_ID="${1:-UNKNOWN}"
CALLER_NUM="${2:-unknown}"
CALLER_NAME="${3:-unknown}"
SEVERITY="${4:-critical}"
STATUS="${5:-pending}"

STORE_DIR="/var/lib/upes-ecs/incidents"
ALERT_DIR="/var/lib/upes-ecs/alerts"
TS="$(date +%Y-%m-%dT%H:%M:%S%z)"

mkdir -p "${STORE_DIR}" "${ALERT_DIR}"

# Append one JSON record (newline-delimited JSON — easy to tail/ingest later).
cat >> "${STORE_DIR}/missed-emergency.ndjson" <<EOF
{"incident_id":"${INCIDENT_ID}","type":"missed_emergency","datetime":"${TS}","caller_extension":"${CALLER_NUM}","caller_name":"${CALLER_NAME}","severity":"${SEVERITY}","review_status":"${STATUS}","voicemail":"$([[ "${STATUS}" == "pending-novm" ]] && echo none || echo available)"}
EOF

# Raise a pending-review flag for the dashboard / daily check to surface.
echo "${TS} ${INCIDENT_ID} ${CALLER_NUM} ${SEVERITY} ${STATUS}" >> "${ALERT_DIR}/missed-pending.log"

logger -t upes-ecs "MISSED EMERGENCY ${INCIDENT_ID} caller=${CALLER_NUM} severity=${SEVERITY} status=${STATUS}"
