#!/usr/bin/env bash
#
# install-macos.sh -- native, single-node UPES-ECS install for macOS.
#
# Asterisk runs NATIVELY via Homebrew (no QEMU, no HA). Supports both
# Apple Silicon (arm64, brew prefix /opt/homebrew) and Intel (x86_64,
# /usr/local). It mirrors the proven deploy/jetson/install-jetson.sh shape,
# swapping apt->brew and systemd->launchd, generalised to ONE Mac node.
#
# It:
#   * runs preflight checks (macOS version, arch, required commands, disk),
#   * detects the Homebrew prefix (arm64 vs Intel),
#   * ensures Homebrew + `brew install asterisk python@3`,
#   * lays down $(brew --prefix)/etc/asterisk from the repo deploy/asterisk
#     (backing up any existing config first),
#   * sets external_media_address / external_signaling_address to the Mac's
#     LAN IP (ipconfig getifaddr en0, with a sane fallback),
#   * installs the pre-generated sounds incl. the chosen language pack,
#   * sets up the FastAPI status API in a Python venv and the Console,
#   * installs launchd LaunchAgents for asterisk / api / console, plus a
#     foreground fallback (run-foreground.sh),
#   * prints the "dial 111 / Console / phones" summary.
#
# It is idempotent, hardened (set -euo pipefail + error trap), and lint-clean
# (bash -n + shellcheck). It has been STATIC-VALIDATED on a non-macOS host; it
# MUST still be run on a real Mac to confirm airtight (see README-MACOS.md).
#
# Operator messages are LOCALIZED: the installer detects the macOS operator
# locale (defaults read -g AppleLocale, then $LC_ALL/$LANG) and prints in that
# language when a catalog exists, else English. Override with --lang <code>.
# NOTE: --lang controls the INSTALLER'S OWN messages; --language controls the
# deployed PBX voice + Console language (two independent settings).
#
# Usage:
#   ./install-macos.sh [--language <voice-code>] [--lang <ui-code>] [--lan-ip <ip>]
#     --language <code>  PBX voice + Console language pack (en hi te ml ur ne ...)
#     --lang <code>      installer message language (en hi te ml ur ne es fr de pt ar)
#     --lan-ip <ip>      pin the advertised LAN IP (skip auto-detect)
#     -h | --help        show this help
#
set -euo pipefail

#--------------------------------------------------------------------------------
# 0. Args + locations
#--------------------------------------------------------------------------------
LANGUAGE="en"          # PBX voice + Console pack (unchanged semantics)
LAN_IP=""
MSG_LANG="en"          # installer UI language (resolved below)
MSG_LANG_OVERRIDE=""   # from --lang
MIN_MACOS=11           # tested-minimum macOS major (Big Sur)
MIN_DISK_MB=1500       # brew asterisk + python + venv + fastapi headroom
WORK_TMP=""            # scratch dir, cleaned on exit

# --- environment facts (cheap, needed by preflight + guidance) ---------------
UNAME_S="$(uname -s 2>/dev/null || echo unknown)"
ARCH="$(uname -m 2>/dev/null || echo unknown)"
IS_DARWIN=0; [ "$UNAME_S" = "Darwin" ] && IS_DARWIN=1
if [ "$ARCH" = "arm64" ]; then GUESS_PREFIX="/opt/homebrew"; else GUESS_PREFIX="/usr/local"; fi

# This script lives at <repo>/deploy/macos/install-macos.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CATALOG_DIR="$SCRIPT_DIR/i18n"

