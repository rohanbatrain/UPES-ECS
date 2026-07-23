#!/usr/bin/env bash
#
# install-jetson.sh -- native UPES-ECS install for an NVIDIA Jetson Nano
# (ARM64 Ubuntu 20.04/22.04) as one node of a two-node active/standby HA cluster.
#
# Unlike the QEMU/Windows path, Asterisk runs NATIVELY here (no emulation), and
# a keepalived-managed floating Virtual IP (VIP) provides high availability: the
# MASTER owns the VIP that phones register to; if it fails, the BACKUP takes the
# VIP (gratuitous ARP) and phones re-register. Both nodes advertise the VIP as
# external_media_address so media follows the VIP.
#
# This reuses the proven logic of deploy/qemu/seed/setup-in-vm.sh but reads all
# config STRAIGHT FROM THE REPO CHECKOUT (not the cloud-init /mnt/upesdata mount).
#
# NOTE: written from standard, proven patterns. It is idempotent and lint-clean,
# but has NOT been run on real Jetson hardware -- validate on a real board with
# the customer's Junos versions before going live.
#
# Usage:
#   sudo ./install-jetson.sh --role primary   --vip 10.20.30.1 --peer 10.20.30.12 \
#        [--iface eth0] [--priority 150] [--vrid 51]
#   sudo ./install-jetson.sh --role secondary --vip 10.20.30.1 --peer 10.20.30.11 \
#        [--iface eth0] [--priority 100] [--vrid 51]
#
set -euo pipefail

#--------------------------------------------------------------------------------
# 0. Args + repo location
#--------------------------------------------------------------------------------
ROLE=""
VIP=""
PEER=""
IFACE="eth0"
PRIORITY=""
VRID="51"

usage() {
  sed -n '2,30p' "$0"
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --role)     ROLE="${2:-}"; shift 2 ;;
    --vip)      VIP="${2:-}"; shift 2 ;;
    --peer)     PEER="${2:-}"; shift 2 ;;
    --iface)    IFACE="${2:-}"; shift 2 ;;
    --priority) PRIORITY="${2:-}"; shift 2 ;;
    --vrid)     VRID="${2:-}"; shift 2 ;;
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
[ -n "$VIP" ]  || die "--vip <ip> is required (the floating IP phones register to)"
[ -n "$PEER" ] || die "--peer <ip> is required (the OTHER node's static IP)"

# Default VRRP priority by role if not overridden (higher wins -> MASTER).
if [ -z "$PRIORITY" ]; then
  if [ "$ROLE" = "primary" ]; then PRIORITY="150"; else PRIORITY="100"; fi
fi

# This script lives at <repo>/deploy/jetson/install-jetson.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ASTSRC="$REPO_ROOT/deploy/asterisk"
[ -d "$ASTSRC" ]        || die "cannot find $ASTSRC -- run from inside the repo checkout"
[ -d "$REPO_ROOT/api" ] || die "cannot find $REPO_ROOT/api -- repo layout unexpected"

echo "==================================================================="
echo " UPES-ECS Jetson install"
echo "   role=$ROLE  vip=$VIP  peer=$PEER  iface=$IFACE  priority=$PRIORITY  vrid=$VRID"
echo "   repo=$REPO_ROOT"
echo "==================================================================="

#--------------------------------------------------------------------------------
# 1. Packages (native ARM64 -- no QEMU)
#--------------------------------------------------------------------------------
echo "== apt packages =="
export DEBIAN_FRONTEND=noninteractive
apt-get update -y >/dev/null 2>&1 || echo "  (apt update failed/offline -- continuing with what's installed)"
# asterisk + tools; keepalived (VRRP/VIP); rsync (config sync); fail2ban; python3.
apt-get install -y \
  asterisk sox libsox-fmt-all \
  python3 python3-pip \
  keepalived rsync fail2ban \
  curl iproute2 openssh-client \
  >/dev/null 2>&1 || echo "  (some apt installs failed/offline -- verify manually below)"

