# UPES-ECS — Local Asterisk on the Current Node

Runs a **real Asterisk** on this machine (Docker) to validate the UPES-ECS emergency
dialplan and ERT queue before deploying to the Linux server / van.

> This is the **current node = our server for now** setup. It proves the config is
> correct. Full **phone registration + two-way audio** is done on the Linux
> server/van with host networking — Windows Docker NAT is not suitable for RTP.

---

## Run

```bash
cd deploy
docker compose up -d --build        # build + start
docker exec -it upes-ecs-asterisk asterisk -rvvv   # attach to the Asterisk console
```

Manage:
```bash
docker compose logs -f              # watch logs
docker compose restart              # after editing ../config/extensions_custom.conf
docker compose down                 # stop + remove
```

Re-load dialplan after a config edit (without full restart):
```bash
docker exec upes-ecs-asterisk asterisk -rx "dialplan reload"
```

---

## What's validated here ✅ (end-to-end, not just "loads")

Confirmed on this node (Asterisk 18 LTS, Ubuntu 22.04 container):

**Config loads**
- All contexts: `ctx_emergency_111`, `ctx_escalation`, `ctx_emergency_vm`, `ctx_drill_199`, `ctx_student/staff/ert/ert_lead/paging/conference`.
- `ert_emergency_queue` built from **generic positions** `4110/4111/4112` (shift model — [SOP 30](../SOP/30-ERT-Roles-and-Shifts.md)).
- Endpoints defined: `1001` + positions `4101/4110/4111/4112` + fixed `4200/4300`.
- Modules present: `func_shell`, `app_queue`, `app_confbridge`, `app_voicemail`, `app_mixmonitor`, `app_page`.

**A real call to 111 ran the whole chain**
- Incident ID assigned from the locked counter → `ERT-YYYYMMDD-NNNN` (stamped on CDR `accountcode` + `EMERGENCY_111_CALL`).
- **MixMonitor recorded** from the first second → `ERT-…_….wav`.
- Queue → **escalation** (`Dial PJSIP/4101,20`) → **voicemail** context.
- Helper script wrote a **Missed Emergency Incident** (`severity: critical, review: pending`) + pending-alert.

**199 drill is isolated**
- Separate `DRILL_….wav` recording, CDR `accountcode = DRILL-ONLY`, dialed a test target only — **no real escalation**.

**Health check works**
- `upes-ecs-healthcheck.sh` runs and honestly reports **CRITICAL** (0 registered responders) — correct behaviour until real devices register.

Queue members / devices show **Unavailable** until real phones register — expected here (no phones connected).

---

## WSL2 — real-audio last mile ✅ (proven)

Docker on Windows can't carry SIP/RTP, so the live-audio test runs natively in **WSL2
Ubuntu** (real localhost networking). Scripts: `wsl-setup.sh` (install + configure),
`wsl-call-test.sh` (softphone call), `wsl-rtp-proof.sh` (RTP stats).

```bash
wsl -d Ubuntu-22.04 -u root -- bash /mnt/c/Users/Rohan/UPES/deploy/wsl-setup.sh
wsl -d Ubuntu-22.04 -u root -- bash /mnt/c/Users/Rohan/UPES/deploy/wsl-rtp-proof.sh
```

**Confirmed with a real softphone (baresip) registered to Asterisk:**
- **SIP registration** over UDP → `200 OK`, contact bound (`pjsip show contacts` = 1).
- **Call to 111 answered** → CDR: caller `1001` → `111`, `ANSWERED`, `EMERGENCY_111_CALL`.
- **Live RTP media** → Asterisk streamed **576 packets in 12 s** (~48/s = G.711 20 ms rate) to the phone.
- **Emergency recording** → **11.56 s WAV, RMS amplitude 0.047** (real audio, not silence).
- **Caller identity captured** → recording named `ERT-…_1001_….wav`.

**Bug found + fixed by this test:** the dialplan used `MixMonitor(…,b)` (records only
while *bridged*), which contradicts Feature 4 (record hold + voicemail too). Changed to
`MixMonitor(…)` — recording now captures the whole call. Verified: 44 bytes → 185 KB.

> Only the softphone's **outbound mic** shows 0 packets — WSL has no microphone hardware
> for a headless softphone. A real Android has a mic + speaker, so that direction works
> on real devices. Everything else is proven.

---

## What still needs the Linux server / van

- **Phone/softphone registration** and **two-way audio** (RTP) — do on the Linux
  host with `network_mode: host` or `ports:` mapping (uncomment in `docker-compose.yml`),
  or a native FreePBX install ([SOP 08](../SOP/08-FreePBX-Build-Guide.md)).
- **Helper scripts** (`incident_id.sh`, `missed_incident.sh`, …) — mount `/opt/upes-ecs`
  and `/var/lib/upes-ecs` into the container, or run them on the native host (`setup.sh`).
- **Prompts** — drop the recorded `upes-ecs/*` WAVs ([SOP 28](../SOP/28-Voice-Prompt-Scripts.md)).
- **FreePBX GUI** — the production build uses FreePBX; this container is raw Asterisk
  for fast config validation.

---

## Files

| File | Purpose |
|---|---|
| `Dockerfile` | Ubuntu 22.04 + Asterisk 18 LTS |
| `docker-compose.yml` | Mounts the real `../config/extensions_custom.conf` + validation configs |
| `asterisk/extensions.conf` | Entry point — `#include extensions_custom.conf` |
| `asterisk/pjsip.conf` | Transport + test endpoints (`1001`, `4110`) |
| `asterisk/queues.conf` | `ert_emergency_queue` with position members |

> The validation configs (`asterisk/*.conf`) are minimal stand-ins for what FreePBX
> generates in production. The **real** file under test is `../config/extensions_custom.conf`.
