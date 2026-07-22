# UPES-ECS Operations Console

A self-contained web app — the one place to **see live status, register clients, drive
emergency comms, and run privileged PBX actions** (behind a confirmation modal). LAN-only,
no internet/CDN/fonts, works offline.

Built as a small vanilla-JS **feature registry**: each section is one module object
(`{id, title, icon, group, render()}`) in `app.js`. Adding a feature = adding one module —
the sidebar nav and routing build themselves. No build step, no framework, no CDN.

---

## Run it

**Production (set-and-forget) — install autostart ONCE, never launch it by hand again:**

```powershell
# registers logon launchers (no admin) for the VM + a SUPERVISED console:
powershell -ExecutionPolicy Bypass -File ..\deploy\qemu\Register-Autostart.ps1
```

At every logon this boots the PBX VM, then (~25 s later) starts the console **supervisor**
`Run-Console.ps1`, which runs `Serve.ps1` and **auto-restarts it if it ever dies**. Serve
serves assets `no-cache` and exposes a `/__build` stamp the dashboard polls — so when you
deploy an edit (`app.js`/`app.css`/`index.html`), every open wallboard **reloads itself**
within ~4 s. No babysitting, no hard-refresh. Undo with `Register-Autostart.ps1 -Remove`.

> **Full step-by-step, params, verify & troubleshooting:**
> [deploy/qemu/Autostart-Setup.md](../deploy/qemu/Autostart-Setup.md).

**Manual (one-off / dev):**

```powershell
# from this folder:
powershell -ExecutionPolicy Bypass -File Run-Console.ps1     # supervised: serve + auto-restart
#   or, single run without the supervisor:
powershell -ExecutionPolicy Bypass -File Serve.ps1           # serve + live API proxy + fallback refresh
# then open the printed URL, e.g. http://localhost:8080
```

---

## Campus LED-TV screens (always-on wallboards)

Two purpose-built, full-screen, self-refreshing boards for public/control-room LED TVs.
They poll `/api/status` (live, via the SSH-tunnelled in-VM API) every ~4 s with a
`status.json` fallback, degrade gracefully (**live → stale → offline**, never blank), show
people/positions **by name** (from `directory.json`, generated from the source-of-truth
`pjsip_accounts.conf`), and **auto-reload on deploy**.

| URL | For | Shows |
|---|---|---|
| [`/tv-safety.html`](tv-safety.html) | Public / lobby | Giant **DIAL 111**, "line active" status, responders-ready, how-to (111/102/199). **Auto-switches to an EVACUATION board** while a roll-call has unaccounted people (safe / responded / unaccounted counts + "press 1 to mark safe"). |
| [`/tv-ops.html`](tv-ops.html) | Control room / ERT desk | State pill, KPI strip (ERT ready, endpoints online, active calls, disk, missed, 111-answered %, avg answer), ERT queue with live states, live calls, missed emergencies, recent CDR, all-time analytics (answer %, drill pass, 14-day volume, by-type), shift log. |

**Launch (kiosk, per-monitor):**

```powershell
powershell -File Show-TV.ps1 -Both                 # dual-display PC: safety→monitor 0, ops→monitor 1
powershell -File Show-TV.ps1 -Screen ops -Monitor 1  # one screen on a chosen monitor
```

`Show-TV.ps1` opens Edge/Chrome in `--kiosk` at the target monitor's bounds, each in its own
profile (two independent TVs from one PC). In-page: `F` toggles fullscreen; Ctrl+W exits.

**Files:** `tv-safety.html` / `tv-ops.html` (entry pages) · `tv.js` (shared poll/reconnect +
render engine, dispatched by `<body data-screen>`) · `tv.css` (dark, high-contrast, fits
1080p→4K) · `directory.json` (ext→name, kept in sync by `Add-UpesUser.ps1`). The registrar IP
each board shows is the address **Asterisk advertises** (`mediaAddress` from the API), i.e.
the one phones must actually use — not merely the host's default-route IP.

- **`Serve.ps1`** serves the console on `http://localhost:8080`, opens a **persistent SSH
  tunnel** to the VM (`localhost:18090 → VM:8090`), and **proxies `/api/*`** to the in-VM
  `upes-api` service. It also refreshes `status.json` as an automatic fallback. Run it
  **elevated** to also expose it on the LAN (so any browser can view it).