#--------------------------------------------------------------------------------
# 0a. Localization: message catalog + msg() router
#     _msg_en is the GUARANTEED inline English fallback (never depends on files).
#     Extra languages load from i18n/<code>.sh, each defining _msg_<code>.
#     Any key missing in a language falls back to English; missing key -> the key.
#--------------------------------------------------------------------------------
_msg_en() {
  case "$1" in
    warn_not_macos)   printf '%s' 'WARNING: this is not macOS (uname=%s). Continuing for static/dry checks only.';;
    err_no_astsrc)    printf '%s' 'cannot find %s -- run from inside the extracted repo/payload';;
    err_no_api)       printf '%s' 'cannot find %s -- payload layout unexpected';;
    unknown_arg)      printf '%s' 'Unknown argument: %s';;
    err_trap)         printf '%s' 'install-macos.sh failed at line %s (exit %s). Nothing was force-started; fix the cause and re-run (the script is idempotent).';;
    msg_lang_selected) printf '%s' 'installer language: %s';;
    # --- preflight -----------------------------------------------------------
    hdr_preflight)    printf '%s' 'preflight checks';;
    pf_macos_ver)     printf '%s' 'macOS version: %s';;
    pf_macos_old)     printf '%s' 'WARNING: macOS %s is older than the tested minimum (%s) -- proceeding, but untested.';;
    pf_arch)          printf '%s' 'architecture: %s (Homebrew prefix will be %s)';;
    pf_missing_cmd)   printf '%s' 'required command not found: %s';;
    pf_missing_fatal) printf '%s' 'missing required command(s) -- install them (e.g. Xcode Command Line Tools: xcode-select --install) and re-run';;
    pf_cmds_ok)       printf '%s' 'required commands present';;
    pf_disk)          printf '%s' 'free disk space: %s MB';;
    pf_disk_low)      printf '%s' 'WARNING: low free disk space (%s MB) -- brew asterisk + python + venv need ~%s MB.';;
    pf_sudo_note)     printf '%s' 'some steps use sudo (creating /opt/upes-ecs and /var/lib/upes-ecs) -- you may be prompted for your login password once.';;
    # --- homebrew ------------------------------------------------------------
    hdr_homebrew)     printf '%s' 'Homebrew';;
    err_brew_missing) printf '%s' 'ERROR: Homebrew (brew) is not installed / not on PATH.\nInstall it first (do NOT let this script silently curl|bash your shell):\n\n  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"\n\nThen, on Apple Silicon, add brew to your PATH:\n  eval "$(%s/bin/brew shellenv)"\n\nRe-run this installer afterwards.\n';;
    brew_prefix)      printf '%s' 'brew prefix: %s  (arch %s)';;
    hdr_brew_install) printf '%s' 'brew install asterisk python@3';;
    brew_install_warn) printf '%s' '(brew install reported an issue -- if asterisk/python3 are already present, continuing)';;
    asterisk_bin)     printf '%s' 'asterisk: %s';;
    python_bin)       printf '%s' 'python3:  %s';;
    # --- dirs / config -------------------------------------------------------
    hdr_state_dirs)   printf '%s' 'state + install dirs (sudo)';;
    state_creating)   printf '%s' 'creating %s and %s (may prompt for your password)';;
    no_helper_scripts) printf '%s' '(no scripts/*.sh in payload -- skipping helper copy)';;
    hdr_ast_runtime)  printf '%s' 'asterisk runtime dirs + asterisk.conf';;
    backed_up_cfg)    printf '%s' 'backed up existing config -> %s';;
    hdr_ast_cfg)      printf '%s' 'asterisk config';;
    cfg_missing_accounts) printf '%s' '!! %s missing -- NO SIP accounts will be provisioned (add users post-install)';;
    cfg_optional_skip) printf '%s' '(optional %s not present, skipped)';;
    accounts_stub)    printf '%s' 'pjsip_accounts.conf is an empty stub -- add SIP users after install (README-MACOS.md)';;
    paging_pin)       printf '%s' 'generated paging PIN -> %s';;
    # --- addressing ----------------------------------------------------------
    hdr_ext_addr)     printf '%s' 'external media/signaling address';;
    lan_fallback)     printf '%s' 'could not auto-detect a LAN IP -- using fallback %s (override with --lan-ip)';;
    lan_ip)           printf '%s' 'LAN IP: %s';;
    # --- prompts -------------------------------------------------------------
    hdr_prompts)      printf '%s' 'voice prompts (language=%s)';;
    lang_no_pack)     printf '%s' '!! requested language %s has no packed pack -- falling back to en';;
    prompts_seed)     printf '%s' '(no en/upes-ecs prompts found -- seeding placeholders)';;
    # --- groups / api / console ---------------------------------------------
    hdr_groups)       printf '%s' 'callout / roll-call groups';;
    groups_present)   printf '%s' '(groups already present -- leaving in place)';;
    hdr_api)          printf '%s' 'local status API (FastAPI :8090)';;
    err_venv)         printf '%s' 'failed to create venv at %s (is python@3 installed?)';;
    pip_warn)         printf '%s' '(fastapi/uvicorn install failed/offline -- API may not start until deps are present)';;
    hdr_console)      printf '%s' 'Console web server (:8080)';;
    # --- env / launchd -------------------------------------------------------
    hdr_env)          printf '%s' 'env file + foreground fallback';;
    hdr_launchd)      printf '%s' 'launchd agents (~/Library/LaunchAgents)';;
    launchd_load_fail) printf '%s' '(could not launchctl-load %s -- use the foreground fallback instead)';;
    launchctl_missing) printf '%s' '(launchctl not found -- not macOS? use run-foreground.sh)';;
    ast_not_answering) printf '%s' '(asterisk not answering yet -- check %s)';;
    # --- summary -------------------------------------------------------------
    gatekeeper_note)  printf '%s' 'Unsigned build: if macOS quarantines the installer, run  xattr -dr com.apple.quarantine <file>  (see README-MACOS.md "Gatekeeper").';;
    summary_complete) printf '%s' 'UPES-ECS macOS install complete.';;
    sum_emergency)    printf '%s' 'emergency (ERT queue)';;
    sum_phones)       printf '%s' 'register to %s:5060  (WebSocket app: ws://%s:8088/ws)';;
    sum_services)     printf '%s' 'Services (launchd LaunchAgents):';;
    sum_foreground)   printf '%s' 'Foreground fallback (no launchd):';;
    sum_add_users)    printf '%s' 'Add SIP users post-install (the shipped accounts file is a clean stub):';;
    sum_see_readme)   printf '%s' 'see README-MACOS.md "Add a user".';;
    *) return 1;;
  esac
}

