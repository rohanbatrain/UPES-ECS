# UPES-ECS Pilot Test Plan

The concrete test matrix that must pass before go-live. Every row is a **Must pass**.
Run these during the pilot ([Rollout Plan](16-Rollout-Plan.md) stages 1–5).

---

## 1. Pilot parameters

| Parameter | Target |
|---|---|
| Pilot users | 10–25 |
| ERT pilot members | Min 2, recommended 3+ |
| Simultaneous normal calls | 10 (scale after LAN capacity test) |
| Simultaneous emergency calls | 2–5 |
| Mandatory fixed devices | ERT room phone, Security `4300`, Medical `4200` (if teams in pilot) |
| Pilot area | ERT room + one academic area + one hostel/security/medical path (TBD) |

---

## 2. Functional test matrix

| # | Test | Pass criteria |
|---|---|---|
| 1 | Mobile SIP registration over Wi-Fi | Registers + stays registered |
| 2 | SAP-ID → SAP-ID calling | Connects, clear two-way audio |
| 3 | Any authenticated user calls 111 | Reaches ERT queue |
| 4 | 111 reaches ERT queue | ERT device rings |
| 5 | ERT answers | Caller ID shows `EMERGENCY 111 - Name - SAP ID` |
| 6 | Escalation | Unanswered → Lead 4101 → backup group |
| 7 | Emergency voicemail | Records; creates Missed Emergency Incident (Critical, Pending) |
| 8 | Recording for 111 | File created, correct naming, linked to incident |
| 9 | Student calls not recorded | No recording produced |
| 10 | Warm transfer | Caller handed off after target confirms |
| 11 | Three-way bridge | Caller + ERT + responder all connected |
| 12 | Paging restricted | Authorized works; **student blocked + logged** |
| 13 | Conference 9000 restricted | Authorized joins; **unauthorized blocked + logged** |
| 14 | Pause/resume `*45`/`*46` | Paused agent skipped by queue |
| 15 | Missed-call review | Appears in review queue; callback works |
| 16 | 199 drill | Simulates 111, **no real dispatch**, `DRILL-ONLY` |
| 17 | Health check | Script/CLI reports status correctly |
| 18 | Backup/restore | Config restore test passes |
| 19 | SOP understood | ERT completes a call-handling drill |

**All 19 must pass.** A failed 111/199 test or recording failure is a **critical, do-not-go-live** condition.

---

## 3. Capacity / quality tests

| Test | Target |
|---|---|
| Simultaneous SIP registrations | Pilot count stable |
| Simultaneous student calls | 10 without degradation |
| Simultaneous emergency calls | 2–5 answered |
| Normal load vs 111 priority | **111 unaffected** by normal traffic |
| AP behaviour under voice load | No excessive drops |
| Latency / jitter / loss | < 150 ms · low · < 1% |
| Call setup time | < 3 s internal |
| PBX CPU/RAM | Within headroom |
| Recording storage growth | Tracked; disk < 75% |

---

## 4. Mobile-specific checks

- [ ] Registers over Wi-Fi and reconnects after Wi-Fi drop.
- [ ] Call to 111 + another SAP-ID works with two-way audio.
- [ ] Behaviour on **screen lock** documented (background/battery settings).
- [ ] Mic permission behaviour verified.
- [ ] Caller ID renders `Name - SAP ID`.

---

## 5. Security / access checks

- [ ] Anonymous SIP rejected.
- [ ] Guest Wi-Fi blocked from registering.
- [ ] Unknown device registration blocked/monitored.
- [ ] Student denied paging/conference/recordings (each logged as Access Denied Event).
- [ ] Failed registrations logged.
- [ ] Lost-device reset flow works.

---

## 6. Edge cases

| Case | Expected |
|---|---|
| Caller hangs up before voicemail | Missed emergency record created (no voicemail) |
| Caller says nothing to voicemail | Silent voicemail saved, Pending Review |
| Repeated calls from same SAP ID | Grouped by SAP ID + time window |
| Queue has zero available responders | Still accepts call, immediately escalates, raises alert |
| Weak Wi-Fi mid-call | Move caller / use fixed phone / ERT callback |
| AP overloaded | Escalate to IT; reduce load; add AP/voice VLAN later |

---

## 7. Sign-off

Pilot passes when the functional matrix (all 19), capacity targets, and security
checks pass, and ERT completes a drill. Sign-off: **IT Admin + ERT Lead**, then the
[Go-Live Checklist](18-Go-Live-Checklist.md) for **UPES administration** approval.
