# UPES-ECS Backup & Restore Procedure

**Model:** local-first. No cloud dependency. Sensitive data encrypted.
**Names:** snapshots `ECS Snapshot YYYYMMDD-HHMM` · export `upes-ecs-export-YYYYMMDD.zip` · git repo `upes-ecs-config` · restore doc **UPES-ECS Restore Checklist**.

> A backup you have never restored is not a backup. Test restore quarterly (monthly during pilot).

---

## 1. What gets backed up

| Category | Includes |
|---|---|
| **Asterisk config** | `pjsip.conf`, `extensions.conf` + `extensions_custom.conf`, `queues.conf`, `voicemail.conf`, `confbridge.conf`, `features.conf`, `rtp.conf`, custom `logger.conf`/`modules.conf` |
| **Identity** | SAP-ID ↔ extension mappings, display names, roles/contexts, fixed-device mappings, caller-ID names, account status |
| **Emergency dialplan** | 111, 199, queue routing, escalation, voicemail fallback, 700–799 paging, 9000–9004 conferences, transfer rules |
| **Queue config** | members, strategy, timeouts, announcements, pause behaviour |
| **Prompts** | voicemail, hold, drill, paging-test, any pre-recorded messages |
| **Recordings/voicemail** | emergency recordings + voicemails (retention policy) |
| **Logs/metadata** | CDR, CEL, queue, paging, conference, missed-emergency, access-denied, registration, health logs |
| **Health config** | check scripts, thresholds, critical-device list, dashboard config |
| **Docs** | SOP + drill docs |

---

## 2. Backup types & schedule

| Type | When | Contents |
|---|---|---|
| **Pre-change** *(mandatory)* | Before **any** production change | Full config snapshot |
| **Daily config** | Every day | Config + SIP account data + SAP mappings + fixed mappings + dialplan + queues + voicemail config + prompts |
| **Weekly export** | Weekly | Responder directory, device list, role/context map, extension ownership, health config, relevant logs → `upes-ecs-export-YYYYMMDD.zip` |
| **Policy recordings** | Per policy | Emergency recordings + voicemails (encrypted) under retention |

**Pre-change is mandatory** for any change to: 111 routing, ERT queue, SIP accounts, contexts, paging codes, conference rooms, voicemail, recording paths, access control.

```text
Backup first → apply change → test (199/111) → rollback to snapshot if broken.
```

---

## 3. Retention of backups

- **Config:** keep **30 daily** + **12 weekly** snapshots (auto-rotate).
- **Logs:** **1 year.**
- **Recordings/voicemail:** **90 days** unless flagged for preservation.

---

## 4. Storage layout (local-first)

```text
Primary:   backup directory on the PBX server (separate disk if possible) or local NAS
Secondary: separate LAN machine / NAS
Offline:   encrypted USB copy, physically locked, held by authorized admin
```

No cloud required.

---

## 5. Security

Backups can contain SIP credentials, SAP-ID identity data, recordings, and logs — treat as sensitive.

- **Access:** IT Admin + approved UPES-ECS owner only. Not students/staff/normal ERT.
- **Encryption:** config-only backups = restricted access; credential/recording backups = **restricted access + encrypted**.
- Credentials stored as secrets/hashes, **never plain text** in docs.
- **Backup access is logged.** Offline media physically locked.
- Deletion requires **IT Admin + university authority / ERT Lead** approval.

---

## 6. Versioning (git)

Keep `extensions_custom.conf` and all custom config in the LAN-local git repo **`upes-ecs-config`** with change notes and rollback tags:

```text
v1.0  Initial 111 emergency hotline
v1.1  Added ERT queue
v1.2  Added fallback escalation
v1.3  Added paging restrictions
v1.4  Added SAP-ID user accounts
```

**Change control** — every production change records: what / who / when / why / backup taken / test result / rollback plan.

FreePBX's own **Backup & Restore module** covers the GUI-managed config; the git repo covers custom dialplan + scripts. Use both.

---

## 7. Restore

**Who:** IT Admin + approved UPES-ECS owner. **Target time:** config-only restore **under 1 hour**.

**Restore order:**
```text
1. OS / network (static IP, hostname)
2. Asterisk/FreePBX config
3. SIP accounts + SAP-ID mappings
4. Dialplan + queues
5. Prompts + voicemail
6. Logs / recordings (as needed, encrypted)
```

**Verification checklist (UPES-ECS Restore Checklist):**
- [ ] Service running
- [ ] SIP users register
- [ ] Student-to-student calling works
- [ ] **199** test passes, then **111** reaches the queue
- [ ] Recording works · [ ] Voicemail works · [ ] Queue works
- [ ] Fixed phones (4200/4300) register
- [ ] Unauthorized paging blocked · [ ] Unauthorized 9000 blocked
- [ ] Health monitoring reports correctly · [ ] Backup status current

Sign-off: **IT Admin + ERT Lead.**

---

## 8. Failure handling

- **Backup fails** → **Critical** alert; fix before any config change or go-live.
- **Restore fails** → escalate to IT lead; use the previous snapshot or the manual rebuild plan.

---

## 9. Test cadence

- Restore test **after every major change**.
- Full restore drill: **quarterly** (monthly during pilot).
- SAP-ID ownership history must be preserved through any restore so call logs and identities stay accurate.
