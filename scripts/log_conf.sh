#!/usr/bin/env bash
# log_conf.sh — record Incident Conference join/leave events.
# Usage: log_conf.sh <caller_num> <room> <join|leave>
set -euo pipefail
CALLER="${1:-unknown}"; ROOM="${2:-unknown}"; ACTION="${3:-unknown}"
TS="$(date +%Y-%m-%dT%H:%M:%S%z)"
DIR="/var/lib/upes-ecs/conference"; mkdir -p "${DIR}"
echo "${TS} CONF room=${ROOM} caller=${CALLER} action=${ACTION}" >> "${DIR}/conference.log"
logger -t upes-ecs "CONF room=${ROOM} caller=${CALLER} action=${ACTION}"
