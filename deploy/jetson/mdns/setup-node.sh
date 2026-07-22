#!/usr/bin/env bash
#
# setup-node.sh - ONE command to stand up a Jetson in the simple two-server
# mDNS name-failover cluster. Wraps the two underlying steps so you never touch
# the word "vip": it installs the full stack, then converts the node to mDNS
# failover (no Virtual IP, no Juniper VRRP config).
#
# Two boxes. Each knows the other exists on the LAN (keepalived heartbeat).
# Whoever is alive owns the name upes-ecs.local. Phones just follow the name.
#
# Usage (run on EACH box):
#   sudo ./setup-node.sh --role primary   --self <THIS-BOX-IP> --peer <OTHER-BOX-IP> [--iface eth0] [--host upes-ecs.local]
#   sudo ./setup-node.sh --role secondary --self <THIS-BOX-IP> --peer <OTHER-BOX-IP> [--iface eth0] [--host upes-ecs.local]
#
# --self  = this box's own static LAN IP on the voice VLAN
# --peer  = the OTHER box's static LAN IP
# Optional: --iface (default eth0), --host (default upes-ecs.local), --vrid, --priority
#
set -euo pipefail

ROLE=""; SELF=""; PEER=""; IFACE="eth0"; HOST="upes-ecs.local"; VRID=""; PRIORITY=""

die() { echo "ERROR: $*" >&2; exit 1; }
usage() {
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --role)     ROLE="${2:-}"; shift 2 ;;
    --self)     SELF="${2:-}"; shift 2 ;;
    --peer)     PEER="${2:-}"; shift 2 ;;
    --iface)    IFACE="${2:-}"; shift 2 ;;
    --host)     HOST="${2:-}"; shift 2 ;;
    --vrid)     VRID="${2:-}"; shift 2 ;;
    --priority) PRIORITY="${2:-}"; shift 2 ;;
    -h|--help)  usage 0 ;;
    *) echo "Unknown argument: $1" >&2; usage 1 ;;
  esac
done

case "$ROLE" in
  primary|secondary) ;;
  *) die "--role must be 'primary' or 'secondary'";;
esac
[ -n "$SELF" ] || die "--self <ip> is required (THIS box's own static LAN IP)"
[ -n "$PEER" ] || die "--peer <ip> is required (the OTHER box's static LAN IP)"
[ -n "$IFACE" ] || die "--iface <nic> is required (the voice-VLAN NIC, e.g. eth0)"
[ -n "$HOST" ] || die "--host must be non-empty (the mDNS name, e.g. upes-ecs.local)"

# Resolve paths relative to THIS script, so it works from any cwd.
HERE="$(cd "$(dirname "$0")" && pwd)"
INSTALL="$HERE/../install-jetson.sh"
ENABLE="$HERE/enable-mdns-failover.sh"
[ -x "$INSTALL" ] || [ -f "$INSTALL" ] || die "cannot find install-jetson.sh at $INSTALL"
[ -f "$ENABLE" ] || die "cannot find enable-mdns-failover.sh at $ENABLE"

# Optional passthroughs (only add the flag if the caller set it).
opt=()
[ -n "$VRID" ]     && opt+=(--vrid "$VRID")
[ -n "$PRIORITY" ] && opt+=(--priority "$PRIORITY")

echo ">> Step 1/2: install full PBX stack on this $ROLE node (self=$SELF, peer=$PEER, iface=$IFACE)"
# install-jetson.sh wants a --vip; in mDNS mode each node simply advertises its
# OWN ip, so we hand it --self. enable-mdns-failover.sh (step 2) then strips the
# VIP logic and swaps in the no-VIP heartbeat config.
bash "$INSTALL" --role "$ROLE" --vip "$SELF" --peer "$PEER" --iface "$IFACE" "${opt[@]}"

echo ">> Step 2/2: convert this node to mDNS name-failover (no VIP), name=$HOST"
bash "$ENABLE" --role "$ROLE" --iface "$IFACE" --host "$HOST" --peer "$PEER" "${opt[@]}"

echo
echo "OK: this $ROLE node is up. It advertises $HOST -> $SELF when it is the live node."
echo "    Do the same on the other box, then point phones at $HOST (short SIP expiry ~60s)."
echo "    Failover test: 'sudo systemctl stop asterisk' here -> other box takes over $HOST -> dial 111."
