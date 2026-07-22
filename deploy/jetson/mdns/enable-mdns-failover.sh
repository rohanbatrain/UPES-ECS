#!/usr/bin/env bash
#
# enable-mdns-failover.sh -- turn a Jetson node into part of a NO-VIP, mDNS
# name-failover HA pair for UPES-ECS.
#
# This is the SIMPLER high-availability path (no floating Virtual IP, no Juniper
# VRRP on the router). keepalived still runs VRRP between the two boards for
# ELECTION + Asterisk HEALTH, but instead of moving a VIP it publishes/withdraws
# the mDNS name upes-ecs.local via Avahi:
#
#   * The MASTER publishes  upes-ecs.local -> its OWN interface IP.
#   * BACKUP/FAULT withdraw the name.
#   * Each node advertises its OWN IP as Asterisk external_media_address /
#     external_signaling_address (the NAME resolves to whichever node is active).
#   * Phones set SIP server = upes-ecs.local ONCE and, with a short registration
#     expiry (~60s), re-resolve + re-register to the new MASTER on failover.
#
# Run this on EACH node AFTER install-jetson.sh (or standalone -- it copies the
# shared chk-asterisk.sh from the VIP kit if the installer did not).
#
# NOTE: written from standard, proven patterns (Avahi + keepalived VRRP on ARM64
# Ubuntu). It is idempotent and lint-clean, but has NOT been run on real Jetson
# hardware -- validate on two real boards before go-live.
#
# Usage:
#   sudo ./enable-mdns-failover.sh --role primary   --iface eth0 \
#        [--vrid 51] [--priority 150] [--peer 10.20.30.12] [--host upes-ecs.local]
#   sudo ./enable-mdns-failover.sh --role secondary --iface eth0 \
#        [--vrid 51] [--priority 100] [--peer 10.20.30.11] [--host upes-ecs.local]
#
set -euo pipefail

#--------------------------------------------------------------------------------
# 0. Args
#--------------------------------------------------------------------------------
ROLE=""
IFACE="eth0"
VRID="51"
PRIORITY=""
PEER=""
HOST="upes-ecs.local"

usage() {
  sed -n '2,34p' "$0"
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --role)     ROLE="${2:-}"; shift 2 ;;
    --iface)    IFACE="${2:-}"; shift 2 ;;
    --vrid)     VRID="${2:-}"; shift 2 ;;
    --priority) PRIORITY="${2:-}"; shift 2 ;;
    --peer)     PEER="${2:-}"; shift 2 ;;
    --host)     HOST="${2:-}"; shift 2 ;;
    -h|--help)  usage 0 ;;
    *) echo "Unknown argument: $1" >&2; usage 1 ;;
  esac
done

die() { echo "ERROR: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run as root (sudo)."
case "$ROLE" in
  primary|secondary) ;;
  *) die "--role must be 'primary' or 'secondary'";;
esac
[ -n "$IFACE" ] || die "--iface <nic> is required (the voice-VLAN NIC, e.g. eth0)"
[ -n "$HOST" ]  || die "--host must be non-empty (the mDNS name, e.g. upes-ecs.local)"

# Default VRRP priority by role if not overridden (higher wins -> MASTER).
if [ -z "$PRIORITY" ]; then
  if [ "$ROLE" = "primary" ]; then PRIORITY="150"; else PRIORITY="100"; fi
fi
STATE="BACKUP"; [ "$ROLE" = "primary" ] && STATE="MASTER"

# This script lives at <repo>/deploy/jetson/mdns/enable-mdns-failover.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JETSON_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"     # the VIP kit (source of chk-asterisk.sh)

echo "==================================================================="
echo " UPES-ECS mDNS name-failover enable (NO VIP)"
echo "   role=$ROLE  state=$STATE  iface=$IFACE  vrid=$VRID  priority=$PRIORITY"
echo "   host=$HOST  peer=${PEER:-<none>}"
echo "==================================================================="

