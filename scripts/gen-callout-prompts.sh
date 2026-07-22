#!/usr/bin/env bash
# ============================================================================
# UPES-ECS — generate the EMERGENCY ALERT SERVICE (EAS) mass-callout prompts.
#
# These are the recorded messages the EAS plays to phones during a mass call-out
# / roll-call (scripts/mass_callout.sh -> [ctx_callout]). Unlike the offline
# panic-coach (gen-coach-prompts.sh, which uses robotic pico2wave), the EAS
# announcements are the campus-wide "voice of authority" — so they are voiced
# with **Piper**, the professional on-prem neural TTS the AI-101 stack already
# standardizes on (../AI-101/, SOP 19). Fully offline, no cloud.
#
# Output: Asterisk-native 8 kHz mono 16-bit PCM WAV, plus a hi-fi master kept per
# SOP 28. Re-run any time to refresh wording (keep the text source-controlled here).
#
# VOICE MODEL
#   Piper voices are .onnx (+ matching .onnx.json) files. Point PIPER_MODEL at the
#   professional voice you want — you have several installed. A calm, clear, neutral
#   authority voice suits the EAS (e.g. en_US-lessac-high, en_GB-northern_english_male-medium).
#
#     PIPER_BIN     path to the piper binary            (default: piper on PATH)
#     PIPER_MODEL   path to the .onnx voice model       (default: first *.onnx under PIPER_MODEL_DIR)
#     PIPER_MODEL_DIR  where voices live                (default: /opt/piper/models)
#
#   Example:
#     PIPER_MODEL=/opt/piper/models/en_US-lessac-high.onnx ./gen-callout-prompts.sh
# ============================================================================
set -euo pipefail

SND_ROOT="${SND_ROOT:-/usr/share/asterisk/sounds/en}"
CUSTOM="${SND_ROOT}/custom"          # EAS announcement set: custom/upes-*  (Console MESSAGES)
UPES="${SND_ROOT}/upes-ecs"          # roll-call control prompts: upes-ecs/rollcall-*
MASTERS="${MASTERS:-/var/lib/upes-ecs/audio-masters}"   # hi-fi masters (SOP 28)

PIPER_BIN="${PIPER_BIN:-piper}"
PIPER_MODEL_DIR="${PIPER_MODEL_DIR:-/opt/piper/models}"

mkdir -p "${CUSTOM}" "${UPES}" "${MASTERS}"

# ---- locate Piper + a voice model -------------------------------------------
if ! command -v "${PIPER_BIN}" >/dev/null 2>&1 && [[ ! -x "${PIPER_BIN}" ]]; then
  echo "ERROR: piper not found (PIPER_BIN=${PIPER_BIN})." >&2
  echo "       Install the on-prem Piper TTS or set PIPER_BIN to its path." >&2
  exit 1
fi

if [[ -z "${PIPER_MODEL:-}" ]]; then
  PIPER_MODEL="$(find "${PIPER_MODEL_DIR}" -maxdepth 2 -name '*.onnx' 2>/dev/null | sort | head -1 || true)"
fi
if [[ -z "${PIPER_MODEL:-}" || ! -r "${PIPER_MODEL}" ]]; then
  echo "ERROR: no Piper voice model found." >&2
  echo "       Set PIPER_MODEL=/path/to/voice.onnx (or drop one under ${PIPER_MODEL_DIR})." >&2
  exit 1
fi

if ! command -v sox >/dev/null 2>&1; then
  echo "ERROR: sox not found (needed to convert to Asterisk 8 kHz mono)." >&2
  exit 1
fi

echo "EAS prompts: voice=$(basename "${PIPER_MODEL}")  ->  ${CUSTOM} + ${UPES}"

# Model sample rate (Piper voices are usually 22050; override if yours differs).
PIPER_SR="${PIPER_SR:-22050}"

# say <dest_dir> <name> <text...>
#   Piper streams RAW PCM for the WHOLE text (all sentences) to stdout -> we capture
#   a hi-fi master, then downsample to Asterisk-native 8 kHz mono. We use --output-raw
#   so the whole (multi-sentence) announcement streams out in one go.
#   GOTCHA: do NOT pass Piper's --download-dir when the voice already exists on disk —
#   in the piper-tts CLI it truncates synthesis to the first few seconds. Point the
#   voice via PIPER_MODEL (a full path) only.
say() {
  local dir="$1" name="$2"; shift 2
  local text="$*"
  local master="${MASTERS}/${name}.master.wav"
  # raw 16-bit mono PCM at the model rate -> master WAV
  printf '%s' "${text}" \
    | "${PIPER_BIN}" --model "${PIPER_MODEL}" --output-raw 2>/dev/null \
    | sox -t raw -r "${PIPER_SR}" -e signed -b 16 -c 1 - "${master}"
  # normalize level, trim lead-in/out silence, downsample to Asterisk-native format
  sox "${master}" -r 8000 -c 1 -b 16 "${dir}/${name}.wav" \
      norm -3 silence 1 0.05 0.3% reverse silence 1 0.05 0.3% reverse
  echo "  + ${dir#${SND_ROOT}/}/${name}.wav"
}

# ---- EAS announcement set  (custom/upes-*  — matches Console MESSAGES) -------
# House style per SOP 28: "Attention. This is the UPES Emergency Alert Service. …
# Await further instructions." Kept short — in a crisis, long prompts cost time.

say "${CUSTOM}" upes-evacuate \
  "Attention. This is the UPES Emergency Alert Service. Evacuate the building now. Leave immediately by the nearest safe exit. Do not use the lifts. Move to your assembly point and await further instructions."

say "${CUSTOM}" upes-shelter \
  "Attention. This is the UPES Emergency Alert Service. Shelter in place now. Move indoors, lock or block your door, stay away from windows, and remain quiet until you are told it is safe. Await further instructions."

say "${CUSTOM}" upes-allclear \
  "Attention. This is the UPES Emergency Alert Service. The emergency is now over. It is safe to resume normal activity. Thank you for your cooperation."

say "${CUSTOM}" upes-assemble \
  "Attention. This is the UPES Emergency Alert Service. Proceed to your designated assembly point now. Move calmly, help others where you can, and wait to be counted. Await further instructions."

say "${CUSTOM}" upes-rollcall \
  "Attention. This is the UPES Emergency Alert Service. This is a safety head count. If you are safe and able to respond, press one now."

say "${CUSTOM}" upes-test \
  "This is a test of the UPES Emergency Alert Service. This is only a test. No action is required, and no emergency response will be dispatched."

# ---- roll-call control prompts  (upes-ecs/  — played by [ctx_callout]) -------
say "${UPES}" rollcall-press1 \
  "Press one if you are safe."

say "${UPES}" rollcall-thanks \
  "Thank you. You are marked safe. You may now hang up."

say "${UPES}" rollcall-noack \
  "No response was recorded. Please contact your warden as soon as you are able."

chown -R asterisk:asterisk "${CUSTOM}" "${UPES}" 2>/dev/null || true
echo "EAS mass-callout prompts written. Hi-fi masters kept in ${MASTERS}."
