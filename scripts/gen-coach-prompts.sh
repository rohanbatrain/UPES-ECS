#!/usr/bin/env bash
# ============================================================================
# UPES-ECS — generate the OFFLINE panic-coach + emergency front-door prompts.
# ONE consistent voice: Piper en_US-lessac-high (offline neural TTS). pico2wave
# is kept ONLY as a fallback so a build never fails to produce the life-safety
# prompts if Piper is missing. Output is Asterisk-native 8kHz mono 16-bit PCM WAV.
# Re-run any time to refresh. Guidance is concise, calm, universally-safe first aid.
# ============================================================================
set -euo pipefail
DEST=/usr/share/asterisk/sounds/en/upes-ecs/coach
ROOT=/usr/share/asterisk/sounds/en/upes-ecs
mkdir -p "$DEST"

# --- voice selection: Piper preferred, pico2wave fallback ---
PIPER_BIN="${PIPER_BIN:-/opt/piper/piper}"
PIPER_MODEL="${PIPER_MODEL:-/opt/piper/models/en_US-lessac-high.onnx}"
PICO_VOICE="${COACH_VOICE:-en-GB}"

if [ -x "$PIPER_BIN" ] && [ -f "$PIPER_MODEL" ]; then
  TTS=piper
  echo "TTS engine: Piper — $(basename "$PIPER_MODEL")"
elif command -v pico2wave >/dev/null 2>&1; then
  TTS=pico
  echo "WARNING: Piper not found ($PIPER_BIN / $PIPER_MODEL); using pico2wave ($PICO_VOICE) FALLBACK." >&2
else
  echo "ERROR: neither Piper nor pico2wave available — cannot generate prompts." >&2
  exit 1
fi

command -v sox >/dev/null 2>&1 || { echo "ERROR: sox not found." >&2; exit 1; }

# _synth <full-output-wav> <text>  — synth once, downsample to Asterisk 8k mono.
_synth() {
  local out="$1" text="$2" tmp
  tmp="$(mktemp --suffix=.wav)"
  if [ "$TTS" = piper ]; then
    printf '%s\n' "$text" | "$PIPER_BIN" --model "$PIPER_MODEL" --output_file "$tmp" 2>/dev/null
  else
    pico2wave -l "$PICO_VOICE" -w "$tmp" "$text"
  fi
  sox "$tmp" -r 8000 -c 1 -b 16 "$out"
  rm -f "$tmp"
}

say()     { local name="$1"; shift; _synth "$DEST/${name}.wav" "$*"; echo "  + coach/${name}.wav"; }
# sayroot: shared emergency prompts that live at the upes-ecs/ root (not coach/)
sayroot() { local name="$1"; shift; _synth "$ROOT/${name}.wav" "$*"; echo "  + ${name}.wav"; }

say intro "You have reached the campus emergency guidance line. No responder is free at this moment, and help has been alerted to call you back. Stay calm. Take a slow breath. I will guide you through what to do. If you are able, also call your national emergency number now."

say intro-test "This is the campus emergency guidance line, in test mode. No real incident is being logged. I will guide you through what to do in an emergency."

say menu "Choose the situation. Press 1 if someone is not breathing or has no pulse. Press 2 for severe bleeding. Press 3 for choking. Press 4 for fire or smoke. Press 5 for a threat, attacker, or lockdown. Press 6 if someone is unconscious but breathing. Press 7 if you are trapped. Press 9 to try a responder again. Press 8 to leave a message. Press 0 to hear these choices again."

say cpr "Put the person on their back on a firm surface and kneel beside them. Place the heel of one hand in the centre of the chest, and your other hand on top. Push down hard and fast, about twice every second, letting the chest rise fully each time. Keep going without stopping. If someone is nearby, send them for the nearest defibrillator, and turn it on to follow its spoken instructions. Do not stop until help arrives or the person wakes."

say bleeding "Press firmly and directly on the wound with a cloth or your hand. Do not remove the cloth. If blood soaks through, add more on top and keep pressing hard. If it is an arm or a leg and the bleeding will not stop, tie a strong band tightly a few centimetres above the wound, between the wound and the heart, and note the time. Keep the person warm and still."

say choking "Ask if they can speak or cough. If they cannot breathe, stand behind them and give five firm blows between the shoulder blades with the heel of your hand. If that does not work, wrap your arms around their waist and give five quick inward and upward thrusts just above the navel. Keep repeating the back blows and the thrusts until the object comes out or help arrives."

say fire "Get everyone out now, and do not stop for belongings. Stay low under the smoke, where the air is clearer. Before opening any door, feel it with the back of your hand. If it is hot, find another way out. Do not use the lifts. Once you are outside, stay outside, and move to the assembly point. Do not go back in."

say lockdown "If you can leave the area safely, move away from the danger quietly and quickly. If you cannot, get into a room, lock or block the door, and stay low, away from windows and doors. Turn off the lights and set your phone to silent. Stay quiet and out of sight. Do not open the door until security or the police tell you it is safe."

say recovery "If the person is breathing but not awake, gently roll them onto their side. Tilt their head back a little to keep the airway open, and lift their chin. Stay with them and keep watching that they are still breathing. If they stop breathing, begin chest compressions in the centre of the chest."

say trapped "Stay as calm and still as you can, to save air and energy. Cover your nose and mouth with cloth against dust. Tap steadily on a pipe, a wall, or any hard surface, so rescuers can hear you. Shout only as a last resort, to avoid breathing in dust. Do not light any flame. Move as little as possible and wait to be found."

say tryagain "I am trying to reach a responder now. Please stay on the line and hold."
say noresponder "No responder is free yet. I will stay with you. Returning to the guidance."
say invalid "Sorry, I did not understand that."
say nochoice "I did not hear a choice."
say leavemsg "I will now let you leave a message for the response team. After the tone, say where you are and what is happening."

# Language chooser played when the caller presses * during the coach (see extensions_aihelpline.conf).
# Digit words are spoken; the caller presses the physical 1/2 key. Add a language -> extend this line.
say pick-language "To change the language, press 1 for English, or 2 for Hindi."

say fastpath-intro "First aid guidance. A responder is still being alerted and will join if they can. Stay with me."

# ---- shared 111-flow prompts (disaster-ready front door) ----
sayroot emergency-preanswer "You have reached the campus emergency line. Your call is being recorded, and help is being reached now. Stay on the line. If someone needs first aid right now, press 1 at any time, and I will guide you."

sayroot hold-firstaid "Still connecting you to a responder. If you need first aid now, press 1 for step by step guidance."

sayroot responder-alert "Emergency alert. There is an active call on the campus emergency line and no responder has answered. Please make yourself available now. Press 1 to join the emergency queue."

sayroot shift-on "You are now on shift. You will receive campus emergency calls until you go off shift by dialling star two three."
sayroot shift-off "You are now off shift. You will no longer receive campus emergency calls."

# ---- *55 self-service "set my language" prompts (ctx_setlang) ----
sayroot lang-ask "To set the language for your emergency calls, enter your language number, then press the hash key. Your language number is listed in the campus directory."
sayroot lang-set "Your emergency language has been set. This is how your calls will now sound."
sayroot lang-badcode "Sorry, that is not a valid language number. Please check the campus directory, and try again."

# retire the placeholder preanswer so the real one is used
rm -f "$ROOT/emergency-preanswer.gsm" 2>/dev/null || true

chown -R asterisk:asterisk "$ROOT" 2>/dev/null || true
echo "panic-coach + 111-flow prompts written to $ROOT"
