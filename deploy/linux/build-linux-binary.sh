#!/usr/bin/env bash
#
# build-linux-binary.sh -- package UPES-ECS into ONE self-extracting installer:
#     dist/upes-ecs-linux-installer.run
#
# Run from the Windows host via `wsl -- bash -lc '.../build-linux-binary.sh'`
# or directly inside WSL/Linux. Size is explicitly a non-issue -- the whole
# functional payload (sounds incl. language packs, Console, api, scripts,
# config, i18n, deploy/) is bundled so the target needs no repo checkout.
#
# SECURITY (hard rule): NO real secrets in the binary.
#   * pjsip_accounts.conf is replaced with a CLEAN STUB (no SIP passwords).
#   * secrets/, *.filled.csv, TEAM-CREDENTIALS.md, *users*.csv are stripped.
#   * The staged payload is scanned for secret-looking lines; the build ABORTS
#     if any are found.
#
# Prefers `makeself`; falls back to a hand-rolled #!/bin/sh + appended tar.gz.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DIST="$REPO_ROOT/dist"
OUT="$DIST/upes-ecs-linux-installer.run"

# WSL quirk: building on a /mnt/<drive> DrvFs path makes makeself's tar/gzip/
# cksum/md5sum steps slow and (when the backing vhdx errors) unreliable. Stage +
# package in a NATIVE Linux work dir, then copy only the final .run to dist/.
if [ -n "${UPES_BUILD_WORKROOT:-}" ]; then
  WORKROOT="$UPES_BUILD_WORKROOT"
elif printf '%s' "$REPO_ROOT" | grep -q '^/mnt/'; then
  WORKROOT="$(mktemp -d /var/tmp/upes-linux-build.XXXXXX 2>/dev/null || mktemp -d)"
else
  WORKROOT="$DIST"
fi
STAGE="$WORKROOT/linux-stage"
PAYLOAD="$STAGE/upes-ecs"
BUILT="$STAGE/upes-ecs-linux-installer.run"   # built here (native FS), copied to $OUT

echo "== build UPES-ECS Linux installer =="
echo "   repo=$REPO_ROOT"
echo "   workroot=$WORKROOT"
mkdir -p "$DIST"
rm -rf "$STAGE"
mkdir -p "$PAYLOAD"

#--------------------------------------------------------------------------------
# 1. Copy the functional payload (preserving repo-relative layout so
#    install-linux.sh resolves REPO_ROOT the same way it does in a checkout).
#--------------------------------------------------------------------------------
echo "== staging payload =="
copy_tree() {  # <rel-path>
  local rel="$1"
  if [ -e "$REPO_ROOT/$rel" ]; then
    mkdir -p "$PAYLOAD/$(dirname "$rel")"
    cp -a "$REPO_ROOT/$rel" "$PAYLOAD/$rel"
  else
    echo "  (skip missing $rel)"
  fi
}

# deploy/ but ONLY the bits we need (exclude qemu images, docker, etc. are small
# anyway; we copy the whole deploy tree then prune heavy/irrelevant subdirs).
copy_tree deploy/asterisk
copy_tree deploy/jetson/serve-console.py
copy_tree deploy/linux
copy_tree Console
copy_tree i18n
copy_tree api
copy_tree scripts
copy_tree config

#--------------------------------------------------------------------------------
# 2. Strip caches + anything that should never ship.
#--------------------------------------------------------------------------------
echo "== pruning caches + non-shippable files =="
find "$PAYLOAD" -type d -name '__pycache__' -prune -exec rm -rf {} + 2>/dev/null || true
find "$PAYLOAD" -type d -name 'logs'         -prune -exec rm -rf {} + 2>/dev/null || true
find "$PAYLOAD" -type d -name 'recordings'   -prune -exec rm -rf {} + 2>/dev/null || true
# Console PowerShell helpers are Windows-only -- not needed on Linux.
find "$PAYLOAD/Console" -maxdepth 1 -type f -name '*.ps1' -delete 2>/dev/null || true

#--------------------------------------------------------------------------------
# 3. SECURITY: replace pjsip_accounts.conf with a CLEAN STUB + strip credentials.
#--------------------------------------------------------------------------------
echo "== SECURITY: scrubbing secrets =="
cat > "$PAYLOAD/deploy/asterisk/pjsip_accounts.conf" <<'STUB'
; ============================================================================
; UPES-ECS - pjsip_accounts.conf  (CLEAN STUB -- shipped in the installer)
; ----------------------------------------------------------------------------
; NO accounts and NO SIP passwords ship in the installer, by design.
; Add users AFTER install on the node (see README-LINUX.md "Add a user"):
;   1. Append an endpoint/auth/aor triple to THIS file on the installed node
;      (/etc/asterisk/pjsip_accounts.conf), e.g.:
;
;        [4130](endpoint-tpl)
;        context=ctx_ert
;        auth=4130
;        aors=4130
;        callerid=ERT Operator 5 <4130>
;        [4130](auth-tpl)
;        username=4130
;        password=<a strong unique secret>
;        [4130](aor-tpl)
;
;   2. asterisk -rx 'pjsip reload'
; ============================================================================
STUB

