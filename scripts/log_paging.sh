#!/usr/bin/env bash
# log_paging.sh — record an Emergency Paging Attempt (allowed or denied).
# Usage: log_paging.sh <caller_num> <code> <zone> [denied]
set -euo pipefail
CALLER="${1:-unknown}"; CODE="${2:-unknown}"; ZONE="${3:-unknown}"; RESULT="${4:-allowed}"
TS="$(date +%Y-%m-%dT%H:%M:%S%z)"
DIR="/var/lib/upes-ecs/paging"; mkdir -p "${DIR}"
echo "${TS} PAGING code=${CODE} zone=${ZONE} caller=${CALLER} result=${RESULT}" >> "${DIR}/paging.log"
logger -t upes-ecs "PAGING code=${CODE} zone=${ZONE} caller=${CALLER} result=${RESULT}"
