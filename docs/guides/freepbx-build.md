# UPES-ECS FreePBX Build Guide (Phase 0 + Phase 1)

Hands-on steps to stand up the emergency core in **FreePBX**. Follow in order.
Assumes the [Numbering Plan](01-Numbering-Plan.md) and [Role Matrix](04-SIP-Account-Role-Matrix.md).

> Everything here is LAN-only. Do **not** open SIP/RTP to the public internet.

---

## Phase 0 — Server & first calls

### 0.1 Install
- OS: **Ubuntu Server LTS** or **Debian stable**. Hostname: `upes-ecs-pbx-01`.
- Install **FreePBX** (official FreePBX distro is simplest, or `freepbx` on top of Asterisk 18+/20+).
- Apply updates; install all module updates in **Admin → Module Admin**.

### 0.2 Network
- Give the server a **static IP** (record IP / subnet / gateway).
- Local DNS: point `pbx.upes.lan` and `sip.upes.lan` at that IP (or document the IP fallback).
- **Asterisk SIP Settings → RTP**: set the RTP range (default 10000–20000) and, since LAN-only, leave external/NAT settings empty. Local Networks = your campus subnets.
- Confirm **Wi-Fi client isolation is OFF** (or use a voice VLAN) so clients reach the PBX.

### 0.3 SIP driver defaults
- **Settings → Asterisk SIP Settings**: use **PJSIP** (chan_pjsip), bind UDP 5060 on the LAN interface only.
- **Allow Anonymous Inbound SIP = No.** **Allow SIP Guests = No.**

### 0.4 Two test extensions + echo
- **Applications → Extensions → Add (PJSIP)**: create `1001`, `1002` (temporary test only).
- Register two softphones (Linphone) on Wi-Fi; call `1001 ↔ 1002`.
- **Applications → Feature Codes**: enable **Echo Test** and set it to **198** (or add a custom `198 → Echo()`).

✅ **Phase 0 done when** two Wi-Fi phones call each other and 198 echoes.

---

## Phase 1 — Emergency core

### 1.1 Contexts / classes
FreePBX groups permissions via **Class of Service** (COS) or custom contexts. For UPES-ECS:
- Simplest: use the **Class of Service** module to build classes matching the [Role Matrix](04-SIP-Account-Role-Matrix.md) (student, staff, ert, ert_lead, control_room, fixed_device, admin).
- Advanced/custom logic (drill mode, SAP-ID rules) goes in **`extensions_custom.conf`** — see [09-Dialplan-Design.md](09-Dialplan-Design.md).

### 1.2 SAP-ID extensions (bulk)
- **Admin → Bulk Handler → Extensions → Import**: CSV with columns
  `extension = SAP ID`, `name`, `secret` (≥12 random), `voicemail`, plus a COS/context column.
- Set **Display Name** = person's name (caller ID renders `Name - SAP ID` via CID Name Prefix or outbound CID).
- Assign each to the correct class/context.

### 1.3 Fixed devices
- Create PJSIP extensions in **4000–4999**: `4101` ERT Lead, `41xx` ERT desks, `4200` Medical, `4300` Security.
- Display name = `Location-Role-Extension` (e.g. `Security-Control-4300`).
- Give static IPs where possible; restrict dialing by class.

### 1.4 ERT queue
- **Applications → Queues → Add**: name `ert_emergency_queue`.
  - **Ring Strategy:** `ringall`.
  - **Agent Timeout:** 20s. **Max Wait Time:** 20s → then fail over (escalation).
  - **Static Agents:** ERT desk phones + ERT mobile SAP-IDs.
  - **Skip Busy Agents:** Yes. **Music on Hold:** *None* (emergency hold announcement instead).
  - **Join Announcement / Periodic:** short "stay on the line" prompt.
  - **Fail Over Destination:** the escalation chain (below).

### 1.5 Escalation chain
Build with **Announcements + a custom context or a chain of Queues/Ring Groups**:
```text
ert_emergency_queue  (20s, ringall)
   └─ fail → ERT Lead 4101            (Ring Group / dial, 20s)
        └─ no answer → Backup Group   (Ring Group: 4300 + 4200 + warden/admin, ringall, 20s)
             └─ no answer → Emergency Voicemail box
```
- Backup group = **Applications → Ring Groups**, strategy `ringall`, 20s.
- Voicemail: a dedicated **Emergency Voicemail** box, max message 60s, prompt per [Numbering Plan](01-Numbering-Plan.md).

### 1.6 The 111 route
- Use a **Custom Destination** or **Misc Application** mapping **111**:
  1. `MixMonitor` start (recording begins immediately).
  2. Enter `ert_emergency_queue`.
- Pre-answer prompt: *"You have reached UPES Emergency Response. Your emergency call may be recorded. Please stay on the line."*
- Ensure **111 is reachable from every context** (it bypasses normal restrictions).

### 1.7 Recording
- **Settings → Advanced Settings:** confirm the recordings path + free space.
- Force recording **On** for the 111/199 routes only. Leave student-to-student **Off** by default.
- File naming via `MIXMON_FORMAT`/custom `MIXMONITOR_FILENAME`: `ERT-YYYYMMDD-0001_CALLER-SAPID_YYYYMMDD-HHMMSS.wav`.

### 1.8 Drill line 199
- Clone the 111 route to **199** but:
  - Prompt: *"This is a UPES-ECS drill call. No real emergency response will be dispatched."*
  - Route to a **test ERT target** (or the same queue in a drill window), **no** real escalation/dispatch.
  - Tag CDR/recording with `DRILL-ONLY` (set a channel variable / accountcode).

### 1.9 Verify (Phase 1 exit)
- [ ] Dial **111** from a student mobile → ERT device rings → answered → recording file created.
- [ ] Leave 111 unanswered → escalates → **Emergency Voicemail** → Missed Emergency Incident.
- [ ] Dial **199** → drill prompt → no real dispatch → `DRILL-ONLY` in logs.
- [ ] Student-to-student call → works, **not** recorded.

---

## FreePBX-specific tips

- **Every change:** click the red **Apply Config** banner, then verify with a test call.
- Use **Admin → Config Edit** for `extensions_custom.conf` (custom dialplan survives reloads).
- **CDR Reports** and **Asterisk Info → Queues** give you live queue/agent status for the daily readiness check.
- **Backup & Restore module** handles config backups (see [11-Backup-Restore-Procedure.md](11-Backup-Restore-Procedure.md)); still keep a git copy of custom configs.
- Lock the **FreePBX Admin GUI** to the management subnet only — never student Wi-Fi.