# Load an external catalog for the chosen UI language (defines _msg_<code>).
# Best-effort: a missing/broken file simply leaves English in place.
load_catalog() {
  local code="$1"
  [ "$code" = "en" ] && return 0
  if [ -f "$CATALOG_DIR/$code.sh" ]; then
    # shellcheck source=/dev/null
    . "$CATALOG_DIR/$code.sh" 2>/dev/null || true
  fi
}

# msg <key> [printf-args...] -> localized, formatted text (no trailing newline).
msg() {
  local key="$1"; shift
  local fn="_msg_${MSG_LANG}" tmpl=""
  if declare -f "$fn" >/dev/null 2>&1; then
    tmpl="$("$fn" "$key" 2>/dev/null || true)"
  fi
  [ -n "$tmpl" ] || tmpl="$(_msg_en "$key" 2>/dev/null || true)"
  [ -n "$tmpl" ] || tmpl="$key"
  # shellcheck disable=SC2059  # template is a controlled format string
  printf "$tmpl" "$@"
}

#--------------------------------------------------------------------------------
# 0b. Output helpers + traps
#--------------------------------------------------------------------------------
log()  { echo "== $* =="; }
info() { echo "   $*"; }
die()  { trap - ERR; echo "ERROR: $*" >&2; exit 1; }

# key-based variants: resolve via msg() then print.
logk()  { log  "$(msg "$@")"; }
infok() { info "$(msg "$@")"; }
diek()  { die  "$(msg "$@")"; }

usage() {
  sed -n '34,39p' "$0"
  trap - ERR
  exit "${1:-0}"
}

cleanup() {
  [ -n "${WORK_TMP:-}" ] && [ -d "$WORK_TMP" ] && rm -rf "$WORK_TMP" 2>/dev/null || true
}
err_trap() {
  local code="$1" line="$2"
  trap - ERR
  msg err_trap "$line" "$code" >&2
  echo "" >&2
}
trap 'err_trap "$?" "$LINENO"' ERR
trap cleanup EXIT

#--------------------------------------------------------------------------------
# 0c. Parse args
#--------------------------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --language) LANGUAGE="${2:-en}"; shift 2 ;;
    --lang)     MSG_LANG_OVERRIDE="${2:-}"; shift 2 ;;
    --lan-ip)   LAN_IP="${2:-}";     shift 2 ;;
    -h|--help)  usage 0 ;;
    *) echo "$(msg unknown_arg "$1")" >&2; usage 1 ;;
  esac
done

#--------------------------------------------------------------------------------
# 0d. Resolve the installer UI language (override > AppleLocale > LC_ALL/LANG)
#--------------------------------------------------------------------------------
SUPPORTED_MSG_LANGS=" en hi te ml ur ne es fr de pt ar "

normalize_lang() {
  # e.g. en_IN.UTF-8 -> en ; hi-IN -> hi ; pt_BR@euro -> pt
  local raw="$1" code
  code="${raw%%.*}"      # drop .UTF-8
  code="${code%%@*}"     # drop @modifier
  code="$(printf '%s' "$code" | tr 'A-Z' 'a-z' | tr '-' '_')"
  code="${code%%_*}"     # primary subtag only
  printf '%s' "$code"
}

detect_msg_lang() {
  local raw="" code
  if [ -n "$MSG_LANG_OVERRIDE" ]; then
    raw="$MSG_LANG_OVERRIDE"
  elif [ "$IS_DARWIN" = "1" ] && command -v defaults >/dev/null 2>&1; then
    raw="$(defaults read -g AppleLocale 2>/dev/null || true)"
  fi
  [ -n "$raw" ] || raw="${LC_ALL:-${LANG:-en}}"
  code="$(normalize_lang "$raw")"
  [ -n "$code" ] || code="en"
  # Only accept codes we actually ship a catalog for; else English.
  case "$SUPPORTED_MSG_LANGS" in
    *" $code "*) printf '%s' "$code" ;;
    *)           printf '%s' "en" ;;
  esac
}

