# UPES-ECS ERT & Fixed-Device SIP Setup Guide

For **Emergency Response Team** members, control-room staff, and **fixed campus
devices** (desk phones, medical/security phones, IP speakers).

ERT members should have **two ways to answer**: a **fixed desk phone** in
UPES-ERT-ROOM **and** a mobile SIP app — so a dead battery never means a missed
emergency.

---

## Part 1 — ERT member (mobile app)

Same as the student guide, but with the **ERT profile** (your SAP ID stays your number).

```text
App          : Linphone (Android/iOS) or MicroSIP (Windows desk)
Username     : <your SAP ID>
Password     : <your UPES-ECS ERT password>
Domain       : pbx.upes.lan   (or IP from IT)
Display name : Your Name       → shows as "Name - SAP ID" on caller ID
Profile      : UPES-ECS ERT Profile  (your account is placed in ctx_ert)
```

Your **role/context** — not your number — is what lets you receive the 111 queue.
IT sets this in FreePBX; you don't configure it yourself.

---

## Part 2 — Fixed devices (role/location answer points)

A "fixed device" is defined by its **extension + role + location** (4xxx), **not** by
the hardware. It is provisioned by IT with a **fixed 4xxx extension**, not a SAP ID.

> **Hardware — Phase 1 = dedicated Android phone (Linphone); IP phones later.**
> For now, each fixed answer point (ERT Lead 4101, Medical 4200, Security 4300) is a
> **dedicated Android phone** logged in as its 4xxx extension. When IP phones arrive,
> provision the **same extension** on the IP phone and retire the Android — no config
> change. An Android used as an answer point **must** be:
> - **dedicated** to that role (not someone's personal phone),
> - **kept on the charger**, always powered,
> - **battery-optimization OFF / Unrestricted**, auto-start ON (see [doc 24](../reference/mobile-app-reliability.md)),
> - ideally **screen-lock disabled** or set to stay awake while charging,
>
> otherwise it will deregister and miss incoming emergency calls.

```text
Extension    : 4000-4999 range   (see Numbering Plan)
Username     : the fixed extension (e.g. 4300)
Password     : strong random per device
Display name : Location-Role-Extension   e.g. Security-Control-4300
Context      : ctx_fixed_device (or ctx_ert for ERT desks)
Hardware     : Phase 1 = dedicated Android + Linphone; later = IP phone (same extension)
Static IP    : recommended (set when on IP phones; for Android, DHCP reservation)
```

**Key fixed extensions:**

| Ext | Device | Caller ID shows |
|---|---|---|
| 4101 | ERT Lead position | `ERT-Lead` · `ctx_ert_lead` |
| 4110–411x | ERT Operator positions (answer 111 queue) | `ERT-Desk-1…` · `ctx_ert` |
| 4200 | Medical position (dispatch target) | `Medical-1` · `ctx_responder` |
| 4300 | Security position (dispatch target) | `Security-Control` · `ctx_responder` |
| 47xx | IP speakers / gate phones (fixed) | zone/location · `ctx_fixed_device` |

**Positions vs fixed devices:** 4101–4699 are **responder positions** staffed by shift
([SOP 30](../operations/ert-roles-and-shifts.md)) — ERT positions answer the 111 queue, the rest
(`ctx_responder`) are dispatch targets. 4700–4799 are true **fixed devices** (a speaker
only *receives* paging; a gate phone only calls 111 + selected security/ERT).

---

## Part 3 — Joining the emergency queue

- ERT devices are added to **`ert_emergency_queue`** in FreePBX (both desk phones and ERT mobile apps).
- Strategy = **ring all available**; busy/paused/offline are skipped.
- **Healthy queue = at least 2 available responders.** Below that, tell the ERT Lead.

**Pause / resume yourself** (e.g. stepping away from the desk):

```text
*45  → Pause  (stop receiving queue calls)
*46  → Resume (start receiving queue calls again)
```

Pausing only affects **queue** calls — you can still be dialed directly and can still join conferences. Confirm the prompt to avoid accidental pause.

---

## Part 4 — Answering a 111 call

1. Your device rings with caller ID: `EMERGENCY 111 - Name - SAP ID`.
2. Answer and use the opening line from the [ERT SOP](../operations/ert-sop.md):
   > "UPES Emergency Response, this is [name]. What is your emergency and where are you located?"
3. Recording is already running (started the moment the caller dialed 111).
4. Classify → decide dispatch mode → keep incident ownership → log.

Full call handling is in **[02-ERT-SOP.md](../operations/ert-sop.md)** — keep it open at your desk.

---

## Part 5 — Dispatch, paging, conference (quick reference)

| Action | How | Restriction |
|---|---|---|
| **Warm transfer** | Hold caller → call target → confirm → transfer | ERT Operators / Lead |
| **Three-way bridge** | Bring responder into the live call, you stay on | Lead / trained Operators |
| **Paging a zone** | Dial the zone code `700–705` and speak live | Lead / Control Room; 700 needs PIN |
| **Open Command Room** | Dial **9000** + PIN | Emergency roles only; recorded when active |
| **Reach Medical / Security** | Dial **4200 / 4300** | ERT roles |

Never use **blind transfer** as the normal workflow — the caller can get lost and you lose ownership.

---

## Part 6 — Daily readiness (start of shift)

- [ ] Your desk phone **and** mobile app show **Registered**.
- [ ] Queue shows **≥ 2 available** responders.
- [ ] A **199** test call rings your device and records.
- [ ] Medical `4200` and Security `4300` are registered.
- [ ] Health Dashboard = OK; storage not full.

If anything fails → tell the ERT Lead / IT **before** relying on the system. A failed
111/199 test is a **critical, do-not-go-live** condition.

---

## Part 7 — If a device is lost or compromised

Report to IT/helpdesk immediately. They will reset the SIP credential, force
re-provision, and log the event. For fixed devices, disabling requires IT Admin /
ERT Lead approval and the location/owner record is updated.

**Emergency answering is a duty — keep at least one of your two devices registered at all times.**
