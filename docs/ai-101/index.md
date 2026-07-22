# UPES-ECS — AI Emergency Assistant Line (Extension 101)

AI-first **triage** front end for the UPES-ECS campus emergency system, built on the
open-source **AVA — AI Voice Agent for Asterisk**
([github.com/hkjarral/AVA-AI-Voice-Agent-for-Asterisk](https://github.com/hkjarral/AVA-AI-Voice-Agent-for-Asterisk),
MIT) with a **fully-local LLM** (Ollama / llama.cpp, on-prem) as the triage brain — **no
cloud, no API keys, no internet for inference**.

> **Golden rule (from [SOP 19](design.md)):** if the AI is ever unsure
> → escalate to **111**. **111 stays human-first and must keep working even if every AI
> component is offline.** 101 never replaces 111; it collects details, gives ERT a
> pre-brief, and hands urgent/unclear calls straight to 111.

This folder is a **design + integration plan**, not shipped code. It shows how AVA is
wired onto the existing Asterisk stack (proven in [`../deploy/qemu/`](https://github.com/rohanbatrain/UPES-ECS/blob/main/deploy/qemu/README.md))
without weakening the human-first 111 line.

---

## What is here

| File | Purpose |
|---|---|
| `README.md` | This overview + how 101 maps to SOP 19. |
| [`Integration-Plan.md`](integration-plan.md) | Core doc: AVA architecture, Asterisk hooks, the local STT→LLM→TTS pipeline, dialplan wiring, incident logging, and the safety/fallback matrix. |
| [`deployment.md`](deployment.md) | How to run AVA alongside the QEMU Asterisk VM: install, config, local model hosting, ARI creds, health checks, phased rollout. |
| [`TODO.md`](todo.md) | Ordered build checklist to get a working 101 prototype. |

---

## The lines (never a single point of failure)

```text
111  Human-first Campus Emergency Hotline   — no AI dependency, EVER (see extensions_custom.conf)
102  Offline panic-coach (BUILT + LIVE)     — deterministic guidance, ZERO internet (ctx_ai_helpline)
101  AI Emergency Assistant Line (planned)  — AVA + LOCAL LLM triage, ALWAYS escalates to 111
196  Internal AI test line                  — AVA only, staff/ERT, never students
199  Drill / test                           198  echo/audio test
```

101 is a **thin, disposable layer** in front of the same `ert_emergency_queue` that 111
uses. If AVA, the local model host, or the STT/TTS pipeline fails, the call is thrown to
**111** and handled by humans exactly as it is today.

> **Already shipped — the offline floor beneath 101.** Extension **102** / `ctx_ai_helpline`
> (config [`../config/extensions_aihelpline.conf`](https://github.com/rohanbatrain/UPES-ECS/blob/main/config/extensions_aihelpline.conf)) is a
> **fully-offline, deterministic panic-coach** that is *already built and running*: when no
> responder answers 111 (queue timeout + escalation unanswered) the caller is coached through
> CPR, bleeding, choking, fire, lockdown, recovery position and being-trapped, with retry-a-
> responder and leave-a-message options — all on offline TTS, no cloud. It directly satisfies
> SOP 19's rule that the fallback must keep working **with every AI component offline**, and it
> is what 101 (AVA + local LLM) *upgrades* when a capable AI host is up, not replaces. So the real
> layering is: **111 (human) → 101 (local online AI triage, when the AI host is up) → 102 (offline
> coach) → voicemail.** Bringing up 101 does not touch 102; 102 remains the guaranteed floor.

---

## How this maps to SOP 19

| SOP 19 requirement | Where it lives in this design |
|---|---|
| §1 Two paths; 101 never replaces 111 | 101 dialplan does `Stasis()` → triage → `Dial`/`transfer` into the **existing** `ctx_emergency_111` / `ert_emergency_queue`. See [Integration-Plan §4](integration-plan.md#4-upes-ecs-dialplan-wiring). |
| §2 Call flow (answer → collect → pre-brief → escalate) | AVA local-LLM agent prompt + tool-calling; [Integration-Plan §3](integration-plan.md#3-the-local-stt--llm--tts-pipeline). |
| §3 Escalate-to-111 triggers | Encoded in the local-LLM system prompt **and** enforced by a hard dialplan fallback (defence in depth). [Integration-Plan §6](integration-plan.md#6-safetyfallback-matrix). |
| §4 Pre-brief (aid only, ERT decides) | The local LLM produces the structured summary; written to the `ai_*` incident fields. [Integration-Plan §5](integration-plan.md#5-incident-logging-ai_-fields). |
| §5 Hard limits (AI may / may NOT) | Prompt constraints + **no** AVA tools wired that could close/reject/page. [Integration-Plan §6](integration-plan.md#6-safetyfallback-matrix). |
| §6 Failure handling | Dialplan `Stasis()` failure branch → 111; transfer-fail → missed-incident record. [Integration-Plan §4](integration-plan.md#4-upes-ecs-dialplan-wiring). |
| §8 Deployment & privacy (keep audio local) | **Fully local stack → audio never leaves campus.** STT (faster-whisper/Vosk), LLM (Ollama/llama.cpp) and TTS (Piper) all run on-prem; zero cloud egress, no keys. This *strengthens* the privacy posture. [Integration-Plan §3.3](integration-plan.md#33-privacy-decision-fully-local-audio-stays-on-campus). |
| §9 Health checks | [deployment.md §5](deployment.md#5-health-checks). |
| §10 Rollout (196 → 101 test → students) | [deployment.md §6](deployment.md#6-phased-rollout). |
| [SOP 12](../operations/incident-logging-schema.md) §5 `ai_*` fields | [Integration-Plan §5](integration-plan.md#5-incident-logging-ai_-fields). |

---

## Verified vs assumed (be honest about AVA)

Everything in these docs is tagged. In short:

- **Verified** from the AVA README/docs: ARI + Stasis app `asterisk-ai-voice-agent`;
  AudioSocket (default) / ExternalMedia RTP transports; Python 3.11+ / Docker Compose
  two-container stack (`ai_engine` + optional `local_ai_server`); modular STT/LLM/TTS
  with a **fully-local pipeline** supported out of the box — STT via faster-whisper / Vosk,
  LLM via **Ollama / llama.cpp**, TTS via Piper — hosted in `local_ai_server`, no cloud
  provider required; `config/ai-agent.yaml` + `ai-agent.local.yaml` + `.env` config
  hierarchy; a `transfer` tool; Asterisk 18+ requirement.
- **Assumed / to-verify on our stack:** exact local-model config keys / model IDs, how
  AVA's `transfer` tool targets an Asterisk **queue** vs an extension, whether AVA writes
  our `ai_*` incident fields (it does **not** natively — we bridge that), Docker
  availability inside the QEMU VM, and — critically — **a host with enough CPU/GPU to run
  Whisper+LLM+Piper in real time** (the current TCG VM cannot; see
  [deployment.md §1](deployment.md#1-topology)). These are called out inline and in
  [`TODO.md`](todo.md).

> The **locked** thing is the emergency behaviour (SOP 19), not AVA. If AVA proves
> unsuitable, the same dialplan contract (`101 → triage → escalate to 111 → fallback to
> 111`) can front any other agent — but it must remain **local-first: no cloud AI**.
