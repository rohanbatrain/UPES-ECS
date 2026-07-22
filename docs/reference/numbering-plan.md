# UPES-ECS Numbering Plan

The single source of truth for every number, code, and range in UPES-ECS.
All other documents and the FreePBX configuration must match this plan.

---

## 1. Emergency service codes

| Number | Name | Behaviour | Phase |
|---|---|---|---|
| **111** | Campus Emergency Hotline | **The one number to dial.** Human-first. Rings the ERT queue; press 1 any time for the first-aid fast-path; if no answer point is free the call goes straight to the offline coach (102); Lead + backup alerted in the background while the caller is coached. Recorded. | 1 |
| ~~100~~ | **DEPRECATED — removed** | Formerly an alias to 111. **No longer routed or dialable.** Retired because many softphones hijack 100 as "Police" and intercept it before it reaches the PBX; the campus standardised on 111. Do not re-add. | — |
| **102** | Offline Panic-Coach (`ctx_ai_helpline`) | Deterministic first-aid — CPR / bleeding / choking / fire / lockdown / recovery / trapped — with **zero internet**. Automatic fallback when no human answers 111; also dial 102 directly to test. | 1 |
| **101** | Local-first AI Triage Assistant | **Local-first** AI triage (Ollama/llama.cpp + Whisper + Piper — **no cloud, no Gemini**). Always escalates to 111 when urgent/unclear; falls back to 111 on any failure. **Never a number a caller dials.** | 1.5 / 2 |
| **199** | Drill / Test Emergency Line | Simulates the 111 flow. No real dispatch. Logs labelled `DRILL-ONLY`. | 1 |
| **198** | Echo / Audio Test | Plays your own audio back. For checking mic/speaker. Optional. | 1 |
| **196** | Internal AI Test Line | Tests the AI pipeline only. | 2 |
| 112 / 911 | Alias to 111 | **Only if UPES administration approves.** Not enabled by default. | TBD |

> **Do not** use 101 as an alias to 111. 101 is reserved for the local-first AI assistant and is never dialed by a caller.
> **100 is deprecated and unrouted** — 111 is the single campus emergency number. Do not reintroduce a 100 alias.

---

## 2. Human users — SAP ID extensions

Every real person (student, staff, faculty, ERT member) uses their **SAP ID** as
both SIP extension and SIP username.

```text
SIP Extension = SAP ID
SIP Username  = SAP ID
Caller ID     = "Name - SAP ID"   e.g.  "Rohan Batra - 500120597"
```

- The **number identifies the person**; the **role/context decides permissions**.
- SAP IDs are never reused. When a person leaves, the account is disabled and logs are kept.
- Same person, different role → same SAP ID, different context (see Role Matrix).

---

## 3. Responder positions & fixed devices — 4000–4999

**Responder positions** are generic roles **staffed by shift** (not named people) —
see [Responder Roles & Shifts](../operations/ert-roles-and-shifts.md). **Fixed devices** are
location-bound and unstaffed (speakers, gate phones).

| Range / Ext | Role | Staffed? | Context | Answers 111 queue? |
|---|---|---|---|---|
| **4101** | ERT Lead / Incident Commander | position | `ctx_ert_lead` | escalation target |
| **4110–4119** | ERT Operator positions (desks + reserves) | position | `ctx_ert` | ✅ queue member |
| **4120** | ERT Control Room | position | `ctx_control_room` | ✅ |
| **4200–4299** | Medical positions — `4200` dispatch, `4201-4202` seats | position | `ctx_responder` | ❌ dispatch target |
| **4300–4399** | Security positions — `4300` dispatch, `4302-4303` seats | position | `ctx_responder` | ❌ dispatch target |
| **4301** | Security **Lead** (department coordination) | position | `ctx_responder_lead` | ❌ dispatch target |
| **4400–4499** | Warden / Hostel positions — `4400` dispatch, `4401-4402` seats | position | `ctx_responder` | ❌ dispatch target |
| **4500–4599** | Admin / Operations positions — `4500` dispatch, `4501-4502` seats | position | `ctx_responder` | ❌ dispatch target |
| **4600–4699** | IT / Network positions — `4600` dispatch, `4601-4602` seats | position | `ctx_responder` | ❌ dispatch target |
| 4700–4799 | IP speakers / gate phones (fixed) | **no** | `ctx_fixed_device` | ❌ |

