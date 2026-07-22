#!/usr/bin/env bash
#
# chk-asterisk.sh -- keepalived track_script health check for Asterisk.
#
# Exit 0 (healthy) only if BOTH are true:
#   1. the asterisk systemd unit is active, AND
#   2. `asterisk -rx "core show version"` actually responds (the daemon answers
#      on its control socket -- i.e. it is not wedged/deadlocked while "active").
#
# Any failure -> non-zero exit, which makes keepalived subtract the configured
# weight from this node's VRRP priority and hand the VIP to the peer.
#
set -euo pipefail

# 1. unit active?
if ! systemctl is-active --quiet asterisk; then
  exit 1
fi

# 2. control socket answers? (grep keeps us robust to CLI wording changes)
if asterisk -rx "core show version" 2>/dev/null | grep -qi "Asterisk"; then
  exit 0
fi

exit 2
