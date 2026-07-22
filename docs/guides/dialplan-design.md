# UPES-ECS Asterisk Dialplan Design

Reference dialplan for the custom logic that sits **alongside** FreePBX
(`extensions_custom.conf`). FreePBX generates the bulk of the config; this file
documents the emergency-specific routing so it is versioned and restorable.

> These snippets are a **design reference**, not copy-paste-final. Extension names,
> the exact backup roster, and prompt files are TBD until the role/location drill.

---

## 1. Context layout

```text
[ctx_student]        → 111, 199, 198, student/staff calling
[ctx_staff]          → same as student + staff-staff
[ctx_ert]            → the above + ERT dispatch, conferences, *45/*46
[ctx_ert_lead]       → the above + paging, 700, moderate 9000, escalation controls
[ctx_control_room]   → paging, monitoring, conferences
[ctx_fixed_device]   → device-scoped (e.g. speaker = receive paging only)
[ctx_admin]          → management

[ctx_emergency_111]  → shared emergency subroutine (included by all user contexts)
[ctx_ai_helpline]    → 102 offline panic-coach (auto-fallback from the queue; also direct-dial to test)
[ctx_111_fastpath]   → press-1 first-aid fast-path out of the emergency queue
[ctx_drill_199]      → drill subroutine
[ctx_paging]         → paging zones (included only by authorized contexts)
[ctx_conference]     → 9000-9004 (included only by authorized contexts)
```

Each user context `include`s only what its role may reach. **111 and 199 are included by every user context.**

---

## 2. Emergency hotline — 111

```asterisk
[ctx_emergency_111]
exten => 111,1,NoOp(EMERGENCY_111_CALL from ${CALLERID(num)})   ; 111 = primary published hotline
 same => n,Set(CDR(userfield)=EMERGENCY_111_CALL)
 same => n,Set(__INCIDENT_ID=ERT-${STRFTIME(${EPOCH},,%Y%m%d)}-${...seq...})
 same => n,Set(MIXMONITOR_FILENAME=${INCIDENT_ID}_${CALLERID(num)}_${STRFTIME(${EPOCH},,%Y%m%d-%H%M%S)}.wav)
 same => n,MixMonitor(${MIXMONITOR_FILENAME})            ; record WHOLE call (not ,b bridge-only — Feature 4 wants hold+VM captured)
 same => n,Playback(upes-ecs/emergency-preanswer)        ; "...may be recorded. Stay on the line."
 same => n,Queue(ert_emergency_queue,tc,,,20)            ; ring all available, 20s; caller may press 1 → ctx_111_fastpath (set 'context=ctx_111_fastpath' in queues.conf)
 same => n,Goto(ctx_ai_helpline,s,1)                     ; NO answer point free → coach immediately (no serial ring-out, no dead-air)
```

Key points: recording starts **before** answer; incident ID + filename set up front; a queued caller can **press 1** for immediate first-aid; on queue timeout the caller hands off **straight to the offline coach** (never a serial ring-out).

---

## 3. No responder → coach in parallel + background alert

When the queue times out with **no answer point free**, the caller is **never** put
through a serial ring-out and **never** left in silence. Two things happen **at once**:
the caller is coached immediately, and the humans are alerted in the background.

