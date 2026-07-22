# UPES-ECS Responder Roles & Shift Model

How every responder team is staffed. UPES-ECS uses **generic positions** (not
named-person accounts) for **all** responder roles — ERT **and** Medical, Security,
Warden, Operations, IT. Trained officers **occupy a position for their shift**; the
position — its extension, its device, its role — never changes.

> **Why this model:** it gives flexibility. A trained officer can step into a position
> at any time **without registering a new SIP account during a crisis**. The position
> is always ready; only the human in the seat rotates.

> **The nuance:** **ERT positions answer the 111 queue.** Other responder positions
> (Medical, Security, Warden, Ops, IT) are **dispatch targets** — they receive handoffs
> and coordinate, but do not answer 111. Same shift model; different job.

---

## 1. The core idea

```text
WRONG (rigid):  queue rings  Staff Member One, Staff Member Two, Staff Member Three  (named people)
                → if they're off-shift or unavailable, you must re-register someone mid-crisis

RIGHT (this):   queue rings  ERT-LEAD, ERT-OP-1, ERT-OP-2  (generic positions)
                → whoever is the trained on-shift officer is already logged into the position
```

- A **position** = a fixed `4xxx` extension + a dedicated Android answer device at the ERT room.
- The **ERT queue members are the positions**, never individuals.
- A **trained officer** takes over a position at shift start and hands it over at shift end.
- **No mid-crisis provisioning.** The seat is always live; the person changes, the account doesn't.

---

## 2. ERT positions (generic roles)

| Position | Extension | Caller ID | Context | In queue? |
|---|---|---|---|---|
| ERT Lead / Incident Commander | **4101** | `ERT-Lead` | `ctx_ert_lead` | Escalation target |
| ERT Operator 1 (Desk 1) | **4110** | `ERT-Desk-1` | `ctx_ert` | ✅ |
| ERT Operator 2 (Desk 2) | **4111** | `ERT-Desk-2` | `ctx_ert` | ✅ |
| ERT Operator 3 (Desk 3) *(scale)* | **4112** | `ERT-Desk-3` | `ctx_ert` | ✅ |
| ERT Control Room *(optional)* | **4120** | `ERT-Control` | `ctx_control_room` | ✅ |

All sit in the ERT desk range **4100–4199** ([Numbering Plan](01-Numbering-Plan.md)).
Provision them from [../provisioning/responder-positions.csv](../provisioning/responder-positions.csv).

**Minimum to go live:** 2 operator positions available (recommended 3+), plus the Lead position.

---

## 2a. Other responder positions (same model)

Medical, Security, Warden, Operations, and IT are **also generic positions staffed by
shift** — trained department staff occupy them, no crisis-time registration. They live
in `ctx_responder`: they can call 111/199, reach ERT and each other, receive dispatch
handoffs, and join coordination rooms — but they **do not answer the 111 queue**,
cannot page all-campus, and cannot control the ERT queue.

Each department has the **same shape**: a **dispatch front-door** (the round number —
always-reachable, and the target of the 111 background-alert / backup) plus **2 answer
seats**. Security additionally has a **Lead** — the one department that coordinates others.
Keep seat count minimal (2) and add more within the hundred-block only when a shift
actually staffs them.

| Position | Extension | Context | Role |
|---|---|---|---|
| Medical Dispatch | **4200** | `ctx_responder` | Dispatch front-door — medical |
| Medical Responder 1 | **4201** | `ctx_responder` | Answer seat — medical |
| Medical Responder 2 | **4202** | `ctx_responder` | Answer seat — medical |
| Security Dispatch | **4300** | `ctx_responder` | Dispatch front-door — security |
| **Security Lead** | **4301** | `ctx_responder_lead` | Department lead — security coordination |
| Security Responder 1 | **4302** | `ctx_responder` | Answer seat — security |
| Security Responder 2 | **4303** | `ctx_responder` | Answer seat — security |
| Warden Dispatch | **4400** | `ctx_responder` | Dispatch front-door — hostel/warden |
| Warden Responder 1 | **4401** | `ctx_responder` | Answer seat — warden |
| Warden Responder 2 | **4402** | `ctx_responder` | Answer seat — warden |
| Operations Dispatch | **4500** | `ctx_responder` | Dispatch front-door — infrastructure |
| Operations Responder 1 | **4501** | `ctx_responder` | Answer seat — operations |
| Operations Responder 2 | **4502** | `ctx_responder` | Answer seat — operations |
| IT / Network Dispatch | **4600** | `ctx_responder` | Dispatch front-door — IT/network |
| IT / Network Responder 1 | **4601** | `ctx_responder` | Answer seat — IT/network |
| IT / Network Responder 2 | **4602** | `ctx_responder` | Answer seat — IT/network |

> **`ctx_responder_lead` (Security Lead 4301):** same base capabilities as a responder
> today — a **distinct context** so the lead seat is identifiable in logs and is the seam
> for future elevated department-lead grants (own-zone paging, room moderation). It does
> **not** answer the 111 queue, page all-campus, or control the ERT queue — those stay ERT-only.

