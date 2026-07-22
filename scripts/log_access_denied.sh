#!/usr/bin/env bash
# log_access_denied.sh — record an Access Denied Event (Feature 13 / Health Monitoring).
# Usage: log_access_denied.sh <caller_num> <attempted_ext>
set -euo pipefail

CALLER="${1:-unknown}"
TARGET="${2:-unknown}"
TS="$(date +%Y-%m-%dT%H:%M:%S%z)"
LOG_DIR="/var/lib/upes-ecs/security"
mkdir -p "${LOG_DIR}"

echo "${TS} ACCESS_DENIED caller=${CALLER} target=${TARGET}" >> "${LOG_DIR}/access-denied.log"
logger -t upes-ecs "ACCESS_DENIED caller=${CALLER} target=${TARGET}"
