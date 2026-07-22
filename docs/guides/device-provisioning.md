# UPES-ECS Device Provisioning Sheet

**Process name:** UPES-ECS SIP Provisioning · **Reset process:** SIP Credential Reset Process
How SIP accounts, devices, credentials, and roles are created, assigned, and revoked.

---

## 1. Three identity types

| Type | Extension | Example |
|---|---|---|
| **Human user** | SAP ID | `500120597` |
| **Fixed device** | 4000–4999 | `4300` Security Control |
| **Service / feature code** | reserved short numbers | `111`, `700`, `9000`, `*45` |

Never mix them. A human uses their SAP ID; a location uses a fixed extension; a feature is a dialplan code, not an account.

---

## 2. Human user provisioning flow

```text
1. Pull/enter SAP ID
2. Create PJSIP extension = SAP ID (FreePBX Bulk Handler for batches)
3. Assign role → context/class of service
4. Generate strong random secret (≥ 12 chars)
5. Set display name → caller ID renders "Name - SAP ID"
6. Deliver credentials once, securely (portal / helpdesk / sealed sheet)
7. User registers SIP app on campus Wi-Fi
8. Account appears in directory; status → Active
```

**Provisioning record (per user):**

| Field | Value |
|---|---|
| SAP ID | |
| Name | |
| Role | student / staff / ert / ert_lead / control_room / admin |
| Context / COS | `ctx_*` |
| Secret delivered | one-time / reset |
| Max devices | students 2 · ERT/staff 3 |
| Status | Pending Setup → Active |

---

## 3. Fixed device provisioning flow

> **Hardware, Phase 1:** a fixed device is a **dedicated Android phone (Linphone)**
> logged in as its 4xxx extension — kept on charger, battery-optimization off. IP
> phones come later and inherit the **same extension** (no reconfig). The identity is
> the extension/role/location, not the hardware.

```text
1. Assign extension from 4000–4999
2. Set owner/location name (Location-Role-Extension)
3. Assign context (ctx_fixed_device or ctx_ert for ERT desks)
4. Generate strong random secret
5. Configure the device:
     Phase 1 → dedicated Android + Linphone (on charger, battery unrestricted)
     Later   → IP phone with the same extension + static IP
6. Lock permissions to required use only
7. Document physical location (mandatory)
8. Add to responder directory if relevant
```

**Fixed device record:**

| Field | Example |
|---|---|
| Extension | `4300` |
| Name | `Security-Control-4300` |
| Location | Security Control Room |
| Context | `ctx_fixed_device` |
| Allowed | Call 111, ERT/security, receive emergency calls |
| Owner | Security dept / role (not an individual) |
| Hardware | Phase 1: dedicated Android + Linphone → later: IP phone (same ext) |
| Static IP | recommended (IP phone); DHCP reservation for Android |
| Status | Active |

**Starter fixed set:** `4101` ERT Lead · `41xx` ERT desks · `4200` Medical · `4300` Security (+ warden/admin/IP speakers as the pilot area needs).

---

## 4. Caller-ID rules

| User type | Caller ID |
|---|---|
| Human | `Name - SAP ID` → `Rohan Batra - 500120597` |
| Fixed device | Location/role → `Medical Room`, `Security-Control-4300` |

Never allow blank/`Unknown`/`Phone 1` caller IDs — every call must be traceable.

---

## 5. Credentials

- **Unique** per account/device. Random, **≥ 12 chars**.
- Banned: `student123`, `sapid123`, `100100`, `password`, one shared password.
- Shared accounts only for controlled fixed devices.
- Delivered once (visible once or admin-resettable). Users change passwords only through the controlled reset flow — never by editing Asterisk directly.

---

## 6. Account lifecycle

`Pending Setup → Active → (Password Reset Required / Lost Device / Disabled) → Archived`

| State | Meaning |
|---|---|
| Pending Setup | Created, not yet registered |
| Active | Can register + use allowed features |
| Password Reset Required | Credential must rotate |
| Lost Device | Possibly compromised — revoke/reset now |
| Disabled | Cannot register or call |
| Archived | Inactive; **logs & identity history preserved** |

---

## 7. Revocation / lost device

```text
Disable extension → reset SIP secret → drop active registration →
block old credential → update status → preserve logs → document reason
```
Lost-device and abuse handling: reset immediately, force re-provision, log the event. Abusive accounts are suspended after review.

---

## 8. Bulk onboarding (FreePBX)

- **CSV import** via Bulk Handler: `extension(SAP ID), name, secret, context/COS, voicemail`.
- Validate + back up before import.
- Group by role; generate secrets in bulk; export a provisioning report.
- Phase 1 = manual/CSV; automation later.

---

## 9. Offboarding

- Student/staff leaves → **disable** account, remove role permissions, **keep logs/history**.
- SAP IDs are **never reused**. Fixed extensions reusable only after history archived.
- Monthly export of accounts, roles, fixed devices, and service codes for audit.

---

## 10. Directory mapping

Provisioning feeds the **UPES-ECS Emergency Responder Directory** and the general
user directory (kept separate). Supports caller-ID lookup, incident identity
mapping, emergency callback, and abuse investigation. Directory maintained by
UPES-ECS Admin / IT; reviewed monthly in pilot, quarterly once stable.