#--------------------------------------------------------------------------------
# 2. Dirs + helper scripts (from repo scripts/)  -- mirrors setup-in-vm.sh
#--------------------------------------------------------------------------------
echo "== dirs + helper scripts =="
mkdir -p /opt/upes-ecs \
         /opt/upes-ecs/api /opt/upes-ecs/groups /opt/upes-ecs/family /opt/upes-ecs/ha \
         /var/lib/upes-ecs/incidents /var/lib/upes-ecs/alerts \
         /var/lib/upes-ecs/security /var/lib/upes-ecs/paging \
         /var/lib/upes-ecs/conference /var/lib/upes-ecs/retention \
         /var/lib/upes-ecs/rollcall /var/lib/upes-ecs/shift \
         /var/lib/upes-ecs/safety /var/lib/upes-ecs/location \
         /var/spool/asterisk/monitor/upes-ecs

if compgen -G "$REPO_ROOT/scripts/*.sh" >/dev/null; then
  cp "$REPO_ROOT"/scripts/*.sh /opt/upes-ecs/
  sed -i 's/\r$//' /opt/upes-ecs/*.sh
  chmod +x /opt/upes-ecs/*.sh
else
  echo "  (no scripts/*.sh found in repo -- skipping helper copy)"
fi

# HA helper scripts (this deploy dir) -> /opt/upes-ecs/ha
for f in chk-asterisk.sh upes-failover-notify.sh upes-ha-sync.sh; do
  cp "$SCRIPT_DIR/$f" /opt/upes-ecs/ha/
  sed -i 's/\r$//' "/opt/upes-ecs/ha/$f"
  chmod +x "/opt/upes-ecs/ha/$f"
done

#--------------------------------------------------------------------------------
# 3. Asterisk config from the repo checkout  -- mirrors setup-in-vm.sh copy set
#--------------------------------------------------------------------------------
echo "== asterisk config =="
# The repo splits dialplan across deploy/asterisk/*.conf AND config/*.conf.
for f in extensions.conf pjsip.conf pjsip_accounts.conf queues.conf voicemail.conf \
         rtp.conf confbridge.conf http.conf fail2ban-asterisk.conf; do
  if [ -f "$ASTSRC/$f" ]; then
    cp "$ASTSRC/$f" /etc/asterisk/
    sed -i 's/\r$//' "/etc/asterisk/$f"
  elif [ "$f" = "pjsip_accounts.conf" ]; then
    echo "  !! CRITICAL: $f missing -- accounts will NOT be provisioned"
  else
    echo "  (optional $f not present, skipped)"
  fi
done
# Extra dialplan includes live under config/ in this repo.
for f in extensions_custom.conf extensions_features.conf extensions_features_wiring.conf extensions_aihelpline.conf; do
  if [ -f "$REPO_ROOT/config/$f" ]; then
    cp "$REPO_ROOT/config/$f" /etc/asterisk/
    sed -i 's/\r$//' "/etc/asterisk/$f"
  fi
done

# live_dangerously: needed by the emergency dialplan's System()/privileged apps.
if [ -f /etc/asterisk/asterisk.conf ]; then
  grep -q live_dangerously /etc/asterisk/asterisk.conf || \
    printf '\n[options]\nlive_dangerously = yes\n' >> /etc/asterisk/asterisk.conf
fi

# All-campus paging PIN: replace placeholder with a random one (idempotent).
if [ -f /etc/asterisk/extensions_custom.conf ] && \
   grep -q '^PAGING_PIN_700=CHANGE-ME' /etc/asterisk/extensions_custom.conf; then
  PIN="$(shuf -i 100000-999999 -n1)"
  sed -i "s/^PAGING_PIN_700=.*/PAGING_PIN_700=${PIN}   ; generated at install - record in secrets/" \
    /etc/asterisk/extensions_custom.conf
  echo "PAGING_PIN_700=${PIN}" > /var/lib/upes-ecs/generated-secrets.txt
  echo "  generated paging PIN -> /var/lib/upes-ecs/generated-secrets.txt"
fi

#--------------------------------------------------------------------------------
# 4. HA: advertise the VIP as the media/signaling address  (native, no NAT)
#--------------------------------------------------------------------------------
echo "== external_media_address = VIP ($VIP) =="
# The repo pjsip.conf ships these two lines commented under [transport-udp]. Both
# nodes must advertise the floating VIP so media/contacts follow it on failover.
if grep -qE '^;?external_media_address=' /etc/asterisk/pjsip.conf; then
  sed -i -E "s|^;?external_media_address=.*|external_media_address=${VIP}|"      /etc/asterisk/pjsip.conf