MSG_LANG="$(detect_msg_lang)"
load_catalog "$MSG_LANG"
infok msg_lang_selected "$MSG_LANG"

#--------------------------------------------------------------------------------
# 0e. Payload sanity + platform note
#--------------------------------------------------------------------------------
[ "$IS_DARWIN" = "1" ] || echo "   $(msg warn_not_macos "$UNAME_S")" >&2

ASTSRC="$REPO_ROOT/deploy/asterisk"
[ -d "$ASTSRC" ]        || diek err_no_astsrc "$ASTSRC"
[ -d "$REPO_ROOT/api" ] || diek err_no_api "$REPO_ROOT/api"

# The invoking (non-root) user. LaunchAgents run in THIS user's context, so all
# state dirs are chowned to them even though we sudo-create the system paths.
RUN_USER="$(id -un)"
RUN_HOME="$HOME"

# Scratch dir (registered for cleanup on exit).
WORK_TMP="$(mktemp -d "${TMPDIR:-/tmp}/upes-ecs-install.XXXXXX" 2>/dev/null || true)"

#--------------------------------------------------------------------------------
# 0f. Preflight checks (actionable, non-fatal except missing core commands)
#--------------------------------------------------------------------------------
logk hdr_preflight
if [ "$IS_DARWIN" = "1" ] && command -v sw_vers >/dev/null 2>&1; then
  MACOS_VER="$(sw_vers -productVersion 2>/dev/null || echo '?')"
  infok pf_macos_ver "$MACOS_VER"
  MACOS_MAJ="${MACOS_VER%%.*}"
  case "$MACOS_MAJ" in
    ''|*[!0-9]*) : ;;
    *) [ "$MACOS_MAJ" -lt "$MIN_MACOS" ] && infok pf_macos_old "$MACOS_VER" "$MIN_MACOS" ;;
  esac
fi
infok pf_arch "$ARCH" "$GUESS_PREFIX"

# Required commands (fatal if any core tool is missing).
MISSING_CMDS=""
for c in sed grep awk id mkdir cp; do
  command -v "$c" >/dev/null 2>&1 || MISSING_CMDS="$MISSING_CMDS $c"
done
if [ -n "$MISSING_CMDS" ]; then
  for c in $MISSING_CMDS; do infok pf_missing_cmd "$c"; done
  diek pf_missing_fatal
fi
infok pf_cmds_ok

# Free disk space (best-effort; warn only).
DISK_MB="$(df -Pk / 2>/dev/null | awk 'NR==2 {printf "%d", int($4/1024)}' || true)"
if [ -n "$DISK_MB" ]; then
  infok pf_disk "$DISK_MB"
  case "$DISK_MB" in
    ''|*[!0-9]*) : ;;
    *) [ "$DISK_MB" -lt "$MIN_DISK_MB" ] && infok pf_disk_low "$DISK_MB" "$MIN_DISK_MB" ;;
  esac
fi
infok pf_sudo_note

#--------------------------------------------------------------------------------
# 1. Homebrew prefix detection (arm64 /opt/homebrew vs Intel /usr/local)
#--------------------------------------------------------------------------------
logk hdr_homebrew
if command -v brew >/dev/null 2>&1; then
  PREFIX="$(brew --prefix)"
else
  # brew not on PATH yet -- print guidance and stop (never silently curl|bash).
  PREFIX="$GUESS_PREFIX"
  msg err_brew_missing "$PREFIX" >&2
  trap - ERR
  exit 1
fi
infok brew_prefix "$PREFIX" "$ARCH"

BREW="$PREFIX/bin/brew"
[ -x "$BREW" ] || BREW="brew"

#--------------------------------------------------------------------------------
# 2. Packages (native -- no QEMU)
#--------------------------------------------------------------------------------
logk hdr_brew_install
# Idempotent: brew is a no-op (or upgrade check) if already installed.
"$BREW" install asterisk python@3 || infok brew_install_warn

ASTERISK_BIN="$PREFIX/sbin/asterisk"
[ -x "$ASTERISK_BIN" ] || ASTERISK_BIN="$(command -v asterisk || echo "$PREFIX/sbin/asterisk")"
PY3="$PREFIX/bin/python3"
[ -x "$PY3" ] || PY3="$(command -v python3 || echo python3)"
infok asterisk_bin "$ASTERISK_BIN"
infok python_bin "$PY3"

