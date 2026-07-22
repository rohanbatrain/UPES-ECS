# UPES-ECS — Feature Codes & Coordination Features

Reference for the features added in [`extensions_features.conf`](extensions_features.conf).
That file **only adds new contexts**; it never redefines existing ones. A human wires
each feature by adding an `include => ctx_xxx` line to the relevant **existing** role
context in [`extensions_custom.conf`](extensions_custom.conf), then `#include`s the new
file alongside it:

```asterisk
; in the master extensions.conf
#include "extensions_custom.conf"
#include "extensions_features.conf"
```

All codes were chosen to avoid the reserved numbers in the
[Numbering Plan](../SOP/01-Numbering-Plan.md): `101/102/111/196/198/199`, `700–799`,
`9000–9099`, `4xxx`, `*45/*46`, and the shift codes `*22/*23` this file adds, 9-digit SAP
IDs, 8-digit employee IDs. (`111` is the sole emergency number; `102`
is the offline panic-coach route. `100` is deprecated and removed — no longer dialable.)

> **Test order after wiring:** `199` (drill) → the new feature in a scheduled drill
> window → `111`. See [Drill/Test SOP](../SOP/03-Drill-Test-SOP.md).

---

## Dial-code summary

| Code | Feature | Context | Include into | Restriction |
|---|---|---|---|---|
| `211` | Dept hunt → Security (PJSIP/4300) | `ctx_departments` | `ctx_staff` (+`ctx_ert`) | staff/responders; students use 111 |
| `212` | Dept hunt → Medical (PJSIP/4200) | `ctx_departments` | `ctx_staff` | staff/responders |
| `213` | Dept hunt → Warden (PJSIP/4400) | `ctx_departments` | `ctx_staff` | staff/responders |
| `214` | Dept hunt → Ops (PJSIP/4500) | `ctx_departments` | `ctx_staff` | staff/responders |
| `215` | Dept hunt → IT (PJSIP/4600) | `ctx_departments` | `ctx_staff` | staff/responders |
| `411` | Dial-by-name directory | `ctx_directory` | `ctx_staff` | needs VM boxes with names |
| `*80<ext>` | Intercom / auto-answer | `ctx_intercom` | `ctx_ert`, `ctx_admin` | ERT / admin only |
| `*9` | One-tap incident bridge → room 9000 | `ctx_bridge_quick` | `ctx_ert` | ERT contexts; 9000 PIN still applies |
| `*77` | Silent SOS / duress | `ctx_sos` | `ctx_student` | all users (inherited chain) |
| `105` | Request callback | `ctx_callback` | `ctx_student` | students + staff |
| `720` | Announce: EVACUATE | `ctx_announce` | `ctx_ert_lead`, `ctx_control_room` | ERT-Lead / control only |
| `721` | Announce: AVOID AREA | `ctx_announce` | `ctx_ert_lead`, `ctx_control_room` | ERT-Lead / control only |
| `722` | Announce: ALL CLEAR | `ctx_announce` | `ctx_ert_lead`, `ctx_control_room` | ERT-Lead / control only |
| `723` | Announce: ASSEMBLE | `ctx_announce` | `ctx_ert_lead`, `ctx_control_room` | ERT-Lead / control only |
| `*22` | Shift ON — join the ERT queue (start answering 111) | `ctx_shift` | `ctx_responder` (+ ERT roles) | responders only |
| `*23` | Shift OFF — leave the ERT queue | `ctx_shift` | `ctx_responder` (+ ERT roles) | responders only |
| _(no code)_ | Mass call-out / roll-call target | `ctx_callout` | — (origination target only) | driven by `mass_callout.sh` |
| _(no code)_ | Follow-me / on-call escalation | `ctx_escalation_followme` | optional swap for `ctx_escalation` | opt-in only |

> **`ctx_student` include chain:** `ctx_staff` includes `ctx_student`, `ctx_ert`
> includes `ctx_staff`, etc. So anything included into `ctx_student` (SOS `*77`,
> callback `105`) is reachable by **everyone**. Anything into `ctx_staff` reaches
> staff **and** responders/ERT, but **not** students.

---

## Features

### Department hunt groups — `211`–`215`  ·  `ctx_departments`
Direct-dial the on-shift responder desk: `211` Security→`4300`, `212` Medical→`4200`,
`213` Warden→`4400`, `214` Ops→`4500`, `215` IT→`4600`. Rings **25s**, then plays a
short "unavailable" prompt and hangs up. **These are non-emergency direct lines** —
real emergencies still use `111`. Students are intentionally not given these (they use
`111`).
- **Include into:** `[ctx_staff]` → `include => ctx_departments`. ERT inherit it via
  `ctx_ert → ctx_staff`; add explicitly to `[ctx_ert]` if you tighten `ctx_staff`.
