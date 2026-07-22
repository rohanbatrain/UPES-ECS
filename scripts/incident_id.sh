#!/usr/bin/env bash
# incident_id.sh — print the next UPES-ECS incident ID: ERT-YYYYMMDD-NNNN
# Called from the dialplan via ${SHELL(...)}. Prints ONE line, no trailing noise.
#
# Uses a per-day counter file with a lock so concurrent 111 calls don't collide.
set -euo pipefail

STATE_DIR="/var/lib/upes-ecs"
DATE="$(date +%Y%m%d)"
SEQ_FILE="${STATE_DIR}/seq-${DATE}.txt"
LOCK="${STATE_DIR}/seq.lock"

mkdir -p "${STATE_DIR}"

# Serialize with flock so two simultaneous calls get different numbers.
exec 9>"${LOCK}"
flock 9

if [[ -f "${SEQ_FILE}" ]]; then
  n=$(<"${SEQ_FILE}")
else
  n=0
fi
n=$((n + 1))
printf '%s' "${n}" > "${SEQ_FILE}"

# Zero-pad to 4 digits: ERT-20260704-0001
printf 'ERT-%s-%04d' "${DATE}" "${n}"