#--------------------------------------------------------------------------------
# 3. State + install dirs (match the API's hard-coded paths exactly).
#    upes_api.py references /opt/upes-ecs and /var/lib/upes-ecs (read-only source
#    we must NOT edit), so we create those and chown to the LaunchAgent user.
#--------------------------------------------------------------------------------
logk hdr_state_dirs
UPES_OPT="/opt/upes-ecs"
UPES_STATE="/var/lib/upes-ecs"
NEED_SUDO=""
if [ ! -w /opt ] || [ ! -w /var/lib ]; then NEED_SUDO="sudo"; fi
infok state_creating "$UPES_OPT" "$UPES_STATE"
$NEED_SUDO mkdir -p \
  "$UPES_OPT/api" "$UPES_OPT/groups" "$UPES_OPT/family" "$UPES_OPT/console" \
  "$UPES_STATE/incidents" "$UPES_STATE/alerts" "$UPES_STATE/security" \
  "$UPES_STATE/paging" "$UPES_STATE/conference" "$UPES_STATE/retention" \
  "$UPES_STATE/rollcall" "$UPES_STATE/shift" "$UPES_STATE/safety" \
  "$UPES_STATE/location"
# Own them as the running user so the (user-context) LaunchAgents can write.
$NEED_SUDO chown -R "$RUN_USER" "$UPES_OPT" "$UPES_STATE"

# Helper scripts (repo scripts/*.sh) -- the API shells out to some of these.
if compgen -G "$REPO_ROOT/scripts/*.sh" >/dev/null 2>&1; then
  cp "$REPO_ROOT"/scripts/*.sh "$UPES_OPT/"
  chmod +x "$UPES_OPT"/*.sh 2>/dev/null || true
else
  infok no_helper_scripts
fi

#--------------------------------------------------------------------------------
# 4. Asterisk runtime dirs under the brew prefix + a coherent asterisk.conf
#--------------------------------------------------------------------------------
logk hdr_ast_runtime
ASTETC="$PREFIX/etc/asterisk"
ASTDATA="$PREFIX/share/asterisk"           # astdatadir -> sounds live under here
ASTVARLIB="$PREFIX/var/lib/asterisk"
ASTSPOOL="$PREFIX/var/spool/asterisk"
ASTRUN="$PREFIX/var/run/asterisk"
ASTLOG="$PREFIX/var/log/asterisk"
ASTMOD="$PREFIX/lib/asterisk/modules"
mkdir -p "$ASTETC" "$ASTDATA/sounds" "$ASTVARLIB/keys" "$ASTVARLIB/astdb" \
         "$ASTSPOOL/monitor/upes-ecs" "$ASTRUN" "$ASTLOG/cdr-csv"

# Back up any existing etc/asterisk before we overwrite it.
if [ -d "$ASTETC" ] && compgen -G "$ASTETC/*.conf" >/dev/null 2>&1; then
  BK="$ASTETC.bak.$(date +%Y%m%d%H%M%S)"
  cp -a "$ASTETC" "$BK"
  infok backed_up_cfg "$BK"
fi

# Write a self-contained asterisk.conf that points every directory under the
# brew prefix (defaults point at /var/... which does not exist on macOS), and
# enable live_dangerously (the emergency dialplan uses System()/privileged apps).
cat > "$ASTETC/asterisk.conf" <<EOF
; Generated by install-macos.sh -- brew-prefix-relative directories.
[directories](!)
astetcdir    => $ASTETC
astmoddir    => $ASTMOD
astvarlibdir => $ASTVARLIB
astdbdir     => $ASTVARLIB/astdb
astkeydir    => $ASTVARLIB/keys
astdatadir   => $ASTDATA
astagidir    => $ASTVARLIB/agi-bin
astspooldir  => $ASTSPOOL
astrundir    => $ASTRUN
astlogdir    => $ASTLOG
astsbindir   => $PREFIX/sbin

[options]
live_dangerously = yes
EOF

#--------------------------------------------------------------------------------
# 5. Asterisk config from the repo checkout (mirrors install-jetson.sh copy set)
#--------------------------------------------------------------------------------
logk hdr_ast_cfg
for f in extensions.conf pjsip.conf pjsip_accounts.conf queues.conf voicemail.conf \
         rtp.conf confbridge.conf http.conf fail2ban-asterisk.conf; do
  if [ -f "$ASTSRC/$f" ]; then
    cp "$ASTSRC/$f" "$ASTETC/"
    /usr/bin/sed -i '' 's/\r$//' "$ASTETC/$f" 2>/dev/null || sed -i 's/\r$//' "$ASTETC/$f"
  elif [ "$f" = "pjsip_accounts.conf" ]; then
    infok cfg_missing_accounts "$f"
  else
    infok cfg_optional_skip "$f"
  fi
done
# Extra dialplan includes live under config/ in this repo.
for f in extensions_custom.conf extensions_features.conf \
         extensions_features_wiring.conf extensions_aihelpline.conf; do
  if [ -f "$REPO_ROOT/config/$f" ]; then
    cp "$REPO_ROOT/config/$f" "$ASTETC/"
    /usr/bin/sed -i '' 's/\r$//' "$ASTETC/$f" 2>/dev/null || sed -i 's/\r$//' "$ASTETC/$f"
  fi
done

# The shipped pjsip_accounts.conf is a CLEAN STUB (no secrets). If it has no
# real accounts, warn -- users are added post-install (see README-MACOS.md).
if ! grep -qE '^\[[0-9]+\]\(endpoint-tpl\)' "$ASTETC/pjsip_accounts.conf" 2>/dev/null; then
  infok accounts_stub
fi

# All-campus paging PIN: replace placeholder with a random one (idempotent).
if [ -f "$ASTETC/extensions_custom.conf" ] && \
   grep -q '^PAGING_PIN_700=CHANGE-ME' "$ASTETC/extensions_custom.conf"; then
  PIN="$(( (RANDOM * 32768 + RANDOM) % 900000 + 100000 ))"
  /usr/bin/sed -i '' "s/^PAGING_PIN_700=.*/PAGING_PIN_700=${PIN}/" "$ASTETC/extensions_custom.conf" 2>/dev/null || \
    sed -i "s/^PAGING_PIN_700=.*/PAGING_PIN_700=${PIN}/" "$ASTETC/extensions_custom.conf"
  echo "PAGING_PIN_700=${PIN}" > "$UPES_STATE/generated-secrets.txt"
  infok paging_pin "$UPES_STATE/generated-secrets.txt"
