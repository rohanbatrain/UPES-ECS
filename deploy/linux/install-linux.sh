#!/usr/bin/env bash
#
# install-linux.sh -- native, single-node UPES-ECS install for x86_64 Linux
# (Ubuntu/Debian). Asterisk runs NATIVELY -- no QEMU, no Jetson ARM, no HA/VIP.
#
# This is the generalisation of deploy/jetson/install-jetson.sh to a single
# x86_64 node: it lays down the emergency dialplan + PJSIP config from the repo
# checkout (or the self-extracting payload), installs the sounds + chosen
# language pack, stands up the status API in a Python venv and the Console web
# server, and wires everything to systemd -- with a non-systemd foreground
# launcher (run-foreground.sh) as a fallback for containers/WSL without pid1
# systemd.
#
# LAN-only posture: nothing here is meant to face the internet. Phones register
# to this node's LAN IP on :5060; the Console is on :8080; the API on :8090
# (loopback). See README-LINUX.md for the firewall note.
#
# Usage:
#   sudo ./install-linux.sh --iface eth0 [--lan-ip 192.168.1.20] \
#        [--language en|hi|te|ml|ur|ne] [--lang <ui-code>] [--no-start]
#
#   --language  voice-prompt + Console pack (audio the callers hear)
#   --lang      language of THIS installer's own on-screen messages; auto-detected
#               from $LC_ALL/$LC_MESSAGES/$LANG, falls back to English
#
set -euo pipefail

#--------------------------------------------------------------------------------
# 0. Args + repo location
#--------------------------------------------------------------------------------
IFACE=""
LAN_IP=""
LANGUAGE="en"
MSGLANG=""
DO_START=1

usage() {
  sed -n '2,33p' "$0"
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --iface)    IFACE="${2:-}"; shift 2 ;;
    --lan-ip)   LAN_IP="${2:-}"; shift 2 ;;
    --language) LANGUAGE="${2:-}"; shift 2 ;;
    --lang)     MSGLANG="${2:-}"; shift 2 ;;
    --no-start) DO_START=0; shift ;;
    -h|--help)  usage 0 ;;
    *) echo "Unknown argument: $1" >&2; usage 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ASTSRC="$REPO_ROOT/deploy/asterisk"

#--------------------------------------------------------------------------------
# 0a. Localization -- route ALL operator-facing text through msg().
#     English is embedded here as the guaranteed fallback; a per-language overlay
#     in i18n/<code>.sh (if present) overrides individual keys. Missing keys stay
#     English. Detect the operator locale unless --lang was passed.
#--------------------------------------------------------------------------------
declare -A MSG

