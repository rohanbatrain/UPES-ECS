#!/usr/bin/env bash
# Append a shift ON/OFF event to the shift log — the audit trail for who is on
# shift, surfaced in the Console "Shift changes" panel and available for review.
set -euo pipefail
EXT="${1:-}"
ACTION="${2:-}"
LOG=/var/lib/upes-ecs/shift/shift.log
mkdir -p "$(dirname "$LOG")"
printf '%s|%s|%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$EXT" "$ACTION" >> "$LOG"
