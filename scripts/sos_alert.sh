#!/usr/bin/env bash
# sos_alert.sh — raise a CRITICAL "silent_sos" incident from the duress code (*77).
# Called from the dialplan: [ctx_sos] exten *77.
#
# Usage: sos_alert.sh <incident_id> <caller_num> <caller_name>
#
# Mirrors missed_incident.sh: writes one ndjson record to the SAME incident store,
# raises an alert flag file for the dashboard/daily check, and logs via logger.
set -euo pipefail

INCIDENT_ID="${1:-UNKNOWN}"
CALLER_NUM="${2:-unknown}"
CALLER_NAME="${3:-unknown}"

STORE_DIR="/var/lib/upes-ecs/incidents"
ALERT_DIR="/var/lib/upes-ecs/alerts"
TS="$(date +%Y-%m-%dT%H:%M:%S%z)"

mkdir -p "${STORE_DIR}" "${ALERT_DIR}"

# Append one newline-delimited JSON record (same store as missed_incident.sh).
cat >> "${STORE_DIR}/silent-sos.ndjson" <<EOF
{"incident_id":"${INCIDENT_ID}","type":"silent_sos","datetime":"${TS}","caller_extension":"${CALLER_NUM}","caller_name":"${CALLER_NAME}","severity":"critical","review_status":"pending","talk_path":"none"}
EOF

# Raise a CRITICAL alert flag the dashboard / daily check surfaces immediately.
echo "${TS} ${INCIDENT_ID} ${CALLER_NUM} critical silent_sos pending" >> "${ALERT_DIR}/sos-pending.log"

logger -t upes-ecs "SILENT SOS ${INCIDENT_ID} caller=${CALLER_NUM} severity=critical status=pending"