load_catalog_en() {
  MSG[banner_title]=" UPES-ECS Linux (single-node, native Asterisk) install"
  MSG[banner_params]="   iface=%s  lan-ip=%s  language=%s"
  MSG[banner_root]="   root=%s"
  MSG[preflight]="preflight checks"
  MSG[err_need_root]="run as root (sudo)."
  MSG[err_no_astsrc]="cannot find %s -- run from inside the repo/payload"
  MSG[err_no_api]="cannot find %s -- layout unexpected"
  MSG[err_iface_required]="--iface <nic> is required (or pass --lan-ip <ip>)"
  MSG[err_iface_noip]="could not read an IPv4 address from --iface %s; pass --lan-ip <ip>"
  MSG[err_disk]="insufficient disk space: %s MB free under %s, need at least %s MB. Free space and re-run."
  MSG[err_missing_cmd]="required command '%s' not found. Install it (package: %s) and re-run."
  MSG[err_no_python3]="python3 not found and could not be installed. Install python3 and re-run."
  MSG[err_asterisk]="asterisk is not installed and could not be installed automatically"
  MSG[err_venv]="python3 -m venv failed (install python3-venv)"
  MSG[err_aborted]="installation aborted -- no changes past the failed step were applied."
  MSG[warn_msglang_missing]="  (no installer message catalog for '%s' -- using English)"
  MSG[init_systemd]="init system: systemd (units will be installed + started)"
  MSG[init_nosystemd]="init system: NO systemd (will install run-foreground.sh launcher instead)"
  MSG[sec_packages]="packages"
  MSG[pkg_installing]="  installing: %s"
  MSG[pkg_apt_update_fail]="  (apt update failed/offline -- continuing)"
  MSG[pkg_apt_install_fail]="  (some apt installs failed/offline -- verify below)"
  MSG[pkg_all_present]="  all required packages already present -- skipping apt"
  MSG[sec_dirs]="dirs + helper scripts"
  MSG[helper_none]="  (no scripts/*.sh found -- skipping helper copy)"
  MSG[sec_astconf]="asterisk config -> /etc/asterisk (backing up existing)"
  MSG[stub_warn]="  !! %s missing from payload -- writing a CLEAN STUB (add users post-install)"
  MSG[optional_skip]="  (optional %s not present, skipped)"
  MSG[include_skip]="  (dialplan include %s not present, skipped)"
  MSG[pin_generated]="  generated paging PIN -> /var/lib/upes-ecs/generated-secrets.txt"
  MSG[sec_extaddr]="external_media_address = LAN IP (%s)"
  MSG[sec_prompts]="voice prompts (en base + language '%s')"
  MSG[pack_installed]="  installed language pack: %s"
  MSG[pack_missing]="  !! no sounds/lang/%s pack found -- falling back to English audio"
  MSG[prompts_seed]="  (no en/upes-ecs prompts found -- seeding placeholders)"
  MSG[sec_groups]="callout / roll-call groups"
  MSG[groups_present]="  (groups already present -- leaving in place)"
  MSG[sec_api]="status API venv (FastAPI :8090)"
  MSG[pip_upgrade_skip]="  (pip self-upgrade skipped/offline)"
  MSG[pip_install_skip]="  (fastapi/uvicorn install skipped/offline -- may already be in the venv)"
  MSG[sec_console]="Console web server (:8080)"
  MSG[sec_region]="region.json -> language '%s'"
  MSG[region_skip]="  (region.json update skipped)"
  MSG[sec_systemd]="systemd units"
  MSG[sd_ast_fail]="  (systemd asterisk start failed -- trying direct)"
  MSG[sec_foreground]="non-systemd: run-foreground.sh is the launcher"
  MSG[fg_start_hint]="  start everything with:  sudo /opt/upes-ecs/run-foreground.sh"
  MSG[ast_not_responding]="  (asterisk not responding yet)"
  MSG[summary_installed]="  UPES-ECS is installed on this node."
  MSG[summary_dial]="    Dial 111 ............ campus emergency hotline (test with 199 first)"
  MSG[summary_console]="    Console ............. http://%s:8080"
  MSG[summary_api]="    API (loopback) ..... http://127.0.0.1:8090/health"
  MSG[summary_register]="    Phones register to .. %s:5060  (SIP/UDP)"
  MSG[summary_language]="    Language ............ %s"
  MSG[summary_adduser1]="  Add users post-install (NO accounts ship in the installer):"
  MSG[summary_adduser2]="    edit /etc/asterisk/pjsip_accounts.conf, then: asterisk -rx 'pjsip reload'"
  MSG[summary_adduser3]="    (see README-LINUX.md 'Add a user')"
}

# Detect the operator's UI language: LC_ALL > LC_MESSAGES > LANG, then strip the
# encoding (.UTF-8), modifier (@euro) and territory (_IN) -> a bare code (hi).
detect_msglang() {
  local raw="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
  raw="${raw%%.*}"; raw="${raw%%@*}"; raw="${raw%%_*}"
  printf '%s' "$raw"
}

load_catalog_en
[ -n "$MSGLANG" ] || MSGLANG="$(detect_msglang)"
[ -n "$MSGLANG" ] || MSGLANG="en"
if [ "$MSGLANG" != "en" ]; then
  if [ -f "$SCRIPT_DIR/i18n/$MSGLANG.sh" ]; then
    # shellcheck source=/dev/null
    . "$SCRIPT_DIR/i18n/$MSGLANG.sh" || true
  else
    # Keep the English catalog; note the fallback once we know we can print.
    MSGLANG_FELLBACK="$MSGLANG"
    MSGLANG="en"
  fi