else
  # Insert right after the udp transport's bind line.
  sed -i -E "/^\[transport-udp\]/,/^\[/ s|^(bind=.*)$|\1\nexternal_media_address=${VIP}|" /etc/asterisk/pjsip.conf
fi
if grep -qE '^;?external_signaling_address=' /etc/asterisk/pjsip.conf; then
  sed -i -E "s|^;?external_signaling_address=.*|external_signaling_address=${VIP}|" /etc/asterisk/pjsip.conf
else
  sed -i -E "/^\[transport-udp\]/,/^\[/ s|^(external_media_address=.*)$|\1\nexternal_signaling_address=${VIP}|" /etc/asterisk/pjsip.conf
fi

#--------------------------------------------------------------------------------
# 5. Voice prompts: copy the PRE-GENERATED language packs from the repo
#--------------------------------------------------------------------------------
echo "== voice prompts (pre-generated sounds) =="
# Asterisk resolves Playback(upes-ecs/x) against sounds/<channel-lang>/upes-ecs/x
# and falls back to sounds/en/upes-ecs/x. So the repo layout maps as:
#     deploy/asterisk/sounds/en/...        -> /usr/share/asterisk/sounds/en/...
#     deploy/asterisk/sounds/lang/<code>/  -> /usr/share/asterisk/sounds/<code>/
SND_DST="/usr/share/asterisk/sounds"
mkdir -p "$SND_DST"
if [ -d "$ASTSRC/sounds/en" ]; then
  mkdir -p "$SND_DST/en"
  cp -a "$ASTSRC/sounds/en/." "$SND_DST/en/"
