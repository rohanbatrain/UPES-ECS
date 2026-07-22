# UPES-ECS — Feature Roadmap (Next Horizon)

**Scope:** Features **beyond** what is already built or being built now, for the UPES Emergency Communication System — a **LAN-only** Asterisk PBX deployed on a van laptop (QEMU Ubuntu VM), with a web **Operations Console**.

**Last updated:** 2026-07-05

This document is deliberately forward-looking. It does **not** re-list the current backlog (which lives in [Project-Status.md](./Project-Status.md)) — it catalogs the *next* wave of capability once the core is in production.

---

## What already exists (do not re-plan)

- **Proven / built:** `111` emergency hotline + ERT queue + escalation + voicemail + recording + incident logging; `199` drill; `198` echo; student-to-student SAP-ID calling; `700x` paging (with access control); `9000x` conference; responder pause/resume `*45`/`*46`; backup/restore; fail2ban; real TTS prompts; the Operations Console; a running QEMU PBX.
- **Being built now (out of scope for this doc):** mass callout, roll-call / headcount, silent SOS / duress, pre-recorded announcements, on-call / follow-me routing, department hunt groups, dial-by-name directory, intercom, callback, and the **Console v2** webapp.

- **Delivered 2026-07-05 (Console live-ops round):**
  - **Incident Timeline** — live, newest-first stream of every handled call, built from the CDR log; emergencies / SOS / drills / bridges / paging colour-coded with filter chips. *(Console section `timeline`, fed by `status.json.cdr[]`.)*
  - **Presence & Shifts** — registration + queue state of every defined endpoint (`pjsip show endpoints`), split into responder positions (on-shift / in-queue / reachable) and registered clients. *(Console section `presence`, fed by `status.json.presence[]`.)* Supersedes the "Presence / BLF for responders" line below for the Console view (deskphone BLF still future).
  - **Call Records + recording playback** — recent call-detail log (roster-named) plus in-browser playback of whole-call recordings synced by `Pull-Recordings.ps1`. *(Console section `records`, fed by `status.json.cdr[]` + `recordings[]`.)*
  - **Insights / CDR analytics** — emergency KPIs (answer-rate + answer-time on 111), **drill pass-rate** (199 answered/total over time), calls-by-type, activity-by-hour histogram, per-day volume, and top callers. Aggregated over the **full** `Master.csv` on the VM (python) → `status.json.analytics{}` → pure-CSS charts. *(Console section `insights`, new **Insights** nav group.)* Delivers the "CDR analytics dashboard" **and** "Drill pass-rate reporting" lines below.
  - **111 made answerable + offline panic-coach (`102`)** — the ERT queue is now staffed by the on-shift registered handset (`ert-shift.sh`), so 111 rings a real phone (wallboard READY). And when *nobody* answers (queue timeout + escalation unanswered), the call now routes to a **fully-offline, deterministic panic-coach** (`ctx_ai_helpline`): a calm scripted decision-tree that coaches the caller through CPR, bleeding, choking, fire, lockdown, recovery position, and being trapped — with "9 = retry a responder" and "8 = leave a message". All audio is offline TTS (pico2wave+sox); no internet. Direct test dial `102`. This is the **zero-internet floor beneath the future AI triage (`101`, a local-first stack — Ollama/llama.cpp + Whisper (STT) + Piper (TTS), **no Gemini/cloud** — see [../AI-101/](../AI-101/README.md))**, and it satisfies SOP 19's rule that the fallback must work with every AI component offline.
  - **Disaster-ready 111 flow (press-1 fast-path + parallel coaching)** — grounded in Emergency Medical Dispatch practice (stay-on-line pre-arrival instructions, no redial loops). The old serial ring-out (queue → Lead 20s → backup 20s → *then* voicemail, ~45–60s of silence before any guidance) is replaced: the caller can **press 1 any time during the queue** to jump to first-aid (`ctx_111_fastpath`), and when no human answers the system does two things **at once** — rings the Lead + backup in the **background** (non-blocking call-files, `alert_responders.sh`, with "press 1 to join the queue") **and** starts the offline coach immediately + logs the incident. New prompts (real press-1 preanswer, periodic "press 1 for first-aid", responder alert). Full flow documented in [../Blueprint/03-Call-Flows.md](../Blueprint/03-Call-Flows.md) §2, [SOP 19](../SOP/19-AI-101-Design.md) (de-vagued: 101/102 are internal routes, never a number a caller dials), and a new **Emergency Call Flow** Console section.