fi

# msg KEY [printf-args...] -- emit a localized line (English fallback per key).
msg() {
  local k="${1:-}"; shift || true
  local fmt="${MSG[$k]:-$k}"
  # shellcheck disable=SC2059
  printf "$fmt\n" "$@"
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
log() { printf '== %s ==\n' "$1"; }

#--------------------------------------------------------------------------------
# 0b. Robustness: fail loud, clean temp, name the failed line.
#--------------------------------------------------------------------------------
TMPFILES=()
cleanup_tmp() {
  local f
  for f in "${TMPFILES[@]:-}"; do
    [ -n "${f:-}" ] && rm -rf "$f" 2>/dev/null || true
  done
}
on_err() {
  local ec=$? line="${1:-?}"
  cleanup_tmp
  printf 'ERROR: %s failed at line %s (exit %s)\n' "${BASH_SOURCE[0]##*/}" "$line" "$ec" >&2
  msg err_aborted >&2
  exit "$ec"
}
trap 'on_err "$LINENO"' ERR
trap cleanup_tmp EXIT

#--------------------------------------------------------------------------------
# 0c. Preflight -- fail early with actionable messages.
#--------------------------------------------------------------------------------
log "$(msg preflight)"
[ "$(id -u)" -eq 0 ] || die "$(msg err_need_root)"

# One-time note if the operator's locale had no catalog.
[ -n "${MSGLANG_FELLBACK:-}" ] && msg warn_msglang_missing "$MSGLANG_FELLBACK"

# This script lives at <root>/deploy/linux/install-linux.sh, both in the repo
# checkout and inside the extracted self-extracting payload (same layout).
[ -d "$ASTSRC" ]        || die "$(msg err_no_astsrc "$ASTSRC")"
[ -d "$REPO_ROOT/api" ] || die "$(msg err_no_api "$REPO_ROOT/api")"

# Core commands we rely on and cannot always auto-install. Map cmd -> apt package.
check_cmd() {  # <cmd> <package>
  command -v "$1" >/dev/null 2>&1 || die "$(msg err_missing_cmd "$1" "$2")"
}
check_cmd awk  coreutils
check_cmd sed  sed
check_cmd grep grep
check_cmd df   coreutils

# Disk space: venv + pip wheels + sounds need headroom. Check the fs backing /var.
MIN_DISK_MB=256
SPACE_TARGET="/var/lib"
[ -d "$SPACE_TARGET" ] || SPACE_TARGET="/"
avail_kb="$(df -Pk "$SPACE_TARGET" 2>/dev/null | awk 'NR==2{print $4}')"
avail_kb="${avail_kb:-0}"
case "$avail_kb" in (*[!0-9]*) avail_kb=0 ;; esac
avail_mb=$(( avail_kb / 1024 ))
[ "$avail_mb" -ge "$MIN_DISK_MB" ] || die "$(msg err_disk "$avail_mb" "$SPACE_TARGET" "$MIN_DISK_MB")"

# Resolve the LAN IP from the iface if not supplied.
if [ -z "$LAN_IP" ]; then
  [ -n "$IFACE" ] || die "$(msg err_iface_required)"
  command -v ip >/dev/null 2>&1 || die "$(msg err_missing_cmd ip iproute2)"
  LAN_IP="$(ip -4 -o addr show dev "$IFACE" 2>/dev/null \
            | awk '{print $4}' | cut -d/ -f1 | head -n1 || true)"
  [ -n "$LAN_IP" ] || die "$(msg err_iface_noip "$IFACE")"
fi
# If iface not given but lan-ip was, keep a label for the summary.
[ -n "$IFACE" ] || IFACE="(lan-ip override)"

echo "==================================================================="
msg banner_title
msg banner_params "$IFACE" "$LAN_IP" "$LANGUAGE"
msg banner_root "$REPO_ROOT"
echo "==================================================================="

#--------------------------------------------------------------------------------
# 1. systemd detection (support BOTH systemd and a foreground fallback)
#--------------------------------------------------------------------------------
HAVE_SYSTEMD=0
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
  HAVE_SYSTEMD=1
  log "$(msg init_systemd)"
else
  log "$(msg init_nosystemd)"
fi

#--------------------------------------------------------------------------------
# 2. Packages (native x86_64 -- no emulation). Install only what's missing.
#--------------------------------------------------------------------------------
log "$(msg sec_packages)"
NEED_PKGS=()
have() { command -v "$1" >/dev/null 2>&1; }
have asterisk    || NEED_PKGS+=(asterisk)
have sox         || NEED_PKGS+=(sox libsox-fmt-all)
have python3     || NEED_PKGS+=(python3)
have curl        || NEED_PKGS+=(curl)
have ip          || NEED_PKGS+=(iproute2)
# python3-venv / pip are libraries, not commands -- probe them directly.
python3 -c 'import venv'     >/dev/null 2>&1 || NEED_PKGS+=(python3-venv)
python3 -c 'import ensurepip'>/dev/null 2>&1 || NEED_PKGS+=(python3-venv)
have pip3 || python3 -m pip --version >/dev/null 2>&1 || NEED_PKGS+=(python3-pip)

if [ "${#NEED_PKGS[@]}" -gt 0 ]; then
  msg pkg_installing "${NEED_PKGS[*]}"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y >/dev/null 2>&1 || msg pkg_apt_update_fail
  apt-get install -y "${NEED_PKGS[@]}" >/dev/null 2>&1 || msg pkg_apt_install_fail
else
  msg pkg_all_present
fi
have python3  || die "$(msg err_no_python3)"
have asterisk || die "$(msg err_asterisk)"

#--------------------------------------------------------------------------------
# 3. Dirs + helper scripts
#--------------------------------------------------------------------------------
log "$(msg sec_dirs)"
mkdir -p /opt/upes-ecs \
         /opt/upes-ecs/api /opt/upes-ecs/groups /opt/upes-ecs/family /opt/upes-ecs/console \
         /var/lib/upes-ecs/incidents /var/lib/upes-ecs/alerts \
         /var/lib/upes-ecs/security /var/lib/upes-ecs/paging \
         /var/lib/upes-ecs/conference /var/lib/upes-ecs/retention \
         /var/lib/upes-ecs/rollcall /var/lib/upes-ecs/shift \
         /var/lib/upes-ecs/safety /var/lib/upes-ecs/location \
         /var/lib/upes-ecs/callbacks \
         /var/spool/asterisk/monitor/upes-ecs

if compgen -G "$REPO_ROOT/scripts/*.sh" >/dev/null; then
  cp "$REPO_ROOT"/scripts/*.sh /opt/upes-ecs/
  sed -i 's/\r$//' /opt/upes-ecs/*.sh
  chmod +x /opt/upes-ecs/*.sh
else
  msg helper_none
fi

#--------------------------------------------------------------------------------
# 4. Asterisk config from the checkout/payload (back up any existing /etc/asterisk)
#--------------------------------------------------------------------------------
log "$(msg sec_astconf)"
mkdir -p /etc/asterisk
STAMP="$(date +%Y%m%d-%H%M%S)"
# Back up only the files we are about to overwrite (keeps the vendor defaults).
BACKUP_DIR="/etc/asterisk/upes-backup-$STAMP"
mkdir -p "$BACKUP_DIR"

install_conf() {  # <src-file> <dst-name>
  local src="$1" dst="$2"
  [ -f "$src" ] || return 1
  if [ -f "/etc/asterisk/$dst" ]; then
    cp -a "/etc/asterisk/$dst" "$BACKUP_DIR/$dst" 2>/dev/null || true
  fi
  cp "$src" "/etc/asterisk/$dst"
  sed -i 's/\r$//' "/etc/asterisk/$dst"
  return 0
}

# Core config from deploy/asterisk/
for f in extensions.conf pjsip.conf pjsip_accounts.conf queues.conf voicemail.conf \
         rtp.conf confbridge.conf http.conf; do
  if install_conf "$ASTSRC/$f" "$f"; then :; else
    if [ "$f" = "pjsip_accounts.conf" ]; then
      msg stub_warn "$f"
      cat > /etc/asterisk/pjsip_accounts.conf <<'STUB'
; UPES-ECS - pjsip_accounts.conf (CLEAN STUB installed by install-linux.sh)
; No accounts ship in the installer. Add users AFTER install; see README-LINUX.md.
STUB
    else
      msg optional_skip "$f"
    fi
  fi
done

# Extra dialplan includes live under config/ in this repo.
for f in extensions_custom.conf extensions_features.conf extensions_features_wiring.conf extensions_aihelpline.conf; do
  install_conf "$REPO_ROOT/config/$f" "$f" \
    || msg include_skip "$f"
done

# live_dangerously: needed by the emergency dialplan's System()/privileged apps.
if [ -f /etc/asterisk/asterisk.conf ]; then
  grep -q 'live_dangerously' /etc/asterisk/asterisk.conf || \
    printf '\n[options]\nlive_dangerously = yes\n' >> /etc/asterisk/asterisk.conf
else
  # Minimal asterisk.conf so System()/privileged apps work if the distro omitted it.
  cat > /etc/asterisk/asterisk.conf <<'ACONF'
[directories](!)
astetcdir => /etc/asterisk
astmoddir => /usr/lib/asterisk/modules
astvarlibdir => /var/lib/asterisk
astdbdir => /var/lib/asterisk
astkeydir => /var/lib/asterisk
astdatadir => /var/lib/asterisk
astagidir => /var/lib/asterisk/agi-bin
astspooldir => /var/spool/asterisk
astrundir => /var/run/asterisk
astlogdir => /var/log/asterisk
astsbindir => /usr/sbin

[options]
live_dangerously = yes
ACONF
fi

# All-campus paging PIN: replace placeholder with a random one (idempotent).
if [ -f /etc/asterisk/extensions_custom.conf ] && \
   grep -q '^PAGING_PIN_700=CHANGE-ME' /etc/asterisk/extensions_custom.conf; then
  PIN="$(shuf -i 100000-999999 -n1)"
  sed -i "s/^PAGING_PIN_700=.*/PAGING_PIN_700=${PIN}   ; generated at install - record in secrets/" \
    /etc/asterisk/extensions_custom.conf
  echo "PAGING_PIN_700=${PIN}" > /var/lib/upes-ecs/generated-secrets.txt
  chmod 600 /var/lib/upes-ecs/generated-secrets.txt
  msg pin_generated
fi

#--------------------------------------------------------------------------------
# 5. Native single-node: advertise the node's LAN IP for media/signaling
#--------------------------------------------------------------------------------
log "$(msg sec_extaddr "$LAN_IP")"
# The repo pjsip.conf ships these two lines commented under [transport-udp].
if grep -qE '^;?external_media_address=' /etc/asterisk/pjsip.conf; then
  sed -i -E "s|^;?external_media_address=.*|external_media_address=${LAN_IP}|" /etc/asterisk/pjsip.conf
else
  sed -i -E "/^\[transport-udp\]/,/^\[/ s|^(bind=.*)$|\1\nexternal_media_address=${LAN_IP}|" /etc/asterisk/pjsip.conf
fi
if grep -qE '^;?external_signaling_address=' /etc/asterisk/pjsip.conf; then
  sed -i -E "s|^;?external_signaling_address=.*|external_signaling_address=${LAN_IP}|" /etc/asterisk/pjsip.conf
else
  sed -i -E "/^\[transport-udp\]/,/^\[/ s|^(external_media_address=.*)$|\1\nexternal_signaling_address=${LAN_IP}|" /etc/asterisk/pjsip.conf
fi

#--------------------------------------------------------------------------------
# 6. Voice prompts: en base + chosen language pack
#--------------------------------------------------------------------------------
log "$(msg sec_prompts "$LANGUAGE")"
SND_DST="/usr/share/asterisk/sounds"
mkdir -p "$SND_DST/en"
if [ -d "$ASTSRC/sounds/en" ]; then
  cp -a "$ASTSRC/sounds/en/." "$SND_DST/en/"
fi
# lang packs: deploy/asterisk/sounds/lang/<code> -> /usr/share/asterisk/sounds/<code>
if [ "$LANGUAGE" != "en" ]; then
  if [ -d "$ASTSRC/sounds/lang/$LANGUAGE" ]; then
    mkdir -p "$SND_DST/$LANGUAGE"
    cp -a "$ASTSRC/sounds/lang/$LANGUAGE/." "$SND_DST/$LANGUAGE/"
    msg pack_installed "$LANGUAGE"
  else
    msg pack_missing "$LANGUAGE"
    LANGUAGE="en"
  fi
fi

# Fallback: never leave a silent PBX. Seed placeholders if en/upes-ecs is empty.
PD="$SND_DST/en/upes-ecs"; mkdir -p "$PD"
if ! compgen -G "$PD/*.wav" >/dev/null && ! compgen -G "$PD/*.gsm" >/dev/null; then
  msg prompts_seed
  SRCG=""
  for g in "$SND_DST"/en/*.gsm; do [ -e "$g" ] && { SRCG="$g"; break; }; done
  for p in emergency-preanswer emergency-voicemail-prompt drill-prompt queue-paused \
           queue-resumed not-authorized queue-hold hold-firstaid; do
    [ -n "$SRCG" ] && cp -f "$SRCG" "$PD/$p.gsm"
  done
fi
chown -R asterisk:asterisk /var/lib/upes-ecs /var/spool/asterisk/monitor/upes-ecs "$SND_DST" 2>/dev/null || true

#--------------------------------------------------------------------------------
# 7. callout / roll-call groups (idempotent)
#--------------------------------------------------------------------------------
log "$(msg sec_groups)"
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
  msg groups_present
fi
chown -R asterisk:asterisk "$GR" 2>/dev/null || true

#--------------------------------------------------------------------------------
# 8. Status/control API in a Python venv (FastAPI on 127.0.0.1:8090)
#--------------------------------------------------------------------------------
log "$(msg sec_api)"
VENV=/opt/upes-ecs/venv
if [ ! -x "$VENV/bin/python" ]; then
  python3 -m venv "$VENV" || die "$(msg err_venv)"
fi
"$VENV/bin/python" -m pip install --quiet --upgrade pip >/dev/null 2>&1 || \
  msg pip_upgrade_skip
"$VENV/bin/python" -m pip install --quiet fastapi "uvicorn[standard]" >/dev/null 2>&1 || \
  msg pip_install_skip
cp "$REPO_ROOT/api/upes_api.py" /opt/upes-ecs/api/upes_api.py
sed -i 's/\r$//' /opt/upes-ecs/api/upes_api.py
# directory.json feeds the API's family/safety directory.
[ -f "$REPO_ROOT/Console/directory.json" ] && \
  cp "$REPO_ROOT/Console/directory.json" /opt/upes-ecs/family/directory.json

#--------------------------------------------------------------------------------
# 9. Console (static server + /api proxy on :8080)
#--------------------------------------------------------------------------------
log "$(msg sec_console)"
CONSOLE_DST=/opt/upes-ecs/console
mkdir -p "$CONSOLE_DST"
if [ -d "$REPO_ROOT/Console" ]; then
  for item in index.html app.js app.css tv.js tv.css tv-ops.html tv-safety.html \
              ui-i18n.js region.json directory.json languages.json status.json; do
    [ -f "$REPO_ROOT/Console/$item" ] && cp "$REPO_ROOT/Console/$item" "$CONSOLE_DST/"
  done
  [ -d "$REPO_ROOT/Console/ui-lang" ] && { mkdir -p "$CONSOLE_DST/ui-lang"; cp -a "$REPO_ROOT/Console/ui-lang/." "$CONSOLE_DST/ui-lang/"; }
fi
# The Linux Console server (stdlib http.server) comes from the Jetson deploy dir.
cp "$REPO_ROOT/deploy/jetson/serve-console.py" /opt/upes-ecs/serve-console.py
sed -i 's/\r$//' /opt/upes-ecs/serve-console.py
chmod +x /opt/upes-ecs/serve-console.py

# region.json: reflect the active language (code + native name from languages.json).
log "$(msg sec_region "$LANGUAGE")"
"$VENV/bin/python" - "$LANGUAGE" "$REPO_ROOT/i18n/languages.json" "$CONSOLE_DST/region.json" <<'PYEOF' || msg region_skip
import json, sys, datetime
code, langs_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
name, native = code, code
try:
    with open(langs_path, encoding="utf-8") as fh:
        for L in json.load(fh).get("languages", []):
            if L.get("code") == code:
                name = L.get("name", code); native = L.get("native", code); break
except Exception:
    pass
if code == "en":
    name, native = "English", "English"
rec = {
    "schema": "upes-ecs.region/v1",
    "language": code, "languageName": name, "native": native,
    "prompts": "packed", "source": "local",
    "deployedAt": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
}
with open(out_path, "w", encoding="utf-8") as fh:
    json.dump(rec, fh, ensure_ascii=False, indent=2)
print("  region.json:", code, "/", native)
PYEOF
chown -R asterisk:asterisk /opt/upes-ecs/console 2>/dev/null || true

#--------------------------------------------------------------------------------
# 10. Service wiring: systemd units OR the foreground launcher
#--------------------------------------------------------------------------------
if [ "$HAVE_SYSTEMD" -eq 1 ]; then
  log "$(msg sec_systemd)"

  # API unit -> venv python
  cat > /etc/systemd/system/upes-api.service <<EOF
[Unit]
Description=UPES-ECS local status/control API (FastAPI/uvicorn on 127.0.0.1:8090)
After=network.target asterisk.service
Wants=asterisk.service

[Service]
Type=simple
User=root
ExecStart=$VENV/bin/python /opt/upes-ecs/api/upes_api.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

  # Console unit
  cat > /etc/systemd/system/serve-console.service <<'EOF'
[Unit]
Description=UPES-ECS Operations Console (static server + /api proxy on :8080)
After=network.target upes-api.service
Wants=upes-api.service

[Service]
Type=simple
User=root
Environment=UPES_CONSOLE_ROOT=/opt/upes-ecs/console
Environment=UPES_CONSOLE_PORT=8080
Environment=UPES_API_BASE=http://127.0.0.1:8090
ExecStart=/usr/bin/python3 /opt/upes-ecs/serve-console.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

  # Asterisk crash auto-recovery drop-in.
  mkdir -p /etc/systemd/system/asterisk.service.d
  printf '[Service]\nRestart=always\nRestartSec=3\n' > /etc/systemd/system/asterisk.service.d/restart.conf

  systemctl daemon-reload
  systemctl enable asterisk       >/dev/null 2>&1 || true
  systemctl enable upes-api       >/dev/null 2>&1 || true
  systemctl enable serve-console  >/dev/null 2>&1 || true

  if [ "$DO_START" -eq 1 ]; then
    systemctl restart asterisk      >/dev/null 2>&1 || { msg sd_ast_fail; asterisk -g 2>/dev/null || true; }
    systemctl restart upes-api      >/dev/null 2>&1 || true
    systemctl restart serve-console >/dev/null 2>&1 || true
  fi
else
  log "$(msg sec_foreground)"
  cp "$SCRIPT_DIR/run-foreground.sh" /opt/upes-ecs/run-foreground.sh
  sed -i 's/\r$//' /opt/upes-ecs/run-foreground.sh
  chmod +x /opt/upes-ecs/run-foreground.sh
  msg fg_start_hint
fi

#--------------------------------------------------------------------------------
# 11. Summary
#--------------------------------------------------------------------------------
sleep 2
echo "-------------------------------------------------------------------"
if [ "$DO_START" -eq 1 ] && [ "$HAVE_SYSTEMD" -eq 1 ]; then
  asterisk -rx "core show version" 2>/dev/null | head -1 || msg ast_not_responding
fi
echo ""
msg summary_installed
msg summary_dial
msg summary_console "$LAN_IP"
msg summary_api
msg summary_register "$LAN_IP"
msg summary_language "$LANGUAGE"
echo ""
msg summary_adduser1
msg summary_adduser2
msg summary_adduser3
echo "UPES-ECS-LINUX-SETUP-DONE"
