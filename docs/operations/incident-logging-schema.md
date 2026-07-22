# UPES-ECS Incident Logging Schema

Defines the structured record created for every emergency call. Asterisk produces
the raw telephony events (CDR/CEL/queue/AMI); this schema is the **readable
incident record** the ERT works from.

```text
Asterisk → CDR / CEL / Queue logs / AMI/ARI → Incident store → Dashboard
```

---

## 1. IDs & formats

| Field | Format | Example |
|---|---|---|
| Incident ID | `ERT-YYYYMMDD-NNNN` | `ERT-20260704-0001` |
| Recording file | `ERT-YYYYMMDD-NNNN_CALLER-SAPID_YYYYMMDD-HHMMSS.wav` | `ERT-20260704-0001_500120597_20260704-143210.wav` |
| Call log label | `EMERGENCY_111_CALL` (or `DRILL-ONLY` for 199) | |

**Every 111 call creates an incident** — including false alarms (closed as such).

---

## 2. Incident record fields

| Field | Notes |
|---|---|
| `incident_id` | `ERT-YYYYMMDD-NNNN` |
| `source_number` | 111 / 101 / 199 |
| `datetime` | Call start |
| `caller_sap_id` | From extension |
| `caller_name` | From directory |
| `caller_extension` | SAP ID or fixed ext |
| `caller_device_ip` | Registered device/IP |
| `caller_role` | student / staff / ert / fixed |
| `caller_location` | Fixed-device location, or as stated by caller |
| `category` | Medical / Security / Fire-Smoke / Accident-Injury / Violence-Threat / Infrastructure / Hostel-Warden / Other |
| `answered_by` | ERT responder identity |
| `queue_wait` | Seconds in queue |
| `answer_time` | Time answered |
| `escalation_attempts` | Lead / backup attempt statuses |
| `dispatch_mode` | none / dispatch-without-transfer / warm-transfer / three-way-bridge |
| `dispatch_target` | Extension/team |
| `handoff_status` | Pending / Accepted / Failed / Completed / Escalated |
| `transfer_bridge_actions` | Timeline of transfer/bridge events |
| `incident_owner` | ERT member who answered (until reassigned) |
| `recording_path` | Link to WAV |
| `voicemail_ref` | Same incident ID if applicable |
| `final_status` | see §4 |
| `severity` | Critical for missed; else operator-set |
| `notes` | ERT Operator initial, ERT Lead final |
| `ai_fields` | (101 only) see §5 |

**Mandatory before closure:** incident_id, datetime, caller SAP-ID + name, caller device/IP, caller role, answered_by, queue_wait, answer_time, escalation_attempts, transfer/bridge actions, **final_status**, notes, recording_path.

---

## 3. Missed Emergency Incident (extra fields)

Created when 111 is unanswered after escalation (or caller hangs up early).

| Field | Value |
|---|---|
| `severity` | **Critical** (default) |
| `review_status` | **Pending Review** (default) |
| `voicemail_ref` | recording, or "none — early hangup" |
| `queue_attempt` / `escalation_attempt` | statuses |
| `callback_attempts` | logged; mandatory when caller known |
| `grouping_key` | group repeats by **SAP ID + time window** |

Appears in the **Missed Emergency Review Queue**. **Never auto-closes.** Review within 5 minutes during active hours.

---

## 4. Status values

**Incident final status:** `Answered · Escalated · Missed · Active Incident · Closed as False Alarm · Closed as Duplicate · Closed`

**Missed review status:** `Pending Review · Reviewed · Callback Attempted · Converted to Active Incident · Closed as Duplicate · Closed as False Alarm`

**Handoff status:** `Pending · Accepted · Failed · Completed · Escalated`

---

## 5. AI-assisted (101) additional fields

```text
source_number = 101      ai_triage_enabled = true
ai_detected_location     ai_detected_category     ai_urgency_hint
ai_summary               ai_questions_completed
transferred_to_111 (t/f) transfer_time            human_responder_answered (t/f)
human_override (t/f)
```

The AI summary is a **pre-brief only** — editable/correctable by ERT. AI can never close an incident.

---

## 6. Who can edit / close

| Action | Who |
|---|---|
| Write initial notes | ERT Operator |
| Edit notes / dispatch entries | ERT Lead / authorized Admin |
| **Close incident** | **ERT Lead / authorized Duty Officer only** |
| View recording | ERT Lead / authorized Control Room Admin / approved authority |
| Download recording | Authorized Admin / ERT Lead only |

All recording/voicemail access is itself logged.

---

## 7. Retention

Incident logs & CDR/CEL: **1 year.** Recordings/voicemail: **90 days** (unless flagged for preservation). Logs are kept **longer than the audio** on purpose.

---

## 8. Separation rule

Normal internal / student-to-student calls stay as **ordinary CDR metadata** — they
do **not** become incidents and are **not** recorded. Only 111/101/199 flows create
incident records. This keeps the emergency record clean and protects privacy.