Everything below is the **next horizon** — sequenced, realistic, and mapped to real Asterisk capabilities.

---

## How to read this

Every feature carries:

- **What it does** — the capability in plain terms.
- **Why for a campus emergency system** — the operational justification.
- **Asterisk / tech fit** — the concrete mechanism (module, subsystem, or external component).
- **Effort** — **Quick** (hours–days, config/scripting) · **Medium** (a week or two, new component or schema) · **Project** (multi-week, new hardware / subsystem / integration).
- **LAN-only?** — **yes** (stays inside the closed campus LAN) · **needs external** (requires a controlled gateway, breaking the pure LAN-only posture — flagged explicitly).

> **LAN-only is a design invariant.** Anything marked *needs external* must terminate on a **single, hardened, one-way-where-possible gateway**, never on the PBX itself. See [Integrations](#7-integrations-breaks-lan-only--needs-a-controlled-gateway).

---

## 1. Reporting & Analytics

Turns call data already flowing through Asterisk into evidence, trends, and after-action review.

| Feature | What it does | Why for a campus emergency system | Asterisk / tech fit | Effort | LAN-only? |
|---|---|---|---|---|---|
| **CDR analytics dashboard** | Call-volume, per-extension, per-hour/day rollups; busy-hour and trend charts | Shows load on `111`, when incidents cluster, whether ERT is over/under-provisioned | `cdr_csv` (already writing) or `cdr_adaptive_odbc` → SQLite/Postgres; charts in Console v2 | Medium | yes |
| **Answer-time / SLA metrics** | Time-to-answer, ring duration, abandon rate on the `111` queue | The single most important emergency KPI: *how fast does a real call get a human?* | Queue events via **CEL** (Channel Event Logging) + AMI `QueueSummary`/`AgentComplete`; compute p50/p90 | Medium | yes |
| **Missed-emergency trend board** | Aggregates the existing `missed_incident.sh` flags into a trended view | Repeated misses are a safety failure that must be visible, not buried in a log file | Read the incident logs / dashboard flags already produced by [`../config/`](../config/) scripts; render trend | Quick | yes |
| **Drill pass-rate reporting** | Scores `199` drills over time: answered / escalated / missed, per shift | Proves readiness to leadership; turns drills into a measurable program | Tag drill CDRs (distinct context/accountcode) + join to incident IDs | Quick | yes |
| **Recordings & incident review portal (restricted)** | Web portal to search, play, and annotate `111` recordings tied to their incident ID | After-action review, training, and dispute resolution — with access tightly controlled | Serve `MixMonitor` files behind RBAC; index by `ERT-YYYYMMDD-NNNN` from `incident_id.sh`; enforce [SOP 13 retention](../SOP/13-Recording-Retention-Policy.md) | Medium | yes |
| **Immutable audit log** | Append-only record of *who listened to / exported / deleted* recordings and who changed config | Recordings are sensitive; access itself must be auditable. Config changes need a paper trail | Structured audit table + hash-chain / append-only file; surface in Console; ties to [SOP 26](../SOP/26-Security-Hardening.md) | Medium | yes |
| **Scheduled digest export** | Nightly/weekly PDF/CSV summary (volume, misses, drills) written to disk | Gives IT/ERT leads a standing report without opening the Console | Cron job over the CDR/CEL store; render locally (no cloud) | Quick | yes |

---

## 2. Resilience & Continuity

Keeps the emergency line answering through power, hardware, and network failure.

| Feature | What it does | Why for a campus emergency system | Asterisk / tech fit | Effort | LAN-only? |
|---|---|---|---|---|---|
| **Standby / failover PBX (van as failover)** | A second Asterisk that takes over if the primary dies — e.g. the van PBX backs up the fixed campus PBX (or vice-versa) | An emergency line that goes down *is* the emergency. Redundancy is non-negotiable at go-live | Two PBXes; failover via **keepalived/VRRP** floating IP, or phones with a **backup registrar** (`aor` outbound/secondary proxy); heartbeat health-check | Project | yes |
| **Config auto-sync (campus ↔ van)** | Keeps dialplan, PJSIP endpoints, prompts, and roster identical on both nodes | A failover node is only useful if its config isn't stale. Manual copy = drift = surprise on the worst day | `rsync`/`git` push of `/etc/asterisk` + `unixtime`d reload; validate with `asterisk -rx 'dialplan reload'` dry-run; extends existing backup/restore | Medium | yes |
| **Scheduled restore drills** | Automated, logged test that a backup actually restores and the PBX answers `198`/`199` after | Backups that were never restored are hope, not a plan. Proves recoverability on a schedule | Cron-driven restore into a scratch VM + automated `199` self-test; record pass/fail to the audit log; extends [SOP 11](../SOP/11-Backup-Restore-Procedure.md) | Medium | yes |
| **UPS / power monitoring** | Reads UPS state; alarms on mains loss and low battery; can trigger graceful shutdown | Risk **R1** — no power, no PBX. The van especially needs a monitored battery runway | **NUT** (Network UPS Tools) on the host → alert into Console; optional dialplan alarm page via `700x`; ties to [SOP 21 R1](../SOP/21-Risk-Register-and-Gaps.md) | Medium | yes |
| **Watchdog & auto-recovery** | Detects a hung Asterisk / stuck registration and restarts the service | Unattended van deployment can't rely on a human noticing a crash at 2am | `systemd` restart policy + a liveness probe (SIP OPTIONS ping / AMI heartbeat) extending [SOP 10](../SOP/10-Health-Monitoring-Checklist.md) | Quick | yes |
| **Cold-standby "PBX-in-a-box" image** | A pre-baked, one-command bootable image so a dead node is replaced in minutes | Fast physical recovery when hardware (not just software) fails | Golden QEMU image + `Deploy-UpesEcsVm.ps1` (already exists) as the rebuild path | Quick | yes |

---

## 3. Reach & Hardware — Audible Campus Alerting

Extends the system from phones-only to **the whole campus can hear it**.

| Feature | What it does | Why for a campus emergency system | Asterisk / tech fit | Effort | LAN-only? |
|---|---|---|---|---|---|
| **IP speaker / PA integration** | Pushes live or pre-recorded audio to IP speakers / a PA head-end across campus | People not holding a phone still need to be warned (evacuate, shelter, all-clear) | SIP-endpoint speakers (Algo/CyberData-class) called as PJSIP endpoints, **or** RTP **multicast paging** (`chan_multicast` / one-way RTP) to a speaker group; hooks the "pre-recorded announcements" work being built now | Project | yes |
| **Zone-based paging** | Address specific buildings/zones (block A, hostels, labs) instead of all-or-nothing | Localizes response; avoids panicking the whole campus for a contained incident | Per-zone paging groups (extension ranges / multicast groups) layered on the `700x` paging plan ([SOP 01](../SOP/01-Numbering-Plan.md)) | Medium | yes |
| **Multilingual announcements at scale (Hindi / English)** | Plays the correct-language prompt per zone, or bilingual back-to-back | UPES is bilingual; an alert nobody understands is not an alert | Pre-recorded prompt sets per language (extends [SOP 28](../SOP/28-Voice-Prompt-Scripts.md)) selected by zone variable in the dialplan | Quick | yes |
| **Multi-campus wireless bridge (Bidholi ↔ Kandoli)** | Extends the LAN across campuses over the rooftop point-to-point link | One PBX can serve both campuses; ERT and paging reach Kandoli — already designed | Layer-2/3 PtP bridge carrying SIP/RTP; failover-aware; **already designed** in [SOP 20](../SOP/20-Multi-Campus-Wireless.md) (cross-link SOP) | Project | yes |
| **Strobe / visual alert outputs** | Drives strobes/beacons alongside audio for high-noise or hearing-impaired areas | Labs, workshops, and hostels at night need a visual channel too | GPIO/relay via a networked I/O module triggered on page, or beacon-equipped IP speakers | Medium | yes |

---

## 4. Provisioning & Scale

Moves onboarding from hand-config (today's error source) to automation that scales to a campus.

| Feature | What it does | Why for a campus emergency system | Asterisk / tech fit | Effort | LAN-only? |
|---|---|---|---|---|---|
| **Bulk SAP-ID onboarding automation** | Ingests a roster CSV and generates PJSIP endpoints, secrets, and voicemail boxes en masse | Thousands of students can't be added by hand; hand-config is the current top failure mode | Template + generator over `pjsip.conf`/`realtime`; extends [`../provisioning/pilot-users.csv`](../provisioning/) flow; secrets set at import (never in repo) | Medium | yes |
| **PJSIP Realtime (DB-backed accounts)** | Store endpoints/AORs/auth in a database instead of flat files | Live add/remove without reloads; the scalable substrate for everything else in this section | `res_pjsip` + `res_config_odbc` (PJSIP Realtime) → Postgres/MySQL on the PBX | Project | yes |
| **QR self-provisioning kiosk** | Student scans a QR at a kiosk → phone auto-configures the correct, encrypted profile | One scan replaces the transport/`+91`/encryption mistakes phones hit today | Extends the QR/profile work in [`../provisioning/linphone/`](../provisioning/); kiosk validates SAP-ID before issuing config | Medium | yes |
| **MDM-managed ERT Androids** | Central management of the always-on ERT answer-point phones (app, config, lockdown, remote wipe) | ERT phones must never sleep, must stay on the right app/config, and survive loss/theft | MDM (e.g. Headwind/open-source) pushing the SIP client + [SOP 24](../SOP/24-Mobile-App-Reliability-and-Battery.md) battery/background hardening | Project | needs external* |
| **Admin console for account lifecycle** | Create / suspend / role-change / offboard accounts with approvals, from the Console | Turnover (students graduate, staff leave) needs a governed lifecycle, not ad-hoc edits | Console v2 UI over PJSIP Realtime + AMI reloads; every change to the audit log; ties to [SOP 04 role matrix](../SOP/04-SIP-Account-Role-Matrix.md) | Medium | yes |

> \* **MDM** typically wants an internet/cloud tenant. A **self-hosted, LAN-only MDM** keeps the invariant; a cloud MDM would need the controlled-gateway treatment.

---

## 5. Access & Security

Hardens signalling, media, roles, and secrets for a production emergency service.

| Feature | What it does | Why for a campus emergency system | Asterisk / tech fit | Effort | LAN-only? |
|---|---|---|---|---|---|
| **TLS + SRTP (encrypted signalling & media)** | Encrypts SIP and RTP so calls can't be sniffed or spoofed on the LAN | Emergency and duress calls are exactly the traffic you must not leak or tamper with (Risk **H2/D3**) | `res_pjsip` TLS transport + `media_encryption=sdes` (or DTLS-SRTP); cert management; per-client profile decision — [SOP 26](../SOP/26-Security-Hardening.md) | Project | yes |
| **Per-role RBAC hardening** | Enforces least-privilege on Console, portal, and dialplan features by role | Not everyone should page campus, hear recordings, or change config. Blast-radius control | Console RBAC + Asterisk contexts per role (already role-scoped in dialplan); align to [SOP 04](../SOP/04-SIP-Account-Role-Matrix.md) / [SOP 27 RACI](../SOP/27-Roles-Ownership-RACI.md) | Medium | yes |
| **SIP flood / DoS protection** | Rate-limits registration/INVITE storms and auto-bans abusers beyond today's fail2ban | A flooded PBX can't answer `111`. Availability is a security property here | Tighten **fail2ban** (already present) + `res_pjsip` `qualify`/ACL + kernel `nftables` rate limits; AMI alarm on spikes | Medium | yes |
| **Secrets manager** | Centralizes SIP passwords, cert keys, AMI/ARI creds out of flat files | Secrets sprawl is a breach waiting to happen; rotation must be possible | Local vault (e.g. `pass`/age/self-hosted Vault) feeding config at deploy; keeps repo placeholder-only (as today) | Medium | yes |
| **Signed / verified config deploys** | Config only loads if it passes validation and a signature/integrity check | Prevents a bad or malicious dialplan from silently breaking `111` | Pre-reload `dialplan reload` dry-run + checksum gate in the deploy pipeline; audit every apply | Quick | yes |

---

## 6. Operations & Responder Management

Day-to-day tooling so shifts, presence, and situational awareness run themselves.

| Feature | What it does | Why for a campus emergency system | Asterisk / tech fit | Effort | LAN-only? |
|---|---|---|---|---|---|
| **Shift roster automation + auto-unpause** | Loads the ERT roster; auto-pauses off-shift responders and unpauses the on-shift ones at handover | Removes reliance on responders remembering `*45`/`*46`; guarantees the queue always has live agents | Scheduled AMI `QueuePause`/`QueueUnpause` driven by the roster; complements manual `*45`/`*46`; ties to [SOP 30](../SOP/30-ERT-Roles-and-Shifts.md) | Medium | yes |
| **On-call calendar** | Defines who is on-call by date/time and feeds routing + escalation | Escalation must reach a *real* on-call person, not a fixed extension that may be off-duty | Calendar → dialplan variables / follow-me targets (dovetails with the on-call routing being built now) | Medium | yes |
| **Real-time control-room wallboard (TV)** | Full-screen live board on a control-room TV: active `111` calls, queue depth, longest wait, agent status, alarms | Shared situational awareness during an incident; the operator shouldn't hunt for numbers | Console v2 read-only wallboard view over AMI/CEL; auto-refresh; kiosk browser on the TV | Medium | yes |
| **Presence / BLF for responders** | Shows each responder's live state (available / on-call / paused / offline) with busy-lamp fields | Dispatch needs to see at a glance who can actually take the next call | `res_pjsip` presence + dialplan `hint`s → SUBSCRIBE/NOTIFY (BLF) on deskphones and in the Console | Medium | yes |
| **Escalation-path visualizer & tester** | Shows and test-fires the `111` escalation chain without a real emergency | Confidence that escalation *will* work before you need it; training aid | Drive the existing escalation dialplan under a test context; log the path to the audit trail | Quick | yes |

---

## 7. Integrations (BREAKS LAN-only — needs a controlled gateway)

> **Read first.** Every item here crosses the campus LAN boundary. Each must terminate on a **single, hardened, monitored gateway** — never on the emergency PBX directly — with **`111` staying fully functional even if the gateway is down**. These are opt-in extensions, not core.

| Feature | What it does | Why for a campus emergency system | Asterisk / tech fit | Effort | LAN-only? |
|---|---|---|---|---|---|
| **SMS / WhatsApp / email mass alerts** | Blasts an alert to students/staff over SMS, WhatsApp, and email in parallel with voice | Reaches people who don't answer a call or aren't on a phone; multi-channel redundancy | External notification gateway (SMS aggregator / WhatsApp Business API / SMTP relay) triggered by the PBX via AGI/ARI webhook | Project | **needs external** |
| **PSTN dial-out to real 100 / 108** | Bridges an on-campus incident to real police (`100`) / ambulance (`108`) | Some emergencies must escalate to public services — the system should hand off cleanly | SIP trunk to an ITSP or a **DAHDI/analog FXO** gateway; strict allow-list; caller-ID/CLI policy — **note [SOP 21 D1](../SOP/21-Risk-Register-and-Gaps.md) `100`-collision risk** | Project | **needs external** |
| **CCTV / access-control pop-on-call** | On a `111` call, pops the nearest camera feed and unlocks/locks relevant doors for responders | Cuts response time; gives the operator eyes on the scene instantly | ARI/AGI event → VMS API (ONVIF) + access-control API on the gateway LAN segment | Project | **needs external** |
| **SIS / HR directory sync** | Auto-populates the dial-by-name directory and roster from campus SIS/HR | Keeps the directory correct as people join/leave — no manual maintenance | Scheduled one-way pull from SIS/HR API → PJSIP Realtime; feeds the dial-by-name work being built now | Project | **needs external** |
| **Native UPES VoIP app (GPS / coordinate broadcast)** | A branded app that registers over SIP, **broadcasts caller GPS/coordinates** on an emergency, and rings even backgrounded via push | Directly answers Risk **R5 (location blindness)**; push fixes the "phone asleep, call missed" failure | Custom SIP client (PJSIP mobile SDK) + **push** (FCM/APNs) waking it on INVITE; coordinates ride in headers/AGI into the incident record | Project | **needs external** |
| **App-push wake-on-INVITE** | Wakes a backgrounded/sleeping phone so an incoming emergency call actually rings | Battery-optimized Androids silently drop SIP; without push, calls to sleeping phones are lost ([SOP 24](../SOP/24-Mobile-App-Reliability-and-Battery.md)) | `res_pjsip` push params (`PJSIP-endpoint` push) + a push gateway (FCM/APNs) — the wake path is inherently cloud | Project | **needs external** |

---

## 8. Accessibility & Inclusion

Ensures people who can't make a normal voice call still reach help.

| Feature | What it does | Why for a campus emergency system | Asterisk / tech fit | Effort | LAN-only? |
|---|---|---|---|---|---|
| **Text / SMS-to-emergency** | Lets someone report silently by text when they can't or shouldn't speak | Duress, hearing/speech disability, or a situation where talking is dangerous | LAN messaging (SIP MESSAGE / in-app chat) into the ERT workflow; SMS variant needs the gateway (§7) | Medium | yes (SMS: needs external) |
| **TTY / RTT support** | Carries real-time text / teletype so deaf/HoH users converse in an emergency | Accessibility obligation; some users have no voice option at all | Asterisk RTT (`T.140`) over the SIP session where clients support it; document supported endpoints | Project | yes |
| **Louder / vibrate answer-point handling** | High-volume ring + strong vibrate + visual flash on ERT answer points | ERT phones in noisy/pocketed conditions must never be missed | Client-side profile on the always-on ERT Androids (via MDM, §4) + [SOP 24](../SOP/24-Mobile-App-Reliability-and-Battery.md) hardening | Quick | yes |
| **Accessible Console (WCAG)** | Screen-reader-friendly, high-contrast, keyboard-navigable Operations Console | Operators and admins may themselves have accessibility needs | Console v2 front-end work: semantic HTML, ARIA, contrast, focus order | Medium | yes |

---

## Recommended next 5

A pragmatic shortlist for the first push *after* the current backlog and the being-built features land. Chosen for **safety impact per unit of effort**, and for staying LAN-only.

1. **CDR + answer-time analytics dashboard** *(§1, Medium, LAN-only)* — You already generate the data; you're flying blind without the view. Answer-time on `111` is *the* emergency KPI, and drill/missed-incident trends turn readiness into something you can show leadership. Highest insight-to-effort ratio.
2. **Shift roster automation + auto-unpause** *(§6, Medium, LAN-only)* — The queue is only as good as the agents logged into it. Automating pause/unpause at handover removes a human single-point-of-failure (someone forgetting `*45`/`*46`) that can silently gut `111`.
3. **UPS / power monitoring** *(§2, Medium, LAN-only)* — Directly retires Risk **R1**. On a van, an unmonitored battery is a countdown to a dead emergency line. Monitoring + graceful shutdown is modest effort for outsized reliability.
4. **IP speaker / zone paging (start small)** *(§3, Project but stageable, LAN-only)* — The biggest reach gap: today only phone-holders get alerted. Even one pilot zone of IP speakers proves audible campus-wide warning and evacuation — the capability people intuitively expect from an emergency system.
5. **TLS + SRTP** *(§5, Project, LAN-only)* — Before any wider go-live, emergency and duress traffic must be encrypted. It closes Risk **H2/D3** and is a prerequisite for trusting the system with real incidents. Bigger lift, but non-negotiable pre-scale.

> **Deliberately deferred from the top 5:** anything in §7 (SMS/WhatsApp, PSTN `100`/`108`, native app, push) — high value but each **breaks LAN-only** and needs the controlled-gateway decision first. Tackle them as a governed second phase, not opportunistically.

---

## Note on AI-101

**AI-101 (local-first — Ollama/llama.cpp + Whisper + Piper, no cloud/Gemini)** — an AI triage front end on extension `101` — is fully designed in [`../AI-101/`](../AI-101/) and [SOP 19](../SOP/19-AI-101-Design.md), but is **deferred by decision**. `111` stays human-first and must keep working even if every AI component is offline. It is intentionally *not* on this roadmap's active track.

---

## Cross-links

- SOPs: [`../SOP/`](../SOP/) — esp. [SOP 01 Numbering](../SOP/01-Numbering-Plan.md) · [SOP 04 Role Matrix](../SOP/04-SIP-Account-Role-Matrix.md) · [SOP 11 Backup/Restore](../SOP/11-Backup-Restore-Procedure.md) · [SOP 13 Retention](../SOP/13-Recording-Retention-Policy.md) · [SOP 20 Multi-Campus Wireless](../SOP/20-Multi-Campus-Wireless.md) · [SOP 21 Risk Register](../SOP/21-Risk-Register-and-Gaps.md) · [SOP 24 Mobile Reliability](../SOP/24-Mobile-App-Reliability-and-Battery.md) · [SOP 26 Security Hardening](../SOP/26-Security-Hardening.md) · [SOP 28 Voice Prompts](../SOP/28-Voice-Prompt-Scripts.md) · [SOP 30 ERT Shifts](../SOP/30-ERT-Roles-and-Shifts.md)
- Blueprint: [`../Blueprint/`](../Blueprint/) — esp. [04 Network & Deployment](../Blueprint/04-Network-and-Deployment.md)
- AI-101 (deferred): [`../AI-101/`](../AI-101/)
- Status of record: [`../Journal/Project-Status.md`](../Journal/Project-Status.md)
- Feature catalog / config: [`../config/FEATURES.md`](../config/FEATURES.md) *(intended catalog — see [`../config/`](../config/) for current config + scripts)*
