# AI-101 Build Checklist — working 101 prototype

Ordered path to a working AVA + **local-LLM** extension **101** that obeys
[SOP 19](../SOP/19-AI-101-Design.md). **No cloud AI** — STT, LLM and TTS all run on-prem.
Do these in order; **do not** enable 101 for students until Phase 2 gates pass.
🔒 = SOP-locked, non-negotiable.

Legend: `[ ]` todo · ✅ verified fact · ⚠️ must verify on our stack.

---

## 0. Prerequisites

- [ ] Confirm the QEMU VM is up and **111 works today** (baseline): call 111 → ANSWERED
      (already proven ✅ in [../deploy/qemu/README.md](../deploy/qemu/README.md)).
- [ ] Read [Integration-Plan.md](Integration-Plan.md) and [deployment.md](deployment.md).
- [ ] No cloud sign-off needed (nothing leaves campus). Instead, confirm budget/availability
      of a **dedicated AI host** (see §1). Internal 196 only until quality is proven.

## 1. Decide the AI host + pick the local model ⚠️ (the critical prerequisite)

- [ ] 🔒 **You need a capable host.** The current TCG VM **cannot** run the local models in
      real time (~15s+/turn). Choose **(b) a dedicated CPU/GPU box on the mgmt LAN**
      ([deployment.md §1](deployment.md#1-topology)). Option (a) in-VM is wiring/smoke-test
      only, not a working 101.
- [ ] **Size the hardware to the model** (decision to record):
      - **LLM:** Llama 3.1 8B or Qwen2.5 7B instruct, ~4–5 GB VRAM at Q4 (fits an 8 GB GPU);
        larger quant/model → more VRAM. Target GPU turn latency ~0.5–2s.
      - **STT:** faster-whisper (small/medium) or Vosk; **TTS:** Piper — modest, but budget
        headroom on top of the LLM.
      - ⚠️ **TODO for the user:** confirm final model + GPU (VRAM) sizing before Phase 1.5b.
- [ ] If a GPU host: install NVIDIA driver + Container Toolkit; `nvidia-smi` works.
- [ ] Verify **Docker + Docker Compose v2** present (`docker compose version`); install if
      missing ⚠️.

## 2. Get AVA running (STT/TTS wired, model pulled)

- [ ] `git clone` AVA into `/opt/ava`; read its own README for exact steps.
- [ ] Enable **ARI** in Asterisk bound to **localhost/mgmt only**; create ARI user `ava`
      with a strong password (`ari.conf`, `http.conf`) ⚠️.
- [ ] `agent setup` → `agent check --local`: ARI reachable, transport = **AudioSocket** ✅,
      local STT/LLM/TTS load.
- [ ] `ollama pull qwen2.5:7b-instruct` (or `llama3.1:8b-instruct`); place faster-whisper
      and Piper model files into `local_ai_server`. After first pull the host can run
      **air-gapped**.
- [ ] Confirm Stasis app registers: `asterisk -rx "ari show apps"` shows
      `asterisk-ai-voice-agent` ✅.

## 3. Local model management (NO keys) 🔒

- [ ] 🔒 **No LLM API key exists** — inference is local. Confirm `config/ai-agent.local.yaml`
      points the LLM at the **local** Ollama/llama.cpp endpoint (e.g.
      `http://localhost:11434`), never an external URL.
- [ ] The **only** secret is the ARI credential in `/opt/ava/.env` (`chmod 600`, git-ignored ✅).
- [ ] Pin model versions/digests; back up model files so a rebuild needs no internet.
- [ ] Confirm `.env` and `config/ai-agent.local.yaml` are in `.gitignore`.

## 4. Configure the `upes-ecs-101` agent

- [ ] In `config/ai-agent.local.yaml`: agent slug **`upes-ecs-101`**, pipeline =
      **fully local** (faster-whisper + Ollama/llama.cpp + Piper) ✅.
- [ ] Paste the **SOP 19 system prompt** (opening / collect / escalation / hard limits)
      from [Integration-Plan §3.2](Integration-Plan.md#32-triage-system-prompt-lives-in-the-ava-agent-config).
- [ ] Enable **only** the `transfer` tool (→ ext `111`) + a post-call HTTP hook.
      🔒 **Do NOT** enable close / false-alarm / page / voicemail-instead-of-escalate.
- [ ] `agent config validate` passes ✅.

## 5. Add the dialplan (196 + 101 + fallback)

- [ ] Add `ctx_ai_196`, `ctx_ai_101`, `ctx_ai_fallback` to
      [../config/extensions_custom.conf](../config/extensions_custom.conf)
      ([Integration-Plan §4](Integration-Plan.md#4-upes-ecs-dialplan-wiring)).
- [ ] Record prompt `upes-ecs/ai-unavailable` (SOP 19 failure line) into the sounds dir
      ([SOP 28](../SOP/28-Voice-Prompt-Scripts.md)).
- [ ] `include => ctx_ai_196` in **ctx_staff / ctx_ert only** (NOT ctx_student). Leave
      `ctx_ai_101` **out** of student contexts for now.
- [ ] Reload dialplan; **test order 198 → 196 → 101 → 111**.

## 6. Prove escalation (101 → 111) 🔒

- [ ] Call 196, run a mock "student fainted in Hostel A" scenario → AI classifies Medical/
      High → `transfer` → caller lands in `ert_emergency_queue` (existing 111 flow).
- [ ] Verify the escalation phrase / "I want a human" / "emergency" all transfer to 111.
- [ ] Confirm `INCIDENT_ID` survives the transfer (or that `ctx_emergency_111` mints one) ⚠️.

## 7. Prove fallback (any failure → 111) 🔒

- [ ] Stop AVA (`docker compose stop`), call 101/196 → hear `ai-unavailable` → routed to
      111. **This is the most important test.**
- [ ] Stop the local model (`ollama stop` / kill `local_ai_server`) → AVA errors out of
      Stasis → fallback → 111.
- [ ] Simulate transfer-to-111 fail → **critical missed AI emergency** record created +
      ERT alerted (`missed_incident.sh` path) ⚠️.
- [ ] Confirm **111 is identical** with AVA up vs down.

## 8. Incident logging (`ai_*` fields)

- [ ] Build the small post-call endpoint / `ai_incident.sh` that writes `ai_summary`,
      `ai_detected_category`, `ai_detected_location`, `ai_urgency_hint`,
      `ai_questions_completed` keyed by `INCIDENT_ID`
      ([Integration-Plan §5](Integration-Plan.md#5-incident-logging-ai_-fields)).
- [ ] Verify a 101 incident shows `source_number=101`, `ai_triage_enabled=true`,
      `transferred_to_111`, `transfer_time`, and is **ERT-editable** (SOP 12 §5).
- [ ] Confirm **AI cannot close** an incident (no such tool; only ERT Lead closes) 🔒.

## 9. Health checks

- [ ] Add a **101-only, non-blocking** AVA probe to the health script (never flips
      system/111 to Critical on its own) — [deployment.md §5](deployment.md#5-health-checks).
- [ ] Green: engine up, ARI app present, STT/LLM/TTS up, 196+101 answer, 101→111 transfer,
      fallback, response time, `ai_*` written.

## 10. Pilot & advance (per SOP 19 §10)

- [ ] **Phase 1.5a:** 196 internal only — soak test, tune prompt/latency.
- [ ] **Phase 1.5b:** enable 101 for **ERT test extensions**; Incident Commander reviews +
      approves prompt/routing.
- [ ] **Before Phase 2 (students):** 🔒 confirm the **dedicated AI host** meets the latency
      budget, record the (already-local) privacy decision
      ([Integration-Plan §3.3](Integration-Plan.md#33-privacy-decision-fully-local-audio-stays-on-campus)),
      then add `include => ctx_ai_101` to student/staff contexts. No cloud approval needed.
- [ ] Document the **kill switch** (remove include / stop AVA → callers get 111) in the
      ERT runbook.

---

### Definition of done (prototype)

196 answers with **local-LLM** triage · 101 escalates urgent/unclear to 111 · **any** AI
failure falls back to 111 · `ai_*` pre-brief logged and ERT-editable · **111 works with AVA
fully stopped** · **no cloud, no API keys, nothing leaves campus** · privacy decision
recorded for the Phase 2 gate.