#--------------------------------------------------------------------------------
# 1. Packages: Avahi (mDNS responder + avahi-publish) and keepalived
#--------------------------------------------------------------------------------
echo "== apt packages (avahi-daemon avahi-utils keepalived) =="
export DEBIAN_FRONTEND=noninteractive
apt-get update -y >/dev/null 2>&1 || echo "  (apt update failed/offline -- continuing with what's installed)"
apt-get install -y avahi-daemon avahi-utils keepalived >/dev/null 2>&1 \
  || echo "  (some apt installs failed/offline -- verify avahi-daemon/avahi-utils/keepalived manually)"

# Avahi must be running for avahi-publish to work; enable it at boot.
systemctl enable avahi-daemon  >/dev/null 2>&1 || true
systemctl restart avahi-daemon >/dev/null 2>&1 || true

#--------------------------------------------------------------------------------
# 2. Asterisk external address = THIS node's own iface IP (name resolves to active)
#--------------------------------------------------------------------------------
echo "== external_media_address = this node's IP on $IFACE =="
NODE_IP="$(ip -4 -o addr show dev "$IFACE" scope global 2>/dev/null \
             | awk '{print $4}' | cut -d/ -f1 | head -n1)"
[ -n "$NODE_IP" ] || die "no global IPv4 found on '$IFACE' -- set a static IP first (see README-MDNS.md)"
echo "   this node IP = $NODE_IP"

PJSIP="/etc/asterisk/pjsip.conf"
if [ -f "$PJSIP" ]; then
  # external_media_address (uncomment+set, or insert after the udp bind line).
  if grep -qE '^;?external_media_address=' "$PJSIP"; then
    sed -i -E "s|^;?external_media_address=.*|external_media_address=${NODE_IP}|" "$PJSIP"
  else
    sed -i -E "/^\[transport-udp\]/,/^\[/ s|^(bind=.*)$|\1\nexternal_media_address=${NODE_IP}|" "$PJSIP"
  fi
  # external_signaling_address (uncomment+set, or insert after external_media_address).
  if grep -qE '^;?external_signaling_address=' "$PJSIP"; then
    sed -i -E "s|^;?external_signaling_address=.*|external_signaling_address=${NODE_IP}|" "$PJSIP"
  else
    sed -i -E "/^\[transport-udp\]/,/^\[/ s|^(external_media_address=.*)$|\1\nexternal_signaling_address=${NODE_IP}|" "$PJSIP"
  fi
  # Apply without a full restart (idempotent; safe no-op if asterisk is down).
  asterisk -rx "pjsip reload" >/dev/null 2>&1 || echo "  (pjsip reload skipped -- asterisk not running yet)"
else
  echo "  !! $PJSIP not found -- run install-jetson.sh first (or copy asterisk config)."
fi

#--------------------------------------------------------------------------------
# 3. Install the mDNS publisher + failover hook + service (idempotent)
#--------------------------------------------------------------------------------
echo "== install mDNS publisher / failover hook / service =="
mkdir -p /opt/upes-ecs /opt/upes-ecs/ha /var/lib/upes-ecs/ha

# Publisher + keepalived notify hook -> /opt/upes-ecs/
for f in upes-mdns-publish.sh upes-mdns-failover.sh; do
  cp "$SCRIPT_DIR/$f" "/opt/upes-ecs/$f"
  sed -i 's/\r$//' "/opt/upes-ecs/$f"
  chmod 0755 "/opt/upes-ecs/$f"
  chown root:root "/opt/upes-ecs/$f" 2>/dev/null || true
done

# systemd unit for the publisher (started by keepalived on MASTER; not enabled at boot).
cp "$SCRIPT_DIR/upes-mdns.service" /etc/systemd/system/upes-mdns.service
sed -i 's/\r$//' /etc/systemd/system/upes-mdns.service