fi
if [ -d "$ASTSRC/sounds/lang" ]; then
  for langdir in "$ASTSRC"/sounds/lang/*/; do
    [ -d "$langdir" ] || continue
    code="$(basename "$langdir")"
    mkdir -p "$SND_DST/$code"
    cp -a "${langdir}." "$SND_DST/$code/"
  done
fi

# Fallback: if the en/upes-ecs prompts are missing, keep the QEMU behaviour of
# seeding placeholders + generating coach prompts (never leave a silent PBX).
PD="$SND_DST/en/upes-ecs"; mkdir -p "$PD"
if ! compgen -G "$PD/*.wav" >/dev/null && ! compgen -G "$PD/*.gsm" >/dev/null; then
  echo "  (no en/upes-ecs prompts found -- seeding placeholders as fallback)"
  SRCG=""
  for g in "$SND_DST"/en/*.gsm; do [ -e "$g" ] && { SRCG="$g"; break; }; done
  for p in emergency-preanswer emergency-voicemail-prompt drill-prompt queue-paused \
           queue-resumed not-authorized queue-hold; do
    [ -n "$SRCG" ] && cp -f "$SRCG" "$PD/$p.gsm"
  done
fi
# gen-coach-prompts.sh kept available as a fallback generator (needs pico2wave/sox).
if [ -x /opt/upes-ecs/gen-coach-prompts.sh ]; then
  /opt/upes-ecs/gen-coach-prompts.sh >/dev/null 2>&1 || echo "  (coach prompt gen skipped -- prompts already packed)"
fi
chown -R asterisk:asterisk /var/lib/upes-ecs /var/spool/asterisk/monitor/upes-ecs "$SND_DST" 2>/dev/null || true

#--------------------------------------------------------------------------------
# 6. callout / roll-call groups  -- mirrors setup-in-vm.sh
#--------------------------------------------------------------------------------
echo "== callout / roll-call groups =="
GR=/opt/upes-ecs/groups
if [ ! -f "$GR/all.csv" ]; then
  printf '500120597\n500000002\n500000003\n500000004\n' > "$GR/roster.csv"
  printf '500120597\n500000002\n500000003\n500000004\n40000001\n40000002\n40000003\n4101\n4110\n4111\n4112\n4113\n4120\n4200\n4300\n4400\n4500\n4600\n' > "$GR/all.csv"
  printf '4101\n4110\n4111\n4112\n4113\n4120\n' > "$GR/ert.csv"
  printf '4200\n4300\n4400\n4500\n4600\n' > "$GR/responders.csv"
  cp "$GR/roster.csv" "$GR/hostels.csv"
  cp "$GR/roster.csv" "$GR/academic.csv"
  cp "$GR/all.csv"    "$GR/700.csv"
  cp "$GR/roster.csv" "$GR/701.csv"
  cp "$GR/roster.csv" "$GR/702.csv"
  printf '4300\n' > "$GR/703.csv"
  printf '4200\n4110\n4111\n' > "$GR/704.csv"
  printf '4500\n' > "$GR/705.csv"
else
  echo "  (groups already present -- leaving in place)"
fi
chown -R asterisk:asterisk "$GR"

#--------------------------------------------------------------------------------
# 7. Local status/control API (FastAPI on 127.0.0.1:8090)
#--------------------------------------------------------------------------------
echo "== local status API (FastAPI :8090) =="
pip3 install --quiet fastapi 'uvicorn[standard]' >/dev/null 2>&1 || \
  echo "  (fastapi/uvicorn install skipped/offline -- may already be present)"
cp "$REPO_ROOT/api/upes_api.py" /opt/upes-ecs/api/upes_api.py
sed -i 's/\r$//' /opt/upes-ecs/api/upes_api.py
cp "$REPO_ROOT/api/upes-api.service" /etc/systemd/system/upes-api.service
sed -i 's/\r$//' /etc/systemd/system/upes-api.service
# directory.json feeds the API's family/safety directory.
[ -f "$REPO_ROOT/Console/directory.json" ] && \
  cp "$REPO_ROOT/Console/directory.json" /opt/upes-ecs/family/directory.json

#--------------------------------------------------------------------------------
# 8. Console (Linux static server + /api proxy on :8080)  -- replaces Serve.ps1
#--------------------------------------------------------------------------------
echo "== Console web server (:8080) =="
CONSOLE_DST=/opt/upes-ecs/console
mkdir -p "$CONSOLE_DST"
# Copy the whole Console front-end (html/js/css/json + ui-lang). Runtime data
# (region.json/directory.json/ui-lang) is refreshed on the secondary by the HA sync.
if [ -d "$REPO_ROOT/Console" ]; then
  # Copy files the dashboard actually serves; skip PowerShell + logs/recordings.
  for item in index.html app.js app.css tv.js tv.css tv-ops.html tv-safety.html \
              ui-i18n.js region.json directory.json languages.json status.json; do
    [ -f "$REPO_ROOT/Console/$item" ] && cp "$REPO_ROOT/Console/$item" "$CONSOLE_DST/"
  done
  [ -d "$REPO_ROOT/Console/ui-lang" ] && { mkdir -p "$CONSOLE_DST/ui-lang"; cp -a "$REPO_ROOT/Console/ui-lang/." "$CONSOLE_DST/ui-lang/"; }
fi
cp "$SCRIPT_DIR/serve-console.py" /opt/upes-ecs/ha/serve-console.py
sed -i 's/\r$//' /opt/upes-ecs/ha/serve-console.py
chmod +x /opt/upes-ecs/ha/serve-console.py
cp "$SCRIPT_DIR/serve-console.service" /etc/systemd/system/serve-console.service
sed -i 's/\r$//' /etc/systemd/system/serve-console.service

#--------------------------------------------------------------------------------
# 9. keepalived (VRRP / floating VIP) for this role
#--------------------------------------------------------------------------------
echo "== keepalived (VRRP VIP $VIP, state $( [ "$ROLE" = primary ] && echo MASTER || echo BACKUP )) =="
STATE="BACKUP"; [ "$ROLE" = "primary" ] && STATE="MASTER"
# A shared VRRP password. CHANGE-ME in production; both nodes MUST match.
VRRP_PASS="upesecs1"
mkdir -p /etc/keepalived
# Render the template -> /etc/keepalived/keepalived.conf
sed -e "s|@STATE@|${STATE}|g" \
    -e "s|@IFACE@|${IFACE}|g" \
    -e "s|@VRID@|${VRID}|g" \
    -e "s|@PRIORITY@|${PRIORITY}|g" \
    -e "s|@VRRP_PASS@|${VRRP_PASS}|g" \
    -e "s|@VIP@|${VIP}|g" \
    "$SCRIPT_DIR/keepalived.conf.tmpl" > /etc/keepalived/keepalived.conf
sed -i 's/\r$//' /etc/keepalived/keepalived.conf

#--------------------------------------------------------------------------------
# 10. HA config-sync service + timer (primary pushes to secondary)
#--------------------------------------------------------------------------------
echo "== HA config sync (rsync primary -> secondary) =="
cp "$SCRIPT_DIR/upes-ha-sync.service" /etc/systemd/system/upes-ha-sync.service
cp "$SCRIPT_DIR/upes-ha-sync.timer"   /etc/systemd/system/upes-ha-sync.timer
sed -i 's/\r$//' /etc/systemd/system/upes-ha-sync.service /etc/systemd/system/upes-ha-sync.timer
# The sync PUSHes from primary to the peer. Persist role+peer for the sync unit.
cat > /opt/upes-ecs/ha/ha.env <<EOF
# Written by install-jetson.sh -- consumed by upes-ha-sync.sh
UPES_ROLE=${ROLE}
UPES_PEER=${PEER}
UPES_VIP=${VIP}
# SSH user + key used to push config to the peer (see README key-exchange step).
UPES_SSH_USER=ubuntu
UPES_SSH_KEY=/root/.ssh/upes_ha
EOF

#--------------------------------------------------------------------------------
# 11. fail2ban (SIP + SSH brute-force)  -- mirrors setup-in-vm.sh
#--------------------------------------------------------------------------------
echo "== fail2ban =="
if [ -f "$ASTSRC/fail2ban-asterisk.conf" ]; then
  cp "$ASTSRC/fail2ban-asterisk.conf" /etc/fail2ban/jail.d/upes-asterisk.local
  sed -i 's/\r$//' /etc/fail2ban/jail.d/upes-asterisk.local
fi

#--------------------------------------------------------------------------------
# 12. asterisk crash auto-recovery  -- mirrors setup-in-vm.sh
#--------------------------------------------------------------------------------
echo "== asterisk auto-restart =="
mkdir -p /etc/systemd/system/asterisk.service.d
printf '[Service]\nRestart=always\nRestartSec=3\n' > /etc/systemd/system/asterisk.service.d/restart.conf

#--------------------------------------------------------------------------------
# 13. Enable + start everything
#--------------------------------------------------------------------------------
echo "== enable + start services =="
systemctl daemon-reload
systemctl enable asterisk       >/dev/null 2>&1 || true
systemctl enable upes-api       >/dev/null 2>&1 || true
systemctl enable serve-console  >/dev/null 2>&1 || true
systemctl enable fail2ban       >/dev/null 2>&1 || true
systemctl enable keepalived     >/dev/null 2>&1 || true

systemctl restart asterisk      >/dev/null 2>&1 || { asterisk -g 2>/dev/null || true; }
systemctl restart upes-api      >/dev/null 2>&1 || true
systemctl restart serve-console >/dev/null 2>&1 || true
systemctl restart fail2ban      >/dev/null 2>&1 || true
systemctl restart keepalived    >/dev/null 2>&1 || true

# The config-sync timer runs on the PRIMARY only (it PUSHes to the secondary).
if [ "$ROLE" = "primary" ]; then
  systemctl enable  upes-ha-sync.timer >/dev/null 2>&1 || true
  systemctl restart upes-ha-sync.timer >/dev/null 2>&1 || true
else
  systemctl disable upes-ha-sync.timer >/dev/null 2>&1 || true
  systemctl stop    upes-ha-sync.timer >/dev/null 2>&1 || true
fi

sleep 4
echo "-------------------------------------------------------------------"
asterisk -rx "core show uptime" 2>/dev/null | head -1 || echo "  (asterisk not responding yet -- check: journalctl -u asterisk -e)"
echo "  VIP status on $IFACE:"
ip -4 addr show dev "$IFACE" 2>/dev/null | grep -w "$VIP" >/dev/null 2>&1 \
  && echo "    VIP $VIP is HELD by this node ($STATE)" \
  || echo "    VIP $VIP not held here (expected on BACKUP, or before keepalived converges)"
echo "  Console:  http://${VIP}:8080   (this node: http://$(hostname -I 2>/dev/null | awk '{print $1}'):8080)"
echo "  API:      http://127.0.0.1:8090/health"
echo "UPES-ECS-JETSON-SETUP-DONE ($ROLE)"
