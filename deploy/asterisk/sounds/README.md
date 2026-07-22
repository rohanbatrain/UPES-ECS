# EAS voice prompts (Emergency Alert Service)

> **Not committed to the repo.** The generated `.wav` prompts (~1 GB across 44
> languages) are **not** stored in git — this keeps clones lightweight and free of any
> Git LFS dependency. They are **regenerated at setup** with neural Piper TTS:
>
> - `Install-UpesEcs.ps1` builds and pushes every language pack automatically, **or**
> - run the generators directly: `scripts/gen-coach-prompts.win.ps1`,
>   `scripts/gen-rest-prompts.win.ps1`, `scripts/gen-lang-prompts.win.ps1`,
>   `scripts/gen-callout-prompts.sh` (voices listed in `i18n/TTS-VOICES.md`).
>
> Verify coverage afterwards with `scripts/verify-prompt-coverage.ps1`.

Pre-generated audio for the mass call-out / roll-call feature (`mass_callout.sh` →
`[ctx_callout]`). These are the messages the **UPES Emergency Alert Service** plays to
phones during a callout. The image ships them (see `deploy/Dockerfile`), so callouts have
real audio out of the box.

## Files

```
en/custom/upes-evacuate.wav     "Evacuate the building now…"
en/custom/upes-shelter.wav      "Shelter in place now…"
en/custom/upes-allclear.wav     "The emergency is now over…"
en/custom/upes-assemble.wav     "Proceed to your assembly point now…"
en/custom/upes-rollcall.wav     "Safety head count. Press one if you are safe."
en/custom/upes-test.wav         "This is a test… no action required."
en/upes-ecs/rollcall-press1.wav "Press one if you are safe."   (Read() prompt)
en/upes-ecs/rollcall-thanks.wav "Thank you. You are marked safe…"
en/upes-ecs/rollcall-noack.wav  "No response was recorded…"
masters/*.master.wav            hi-fi 22.05 kHz masters (kept per SOP 28; not served)
```

The `custom/upes-*` names match the Console message picker (`MESSAGES` in `Console/app.js`);
the `upes-ecs/rollcall-*` names are what `[ctx_callout]` calls. Exact wording lives in
[SOP 28](../../SOP/28-Voice-Prompt-Scripts.md).

## Format

Asterisk-native **8 kHz, mono, 16-bit PCM WAV** (normalized, silence-trimmed).

## How they were generated

Professional on-prem **Piper neural TTS** (voice `en_US-lessac-high` — clear, neutral
authority; the same Piper family the AI-101 stack and Paridyum's `pd-ai-speech` voice map
use). Not the robotic `pico2wave` the offline panic-coach uses.

To regenerate (e.g. new wording or a different voice), run
[`scripts/gen-callout-prompts.sh`](../../scripts/gen-callout-prompts.sh) with `PIPER_MODEL`
pointed at your voice (install piper-tts + a voice, then run it). The committed files here were
produced with Piper voice `en_US-lessac-high` and downsampled with `sox`.

> Note on Piper: pass the voice via `PIPER_MODEL` (a full path to the `.onnx`); do **not**
> also pass `--download-dir` when the voice already exists — in the piper-tts CLI it truncates
> synthesis to the first few seconds.

## Loading into a running container (no rebuild)

```sh
SB=deploy/asterisk/sounds/en
docker cp "$SB/custom"   upes-ecs-asterisk:/usr/share/asterisk/sounds/en/
docker cp "$SB/upes-ecs" upes-ecs-asterisk:/usr/share/asterisk/sounds/en/
docker exec upes-ecs-asterisk chown -R asterisk:asterisk \
  /usr/share/asterisk/sounds/en/custom /usr/share/asterisk/sounds/en/upes-ecs
```
