# UPES-ECS Day-1 Quickstart

The shortest path from bare server to a working **Dial 111**. Condensed critical path —
each step links to the full doc. Do them in order; test after each block.

> Goal of Day 1: prove **dial 111 → an ERT Android rings → call is recorded**, plus 199 drill.
> That's the Phase-1 milestone. Everything else layers on later.

---

## Before you start — collect these

- [ ] Server (mini-PC/van PBX) with **Ubuntu Server LTS / Debian** + a **static IP**
- [ ] Router, switch, access point powered; **Wi-Fi client isolation OFF** (or voice VLAN)
- [ ] 3–4 **dedicated Android phones** (ERT answer points) + chargers
- [ ] A couple of test phones for "callers"
- [ ] The confirmed roster (Notes/Confirmed Details.md)

---

## Block A — Server & FreePBX  ([SOP 08 §0](../guides/freepbx-build.md))

1. Install FreePBX (distro or on Asterisk 18+/20+); apply module updates.
2. Set static IP; resolve `pbx.upes.lan` / `sip.upes.lan` (or note the IP).
3. Asterisk SIP Settings → **PJSIP**, LAN interface only; **Allow Anonymous = No**, **SIP Guests = No**.
4. From the repo root on the server: `sudo ./setup.sh`

**Test:** create two temp extensions, register two Androids on Wi-Fi, call each other + dial **198** (echo).

---

## Block B — Emergency core  ([SOP 08 §1](../guides/freepbx-build.md), [config/](https://github.com/rohanbatrain/UPES-ECS/blob/main/config/))

1. Merge `config/extensions_custom.conf` into `/etc/asterisk/`, then `dialplan reload`.
2. Record the prompts into `/var/lib/asterisk/sounds/en/upes-ecs/`  ([SOP 28](../reference/voice-prompt-scripts.md)).
3. **Queue:** create `ert_emergency_queue` — ringall, 20s, skip-busy, no MoH.
4. **Fixed answer points:** import [fixed-devices.csv](https://github.com/rohanbatrain/UPES-ECS/blob/main/provisioning/fixed-devices.csv) → put Linphone on the dedicated Androids as `4101` (ERT Lead), `4200` (Medical), `4300` (Security). Keep them **on charger, battery-unrestricted** ([SOP 24](../reference/mobile-app-reliability.md)).
5. Add those ERT devices as queue agents.
6. **Route 111 + 199** (FreePBX Custom Destinations) → `ctx_emergency_111` / `ctx_drill_199`.

**Test:** dial **199** (drill, no real dispatch) → then **111** → an ERT Android rings → answer → confirm a recording file appears under `/var/spool/asterisk/monitor/upes-ecs/`.

---

## Block C — Users & access  ([SOP 04](../reference/sip-account-role-matrix.md), [provisioning/](https://github.com/rohanbatrain/UPES-ECS/blob/main/provisioning/))

1. Fill secrets into a throwaway file and import the roster:
   ```bash
   awk -F, 'BEGIN{OFS=","} NR==1{print;next}{ "openssl rand -base64 15"|getline s; $3=s; print }' \
       provisioning/pilot-users.csv > provisioning/pilot-users.filled.csv
   # FreePBX → Bulk Handler → Extensions → Import  (then delete the .filled.csv)
   ```
2. **Confirm each person's role** and set ERT members to `ctx_ert` / `ctx_ert_lead` (don't guess).
3. Verify a student account can call **111** + another SAP-ID, but is **denied** paging/conference.

**Test:** SAP-ID → SAP-ID call works and is **not** recorded; caller ID shows `Name - SAP ID`.

---

## Block D — Prove it & back it up

1. Run the [Health Check](../operations/health-monitoring.md): `sudo /opt/upes-ecs/upes-ecs-healthcheck.sh`
2. Walk the [Pilot Test Plan](../operations/pilot-test-plan.md) — the 19 tests.
3. Take a config backup + commit custom config to the `upes-ecs-config` git repo ([SOP 11](../guides/backup-restore.md)).

---

## Day-1 done when

- [ ] 111 rings an ERT Android, is answered, and is recorded
- [ ] Unanswered 111 → escalation → Emergency Voicemail → Missed Emergency Incident
- [ ] 199 drill works with no real dispatch
- [ ] SAP-ID → SAP-ID call works and is not recorded
- [ ] Health check reports READY

**Then** move to Phase 2/3 (roles, paging, conference, van drill) via the
[Master Plan](../operations/master-implementation-plan.md), and toward the [Go-Live Checklist](go-live-checklist.md).

---

## If something fails

| Symptom | Check |
|---|---|
| Android won't register | Wi-Fi client isolation; SAP ID/password/domain; firewall |
| 111 rings nobody | Queue has ≥1 available agent; Androids registered + on charger |
| No recording | `${REC_DIR}` writable by `asterisk`; MixMonitor before Answer |
| Android misses calls when idle | Battery optimization OFF, on charger, screen stay-awake ([SOP 24](../reference/mobile-app-reliability.md)) |
| Incident ID blank | `func_shell` not loaded — see [config/README.md](https://github.com/rohanbatrain/UPES-ECS/blob/main/config/README.md) |
