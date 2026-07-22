# UPES-ECS Emergency Response SOP

**For:** ERT Operators and ERT Lead / Incident Commander
**Covers:** answering 111, classifying, dispatching, coordinating, logging, closing
**Companion docs:** [Numbering Plan](01-Numbering-Plan.md) · [Drill SOP](03-Drill-Test-SOP.md) · [Role Matrix](04-SIP-Account-Role-Matrix.md)

> This SOP is deliberately short. In an emergency, long forms slow response.
> Keep it to one screen you can act on.

---

## 0. Before your shift (30 seconds)

You answer as a **generic ERT position** (e.g. `ERT-Desk-1` / 4110), not as yourself —
see [ERT Roles & Shifts](30-ERT-Roles-and-Shifts.md). Take over the position live and
hand it over live; the seat stays in the queue, only the officer changes.

Confirm on the Health Dashboard (or ask IT):

- [ ] You are **at your position** and its Android is **Registered**, on charger.
- [ ] The position shows **Available** in the queue (dial `*46` if paused).
- [ ] ERT queue shows **at least 2 available** positions.
- [ ] Last **199 test call** rings your position.
- [ ] Recording + voicemail = OK, storage not full.
- [ ] You've read the missed-emergency queue + open incidents from the last shift, and **signed the shift log**.

If fewer than 2 positions are available, tell the ERT Lead **before** relying on the system.

---

## Part A — Answering a 111 call

**Opening line (say it every time):**

> "UPES Emergency Response, this is **[your name]**. What is your emergency and where are you located?"

**Capture fast — these six are mandatory:**

1. What happened?
2. **Exact location?** (building, floor, room, landmark)
3. Is anyone injured or in immediate danger?
4. Caller name / SAP ID?
5. Callback extension?
6. Is the situation still ongoing?

Ask optional questions **only if it doesn't slow help**: number of people, visible hazards (fire/smoke/electrical/water), whether they can stay on the line.

**Rule:** If the call sounds serious and you're missing details → **dispatch first, gather details second.**

---

## Part B — Classify the incident

Pick **one** category (keep it simple):

```text
Medical   ·   Security   ·   Fire / Smoke   ·   Accident / Injury
Violence / Threat   ·   Infrastructure   ·   Hostel / Warden   ·   Other
```

---

## Part C — Decide the dispatch (decision tree)

```text
Is there a life / safety risk?
├─ YES  → Dispatch the right team IMMEDIATELY.
│         Serious / multi-team → also open Conference 9000 and/or three-way bridge.
│
├─ UNCLEAR → Keep caller on the line. Use a THREE-WAY BRIDGE so the
│            responder can question the caller directly. Escalate to ERT Lead.
│
└─ NON-CRITICAL → DISPATCH WITHOUT TRANSFER. Give safety instruction, log it.
```

**Dispatch modes** (never use blind transfer):

| Mode | When | How |
|---|---|---|
| **Dispatch without transfer** *(default)* | You can send help without the caller talking to another team | Keep the caller, separately call the responder team |
| **Warm transfer** | The responder must speak to the caller directly | Put caller on brief hold → call target → confirm they'll take it → transfer |
| **Three-way bridge** | Serious / unclear / location vague | Bring the responder into the same call; you stay on |

**You remain the Incident Owner** until a handoff is confirmed or the ERT Lead reassigns it. This prevents "I thought someone else had it."

**Quick dispatch guide:**

- **Medical injury** → Medical Room `4200` (warm transfer or 3-way).
- **Fire / smoke** → Security `4300` + Operations. Consider paging **only** if an area must evacuate/avoid.
- **Security threat** → Security Control `4300`. Keep caller on line if safe.
- **Hostel emergency** → Warden + Security. Hostel paging `702` only if authorized.
- **Major / multi-team** → Activate **Conference 9000**, escalate to ERT Lead.

---

## Part D — Paging (use with care)

Paging is powerful and can cause panic. **Use only when a public safety action is needed** (evacuate, avoid an area, immediate instruction) **and ERT Lead / Incident Commander approves.**

- **Never** page for rumors, minor incidents, personal disputes, or testing without a drill notice.
- All-campus **700 requires a PIN** and ERT Lead approval.

**Message template — short, calm, action-first:**

```text
Attention. This is UPES Emergency Response.
[Instruction].
[Area affected].
[What to do].
Await further instructions.
```

Example:
> "Attention. This is UPES Emergency Response. Students in Hostel B, evacuate using the main staircase. Move to the football ground assembly point. Do not use elevators. Await further instructions."

