#!/usr/bin/env bash
# mass_callout.sh — mass-callout / roll-call engine for UPES-ECS.
#
# Rings every extension in a group CSV and plays a message. In "rollcall" mode it
# also collects a "press 1 = safe" DTMF ack. Origination target is [ctx_callout]
# in extensions_features.conf.
#
# The call is presented to the callee as the Emergency Alert Service — caller ID
# "UPES-EAS" <111> — NOT as an anonymous/unknown call. (EAS = Emergency Alert
# Service; 111 is the primary Campus Emergency number, see Numbering & Data Map.)
#
# Usage:
#   mass_callout.sh <group.csv> <sound_name> <notify|rollcall>
#
#   <group.csv>    One extension per line (blank lines and #comments ignored).
#                  Example: provisioning/callout-groups/wardens.example.csv
#   <sound_name>   Asterisk sound to play. A bare name is prefixed with "upes-ecs/"
#                  (so "callout-drill" -> "upes-ecs/callout-drill"). Pass a name
#                  that already contains "/" to use it verbatim.
#   mode           notify   = play message, hang up.
#                  rollcall = play message, read one DTMF digit (1 = safe),
#                             append "ext,response,time" to the run CSV.
#
# Output (rollcall):
#   /var/lib/upes-ecs/rollcall/<runid>.roster  every extension attempted (for the report)
#   /var/lib/upes-ecs/rollcall/<runid>.csv      ext,response,time  (written by ctx_callout)
#   Summarize a run with:  rollcall_report.sh <runid>
#
# HOW THE CALL IS PLACED (call files, not `channel originate`)
#   Each member is rung with an Asterisk *call file* dropped into the outgoing
#   spool (the same non-blocking mechanism as alert_responders.sh). Two reasons:
#     1. CallerID — a call file carries "CallerID: <UPES-EAS> <111>", so the phone
#        shows the Emergency Alert Service, not ANONYMOUS. `channel originate`
#        cannot attach a caller ID.
#     2. Per-call variables — the sound, run id and mode ride on the call file via
#        Setvar:, so ${CALLOUT_SOUND}/${CALLOUT_RUNID} are channel variables that
#        exist the instant the callee answers. The old `channel originate` path
#        could only pass these as shared globals, whose propagation raced the
#        answer: the callee often reached Playback(${CALLOUT_SOUND}) before the
#        global was readable, so an empty Playback() dropped the call with no
#        message. Call files remove that race entirely.
#
# CONCURRENCY
#   Because every parameter now rides on its own call file (no shared globals),
#   runs are independent and no lock is required. Calls are still paced CALL_DELAY
#   seconds apart to avoid flooding the PBX/registrar.
set -euo pipefail

# ---- tunables (override via env) --------------------------------------------
CALL_DELAY="${CALL_DELAY:-2}"          # seconds between originations
STATE_DIR="/var/lib/upes-ecs/rollcall"
SPOOL="${SPOOL:-/var/spool/asterisk/outgoing}"   # Asterisk outgoing call-file spool
STAGE="${STAGE:-/tmp}"                 # stage call files here, then atomic-move into SPOOL

# Emergency Alert Service caller identity shown on the ringing phone.
EAS_CID_NAME="${EAS_CID_NAME:-UPES-EAS}"   # display name (never ANONYMOUS)
EAS_CID_NUM="${EAS_CID_NUM:-111}"          # number = primary Campus Emergency number

# Ring/retry behaviour of each call file.
WAIT_TIME="${WAIT_TIME:-30}"           # seconds to wait for an answer
MAX_RETRIES="${MAX_RETRIES:-1}"        # retries if unanswered/busy
RETRY_TIME="${RETRY_TIME:-15}"         # seconds between retries

usage() { sed -n '2,48p' "$0"; }

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage; exit 0
fi

if [[ $# -ne 3 ]]; then
  echo "ERROR: expected 3 arguments." >&2
  echo "Usage: $(basename "$0") <group.csv> <sound_name> <notify|rollcall>" >&2
  exit 2
fi

GROUP_CSV="$1"
SOUND_NAME="$2"
MODE="$3"

case "${MODE}" in
  notify|rollcall) ;;
  *) echo "ERROR: mode must be 'notify' or 'rollcall' (got '${MODE}')." >&2; exit 2 ;;
