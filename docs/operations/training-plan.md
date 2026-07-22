# UPES-ECS Training Plan

**Purpose:** make sure **every role can operate the system before go-live** — and
stays current after. Training ties the SOPs to muscle memory: each role must
*demonstrate* its tasks, not just read them.

**Companion docs:** [ERT SOP](02-ERT-SOP.md) · [Drill & Test SOP](03-Drill-Test-SOP.md) · [Pilot Test Plan](17-Pilot-Test-Plan.md) · [ERT Roles & Shifts](30-ERT-Roles-and-Shifts.md)

> Training follows the shift model: officers are trained on a **position**
> ([ERT Roles & Shifts](30-ERT-Roles-and-Shifts.md)), not as a named "ERT account."
> Train **reserves too**, so surge staffing actually works.

---

## 1. Who needs training + what they learn

| Role | Must be able to |
|---|---|
| **ERT Operator** | Answer 111 per the [ERT SOP](02-ERT-SOP.md); classify; the three **dispatch modes** (dispatch-without-transfer / warm transfer / three-way bridge); **silent / can't-speak protocol** (Part I); logging every call; **shift handover** ([SOP 30](30-ERT-Roles-and-Shifts.md)); **pause/resume `*45`/`*46`**. |
| **ERT Lead / Incident Commander** | All Operator content **plus** escalation, **paging approval + 700 PIN**, **Conference 9000 moderation**, incident **closure**, **surge / declared-incident** posture (SOP 02 Part J), and **van deployment** authority ([Van Deployment](23-Mobile-Van-Deployment.md)). |
| **Control Room** | Daily readiness checks, the **Health Dashboard**, and ongoing monitoring ([Health Monitoring](10-Health-Monitoring-Checklist.md)). |
| **IT / UPES-ECS Admin** | FreePBX build ([Build Guide](08-FreePBX-Build-Guide.md)), provisioning from CSVs ([Provisioning Sheet](14-Device-Provisioning-Sheet.md)), **backup / restore** ([SOP 11](11-Backup-Restore-Procedure.md)), health scripts, **security hardening** ([SOP 26](26-Security-Hardening.md)). |
| **Pilot Students / Staff** | Install the SIP app, **SAP-ID login**, **dial 111**, test with **199 / 198**, and set **battery / background** correctly ([Mobile App Reliability & Battery](24-Mobile-App-Reliability-and-Battery.md)). |

---

## 2. Training modules

| Module | Audience | Source doc | Format |
|---|---|---|---|
| M1 — Dial 111 basics + app setup | Pilot Students / Staff | [05](05-Student-SIP-Setup-Guide.md) · [24](24-Mobile-App-Reliability-and-Battery.md) | Hands-on setup + short demo |
| M2 — Battery / background reliability | Pilot users · IT | [24](24-Mobile-App-Reliability-and-Battery.md) | Hands-on, per phone model |
| M3 — Call handling (answer / classify / dispatch) | ERT Operators · Lead | [02](02-ERT-SOP.md) · [06](06-ERT-SIP-Setup-Guide.md) | SOP walk-through + role-play drill |
| M4 — Silent-call & missed-emergency review | ERT Operators · Lead | [02](02-ERT-SOP.md) (Parts F, I) | Scenario drill |
| M5 — Logging & incident records | ERT Operators · Lead | [02](02-ERT-SOP.md) · [12](12-Incident-Logging-Schema.md) | Walk-through + fill-in practice |
| M6 — Shift handover & pause/resume | ERT Operators · Lead | [30](30-ERT-Roles-and-Shifts.md) · [06](06-ERT-SIP-Setup-Guide.md) | Live handover rehearsal |
| M7 — Paging, Conference 9000, escalation | ERT Lead | [02](02-ERT-SOP.md) (Parts D, E) · [04](04-SIP-Account-Role-Matrix.md) | Controlled demo (PIN, drill notice) |
| M8 — Surge / declared incident & van | ERT Lead | [02](02-ERT-SOP.md) (Part J) · [23](23-Mobile-Van-Deployment.md) | Tabletop + field drill |
| M9 — Daily readiness & Health Dashboard | Control Room · ERT Lead | [10](10-Health-Monitoring-Checklist.md) | Hands-on dashboard tour |
| M10 — Build, provisioning & hardening | IT / Admin | [08](08-FreePBX-Build-Guide.md) · [14](14-Device-Provisioning-Sheet.md) · [26](26-Security-Hardening.md) | Hands-on build session |
| M11 — Backup / restore + health scripts | IT / Admin | [11](11-Backup-Restore-Procedure.md) · [../scripts/](../scripts/) | Hands-on, run a real restore |
| M12 — Drill & test discipline | ERT Lead · IT | [03](03-Drill-Test-SOP.md) · [17](17-Pilot-Test-Plan.md) | Run a 199 drill end-to-end |