- Open the printed URL in a browser. The reference sections work with no data source; the
  live sections use the **live API** (`GET /api/status`, refreshing ~every 4 s at ~1.5 s
  latency) and fall back to `status.json` if the tunnel/API is down.

---

## Live status & control API (`upes-api` on the VM :8090)

A small **FastAPI** service (`systemd` unit `upes-api`, `Restart=always`) runs **inside the
VM on port 8090**, querying Asterisk locally. It exposes:

- `GET /health` — liveness.
- `GET /status` — the full wallboard schema (same shape the Console consumes; supersedes the
  old ~75 s SSH `Update-Status.ps1` pull — now ~1.5 s).
- `POST /exec` — privileged actions on a **strict whitelist**: `shift` / `callout` / `drill`
  / `reload`. Nothing outside the whitelist can run.

**`POST/GET /api/rebind` is different** — it's served **host-side by `Serve.ps1` itself**, not
proxied to the VM, because only the host knows its current LAN IP. `POST` starts
`Set-UpesLanIp.ps1` **detached** (auto-detect new IP → update `external_media_address` → reload
PJSIP) and returns immediately; `GET` reports `running`/done + the script output. Running it
detached is deliberate: the PJSIP reload is slow (~60–90 s on the emulated PBX) and a synchronous
run would block `Serve.ps1`'s single-threaded listener and freeze every open wallboard.

`Serve.ps1` proxies the Console's `/api/*` to it over the persistent SSH tunnel
(`localhost:18090 → VM:8090`). **Security posture:** the :8090 API is an attack surface, so it
**binds locally / tunnel-only** (never the public LAN) and **CORS is restricted** so a random
browser page can't cross-origin `POST` to `/exec`. `status.json` remains a read-only fallback.

---

## Serving many screens (scaling)

The console is built to drive **a wall of TVs and a room full of dashboards from one
laptop** without multiplying load on the single-vCPU emulated PBX. Three mechanisms make
5 screens and 50 screens cost the VM roughly the same:

**1. Fan-in cache.** `Serve.ps1` caches the live read endpoints **in memory** and shares a
single upstream fetch across **every** connected screen. When many wallboards poll at once,
the first request triggers one fetch through the SSH tunnel to the in-VM API; everyone else
within the TTL is served that same cached snapshot. So the VM sees a steady trickle of
fetches no matter how many browsers are watching.

| Endpoint | TTL | Served to |
|---|---|---|
| `GET /api/status` | ~2 s | Wallboards + dashboard (full schema) |
| `GET /api/live` | ~1 s | Fast KPI strip / live-call tiles |

Every response carries an **`X-Upes-Cache`** header so you can see the cache working:

| `X-Upes-Cache` | Meaning |
|---|---|
| `hit` | Served from the in-memory cache — the VM was **not** touched |
| `miss` | Cache was cold/expired — this request did the one real upstream fetch |
| `stale` | Upstream was unreachable, so the **last good** snapshot was served |

**2. Serve-stale (never blank).** If the VM or the SSH tunnel hiccups, the console keeps
serving the last good snapshot marked `X-Upes-Cache: stale` instead of erroring. Wallboards
never blank out, and — just as important — failed requests **don't pile up** into a
thundering herd of retries against a struggling VM. (The front-end still shows its own
live -> stale -> offline treatment on top of this.)

**3. Cached, compressed static assets.** `index.html`, `app.js`, `app.css`, `tv.js`,
`tv.css`, the wallboard HTML, `directory.json`, docs, etc. are held **in memory** and
**gzip-compressed** for `html/js/css/json/md` when the browser sends
`Accept-Encoding: gzip`. Extra screens loading the app cost almost nothing.

### Load-test it

`tests\Load-Test-Console.ps1` is a **strictly read-only** (GET-only) load generator that
spins up N virtual screens polling exactly like the real front-end, then reports latency
and the `X-Upes-Cache` breakdown. It never POSTs and never touches `/api/exec`, `/api/rebind`
or any mutating endpoint, so it can't change PBX state.

```powershell
# from this folder's sibling tests\ dir:
powershell -ExecutionPolicy Bypass -File ..\tests\Load-Test-Console.ps1 -Clients 25 -Seconds 60 -Endpoint mixed
```

