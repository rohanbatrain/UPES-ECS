# UPES-ECS Drill & Test SOP

**For:** ERT Lead / Incident Commander + IT / UPES-ECS Admin
**Purpose:** test the emergency system safely — without causing panic or polluting real emergency records.

> **Golden rule:** routine testing uses **199**, never **111**.
> Real-111 testing happens only in a planned, announced drill window.

---

## 1. Test numbers

| Number | Use |
|---|---|
| **199** | Drill/Test line. Simulates the full 111 flow. **No real dispatch.** Logs labelled `DRILL-ONLY`. Recorded, marked drill. |
| **198** | Echo test — hear your own audio back (checks mic/speaker/network). |
| **111** | Real line. Test **only** during an approved, announced drill window. |
| 196 | Internal AI test line (later phase). |

- Any authenticated user may call **199** to check their own setup.
- **Drill mode** (which drills actually exercise escalation/paging/conference) is controlled by the ERT Lead.

---

## 2. Drill labelling

Every drill call, recording, and log entry is marked so it can never be confused with a real event:

```text
DRILL-ONLY
```

Paging drills additionally start with the spoken prefix:

> "Drill, drill, drill. This is a UPES-ECS drill. No real emergency response will be dispatched."

---

## 3. Drill types & cadence

| Drill | Frequency | What it proves |
|---|---|---|
| **1. Technical test** | As needed / daily readiness | SIP registration, 199 routing, ERT answer, recording, voicemail, logs |
| **2. ERT call-handling drill** | Monthly | Operators answer, ask the 6 questions, classify, dispatch, log |
| **3. Missed-call drill** | Monthly | Voicemail records + Missed Emergency Review Queue works |
| **4. Paging drill** | Monthly (**prior notice required**) | Authorized paging works; unauthorized paging is blocked; audibility per zone |
| **5. Full incident drill** | Quarterly (**ERT Lead + university approval**) | End-to-end: 111 → queue → dispatch → 9000 → paging → recording → review |

---

## 4. Daily readiness check (before relying on the system)

Owner: IT/Admin duty person or ERT control-room assignee.

- [ ] Asterisk / FreePBX service running.
- [ ] ERT queue has **≥ 2 available** responders.
- [ ] ERT answering device registered.
- [ ] **199 test call** works end to end.
- [ ] Emergency recording works (test call produced a file).
- [ ] Emergency voicemail can record.
- [ ] Storage not full (warning at 75%, critical at 90%).
- [ ] Critical fixed phones (Medical 4200, Security 4300) registered.
- [ ] One mobile SIP test over Wi-Fi works.

Log result as **Daily ECS Readiness Check**.

---

## 5. Weekly drill health check

Owner: ERT Lead + IT owner. Run a small scenario and verify:

- [ ] Student mobile calls 199 → ERT answers.
- [ ] Recording verified + labelled drill.
- [ ] Missed-call voicemail path tested.
- [ ] Warm transfer tested.
- [ ] Three-way bridge tested.
- [ ] Conference 9000 join tested (authorized) + blocked (unauthorized).
- [ ] Paging tested from an authorized device + blocked from a student account.

Log result as **Weekly ECS Drill Health Report**.

---

## 6. Running a full incident drill (quarterly)

**Before:**
1. Get ERT Lead + university authority approval.
2. Announce the window to ERT / control room (and campus if paging is involved).
3. Take a config backup.
4. Confirm daily readiness check passes.

**During:** run the scenario end to end using **199** where possible. If the real **111** line must be exercised, announce it first and keep the window tight.

**After:** produce the **UPES-ECS Post-Drill Review Report**:

```text
Scenario:
Participants:
Timings (answer / dispatch / resolution):
Pass / Fail per step:
Issues found:
Action items → Owner → Due date:
```

- SOP issues → action-item owner is the **ERT Lead**.
- Technical issues → action-item owner is the **IT Admin**.
- **Drill records are kept.** Every failure creates an action item.

---

## 7. Safety guardrails (what a drill must NOT do)

- ❌ Never surprise-test campus-wide paging (700) — always give notice.
- ❌ Never use **111** casually for routine testing — use **199**.
- ❌ Never auto-open Conference 9000 for every drill call.
- ❌ Never dispatch a real response during a drill unless the drill controller explicitly approves it.
- ❌ Never leave a drill's simulated "missed" call unreviewed — treat the workflow as real.

---

## 8. Go / no-go rule

If a **199 or 111 test fails**, the system is **not ready**. Do not go live and do not
rely on it until the failure is fixed and re-tested. A failed recording or a queue
with zero available responders is a **critical** failure, not a warning.
