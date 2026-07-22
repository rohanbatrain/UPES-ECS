# UPES-ECS Test Evidence & Sign-off Sheet

**Purpose:** a fill-in **record** proving each pilot test actually **passed** — the
evidence companion to the [Pilot Test Plan](17-Pilot-Test-Plan.md). Print it, run the
tests, fill every Result cell, attach evidence, then use it for go-live sign-off
([Go-Live Checklist](18-Go-Live-Checklist.md)).

> Every functional row is a **Must pass**. A failed **111 / 199** test or a
> **recording failure** is a **critical, do-not-go-live** condition (see §6).

---

## Header — fill before testing

| Field | Value |
|---|---|
| Date | |
| Environment | ☐ Campus fixed  ☐ Van |
| Tester(s) | |
| Asterisk version | |
| FreePBX version | |
| Config version | |
| Server | `upes-ecs-pbx-01` / |

---

## 1. Functional tests (all 19 must pass)

From [Pilot Test Plan §2](17-Pilot-Test-Plan.md). Record evidence for each: recording
filename, incident ID, or log line.

| # | Test | Expected result | Result (PASS/FAIL) | Evidence / notes | Tester | Date |
|---|---|---|---|---|---|---|
| 1 | Mobile SIP registration over Wi-Fi | Registers + stays registered | | | | |
| 2 | SAP-ID → SAP-ID calling | Connects, clear two-way audio | | | | |
| 3 | Any authenticated user calls 111 | Reaches ERT queue | | | | |
| 4 | 111 reaches ERT queue | ERT device rings | | | | |
| 5 | ERT answers | Caller ID shows `EMERGENCY 111 - Name - SAP ID` | | | | |
| 6 | Escalation | Unanswered → Lead 4101 → backup group | | | | |
| 7 | Emergency voicemail | Records; creates Missed Emergency Incident (Critical, Pending) | | | | |
| 8 | Recording for 111 | File created, correct naming, linked to incident | | | | |
| 9 | Student calls not recorded | No recording produced | | | | |
| 10 | Warm transfer | Caller handed off after target confirms | | | | |
| 11 | Three-way bridge | Caller + ERT + responder all connected | | | | |
| 12 | Paging restricted | Authorized works; student blocked + logged | | | | |
| 13 | Conference 9000 restricted | Authorized joins; unauthorized blocked + logged | | | | |
| 14 | Pause/resume `*45`/`*46` | Paused agent skipped by queue | | | | |
| 15 | Missed-call review | Appears in review queue; callback works | | | | |
| 16 | 199 drill | Simulates 111, no real dispatch, `DRILL-ONLY` | | | | |
| 17 | Health check | Script/CLI reports status correctly | | | | |
| 18 | Backup/restore | Config restore test passes | | | | |
| 19 | SOP understood | ERT completes a call-handling drill | | | | |

---

## 2. Capacity / quality checks

From [Pilot Test Plan §3](17-Pilot-Test-Plan.md).

| Test | Target | Result (PASS/FAIL) | Evidence / measured value | Tester | Date |
|---|---|---|---|---|---|
| Simultaneous SIP registrations | Pilot count stable | | | | |
| Simultaneous student calls | 10 without degradation | | | | |
| Simultaneous emergency calls | 2–5 answered | | | | |
| Normal load vs 111 priority | 111 unaffected by normal traffic | | | | |
| AP behaviour under voice load | No excessive drops | | | | |
| Latency / jitter / loss | < 150 ms · low · < 1% | | | | |
| Call setup time | < 3 s internal | | | | |
| PBX CPU/RAM | Within headroom | | | | |
| Recording storage growth | Tracked; disk < 75% | | | | |

---

## 3. Security / access checks

From [Pilot Test Plan §5](17-Pilot-Test-Plan.md).

| Check | Expected | Result (PASS/FAIL) | Evidence / log line | Tester | Date |
|---|---|---|---|---|---|
| Anonymous SIP rejected | Rejected | | | | |
| Guest Wi-Fi blocked from registering | Blocked | | | | |
| Unknown device registration | Blocked / monitored | | | | |
| Student denied paging/conference/recordings | Denied + logged (Access Denied Event) | | | | |
| Failed registrations logged | Logged | | | | |
| Lost-device reset flow | Works | | | | |

---

## 4. Edge cases

From [Pilot Test Plan §6](17-Pilot-Test-Plan.md).

| Case | Expected | Result (PASS/FAIL) | Evidence / incident ID | Tester | Date |
|---|---|---|---|---|---|
| Caller hangs up before voicemail | Missed emergency record created (no voicemail) | | | | |
| Caller says nothing to voicemail | Silent voicemail saved, Pending Review | | | | |
| Repeated calls from same SAP ID | Grouped by SAP ID + time window | | | | |
| Queue has zero available responders | Accepts call, immediately escalates, raises alert | | | | |
| Weak Wi-Fi mid-call | Move caller / use fixed phone / ERT callback | | | | |
| AP overloaded | Escalate to IT; reduce load; add AP/voice VLAN later | | | | |

---

## 5. Mobile-specific checks (optional per-device record)

From [Pilot Test Plan §4](17-Pilot-Test-Plan.md) · [SOP 24](24-Mobile-App-Reliability-and-Battery.md).

| Check | Result (PASS/FAIL) | Phone model / notes | Tester | Date |
|---|---|---|---|---|
| Registers + reconnects after Wi-Fi drop | | | | |
| 111 + another SAP-ID call, two-way audio | | | | |
| Behaviour on screen lock documented | | | | |
| Mic permission behaviour verified | | | | |
| Caller ID renders `Name - SAP ID` | | | | |

---

## 6. Critical-failure reminder

> **Do-not-go-live conditions.** If any of these fail, **stop** — do not sign off until fixed and re-tested:
> - A failed **111** test (tests 3, 4, 5).
> - A failed **199** drill (test 16).
> - A **recording failure** on 111/199 (test 8).
> - Missed-emergency capture not working (test 7).
>
> Re-run the whole affected row on **199 before 111** after any fix, and back up before re-config.

---

## 7. Final sign-off

Testing complete, all 19 functional tests **PASS**, capacity/security/edge checks
recorded, and ERT drill completed. Sign-off order: **IT Admin + ERT Lead**, then
**University**. See [Pilot Test Plan §7](17-Pilot-Test-Plan.md) and
[Go-Live Checklist](18-Go-Live-Checklist.md).

| Role | Name | Date | Signature |
|---|---|---|---|
| IT / UPES-ECS Admin | | | |
| ERT Lead / Incident Commander | | | |
| University (UPES administration) | | | |

**Go-live approved: ☐ Y  ☐ N**

Reason / conditions (if N): ________________________________________________
