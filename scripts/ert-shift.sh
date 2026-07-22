#!/usr/bin/env bash
# UPES-ECS — staff / unstaff an ERT answer point on the emergency (111) queue.
#
# The 111 hotline is only "ready" when at least one ERT answer point is available
# in the queue. Positions 4110-4113 are static members; in a pilot the on-shift
# operator's registered handset joins the queue so 111 actually rings a phone.
#
# Usage:
#   ert-shift.sh on  <extension>   # go on shift  (add PJSIP/<ext> to the ERT queue)
#   ert-shift.sh off <extension>   # go off shift (remove it)
#   ert-shift.sh status            # show queue members + availability
#
# Dynamic members persist in astdb across Asterisk restarts. The handset must be
# registered for the member to show "Not in use" (available).
set -euo pipefail
QUEUE="${UPES_QUEUE:-ert_emergency_queue}"
ACT="${1:-status}"
EXT="${2:-}"

case "$ACT" in
  on)
    [ -n "$EXT" ] || { echo "usage: $0 on <extension>" >&2; exit 2; }
    asterisk -rx "queue add member PJSIP/$EXT to $QUEUE penalty 0 as On-Shift-$EXT"
    ;;
  off)
    [ -n "$EXT" ] || { echo "usage: $0 off <extension>" >&2; exit 2; }
    asterisk -rx "queue remove member PJSIP/$EXT from $QUEUE"
    ;;
  status|*)
    asterisk -rx "queue show $QUEUE"
    ;;
esac
