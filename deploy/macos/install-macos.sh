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
# It is idempotent and lint-clean (bash -n + shellcheck). It has been
# STATIC-VALIDATED on a non-macOS host; it MUST still be run on a real Mac to
# confirm airtight (see README-MACOS.md "validation status").
#
# Usage:
#   ./install-macos.sh [--language en|hi|te|ml|ur|ne|...] [--lan-ip <ip>]
#
set -euo pipefail

#--------------------------------------------------------------------------------
# 0. Args + locations
#--------------------------------------------------------------------------------
LANGUAGE="en"
LAN_IP=""

usage() {
  sed -n '2,33p' "$0"
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --language) LANGUAGE="${2:-en}"; shift 2 ;;
    --lan-ip)   LAN_IP="${2:-}";     shift 2 ;;
    -h|--help)  usage 0 ;;
    *) echo "Unknown argument: $1" >&2; usage 1 ;;
  esac
done

log()  { echo "== $* =="; }
info() { echo "   $*"; }
die()  { echo "ERROR: $*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || \
  echo "WARNING: this is not macOS (uname=$(uname -s)). Continuing for static/dry checks only." >&2

# This script lives at <repo>/deploy/macos/install-macos.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ASTSRC="$REPO_ROOT/deploy/asterisk"
[ -d "$ASTSRC" ]        || die "cannot find $ASTSRC -- run from inside the extracted repo/payload"
[ -d "$REPO_ROOT/api" ] || die "cannot find $REPO_ROOT/api -- payload layout unexpected"

# The invoking (non-root) user. LaunchAgents run in THIS user's context, so all
# state dirs are chowned to them even though we sudo-create the system paths.
RUN_USER="$(id -un)"
RUN_HOME="$HOME"

#--------------------------------------------------------------------------------
# 1. Homebrew prefix detection (arm64 /opt/homebrew vs Intel /usr/local)
#--------------------------------------------------------------------------------
log "Homebrew"
if command -v brew >/dev/null 2>&1; then
  PREFIX="$(brew --prefix)"
else
  # brew not on PATH yet -- guess by arch so we can still print guidance.
  if [ "$(uname -m)" = "arm64" ]; then PREFIX="/opt/homebrew"; else PREFIX="/usr/local"; fi
  cat >&2 <<EOF
ERROR: Homebrew (brew) is not installed / not on PATH.
Install it first (do NOT let this script silently curl|bash your shell):

  /bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

Then, on Apple Silicon, add brew to your PATH:
  eval "\$($PREFIX/bin/brew shellenv)"

Re-run this installer afterwards.
EOF
  exit 1
fi
info "brew prefix: $PREFIX  (arch $(uname -m))"

BREW="$PREFIX/bin/brew"
[ -x "$BREW" ] || BREW="brew"

#--------------------------------------------------------------------------------
# 2. Packages (native -- no QEMU)
#--------------------------------------------------------------------------------
log "brew install asterisk python@3"
# Idempotent: brew is a no-op (or upgrade check) if already installed.
"$BREW" install asterisk python@3 || \
  info "(brew install reported an issue -- if asterisk/python3 are already present, continuing)"

ASTERISK_BIN="$PREFIX/sbin/asterisk"
[ -x "$ASTERISK_BIN" ] || ASTERISK_BIN="$(command -v asterisk || echo "$PREFIX/sbin/asterisk")"
PY3="$PREFIX/bin/python3"
[ -x "$PY3" ] || PY3="$(command -v python3 || echo python3)"
info "asterisk: $ASTERISK_BIN"
info "python3:  $PY3"

#--------------------------------------------------------------------------------
# 3. State + install dirs (match the API's hard-coded paths exactly).
#    upes_api.py references /opt/upes-ecs and /var/lib/upes-ecs (read-only source
#    we must NOT edit), so we create those and chown to the LaunchAgent user.
#--------------------------------------------------------------------------------
log "state + install dirs (sudo)"
UPES_OPT="/opt/upes-ecs"
UPES_STATE="/var/lib/upes-ecs"
NEED_SUDO=""
if [ ! -w /opt ] || [ ! -w /var/lib ]; then NEED_SUDO="sudo"; fi
info "creating $UPES_OPT and $UPES_STATE (may prompt for your password)"
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
  info "(no scripts/*.sh in payload -- skipping helper copy)"
fi

#--------------------------------------------------------------------------------
# 4. Asterisk runtime dirs under the brew prefix + a coherent asterisk.conf
#--------------------------------------------------------------------------------
log "asterisk runtime dirs + asterisk.conf"
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
  info "backed up existing config -> $BK"
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
log "asterisk config"
for f in extensions.conf pjsip.conf pjsip_accounts.conf queues.conf voicemail.conf \
         rtp.conf confbridge.conf http.conf fail2ban-asterisk.conf; do
  if [ -f "$ASTSRC/$f" ]; then
    cp "$ASTSRC/$f" "$ASTETC/"
    /usr/bin/sed -i '' 's/\r$//' "$ASTETC/$f" 2>/dev/null || sed -i 's/\r$//' "$ASTETC/$f"
  elif [ "$f" = "pjsip_accounts.conf" ]; then
    info "!! $f missing -- NO SIP accounts will be provisioned (add users post-install)"
  else
    info "(optional $f not present, skipped)"
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
  info "pjsip_accounts.conf is an empty stub -- add SIP users after install (README-MACOS.md)"
fi

# All-campus paging PIN: replace placeholder with a random one (idempotent).
if [ -f "$ASTETC/extensions_custom.conf" ] && \
   grep -q '^PAGING_PIN_700=CHANGE-ME' "$ASTETC/extensions_custom.conf"; then
  PIN="$(( (RANDOM * 32768 + RANDOM) % 900000 + 100000 ))"
  /usr/bin/sed -i '' "s/^PAGING_PIN_700=.*/PAGING_PIN_700=${PIN}/" "$ASTETC/extensions_custom.conf" 2>/dev/null || \
    sed -i "s/^PAGING_PIN_700=.*/PAGING_PIN_700=${PIN}/" "$ASTETC/extensions_custom.conf"
  echo "PAGING_PIN_700=${PIN}" > "$UPES_STATE/generated-secrets.txt"
  info "generated paging PIN -> $UPES_STATE/generated-secrets.txt"
fi

#--------------------------------------------------------------------------------
# 6. LAN IP -> external_media_address / external_signaling_address
#--------------------------------------------------------------------------------
log "external media/signaling address"
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
  info "could not auto-detect a LAN IP -- using fallback $LAN_IP (override with --lan-ip)"
fi
info "LAN IP: $LAN_IP"

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
log "voice prompts (language=$LANGUAGE)"
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
  info "!! requested language '$LANGUAGE' has no packed pack -- falling back to en"
fi

# Never leave a silent PBX: if en/upes-ecs prompts are missing, seed placeholders.
PD="$SND_DST/en/upes-ecs"; mkdir -p "$PD"
if ! compgen -G "$PD/*.wav" >/dev/null 2>&1 && ! compgen -G "$PD/*.gsm" >/dev/null 2>&1; then
  info "(no en/upes-ecs prompts found -- seeding placeholders)"
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
log "callout / roll-call groups"
GR="$UPES_OPT/groups"
if [ ! -f "$GR/all.csv" ]; then
  printf '500120597\n500120596\n500119503\n500119499\n' > "$GR/roster.csv"
  printf '500120597\n500120596\n500119503\n500119499\n40001097\n40003657\n40004432\n4101\n4110\n4111\n4112\n4113\n4120\n4200\n4300\n4400\n4500\n4600\n' > "$GR/all.csv"
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
  info "(groups already present -- leaving in place)"
fi

#--------------------------------------------------------------------------------
# 9. Local status/control API (FastAPI on :8090) in a Python venv
#--------------------------------------------------------------------------------
log "local status API (FastAPI :8090)"
VENV="$UPES_OPT/venv"
if [ ! -x "$VENV/bin/python3" ]; then
  "$PY3" -m venv "$VENV" || die "failed to create venv at $VENV (is python@3 installed?)"
fi
"$VENV/bin/python3" -m pip install --quiet --upgrade pip >/dev/null 2>&1 || true
"$VENV/bin/python3" -m pip install --quiet fastapi 'uvicorn[standard]' || \
  info "(fastapi/uvicorn install failed/offline -- API may not start until deps are present)"
cp "$REPO_ROOT/api/upes_api.py" "$UPES_OPT/api/upes_api.py"
# directory.json feeds the API family/safety directory.
[ -f "$CON_SRC/directory.json" ] && cp "$CON_SRC/directory.json" "$UPES_OPT/family/directory.json"

#--------------------------------------------------------------------------------
# 10. Console (stdlib static server + /api proxy on :8080)
#--------------------------------------------------------------------------------
log "Console web server (:8080)"
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
log "env file + foreground fallback"
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
log "launchd agents (~/Library/LaunchAgents)"
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
    info "(could not launchctl-load $label -- use the foreground fallback instead)"
}
if command -v launchctl >/dev/null 2>&1; then
  load_agent "$AST_PLIST" "com.upes-ecs.asterisk"
  load_agent "$API_PLIST" "com.upes-ecs.api"
  load_agent "$CON_PLIST" "com.upes-ecs.console"