```asterisk
[ctx_ai_helpline]                                         ; 102 — offline panic-coach
exten => s,1,NoOp(Offline coach for ${INCIDENT_ID})
 same => n,System(/opt/upes-ecs/alert_responders.sh "${INCIDENT_ID}" "${CALLERID(num)}" &)
                                                          ; BACKGROUND call-files → Lead 4101 + backup (Security/Medical/Warden), "press 1 to join queue" — never holds the caller
 same => n,System(/opt/upes-ecs/missed_incident.sh "${INCIDENT_ID}" "${CALLERID(num)}" critical pending)
                                                          ; log Missed Emergency Incident at once (Critical, Pending Review)
 same => n(menu),Background(upes-ecs/coach-menu)          ; deterministic first-aid tree: CPR/bleeding/choking/fire/lockdown/recovery/trapped
 same => n,WaitExten(600)
 same => n,Goto(menu)
exten => 9,1,Goto(ctx_emergency_111,111,7)               ; 9 = retry a responder → re-enter the queue (bridge whoever is now free)
exten => 8,1,Goto(ctx_emergency_vm,s,1)                  ; 8 = leave a message → emergency voicemail
exten => 102,1,Goto(s,1)                                 ; direct-dial 102 to TEST the coach (dial-102-to-test)

[ctx_111_fastpath]                                        ; press-1 fast-path OUT of the queue
exten => 1,1,NoOp(Fast-path first-aid for ${INCIDENT_ID})
 same => n,Goto(ctx_ai_helpline,s,menu)                  ; jump straight to first-aid without waiting the queue out
```

- **Coach in parallel, not serial.** Alerting humans (call-files) and coaching the caller
  run **simultaneously** — the caller is guided while the responder phones ring.
- **100% offline.** No internet, no AI service; coach prompts are pre-generated with an
  offline TTS (`gen-coach-prompts.sh`). `102` also auto-falls-back here and can be
  **dialled directly to test**.
- Inside the coach: **9 = retry a responder**, **8 = leave a message**. Nothing dead-ends.

---

## 4. Emergency voicemail (reached via coach "8 = message")

```asterisk
[ctx_emergency_vm]
exten => s,1,NoOp(Voicemail for ${INCIDENT_ID})
 same => n,Playback(upes-ecs/emergency-voicemail-prompt)
 same => n,Set(VM_MESSAGE_MAX=60)
 same => n,VoiceMail(emergency@upes-ecs,u)               ; unavailable msg, 60s max
 same => n,System(/opt/upes-ecs/missed_incident.sh "${INCIDENT_ID}" "${CALLERID(num)}" critical pending voicemail)
 same => n,Hangup()
```

The **Missed Emergency Incident** (severity Critical, Pending Review) is created the moment
the queue misses — at coach entry (§3), not here — so a human calls back **regardless of
whether the caller leaves a message**. Reaching voicemail via **8** just attaches the
recording to that same incident. Silent voicemail is still saved and marked Pending Review;
an early hangup still leaves the missed record (no voicemail).

---

## 5. Drill line — 199

```asterisk
[ctx_drill_199]
exten => 199,1,NoOp(DRILL-ONLY test call)
 same => n,Set(CDR(accountcode)=DRILL-ONLY)
 same => n,Set(MIXMONITOR_FILENAME=DRILL_${CALLERID(num)}_${STRFTIME(${EPOCH},,%Y%m%d-%H%M%S)}.wav)
 same => n,MixMonitor(${MIXMONITOR_FILENAME})
 same => n,Playback(upes-ecs/drill-prompt)               ; "This is a UPES-ECS drill call..."
 same => n,Dial(PJSIP/ert-test-target,20)                ; test target, NO real escalation
 same => n,Hangup()
```

199 never triggers real dispatch, escalation, or a real incident.

---

## 6. Paging — 700–799 (authorized contexts only)

```asterisk
[ctx_paging]
; 700 all-campus requires PIN
exten => 700,1,GotoIf($["${CONTEXT_ALLOWS_ALLCALL}"="1"]?ok:deny)
 same => n(ok),Authenticate(${PAGING_PIN_700})
 same => n,Set(CDR(userfield)=PAGING_700_ALLCAMPUS)
 same => n,Page(${ALLCAMPUS_SPEAKERS},d)                 ; live announce to speakers
 same => n,Hangup()
 same => n(deny),Playback(upes-ecs/not-authorized)
 same => n,System(/opt/upes-ecs/log_access_denied.sh "${CALLERID(num)}" PAGING_700)
 same => n,Hangup()

exten => 701,1,...(Academic)   exten => 702,...(Hostels)   exten => 703,...(Security)
exten => 704,...(Medical/ERT)  exten => 705,...(Admin/Ops)
```

