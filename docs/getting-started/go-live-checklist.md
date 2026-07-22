# UPES-ECS Go-Live Checklist

Final gate before UPES-ECS is declared production-ready. Nothing here is optional.

---

## 1. Minimum feature set live

- [ ] SIP registration (mobile over Wi-Fi + fixed devices)
- [ ] SAP-ID → SAP-ID internal calling
- [ ] **111** → ERT queue → offline coach (102) fallback with background Lead/backup alert → voicemail catch
- [ ] ERT answering (min 2, recommended 3+ available)
- [ ] Emergency recording + incident logging
- [ ] Basic logs (CDR/CEL/queue)
- [ ] Fixed ERT / Security `4300` / Medical `4200` devices (if teams in pilot)
- [ ] Health check (script/CLI at minimum)
- [ ] Backup + tested restore
- [ ] **199** drill mode safe

---

## 2. Fully tested (from Pilot Test Plan)

- [ ] 111 · 199 · queue · press-1 first-aid · offline coach (102) fallback · voicemail · recording
- [ ] Access restrictions (paging/conference/recording denied to students)
- [ ] Fixed devices register with correct caller ID
- [ ] Backup/restore config test passed
- [ ] All 19 functional tests **passed**

---

## 3. Infrastructure confirmed (collect from UPES IT)

- [ ] Static server IP / subnet / gateway set
- [ ] `pbx.upes.lan` / `sip.upes.lan` resolve (or IP fallback documented)
- [ ] Campus Wi-Fi SSID confirmed
- [ ] Client isolation checked (SIP/RTP to PBX allowed)
- [ ] Allowed subnets set; guest Wi-Fi blocked; management subnet separated
- [ ] Router/switch/AP models recorded; capacity acceptable

---

## 4. People & process ready

- [ ] Final ERT roster set; queue membership configured
- [ ] ERT trained on the [ERT SOP](02-ERT-SOP.md); completed a drill
- [ ] Control-room/daily-readiness owner assigned
- [ ] Support/helpdesk runbook in place
- [ ] Student + ERT setup guides distributed
- [ ] "Campus Emergency: Dial 111 on UPES-ECS" posters ready

---

## 5. Policy & approvals

- [ ] Recording-retention policy approved by UPES administration
- [ ] Access-control matrix approved
- [ ] Paging-approval authority (ERT Lead / Incident Commander) confirmed
- [ ] Backup encryption + access policy in place
- [ ] Go-live approved by **UPES administration + ERT Lead + IT owner**

---

## 6. Phase-1 success criteria — all must pass

Mobile SIP registration over Wi-Fi · SAP-ID → SAP-ID calling · any user calls 111 ·
111 reaches queue · press-1 first-aid works · offline coach (102) fallback with background Lead/backup alert works · voicemail catch works · recording works · student
calls not recorded · paging restricted · conference restricted · dispatch/bridge
works · health checks pass · backup/restore passes · drill mode safe · SOP understood.

---

## 7. Rollback triggers (abort go-live / revert)

- 111 fails to route
- Queue unavailable / zero available ERT
- Recording fails
- PBX unstable
- Wi-Fi can't carry calls
- Unauthorized-access risk detected

If any trigger fires: **do not go live** (or roll back to the last good snapshot), fix, re-test, re-approve.

---

## 8. Day-1 operations

- [ ] Daily ECS Readiness Check scheduled + owner assigned
- [ ] Weekly drill health report scheduled
- [ ] Monthly directory/device review scheduled
- [ ] Quarterly (monthly in early pilot) restore test scheduled
- [ ] Incident/missed-call review discipline active (5-min review during active hours)

---

## Sign-off

| Role | Name | Date |
|---|---|---|
| IT / UPES-ECS Admin | | |
| ERT Lead / Incident Commander | | |
| UPES Administration | | |

**Go-live date: ____________ (set only after all boxes checked).**
