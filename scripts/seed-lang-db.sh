#!/usr/bin/env bash
# ============================================================================
# UPES-ECS — seed per-user voice language into Asterisk astdb (DB(lang/<ext>)).
# ----------------------------------------------------------------------------
# Replays the runtime language map (ext,lang CSV) into astdb so the dialplan's
# sub_setlang routing is self-healing across a PBX restart or an astdb wipe.
# Idempotent — re-running just re-asserts the same keys. Runs at boot via the
# upes-lang-seed.service oneshot (installed by setup-in-vm.sh) and can be run
# by hand any time:  /opt/upes-ecs/seed-lang-db.sh [csv]
#
# Source of truth on the VM: /opt/upes-ecs/family/user-languages.csv — kept
# current by the app-facing API (POST /lang) and seeded from the repo's
# provisioning/user-languages.csv at build. The campus default (lang/_default)
# is owned by Install-UpesEcs.ps1 (Sync-LangDb) and is preserved here unless
# UPES_DEFAULT_LANG is explicitly set.
# ============================================================================
set -euo pipefail
CSV="${1:-/opt/upes-ecs/family/user-languages.csv}"

# Optional: only touch the campus default if explicitly provided (else keep astdb's).
if [ -n "${UPES_DEFAULT_LANG:-}" ]; then
  asterisk -rx "database put lang _default ${UPES_DEFAULT_LANG}" >/dev/null 2>&1 || true
fi

[ -f "$CSV" ] || { echo "seed-lang-db: no CSV at $CSV (nothing to seed)"; exit 0; }

n=0
# skip the header row; fields: ext,lang (ignore any trailing columns)
tail -n +2 "$CSV" | while IFS=, read -r ext lang _rest; do
  ext="$(printf '%s' "${ext:-}" | tr -d '[:space:]\r')"
  lang="$(printf '%s' "${lang:-}" | tr -d '[:space:]\r')"
  case "$ext"  in ''|*[!0-9]*)      continue;; esac   # digits only
  case "$lang" in ''|*[!a-z]*)      continue;; esac   # 2-3 lowercase letters
  asterisk -rx "database put lang ${ext} ${lang}" >/dev/null 2>&1 || true
  n=$((n+1))
done
echo "seed-lang-db: seeded per-user language from $CSV"