else
  info "(launchctl not found -- not macOS? use run-foreground.sh)"
fi

#--------------------------------------------------------------------------------
# 13. Summary
#--------------------------------------------------------------------------------
sleep 3 || true
echo "-------------------------------------------------------------------"
if command -v launchctl >/dev/null 2>&1; then
  "$ASTERISK_BIN" -rx "core show uptime" 2>/dev/null | head -1 || \
    info "(asterisk not answering yet -- check $ASTLOG/com.upes-ecs.asterisk.err.log)"
fi
cat <<EOF
UPES-ECS macOS install complete.

  Dial 111 ....... emergency (ERT queue)
  Console ........ http://$LAN_IP:8080
  API health ..... http://127.0.0.1:8090/health
  Phones (SIP) ... register to $LAN_IP:5060  (WebSocket app: ws://$LAN_IP:8088/ws)

  brew prefix .... $PREFIX
  Asterisk conf .. $ASTETC
  Sounds ......... $SND_DST   (language: $LANGUAGE)
  State .......... $UPES_STATE

  Services (launchd LaunchAgents):
    launchctl kickstart -k gui/$UID_NUM/com.upes-ecs.asterisk
    launchctl print gui/$UID_NUM/com.upes-ecs.asterisk
  Foreground fallback (no launchd):
    $UPES_OPT/run-foreground.sh

  Add SIP users post-install (the shipped accounts file is a clean stub):
    see README-MACOS.md "Add a user".

UPES-ECS-MACOS-SETUP-DONE
EOF
