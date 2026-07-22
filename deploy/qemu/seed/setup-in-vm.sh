#!/usr/bin/env bash
# UPES-ECS in-VM setup — runs at first boot via cloud-init. Installs the real
# emergency dialplan + helper scripts into the freshly-apt-installed Asterisk.
set -e
SRC=/mnt/upesdata

echo "== dirs + helper scripts =="
mkdir -p /opt/upes-ecs \
         /var/lib/upes-ecs/incidents /var/lib/upes-ecs/alerts \
         /var/lib/upes-ecs/security /var/lib/upes-ecs/paging \
         /var/lib/upes-ecs/conference /var/lib/upes-ecs/retention \
         /var/spool/asterisk/monitor/upes-ecs
cp "$SRC"/scripts/*.sh /opt/upes-ecs/
sed -i 's/\r$//' /opt/upes-ecs/*.sh
chmod +x /opt/upes-ecs/*.sh

echo "== asterisk config =="
for f in extensions_custom.conf extensions_features.conf extensions_features_wiring.conf extensions_aihelpline.conf extensions.conf pjsip.conf pjsip_accounts.conf queues.conf voicemail.conf rtp.conf confbridge.conf; do
  # Don't let one missing file abort the whole provision (set -e) and leave a half-built
  # emergency PBX. pjsip_accounts.conf missing = NO accounts, so make that failure LOUD.
  if [ -f "$SRC/asterisk/$f" ]; then
    cp "$SRC/asterisk/$f" /etc/asterisk/
    sed -i 's/\r$//' "/etc/asterisk/$f"
  elif [ "$f" = "pjsip_accounts.conf" ]; then
    echo "  !! CRITICAL: $f missing from payload — accounts will NOT be provisioned (fix Deploy/build copy list)"
  else
    echo "  (optional $f not in payload, skipped)"
  fi
done
grep -q live_dangerously /etc/asterisk/asterisk.conf || \
  printf '\n[options]\nlive_dangerously = yes\n' >> /etc/asterisk/asterisk.conf
# prod: replace the placeholder all-campus paging PIN with a random one (recorded to secrets)
if grep -q '^PAGING_PIN_700=CHANGE-ME' /etc/asterisk/extensions_custom.conf; then
  PIN=$(shuf -i 100000-999999 -n1)
  sed -i "s/^PAGING_PIN_700=.*/PAGING_PIN_700=${PIN}   ; generated at build - record in secrets/" /etc/asterisk/extensions_custom.conf
  mkdir -p /var/lib/upes-ecs
  echo "PAGING_PIN_700=${PIN}" > /var/lib/upes-ecs/generated-secrets.txt
  echo "  generated paging PIN -> /var/lib/upes-ecs/generated-secrets.txt"
fi

