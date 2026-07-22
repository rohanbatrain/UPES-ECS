#!/usr/bin/env bash
#
# build-macos-binary.sh -- package the UPES-ECS macOS payload into ONE
# self-extracting Finder-double-clickable installer:
#
#     dist/upes-ecs-macos-installer.command
#
# Strategy: prefer `makeself` (emits a shell self-extractor); if makeself is
# unavailable, hand-roll an equivalent -- a `#!/bin/sh` header with an appended
# gzip'd tar payload that extracts to a temp dir and runs install-macos.sh.
# Both outputs are plain POSIX-shell + tar.gz, so the artifact built on Linux/WSL
# is byte-identical in behaviour on macOS (only the RUNTIME needs a real Mac).
#
# SECURITY: the payload ships pjsip_accounts.conf as a CLEAN STUB (no secrets),
# and this script excludes secrets/, *.filled.csv, TEAM-CREDENTIALS.md, *users*.csv,
# the 1.4GB Flutter app/, the APK, and .git. It then SCANS the staged payload and
# ABORTS if any secret-looking line survives.
#
# Run on macOS, Linux, or WSL. Usage:
#   ./build-macos-binary.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DIST="$REPO_ROOT/dist"
OUT="$DIST/upes-ecs-macos-installer.command"
STAGE="$DIST/macos-stage"
PKGROOT="$STAGE/upes-ecs"     # payload root; mirrors the repo layout the installer expects

log() { echo "== $* =="; }
die() { echo "ERROR: $*" >&2; exit 1; }

mkdir -p "$DIST"
rm -rf "$STAGE"
mkdir -p "$PKGROOT"

#--------------------------------------------------------------------------------
# 1. Stage the FUNCTIONAL payload (only what install-macos.sh reads)
#--------------------------------------------------------------------------------
log "staging payload -> $PKGROOT"
copy_tree() {
  # $1 = repo-relative dir; skip if absent
  local rel="$1"
  [ -e "$REPO_ROOT/$rel" ] || { echo "   (skip missing $rel)"; return 0; }
  mkdir -p "$PKGROOT/$(dirname "$rel")"
  cp -a "$REPO_ROOT/$rel" "$PKGROOT/$(dirname "$rel")/"
}

# deploy/ but ONLY macos + asterisk (skip qemu/jetson/linux/windows trees to keep
# it lean and avoid coupling to other agents' in-progress work).
mkdir -p "$PKGROOT/deploy"
cp -a "$REPO_ROOT/deploy/macos"    "$PKGROOT/deploy/macos"
cp -a "$REPO_ROOT/deploy/asterisk" "$PKGROOT/deploy/asterisk"

copy_tree Console
copy_tree i18n
copy_tree api
copy_tree scripts
copy_tree config

#--------------------------------------------------------------------------------
# 2. Prune anything unnecessary or sensitive from the STAGED copy
#--------------------------------------------------------------------------------
log "pruning excluded / sensitive files from stage"
# Never ship the huge/binary/secret trees.
rm -rf "$PKGROOT/app" "$PKGROOT/secrets" 2>/dev/null || true
find "$PKGROOT" -name '.git' -prune -exec rm -rf {} + 2>/dev/null || true
find "$PKGROOT" -type d -name '__pycache__' -prune -exec rm -rf {} + 2>/dev/null || true
# Secret-bearing / credential files, wherever they landed.
find "$PKGROOT" -type f \( \
      -iname '*.filled.csv' -o \
      -iname '*users*.csv'  -o \
      -iname 'TEAM-CREDENTIALS.md' -o \
      -iname 'UPES-Safe.apk' \
    \) -print -delete 2>/dev/null || true

#--------------------------------------------------------------------------------
# 3. Replace pjsip_accounts.conf with a CLEAN STUB (no SIP passwords)
#--------------------------------------------------------------------------------
log "writing clean pjsip_accounts.conf stub (no secrets)"
cat > "$PKGROOT/deploy/asterisk/pjsip_accounts.conf" <<'STUB'
; ============================================================================
; UPES-ECS - pjsip_accounts.conf  (CLEAN STUB shipped in the macOS installer)
; #included by pjsip.conf AFTER the (endpoint-tpl)/(auth-tpl)/(aor-tpl) templates.
;
; This file intentionally contains NO accounts and NO secrets. Real SIP
; credentials are NEVER packaged into the installer binary.
;
; Add users AFTER install (single source of truth -- pins the secret once):
;   * on this Mac, append endpoint/auth/aor blocks here, then:
;       asterisk -rx "pjsip reload"
;   * a template block looks like:
;       [4201](endpoint-tpl)
;       context=ctx_responder
;       auth=4201
;       aors=4201
;       callerid=Medical Responder 1 <4201>
;       [4201](auth-tpl)
;       username=4201
;       password=<CHOOSE-A-STRONG-SECRET>
;       [4201](aor-tpl)
;
; See README-MACOS.md "Add a user" for the full procedure.
; ============================================================================
STUB