**Department shape:** each responder department has a **dispatch front-door** (the round
number — always reachable, and the target of the 111 background-alert / backup) plus
**2 answer seats**, kept minimal; add more within the hundred-block only when a shift
staffs them. Security additionally has a **Lead** (`4301`) — the one department that
coordinates others.

**Naming (FreePBX display name):** positions use a role name (`ERT-Desk-1`,
`Medical-1`, `Security-Control`); fixed devices use `Location-Role-Extension`
(`Security-Gate-Main-4301`).

Provision positions from [../provisioning/responder-positions.csv](https://github.com/rohanbatrain/UPES-ECS/blob/main/provisioning/responder-positions.csv),
fixed devices from [../provisioning/fixed-devices.csv](https://github.com/rohanbatrain/UPES-ECS/blob/main/provisioning/fixed-devices.csv).
Final roster/locations are **TBD** — collect from UPES IT before provisioning.

---

## 4. Emergency paging zones — 700–799

Live voice broadcast to fixed/shared devices. **Restricted** (see Role Matrix).

| Code | Zone | Who may page |
|---|---|---|
| **700** | All-Campus Emergency Broadcast | ERT Lead / Incident Commander **only** — **PIN required** |
| 701 | Academic Blocks | ERT Lead / Control Room |
| 702 | Hostels | ERT Lead / Warden-authorized role |
| 703 | Security Gates | ERT Lead / Security Control |
| 704 | Medical / ERT Zone | ERT Lead / Control Room |
| 705 | Admin / Operations Zone | ERT Lead / Control Room |

- Students and general staff are **blocked** from all paging codes.
- All paging attempts (success **and** denied) are logged as `Emergency Paging Attempt`.
- Start phrase: **"Attention. This is UPES Emergency Response."**
- Drill paging is prefixed: **"Drill, drill, drill."** and requires prior notice.

---

## 5. Incident command conference rooms — 9000–9099

Responder-only voice bridges. **PIN-protected. No student/general-staff access.**

| Room | Name | Access |
|---|---|---|
| **9000** | Main Incident Command Room | ERT Lead, ERT Operators, Security, Medical, Warden/Admin emergency roles |
| 9001 | Security Coordination Room | Security + ERT Lead / Control Room |
| 9002 | Medical Coordination Room | Medical + ERT Lead / Control Room |
| 9003 | Warden / Hostel Coordination Room | Wardens + ERT Lead / Control Room |
| 9004 | Operations / Admin Coordination Room | Admin/Ops + ERT Lead / Control Room |

- **9000 is recorded** when activated for a real incident. Side rooms are not recorded by default.
- Participant limits: 9000 → 20, side rooms → 10.
- Every join/leave is logged as `Incident Conference Logs`.

---

## 6. Feature codes

| Code | Action | Who |
|---|---|---|
| **`*22`** | Go **on shift** — join the emergency queue for your shift | Responders (self) |
| **`*23`** | Go **off shift** — leave the emergency queue at end of shift | Responders (self) |
| **`*45`** | Pause self from ERT emergency queue (short break, still on shift) | ERT members (self) |
| **`*46`** | Resume into ERT emergency queue after a pause | ERT members (self) |

- `*22`/`*23` are the **shift login/logout** (whole shift); `*45`/`*46` are a **temporary pause/resume** within a shift — the two are distinct.
- ERT Lead can pause/resume other members (via admin action).
- Pause only affects **queue** calls — a paused responder can still be dialed directly and can still join conferences.
- Confirmation prompt recommended to prevent accidental pause.

---

## 7. The emergency call path (111)

```text
Caller dials 111
        │  (recording starts immediately)
        ▼
ert_emergency_queue        ── ring all available answer points
        │                     • press 1 any time  ─────────►  first-aid fast-path (102)
        │  no answer point free / nobody answers
        ▼
Offline Panic-Coach (102)  ── straight to the coach, NO dead-air. Deterministic
        │                     first-aid; caller coached in parallel while, in the
        │                     BACKGROUND, ERT Lead (4101) + backup (Security 4300 +
        │                     Medical 4200 + Warden/Admin duty) are auto call-filed
        │                     ("press 1 to join the queue").
        │
        │  inside the coach:  9 = retry a responder
        │                     8 = leave a message ─────────►  Emergency Voicemail (max 60s)
        │                                                             │
        ▼                                                             ▼
   caller stays coached                                Missed Emergency Incident
   until a human joins                                 ── severity Critical, Pending Review
                                                          (still the final catch)
```

- **No serial escalation, no dead-air:** the call no longer rings Lead 20s → backup 20s → voicemail in sequence. The queue rings available answer points; if none is free the caller goes **straight to the offline coach**, and the Lead + backup are alerted **in the background in parallel** — the caller is being coached the whole time.
- **Press 1 any time** during the queue jumps straight to the first-aid fast-path.
- **Inside the coach:** `9` retries a responder; `8` leaves a message → emergency voicemail → Missed Incident (the final catch that guarantees nothing is dropped).

**Queue rules:** strategy = ring all available; skip busy/paused/offline; healthy = **min 2 available responders**; the coach/background alert kicks in the moment no answer point is free.

---

## 8. Identity / logging formats

| Item | Format | Example |
|---|---|---|
| Incident ID | `ERT-YYYYMMDD-0001` | `ERT-20260704-0001` |
| Recording file | `ERT-YYYYMMDD-0001_CALLER-SAPID_YYYYMMDD-HHMMSS.wav` | `ERT-20260704-0001_500120597_20260704-143210.wav` |
| Call log label (111) | `EMERGENCY_111_CALL` | |
| Queue log | `ERT_EMERGENCY_QUEUE` | |
| Access-denied event | `Access Denied Event` | |

---

## 9. Dialplan contexts (permission groups)

| Context | Assigned to |
|---|---|
| `ctx_student` | Students |
| `ctx_staff` | Staff / faculty |
| `ctx_ert` | ERT Operator positions (answer the 111 queue) |
| `ctx_ert_lead` | ERT Lead / Incident Commander position |
| `ctx_responder` | Medical / Security / Warden / Ops / IT positions (dispatch targets) |
| `ctx_responder_lead` | Department-lead position (Security Lead 4301) — `ctx_responder` base + seam for future elevated grants; not an ERT/queue role |
| `ctx_control_room` | UPES-ERT-ROOM / control-room users |
| `ctx_ai_helpline` | Offline panic-coach (102) — deterministic first-aid, zero internet |
| `ctx_fixed_device` | Fixed campus SIP devices (speakers, gate phones) |
| `ctx_admin` | UPES-ECS / IT admins |

Full permission detail is in [04-SIP-Account-Role-Matrix.md](sip-account-role-matrix.md).

---

## 10. Retention

| Data | Retention |
|---|---|
| Emergency call recordings & voicemail | **90 days** (university may extend) |
| Incident logs, CDR/CEL, queue/paging/conference logs | **1 year** |
| Config backups | 30 daily + 12 weekly snapshots |

Final legal retention policy is **TBD** — to be approved by UPES administration.

---

## Reserved / do-not-assign

- `111`, `100`, `101`, `102`, `196`, `198`, `199` — service codes, never assign to a user.
- `700–799`, `9000–9099`, `4000–4999` — reserved ranges.
- `*22`, `*23`, `*45`, `*46` — feature codes.
- Any SAP ID — belongs to its owner only.
