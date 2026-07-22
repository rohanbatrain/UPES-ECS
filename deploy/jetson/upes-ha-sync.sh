#!/usr/bin/env bash
#
# upes-ha-sync.sh -- replicate mutable UPES-ECS state PRIMARY -> SECONDARY over SSH.
#
# So that Add-UpesUser (and any config/prompt/directory change made on the primary)
# propagates to the standby, this rsyncs the authoritative, changeable state:
#   - /etc/asterisk               (esp. pjsip_accounts.conf = accounts source of truth)
#   - /usr/share/asterisk/sounds  (voice prompts incl. language packs)
#   - /opt/upes-ecs/groups        (callout / roll-call rosters)
#   - Console runtime data        (region.json, directory.json, ui-lang/)
#
# Runs on the PRIMARY (from the systemd timer, or on demand). It is a one-way PUSH:
# primary is the source of truth; the secondary is overwritten to match. After a
# config push it reloads the peer's Asterisk so new accounts register immediately.
#
# Key-based SSH only (no passwords). See README for the one-time key exchange.
#
set -euo pipefail

ENV_FILE="/opt/upes-ecs/ha/ha.env"
# shellcheck source=/dev/null
[ -f "$ENV_FILE" ] && . "$ENV_FILE"

ROLE="${UPES_ROLE:-unknown}"
PEER="${UPES_PEER:-}"
SSH_USER="${UPES_SSH_USER:-ubuntu}"
SSH_KEY="${UPES_SSH_KEY:-/root/.ssh/upes_ha}"
CONSOLE_DIR="/opt/upes-ecs/console"

log() { logger -t upes-ha-sync "$*"; echo "$(date -u +%H:%M:%SZ) $*"; }

# Only the primary pushes. On the secondary this is a deliberate no-op so the same
# image/units are safe on both nodes.
if [ "$ROLE" != "primary" ]; then
  log "role=$ROLE (not primary) -- nothing to push, exiting 0"
  exit 0
fi
[ -n "$PEER" ] || { log "UPES_PEER not set in $ENV_FILE -- cannot sync"; exit 1; }
[ -f "$SSH_KEY" ] || { log "SSH key $SSH_KEY missing -- run the key-exchange step (README)"; exit 1; }

SSH_OPTS=(-i "$SSH_KEY" -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
          -o ConnectTimeout=8 -o ServerAliveInterval=5 -o ServerAliveCountMax=3)
RSYNC_SSH="ssh ${SSH_OPTS[*]}"
REMOTE="${SSH_USER}@${PEER}"

# Reachability gate: if the peer is down, log and exit 0 (a dead standby must not
# make the primary's timer look "failed" or spam alerts -- it will catch up later).
if ! ssh "${SSH_OPTS[@]}" "$REMOTE" true 2>/dev/null; then
  log "peer $PEER unreachable over SSH -- skipping this cycle (will retry)"
  exit 0
fi

# rsync into a temp path on the peer, then move into place with sudo. The SSH user
# is unprivileged, so we push to a staging dir it owns, then sudo-sync to system
# dirs on the remote. Requires NOPASSWD sudo for rsync on the peer (README).
STAGE="/tmp/upes-ha-stage"
# Single-quoted so the literal path is created on the REMOTE (not expanded here).
ssh "${SSH_OPTS[@]}" "$REMOTE" \
  'mkdir -p /tmp/upes-ha-stage/asterisk /tmp/upes-ha-stage/sounds /tmp/upes-ha-stage/groups /tmp/upes-ha-stage/console' \
  2>/dev/null || true

push() {  # push <local_src> <remote_stage_subdir>  (note trailing slashes matter)
  local src="$1" sub="$2"
  if [ ! -e "$src" ]; then
    log "  (skip missing $src)"
    return 0
  fi
  if rsync -a --delete -e "$RSYNC_SSH" "$src" "${REMOTE}:${STAGE}/${sub}"; then
    log "  synced $src -> peer:$STAGE/$sub"
  else
    log "  WARN rsync failed for $src"
  fi
}

log "PUSH primary -> $PEER : accounts, sounds, groups, console"
push "/etc/asterisk/"                 "asterisk/"
push "/usr/share/asterisk/sounds/"    "sounds/"
push "/opt/upes-ecs/groups/"          "groups/"
# Console runtime data only (not the whole front-end; app.js/css come from install).
for f in region.json directory.json; do
  [ -f "$CONSOLE_DIR/$f" ] && rsync -a -e "$RSYNC_SSH" "$CONSOLE_DIR/$f" "${REMOTE}:${STAGE}/console/" 2>/dev/null || true
done
[ -d "$CONSOLE_DIR/ui-lang" ] && rsync -a --delete -e "$RSYNC_SSH" "$CONSOLE_DIR/ui-lang/" "${REMOTE}:${STAGE}/console/ui-lang/" 2>/dev/null || true

# Move staged content into place on the peer + reload its Asterisk. The remote must
# NOT overwrite its own VIP/keepalived config -- we only sync Asterisk config, and
# external_media_address=VIP is identical on both nodes, so it is safe to copy.
log "apply on peer + reload asterisk"
ssh "${SSH_OPTS[@]}" "$REMOTE" 'sudo bash -s' <<'REMOTE_EOF' 2>/dev/null || log "  WARN remote apply/reload step failed"
set -e
STAGE="/tmp/upes-ha-stage"
rsync -a --delete "$STAGE/asterisk/" /etc/asterisk/
rsync -a --delete "$STAGE/sounds/"   /usr/share/asterisk/sounds/
rsync -a --delete "$STAGE/groups/"   /opt/upes-ecs/groups/
mkdir -p /opt/upes-ecs/console
[ -f "$STAGE/console/region.json" ]    && cp "$STAGE/console/region.json"    /opt/upes-ecs/console/ || true
[ -f "$STAGE/console/directory.json" ] && cp "$STAGE/console/directory.json" /opt/upes-ecs/console/ || true
[ -f "$STAGE/console/directory.json" ] && cp "$STAGE/console/directory.json" /opt/upes-ecs/family/directory.json || true
[ -d "$STAGE/console/ui-lang" ]        && rsync -a --delete "$STAGE/console/ui-lang/" /opt/upes-ecs/console/ui-lang/ || true
chown -R asterisk:asterisk /usr/share/asterisk/sounds /opt/upes-ecs/groups /var/lib/upes-ecs 2>/dev/null || true
# Reload dialplan + pjsip so freshly-synced accounts register without a restart.
asterisk -rx "dialplan reload" >/dev/null 2>&1 || true
asterisk -rx "pjsip reload"    >/dev/null 2>&1 || true
REMOTE_EOF

log "sync complete"
exit 0