esac

if [[ ! -r "${GROUP_CSV}" ]]; then
  echo "ERROR: group CSV not readable: ${GROUP_CSV}" >&2
  exit 2
fi

# Prefix a bare sound name with the UPES-ECS sounds subdir.
if [[ "${SOUND_NAME}" == */* ]]; then
  SOUND="${SOUND_NAME}"
else
  SOUND="upes-ecs/${SOUND_NAME}"
fi

# Run id: date-time + short random, safe as a filename component.
RUNID="$(date +%Y%m%d-%H%M%S)-$$"

mkdir -p "${STATE_DIR}"

ROSTER="${STATE_DIR}/${RUNID}.roster"
: > "${ROSTER}"
if [[ "${MODE}" == "rollcall" ]]; then
  RC_CSV="${STATE_DIR}/${RUNID}.csv"
  : > "${RC_CSV}"                     # create empty; ctx_callout appends rows
  # CRITICAL: this script runs as root (via the API), but the dialplan System() append
  # runs as the 'asterisk' user. Without this it can't write the file (Permission denied)
  # and every response is silently lost. Make it writable by Asterisk.
  chown asterisk:asterisk "${RC_CSV}" 2>/dev/null || chmod 0666 "${RC_CSV}" 2>/dev/null || true
fi
# keep the whole state dir owned by asterisk so future appends/creates succeed too
chown asterisk:asterisk "${STATE_DIR}" 2>/dev/null || true

echo "mass_callout: runid=${RUNID} mode=${MODE} sound=${SOUND} group=${GROUP_CSV} cid=\"${EAS_CID_NAME}\" <${EAS_CID_NUM}>"
logger -t upes-ecs "MASS_CALLOUT start runid=${RUNID} mode=${MODE} sound=${SOUND} eas_cid=${EAS_CID_NAME}"

# ---- ring each member via a call file ---------------------------------------
count=0
while IFS= read -r line || [[ -n "${line}" ]]; do
  # normalize: strip CR (Windows CSV), surrounding whitespace
  ext="${line%%$'\r'}"
  ext="$(printf '%s' "${ext}" | tr -d '[:space:]')"
  [[ -z "${ext}" ]] && continue          # blank line
  [[ "${ext}" == \#* ]] && continue       # comment
  # keep only digits (extensions are numeric); reject anything else defensively
  if [[ ! "${ext}" =~ ^[0-9]+$ ]]; then
    echo "  skip (not numeric): ${ext}" >&2
    continue
  fi

  echo "${ext}" >> "${ROSTER}"
  echo "  -> call ${ext} (${MODE}) as \"${EAS_CID_NAME}\" <${EAS_CID_NUM}>"

  f="${STAGE}/callout-${RUNID}-${ext}.call"
  cat > "${f}" <<EOF
Channel: PJSIP/${ext}
CallerID: "${EAS_CID_NAME}" <${EAS_CID_NUM}>
MaxRetries: ${MAX_RETRIES}
RetryTime: ${RETRY_TIME}
WaitTime: ${WAIT_TIME}
Context: ctx_callout
Extension: ${MODE}
Priority: 1
Setvar: CALLOUT_SOUND=${SOUND}
Setvar: CALLOUT_RUNID=${RUNID}
Setvar: CALLOUT_MODE=${MODE}
Setvar: CALLOUT_MEMBER=${ext}
EOF
  chown asterisk:asterisk "${f}" 2>/dev/null || true
  # atomic move into the spool dir triggers the (non-blocking) call
  if ! mv "${f}" "${SPOOL}/" 2>/dev/null; then
    echo "  WARN: could not spool call file for ${ext} (is ${SPOOL} writable?)" >&2
  fi

  count=$((count + 1))
  sleep "${CALL_DELAY}"
done < "${GROUP_CSV}"

echo "mass_callout: done. runid=${RUNID} attempted=${count}"
logger -t upes-ecs "MASS_CALLOUT end runid=${RUNID} attempted=${count}"
