# UPES-ECS Quick-Reference Cards

Print-and-post one-pagers. Cut along the lines. Keep the ERT card at every desk, the
van card in the van, and the student card on notice boards.

---

## ✂️ ERT DESK CARD

```text
┌─────────────────────────────────────────────────────────────┐
│  UPES-ECS — ERT DESK QUICK CARD                             │
│                                                             │
│  ANSWER 111:                                                │
│  "UPES Emergency Response, this is [name].                  │
│   What is your emergency and where are you located?"        │
│                                                             │
│  ASK (6): what happened · WHERE · injured/danger ·          │
│           name/SAP ID · callback · still ongoing?           │
│                                                             │
│  DISPATCH:                                                  │
│   life risk  → send help NOW (+ 9000 / bridge if big)      │
│   unclear    → 3-way bridge, keep caller on, tell Lead     │
│   minor      → dispatch without transfer, log              │
│                                                             │
│  KEY NUMBERS:  Medical 4200 · Security 4300 · Lead 4101    │
│   Paging 700-705 (Lead approves) · Command room 9000       │
│   Pause queue *45 · Resume *46                             │
│                                                             │
│  SILENT CALLER = REAL EMERGENCY. Don't hang up.            │
│   "If you can't speak, press any key." Dispatch to         │
│   known location. Log Critical.                            │
│                                                             │
│  YOU OWN THE INCIDENT until handoff confirmed.             │
│  Unsure? → escalate to Lead, keep caller on line.          │
│  Answer ≤20s · Missed callback ≤5 min · Log everything.    │
└─────────────────────────────────────────────────────────────┘
```

---

## ✂️ SURGE / DECLARED INCIDENT CARD

```text
┌─────────────────────────────────────────────────────────────┐
│  MANY CALLS AT ONCE / BIG EVENT → ERT LEAD DECLARES INCIDENT│
│                                                             │
│  1. BROADCAST FIRST — page instructions (700s) to cut calls │
│  2. OPEN 9000 — pull in all operators + off-duty            │
│  3. DEPLOY THE VAN if fixed infra is degraded               │
│  4. TRIAGE — overflow → location voicemail; dedupe reports  │
│  5. PRIORITIZE BY SEVERITY, not call order                  │
│                                                             │
│  Rule: broadcasting beats answering-each in a mass event.   │
└─────────────────────────────────────────────────────────────┘
```

---

## ✂️ VAN DEPLOYMENT CARD

```text
┌─────────────────────────────────────────────────────────────┐
│  UPES-ECS — VAN FIELD DEPLOYMENT                            │
│                                                             │
│  1. Drive to zone w/ line-of-sight to repeaters             │
│  2. Raise mast · start power (battery → generator)          │
│  3. Power-on: PBX → AP → repeaters → backhaul links up      │
│  4. Verify: queue ≥2 available                              │
│  5. Coverage: register a phone at each repeater edge         │
│  6. TEST: dial 199 then 111 → console rings → recording OK  │
│  7. Announce live · page instructions if declared incident  │
│                                                             │
│  PRE-CHECK (keep van ready): config synced · batteries     │
│   charged · generator fueled · spare repeater onboard      │
└─────────────────────────────────────────────────────────────┘
```

---

## ✂️ STUDENT / STAFF CARD

```text
┌─────────────────────────────────────────────────────────────┐
│  CAMPUS EMERGENCY?  →  DIAL 111                             │
│  on UPES-ECS (your SIP app, campus Wi-Fi)                   │
│                                                             │
│  Setup once:  install Linphone → log in with SAP ID →      │
│               allow background + turn OFF battery saver     │
│  Test safely: dial 199 (drill) or 198 (echo)               │
│  Call a friend: dial their SAP ID                          │
│                                                             │
│  In an emergency: say WHAT happened and WHERE you are.     │
│  Keep the app running. Stay on campus Wi-Fi. Stay charged. │
└─────────────────────────────────────────────────────────────┘
```

> **If no responder is free**, 111 hands you straight to the offline first-aid
> coach — no dead-air. **Press 1** any time for immediate first-aid steps. (The
> coach also answers on **102** if you want to try it.)

---

## ✂️ POSTER (large print)

```text
╔═════════════════════════════════════════╗
║                                         ║
║        CAMPUS EMERGENCY                 ║
║                                         ║
║            DIAL  1 1 1                   ║
║                                         ║
║        on UPES-ECS                       ║
║   (SIP app · campus Wi-Fi · no SIM)     ║
║                                         ║
║   Say what happened and where you are.  ║
║                                         ║
╚═════════════════════════════════════════╝
```

---

## Daily readiness micro-card (control room)

```text
□ Asterisk up   □ Queue ≥2 available   □ ERT device registered
□ 199 test OK   □ Recording OK         □ Voicemail OK
□ Storage <75%  □ 4200 & 4300 up       □ Mobile Wi-Fi test OK
□ No unreviewed missed emergencies
```
