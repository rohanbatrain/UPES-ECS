#!/usr/bin/env bash
# rollcall_report.sh — summarize a UPES-ECS roll-call run.
#
# Usage:
#   rollcall_report.sh <runid | path-to-runid.csv>
#
# Reads:
#   /var/lib/upes-ecs/rollcall/<runid>.roster  every extension attempted (from mass_callout.sh)
#   /var/lib/upes-ecs/rollcall/<runid>.csv      ext,response,time rows (from ctx_callout)
#
# Reports: total called, acknowledged-safe (pressed 1), responded-but-not-safe,
# and no-response (with the extension list) = roster minus everyone who answered.
set -euo pipefail

STATE_DIR="/var/lib/upes-ecs/rollcall"

usage() { sed -n '2,17p' "$0"; }

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -ne 1 ]]; then
  usage
  [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && exit 0 || exit 2
fi

ARG="$1"
# Accept a runid or a path to the .csv; derive both files.
if [[ "${ARG}" == *.csv ]]; then
  CSV="${ARG}"
  RUNID="$(basename "${ARG}" .csv)"
  DIR="$(dirname "${ARG}")"
else
  RUNID="${ARG}"
  DIR="${STATE_DIR}"
  CSV="${DIR}/${RUNID}.csv"
fi
ROSTER="${DIR}/${RUNID}.roster"

if [[ ! -f "${ROSTER}" && ! -f "${CSV}" ]]; then
  echo "ERROR: no roster or response CSV found for runid '${RUNID}' in ${DIR}" >&2
  exit 2
fi
[[ -f "${CSV}" ]]    || CSV=/dev/null
[[ -f "${ROSTER}" ]] || ROSTER=/dev/null

# Extensions attempted (unique, numeric).
roster_exts="$(grep -E '^[0-9]+$' "${ROSTER}" 2>/dev/null | sort -u || true)"
total_called="$(printf '%s\n' "${roster_exts}" | grep -c . || true)"

# Responses: ext,response,time  -> everyone who answered (appears in CSV).
responded_exts="$(awk -F, 'NF>=1 && $1 ~ /^[0-9]+$/ {print $1}' "${CSV}" | sort -u || true)"
# Acknowledged safe = response field == 1 (last row per ext wins if repeated).
safe_exts="$(awk -F, 'NF>=2 && $1 ~ /^[0-9]+$/ && $2==1 {print $1}' "${CSV}" | sort -u || true)"

n_responded="$(printf '%s\n' "${responded_exts}" | grep -c . || true)"
n_safe="$(printf '%s\n' "${safe_exts}" | grep -c . || true)"

# Responded but not safe = answered but did not press 1.
notsafe_exts="$(comm -23 <(printf '%s\n' "${responded_exts}" | grep -E '^[0-9]+$' | sort -u) \
                          <(printf '%s\n' "${safe_exts}"      | grep -E '^[0-9]+$' | sort -u) || true)"
n_notsafe="$(printf '%s\n' "${notsafe_exts}" | grep -c . || true)"

# No-response = roster minus everyone who answered.
noresp_exts="$(comm -23 <(printf '%s\n' "${roster_exts}"    | grep -E '^[0-9]+$' | sort -u) \
                         <(printf '%s\n' "${responded_exts}" | grep -E '^[0-9]+$' | sort -u) || true)"
n_noresp="$(printf '%s\n' "${noresp_exts}" | grep -c . || true)"

echo "==================================================="
echo " UPES-ECS Roll-Call Report"
echo " Run ID        : ${RUNID}"
echo "---------------------------------------------------"
printf ' Total called  : %s\n' "${total_called}"
printf ' Ack safe (1)  : %s\n' "${n_safe}"
printf ' Responded !=1 : %s\n' "${n_notsafe}"
printf ' No response   : %s\n' "${n_noresp}"
echo "---------------------------------------------------"
if [[ "${n_noresp}" -gt 0 ]]; then
  echo " NO-RESPONSE extensions (follow up):"
  printf '   %s\n' ${noresp_exts}
fi
if [[ "${n_notsafe}" -gt 0 ]]; then
  echo " RESPONDED-NOT-SAFE extensions (answered, no '1'):"
  printf '   %s\n' ${notsafe_exts}
fi
echo "==================================================="
