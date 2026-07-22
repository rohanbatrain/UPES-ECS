# UPES-ECS Local System Health Monitoring

**Dashboard name:** UPES-ECS Health Dashboard · **Statuses:** OK · Warning · Critical · Offline
**Scope:** LAN-only. No cloud monitoring, no SMS/WhatsApp/email alerts.

> Asterisk *running* is not enough — the queue, recording, voicemail, or mobile
> calling can be broken while the service is up. Check the whole path.

---

## What to monitor

| # | Check | Healthy | Critical |
|---|---|---|---|
| 1 | Asterisk / FreePBX service | Running | Down = whole system down |
| 2 | SIP registrations (ERT, Lead, Security, Medical, fixed, pilot users) | Required ones online | ERT/fixed devices offline |
| 3 | ERT queue | **≥ 2 available** | 0 available responders |
| 4 | 111 test flow (via 199 routinely) | Passes | 111 doesn't route / no answer path |
| 5 | Emergency recording | Test call produced a file | 111 completes but recording fails |
| 6 | Emergency voicemail | Can record + retrieve | Cannot record |
| 7 | Local storage | < 75% used | ≥ 90% used |
| 8 | Network reachability (Wi-Fi/LAN → PBX) | SIP + 2-way RTP OK | One-way / no audio |
| 9 | Mobile Wi-Fi SIP | Register + call + audio | Clients can't register over Wi-Fi |
| 10 | Fixed/critical devices | Registered | ERT answering device offline |
| 11 | Paging (if enabled) | Authorized works, unauth blocked | Authorization broken |
| 12 | Conference 9000 | Authorized joins, unauth blocked | Unauth can join |
| 13 | Access-control events | Denials logged | Restricted features reachable by wrong role |

---

## Thresholds (from decisions)

| Metric | Warning | Critical |
|---|---|---|
| Disk usage | 75% | 90% |
| Available ERT agents | < 3 | < 2 |
| Queue wait before escalation | — | > 20s unhandled |
| Packet loss during calls | > 1% | > 3–5% |
| Call setup time (internal) | > 5s | — |
| Failed registrations | repeated from same account/IP | ERT/fixed device fails |
| Recording failure | — | any 111 recording fails |
| 111 test failure | — | **do not go live** |

---

## Daily ECS Readiness Check

Owner: IT/Admin duty person or ERT control-room assignee. (Same list as the [Drill SOP](drill-test-sop.md).)

- [ ] Service running · [ ] Queue ≥ 2 available · [ ] ERT device registered
- [ ] 199 test call OK · [ ] Recording OK · [ ] Voicemail OK
- [ ] Storage not full · [ ] Medical 4200 + Security 4300 registered · [ ] Mobile Wi-Fi test OK

Log as **Daily ECS Readiness Check**.

---

## Weekly ECS Drill Health Report

Run the weekly drill scenario ([Drill SOP §5](drill-test-sop.md)) and record pass/fail + any offline devices, call-quality issues, and access-control results.

---

## System health verdicts

- **Unhealthy (do not rely / do not go live):** PBX down · queue unavailable · zero ERT devices · recording path failed · 111 test failed.
- **Degraded:** low ERT count · high failed registrations · high packet loss · one critical fixed phone offline.
- **Ready:** PBX running · required registrations online · 111/199 test passes · recording + voicemail OK · backup recent.

---

## Implementation (Phase 1 → later)

- **Phase 1 (MVP):** Asterisk CLI checks (`pjsip show registrations`, `queue show ert_emergency_queue`), local shell scripts, `df -h` for disk, a manual readiness checklist. **CLI/script is acceptable for MVP.**
- **Later:** a LAN-only **UPES-ECS Health Dashboard** page (example view below), still no external alerting.

```text
UPES-ECS Health Dashboard
Asterisk: OK        Emergency 111: OK       ERT Queue: 3 available, 1 busy, 0 waiting
Recording: OK       Voicemail: OK           Storage: 42% used
Medical 4200: OK    Security 4300: Offline  Paging: OK    Conf 9000: OK
Last Test Call: Passed 10:32
```

Dashboard is **LAN-only** — no public access, no cloud, no external alerts.

---

## Who can view

ERT Lead · Control Room · IT Admin. Not students, not general staff.
