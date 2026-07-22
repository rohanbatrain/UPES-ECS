# UPES-ECS Config & Scripts Pack

Starter Asterisk config + helper scripts for the emergency core. **Reference, not
blind drop-in** — adapt paths, extensions, prompts, and the roster to your site, then
test with **199 before 111**.

> Design detail is in [../SOP/09-Dialplan-Design.md](../SOP/09-Dialplan-Design.md).
> Build steps are in [../SOP/08-FreePBX-Build-Guide.md](../SOP/08-FreePBX-Build-Guide.md).

---

## Files

| File | Goes where | Purpose |
|---|---|---|
| `config/extensions_custom.conf` | `/etc/asterisk/extensions_custom.conf` | Emergency dialplan (**111 primary**, 199 drill, escalation, VM, paging, conference, `*45/*46`, role contexts) |
| `config/extensions_features.conf` | `/etc/asterisk/extensions_features.conf` | Coordination feature contexts (dept hunt, SOS `*77`, announcements, callout, **shift login `*22`/`*23`**, etc.) |
| `config/extensions_features_wiring.conf` | `/etc/asterisk/extensions_features_wiring.conf` | Include lines that wire the feature contexts into the role contexts |
| `config/extensions_aihelpline.conf` | `/etc/asterisk/extensions_aihelpline.conf` | **`102` offline panic-coach** (`ctx_ai_helpline`) — the deterministic first-aid decision tree reached when nobody answers `111` |
| `deploy/asterisk/pjsip_accounts.conf` | `/etc/asterisk/pjsip_accounts.conf` | PJSIP endpoints/AORs/auth for the ERT positions + pilot users |
| `scripts/incident_id.sh` | `/opt/upes-ecs/` | Prints next `ERT-YYYYMMDD-NNNN` (locked counter) |
| `scripts/missed_incident.sh` | `/opt/upes-ecs/` | Writes a Missed Emergency Incident + dashboard flag |
| `scripts/log_access_denied.sh` | `/opt/upes-ecs/` | Access Denied Event log |
| `scripts/log_paging.sh` | `/opt/upes-ecs/` | Emergency Paging Attempt log |
| `scripts/log_conf.sh` | `/opt/upes-ecs/` | Conference join/leave log |
| `scripts/upes-ecs-healthcheck.sh` | `/opt/upes-ecs/` | LAN-only readiness check (cron + daily check) |
| `scripts/retention-cleanup.sh` | `/opt/upes-ecs/` | Deletes recordings/VM past 90 days (audited) |

---

## Install

```bash
# 1. Scripts
sudo mkdir -p /opt/upes-ecs /var/lib/upes-ecs
sudo cp scripts/*.sh /opt/upes-ecs/
sudo chmod +x /opt/upes-ecs/*.sh
sudo chown -R asterisk:asterisk /var/lib/upes-ecs        # so dialplan System() can write

# 2. Dialplan — custom core + feature contexts + wiring + the 102 offline coach
sudo cp config/extensions_custom.conf /etc/asterisk/
sudo cp config/extensions_features*.conf /etc/asterisk/        # extensions_features.conf + _wiring.conf
sudo cp config/extensions_aihelpline.conf /etc/asterisk/       # 102 panic-coach (ctx_ai_helpline)
sudo cp deploy/asterisk/pjsip_accounts.conf /etc/asterisk/     # PJSIP endpoints/AORs/auth
sudo asterisk -rx 'dialplan reload'
sudo asterisk -rx 'pjsip reload'

# 3. Recording dir
sudo mkdir -p /var/spool/asterisk/monitor/upes-ecs
sudo chown asterisk:asterisk /var/spool/asterisk/monitor/upes-ecs

# 4. func_shell must be loaded for ${SHELL()} (incident_id). Check:
sudo asterisk -rx 'module show like func_shell'
```

Enable `${SHELL()}` only if your policy allows it; otherwise replace the
`incident_id.sh` call with an AGI or a FreePBX-native counter.

---

## Wire into FreePBX

1. **Admin → Config Edit** — confirm `extensions_custom.conf` is present.
2. **Custom Destinations** — add:
   - `111` → `ctx_emergency_111,111,1` (sole emergency number)
   - `102` → `ctx_ai_helpline,102,1` (offline panic-coach — internal fallback / test dial)
   - `199` → `ctx_drill_199,199,1`
3. **Inbound/feature routing** — point the emergency numbers at those destinations.
4. **Extensions / Class of Service** — put each user in the matching role context
   (`ctx_student` … `ctx_admin`).
5. **Queue** — create `ert_emergency_queue` (ringall, 20s) with ERT agents.
6. **Apply Config.**

---

## Cron

```cron
# Health check every 5 min (writes status for the local dashboard)
*/5 * * * * /opt/upes-ecs/upes-ecs-healthcheck.sh > /var/lib/upes-ecs/health.txt 2>&1

# Retention cleanup daily at 03:30
30 3 * * * /opt/upes-ecs/retention-cleanup.sh
```

---

## Record the prompts

Create these under `/var/lib/asterisk/sounds/en/upes-ecs/` (wording in the SOPs):

| File | Wording source |
|---|---|
| `emergency-preanswer` | [Numbering Plan](../SOP/01-Numbering-Plan.md) / Feature 1 |
| `emergency-voicemail-prompt` | [Feature 10 decisions](../Docs/Feature-10.md) |
| `drill-prompt` | [Drill SOP](../SOP/03-Drill-Test-SOP.md) |
| `queue-paused` / `queue-resumed` | short confirmations |
| `not-authorized` | "You are not authorized for this feature." |

---

## Secrets

`PAGING_PIN_700`, conference PINs, and SIP secrets must **not** live in plain text in
production. Use a local secrets store / restricted include file, and keep them out of
the public git history. See [Backup & Restore §5](../SOP/11-Backup-Restore-Procedure.md).

---

## Test order (after any change)

```text
199 (drill)  →  111 (real path)  →  student-to-student  →  paging (authorized + denied)
```
