#!/usr/bin/env bash
# deploy-standalone.sh -- SINGLE-NODE (no-HA) UPES-ECS install for a Jetson / bare-metal
# ARM64 (or any) Linux box. Run as root FROM INSIDE THE REPO CHECKOUT:
#     sudo bash deploy/jetson/deploy-standalone.sh
#
# Differs from install-jetson.sh (which is HA/keepalived-oriented):
#   - no --vip/--peer, no keepalived, no ha-sync  (single node)
#   - external_media_address = this box's own primary IP
#   - the FastAPI runs under a python3.8 venv  (stock JetPack 4.x python is 3.6, too old
#     for modern FastAPI/uvicorn; serve-console.py is stdlib and runs on 3.6 either way)
#
# NOTE: this does NOT enable live_dangerously (required by the dialplan's System() incident-
# logging/alert/callout). Enable it deliberately as a separate, reviewed step:
#     sudo sed -i 's/^;live_dangerously = no.*/live_dangerously = yes/' /etc/asterisk/asterisk.conf
#     sudo systemctl restart asterisk
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
IP="$(hostname -I | awk '{print $1}')"
AST="$REPO/deploy/asterisk"
[ "$(id -u)" -eq 0 ] || { echo "run as root (sudo)"; exit 1; }
[ -d "$AST" ] || { echo "ERROR: $AST missing -- run from inside the repo checkout"; exit 1; }
echo "== UPES-ECS standalone deploy  repo=$REPO  node IP=$IP =="

echo "== 1. packages (idempotent) =="
export DEBIAN_FRONTEND=noninteractive
apt-get install -y asterisk asterisk-modules sox libsox-fmt-all \
  python3.8 python3.8-venv python3.8-dev curl ca-certificates fail2ban >/dev/null 2>&1 \
  || echo "  (some apt installs failed/offline -- verify below)"

echo "== 2. dirs + helper scripts =="
mkdir -p /opt/upes-ecs/api /opt/upes-ecs/console /opt/upes-ecs/ha /opt/upes-ecs/groups /opt/upes-ecs/family \
         /var/lib/upes-ecs/{incidents,alerts,security,paging,conference,retention,rollcall,shift,safety,location} \
         /var/spool/asterisk/monitor/upes-ecs
if compgen -G "$REPO/scripts/*.sh" >/dev/null; then
  cp "$REPO"/scripts/*.sh /opt/upes-ecs/ 2>/dev/null || true
  sed -i 's/\r$//' /opt/upes-ecs/*.sh 2>/dev/null || true
  chmod +x /opt/upes-ecs/*.sh 2>/dev/null || true
fi

echo "== 3. asterisk config =="
for f in extensions.conf pjsip.conf pjsip_accounts.conf queues.conf voicemail.conf rtp.conf confbridge.conf http.conf fail2ban-asterisk.conf; do
  [ -f "$AST/$f" ] && { cp "$AST/$f" /etc/asterisk/; sed -i 's/\r$//' "/etc/asterisk/$f"; }
done
for f in extensions_custom.conf extensions_features.conf extensions_features_wiring.conf extensions_aihelpline.conf; do
  [ -f "$REPO/config/$f" ] && { cp "$REPO/config/$f" /etc/asterisk/; sed -i 's/\r$//' "/etc/asterisk/$f"; }
done

echo "== 4. external_media_address = $IP =="
if grep -qE '^;?external_media_address=' /etc/asterisk/pjsip.conf; then
  sed -i -E "s|^;?external_media_address=.*|external_media_address=${IP}|" /etc/asterisk/pjsip.conf
else
  sed -i -E "/^\[transport-udp\]/,/^\[/ s|^(bind=.*)$|\1\nexternal_media_address=${IP}|" /etc/asterisk/pjsip.conf
fi
if grep -qE '^;?external_signaling_address=' /etc/asterisk/pjsip.conf; then
  sed -i -E "s|^;?external_signaling_address=.*|external_signaling_address=${IP}|" /etc/asterisk/pjsip.conf
else
  sed -i -E "/^\[transport-udp\]/,/^\[/ s|^(external_media_address=.*)$|\1\nexternal_signaling_address=${IP}|" /etc/asterisk/pjsip.conf
fi
if [ -f /etc/asterisk/extensions_custom.conf ] && grep -q '^PAGING_PIN_700=CHANGE-ME' /etc/asterisk/extensions_custom.conf; then
  PIN="$(shuf -i 100000-999999 -n1)"; sed -i "s/^PAGING_PIN_700=.*/PAGING_PIN_700=${PIN}/" /etc/asterisk/extensions_custom.conf
  echo "PAGING_PIN_700=${PIN}" > /var/lib/upes-ecs/generated-secrets.txt
fi