Only `ctx_ert_lead` / `ctx_control_room` (zone-appropriate) `include => ctx_paging`.
Every attempt — allowed **and** denied — is logged as `Emergency Paging Attempt`.

---

## 7. Conference rooms — 9000–9004

```asterisk
[ctx_conference]
exten => 9000,1,NoOp(Main Incident Command Room)
 same => n,Set(CONFBRIDGE(bridge,record_conference)=yes)  ; 9000 recorded when active
 same => n,ConfBridge(9000,upes_incident_bridge,upes_user,${PIN_9000})
exten => 9001,1,ConfBridge(9001,upes_side_bridge,...)     ; side rooms, not recorded by default
; 9002 Medical, 9003 Warden, 9004 Operations
```

Only emergency-role contexts `include => ctx_conference`. PIN on all rooms.
Join/leave logged as `Incident Conference Logs`. Limits: 9000 → 20, side → 10.

---

## 8. Shift login & pause / resume — *22 / *23 and *45 / *46

```asterisk
; in ctx_ert / ctx_ert_lead
; --- shift login: JOIN / LEAVE the ERT emergency queue (membership) ---
exten => *22,1,AddQueueMember(ert_emergency_queue,PJSIP/${CALLERID(num)})    ; go ON shift — join the queue
 same => n,Playback(upes-ecs/shift-on)
exten => *23,1,RemoveQueueMember(ert_emergency_queue,PJSIP/${CALLERID(num)}) ; go OFF shift — leave the queue
 same => n,Playback(upes-ecs/shift-off)

; --- pause / resume: temporary, WITHOUT leaving the queue ---
exten => *45,1,QueuePause(ert_emergency_queue,PJSIP/${CALLERID(num)})
 same => n,Playback(upes-ecs/queue-paused)
exten => *46,1,QueueUnpause(ert_emergency_queue,PJSIP/${CALLERID(num)})
 same => n,Playback(upes-ecs/queue-resumed)
```

- **`*22` / `*23` = shift login** — join / leave the ERT emergency queue at shift start / end.
- **`*45` / `*46` = pause / resume** — a brief step-away while **remaining** a queue member.
- Pause affects **queue** calls only. ERT Lead can pause / remove others via AMI/admin action.

---

## 9. Student / internal calling

```asterisk
[ctx_student]
include => ctx_emergency_111        ; 111 always reachable
include => ctx_drill_199            ; 199 test
exten => 198,1,Echo()               ; audio test
; SAP-ID to SAP-ID (5xxxxxxxx pattern) — normal call, NOT recorded
exten => _5XXXXXXXX,1,Dial(PJSIP/${EXTEN},30)
; explicitly NO include of ctx_paging / ctx_conference
```

Student-to-student calls carry ordinary CDR metadata only — no recording, no incident.

---

## 10. Access-denied logging

Any restricted number reached from a context that doesn't allow it →
`Playback(not-authorized)` + `log_access_denied.sh` → **Access Denied Event**
(feeds Health Monitoring, Feature 16).

---

## 11. Emergency priority

- 111 is included in every context and **bypasses** normal dial restrictions.
- Keep ERT/emergency channels separate from bulk student calling; apply per-user
  call limits if capacity testing shows normal traffic degrading the queue.
- Network QoS (DSCP/EF for RTP) added later if the switch/AP support it.

---

## 12. Files this design touches (for backup)

`extensions_custom.conf` · `extensions_aihelpline.conf` (102 offline coach) · `pjsip.conf` (FreePBX-managed + custom) · `queues.conf` ·
`confbridge.conf` · `voicemail.conf` · `features.conf` · custom prompts under
`upes-ecs/` · helper scripts in `/opt/upes-ecs/`. All go in the `upes-ecs-config`
git repo — see [11-Backup-Restore-Procedure.md](backup-restore.md).