---

## 3. Delivery format

Short, repeatable, hands-on. Every session is:

1. **Hands-on setup** — get the device/app/server actually working, not just described.
2. **SOP walk-through** — read the relevant doc together, one screen at a time.
3. **Drill** — practice on **199** (never 111) per the [Drill & Test SOP](03-Drill-Test-SOP.md); ERT drills feed the [Pilot Test Plan](17-Pilot-Test-Plan.md) matrix.

> **Golden rules apply in training too:** test with **199 before 111**; **back up
> before any change**; unsure → **escalate**. Never fire a real 111 or live paging to
> "practice" without a posted drill notice.

---

## 4. Per-role competency checklist (demonstrate before sign-off)

**ERT Operator**
- [ ] Answers a 199 call using the opening line; captures the six mandatory fields.
- [ ] Classifies and picks the correct **dispatch mode** (no blind transfer).
- [ ] Runs the **silent-call protocol** (stay on line, DTMF prompt, dispatch to known location).
- [ ] Completes an incident log with all mandatory fields.
- [ ] Performs a **live shift handover** and uses **`*45`/`*46`** correctly.

**ERT Lead / Incident Commander**
- [ ] Everything above, **plus:**
- [ ] Approves + sends a paging message (700 **PIN**, drill notice posted).
- [ ] Opens and moderates **Conference 9000**; links it to an Incident ID.
- [ ] Manages an **escalation** and formally **closes** an incident.
- [ ] Runs a **declared-incident / surge** tabletop, including **van deployment** call.

**Control Room**
- [ ] Reads the **Health Dashboard**; identifies "≥ 2 positions available."
- [ ] Completes a daily readiness check and flags a failing item to ERT Lead/IT.

**IT / UPES-ECS Admin**
- [ ] Builds/confirms a working "Dial 111" path; provisions from CSVs.
- [ ] Runs a **backup and a tested restore**.
- [ ] Runs the health-check script; applies a security-hardening item.

**Pilot Student / Staff**
- [ ] App installed, **SAP-ID login**, registered (green).
- [ ] Dials **199** successfully; knows **111** is the real emergency number.
- [ ] Battery optimization off / background allowed per [SOP 24](24-Mobile-App-Reliability-and-Battery.md).

---

## 5. Sign-off

Sign off only after the person **demonstrates** their checklist. Refer to trained
officers generically (see [ERT Roles & Shifts](30-ERT-Roles-and-Shifts.md)); the
confirmed roster is held in `../Notes/Confirmed Details.md`.

| Role trained | Trainer | Date | Signed |
|---|---|---|---|
| ERT Operator | | | |
| ERT Operator (reserve) | | | |
| ERT Lead / Incident Commander | | | |
| Control Room | | | |
| IT / UPES-ECS Admin | | | |
| Pilot Students / Staff (batch) | | | |

---

## 6. Refresher cadence

| Trigger | Action |
|---|---|
| **Initial** | Full module set for the role, before go-live. |
| **Monthly** | **Basic drill** — one 199 call-handling drill per shift; readiness check. |
| **Quarterly** | **Full drill** — surge/declared-incident tabletop + restore test. |
| **On any major change** | Re-train affected roles (dialplan, hardware, app, provisioning, policy). |
| **Reserves** | Re-train off-shift trained officers on the same cadence so **surge staffing works** — a reserve who can't operate is not a reserve. |

---

## 7. Trainer notes

- **Train the position, not the person.** Every officer must be interchangeable in a
  seat — that is the whole point of the shift model.
- **Drills only on 199/198.** A live 111 or live paging in training will cause a real
  dispatch or panic. Post a drill notice first.
- **Make them fail once.** Run the missed-emergency and silent-call scenarios so people
  practice the recovery path, not just the happy path.
- **Log training like an incident.** Keep the sign-off table current; an unsigned role
  is a go-live gap ([Risk Register](21-Risk-Register-and-Gaps.md)).
- **Reserves are real coverage.** If you only train the primary shift, you have no surge
  capacity — train enough people to fill every position twice.
