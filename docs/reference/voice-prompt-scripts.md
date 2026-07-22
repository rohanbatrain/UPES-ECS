# UPES-ECS Voice Prompt Scripts

Exact wording for every recorded prompt the system plays. Hand this to whoever records
the audio. Every line traces to a locked decision in the specs.

---

## Recording specs

| Setting | Value |
|---|---|
| Format | WAV, **8 kHz, 16-bit, mono** PCM (Asterisk-native; also keep a hi-fi master) |
| Location | `/var/lib/asterisk/sounds/en/upes-ecs/` (drop the `.wav` extension when calling in dialplan) |
| Voice | Calm, clear, unhurried, neutral authority. No music. No echo. |
| Level | Consistent volume, no clipping; short lead-in silence trimmed |
| Language | **English first.** Hindi versions are a later enhancement (record as `.../hi/upes-ecs/`) |

> Keep every emergency prompt **short**. In a crisis, long prompts cost time.

---

## Core emergency prompts

### `emergency-preanswer` — played when 111 is answered
> "You have reached UPES Emergency Response. Your emergency call may be recorded. Please stay on the line."

### `queue-hold` — periodic announcement while waiting in the ERT queue
> "Campus emergency line. Please stay on the call. A responder will answer shortly."

*(No hold music on emergency calls — this announcement only.)*

### `emergency-voicemail-prompt` — played when all responders miss the call
> "No UPES Emergency Response member is available at this moment. Please state your name, SAP ID, location, and emergency clearly. Stay near your phone for a callback."

*(Max message length 60 seconds.)*

### `silent-caller-cue` — optional, spoken by the responder or as a prompt on a silent 111 call
> "This is UPES Emergency Response. If you can hear me but cannot speak, press any key now."

---

## Drill & test prompts

### `drill-prompt` — played on 199
> "This is a UPES-ECS drill call. No real emergency response will be dispatched."

### `drill-voicemail-prompt` — drill missed-call test
> "This is a UPES-ECS drill. This is a test of the emergency voicemail. Please leave a short test message after the tone."

---

## Access / feature prompts

### `not-authorized` — restricted feature reached from a role that isn't allowed
> "You are not authorized to use this feature. If this is an emergency, dial one one one."

### `queue-paused` — after `*45`
> "You are now paused from the emergency queue."

### `queue-resumed` — after `*46`
> "You are now active in the emergency queue."

---

## Paging prompts (spoken live by the operator — templates, not recordings)

### All-campus / zone start phrase
> "Attention. This is UPES Emergency Response."

### Full announcement template
> "Attention. This is UPES Emergency Response. [Instruction]. [Area affected]. [What to do]. Await further instructions."

**Example:**
> "Attention. This is UPES Emergency Response. Students in Hostel B, evacuate using the main staircase. Move to the football ground assembly point. Do not use elevators. Await further instructions."

### Paging **drill** prefix (spoken before any paging test)
> "Drill, drill, drill. This is a UPES-ECS drill. No real emergency response will be dispatched."

---

## AI Assistant Line 101 prompts (later phase — Feature 19)

### `ai-101-opening`
> "You have reached the UPES-ECS AI Emergency Assistant. If this is an immediate emergency, say emergency or dial one one one at any time. Please tell me what happened and where you are located."

### `ai-101-escalation`
> "This sounds urgent. I am connecting you to UPES Emergency Response now. Please stay on the line."

### `ai-101-noncritical`
> "I have recorded your request and will route it to the appropriate support path if available. If this becomes urgent, dial one one one immediately."

### `ai-101-failure`
> "The AI Emergency Assistant is currently unavailable. Connecting you to UPES Emergency Response now."

### `ai-101-drill`
> "This is a UPES-ECS AI emergency drill. No real emergency response will be dispatched unless the drill controller approves it."

---

## Offline Panic-Coach (102) prompts

The offline coach (`ctx_ai_helpline`, dialable on **102** and the automatic fallback
when no human answers 111) plays its **own** deterministic first-aid prompts —
one prompt set per topic: **CPR · bleeding · choking · fire · lockdown · recovery ·
trapped**, plus the retry (`9`) / leave-message (`8`) menu. These are **generated
TTS**, not hand-recorded: they are produced by **`gen-coach-prompts.sh`** (local
Piper voice, no cloud), so they are regenerated rather than re-read by a person.
Keep the wording source-controlled with that script.

