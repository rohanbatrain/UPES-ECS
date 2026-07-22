# UPES-ECS — Operational Document Set

**System:** UPES Emergency Communication System (UPES-ECS)
**Type:** LAN-only campus emergency + internal SIP calling on Asterisk (FreePBX)
**Primary user device:** Mobile phone on campus Wi-Fi + SIP app
**Identity model:** SAP ID = SIP extension = SIP username
**Build:** FreePBX (web admin) on top of Asterisk, one local server `upes-ecs-pbx-01`

> Students only ever need to remember one thing: **Dial 111.**

---

## What is in this folder

**Plan & build**

| # | Document | Audience | Purpose |
|---|---|---|---|
| 29 | [Day-1 Quickstart](29-Quickstart-Day1.md) | IT / builders | Shortest path: bare server → working "Dial 111". |
| 07 | [Master Implementation Plan](07-Master-Implementation-Plan.md) | Everyone | The phased roadmap (Phase 0 → later). Start here. |
| 08 | [FreePBX Build Guide](08-FreePBX-Build-Guide.md) | IT / Admin | Hands-on Phase 0 + Phase 1 server steps. |
| 09 | [Dialplan Design](09-Dialplan-Design.md) | IT / Admin | Reference dialplan for the custom emergency logic. |
| 15 | [Local Infrastructure Diagram](15-Local-Infrastructure-Diagram.md) | IT | Network layout, server, segmentation, quality targets. |

**Operate**

| # | Document | Audience | Purpose |
|---|---|---|---|
| 01 | [Numbering Plan](01-Numbering-Plan.md) | IT / ERT / Admin | The master number map. Everything references this. |
| 02 | [ERT SOP](02-ERT-SOP.md) | ERT Operators & Lead | How to answer 111, classify, dispatch, log, close. |
| 03 | [Drill & Test SOP](03-Drill-Test-SOP.md) | ERT Lead / IT | How to test the system safely without causing panic. |
| 04 | [SIP Account & Role Matrix](04-SIP-Account-Role-Matrix.md) | IT / Admin | Who can do what. The access-control source of truth. |
| 30 | [Responder Roles & Shifts](30-ERT-Roles-and-Shifts.md) | ERT Lead / IT | Generic positions (ERT + Medical/Security/…) staffed by shift, not named people. |
| 31 | [Training Plan](31-Training-Plan.md) | All roles | Train every role before go-live; refreshers + reserves for surge. |
| 10 | [Health Monitoring Checklist](10-Health-Monitoring-Checklist.md) | IT / ERT Lead | Is the system actually ready right now? |
| 12 | [Incident Logging Schema](12-Incident-Logging-Schema.md) | IT / ERT | Structured record for every emergency call. |
| 13 | [Recording & Retention Policy](13-Recording-Retention-Policy.md) | Admin / IT | What's recorded, for how long, who can access. |
| 14 | [Device Provisioning Sheet](14-Device-Provisioning-Sheet.md) | IT / Admin | Create / assign / revoke SIP accounts + devices. |

**Users**

| # | Document | Audience | Purpose |
|---|---|---|---|
| 05 | [Student SIP Setup Guide](05-Student-SIP-Setup-Guide.md) | Students / Staff | Install app, log in with SAP ID, dial 111. |
| 06 | [ERT SIP Setup Guide](06-ERT-SIP-Setup-Guide.md) | ERT / Fixed devices | ERT phone + desk device setup and answering. |

**Roll out & prove**

| # | Document | Audience | Purpose |
|---|---|---|---|
| 16 | [Rollout Plan](16-Rollout-Plan.md) | All | Staged deployment (lab → ERT → devices → users → paging). |
| 17 | [Pilot Test Plan](17-Pilot-Test-Plan.md) | IT / ERT Lead | The 19-test matrix that must pass. |
| 32 | [Test Evidence & Sign-off Sheet](32-Test-Evidence-Sheet.md) | IT / ERT Lead / University | Fill-in record proving each pilot test passed; go-live evidence. |
| 11 | [Backup & Restore Procedure](11-Backup-Restore-Procedure.md) | IT / Admin | Local-first backups + tested restore. |
| 18 | [Go-Live Checklist](18-Go-Live-Checklist.md) | Approvers | Final gate + sign-off before production. |

