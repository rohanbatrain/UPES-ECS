# UPES-ECS Rollout Plan

Staged deployment from a lab test to a controlled campus pilot. **Do not onboard the
whole university on day one** — prove each stage, then scale.

---

## Stage 1 — Core lab test

**Goal:** prove SIP calling works on the campus LAN/Wi-Fi.

- Asterisk/FreePBX server + router/switch/AP.
- 2–3 mobile SIP clients + 1 ERT client/device.
- Test: student-to-student calling, 111 calling, recording/logging.

**Exit:** two Wi-Fi phones call each other and 111 reaches an ERT device.

---

## Stage 2 — ERT pilot

**Goal:** prove the emergency core.

- Add ERT users/devices to `ert_emergency_queue`.
- Add escalation + emergency voicemail.
- Test missed-call recovery and responder availability (`*45`/`*46`).

**Exit:** 111 → queue → answer/recorded; unanswered → voicemail → Missed Emergency Incident; pause/resume works.

---

## Stage 3 — Critical device pilot

**Goal:** bring in fixed emergency phones + coordination.

- Add Security `4300`, Medical `4200`, warden/admin phones if available.
- Test warm transfer, three-way bridge, conference rooms.

**Exit:** dispatch modes + 9000 work; unauthorized access blocked and logged.

---

## Stage 4 — Student/staff pilot

**Goal:** validate real user access at small scale.

- Add **10–25** selected student + staff SAP-ID accounts.
- Test student-to-student call quality, misuse controls, support process.

**Exit:** pilot users register over Wi-Fi, call 111 + each other; students denied emergency features; support runbook works.

---

## Stage 5 — Paging / announcement expansion

**Goal:** enable outbound emergency broadcast.

- Add paging zones/devices (700–799).
- Test authorized paging, blocked student paging, audibility per zone.

**Exit:** authorized paging audible; unauthorized paging blocked and logged.

---

## Later expansion (post-pilot)

Wider student rollout · QR provisioning · full directory UI · multilingual prompts ·
IP speakers everywhere · VLAN/QoS · shift-based queue automation · advanced dashboard ·
**AI line 101** · **multi-campus wireless bridge**.

---

## What ships staged vs. now

| Now (Phase 1) | Staged later |
|---|---|
| SIP registration, SAP-ID dialing | QR provisioning |
| 111 queue + escalation + voicemail | Full directory UI |
| Recording + logging | Multilingual prompts |
| Fixed ERT/security/medical devices | IP speakers everywhere |
| Health check (script/CLI) | Advanced dashboard |
| Backup/restore | VLAN/QoS, shift automation |
| Drill mode (199) | AI 101, multi-campus |

---

## Roles for rollout

| Role | Responsibility |
|---|---|
| IT / UPES-ECS Admin | Server, FreePBX, provisioning, backups, health |
| ERT Lead | Queue roster, SOP training, drill sign-off |
| Control Room | Daily readiness, monitoring |
| University administration | Approvals (paging policy, retention, go-live) |

---

## Review cadence

- Directory/device review: **monthly** in pilot, **quarterly** once stable.
- Drills: **monthly** basic, **quarterly** full-scenario.
- Restore test: **monthly** in pilot, **quarterly** after.

---

## Approvals

Go-live requires **UPES administration + ERT Lead + IT owner** sign-off after a
successful pilot. Go-live date is **TBD** — set only after the [Pilot Test Plan](17-Pilot-Test-Plan.md) passes.