#--------------------------------------------------------------------------------
# 4. SECURITY GATE: fail the build if any secret-looking line survives
#--------------------------------------------------------------------------------
log "security scan (must find 0 secret-looking lines)"
HITS="$(grep -rIlE '(password|secret)[[:space:]]*=[[:space:]]*[0-9a-f]{10,}' "$PKGROOT" 2>/dev/null || true)"
if [ -n "$HITS" ]; then
  echo "$HITS" >&2
  die "secret-looking lines found in staged payload -- refusing to build."
fi
# Also assert the sensitive filenames are gone.
LEFT="$(find "$PKGROOT" -type f \( -iname '*.filled.csv' -o -iname '*users*.csv' -o -iname 'TEAM-CREDENTIALS.md' \) 2>/dev/null || true)"
[ -z "$LEFT" ] || { echo "$LEFT" >&2; die "sensitive files still present in stage."; }
echo "   OK: 0 secret-looking lines, 0 sensitive files."

# Normalise line endings + perms on shell/python we control.
find "$PKGROOT/deploy/macos" -type f \( -name '*.sh' -o -name '*.py' \) -exec chmod +x {} + 2>/dev/null || true

STAGE_SIZE="$(du -sh "$PKGROOT" 2>/dev/null | awk '{print $1}')"
echo "   staged payload size: ${STAGE_SIZE:-unknown}"

#--------------------------------------------------------------------------------
# 5. Build the self-extracting .command
#--------------------------------------------------------------------------------
STARTUP="deploy/macos/bootstrap-install.sh"
# Small in-payload bootstrapper the extractor invokes; forwards args to the real
# installer from the correct CWD (the extracted payload root).
cat > "$PKGROOT/deploy/macos/bootstrap-install.sh" <<'BOOT'
#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$HERE/install-macos.sh" "$@"
BOOT
chmod +x "$PKGROOT/deploy/macos/bootstrap-install.sh"

if command -v makeself >/dev/null 2>&1 || command -v makeself.sh >/dev/null 2>&1; then
  log "packaging with makeself"
  MK="$(command -v makeself || command -v makeself.sh)"
  # makeself <archive_dir> <file_name> <label> <startup_script...>
  "$MK" --gzip --notemp-nocleanup 2>/dev/null "$PKGROOT" "$OUT" \
      "UPES-ECS macOS installer" "./$STARTUP" || \
  "$MK" --gzip "$PKGROOT" "$OUT" "UPES-ECS macOS installer" "./$STARTUP"
else
  log "makeself not found -- hand-rolling a POSIX self-extractor"
  TARBALL="$STAGE/payload.tar.gz"
  # Deterministic-ish tar of the payload ROOT contents (so 'upes-ecs/...' is the top dir).
  ( cd "$STAGE" && tar -czf "$TARBALL" "upes-ecs" )

  HEADER="$STAGE/header.sh"
  cat > "$HEADER" <<'HDR'
#!/bin/sh
# UPES-ECS macOS self-extracting installer (hand-rolled).
# Extracts the appended tar.gz to a temp dir and runs the installer.
set -eu
echo "== UPES-ECS macOS installer =="
TMP="$(mktemp -d "${TMPDIR:-/tmp}/upes-ecs.XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT INT TERM
# The payload starts at the line after __ARCHIVE_BELOW__.
ARCHIVE_LINE=$(awk '/^__ARCHIVE_BELOW__$/ {print NR + 1; exit 0}' "$0")
tail -n "+${ARCHIVE_LINE}" "$0" | tar -xzf - -C "$TMP"
echo "== extracted to $TMP -- launching installer =="
# Forward any args (e.g. --language hi --lan-ip 10.0.0.5) to the installer.
"$TMP/upes-ecs/deploy/macos/install-macos.sh" "$@"
echo "== installer finished =="
exit 0
__ARCHIVE_BELOW__
HDR
  cat "$HEADER" "$TARBALL" > "$OUT"
fi

chmod +x "$OUT"
OUT_SIZE="$(du -h "$OUT" 2>/dev/null | awk '{print $1}')"
echo "-------------------------------------------------------------------"
echo "Built: $OUT"
echo "Size : ${OUT_SIZE:-unknown}"
echo "Run  : chmod +x '$OUT' && '$OUT' [--language hi] [--lan-ip <ip>]"
echo "       (or double-click in Finder; unsigned -> see README-MACOS.md Gatekeeper)"
echo "UPES-ECS-MACOS-BUILD-DONE"
