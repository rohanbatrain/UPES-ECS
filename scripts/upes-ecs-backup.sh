#!/usr/bin/env bash
# ============================================================================
# UPES-ECS - nightly backup of everything needed to rebuild state:
#   /etc/asterisk (dialplan, pjsip accounts, queues, voicemail, secrets),
#   /var/lib/upes-ecs (incidents, shift log, alerts, conference logs),
#   /var/spool/asterisk/voicemail, and the astdb (dynamic queue members).
# Keeps the last N archives. Restore = stop asterisk, untar, start asterisk.
# ============================================================================
set -euo pipefail
DEST=/var/backups/upes-ecs
KEEP="${UPES_BACKUP_KEEP:-14}"
STAMP="$(date '+%Y%m%d-%H%M%S')"
mkdir -p "$DEST"

# export astdb (dynamic queue members / persistent shift staffing)
asterisk -rx "database show" > "/tmp/astdb-$STAMP.txt" 2>/dev/null || true

# Include the CardDAV directory + its config/creds when present (paths that don't
# exist are silently skipped by the trailing || true).
CARDDAV_PATHS=()
[ -d /var/lib/radicale ] && CARDDAV_PATHS+=(var/lib/radicale)
[ -d /etc/radicale ]     && CARDDAV_PATHS+=(etc/radicale)

tar -czf "$DEST/upes-ecs-backup-$STAMP.tgz" \
  -C / \
  etc/asterisk \
  var/lib/upes-ecs \
  var/spool/asterisk/voicemail \
  var/lib/asterisk/astdb.sqlite3 \
  "${CARDDAV_PATHS[@]}" \
  "tmp/astdb-$STAMP.txt" 2>/dev/null || true
rm -f "/tmp/astdb-$STAMP.txt"

# prune old archives
ls -1t "$DEST"/upes-ecs-backup-*.tgz 2>/dev/null | tail -n +$((KEEP + 1)) | xargs -r rm -f

echo "$(date '+%Y-%m-%d %H:%M:%S') backup -> $DEST/upes-ecs-backup-$STAMP.tgz ($(ls -1 "$DEST"/upes-ecs-backup-*.tgz 2>/dev/null | wc -l) kept)"