**Later phases**

| # | Document | Audience | Purpose |
|---|---|---|---|
| 19 | [AI Assistant Line 101](19-AI-101-Design.md) | IT / ERT Lead | Local-first AI triage (no cloud) that always falls back to 111. |
| 20 | [Multi-Campus Wireless](20-Multi-Campus-Wireless.md) | IT | Bidholi ↔ Kandoli rooftop wireless bridge. |
| 23 | [Mobile Van & Repeater Deployment](23-Mobile-Van-Deployment.md) | IT / ERT Lead | Self-powered PBX-in-a-van + corner repeaters for disaster mode. |
| 24 | [Mobile App Reliability & Battery](24-Mobile-App-Reliability-and-Battery.md) | Users / IT | Keep the SIP app registered so callbacks work. |

**Harden & own**

| # | Document | Audience | Purpose |
|---|---|---|---|
| 26 | [Security Hardening & Abuse](26-Security-Hardening.md) | IT | SIP hardening, firewall, prank/DoS handling. |
| 27 | [Ownership & RACI](27-Roles-Ownership-RACI.md) | IT / ERT Lead / University | Who owns what; no single point of failure. |

**Review & reference**

| # | Document | Audience | Purpose |
|---|---|---|---|
| 21 | [Risk Register & Known Gaps](21-Risk-Register-and-Gaps.md) | IT / ERT Lead / University | Honest list of what can fail + fixes. **Read before go-live.** |
| 22 | [Glossary](22-Glossary.md) | Everyone | Plain-language key to terms, acronyms, and numbers. |
| 25 | [Quick-Reference Cards](25-Quick-Cards.md) | ERT / Van / Students | Print-and-post one-pagers + "Dial 111" poster. |
| 28 | [Voice Prompt Scripts](28-Voice-Prompt-Scripts.md) | Whoever records audio | Exact wording for every recorded prompt. |

**Config, scripts & provisioning** (outside this folder)

| Path | Purpose |
|---|---|
| [../config/](../config/) | `extensions_custom.conf` + install/wiring README |
| [../scripts/](../scripts/) | Helper scripts: incident ID, missed-incident, health check, retention, logging |
| [../provisioning/](../provisioning/) | CSVs: `pilot-users` (people), `responder-positions` (shift roles), `fixed-devices` |

---

## Golden rules (apply to every document)

1. **111 is human-first and must never depend on AI, internet, or cellular.** When no human answers, the offline panic-coach (102) picks up automatically.
2. **If anyone is ever unsure → escalate. Never drop an emergency call silently.**
3. **Only 111 / 199 (drill) flows are recorded. Student-to-student calls are never recorded.**
4. **Emergency control features (paging, conference, recordings) are role-restricted.**
5. **Every change to the live server takes a backup first.**

---

## Numbering at a glance

```text
111    Emergency Hotline (human-first ERT) — the number to dial
100    DEPRECATED / removed (old Police-association alias; no longer dialable)
102    Offline panic-coach — deterministic first-aid, zero internet; auto fallback when no human answers (also dial to test)
101    Local-first AI triage assistant (later phase; never dialed by a caller)
199    Drill / Test line (safe, no real dispatch)
198    Echo / audio test (optional)
196    Internal AI test line (later)

700-799   Emergency paging zones
9000-9099 Incident command conference rooms
4000-4999 Fixed campus devices (desk phones, IP speakers)
*22 / *23 Responder go on / off shift (join / leave emergency queue)
*45 / *46 ERT queue Pause / Resume

<SAP ID>  Every human user's extension
```

---

## Status of decisions

All naming, numbers, timeouts, and role rules in these documents come from the
**UPES-ECS Filled Decision Questionnaire**. Items marked **TBD** must be collected
from UPES IT before go-live (server IP, Wi-Fi SSID, client-isolation status, final
ERT roster, final fixed-phone locations, university recording-retention policy).
