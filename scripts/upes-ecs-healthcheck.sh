#!/usr/bin/env bash
# upes-ecs-healthcheck.sh — LAN-only readiness check for UPES-ECS.
# Run from cron and/or the Daily ECS Readiness Check. Prints OK/WARN/CRIT lines
# and exits: 0 = all OK, 1 = warnings, 2 = critical.
#
# No external alerting (LAN-only). Output can feed a local dashboard.
set -uo pipefail

QUEUE="ert_emergency_queue"
REC_DIR="/var/spool/asterisk/monitor/upes-ecs"
MIN_AGENTS=2
DISK_WARN=75
DISK_CRIT=90

rc=0
crit(){ echo "CRIT: $*"; rc=2; }
warn(){ echo "WARN: $*"; [[ $rc -lt 1 ]] && rc=1; }
ok(){   echo "OK:   $*"; }

# 1. Asterisk running?
if asterisk -rx 'core show uptime' >/dev/null 2>&1; then
  ok "Asterisk service running"
else
  crit "Asterisk not responding"
  echo "---"; echo "SUMMARY: CRITICAL (Asterisk down)"; exit 2
fi

# 2. ERT queue available agents
avail=$(asterisk -rx "queue show ${QUEUE}" 2>/dev/null | grep -c "(Not in use)")
if   [[ "${avail}" -ge "${MIN_AGENTS}" ]]; then ok "ERT queue: ${avail} available"
elif [[ "${avail}" -ge 1 ]];              then warn "ERT queue: only ${avail} available (min ${MIN_AGENTS})"
else crit "ERT queue: 0 available responders"; fi

# 3. Recording dir writable
if [[ -d "${REC_DIR}" && -w "${REC_DIR}" ]]; then ok "Recording dir writable"
else crit "Recording dir missing/not writable: ${REC_DIR}"; fi

# 4. Disk usage on the recordings partition
use=$(df --output=pcent "${REC_DIR}" 2>/dev/null | tail -1 | tr -dc '0-9')
use=${use:-0}
if   [[ "${use}" -ge "${DISK_CRIT}" ]]; then crit "Disk ${use}% used (critical ${DISK_CRIT}%)"
elif [[ "${use}" -ge "${DISK_WARN}" ]]; then warn "Disk ${use}% used (warn ${DISK_WARN}%)"
else ok "Disk ${use}% used"; fi

# 5. Critical fixed-device registrations (edit list to your site)
for dev in 4101 4200 4300; do
  if asterisk -rx "pjsip show endpoint ${dev}" 2>/dev/null | grep -q "Avail\|Not in use\|In use"; then
    ok "Device ${dev} registered"
  else
    warn "Device ${dev} not registered"
  fi
done

# 6. Pending missed emergencies awaiting review
pending="/var/lib/upes-ecs/alerts/missed-pending.log"
if [[ -s "${pending}" ]]; then warn "Missed emergencies pending review: $(wc -l < "${pending}")"; fi

# 7. CardDAV directory (shared campus phonebook) reachable
if systemctl list-unit-files 2>/dev/null | grep -q '^upes-carddav\.service'; then
  code=$(curl -s -o /dev/null -w '%{http_code}' -X PROPFIND -H 'Depth: 0' \
         "http://127.0.0.1:5232/upes/directory/" 2>/dev/null || echo 000)
  # 207 = served; 401 = up but auth-challenged (still healthy). 000/others = down.
  if [[ "${code}" == "207" || "${code}" == "401" ]]; then ok "CardDAV directory up (HTTP ${code})"
  else warn "CardDAV directory not responding (HTTP ${code})"; fi
  n=$(ls /var/lib/radicale/collections/collection-root/upes/directory/*.vcf 2>/dev/null | wc -l)
  [[ "${n}" -ge 1 ]] && ok "CardDAV directory has ${n} contact(s)" || warn "CardDAV directory has no contacts (check sync timer)"
fi

echo "---"
case $rc in
  0) echo "SUMMARY: READY (all OK)";;
  1) echo "SUMMARY: DEGRADED (warnings)";;
  2) echo "SUMMARY: CRITICAL — do not rely on system until fixed";;
esac
exit $rc
