#!/usr/bin/env bash
# ============================================================================
# UPES-ECS — alert the ERT Lead + backup responders WITHOUT holding the caller.
# Called from the dialplan the moment the 111 queue fails to connect a human.
# Drops Asterisk call-files (non-blocking) that ring each responder and play a
# spoken alert; the responder can press 1 to (re)join the emergency queue, so the
# caller's coach "9 = retry a responder" then bridges them. The caller is coached
# immediately in parallel — never left in silence (EMD pre-arrival principle).
# ============================================================================
set -euo pipefail
INCIDENT="${1:-unknown}"
CALLER="${2:-}"
SPOOL=/var/spool/asterisk/outgoing
STAGE=/tmp
LEAD="${UPES_LEAD:-4101}"
BACKUP_RAW="${UPES_BACKUP:-}"

# Build the target list: Lead + each backup device (strip "PJSIP/", split on "&").
targets=("$LEAD")
IFS='&' read -ra parts <<< "${BACKUP_RAW//PJSIP\//}"
for p in "${parts[@]}"; do [ -n "$p" ] && targets+=("$p"); done

for ext in "${targets[@]}"; do
  f="$STAGE/alert-${INCIDENT}-${ext}.call"
  cat > "$f" <<EOF
Channel: PJSIP/${ext}
CallerID: "EMERGENCY 111" <111>
MaxRetries: 1
RetryTime: 10
WaitTime: 25
Context: ctx_responder_alert
Extension: s
Priority: 1
Setvar: RESP_EXT=${ext}
Setvar: INCIDENT_ID=${INCIDENT}
Setvar: ALERT_CALLER=${CALLER}
EOF
  chown asterisk:asterisk "$f" 2>/dev/null || true
  # atomic move into the spool dir triggers the (non-blocking) originate
  mv "$f" "$SPOOL/" 2>/dev/null || true
done