---

## Part E — Conference 9000 (Main Incident Command Room)

Open **9000 only** when more than one team is involved or the ERT Lead needs live coordination. **Do not** open 9000 for every call.

- 9000 is **recorded** during a real incident.
- Requires role access + PIN.
- Link the conference to the Incident ID.

---

## Part F — Missed emergency review (mandatory)

Missed 111 calls become **Missed Emergency Incidents** (severity Critical, status Pending Review) and appear in the **Missed Emergency Review Queue**. They must **never** auto-close.

**Review within 5 minutes during active hours:**

1. Open the missed incident on the dashboard.
2. Listen to the voicemail.
3. Identify caller + location (from SAP ID / caller ID).
4. **Call back** (mandatory when the caller is known).
5. Dispatch responders if the situation is clear.
6. Add action notes.
7. Mark **Reviewed** or **Convert to Active Incident**.

Status values: `Pending Review · Reviewed · Callback Attempted · Converted to Active Incident · Closed as Duplicate · Closed as False Alarm`.

---

## Part G — Logging (every call)

The system auto-creates an incident for **every** 111 call. You fill in what it can't capture.

**Mandatory fields:** Incident ID, date/time, caller SAP ID + name, caller device/IP, caller role, answered-by, queue wait, answer time, escalation attempts, transfer/bridge actions, **final status**, notes, recording path.

- ERT Operator writes the initial notes; **ERT Lead finalizes and closes.**
- False alarms are still logged, then closed as `Closed as False Alarm`.
- Dispatch notes are **mandatory** for any real dispatch.

---

## Part H — Closing & post-incident review

- **Only ERT Lead / Duty Officer closes** an incident, after reviewing notes and final status.
- For any serious incident or failed drill, produce a short review note:

```text
Date / Scenario:
What worked:
What failed:
Response time (answer + dispatch):
Recording / log status:
Device issues:
Training gaps:
Action items → Owner → Due date:
```

---

## Part I — Silent / can't-speak calls

A 111 call that connects but the caller is **silent, whispering, or the audio sounds
like distress** is treated as a **real, critical emergency** — never dismissed as a
wrong number or pocket-dial.

**Protocol:**
1. **Do not hang up.** Stay on the line and listen to the background (voices, threats, movement).
2. Offer a no-speech path:
   > "This is UPES Emergency Response. If you can hear me but can't speak, **press any key** now."
   A DTMF keypress confirms a live silent emergency.
3. The call **already carries the caller's SAP ID** (identity) and, if from a fixed
   device, its location — use them.
4. Dispatch security to the caller's **known/registered location**; attempt a discreet
   callback or text via the directory only if it won't endanger the caller.
5. Log as a **silent emergency, severity Critical.** Keep recording.

**Why one number:** someone hiding from a threat can only remember **111** — there is
deliberately no separate "silent line" to decide between under pressure.

> **Future:** the UPES VoIP app's **silent panic button** (broadcasts coordinates with
> the call) will be the real solution — see [Risk Register R6](21-Risk-Register-and-Gaps.md).

---

## Part J — Surge / Declared Incident posture

When you get **many simultaneous 111 calls** or a known campus-wide event (earthquake,
fire, major hazard), the **ERT Lead declares an incident** and the team switches from
"answer each call" to "control the event."

**On declaration:**
1. **Broadcast first.** Use **paging (700s)** to give the whole affected area
   instructions immediately — this cuts inbound call volume by answering the common question.
2. **Open Conference 9000** for multi-team coordination; pull in all available ERT
   operators (and off-duty responders).
3. **Deploy the disaster-response van** to the incident zone if fixed infra is degraded
   — see [Mobile Van Deployment](23-Mobile-Van-Deployment.md).
4. **Triage, don't queue-block.** Callers who can't be answered go to a **triage
   voicemail that captures location**; **dedupe** many reports of the same event
   (group by area + time).
5. **Prioritize by severity, not call order** — life-safety first.

**Principle:** in a mass event, **broadcasting instructions beats answering every call
individually.** Don't let the queue saturate — push information out, pull coordination
into 9000, and dispatch by severity.

---

## Response-time expectations

| Milestone | Target |
|---|---|
| Answer 111 | Within **20 seconds** |
| Escalation kicks in | After 20 seconds unanswered |
| Missed-call callback | Within **5 minutes** |

**If you are ever unsure → escalate to ERT Lead and keep the caller on the line.**
