# UPES-ECS Glossary

Plain-language key to the terms, numbers, and acronyms used across UPES-ECS.
For non-technical readers (administration, ERT, wardens) as much as IT.

---

## Core system

| Term | Meaning |
|---|---|
| **UPES-ECS** | UPES Emergency Communication System — the whole LAN-only campus emergency + internal calling system. |
| **Asterisk** | The open-source phone-system engine that actually routes the calls. |
| **FreePBX** | A web admin panel on top of Asterisk — where IT clicks to create accounts, queues, recordings. The chosen build. |
| **PBX** | Private Branch Exchange — an internal phone system. |
| **LAN-only** | Runs entirely on the campus network; no public internet, no cellular, no cloud. |
| **PBX server** | The one local machine (`upes-ecs-pbx-01`) running Asterisk/FreePBX. |

## Calling & network

| Term | Meaning |
|---|---|
| **SIP** | Session Initiation Protocol — the standard phones use to set up calls. |
| **PJSIP** | The modern SIP engine inside Asterisk. |
| **RTP** | Real-time Transport Protocol — carries the actual voice audio. |
| **SRTP / TLS** | Encrypted versions of RTP/SIP (recommended for ERT/fixed devices). |
| **Softphone** | A phone app on a mobile/PC (e.g. Linphone, MicroSIP). |
| **Extension** | A user's internal number. Here, a person's **SAP ID**. |
| **Registration** | A phone "logging in" to the PBX so it can make/receive calls. |
| **VLAN** | A separated virtual network segment (e.g. a voice-only network). |
| **PoE** | Power over Ethernet — powers IP phones/APs through the network cable. |
| **QoS / DSCP** | Network settings that give voice traffic priority. |
| **Client isolation** | A Wi-Fi setting that blocks devices from talking to each other/the PBX — **must be off** (or bypassed) for UPES-ECS. |

## People & roles

| Term | Meaning |
|---|---|
| **ERT** | Emergency Response Team — the trained people who answer 111. |
| **ERT Operator** | Front-line responder who answers 111 calls. |
| **ERT Lead / Incident Commander** | Senior emergency authority; approves paging, closes incidents, runs coordination. |
| **UPES-ERT-ROOM** | The control room where ERT answers. |
| **SAP ID** | The university's unique ID for each person — used as their phone number/username. |
| **Fixed device** | A phone tied to a location, not a person (e.g. `4300` Security Control). |

## Emergency flow

| Term | Meaning |
|---|---|
| **Queue** | A waiting line that rings available ERT members (`ert_emergency_queue`). Press **1** any time to jump to the first-aid fast-path. |
| **Ring-all** | Queue strategy: ring every available responder at once. |
| **Offline Panic-Coach (102)** | Deterministic first-aid — CPR / bleeding / choking / fire / lockdown / recovery / trapped — with **zero internet** (`ctx_ai_helpline`). The automatic fallback when no human answers 111; also dialable on **102** to test. Inside it: `9` retries a responder, `8` leaves a message. |
| **Escalation** | When no answer point is free, the caller goes **straight to the offline coach (102)** — no dead-air — while the ERT Lead + backup are alerted **in the background in parallel** (auto call-files, "press 1 to join the queue"). No longer a serial Lead-20s → backup-20s → voicemail chain. |
| **Emergency Voicemail** | The final catch: reached from inside the coach (press `8` to leave a message) when no human joins; a missed message becomes a Missed Incident. |
| **Missed Emergency Incident** | A critical, must-review record created by an unanswered 111 call. |
| **Warm transfer** | Announce the caller to the next responder before handing over. |
| **Three-way bridge** | Caller + ERT + responder all on one live call. |
| **Blind transfer** | Sending a caller away without confirming pickup — **discouraged**. |
| **Paging** | Live voice broadcast to speakers/phones in a zone (700s). |
| **ConfBridge** | Asterisk's conference-room feature (rooms 9000–9004). |
| **Drill Mode** | Safe testing on **199** — no real dispatch. |

## Logging & data

| Term | Meaning |
|---|---|
| **CDR** | Call Detail Record — one row per call (who/when/how long). |
| **CEL** | Channel Event Logging — detailed per-call events. |
| **AMI / ARI** | Asterisk interfaces that let software read events / control calls (used by dashboards + AI). |
| **MixMonitor** | The Asterisk feature that records a call. |
| **Incident ID** | `ERT-YYYYMMDD-NNNN` — the ID tying a call, recording, and voicemail together. |
| **Access Denied Event** | Log entry when someone tries a feature they're not allowed to use. |
| **Retention** | How long recordings/logs are kept (90 days audio, 1 year logs). |
| **DPDP Act** | India's Digital Personal Data Protection Act 2023 — governs the personal data/recordings. |

## AI (later phase)

| Term | Meaning |
|---|---|
| **STT / TTS** | Speech-to-Text / Text-to-Speech — the AI's ears and voice. |
| **LLM** | Large Language Model — the AI that understands and summarizes the caller. |
| **Pre-brief** | The AI's structured summary handed to ERT when it escalates a 101 call to 111. |

## Key numbers (see [Numbering Plan](numbering-plan.md))

| Number | Meaning |
|---|---|
| **111** | Emergency Hotline (human-first) — **the number to dial**. |
| **102** | Offline Panic-Coach — deterministic first-aid, zero internet; auto fallback when no human answers, also dialable to test. |
| **101** | Local-first AI triage assistant (no cloud, no Gemini; later phase). Never dialed by a caller. |
| **199 / 198 / 196** | Drill line / echo test / AI test. |
| **700–799** | Paging zones. |
| **9000–9099** | Incident conference rooms. |
| **`*22` / `*23`** | Responder go on / off shift (join / leave the emergency queue). |
| **`*45` / `*46`** | ERT queue pause / resume (temporary, within a shift). |
| **4000–4999** | Fixed campus devices. |