Add more per department within its hundred-block (e.g. `4203`, `4204` for extra medical
seats). Provision from [../provisioning/responder-positions.csv](../provisioning/responder-positions.csv).

> **Fixed devices vs positions:** a *position* is occupied by a rotating trained person
> (Medical, Security desks). A *fixed device* is location-bound and not staffed (IP
> speaker, unattended gate phone) — those stay in `ctx_fixed_device`
> ([fixed-devices.csv](../provisioning/fixed-devices.csv)).

---

## 3. People vs positions

| | People (officers) | Positions (ERT roles) |
|---|---|---|
| Account | Personal SAP-ID (student/staff context) | Generic `4xxx` (ERT context) |
| Purpose | Normal person-to-person calls | Emergency answering + queue |
| Recorded | No (normal calls) | Yes (111/199 flows) |
| Changes | — | Never; only the occupant rotates |

So your confirmed roster (Staff Member One, Staff Member Two, Staff Member Three, Rohan Batra) are
**staff/student accounts** for normal calling **and** trained officers who *staff* ERT
positions on their shift. **None of them is permanently an "ERT account."** This is
what resolves the earlier "who is ERT?" question — it's a **shift assignment, not an
account property.**

---

## 4. Shift roster (who holds which position when)

Kept as a simple sheet — **outside Asterisk** — owned by the ERT Lead. Example:

| Shift | Time | ERT-Lead (4101) | ERT-Op-1 (4110) | ERT-Op-2 (4111) |
|---|---|---|---|---|
| A (Morning) | 06:00–14:00 | Officer __ | Officer __ | Officer __ |
| B (Evening) | 14:00–22:00 | Officer __ | Officer __ | Officer __ |
| C (Night) | 22:00–06:00 | Officer __ | Officer __ | Officer __ |

- Only **trained** officers may be rostered to a position.
- Coverage rule: at least the minimum available positions per shift ([Health Monitoring](10-Health-Monitoring-Checklist.md)).
- Off-shift trained officers are a **reserve** — they can occupy a spare position immediately in a surge, no new registration needed.

---

## 5. Shift handover (start & end of every shift)

> **Shift login codes:** `*22` = **go on shift** (join the ERT emergency queue) · `*23` =
> **go off shift** (leave it). These are the shift join / leave codes — **separate** from
> `*45` / `*46`, which only **pause / resume** you temporarily while you remain on shift.

**Incoming officer, at the position:**
- [ ] Position Android is **Registered** (green), on charger, battery-unrestricted.
- [ ] Go **on shift**: dial `*22` to join the ERT emergency queue; the position then shows **Available**. (`*45` / `*46` only pause / resume within a shift — they are not the shift login.)
- [ ] A **199** test call rings the position.
- [ ] Read the missed-emergency queue + any open incidents from the previous shift.
- [ ] Sign the **shift log** (position, officer, time-in).

**Outgoing officer:**
- [ ] Brief the incoming officer on open incidents.
- [ ] Do **not** go off shift (`*23`, which removes the position from the queue) until the reliever is confirmed live — never a plain `*45` pause as a stand-in for handover.
- [ ] Sign time-out.

> **Never leave a position uncovered.** Hand over live — the seat stays in the queue
> the whole time; only the human swaps.

---

## 6. Accountability (who actually answered)

The position answers the call, so logs show the **position** (`ERT-Desk-1`). To get the
**person**, combine two records:

```text
Incident log  → position + timestamp   (from Asterisk, automatic)
Shift log     → officer on that position at that time   (from the roster)
= the individual officer who handled the incident
```

Officers are also expected to state their name on answer ("UPES Emergency Response,
this is [name]…") per the [ERT SOP](02-ERT-SOP.md), so the recording captures it too.

---

## 7. Surge staffing (ties to declared incidents)

In a [declared incident](02-ERT-SOP.md), reserve trained officers **occupy spare
positions immediately** — because the accounts already exist and are trained-for, there
is zero setup delay. If more seats are needed than positions exist, add positions from
the 4100–4199 range ahead of time (pre-provisioned spares kept paused, unpaused on demand).

**Recommendation:** pre-provision **1–2 spare operator positions** (e.g. 4113, 4114)
kept paused, so a surge is `*46` (unpause) + sit down, not "create an account."

---

## 8. Van / field positions

The disaster-response van carries its **own position devices** (same extensions, synced
config) — see [Mobile Van Deployment](23-Mobile-Van-Deployment.md). A trained officer
staffs the van position on deployment exactly like a room position.

---

## 9. What changed from the original questionnaire

The questionnaire said *"time-of-day membership: keep static for Phase 1; shift-based
later."* This model brings **shift-based staffing forward to Phase 1** via generic
positions — which is simpler *and* more resilient than static named membership, because
the queue never has to be re-edited when people change.

---

## Summary

- ERT queue = **positions**, not people.
- Officers **staff positions by shift**; trained reserves can jump in with no setup.
- **No crisis-time registration.** Continuity through handover.
- Accountability = incident log (position) + shift log (officer).
