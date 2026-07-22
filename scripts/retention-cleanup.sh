#!/usr/bin/env bash
# retention-cleanup.sh — delete emergency recordings/voicemail past retention,
# UNLESS flagged for preservation. Logs every deletion (audit). Run daily via cron.
#
# Policy defaults (see 13-Recording-Retention-Policy.md):
#   Recordings/voicemail: 90 days   Logs: keep longer (handled separately)
# Preservation: create a file  <recording>.preserve  to exempt an incident.
set -euo pipefail

REC_DIR="/var/spool/asterisk/monitor/upes-ecs"
VM_DIR="/var/spool/asterisk/voicemail/upes-ecs"
RETAIN_DAYS=90
AUDIT="/var/lib/upes-ecs/retention/deletions.log"
TS="$(date +%Y-%m-%dT%H:%M:%S%z)"

mkdir -p "$(dirname "${AUDIT}")"

delete_old() {
  local dir="$1"
  [[ -d "${dir}" ]] || return 0
  # Find WAVs older than retention with NO matching .preserve flag.
  find "${dir}" -type f -name '*.wav' -mtime "+${RETAIN_DAYS}" -print0 |
  while IFS= read -r -d '' f; do
    if [[ -e "${f}.preserve" ]]; then
      echo "${TS} SKIP (preserved) ${f}" >> "${AUDIT}"
      continue
    fi
    rm -f -- "${f}"
    echo "${TS} DELETED ${f}" >> "${AUDIT}"
    logger -t upes-ecs "RETENTION deleted ${f}"
  done
}

delete_old "${REC_DIR}"
delete_old "${VM_DIR}"

echo "${TS} retention run complete (retain=${RETAIN_DAYS}d)" >> "${AUDIT}"
