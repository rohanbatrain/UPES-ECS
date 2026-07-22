# UPES-ECS Emergency PBX -- Local Status API

A small FastAPI service that runs **inside the Asterisk VM** (Ubuntu 22.04) and
exposes the emergency PBX state over a fast local HTTP API.

## Why

The Emergency Console previously polled the PBX over SSH, opening a new SSH
session per request -- far too slow. This service instead lives on the VM and
queries Asterisk locally through `asterisk -rx` subprocess calls (no SSH). The
systemd unit runs it as **root**, so `asterisk -rx` works without sudo.

It listens on `0.0.0.0:8090` with permissive CORS so the Console can call it
cross-origin.

## Endpoints

### `GET /health`
Liveness check.
```json
{ "ok": true, "service": "upes-api" }
```

### `GET /status`
Full point-in-time snapshot consumed by the Console: overall `state`
(`READY` / `DEGRADED` / `CRITICAL` / `OFFLINE`), Asterisk version/uptime, queue
availability, registrations, disk usage, active calls, queue members, registered
users, endpoint presence, recent missed emergencies, recent CDRs, recordings,
full-history `analytics`, the shift log, `mediaAddress` (the LAN IP Asterisk
advertises to phones), and `followups` (the missed-emergency callback queue).

`followups` = `{pending, overdue, targetSec, queue[], recentClosed[]}` — derived
(not stored) from the incident log + `followups.ndjson`: each missed 111 call stays
OPEN until a `safe`/`escalated` callback closes it; `overdue` counts open items past
the 5-min target. `missedPending` mirrors `followups.pending`.

Every underlying subprocess/file read is defensive (timeouts + try/except), so
`/status` never hangs and never 500s -- partial failures return empty/default
values.

### `GET /live`
Lightweight, high-frequency snapshot of only the fast-changing state
(`asterisk`, `activeCalls`, `liveCalls`, `queueAvailable`, `queueMembers`). The
Console/TV boards poll this ~1s so an ended call clears almost immediately, without
the cost of the full `/status` (which parses the whole CDR + analytics each call).

### `POST /exec`
Strictly whitelisted control actions. Body: `{"action": str, "args": {...}}`.
Returns `{"ok": bool, "command": str, "output": str}`. Anything not on the
whitelist (or failing validation) returns `{"ok": false, "output": "rejected"}`.

| action    | args                                             | effect |
|-----------|--------------------------------------------------|--------|
| `shift`   | `mode` = `on`\|`off` (default `on`), `ext` digits | runs `/opt/upes-ecs/ert-shift.sh <mode> <ext>` |
| `callout` | `group` `[a-z0-9]`, `sound` `[A-Za-z0-9/_-]`, `mode` = `notify`\|`rollcall` | runs `/opt/upes-ecs/mass_callout.sh /opt/upes-ecs/groups/<group>.csv <sound> <mode>` |
| `drill`   | `ext` digits                                     | `asterisk -rx "originate PJSIP/<ext> extension 199@ctx_student"` |
| `reload`  | (none)                                           | `asterisk -rx "dialplan reload"` |
| `followup`| `incident_id` `[A-Za-z0-9-]`, `ext` digits, `outcome` = `safe`\|`escalated`\|`noanswer`\|`needshelp`, `note` (optional) | runs `/opt/upes-ecs/followup.sh <id> <ext> <outcome> <note>` — logs a missed-emergency callback (safe/escalated close it; noanswer/needshelp keep it open) |

All arguments are regex-validated/sanitized and passed as explicit argument
lists (never through a shell), so user input can't be interpreted by a shell.

## Install / run

From this `api/` directory on the VM, as root:

```bash
sudo ./install-upes-api.sh
```

This installs `fastapi` + `uvicorn[standard]`, copies `upes_api.py` to
`/opt/upes-ecs/api/`, installs the `upes-api.service` systemd unit, enables and
starts it, then curls `/health` to verify.

### Manual run (dev)
```bash
python3 /opt/upes-ecs/api/upes_api.py
# serves on 0.0.0.0:8090
```

### Service management
```bash
systemctl status upes-api
journalctl -u upes-api -f
systemctl restart upes-api
```

## Files
- `upes_api.py` -- the FastAPI app (served by uvicorn on :8090).
- `install-upes-api.sh` -- installer (deps + systemd unit + verify).
- `upes-api.service` -- systemd unit (runs as root, `Restart=always`).
- `README.md` -- this file.

---

# UPES-ECS Safety & Location API (mobile app)

A **second** FastAPI service — `safety_api.py` on `0.0.0.0:8091` — that serves the
**UPES Safe mobile app** (see [`../app/`](../app/)). Unlike `upes_api.py` (loopback,
operator-only), this one is reached by student/parent **phones on the campus LAN**, so
every route except `/health` requires **HTTP Basic auth**: username = SAP ID, password =
the pinned SIP secret from `pjsip_accounts.conf` (the single source of truth — one
credential, no drift).

| method + route  | auth        | purpose |
|-----------------|-------------|---------|
| `GET /health`   | none        | liveness + user count |
| `POST /loc`     | self        | report GPS `{lat,lon,acc,battery}`; returns the live `emergency` state |
| `POST /safe`    | self        | self-declare `{status: safe\|needshelp, note}`; `needshelp` also hits the Console urgent list |
| `GET /me`       | self        | own identity + status + `isParent`/`isOperator`/`emergency` |
| `GET /emergency`| self        | is a campus emergency active? |
| `POST /emergency`| operator   | raise/clear the "mark yourself safe" campaign |
| `GET /family`   | parent      | each linked child: registered, app-active, last location, on-campus, safe-state |
| `GET /map`      | operator    | everyone's latest position (for a Console map) |

Emergency is auto-active when any live `111` call is in progress **or** an operator set
the flag. Family links come from `/opt/upes-ecs/family/families.csv`
(`parent_sap,child_sap`), managed by [`../provisioning/family/Add-UpesFamily.ps1`](../provisioning/family/README.md).
On-campus is a geofence check against `/opt/upes-ecs/family/campus.json`.

Install (inside the VM, as root): `sudo ./install-safety-api.sh` — installs deps, seeds
`/opt/upes-ecs/family/`, installs `upes-safety-api.service`, starts it, curls `/health`.

Files: `safety_api.py`, `install-safety-api.sh`, `safety-api.service`.
