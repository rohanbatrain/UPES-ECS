#!/usr/bin/env bash
# Set up UPES-ECS Asterisk natively in WSL2 Ubuntu (real SIP/RTP on localhost),
# reusing the repo's real config + scripts. Run as root inside WSL:
#   wsl -d Ubuntu-22.04 -u root -- bash /mnt/c/Users/Rohan/UPES/deploy/wsl-setup.sh
set -e
REPO=/mnt/c/Users/Rohan/UPES
export DEBIAN_FRONTEND=noninteractive

echo "== installing asterisk + softphone (baresip) + sounds =="
apt-get update -y -qq
apt-get install -y -qq asterisk asterisk-core-sounds-en-gsm baresip >/dev/null

echo "== helper scripts -> /opt/upes-ecs =="
mkdir -p /opt/upes-ecs \
         /var/lib/upes-ecs/incidents /var/lib/upes-ecs/alerts \
         /var/lib/upes-ecs/security /var/lib/upes-ecs/paging \
         /var/lib/upes-ecs/conference /var/lib/upes-ecs/retention \
         /var/spool/asterisk/monitor/upes-ecs
cp "$REPO"/scripts/*.sh /opt/upes-ecs/
sed -i 's/\r$//' /opt/upes-ecs/*.sh
chmod +x /opt/upes-ecs/*.sh

echo "== asterisk config (real extensions_custom.conf + validation configs) =="
cp "$REPO"/config/extensions_custom.conf /etc/asterisk/
cp "$REPO"/deploy/asterisk/extensions.conf /etc/asterisk/
cp "$REPO"/deploy/asterisk/pjsip.conf /etc/asterisk/
cp "$REPO"/deploy/asterisk/queues.conf /etc/asterisk/
cp "$REPO"/deploy/asterisk/voicemail.conf /etc/asterisk/
sed -i 's/\r$//' /etc/asterisk/extensions_custom.conf /etc/asterisk/extensions.conf \
                 /etc/asterisk/pjsip.conf /etc/asterisk/queues.conf /etc/asterisk/voicemail.conf

# SHELL() for incident IDs
grep -q live_dangerously /etc/asterisk/asterisk.conf || \
  printf '\n[options]\nlive_dangerously = yes\n' >> /etc/asterisk/asterisk.conf

echo "== placeholder prompts =="
PD=/usr/share/asterisk/sounds/en/upes-ecs; mkdir -p "$PD"
SRC=$(ls /usr/share/asterisk/sounds/en/*.gsm 2>/dev/null | head -1)
for p in emergency-preanswer emergency-voicemail-prompt drill-prompt queue-paused queue-resumed not-authorized queue-hold; do
  [ -n "$SRC" ] && cp -f "$SRC" "$PD/$p.gsm"
done
chown -R asterisk:asterisk /var/lib/upes-ecs /var/spool/asterisk/monitor/upes-ecs "$PD" 2>/dev/null || true

echo "== (re)start asterisk =="
pkill -x asterisk 2>/dev/null || true
sleep 2
asterisk -g >/dev/null 2>&1 || true
sleep 4
asterisk -rx "core show uptime" | head -1
asterisk -rx "dialplan show ctx_emergency_111" | head -3
echo "WSL-SETUP-DONE"