fi

#--------------------------------------------------------------------------------
# 6. LAN IP -> external_media_address / external_signaling_address
#--------------------------------------------------------------------------------
logk hdr_ext_addr
if [ -z "$LAN_IP" ]; then
  # macOS: primary Wi-Fi/Ethernet is usually en0; fall back en1..en7, then hostname.
  for ifc in en0 en1 en2 en3 en4 en5 en6 en7; do
    if command -v ipconfig >/dev/null 2>&1; then
      LAN_IP="$(ipconfig getifaddr "$ifc" 2>/dev/null || true)"
    fi
    [ -n "$LAN_IP" ] && break
  done
fi
if [ -z "$LAN_IP" ]; then
  # Last-resort fallbacks that work off-Darwin too (dry runs).
  LAN_IP="$(ipconfig getifaddr en0 2>/dev/null || true)"
  [ -n "$LAN_IP" ] || LAN_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
  [ -n "$LAN_IP" ] || LAN_IP="127.0.0.1"
  infok lan_fallback "$LAN_IP"
fi
infok lan_ip "$LAN_IP"

set_pjsip_addr() {
  # $1 = key (external_media_address | external_signaling_address)
  local key="$1"
  if grep -qE "^;?${key}=" "$ASTETC/pjsip.conf"; then
    /usr/bin/sed -i '' -E "s|^;?${key}=.*|${key}=${LAN_IP}|" "$ASTETC/pjsip.conf" 2>/dev/null || \
      sed -i -E "s|^;?${key}=.*|${key}=${LAN_IP}|" "$ASTETC/pjsip.conf"
  else
    /usr/bin/sed -i '' -E "/^\[transport-udp\]/,/^\[/ s|^(bind=.*)$|\1\n${key}=${LAN_IP}|" "$ASTETC/pjsip.conf" 2>/dev/null || \
      sed -i -E "/^\[transport-udp\]/,/^\[/ s|^(bind=.*)$|\1\n${key}=${LAN_IP}|" "$ASTETC/pjsip.conf"
  fi
}
set_pjsip_addr external_media_address
set_pjsip_addr external_signaling_address

#--------------------------------------------------------------------------------
# 7. Voice prompts (pre-generated sounds) incl. the chosen language pack
#--------------------------------------------------------------------------------
logk hdr_prompts "$LANGUAGE"
SND_DST="$ASTDATA/sounds"
mkdir -p "$SND_DST/en"
if [ -d "$ASTSRC/sounds/en" ]; then
  cp -a "$ASTSRC/sounds/en/." "$SND_DST/en/"
