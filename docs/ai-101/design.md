# UPES-ECS AI Emergency Assistant (101) — local online triage layer

**Status:** Design approved · **Phase:** 1.5 / 2 (not required for go-live) · local-first
**AVA** ([github.com/hkjarral/AVA-AI-Voice-Agent-for-Asterisk](https://github.com/hkjarral/AVA-AI-Voice-Agent-for-Asterisk)) + a **fully-local LLM** (Ollama/llama.cpp, on-prem — no cloud).

> Golden rule: **If the AI is ever unsure → escalate to a human.**
> 111 stays human-first and must keep working even if every AI component is offline.

> ### ⚠️ Updated model (2026-07) — read this first
> Earlier drafts described 101 as a **number the caller dials** ("AI-first triage"). That is
> **superseded** and must not be built that way. Grounded in Emergency Medical Dispatch and
> modern 911-AI practice (no redial loops; stay on the line; human-first):
> - **The campus learns exactly one number: `111`.** `101` and `102` are **internal routes
>   the system invokes** — a caller is **never** told to hang up and dial them.
> - **101 is a *local* AI capability that rides a 111 call** (via AVA/ARI), running the whole
>   STT→LLM→TTS pipeline **on-prem with zero internet** — no cloud, no API keys, audio never
>   leaves the premises. It gives the ERT a spoken pre-brief and escalates urgent/unclear cases
>   to humans. When the local AI host is **down** or AVA fails, it transparently falls back to
>   **102**.
> - **102, the offline panic-coach, is already BUILT and LIVE** (`ctx_ai_helpline`,
>   [`../config/extensions_aihelpline.conf`](https://github.com/rohanbatrain/UPES-ECS/blob/main/config/extensions_aihelpline.conf)) — a
>   deterministic first-aid decision tree that needs **zero internet**. It is the guaranteed
>   floor beneath 101, and it satisfies this SOP's rule that the fallback works with every AI
>   component offline. Bringing up 101 does **not** touch 102.

---

## 1. The layered model (one number, graceful degradation)

```text
111  Human-first Campus Emergency Hotline   — no AI/internet dependency, EVER
 └─ 101  Local AI triage (AVA + local LLM)  — rides 111 when the AI host is up; pre-brief; human-first
 └─ 102  Offline panic-coach (BUILT + LIVE) — deterministic first-aid; ZERO internet
 └─ voicemail → Missed Incident             — never a dead end
199  Drill / Test                           196  Internal AI test (later)
```

Order of preference on an unanswered 111: **human → 101 (if the local AI host is up) → 102 (always) → voicemail.**

- 101 is **not** a replacement for 111, **not** a general chatbot, and **not** a dialled number.
- 101 collects details, gives a pre-brief, and hands urgent/unclear cases to humans.
- 102 is what a caller actually hears when no human is free and AI is unavailable/offline.

---

## 2. 101 call flow

The caller **never dials 101** — they dial **111**. 101 is the local-AI capability the
system routes a 111 call into **when the AI host is online** (otherwise the call goes to
humans, then the 102 offline coach). From the caller's side it is one continuous call.

```text
1. Caller dials 111 (the only number)
2. If the AI host is online, the system routes the call to the local AI triage (101)
3. AI answers, states: immediate emergency → say "emergency" or you'll be connected to a person
4. AI asks: what happened, where, injury/danger, are you safe, can you stay on, name/SAP ID
5. AI builds a structured summary (pre-brief) for the ERT
6. Urgent / unclear / high-risk → transfer/escalate to a human on 111
7. Non-critical → assistance log or approved support path
8. Escalated calls link to an incident record
9. Any AI failure / host offline → fall back to a human, then the 102 offline coach
```

**Opening prompt:**
> "You have reached UPES Emergency. If this is an immediate emergency, say emergency or stay on the line to reach a responder. Please tell me what happened and where you are located."

**Escalation prompt:** "This sounds urgent. I am connecting you to UPES Emergency Response now. Please stay on the line."

**Failure prompt:** "The AI Emergency Assistant is currently unavailable. Connecting you to UPES Emergency Response now."

---

## 3. Escalate-to-111 triggers

Medical/injury/unconscious · violence/threat/harassment · fire/smoke/accident ·
security/hostel/infrastructure danger · panic · caller says "emergency" · caller asks
for a human · AI can't understand · **AI is unsure**. When in doubt, escalate.

---

## 4. AI pre-brief (aid only — ERT decides)

```text
Caller: Name / SAP ID
Location: Hostel A, near main gate
Category: Medical
Urgency Hint: High
Summary: Caller reports a student fainted and is not responding.
Caller Status: Can stay on line
Recommended Path: ERT + Medical Room
```

Logged with the `ai_*` fields in [12-Incident-Logging-Schema.md](../operations/incident-logging-schema.md). ERT can override the summary/category.

---

## 5. Safety model (hard limits)

**AI may:** collect info · summarize · route to approved destinations · escalate to 111 · create assistance logs · support drills.

**AI may NOT:** replace ERT · delay 111 · reject an emergency · mark false alarm ·
close an incident · suppress escalation · page all-campus · give medical diagnosis ·
give risky instructions · call unauthorized users · access unrelated student data.

---

## 6. Failure handling (never a single point of failure)

```text
AI down / too slow / STT fails / can't classify / caller asks for human → transfer to 111
Transfer to 111 fails → create critical missed AI emergency record + alert ERT/control room
```

Severity: 111 failure = **Critical**; 101 AI failure = **Warning/Degraded** if 111 works; 101 unable to reach 111 = **Critical for the AI feature**.

---

## 7. Access model

| Role | Can |
|---|---|
| Students / Staff | Call 101; be transferred to 111. **No** access to AI logs/summaries/recordings. |
| ERT | Receive escalated 101 calls; view pre-briefs; override AI summary/category. |
| ERT Lead / Incident Commander | Review AI-assisted incidents; approve prompt/routing changes; **disable 101 if unsafe.** |
| IT / UPES-ECS Admin | Manage AI service/health; restart/disable; cannot change SOP without approval. |

---

## 8. Deployment & privacy

```text
Asterisk (ARI/Stasis, AudioSocket/RTP) → AI voice-agent service →
LOCAL STT (faster-whisper/Vosk) + LOCAL LLM (Ollama/llama.cpp) + LOCAL TTS (Piper) →
incident log / summary → transfer back to 111 queue
```

**Locked posture (2026-07): fully local, NO cloud AI.** The entire STT→LLM→TTS pipeline
runs **on-prem** (campus/van) with **zero internet, no API keys**; emergency audio,
transcripts and summaries **never leave the premises**. This satisfies — and exceeds — the
"keep emergency audio local" requirement; no cloud-AI approval is sought because there is
no cloud. The implementation is replaceable — the locked design is the emergency behaviour
**and the local-first constraint**, not any one AI project. It must support: Asterisk
integration, **local** STT/LLM/TTS, transfer to approved extensions/queues, on-prem
deployment, health monitoring, logging, and **safe fallback to 111**.

> ⚠️ **Hardware prerequisite (stated honestly).** Local Whisper + an 8B-class LLM + Piper
> need real CPU/GPU. The current van VM (QEMU/TCG, no hardware acceleration) **cannot** run
> them at usable latency (~15s+/turn). 101 therefore requires a **dedicated GPU box /
> capable host** (GPU ~0.5–2s/turn; CPU-only ~5–15s, marginal) — not the current laptop VM.
> This is a capacity prerequisite, **not** a change to the human-first guarantees: 111 and
> 102 remain fully independent of it.

---

## 9. Health checks (separate from 111)

AI engine running · reachable from Asterisk · 101 + 196 test calls · STT/TTS/LLM up ·
101→111 transfer works · AI fallback to 111 works · response time acceptable · AI logs
being written · summary generation working.

---

## 10. Rollout

```text
Phase 1    Prove 111 human-first (no AI)
Phase 1.5  101 in test mode for ERT/internal; 196 internal test; 199 drill integration
Phase 2    Students/staff call 101; escalates urgent/unclear to 111
Phase 3    Better routing, dashboard summaries, analytics, approved integrations
```