- **Restriction:** staff / responders only.
- **Dependency:** sound file `upes-ecs/dept-unavailable`. Targets `4200/4300/4400/4500/4600`
  provisioned per [responder-positions.csv](../provisioning/responder-positions.csv).

### Dial-by-name directory — `411`  ·  `ctx_directory`
`Directory()` lets a caller spell a name to find an extension. Reads names from the
`upes-ecs` voicemail context.
- **Include into:** `[ctx_staff]` → `include => ctx_directory` (ERT inherit via `ctx_staff`).
- **Restriction:** staff / responders.
- **⚠ Dependency — voicemail boxes:** a user/department only appears if it has a
  **voicemail box with a full name** in the `upes-ecs` context of
  [`voicemail.conf`](../deploy/asterisk/voicemail.conf). **Today only the `emergency`
  box exists**, so `411` is effectively empty until per-user/dept VM boxes are added.

### Intercom / auto-answer — `*80<ext>`  ·  `ctx_intercom`
Dials `<ext>` with an auto-answer SIP header so the target phone answers hands-free
(broadcast-style). Sends both `Call-Info: <sip:…>;answer-after=0` and
`Alert-Info: Auto Answer` via a `PJSIP_HEADER(add,…)` **pre-dial (`b()`) handler on the
callee channel** — the correct PJSIP method (a plain `Set(PJSIP_HEADER…)` on the caller
would not reach the callee's INVITE).
- **Include into:** `[ctx_ert]` and `[ctx_admin]` → `include => ctx_intercom`.
- **Restriction:** ERT / admin only.
- **Dependency:** target phones must honor auto-answer headers (Polycom/Grandstream/
  Yealink all support one of these; confirm per device model in
  [Device Provisioning](../SOP/14-Device-Provisioning-Sheet.md)). Helper context
  `ctx_intercom_predial` is used internally — do **not** include it in a role.

### One-tap incident bridge — `*9`  ·  `ctx_bridge_quick`
Jumps straight into the **Main Incident Command** ConfBridge room `9000` defined in
`extensions_custom.conf [ctx_conference]`.
- **Include into:** `[ctx_ert]` → `include => ctx_bridge_quick` (ERT-Lead / responder /
  control inherit via their includes).
- **Restriction:** ERT contexts only. Room `9000` is PIN-protected (`PIN_9000`) and
  recorded when active — see [Numbering Plan §5](../SOP/01-Numbering-Plan.md).

### Silent SOS / duress — `*77`  ·  `ctx_sos`
Raises a **CRITICAL** `silent_sos` incident with **minimal/no talk path**, then pages the
ERT alert zone (one-way `A()` prompt) so responders are notified without the caller
having to speak. Uses `incident_id.sh` for the ID and `sos_alert.sh` for the record.
- **Include into:** `[ctx_student]` → `include => ctx_sos` (available to **all** users
  via the include chain).
- **Restriction:** none (deliberately universal).
- **Dependencies:** `sos_alert.sh` at `${UPES_BIN}`; sound `upes-ecs/sos-alert`; global
  **`ERT_ALERT_ZONE`** (PJSIP dial string of ERT alert speakers/desks) — **must be added
  to `[globals]`**. Incident record: `/var/lib/upes-ecs/incidents/silent-sos.ndjson`
  (same store/format as [`missed_incident.sh`](../scripts/missed_incident.sh)); alert flag:
  `/var/lib/upes-ecs/alerts/sos-pending.log`.
- **Design note (not implemented):** a "duress digit while on `111`" option — a caller
  already on the emergency line (`111`) presses a hidden DTMF sequence
  to flag duress — would live in the `111` in-call handler in `extensions_custom.conf`, not
  in this standalone code. Coordinate wording with the [ERT SOP](../SOP/02-ERT-SOP.md).

### Request callback — `105`  ·  `ctx_callback`
Caller presses `1` to confirm; the request (`ext` + timestamp) is appended to
`/var/lib/upes-ecs/callbacks/callbacks.log` for ERT to action, then a short confirmation
plays and the call hangs up. Logged **inline** via `System(...)` (caller ID is sanitized
with `FILTER` before it reaches the shell) — no extra helper script. Swap in a helper
script later if you prefer.
- **Include into:** `[ctx_student]` → `include => ctx_callback` (students + staff).
- **Dependencies:** sounds `upes-ecs/callback-confirm`, `upes-ecs/callback-logged`,
  `upes-ecs/callback-cancelled`.

### Pre-recorded announcements — `720`–`723`  ·  `ctx_announce`
Broadcast a pre-recorded message to all-campus speakers: `720` evacuate, `721` avoid-area,
`722` all-clear, `723` assemble. Implemented as `Page(${ALLCAMPUS_SPEAKERS},A(<file>)i)` —
the `A()` option delivers the prompt **to every paged speaker** (a bare `Playback` would
only play to the caller). Each attempt is logged via
[`log_paging.sh`](../scripts/log_paging.sh).
- **Include into:** `[ctx_ert_lead]` and `[ctx_control_room]` → `include => ctx_announce`.
- **Restriction:** ERT-Lead / control room only.
- **⚠ Numbering note:** `720–723` sit **inside the 700–799 paging block**. They are
  distinct explicit extensions (no clash with `700–705`), but they **must be recorded in
  the [Numbering Plan](../SOP/01-Numbering-Plan.md)** so no future paging zone reuses them.
- **Dependencies:** global **`ALLCAMPUS_SPEAKERS`** (already used by `ctx_paging`; ensure
  it is defined in `[globals]`). Sound files
  `upes-ecs/announce-{evacuate,avoid-area,all-clear,assemble}` are **generated separately**
  (record per the [Voice-Prompt Scripts](../SOP/28-Voice-Prompt-Scripts.md)).

### Shift login / logout — `*22` / `*23`  ·  `ctx_shift`
Self-service ERT shift control from the responder's own handset. `*22` (**shift ON**) adds the
caller to the emergency queue (`AddQueueMember ${UPES_QUEUE}`) so they start answering `111`;
`*23` (**shift OFF**) removes them. Every event is written to the shift log via `shift_event.sh`
for audit + the Console's Presence & Shifts view. Mirrors the `ert-shift.sh` admin tool and the
Console shift buttons. **Distinct from `*45`/`*46`** (queue pause/resume): `*22`/`*23` join or
leave the queue entirely, `*45`/`*46` only pause/unpause an already-joined member.
- **Include into:** `[ctx_responder]` (and the ERT roles that inherit it) → `include => ctx_shift`.
- **Restriction:** responders only.
- **Dependencies:** `shift_event.sh` at `${UPES_BIN}`; global **`UPES_QUEUE`**; sounds
  `upes-ecs/shift-on`, `upes-ecs/shift-off`. Shift log consumed by the Console.

### Mass call-out / roll-call (Emergency Alert Service / EAS) — `ctx_callout` + `mass_callout.sh`
No dial code — this is an **origination target** driven by
[`scripts/mass_callout.sh`](../scripts/mass_callout.sh). The script rings every extension
in a group CSV and plays a message; in **rollcall** mode it also reads one DTMF digit
(`1` = safe) and appends `ext,response,time` to `/var/lib/upes-ecs/rollcall/<runid>.csv`.
- **Caller ID:** the call is presented as the **Emergency Alert Service** —
  `"UPES-EAS" <111>` — **never ANONYMOUS**. Override with env `EAS_CID_NAME` / `EAS_CID_NUM`.
- **How the call is placed & how params reach the dialplan:** one Asterisk **call file**
  per member (same non-blocking spool mechanism as `alert_responders.sh`), dropped into
  `/var/spool/asterisk/outgoing/`. The call file carries the `CallerID:` and passes
  `CALLOUT_SOUND` / `CALLOUT_RUNID` / `CALLOUT_MODE` as per-call `Setvar:` channel
  variables. This replaced the old `channel originate` path, which could not attach a
  caller ID (→ ANONYMOUS) and could only pass params as shared globals whose propagation
  **raced the answer** — the callee often reached `Playback(${CALLOUT_SOUND})` with an
  empty sound and the call dropped with no message. Call files fix both.
- **Concurrency:** none required — every parameter rides on its own call file, so runs are
  independent (no flock/globals). Calls are still paced (`CALL_DELAY`, default 2s) to avoid
  flooding the registrar. See the script header for details.
- **Report:** [`scripts/rollcall_report.sh`](../scripts/rollcall_report.sh) `<runid>`
  prints total called / acknowledged-safe / responded-not-safe / no-response (with the
  no-response extension list — computed from the `<runid>.roster` the engine writes).
- **Dependencies:** group CSVs in
  [`provisioning/callout-groups/`](../provisioning/callout-groups/README.md) (example:
  `wardens.example.csv`); the passed sound file (bare names are prefixed `upes-ecs/`);
  `mass_callout.sh` + `rollcall_report.sh` installed at `${UPES_BIN}`;
  `/var/lib/upes-ecs/rollcall/` writable by the Asterisk user (ctx_callout writes the CSV);
  `/var/spool/asterisk/outgoing/` writable (call-file spool).
- **EAS prompts:** the announcement set (`custom/upes-{evacuate,shelter,allclear,assemble,rollcall,test}`)
  and the roll-call control prompts (`upes-ecs/rollcall-{press1,thanks,noack}`) are generated by
  [`scripts/gen-callout-prompts.sh`](../scripts/gen-callout-prompts.sh) using the **on-prem Piper
  neural TTS** (professional voice — not the robotic pico2wave used by the panic-coach). Point
  `PIPER_MODEL` at the voice you want; wording is source-controlled in that script and in
  [SOP 28](../SOP/28-Voice-Prompt-Scripts.md).
- **Do NOT** `include => ctx_callout` in any role context.

### Follow-me / on-call escalation — `ctx_escalation_followme` (OPTIONAL)
A **drop-in alternative** to `[ctx_escalation]`. Not wired by default and does **not**
overwrite the existing chain. After the ERT Lead and backup group, it dials an on-call
**mobile** via a SIP trunk, with `GotoIfTime()` time-of-day routing (evenings/overnight/
weekends → mobile; business hours → emergency voicemail).
- **To adopt:** change the last hop of `[ctx_emergency_111]` from
  `Goto(ctx_escalation,s,1)` to `Goto(ctx_escalation_followme,s,1)`.
- **Dependencies:** globals **`ONCALL_TRUNK`** and **`ONCALL_MOBILE`**, plus a working
  outbound trunk/gateway. **LAN-only Asterisk cannot reach a mobile without one** — this
  is why the feature is optional/opt-in.

---

## New globals to add to `[globals]`

`extensions_features.conf` does **not** add a second `[globals]` (to avoid duplicate-section
issues). Add these to the existing `[globals]` in `extensions_custom.conf`:

| Global | Used by | Notes |
|---|---|---|
| `ALLCAMPUS_SPEAKERS` | `ctx_announce` (and existing `ctx_paging`) | PJSIP dial string of all-campus IP speakers |
| `ERT_ALERT_ZONE` | `ctx_sos` | PJSIP dial string of ERT alert speakers/desks |
| `ONCALL_TRUNK` | `ctx_escalation_followme` (optional) | SIP trunk name for the on-call mobile leg |
| `ONCALL_MOBILE` | `ctx_escalation_followme` (optional) | on-call mobile number reached via the trunk |

## Sound files to record / generate
`upes-ecs/dept-unavailable`, `upes-ecs/sos-alert`, `upes-ecs/callback-confirm`,
`upes-ecs/callback-logged`, `upes-ecs/callback-cancelled`, `upes-ecs/rollcall-press1`,
`upes-ecs/rollcall-thanks`, `upes-ecs/rollcall-noack`, and the announcements
`upes-ecs/announce-{evacuate,avoid-area,all-clear,assemble}`, plus whatever call-out
message you pass to `mass_callout.sh`. Record per
[Voice-Prompt Scripts](../SOP/28-Voice-Prompt-Scripts.md).

## Voicemail boxes (for `411`)
Add per-user/department boxes with full names to the `upes-ecs` context of
[`voicemail.conf`](../deploy/asterisk/voicemail.conf), or the directory stays empty.

## Data / log locations
| Path | Written by |
|---|---|
| `/var/lib/upes-ecs/incidents/silent-sos.ndjson` | `sos_alert.sh` |
| `/var/lib/upes-ecs/alerts/sos-pending.log` | `sos_alert.sh` |
| `/var/lib/upes-ecs/callbacks/callbacks.log` | `ctx_callback` (`105`) |
| `/var/lib/upes-ecs/rollcall/<runid>.roster` | `mass_callout.sh` |
| `/var/lib/upes-ecs/rollcall/<runid>.csv` | `ctx_callout` (roll-call) |
| `/var/lib/upes-ecs/paging/paging.log` | `log_paging.sh` (announcements) |

See [Incident Logging Schema](../SOP/12-Incident-Logging-Schema.md) and
[Recording Retention Policy](../SOP/13-Recording-Retention-Policy.md).
