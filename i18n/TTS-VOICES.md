# Offline TTS voices for UPES-ECS regional prompts

UPES-ECS is a **LAN-only, offline** emergency PBX. Every voice prompt is
pre-generated on the **Windows host** (the QEMU VM is far too slow for neural
inference) and baked into the deploy tree at
`deploy/asterisk/sounds/lang/<lang>/<file>`. At deploy time the VM downsamples
the 22.05 kHz host WAVs to Asterisk's 8 kHz with `sox`.

This document records the researched **on-premises** (no cloud API) TTS option
for each regional language, with a concrete recommendation and the exact model
URL or install step. It is consumed by `scripts/gen-lang-prompts.win.ps1` via
`i18n/languages.json`.

Two engines are supported by the generator, in priority order:

1. **Piper** neural TTS — natural, clear, 22.05 kHz. Preferred whenever a voice
   model exists for the language. Same engine already used for English
   (`en_US-lessac-high`).
2. **eSpeak-NG** — formant synth, fully offline, no model download, robotic but
   intelligible. Universal fallback for languages Piper does not cover.

---

## Hindi (hi / hi_IN)  — RECOMMENDED: Piper `hi_IN-pratham-medium`

Piper **does** ship Hindi voices in the canonical `rhasspy/piper-voices`
HuggingFace repo. Three `hi_IN` speakers exist, all **medium** quality
(22.05 kHz), all trained on the **AI4Bharat `indicnlp_corpus`**, all licensed
**CC BY-NC-SA 4.0** (non-commercial + attribution + share-alike — acceptable for
an internal, non-commercial university safety system; keep attribution in the
repo, do not resell):

| Voice | Quality | Speaker | Model file | Verified |
|-------|---------|---------|------------|----------|
| **pratham**    | medium (22.05 kHz) | male   | `hi_IN-pratham-medium.onnx` (63.5 MB)    | HTTP 200 |
| **priyamvada** | medium (22.05 kHz) | female | `hi_IN-priyamvada-medium.onnx`           | HTTP 200 |
| **rohan**      | medium (22.05 kHz) | male   | `hi_IN-rohan-medium.onnx`                | HTTP 200 |

### Recommendation
Use **`hi_IN-pratham-medium`** as the default Hindi voice. Rationale:
- It is the most widely referenced / canonical `hi_IN` Piper voice.
- Medium quality = **22.05 kHz mono**, identical to the English pipeline, so the
  existing VM downsample-to-8 kHz step needs no change.
- A clear male voice reads as authoritative for PA-style mass announcements
  (evacuate / shelter / all-clear).

If voice-gender consistency with the English `lessac` (female) voice is
preferred, switch to **`hi_IN-priyamvada-medium`** — same quality/dataset, just
edit the `hi` entry in `i18n/languages.json` (`piper_voice` + the two URLs).
`hi_IN-rohan-medium` is a second male option.

### Exact download (host, one-time)
Piper needs the `.onnx` **and** its `.onnx.json` config side by side:

```
# pratham (recommended)
https://huggingface.co/rhasspy/piper-voices/resolve/main/hi/hi_IN/pratham/medium/hi_IN-pratham-medium.onnx
https://huggingface.co/rhasspy/piper-voices/resolve/main/hi/hi_IN/pratham/medium/hi_IN-pratham-medium.onnx.json
```

PowerShell (save next to the English model in `C:\Users\Rohan\piper-model\`):

```powershell
$base = 'https://huggingface.co/rhasspy/piper-voices/resolve/main/hi/hi_IN/pratham/medium'
$dst  = 'C:\Users\Rohan\piper-model'
Invoke-WebRequest "$base/hi_IN-pratham-medium.onnx"      -OutFile "$dst\hi_IN-pratham-medium.onnx"
Invoke-WebRequest "$base/hi_IN-pratham-medium.onnx.json" -OutFile "$dst\hi_IN-pratham-medium.onnx.json"
```

Then generate:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\gen-lang-prompts.win.ps1 -Lang hi `
  -Model C:\Users\Rohan\piper-model\hi_IN-pratham-medium.onnx
```

(If `-Model` is omitted the generator resolves the file name from
`languages.json` and looks for it beside the English model.)

> Note: Piper Hindi expects **Devanagari** input text (the phonemizer uses
> eSpeak-NG's `hi` phoneme rules under the hood). Keep `i18n/translations/hi.csv`
> in native Devanagari, UTF-8. The generator reads the CSV as UTF-8 so the script
> can stay ASCII-only (PowerShell 5.1 mis-parses non-ASCII in a no-BOM `.ps1`).

### Fallback: eSpeak-NG (`-v hi`)
If a site cannot or will not download the Piper model, eSpeak-NG synthesizes
Hindi fully offline with **no model download**:

```
espeak-ng -v hi -w out.wav "<devanagari text>"
```

It is robotic and flat but phonetically intelligible — acceptable as a
last-resort fallback, not for the primary deployment. The generator falls back
to eSpeak-NG automatically when no Piper model is found for the language.

### Other on-prem options considered (not recommended here)
- **AI4Bharat Indic-TTS / IndicF5** — highest-quality Indic neural voices, but
  heavy (PyTorch/GPU-oriented), a large dependency stack, and slow on the CPU
  host. Overkill for 41 short fixed prompts; Piper already uses AI4Bharat data.
- **Coqui TTS (VITS Hindi)** — good quality but the upstream project is archived
  and the Python/torch install is far heavier than a single Piper `.exe` + model.
- **Cloud (Google/Azure/AWS Polly Hindi)** — **disqualified**: this is a
  no-cloud, LAN-only system.

**Verdict for Hindi: Piper `hi_IN-pratham-medium`, eSpeak-NG `-v hi` as the
zero-download fallback.**

---

## Adding another regional language later

1. Add its entry to `i18n/languages.json` (`code`, `native`, and either a
   researched `piper_voice` + `piper_url` [+ `piper_config_url`], or leave
   `piper_voice` null to use eSpeak-NG via `espeak_lang`).
2. Drop `i18n/translations/<code>.csv` (columns `id,en,<code>`).
3. Run `scripts\gen-lang-prompts.win.ps1 -Lang <code>`.

Check Piper coverage first at
<https://huggingface.co/rhasspy/piper-voices/tree/main> and preview timbre at
<https://rhasspy.github.io/piper-samples/>. If Piper has no model for the
language, eSpeak-NG (`espeak-ng --voices`) almost certainly does — use that.

---

## Sources
- rhasspy/piper-voices (HuggingFace): <https://huggingface.co/rhasspy/piper-voices/tree/main/hi/hi_IN>
- Piper voice samples: <https://rhasspy.github.io/piper-samples/>
- pratham MODEL_CARD (AI4Bharat indicnlp_corpus, CC BY-NC-SA 4.0, 22,050 Hz):
  <https://huggingface.co/rhasspy/piper-voices/raw/main/hi/hi_IN/pratham/medium/MODEL_CARD>
- AI4Bharat indicnlp_corpus: <https://github.com/AI4Bharat/indicnlp_corpus>
- eSpeak-NG: <https://github.com/espeak-ng/espeak-ng>

All four `hi_IN` resolve URLs above were verified live (HTTP 200) on 2026-07-08.