echo "== 5. voice prompts (en + any lang packs present) =="
SND=/usr/share/asterisk/sounds; mkdir -p "$SND"
[ -d "$AST/sounds/en" ] && { mkdir -p "$SND/en"; cp -a "$AST/sounds/en/." "$SND/en/"; }
if [ -d "$AST/sounds/lang" ]; then for d in "$AST"/sounds/lang/*/; do [ -d "$d" ] || continue; c="$(basename "$d")"; mkdir -p "$SND/$c"; cp -a "${d}." "$SND/$c/"; done; fi

echo "== 6. groups =="
GR=/opt/upes-ecs/groups
if [ ! -f "$GR/all.csv" ]; then
  printf '500120597\n500120596\n500119503\n500119499\n' > "$GR/roster.csv"
  printf '500120597\n500120596\n500119503\n500119499\n40001097\n40003657\n40004432\n4101\n4110\n4111\n4112\n4113\n4120\n4200\n4300\n4400\n4500\n4600\n' > "$GR/all.csv"
  printf '4101\n4110\n4111\n4112\n4113\n4120\n' > "$GR/ert.csv"
  printf '4200\n4300\n4400\n4500\n4600\n' > "$GR/responders.csv"
  cp "$GR/roster.csv" "$GR/hostels.csv"; cp "$GR/roster.csv" "$GR/academic.csv"; cp "$GR/all.csv" "$GR/700.csv"
  cp "$GR/roster.csv" "$GR/701.csv"; cp "$GR/roster.csv" "$GR/702.csv"
  printf '4300\n' > "$GR/703.csv"; printf '4200\n4110\n4111\n' > "$GR/704.csv"; printf '4500\n' > "$GR/705.csv"
fi

echo "== 7. API: python3.8 venv + fastapi/uvicorn =="
cp "$REPO/api/upes_api.py" /opt/upes-ecs/api/upes_api.py; sed -i 's/\r$//' /opt/upes-ecs/api/upes_api.py
[ -f "$REPO/Console/directory.json" ] && cp "$REPO/Console/directory.json" /opt/upes-ecs/family/directory.json
[ -x /opt/upes-ecs/venv/bin/python ] || python3.8 -m venv /opt/upes-ecs/venv
/opt/upes-ecs/venv/bin/pip install --quiet --upgrade pip 2>&1 | tail -1
/opt/upes-ecs/venv/bin/pip install --quiet fastapi uvicorn 2>&1 | tail -2 \
  || /opt/upes-ecs/venv/bin/pip install --quiet "fastapi==0.99.1" "pydantic==1.10.13" "uvicorn==0.23.2" 2>&1 | tail -2
cat > /etc/systemd/system/upes-api.service <<EOF
[Unit]
Description=UPES-ECS Emergency PBX local status/control API (FastAPI on :8090)
After=network.target asterisk.service
Wants=asterisk.service
[Service]
Type=simple
User=root
ExecStart=/opt/upes-ecs/venv/bin/python /opt/upes-ecs/api/upes_api.py
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
EOF

echo "== 8. Console (:8080) =="
CON=/opt/upes-ecs/console
for item in index.html app.js app.css tv.js tv.css tv-ops.html tv-safety.html ui-i18n.js region.json directory.json languages.json status.json; do
  [ -f "$REPO/Console/$item" ] && cp "$REPO/Console/$item" "$CON/"
done
[ -d "$REPO/Console/ui-lang" ] && { mkdir -p "$CON/ui-lang"; cp -a "$REPO/Console/ui-lang/." "$CON/ui-lang/"; }
cp "$SCRIPT_DIR/serve-console.py" /opt/upes-ecs/ha/serve-console.py; sed -i 's/\r$//' /opt/upes-ecs/ha/serve-console.py; chmod +x /opt/upes-ecs/ha/serve-console.py
cp "$SCRIPT_DIR/serve-console.service" /etc/systemd/system/serve-console.service; sed -i 's/\r$//' /etc/systemd/system/serve-console.service

echo "== 9. fail2ban + asterisk auto-restart =="
[ -f "$AST/fail2ban-asterisk.conf" ] && cp "$AST/fail2ban-asterisk.conf" /etc/fail2ban/jail.d/upes-asterisk.local 2>/dev/null || true
mkdir -p /etc/systemd/system/asterisk.service.d; printf '[Service]\nRestart=always\nRestartSec=3\n' > /etc/systemd/system/asterisk.service.d/restart.conf
chown -R asterisk:asterisk /var/lib/upes-ecs /var/spool/asterisk/monitor/upes-ecs "$SND" /opt/upes-ecs/groups 2>/dev/null || true

echo "== 10. enable + start =="
systemctl daemon-reload
systemctl enable asterisk upes-api serve-console >/dev/null 2>&1 || true
systemctl restart asterisk; sleep 3
systemctl restart upes-api; sleep 3
systemctl restart serve-console; sleep 2

echo "== STATUS =="
for s in asterisk upes-api serve-console; do echo "  $s: $(systemctl is-active $s)"; done
echo "  $(grep '^external_media_address' /etc/asterisk/pjsip.conf | head -1)"
echo "DONE  console=http://$IP:8080  api=http://127.0.0.1:8090/health"
echo "REMINDER: enable live_dangerously (see header) to activate System() incident-logging/alerts/callouts."
