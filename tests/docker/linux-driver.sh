#!/usr/bin/env bash
#
# linux-driver.sh -- runs INSIDE a clean ubuntu:22.04 / debian:12 container.
# Proves the UPES-ECS Linux installer (deploy/linux/install-linux.sh) is airtight
# on a box with NO Asterisk pre-installed: it must apt-install Asterisk itself,
# lay down the 111 emergency dialplan + PJSIP config, stand up the status API and
# the Console, and install the chosen language pack.
#
# The repo is bind-mounted read-only at /repo. We copy it to a writable /work
# (the installer mutates /etc/asterisk, /opt, /var). Transcript -> /out.
#
# NOTE: intentionally NOT `set -e`. We want to run EVERY check and record a
# PASS/FAIL for each, even if one fails -- an aborted transcript proves nothing.
set -uo pipefail

LANG_CODE="${1:-hi}"
OUT="${OUT:-/out/transcript.txt}"
mkdir -p "$(dirname "$OUT")"
# Mirror everything to the transcript AND stdout.
exec > >(tee "$OUT") 2>&1

PASS=0; FAIL=0
declare -a RESULTS=()
check() {  # check "<name>" <rc>   (rc 0 = pass)
  local name="$1" rc="$2"
  if [ "$rc" -eq 0 ]; then RESULTS+=("PASS  $name"); PASS=$((PASS+1));
  else RESULTS+=("FAIL  $name"); FAIL=$((FAIL+1)); fi
}
hr(){ echo "-------------------------------------------------------------------"; }
sec(){ echo; echo "###################################################################"; echo "### $*"; echo "###################################################################"; }

sec "0. Environment"
. /etc/os-release 2>/dev/null || true
echo "Base image : ${PRETTY_NAME:-unknown}"
echo "Arch       : $(uname -m)"
echo "Language   : $LANG_CODE"
echo "Date (UTC) : $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Asterisk pre-installed? : $(command -v asterisk || echo 'NO (clean box) - installer must apt-install it')"

sec "1. Copy repo -> writable /work"
rm -rf /work && cp -a /repo /work
echo "copied $(du -sh /work 2>/dev/null | awk '{print $1}') to /work"

sec "2. Run installer end-to-end (deploy/linux/install-linux.sh)"
chmod +x /work/deploy/linux/install-linux.sh /work/deploy/linux/run-foreground.sh 2>/dev/null || true
# --lan-ip 127.0.0.1 (LAN-only, no NIC needed in a container). No systemd here,
# so the installer installs the run-foreground.sh launcher; we start services
# ourselves below (as background processes) for controlled, capturable checks.
bash /work/deploy/linux/install-linux.sh --lan-ip 127.0.0.1 --language "$LANG_CODE"
INSTALL_RC=$?
echo "INSTALLER-EXIT-CODE=$INSTALL_RC"
check "installer exits 0 on a clean box (apt-installs Asterisk itself)" "$INSTALL_RC"

sec "3. Start services as background processes (no systemd in container)"
# Asterisk (daemonize, run as asterisk user; fall back to root).
if asterisk -rx 'core show version' >/dev/null 2>&1; then
  echo "asterisk already running"
else
  asterisk -g -U asterisk -G asterisk >/var/log/upes-asterisk.boot 2>&1 \
    || asterisk -g >/var/log/upes-asterisk.boot 2>&1 || true
fi
for _ in $(seq 1 20); do
  asterisk -rx 'core show version' >/dev/null 2>&1 && break
  sleep 1
done
# Status API (venv, 127.0.0.1:8090)
/opt/upes-ecs/venv/bin/python /opt/upes-ecs/api/upes_api.py >/var/log/upes-api.out 2>&1 &
API_PID=$!
# Console (stdlib server + /api proxy, 0.0.0.0:8080)
UPES_CONSOLE_ROOT=/opt/upes-ecs/console UPES_CONSOLE_PORT=8080 \
  UPES_API_BASE=http://127.0.0.1:8090 \
  python3 /opt/upes-ecs/serve-console.py >/var/log/upes-console.out 2>&1 &
CON_PID=$!
echo "api pid=$API_PID  console pid=$CON_PID"
# Give the python services a moment to bind.
for _ in $(seq 1 15); do
  curl -sf http://127.0.0.1:8090/health >/dev/null 2>&1 && break
  sleep 1
done

sec "4. Asterisk: core show version"
asterisk -rx 'core show version'; RC=$?
asterisk -rx 'core show version' | grep -qi 'Asterisk'; check "core show version reports Asterisk" $?
[ $RC -eq 0 ] || true

sec "5. Dialplan: the 111 emergency context"
hr; echo "\$ asterisk -rx 'dialplan show ctx_emergency_111'"; hr
asterisk -rx 'dialplan show ctx_emergency_111'
asterisk -rx 'dialplan show ctx_emergency_111' | grep -q "'111'"; check "dialplan exposes emergency extension 111 in ctx_emergency_111" $?
echo; hr; echo "contexts containing 111 across the whole dialplan:"; hr
asterisk -rx 'dialplan show' | grep -nE "Context '.*111|=> .111," | head -20