echo "== placeholder prompts =="
PD=/usr/share/asterisk/sounds/en/upes-ecs; mkdir -p "$PD"
SRCG=$(ls /usr/share/asterisk/sounds/en/*.gsm 2>/dev/null | head -1)
for p in emergency-preanswer emergency-voicemail-prompt drill-prompt queue-paused queue-resumed not-authorized queue-hold; do
  [ -n "$SRCG" ] && cp -f "$SRCG" "$PD/$p.gsm"
done
chown -R asterisk:asterisk /var/lib/upes-ecs /var/spool/asterisk/monitor/upes-ecs "$PD" 2>/dev/null || true

echo "== offline panic-coach voice prompts (TTS) =="
apt-get install -y libttspico-utils sox >/dev/null 2>&1 || echo "  (pico2wave/sox install skipped/offline)"
[ -x /opt/upes-ecs/gen-coach-prompts.sh ] && /opt/upes-ecs/gen-coach-prompts.sh || echo "  (coach prompt generator not found)"

echo "== health + retention + backup cron =="
cat >/etc/cron.d/upes-ecs <<EOF
*/5 * * * * root /opt/upes-ecs/upes-ecs-healthcheck.sh > /var/lib/upes-ecs/health.txt 2>&1
30 3 * * *   root /opt/upes-ecs/retention-cleanup.sh
0 2 * * *    root /opt/upes-ecs/upes-ecs-backup.sh >> /var/lib/upes-ecs/backup.log 2>&1
EOF

echo "== live status/control API (FastAPI on :8090) =="
apt-get install -y python3-pip >/dev/null 2>&1 || echo "  (python3-pip install skipped)"
python3 -m pip install --quiet fastapi "uvicorn[standard]" >/dev/null 2>&1 || echo "  (fastapi install skipped/offline)"
mkdir -p /opt/upes-ecs/api
if [ -f "$SRC/api/upes_api.py" ]; then
  cp "$SRC/api/upes_api.py" /opt/upes-ecs/api/; sed -i 's/\r$//' /opt/upes-ecs/api/upes_api.py
  cp "$SRC/api/upes-api.service" /etc/systemd/system/; sed -i 's/\r$//' /etc/systemd/system/upes-api.service
  systemctl enable --now upes-api 2>/dev/null || true
fi

echo "== CardDAV directory (Radicale on :5232 -- shared campus phonebook) =="
if [ -f "$SRC/api/carddav/install-carddav.sh" ]; then
  mkdir -p /opt/upes-ecs/family
  [ -f "$SRC/Console/directory.json" ] && cp "$SRC/Console/directory.json" /opt/upes-ecs/family/directory.json
  sed -i 's/\r$//' "$SRC"/api/carddav/*.sh "$SRC"/api/carddav/*.py 2>/dev/null || true
  # UPES_HOST pins the stable mDNS name into every contact's SIP URI (sip:<ext>@host).
  UPES_HOST=upes-ecs.local bash "$SRC/api/carddav/install-carddav.sh" || echo "  (carddav install skipped/failed -- see above)"
else
  echo "  (carddav payload not present, skipped)"
fi

echo "== fast SSH (no ~75s login hang: disable reverse-DNS, GSSAPI, motd-news) =="
mkdir -p /etc/ssh/sshd_config.d
printf 'UseDNS no\nGSSAPIAuthentication no\n' > /etc/ssh/sshd_config.d/00-upes-fast.conf
systemctl disable --now motd-news.timer 2>/dev/null || true
chmod -x /etc/update-motd.d/50-motd-news 2>/dev/null || true
systemctl reload ssh 2>/dev/null || systemctl restart ssh 2>/dev/null || true

echo "== callout / roll-call groups (extensions per group, one per line) =="
mkdir -p /opt/upes-ecs/groups
printf '500120597\n500120596\n500119503\n500119499\n' > /opt/upes-ecs/groups/roster.csv
printf '500120597\n500120596\n500119503\n500119499\n40001097\n40003657\n40004432\n4101\n4110\n4111\n4112\n4113\n4120\n4200\n4300\n4400\n4500\n4600\n' > /opt/upes-ecs/groups/all.csv
printf '4101\n4110\n4111\n4112\n4113\n4120\n' > /opt/upes-ecs/groups/ert.csv
printf '4200\n4300\n4400\n4500\n4600\n' > /opt/upes-ecs/groups/responders.csv
cp /opt/upes-ecs/groups/roster.csv /opt/upes-ecs/groups/hostels.csv
cp /opt/upes-ecs/groups/roster.csv /opt/upes-ecs/groups/academic.csv
cp /opt/upes-ecs/groups/all.csv /opt/upes-ecs/groups/700.csv
cp /opt/upes-ecs/groups/roster.csv /opt/upes-ecs/groups/701.csv
cp /opt/upes-ecs/groups/roster.csv /opt/upes-ecs/groups/702.csv
printf '4300\n' > /opt/upes-ecs/groups/703.csv
printf '4200\n4110\n4111\n' > /opt/upes-ecs/groups/704.csv
printf '4500\n' > /opt/upes-ecs/groups/705.csv
chown -R asterisk:asterisk /opt/upes-ecs/groups

echo "== fail2ban (SIP + SSH brute-force protection) =="
apt-get install -y fail2ban >/dev/null 2>&1 || echo "  (fail2ban install skipped/offline)"
if [ -f "$SRC/asterisk/fail2ban-asterisk.conf" ]; then
  cp "$SRC/asterisk/fail2ban-asterisk.conf" /etc/fail2ban/jail.d/upes-asterisk.local
  sed -i 's/\r$//' /etc/fail2ban/jail.d/upes-asterisk.local
fi
systemctl enable --now fail2ban 2>/dev/null || true

echo "== prod: asterisk crash auto-recovery (systemd) =="
mkdir -p /etc/systemd/system/asterisk.service.d
printf '[Service]\nRestart=always\nRestartSec=3\n' > /etc/systemd/system/asterisk.service.d/restart.conf
systemctl daemon-reload 2>/dev/null || true

echo "== enable + (re)start asterisk service =="
systemctl enable asterisk 2>/dev/null || true
systemctl restart asterisk 2>/dev/null || { asterisk -g 2>/dev/null || true; }
sleep 5
asterisk -rx "core show uptime" 2>/dev/null | head -1 || true

echo "== per-user voice language: runtime CSV + astdb boot re-seed =="
mkdir -p /opt/upes-ecs/family
# runtime source of truth for the app-facing API (POST /lang) and the boot re-seed.
if [ -f "$SRC/provisioning/user-languages.csv" ]; then
  cp "$SRC/provisioning/user-languages.csv" /opt/upes-ecs/family/user-languages.csv
  sed -i 's/\r$//' /opt/upes-ecs/family/user-languages.csv
elif [ ! -f /opt/upes-ecs/family/user-languages.csv ]; then
  printf 'ext,lang\n' > /opt/upes-ecs/family/user-languages.csv
fi
chown -R asterisk:asterisk /opt/upes-ecs/family 2>/dev/null || true
# number->language map for the *55 self-service "set my language" feature code (ctx_setlang).
if [ -f "$SRC/dtmf-languages.csv" ]; then
  cp "$SRC/dtmf-languages.csv" /opt/upes-ecs/dtmf-languages.csv
  sed -i 's/\r$//' /opt/upes-ecs/dtmf-languages.csv
  chown asterisk:asterisk /opt/upes-ecs/dtmf-languages.csv 2>/dev/null || true
fi
# systemd oneshot: replay the CSV into astdb (DB(lang/<ext>)) after asterisk on every boot,
# so voice-language routing survives a restart / astdb wipe (self-healing, idempotent).
cat >/etc/systemd/system/upes-lang-seed.service <<'UNIT'
[Unit]
Description=UPES-ECS seed per-user voice language into Asterisk astdb
After=asterisk.service
Wants=asterisk.service
[Service]
Type=oneshot
ExecStartPre=/bin/sleep 5
ExecStart=/opt/upes-ecs/seed-lang-db.sh
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
UNIT
systemctl enable upes-lang-seed 2>/dev/null || true
# seed once now (asterisk is already up from the step above)
[ -x /opt/upes-ecs/seed-lang-db.sh ] && /opt/upes-ecs/seed-lang-db.sh || echo "  (lang seeder not present in payload)"

echo "UPES-ECS-VM-SETUP-DONE"
