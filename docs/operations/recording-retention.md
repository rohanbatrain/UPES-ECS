# UPES-ECS Emergency Recording & Retention Policy

Governs what is recorded, for how long, who can access it, and how it is protected.

> **Final legal retention period is TBD** — must be approved by UPES administration.
> The values here are the recommended defaults from the decision set.

---

## 1. What is recorded

| Flow | Recorded? |
|---|---|
| **111** emergency calls | ✅ Yes — from the instant 111 is dialed (before answer) |
| **199** drill calls | ✅ Yes — labelled `DRILL-ONLY` |
| **Conference 9000** (active real incident) | ✅ Yes |
| Side rooms 9001–9004 | ❌ No by default (enable only if the incident requires) |
| Emergency **voicemail** | ✅ Yes |
| **Paging** | Log always; record audio only for real emergency broadcast if technically simple |
| **Student-to-student / normal internal** | ❌ **Never** |
| Staff-to-staff / general calls | ❌ No |

Recording continues **through transfer/bridge** where technically possible, and **includes hold time**.

---

## 2. Caller notification

Callers are informed on emergency/drill flows:
> "You have reached UPES Emergency Response. Your emergency call may be recorded. Please stay on the line."

No recording notice on normal calls (they aren't recorded).

---

## 3. Retention

| Data | Default retention |
|---|---|
| Emergency call recordings | **90 days** |
| Emergency voicemail | **90 days** |
| Conference 9000 recordings | 90 days (per policy) |
| Incident logs / CDR / CEL | **1 year** |

- **Auto-delete after retention** unless the incident is **flagged for preservation**.
- Logs deliberately outlive audio.
- Deletion requires **ERT Lead + authorized university IT/admin** approval.

---

## 4. Access control

| Action | Allowed |
|---|---|
| **Listen** to recordings | ERT Lead · authorized Control Room Admin · approved university authority |
| **Download** recordings | Authorized Admin / ERT Lead **only** |
| Review emergency voicemail | ERT Lead / Control Room |
| Any access | **Logged** (who, when, which file) |

**Not allowed:** students, general staff, normal SIP users, unauthenticated users, non-emergency roles.

---

## 5. Storage & security

- Stored **locally** on university-controlled infrastructure (LAN-only). No cloud.
- **Encrypted at rest** (recordings, voicemail, and their backups).
- Recordings live in a controlled directory linked to incident IDs — never as loose unmanaged files.
- Included in encrypted backups under the same retention/security policy.

---

## 6. Naming & linkage

```text
ERT-YYYYMMDD-NNNN_CALLER-SAPID_YYYYMMDD-HHMMSS.wav
```
Every recording links to its **Incident ID** (see [12-Incident-Logging-Schema.md](12-Incident-Logging-Schema.md)), so audio, log, and voicemail share one identity.

---

## 7. Privacy principles

- Only emergency-relevant audio is captured — the system does **not** record the campus at large.
- Student privacy is protected by the default **no-recording** rule on normal calls.
- Access is least-privilege, logged, and time-limited by retention.

---

## 8. Items for UPES administration to confirm

- Final legal retention period (may extend beyond 90 days).
- Whether conference/paging audio is retained and for how long.
- Data-handling / privacy compliance sign-off.
- Preservation/legal-hold process for incidents under investigation.