# EnvironmentFile the service + publisher read (HOST/IFACE), so a DHCP change is
# handled by simply (re)starting the service -- the IP is re-read each start.
cat > /etc/default/upes-mdns <<EOF
# Written by enable-mdns-failover.sh -- consumed by upes-mdns-publish.sh / upes-mdns.service
UPES_MDNS_HOST=${HOST}
UPES_MDNS_IFACE=${IFACE}
EOF

# The keepalived template references /opt/upes-ecs/ha/chk-asterisk.sh. install-jetson.sh
# normally puts it there; if this is a standalone run, copy it from the VIP kit so the
# health check exists (SAME script, reused verbatim).
if [ ! -x /opt/upes-ecs/ha/chk-asterisk.sh ]; then
  if [ -f "$JETSON_DIR/chk-asterisk.sh" ]; then
    cp "$JETSON_DIR/chk-asterisk.sh" /opt/upes-ecs/ha/chk-asterisk.sh
    sed -i 's/\r$//' /opt/upes-ecs/ha/chk-asterisk.sh
    chmod 0755 /opt/upes-ecs/ha/chk-asterisk.sh
    chown root:root /opt/upes-ecs/ha/chk-asterisk.sh 2>/dev/null || true
    echo "  copied chk-asterisk.sh from the VIP kit -> /opt/upes-ecs/ha/"
  else
    echo "  !! chk-asterisk.sh not found (neither installed nor in $JETSON_DIR) --"
    echo "     keepalived's track_script will fail until it exists."
  fi
fi

#--------------------------------------------------------------------------------
# 4. keepalived config from the NO-VIP template (per role)
#--------------------------------------------------------------------------------
echo "== keepalived (VRRP election, state $STATE, NO VIP) =="
# Shared VRRP password. CHANGE-ME in production; both nodes MUST match.
VRRP_PASS="upesecs1"
mkdir -p /etc/keepalived
sed -e "s|@STATE@|${STATE}|g" \
    -e "s|@IFACE@|${IFACE}|g" \
    -e "s|@VRID@|${VRID}|g" \
    -e "s|@PRIORITY@|${PRIORITY}|g" \
    -e "s|@VRRP_PASS@|${VRRP_PASS}|g" \
    "$SCRIPT_DIR/keepalived-mdns.conf.tmpl" > /etc/keepalived/keepalived.conf
sed -i 's/\r$//' /etc/keepalived/keepalived.conf

#--------------------------------------------------------------------------------
# 5. Enable keepalived (restart); leave upes-mdns STOPPED (keepalived starts it)
#--------------------------------------------------------------------------------
echo "== enable + (re)start keepalived; leave upes-mdns for keepalived to start =="
systemctl daemon-reload
systemctl enable keepalived >/dev/null 2>&1 || true

# Make sure the publisher is NOT enabled at boot and is stopped now -- keepalived's
# notify hook starts it only on the elected MASTER.
systemctl disable upes-mdns >/dev/null 2>&1 || true
systemctl stop    upes-mdns >/dev/null 2>&1 || true

systemctl restart keepalived >/dev/null 2>&1 || echo "  (keepalived restart failed -- check: journalctl -u keepalived -e)"

sleep 3
echo "-------------------------------------------------------------------"
echo "  keepalived: $(systemctl is-active keepalived 2>/dev/null || echo unknown)  (state $STATE by config)"
echo "  upes-mdns : $(systemctl is-active upes-mdns 2>/dev/null || echo inactive)  (active only on MASTER)"
if command -v avahi-resolve >/dev/null 2>&1; then
  echo "  resolve   : $(avahi-resolve -4 -n "$HOST" 2>/dev/null || echo "(not resolvable yet -- expected until the MASTER publishes)")"
fi
echo "  This node advertises Asterisk external address = $NODE_IP"
echo "  Phones should use SIP server = $HOST  with a SHORT registration expiry (~60s)."
echo "UPES-ECS-MDNS-FAILOVER-DONE ($ROLE / $STATE)"