# Remove any credential-bearing files that may have been dragged in.
find "$PAYLOAD" -type f \( \
     -iname '*.filled.csv' -o \
     -iname 'TEAM-CREDENTIALS.md' -o \
     -iname '*users*.csv' -o \
     -iname '*credential*' -o \
     -iname '*secret*' \
  \) -print -delete 2>/dev/null || true

# Belt-and-braces: there must be NO secrets/ dir or APK inside the payload.
rm -rf "$PAYLOAD/secrets" 2>/dev/null || true

#--------------------------------------------------------------------------------
# 4. Secret scan: abort if any secret-looking assignment survives.
#--------------------------------------------------------------------------------
echo "== secret scan =="
# password/secret = <10+ hex/alnum chars>  (the accounts file's real-secret shape)
if grep -rnEi '(password|secret)[[:space:]]*=[[:space:]]*[0-9a-z]{10,}' "$PAYLOAD" \
     --include='*.conf' --include='*.csv' --include='*.env' --include='*.md' 2>/dev/null \
     | grep -vE '<|CHANGE|example|placeholder|strong unique' ; then
  echo "!! SECRET SCAN FAILED -- secret-looking lines found above. Aborting build." >&2
  exit 1
fi
echo "  OK: 0 secret-looking lines in the payload"

#--------------------------------------------------------------------------------
# 5. Normalise line endings + perms on the shipped shell scripts.
#--------------------------------------------------------------------------------
find "$PAYLOAD" -type f -name '*.sh' -exec sed -i 's/\r$//' {} + 2>/dev/null || true
find "$PAYLOAD" -type f -name '*.sh' -exec chmod +x {} + 2>/dev/null || true
chmod +x "$PAYLOAD/deploy/jetson/serve-console.py" 2>/dev/null || true

# The makeself "startup script" -- a thin wrapper that forwards args to the
# real installer (which lives at the payload's deploy/linux/install-linux.sh).
cat > "$PAYLOAD/bootstrap.sh" <<'BOOT'
#!/bin/sh
# Bootstrap run by the self-extractor from inside the unpacked payload dir.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
exec bash "$HERE/deploy/linux/install-linux.sh" "$@"
BOOT
chmod +x "$PAYLOAD/bootstrap.sh"

PAYLOAD_MB="$(du -sm "$PAYLOAD" | awk '{print $1}')"
echo "  staged payload: ${PAYLOAD_MB} MB"

#--------------------------------------------------------------------------------
# 6. Package. Prefer makeself; else hand-roll.
#--------------------------------------------------------------------------------
rm -f "$OUT" "$BUILT"
if ! command -v makeself >/dev/null 2>&1 && ! command -v makeself.sh >/dev/null 2>&1; then
  echo "== makeself not found -- attempting apt-get install -y makeself =="
  export DEBIAN_FRONTEND=noninteractive
  apt-get install -y makeself >/dev/null 2>&1 || echo "  (makeself install failed/offline -- will hand-roll)"
fi

MAKESELF_BIN=""
command -v makeself    >/dev/null 2>&1 && MAKESELF_BIN="makeself"
command -v makeself.sh >/dev/null 2>&1 && MAKESELF_BIN="makeself.sh"

if [ -n "$MAKESELF_BIN" ]; then
  echo "== packaging with $MAKESELF_BIN =="
  "$MAKESELF_BIN" --gzip \
    "$PAYLOAD" "$BUILT" \
    "UPES-ECS Linux single-node installer" \
    ./bootstrap.sh
else
  echo "== packaging with hand-rolled self-extractor =="
  TARBALL="$STAGE/payload.tar.gz"
  ( cd "$PAYLOAD" && tar czf "$TARBALL" . )
  HEADER="$STAGE/header.sh"
  cat > "$HEADER" <<'HDR'
#!/bin/sh
# Self-extracting UPES-ECS Linux installer (hand-rolled).
# Extracts the appended tar.gz to a temp dir and runs bootstrap.sh <args>.
set -e
ARCHIVE_LINE=$(awk '/^__UPES_ARCHIVE_BELOW__/{print NR + 1; exit 0;}' "$0")
TMP="$(mktemp -d /tmp/upes-ecs.XXXXXX)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT
tail -n +"$ARCHIVE_LINE" "$0" | tar xz -C "$TMP"
sh "$TMP/bootstrap.sh" "$@"
exit $?
__UPES_ARCHIVE_BELOW__
HDR
  cat "$HEADER" "$TARBALL" > "$BUILT"
fi

chmod +x "$BUILT"

# Copy the finished single-file installer to dist/ (may be a DrvFs path).
echo "== copying installer to $OUT =="
cp -f "$BUILT" "$OUT"
chmod +x "$OUT"

# Clean up the native work dir unless it's dist/ itself (or the caller asked to keep it).
if [ "$WORKROOT" != "$DIST" ] && [ -z "${UPES_BUILD_KEEP:-}" ]; then
  rm -rf "$WORKROOT" 2>/dev/null || true
fi

#--------------------------------------------------------------------------------
# 7. Report
#--------------------------------------------------------------------------------
SIZE="$(du -h "$OUT" | awk '{print $1}')"
echo "-------------------------------------------------------------------"
echo "  BUILT: $OUT  ($SIZE)"
echo "  Install on a target x86_64 Ubuntu/Debian node with:"
echo "    sudo ./upes-ecs-linux-installer.run --iface <nic> [--language en|hi|...]"
echo "UPES-ECS-LINUX-BUILD-DONE"
