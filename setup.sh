#!/usr/bin/env bash
# ============================================================================
# UPES-ECS bootstrap — deploy scripts, config, dirs, permissions, cron.
# Run ON the FreePBX/Asterisk server, from the repo root, as root:
#     sudo ./setup.sh
# Idempotent: safe to re-run. Backs up any existing extensions_custom.conf.
# ============================================================================
set -euo pipefail

ASTERISK_USER="asterisk"
BIN_DIR="/opt/upes-ecs"
STATE_DIR="/var/lib/upes-ecs"
REC_DIR="/var/spool/asterisk/monitor/upes-ecs"
AST_CONF="/etc/asterisk"
CRON_FILE="/etc/cron.d/upes-ecs"

say(){ printf '\n\033[1m==> %s\033[0m\n' "$*"; }

[[ $EUID -eq 0 ]] || { echo "Run as root (sudo ./setup.sh)"; exit 1; }
[[ -d scripts && -d config ]] || { echo "Run from the repo root (scripts/ and config/ must exist)"; exit 1; }

say "1. Creating directories"
mkdir -p "${BIN_DIR}" "${REC_DIR}"
mkdir -p "${STATE_DIR}"/{incidents,alerts,security,paging,conference,retention}

say "2. Installing helper scripts -> ${BIN_DIR}"
cp scripts/*.sh "${BIN_DIR}/"
chmod +x "${BIN_DIR}"/*.sh

say "3. Setting ownership (so dialplan System() can write)"
if id "${ASTERISK_USER}" >/dev/null 2>&1; then
  chown -R "${ASTERISK_USER}:${ASTERISK_USER}" "${STATE_DIR}" "${REC_DIR}"
else
  echo "WARN: user '${ASTERISK_USER}' not found — set ownership manually after installing Asterisk."
fi

say "4. Dialplan config"
if [[ -f "${AST_CONF}/extensions_custom.conf" ]]; then
  ts="$(date +%Y%m%d-%H%M%S)"
  cp "${AST_CONF}/extensions_custom.conf" "${AST_CONF}/extensions_custom.conf.bak-${ts}"
  echo "Backed up existing -> extensions_custom.conf.bak-${ts}"
  echo "NOT overwriting automatically. Review and merge:"
  echo "   diff ${AST_CONF}/extensions_custom.conf config/extensions_custom.conf"
else
  if [[ -d "${AST_CONF}" ]]; then
    cp config/extensions_custom.conf "${AST_CONF}/"
    echo "Installed config/extensions_custom.conf -> ${AST_CONF}/"
  else
    echo "WARN: ${AST_CONF} not found — install Asterisk/FreePBX first, then copy config/extensions_custom.conf."
  fi
fi

say "5. Installing cron jobs -> ${CRON_FILE}"
cat > "${CRON_FILE}" <<EOF
# UPES-ECS — health check every 5 min; retention cleanup daily 03:30
*/5 * * * * root ${BIN_DIR}/upes-ecs-healthcheck.sh > ${STATE_DIR}/health.txt 2>&1
30 3 * * *   root ${BIN_DIR}/retention-cleanup.sh
EOF
chmod 644 "${CRON_FILE}"

say "6. Checks"
if command -v asterisk >/dev/null 2>&1; then
  asterisk -rx 'module show like func_shell' | grep -qi func_shell \
    && echo "func_shell present (\${SHELL()} for incident IDs OK)" \
    || echo "WARN: func_shell not loaded — enable it or replace incident_id.sh call (see config/README.md)."
  echo "Reload dialplan when ready:  asterisk -rx 'dialplan reload'"
else
  echo "Asterisk not installed yet — install FreePBX, then rerun step 4 + reload."
fi

say "Done."
cat <<EOF

Next:
  1. Review/merge  config/extensions_custom.conf  into ${AST_CONF}/
  2. asterisk -rx 'dialplan reload'
  3. Record prompts into /var/lib/asterisk/sounds/en/upes-ecs/  (SOP 28)
  4. Import provisioning CSVs via FreePBX Bulk Handler  (provisioning/README.md)
  5. Create the ert_emergency_queue  (SOP 08)
  6. Test:  199 (drill)  ->  111  ->  SAP-ID to SAP-ID

Health status will appear at:  ${STATE_DIR}/health.txt
EOF
