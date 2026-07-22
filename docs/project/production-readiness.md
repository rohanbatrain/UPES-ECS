# UPES-ECS — Production Readiness & Go-Live

**Last updated:** 2026-07-05

This is the authoritative "is it ready for a real deployment?" checklist. It records what is
**hardened and verified**, what is **automated into the build**, and the few **decisions only
you (the site owner) can make** before go-live.

---

## 1. What is production-ready now (verified)

| Area | State | Evidence |
|---|---|---|
| Emergency line **111** | Answers, records, queues, escalates, coaches, voicemails | dialplan loads clean; call-flow tested |
| **102 offline panic-coach** | Live — deterministic first-aid, zero internet | 15 prompts, all branches resolve |
| Press-1 fast-path + parallel coaching | Live | queue breakout + background responder alert |
| Answer-point staffing | On-shift via `*22`/`*23` + `ert-shift.sh`, logged | shift log verified |
| **Crash auto-recovery** | `systemd Restart=always` — asterisk restarts in ~3s if it dies | killed `-9`, self-healed |
| **Auto-start on boot** | VM + Console launch at Windows logon (no admin) | Startup-folder launchers installed |
| **Nightly backups** | 02:00 cron → `/var/backups/upes-ecs/*.tgz`, keep 14 | backup ran, archive present |
| Health + retention | 5-min healthcheck, 03:30 retention cleanup | cron.d/upes-ecs |
| **Security** | fail2ban active (asterisk + sshd jails); no anonymous/guest SIP; key-only SSH | audited |
| **Secrets** | Real per-user/position SIP secrets; real paging PIN; not web-served | `secrets/`, 404 verified |
| Accounts | 19 endpoints (7 people + 12 positions) load | `pjsip show endpoints` |
| Dynamic-across-routers | Console server-IP auto-updates as the van moves | `status.json.serverIp` |

All of the above is **persisted into the build** (`deploy/qemu/build-vm.ps1` + `seed/setup-in-vm.sh`),
so a fresh `build-vm.ps1` reproduces a hardened server — configs, accounts, scripts, prompts,
crash-recovery, crons, and a freshly-generated paging PIN.

---

## 2. Go-live checklist

**Done (automated/verified):**
- [x] Dialplan + accounts load with no errors
- [x] 111 → queue → escalation/alert → offline coach → voicemail path proven
- [x] Crash auto-recovery (systemd) + boot auto-start (VM + Console)
- [x] Nightly backup + retention + health crons
- [x] fail2ban, no guest SIP, real secrets, real paging PIN
- [x] Every team/person has a real credential (`secrets/TEAM-CREDENTIALS.md`)

**Before you flip it on at a real site (your action):**
- [ ] **Deliver credentials** to each person/desk over a secure channel; register their handset
- [ ] **Assign people to teams/positions** (Medical/Security/Warden/Ops/IT) — table in `secrets/TEAM-CREDENTIALS.md`
- [ ] **Staff the ERT queue** for each shift (`*22`) so 111 is answered (wallboard shows READY)
- [ ] **Set the real escalation roster** — `UPES_LEAD` / `UPES_BACKUP` globals to the actual Lead/backup extensions
- [ ] **Rotate the paging PIN** and re-deliver (`PAGING_PIN_700`)
- [ ] **Battery/Wi-Fi**: disable battery optimisation + background limits on every responder handset (see field guide)
- [ ] **Physical drill**: run a `199` drill, then a supervised `111` end-to-end, per SOP 03/17
- [ ] **Backups off-box**: copy `/var/backups/upes-ecs/` to external media on a schedule

---

## 3. Decisions that change the build (need site input)

| Decision | Default today | Production option |
|---|---|---|
| **SIP transport** | UDP, unencrypted (fine on an isolated LAN) | TLS + SRTP if the LAN isn't trusted — needs certs on PBX + phones |
| **Handsets** | Android softphones (Linphone) | Dedicated IP desk phones per position (BLF, speed-dial) |
| **101 online AI** | Not deployed (design only) | **Local-first** stack (Ollama/llama.cpp + Whisper + Piper) on a **dedicated GPU host** — the TCG van VM can't run it in real time (see `AI-101/`) |
| **Paging speakers** | None (`ALLCAMPUS_SPEAKERS` placeholder) | Real IP speakers wired to 700-series zones |
| **Second PBX / HA** | Single node | Standby PBX + failover if a single van node isn't enough |
| **`live_dangerously=yes`** | On (required for incident-ID `SHELL()` + `System()` alerts) | Accepted, contained: the dialplan is version-controlled and not user-editable |

---

## 4. Operations quick-reference

```text
Start VM ............ qemu\start-vm.ps1            (auto at logon)
Stop VM ............. qemu\stop-vm.ps1
Console ............. Console\Serve.ps1            (auto at logon; http://localhost:8080)
Set van LAN IP ...... qemu\Set-UpesLanIp.ps1
Auto-start on/off ... deploy\qemu\Register-Autostart.ps1  [-Remove]

On the PBX (ssh -p 2222):
  Staff a position .. /opt/upes-ecs/ert-shift.sh on|off|status <ext>
  Backup now ........ sudo /opt/upes-ecs/upes-ecs-backup.sh
  Restore ........... stop asterisk; tar xzf <backup>.tgz -C / ; start asterisk
  Health ............ cat /var/lib/upes-ecs/health.txt
  Recover asterisk .. automatic (systemd Restart=always); manual: systemctl restart asterisk
```

Full call-flow: [../Blueprint/03-Call-Flows.md](../Blueprint/03-Call-Flows.md) ·
Runbook: [../deploy/qemu/README.md](../deploy/qemu/README.md) ·
AI layer: [../AI-101/README.md](../AI-101/README.md)
