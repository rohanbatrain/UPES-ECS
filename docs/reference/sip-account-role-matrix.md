# UPES-ECS SIP Account & Role Matrix

The access-control source of truth. In FreePBX this maps to **contexts** on each
extension. If a capability is not granted here, the dialplan must deny it.

**Principle:** separate *normal internal calling* (open to authenticated users)
from *emergency authority functions* (restricted to emergency roles).

---

## 1. Roles → contexts

| Role | Context | Identity |
|---|---|---|
| Student | `ctx_student` | SAP ID |
| Staff / Faculty | `ctx_staff` | SAP ID (or employee ID mapped) |
| ERT Operator position | `ctx_ert` | 4110–4119 (answers 111 queue) |
| ERT Lead position | `ctx_ert_lead` | 4101 |
| **Responder position** (Medical/Security/Warden/Ops/IT) | `ctx_responder` | 4200–4699 (dispatch target) |
| **Department Lead position** (Security Lead) | `ctx_responder_lead` | 4301 — `ctx_responder` base + reserved seam for elevated grants |
| Control Room / Emergency Admin | `ctx_control_room` | 4120 / SAP ID |
| Fixed campus device | `ctx_fixed_device` | 4700–4799 |
| UPES-ECS / IT Admin | `ctx_admin` | SAP ID |

> The **number identifies the role; the context grants the permissions.**
> A person and a student can both have SAP-ID extensions — the difference is the context.

> **All responder roles are POSITIONS, not people** ([SOP 30](30-ERT-Roles-and-Shifts.md)).
> The `ctx_ert` / `ctx_ert_lead` / `ctx_responder` / `ctx_control_room` accounts are
> generic positions (`4101`, `4110`, `4200`, `4300`, …) staffed by trained officers
> **per shift** — never a person's personal SAP-ID account. Individuals keep
> student/staff accounts for normal calls and **occupy** a position when on shift.
>
> **`ctx_ert` answers the 111 queue. `ctx_responder` (Medical/Security/…) does not** —
> those are dispatch targets: they receive handoffs, reach ERT and each other, and join
> coordination rooms, but cannot answer 111, page all-campus, or control the ERT queue.
>
> **`ctx_responder_lead`** (the Security Lead, 4301) has the **same base capabilities as
> `ctx_responder` today** — it is a separate context so the lead seat is identifiable in
> logs and is the seam for future elevated department-lead grants (own-zone paging,
> coordination-room moderation). It is **not** an ERT role: no 111-queue answer, no
> all-campus paging, no ERT-queue control.

---

## 2. Capability matrix

| Capability | Student | Staff | ERT Op | ERT Lead | Control Room | Fixed Device | IT Admin |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| Call **111** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Call **199** (drill/test) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Student-to-student / internal calls | ✅ | ✅ | ✅ | ✅ | ✅ | limited | ✅ |
| Call staff/faculty | ⚠️ if approved | ✅ | ✅ | ✅ | ✅ | limited | ✅ |
| Call ERT directly (short nums) | ❌ use 111 | ❌ | ✅ | ✅ | ✅ | ⚠️ device-scoped | ✅ |
| Receive calls from ERT | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Receive **111 queue** calls | ❌ | ❌ | ✅ | ✅ | ⚠️ if agent | ⚠️ ERT desk | ❌ |
| Use **paging** (700–799) | ❌ | ❌ | ⚠️ request only | ✅ | ✅ | ❌ | ❌ |
| Page **all-campus 700** | ❌ | ❌ | ❌ | ✅ +PIN | ⚠️ if authorized +PIN | ❌ | ❌ |
| Join **conference 9000** | ❌ | ❌ | ✅ | ✅ | ✅ | ⚠️ role device | ❌ |
| Warm transfer | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Three-way bridge | ❌ | ❌ | ⚠️ if trained | ✅ | ✅ | ❌ | ❌ |
| Pause/resume queue (`*45`/`*46`) | ❌ | ❌ | ✅ self | ✅ self+others | ⚠️ others | ❌ | ✅ |
| Review missed-emergency voicemail | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ⚠️ if authorized |
| Access emergency recordings | ❌ | ❌ | ❌ | ✅ | ⚠️ per policy | ❌ | ⚠️ authorized admin |
| Manage SIP accounts / config | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| View Health Dashboard | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ✅ |

✅ allowed · ❌ denied · ⚠️ conditional (see notes)

---

## 3. Key rules

**Students**
- Can call 111, other students, and (if approved) staff and public/helpdesk fixed devices.
- Cannot page, join conferences, transfer, or touch recordings/voicemail.
- Student-to-student calls are **normal calls — not recorded, not incidents.**
- Cannot call ERT directly; they use **111**.

**Staff / Faculty**
- Similar to students, plus staff-to-staff calling.
- Emergency privileges only if explicitly assigned an emergency role (warden, medical, security, admin duty, IT).

**ERT Operators**
- Receive the 111 queue, dispatch, warm-transfer, join assigned conferences, pause/resume themselves.
- Cannot change config or create accounts.

**ERT Lead / Incident Commander**
- Everything an operator can do, plus: escalation control, paging (incl. 700 with PIN), moderate 9000, review missed voicemail, access recordings per policy, reassign incident ownership, pause/resume others.

**Control Room / Emergency Admin**
- Paging, monitor active calls, review logs, coordinate conferences, missed-emergency recovery.
- Does **not** automatically get server/OS admin unless also in the IT role.

**Fixed devices**
- Minimum permissions for their function only (e.g. an IP speaker only *receives* paging; a gate phone only calls 111 + selected security/ERT).

**IT Admin**
- Manages accounts, contexts, config, backups, health. Cannot change emergency **SOP** without ERT Lead / university approval.

---

## 4. Credential & security policy

| Rule | Setting |
|---|---|
| Anonymous SIP | **Disabled** |
| Guest Wi-Fi / unknown devices | **Blocked** from registering |
| Credentials | **Unique per account/device** |
| Shared credentials | **Banned** except controlled fixed devices |
| Password strength | **≥ 12 characters, random** |
| Password delivery | One-time secure delivery / reset workflow (not plain text in docs) |
| Registration source | University LAN / campus Wi-Fi only |
| Lost device | Immediately reset/revoke the SIP credential |
| Failed registrations | Logged; alert if ERT/fixed devices fail |
| Abuse | Suspend account after review; caller ID + logs identify the user |

---

## 5. Account lifecycle

`Pending Setup → Active → (Password Reset Required / Lost Device / Disabled) → Archived`

- Disabled/archived accounts **keep their logs and identity history**.
- Human SAP IDs are **never reused**. Fixed extensions may be reused only after history is archived.
- Devices per account: **2 for students, 3 for ERT/staff** (adjust after pilot).
- Role elevation (e.g. student → ERT) requires **ERT Lead + IT Admin / university** approval.

---

## 6. Emergency priority

- Calls to **111 are highest priority** and bypass normal restrictions.
- Normal internal/student calling **must not degrade** 111 handling — enforced via
  dedicated emergency context/queue capacity and, later, network QoS.

---

## 7. What gets logged (security-relevant)

Successful + failed SIP registration · unknown-device attempts · restricted-number
denials (`Access Denied Event`) · emergency call attempts · paging attempts
(allowed + denied) · conference joins · transfer/dispatch actions · voicemail &
recording access · config changes · account disable/revoke events.

Normal internal calls stay as ordinary CDR metadata — they do **not** become incidents.
