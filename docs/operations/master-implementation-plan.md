# UPES-ECS Master Implementation Plan

**System:** UPES Emergency Communication System (UPES-ECS)
**Build:** FreePBX (web admin over Asterisk), one local server, LAN-only
**Goal:** the smallest working emergency line first, then layer everything else on top.

> The whole system reduces to one MVP: **Dial 111 → ERT phone rings → call is
> recorded → if unanswered it goes to voicemail and becomes a reviewable incident.**
> Everything else layers on without changing that core.

---

## Phase map

| Phase | Name | Outcome | Effort |
|---|---|---|---|
| **0** | Foundations | Two phones can call each other over Wi-Fi | ½–1 day |
| **1** | Emergency core (MVP) | **Dial 111 works end-to-end** — go/no-go milestone | 2–4 days |
| **2** | Roles & access | Student calling + locked-down emergency features | 2–3 days |
| **3** | Coordination | Paging, conference rooms, dispatch, availability | 3–5 days |
| **4** | Operational hardening | Health checks, backup/restore, SOP + first drill | 2–4 days |
| **1.5 / 2** | AI line 101 | AI triage that always falls back to 111 | later |
| **Later** | Multi-campus | Bidholi ↔ Kandoli rooftop wireless bridge | later |

Each phase is independently usable — you can stop after Phase 1 and already have a real emergency line.

---

## Phase 0 — Foundations

**Do:**
1. Install **Ubuntu Server LTS** (or Debian stable) on the existing server; hostname `upes-ecs-pbx-01`.
2. Assign a **static IP** (mandatory) and record subnet/gateway.
3. Install **FreePBX** (official distro or on top of Asterisk).
4. Confirm the LAN path: **Wi-Fi client isolation OFF** (or a voice VLAN) so phones can reach the PBX for SIP + RTP.
5. Set local name resolution `pbx.upes.lan` / `sip.upes.lan` (or document the static IP fallback).
6. Create 2 test PJSIP extensions + enable **echo test 198**.

**Exit criteria:** two phones on campus Wi-Fi register and call each other; 198 echo works.

---

## Phase 1 — Emergency core (MVP) ← the milestone

**Do:**
1. Provision ~10 **SAP-ID** extensions (CSV import) in the correct contexts.
2. Create queue **`ert_emergency_queue`** — ring all available, 20s timeout, min 2 agents.
3. Point **111** → recording starts immediately → queue.
4. Build the **escalation chain**: queue → ERT Lead `4101` (20s) → backup group (`4300`+`4200`+warden/admin, ring-all 20s) → **Emergency Voicemail**.
5. Configure **MixMonitor recording** on the 111 flow; naming `ERT-YYYYMMDD-0001_...wav`.
6. Create **Missed Emergency Incident** handling (Critical, Pending Review).
7. Create **199 drill line** mirroring 111 but with **no real dispatch**, logs `DRILL-ONLY`.

**Exit criteria (all must pass):** dial 111 → ERT answers → recorded; unanswered 111 → voicemail → missed incident appears; 199 works and dispatches nothing real.

---

## Phase 2 — Roles & access

**Do:**
1. Create the 7 contexts (`ctx_student … ctx_admin`) per the [Role Matrix](04-SIP-Account-Role-Matrix.md).
2. Enable student-to-student / internal calling (not recorded).
3. Provision fixed devices in **4000–4999** (Medical 4200, Security 4300, ERT desks 41xx).
4. Lock paging, conference, recordings, voicemail review to emergency roles.
5. Enforce: no anonymous SIP, unique ≥12-char passwords, LAN-only registration.

**Exit criteria:** a student account can call 111 + another student but is **denied** paging/conference/recording; fixed devices show correct caller ID.

---

## Phase 3 — Coordination

**Do:**
1. Paging **700–799** (ConfBridge/Page), **PIN on 700**, all attempts logged.
2. Conference rooms **9000–9004** with PINs; 9000 recorded when active.
3. Dispatch workflow: warm transfer + three-way bridge; blind transfer restricted.
4. Responder availability: `*45`/`*46` pause/resume; queue reflects busy/paused/offline.

**Exit criteria:** authorized paging + 9000 work; unauthorized attempts are blocked and logged; transfers and pause/resume behave per SOP.

---

## Phase 4 — Operational hardening

**Do:**
1. Health checks (script/CLI first, dashboard later) — see [Health Checklist](10-Health-Monitoring-Checklist.md).
2. Backups: git repo `upes-ecs-config`, daily config + pre-change snapshots, encrypted sensitive data — see [Backup & Restore](11-Backup-Restore-Procedure.md).
3. **Tested restore** (config restore under 1 hour target).
4. Train ERT on the SOP; run the **first drill**; capture a post-drill review.

**Exit criteria:** health check reports correctly; a restore test passes; ERT completes a drill successfully.

---

## Later phases

- **AI line 101** ([19-AI-101-Design.md](19-AI-101-Design.md)) — AI-first triage on its own number, **always** escalates/falls back to 111. 111 never depends on AI.
- **Multi-campus** ([20-Multi-Campus-Wireless.md](20-Multi-Campus-Wireless.md)) — rooftop point-to-point wireless links Bidholi ↔ Kandoli while staying "LAN-only."

---

## TBD items to collect from UPES IT (blocking go-live)

| Item | Needed for |
|---|---|
| Router / switch / AP models | Capacity, VLAN/QoS, client-isolation behaviour |
| Server specs + OS confirmation | Capacity, backup planning |
| Static server IP / subnet / gateway | SIP client config |
| Campus Wi-Fi SSID | Setup guides |
| Client-isolation status | SIP/RTP connectivity |
| Allowed subnets | Firewall / access rules |
| Final ERT roster | Queue membership |
| Final fixed-phone locations | Numbering + provisioning |
| Recording-retention policy | Legal/admin compliance |
| Go-live approval authority | Sign-off |

---

## Success criteria (Phase 1 go/no-go)

Mobile SIP registration over Wi-Fi · SAP-ID → SAP-ID calling · any authenticated
user can call 111 · 111 reaches ERT queue · escalation works · voicemail works ·
recording works for 111 · student calls not recorded · restricted features denied ·
health check passes (script level) · backup/restore config test passes · 199 drill
safe · SOP understood in a responder drill. **All must pass before go-live.**

**Rollback triggers:** 111 fails, queue unavailable, recording fails, PBX unstable,
Wi-Fi can't carry calls, unauthorized-access risk, or no available ERT coverage.