sec "6. PJSIP: endpoints + aors load with no config errors"
hr; echo "\$ asterisk -rx 'pjsip show endpoints'"; hr
asterisk -rx 'pjsip show endpoints'
asterisk -rx 'pjsip show endpoints' | grep -qiE 'Endpoint:'; check "pjsip show endpoints lists endpoints" $?
echo; hr; echo "\$ asterisk -rx 'pjsip show aors'"; hr
asterisk -rx 'pjsip show aors'
asterisk -rx 'pjsip show aors' | grep -qiE 'Aor:'; check "pjsip show aors lists AORs" $?

sec "7. No config-load ERRORs in the Asterisk logs / boot"
FOUND_ERR=0
for L in /var/log/upes-asterisk.boot /var/log/asterisk/messages /var/log/asterisk/full; do
  [ -f "$L" ] || continue
  echo "--- ERROR/config lines in $L ---"
  if grep -nE 'ERROR|Unable to (open|load)|failed to parse|config error' "$L"; then
    FOUND_ERR=1
  else
    echo "  (none)"
  fi
done
# Treat 0 matches as PASS.
check "no ERROR / config-load failures in Asterisk logs" "$FOUND_ERR"

sec "8. Asterisk: core show channels"
asterisk -rx 'core show channels'; check "core show channels runs" $?

sec "9. Status API :8090  (/health and /status return JSON)"
hr; echo "\$ curl -s http://127.0.0.1:8090/health"; hr
H=$(curl -s http://127.0.0.1:8090/health); echo "$H"
echo "$H" | grep -qE '\{.*\}'; check "GET /health returns JSON" $?
echo; hr; echo "\$ curl -s http://127.0.0.1:8090/status | head -c 600"; hr
S=$(curl -s http://127.0.0.1:8090/status); echo "$S" | head -c 600; echo
echo "$S" | grep -qE '\{.*\}'; check "GET /status returns JSON" $?

sec "10. Console :8080  (dashboard HTML + /api/health proxy)"
hr; echo "\$ curl -s http://127.0.0.1:8080/  | head -c 400"; hr
C=$(curl -s http://127.0.0.1:8080/); echo "$C" | head -c 400; echo
echo "$C" | grep -qiE '<html|<!doctype html|<title'; check "GET / returns dashboard HTML" $?
echo; hr; echo "\$ curl -s http://127.0.0.1:8080/api/health   (proxies to API /health)"; hr
P=$(curl -s http://127.0.0.1:8080/api/health); echo "$P"
echo "$P" | grep -qE '\{.*\}'; check "GET /api/health proxies through to the API" $?

sec "11. Language pack present: /usr/share/asterisk/sounds/$LANG_CODE"
if [ "$LANG_CODE" = "en" ]; then PACKDIR=/usr/share/asterisk/sounds/en; else PACKDIR=/usr/share/asterisk/sounds/$LANG_CODE; fi
echo "listing $PACKDIR :"
ls -R "$PACKDIR" 2>/dev/null | head -30
N=$(find "$PACKDIR" -type f 2>/dev/null | wc -l)
echo "file count in pack: $N"
[ "$N" -gt 0 ]; check "language pack '$LANG_CODE' installed with >0 sound files" $?

sec "12. SECRET SCAN of the deployed payload (/etc/asterisk)"
echo "Scanning /etc/asterisk/pjsip_accounts.conf for real SIP secrets:"
SECRETS=$(grep -cE '^[[:space:]]*password=' /etc/asterisk/pjsip_accounts.conf 2>/dev/null || echo 0)
echo "  password= lines in deployed pjsip_accounts.conf: $SECRETS"
grep -nE '^[[:space:]]*password=' /etc/asterisk/pjsip_accounts.conf 2>/dev/null | head -3 \
  | sed -E 's/(password=).{4}.*/\1****REDACTED****/'
echo "  generated paging PIN file: $(ls -l /var/lib/upes-ecs/generated-secrets.txt 2>/dev/null || echo 'not created')"
echo "NOTE: real SIP secrets ARE present in the deployed config (single-source-of-truth"
echo "      design, LAN-only). They must NOT be web-served. See secret-scan note in REPORT.md."

sec "RESULT SUMMARY"
for r in "${RESULTS[@]}"; do echo "  $r"; done
echo
echo "TOTAL: PASS=$PASS FAIL=$FAIL"
# Clean up background python services (asterisk keeps running; container is torn down).
kill "$API_PID" "$CON_PID" 2>/dev/null || true
asterisk -rx 'core stop now' >/dev/null 2>&1 || true
if [ "$FAIL" -eq 0 ]; then echo "OVERALL: PASS"; exit 0; else echo "OVERALL: FAIL"; exit 1; fi