Params: `-Url` (default `http://localhost:8080`), `-Clients` (default 10), `-Seconds`
(default 30), `-Endpoint live|status|mixed` (default `mixed` = a board doing both the fast
`live` poll and the slow `status` poll). It prints total requests, req/s, errors, latency
**p50/p95/p99**, and the `hit/miss/stale` tally with a **hit ratio**.

**How to read it:** a **high hit ratio at high `-Clients`** is the fan-in cache working — it
means the backend served far fewer upstream fetches (`miss + stale`) than the clients issued.
The tool prints that amplification directly (e.g. *"25 screens issued 900 GETs; backend
fetched ~30"*). If latency p95/p99 climbs sharply as you raise `-Clients`, you've found the
concurrency ceiling of the single-listener server.

### Multi-PC / LAN deployment (other PCs + TVs)

To serve the console to other PCs and campus TVs from this laptop **without launching it
elevated every time**, add a one-time URL reservation. Run this **once** in an **elevated**
shell:

```powershell
netsh http add urlacl url=http://+:8080/ user=Everyone
```

After that, run `Serve.ps1` normally (no admin) and it will bind all interfaces. Then point
browsers on the LAN at the laptop's IP:

| URL | For |
|---|---|
| `http://<laptop-ip>:8080/` | Operations dashboard |
| `http://<laptop-ip>:8080/tv-ops.html` | Control-room wallboard |
| `http://<laptop-ip>:8080/tv-safety.html` | Public / lobby wallboard |

**Windows Firewall must allow inbound TCP 8080** for other machines to reach it. On the van's
own AP/router this stays LAN-only (no internet exposure).

> **Restart to apply.** Changes to `Serve.ps1` — including the cache TTLs, gzip, and
> serve-stale behavior above — only take effect after you **restart `Serve.ps1`** (or let the
> `Run-Console.ps1` supervisor restart it). A running listener keeps its old code in memory.

---

## What's on it

| Group | Section | What |
|---|---|---|
| Operations | **Wallboard** | Live control-room view: state banner, stat tiles (Asterisk, ERT queue, active calls, registered, storage, missed), live **queue-members** table, **registered-users** table (ext→name→ip via the built-in roster), **recent missed emergencies**. Auto-refreshes; degrades gracefully with missing fields / no `status.json` |
| Operations | **Incident Timeline** | Live, newest-first stream of every call the PBX handled (built from the CDR log). Emergencies (111), silent SOS, drills, incident bridges and paging are colour-coded; filter chips narrow by kind. Auto-refreshes |
| Operations | **Presence & Shifts** | Who is on each responder position **right now** — registration + queue state of every defined endpoint (`pjsip show endpoints`), split into responder positions (on-shift / in-queue / reachable) and registered clients. Auto-refreshes |
| Operations | **Call Records** | The recent **call-detail log** (from→to→app→result→length, roster-named) plus in-browser **playback of whole-call recordings**, synced from the PBX by `Pull-Recordings.ps1` |
| Insights | **Insights** | Reporting dashboard over the **full** CDR log: emergency **answer-rate + answer-time** on 111, **drill pass-rate** (199), calls-by-type, activity-by-hour histogram, per-day volume, top callers. Pure-CSS charts, no chart library |
| Operations | **Register a Client** | Pick a role → generates the **CSV import line**, a **strong secret** (crypto-random, local), and the exact **Linphone settings** with the current server IP filled in |
| Emergency tools | **Mass Callout** | Pick a group + recorded message → shows the exact callout command **and an Execute button**. Execute opens a confirmation modal (command + effect, second click) that `POST`s to `/api/exec` |
| Emergency tools | **Roll-call / Headcount** | Start a press-1-safe headcount → **Execute button** (confirm modal → `/api/exec`) + a live safe/unaccounted tally |
| Emergency tools | **Announcements** | Pick a paging zone (700–705) + message → the exact page command **and Execute** (confirm modal → `/api/exec`); ERT-Lead / Control only |
| Directory & comms | **Directory** | Searchable roster with SAP-ID / extension and how-to-call note |
| Directory & comms | **Hunt Groups** | Department desks (Security 4300, Medical 4200, Warden 4400, Ops 4500, IT 4600) and their codes |
| Reference | **Emergency Call Flow** | The full `111` disaster-ready flow — press-1 fast-path, parallel responder alerting, and the offline panic-coach (`102`) fallback — as a walkable diagram |
| Reference | **Architecture** | System + network topology as inline **SVG diagrams** (PBX / VM / Console / API / phones), no external assets |
| Reference | **Numbering** | Every number/code/position/context |
| Reference | **ERT & Shifts** | Answer script, dispatch, surge, silent-call, shift model |
| Reference | **Network** | How phones connect, dynamic-across-routers rebind (incl. a **“Rebind PBX to this network”** Execute button — one click to follow the van to a new router / OTG hotspot, no internet needed), client-isolation + firewall checklist |
| Reference | **Operations** | Start/stop/deploy/rebind/health/backup commands |
| Reference | **Docs** | In-app **Markdown doc viewer** — renders the SOP / Blueprint / Journal in-browser (no external site). `secrets/` is blocked from being served |

> The **Emergency tools** now do more than print commands — each shows the exact operator
> command **and an Execute button** that `POST`s to the whitelisted `/api/exec` (proxied to
> the in-VM `upes-api`). Every Execute goes through a **confirmation modal** that shows the
> exact command and what it will do and requires a **second click** before anything runs
> (confirm-before-run). The copy-able `asterisk -rx` / script command is still shown for
> operators who prefer to run it on the PBX by hand. The `/api/exec` whitelist
> (`shift`/`callout`/`drill`/`reload`) bounds what the Console can ever trigger.

---

## Files

| File | Purpose |
|---|---|
| `index.html` | App shell (sidebar + topbar; nav and views injected by `app.js`) |
| `app.css` | Design system — tokens (spacing/type/color), components, layout, responsive, print |
| `app.js` | Vanilla-JS framework: **feature registry**, hash router, live poll, roster + reference data, all feature modules |
| `Update-Status.ps1` | **Fallback** path: queries the VM over SSH → writes `status.json` (incl. `cdr[]`, `recordings[]`, `presence[]`). The live path is the in-VM `/api/status`; this runs on a timer so the Console still shows data if the API/tunnel is down |
| `Pull-Recordings.ps1` | Stages + syncs recent call recordings into `recordings\` so the Call Records player can play them |
| `Serve.ps1` | Local static server + **SSH tunnel + `/api/*` proxy** to the in-VM `upes-api` (:8090) + `status.json` fallback refresh (also syncs recordings every 4th cycle). Serves assets `no-cache` + a `/__build` stamp for auto-reload. Refuses to serve `secrets/` |
| `Run-Console.ps1` | **Supervisor** — runs `Serve.ps1` and auto-restarts it forever (self-heal + crash-loop backoff + single-instance lock). What the logon autostart launches |
| `status.json` | Fallback status (generated; safe to delete) |
| `recordings\` | Synced `.wav` recordings for in-browser playback (generated; safe to delete) |

### Add a new section

Append one module in `app.js` and it appears in the nav automatically:

```js
register({
  id: "myfeature", group: "Reference", icon: "docs",
  title: "My Feature", subtitle: "One line describing it",
  render() { return `<div class="panel">…</div>`; },
  // optional: mount(root) for interactivity, live(root, status) for live data
});
```

---

## Notes

- The console's **server IP updates automatically** from `status.json` (which reads the
  laptop's current LAN IP) — so it stays correct as the van moves between routers.
- The generated **secret is never stored** — deliver it once, securely.
- **`secrets/` is never web-served.** `secrets/TEAM-CREDENTIALS.md` holds real SIP logins;
  both the static server and the in-app doc viewer explicitly block the `secrets/` path.
- The **`/api/exec`** surface is bounded: whitelist-only actions, confirm-before-run in the
  UI, and the API binds tunnel-only with restricted CORS (see the API section above).
- For a permanent setup, run `..\deploy\qemu\Register-Autostart.ps1` **once** — the console
  then starts supervised at every logon (`Run-Console.ps1` keeps `Serve.ps1` alive) and
  auto-reloads open wallboards on deploy via the `/__build` stamp. `status.json` is only the
  backstop if the live API is unreachable.
- **Self-heal + single-instance:** `Run-Console.ps1` restarts `Serve.ps1` on any crash
  (with a crash-loop backoff) and takes a global mutex so a second copy can't double-bind
  port 8080. Restarts are logged to `Console\logs\console-supervisor.log`.