---

## Emergency Alert Service (EAS) — mass call-out / roll-call prompts

The mass call-out engine (`mass_callout.sh` → `[ctx_callout]`) rings phones as the
**Emergency Alert Service** (caller ID **`UPES-EAS` <111>**, never ANONYMOUS) and plays one
of these announcements. Like the panic-coach prompts they are **generated TTS, not
hand-recorded** — but with the **professional on-prem Piper neural voice** (not pico2wave),
produced by **`gen-callout-prompts.sh`**. Keep the wording source-controlled with that script.
House style follows the paging template: *"Attention. This is the UPES Emergency Alert Service.
[Instruction]. Await further instructions."* — kept short.

### Announcement set (`custom/upes-*`)

| Prompt file | Wording |
|---|---|
| `custom/upes-evacuate` | "Attention. This is the UPES Emergency Alert Service. Evacuate the building now. Leave immediately by the nearest safe exit. Do not use the lifts. Move to your assembly point and await further instructions." |
| `custom/upes-shelter` | "Attention. This is the UPES Emergency Alert Service. Shelter in place now. Move indoors, lock or block your door, stay away from windows, and remain quiet until you are told it is safe. Await further instructions." |
| `custom/upes-allclear` | "Attention. This is the UPES Emergency Alert Service. The emergency is now over. It is safe to resume normal activity. Thank you for your cooperation." |
| `custom/upes-assemble` | "Attention. This is the UPES Emergency Alert Service. Proceed to your designated assembly point now. Move calmly, help others where you can, and wait to be counted. Await further instructions." |
| `custom/upes-rollcall` | "Attention. This is the UPES Emergency Alert Service. This is a safety head count. If you are safe and able to respond, press one now." |
| `custom/upes-test` | "This is a test of the UPES Emergency Alert Service. This is only a test. No action is required, and no emergency response will be dispatched." |

### Roll-call control prompts (`upes-ecs/rollcall-*`, played by `[ctx_callout]`)

| Prompt file | Wording |
|---|---|
| `upes-ecs/rollcall-press1` | "Press one if you are safe." *(the `Read()` prompt)* |
| `upes-ecs/rollcall-thanks` | "Thank you. You are marked safe. You may now hang up." |
| `upes-ecs/rollcall-noack` | "No response was recorded. Please contact your warden as soon as you are able." |

---

## Prompt → dialplan reference

| Prompt file | Called in | Doc |
|---|---|---|
| `emergency-preanswer` | `ctx_emergency_111` | [09](../guides/dialplan-design.md) / [Feature 1](../features/feature-01.md) |
| `queue-hold` | queue announcement | [Feature 2](../features/feature-02.md) |
| `emergency-voicemail-prompt` | `ctx_emergency_vm` | [Feature 10](../features/feature-10.md) |
| `silent-caller-cue` | ERT SOP Part I | [02](../operations/ert-sop.md) |
| `drill-prompt` | `ctx_drill_199` | [03](../operations/drill-test-sop.md) |
| `not-authorized` | `ctx_denied` | [26](../guides/security-hardening.md) |
| `queue-paused` / `queue-resumed` | `*45` / `*46` | [09](../guides/dialplan-design.md) |
| `ai-101-*` | 101 flow (later) | [19](../ai-101/design.md) |
| `custom/upes-*` (EAS set) | `[ctx_callout]` via `mass_callout.sh` | [FEATURES](https://github.com/rohanbatrain/UPES-ECS/blob/main/config/FEATURES.md) · `gen-callout-prompts.sh` |
| `upes-ecs/rollcall-*` | `[ctx_callout]` roll-call | `gen-callout-prompts.sh` |

---

## Checklist before go-live

- [ ] All core prompts recorded in English, correct wording, calm tone.
- [ ] Converted to 8 kHz mono WAV and placed in `.../en/upes-ecs/`.
- [ ] Test call confirms each plays clearly at the right moment.
- [ ] Drill prompts clearly distinguishable from real ones.
- [ ] Hi-fi masters archived (for re-encoding / Hindi versions later).
