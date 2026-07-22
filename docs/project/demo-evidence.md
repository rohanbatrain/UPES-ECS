# UPES-ECS Feature Demonstration Evidence

Live verification, on the running QEMU PBX, of the features that were designed and in
the dialplan but not yet demonstrated. Run 2026-07-04. Complements the informal pilot;
feeds [SOP 32 Test-Evidence](../SOP/32-Test-Evidence-Sheet.md).

| Feature | Test | Result | Evidence |
|---|---|---|---|
| **F18 Backup & Restore** | Snapshot `/etc/asterisk` + scripts + state; verify integrity; test-restore and diff vs live | ✅ **PASS** | `ecs-snapshot-…tar.gz` (190 KB), integrity OK, **restored dialplan matched live** |
| **F13 Security hardening** | Install + enable fail2ban with an Asterisk jail | ✅ **PASS** | `fail2ban active`; jails = `asterisk, sshd`; anonymous SIP = 0; SIP bound LAN-only |
| **F9 Responder pause/resume** | Pause then resume a queue member (`*45`/`*46`) | ✅ **PASS** | `paused interface PJSIP/500000003` → state `paused` → unpaused; `*45`/`*46` present in `ctx_queue_control` |
| **F6 Paging access control** | Can a student reach `700`? Can ERT-Lead? | ✅ **PASS** | student → `700` **DENIED**; ERT-Lead → `700` **REACHABLE** |
| **F7 Conference rooms** | ConfBridge profiles load; `9000` routes to ConfBridge | ✅ **PASS (config)** | profiles `upes_incident_bridge`, `upes_side_bridge` loaded; `9000 → ConfBridge` confirmed |
| **F11 Transfer / 3-way dispatch** | Warm transfer + three-way bridge | ⏳ **Needs phones** | Capability present; a full demo requires a live 3-party call (interactive — not auto-testable) |

---

## Notes

- **F18** — this was a real *restore* test, not just a backup: a file was extracted from
  the archive and diffed against the live config (matched). Backup process per
  [SOP 11](../SOP/11-Backup-Restore-Procedure.md); the snapshot lives at
  `/var/backups/upes-ecs/` on the VM.
- **F13** — fail2ban jail config persisted to
  [../deploy/asterisk/fail2ban-asterisk.conf](../deploy/asterisk/fail2ban-asterisk.conf).
  Full hardening plan (TLS/SRTP, firewall, module lockdown) is [SOP 26](../SOP/26-Security-Hardening.md);
  TLS/SRTP remains a production step.
- **F7** — ConfBridge profiles persisted to
  [../deploy/asterisk/confbridge.conf](../deploy/asterisk/confbridge.conf) and threaded
  into the VM build. The room is live and reachable; a multi-party audio demo is best
  done with real phones dialing `9000` (same as F11).
- **F11** — the only item that is inherently interactive. To demo: Rohan calls Student Example Three,
  Student Example Three does an attended transfer / adds a third phone (three-way). Happy to run it live.

## Still open (from [Project-Status.md](Project-Status.md))
Online AI-`101` build (local-first) · production move to the van's Linux box / bridged ·
TLS/SRTP · formal pilot sign-off.

> The `100`-vs-police number question is **resolved**: the sole emergency number is now
> **`111`** (the old `100` is deprecated and fully removed), retiring the
> police-number/OS-interception collision.