fi
# Install every packed language pack (sounds/lang/<code> -> sounds/<code>), and
# make sure the REQUESTED language is present.
if [ -d "$ASTSRC/sounds/lang" ]; then
  for langdir in "$ASTSRC"/sounds/lang/*/; do
    [ -d "$langdir" ] || continue
    code="$(basename "$langdir")"
    mkdir -p "$SND_DST/$code"
    cp -a "${langdir}." "$SND_DST/$code/"
  done
fi
if [ "$LANGUAGE" != "en" ] && [ ! -d "$SND_DST/$LANGUAGE" ]; then
  infok lang_no_pack "$LANGUAGE"
fi

# Never leave a silent PBX: if en/upes-ecs prompts are missing, seed placeholders.
PD="$SND_DST/en/upes-ecs"; mkdir -p "$PD"
if ! compgen -G "$PD/*.wav" >/dev/null 2>&1 && ! compgen -G "$PD/*.gsm" >/dev/null 2>&1; then
  infok prompts_seed
  SRCG=""
  for g in "$SND_DST"/en/*.gsm; do [ -e "$g" ] && { SRCG="$g"; break; }; done
  if [ -n "$SRCG" ]; then
    for p in emergency-preanswer emergency-voicemail-prompt drill-prompt \
             queue-paused queue-resumed not-authorized queue-hold; do
      cp -f "$SRCG" "$PD/$p.gsm"
    done
  fi
fi

# Point Console/region.json at the chosen language (drives the dashboard chip).
CON_SRC="$REPO_ROOT/Console"
if [ -f "$CON_SRC/region.json" ]; then
  /usr/bin/sed -i '' -E "s/\"language\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"language\": \"${LANGUAGE}\"/" \
    "$CON_SRC/region.json" 2>/dev/null || \
    sed -i -E "s/\"language\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"language\": \"${LANGUAGE}\"/" \
    "$CON_SRC/region.json" 2>/dev/null || true
fi

#--------------------------------------------------------------------------------
# 8. callout / roll-call groups (mirrors install-jetson.sh)
#--------------------------------------------------------------------------------
logk hdr_groups
GR="$UPES_OPT/groups"
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
  infok groups_present
fi

#--------------------------------------------------------------------------------
# 9. Local status/control API (FastAPI on :8090) in a Python venv
#--------------------------------------------------------------------------------
logk hdr_api
VENV="$UPES_OPT/venv"
if [ ! -x "$VENV/bin/python3" ]; then
  "$PY3" -m venv "$VENV" || diek err_venv "$VENV"
fi
"$VENV/bin/python3" -m pip install --quiet --upgrade pip >/dev/null 2>&1 || true
"$VENV/bin/python3" -m pip install --quiet fastapi 'uvicorn[standard]' || infok pip_warn
cp "$REPO_ROOT/api/upes_api.py" "$UPES_OPT/api/upes_api.py"
# directory.json feeds the API family/safety directory.
[ -f "$CON_SRC/directory.json" ] && cp "$CON_SRC/directory.json" "$UPES_OPT/family/directory.json"

#--------------------------------------------------------------------------------
# 10. Console (stdlib static server + /api proxy on :8080)
#--------------------------------------------------------------------------------
logk hdr_console
CONSOLE_DST="$UPES_OPT/console"
mkdir -p "$CONSOLE_DST"
if [ -d "$CON_SRC" ]; then
  for item in index.html app.js app.css tv.js tv.css tv-ops.html tv-safety.html \
              ui-i18n.js region.json directory.json languages.json status.json; do
    [ -f "$CON_SRC/$item" ] && cp "$CON_SRC/$item" "$CONSOLE_DST/"
  done
  [ -d "$CON_SRC/ui-lang" ] && { mkdir -p "$CONSOLE_DST/ui-lang"; cp -a "$CON_SRC/ui-lang/." "$CONSOLE_DST/ui-lang/"; }
fi
cp "$SCRIPT_DIR/serve-console.py" "$UPES_OPT/serve-console.py"
chmod +x "$UPES_OPT/serve-console.py"

#--------------------------------------------------------------------------------
# 11. Shared env file + foreground fallback
#--------------------------------------------------------------------------------
logk hdr_env
cat > "$UPES_OPT/macos.env" <<EOF
# Generated by install-macos.sh -- sourced by run-foreground.sh
BREW_PREFIX="$PREFIX"
ASTERISK_BIN="$ASTERISK_BIN"
ASTETC="$ASTETC"
UPES_OPT="$UPES_OPT"
VENV="$VENV"
CONSOLE_ROOT="$CONSOLE_DST"
LAN_IP="$LAN_IP"
LANGUAGE="$LANGUAGE"
export UPES_CONSOLE_ROOT="$CONSOLE_DST"
export UPES_CONSOLE_PORT="8080"
export UPES_API_BASE="http://127.0.0.1:8090"
EOF
cp "$SCRIPT_DIR/run-foreground.sh" "$UPES_OPT/run-foreground.sh"
chmod +x "$UPES_OPT/run-foreground.sh"

#--------------------------------------------------------------------------------
# 12. launchd LaunchAgents (asterisk / api / console)
#--------------------------------------------------------------------------------
logk hdr_launchd
LA_DIR="$RUN_HOME/Library/LaunchAgents"
mkdir -p "$LA_DIR"

write_plist() {
  # $1 label  $2 plist-path  ; remaining args = ProgramArguments
  local label="$1"; local path="$2"; shift 2
  {
    printf '<?xml version="1.0" encoding="UTF-8"?>\n'
    printf '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
    printf '<plist version="1.0"><dict>\n'
    printf '  <key>Label</key><string>%s</string>\n' "$label"
    printf '  <key>ProgramArguments</key><array>\n'
    for a in "$@"; do printf '    <string>%s</string>\n' "$a"; done
    printf '  </array>\n'
    printf '  <key>RunAtLoad</key><true/>\n'
    printf '  <key>KeepAlive</key><true/>\n'
    printf '  <key>StandardOutPath</key><string>%s/%s.out.log</string>\n' "$ASTLOG" "$label"
    printf '  <key>StandardErrorPath</key><string>%s/%s.err.log</string>\n' "$ASTLOG" "$label"
    printf '  <key>EnvironmentVariables</key><dict>\n'
    printf '    <key>PATH</key><string>%s/bin:%s/sbin:/usr/bin:/bin:/usr/sbin:/sbin</string>\n' "$PREFIX" "$PREFIX"
    printf '    <key>UPES_CONSOLE_ROOT</key><string>%s</string>\n' "$CONSOLE_DST"
    printf '    <key>UPES_CONSOLE_PORT</key><string>8080</string>\n'
    printf '    <key>UPES_API_BASE</key><string>http://127.0.0.1:8090</string>\n'
    printf '  </dict>\n'
    printf '</dict></plist>\n'
  } > "$path"
}

AST_PLIST="$LA_DIR/com.upes-ecs.asterisk.plist"
API_PLIST="$LA_DIR/com.upes-ecs.api.plist"
CON_PLIST="$LA_DIR/com.upes-ecs.console.plist"

# asterisk -f = no fork (launchd needs a foreground process to supervise).
write_plist "com.upes-ecs.asterisk" "$AST_PLIST" \
  "$ASTERISK_BIN" -f -C "$ASTETC/asterisk.conf"
write_plist "com.upes-ecs.api" "$API_PLIST" \
  "$VENV/bin/python3" "$UPES_OPT/api/upes_api.py"
write_plist "com.upes-ecs.console" "$CON_PLIST" \
  "$VENV/bin/python3" "$UPES_OPT/serve-console.py"

# Load them. Prefer modern `bootstrap gui/<uid>`; fall back to legacy `load`.
UID_NUM="$(id -u)"
load_agent() {
  local plist="$1" label="$2"
  if launchctl print "gui/$UID_NUM/$label" >/dev/null 2>&1; then
    launchctl bootout "gui/$UID_NUM/$label" >/dev/null 2>&1 || true
  fi
  launchctl bootstrap "gui/$UID_NUM" "$plist" 2>/dev/null || \
    launchctl load -w "$plist" 2>/dev/null || \
    infok launchd_load_fail "$label"
}
if command -v launchctl >/dev/null 2>&1; then
  load_agent "$AST_PLIST" "com.upes-ecs.asterisk"
  load_agent "$API_PLIST" "com.upes-ecs.api"
  load_agent "$CON_PLIST" "com.upes-ecs.console"
else
  infok launchctl_missing
fi

#--------------------------------------------------------------------------------
# 13. Summary
#--------------------------------------------------------------------------------
sleep 3 || true
echo "-------------------------------------------------------------------"
if command -v launchctl >/dev/null 2>&1; then
  "$ASTERISK_BIN" -rx "core show uptime" 2>/dev/null | head -1 || \
    infok ast_not_answering "$ASTLOG/com.upes-ecs.asterisk.err.log"
fi

printf '%s\n\n' "$(msg summary_complete)"
printf '  Dial 111 ....... %s\n' "$(msg sum_emergency)"
printf '  Console ........ http://%s:8080\n' "$LAN_IP"
printf '  API health ..... http://127.0.0.1:8090/health\n'
printf '  Phones (SIP) ... %s\n\n' "$(msg sum_phones "$LAN_IP" "$LAN_IP")"
cat <<EOF
  brew prefix .... $PREFIX
  Asterisk conf .. $ASTETC
  Sounds ......... $SND_DST   (language: $LANGUAGE)
  State .......... $UPES_STATE

EOF
printf '  %s\n' "$(msg sum_services)"
printf '    launchctl kickstart -k gui/%s/com.upes-ecs.asterisk\n' "$UID_NUM"
printf '    launchctl print gui/%s/com.upes-ecs.asterisk\n' "$UID_NUM"
printf '  %s\n' "$(msg sum_foreground)"
printf '    %s/run-foreground.sh\n\n' "$UPES_OPT"
printf '  %s\n' "$(msg sum_add_users)"
printf '    %s\n\n' "$(msg sum_see_readme)"
printf '  %s\n\n' "$(msg gatekeeper_note)"
echo "UPES-ECS-MACOS-SETUP-DONE"
