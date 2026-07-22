# UPES-ECS — Scaling & High-Availability Plan

> **Status: PLAN ONLY — nothing in here is implemented.** This is the design for
> serving many concurrent viewers (TVs + dashboards + phones) reliably, and the
> answer to "can I connect multiple servers and join them on one endpoint?".
> Baseline restore point before any of this work: commit `1d6f51c`.
>
> Companion analysis: the load study in chat (why "single concurrency" bites).
> Related existing kit: [`deploy/jetson/README.md`](https://github.com/rohanbatrain/UPES-ECS/blob/main/deploy/jetson/README.md)
> (active/standby HA), [`Docs/Juniper-Integration-Plan.md`](../networking/juniper-integration-plan.md).

---

## 0. The one idea

**Fan-in, not fan-out.** Today every screen independently polls one shared, slow
backend, so load scales with the number of screens and lands on the CPU that runs
the phone system. The whole plan is to insert **one shared read layer** so that
**5 screens or 500 screens cost the backend the same** — one poll per interval.

Everything else (reverse proxy, round-robin, HA) is *how* we deliver that idea
safely for an emergency system.

---

## 1. The three-tier model (read this before anything else)

Your system is three tiers, and "join multiple servers together" means something
**different and non-interchangeable** in each. Mixing them up is the classic way
to make an emergency system less reliable while trying to scale it.

| Tier | Component(s) | State it holds | Can you round-robin it? | Correct way to "join servers" |
|---|---|---|---|---|
| **A — Presentation** | `serve-console.py` (Jetson) / `Serve.ps1` (Win), the TV/dashboard front-ends | none (stateless) | ✅ Yes | Reverse-proxy round-robin — but rarely needed (see §4) |
| **B — Read model** | `/api/status`, `/api/live` data | short-lived snapshot | ⚠️ Only via a **shared** cache | **Caching reverse proxy** / shared poller (the actual scaling lever) |
| **C — PBX** | Asterisk (SIP registrations, live call state) | **critical, authoritative** | ❌ **Never** | **Active/standby + floating VIP** (keepalived), never load-share |

The failure you must avoid: **round-robining stateful things.** Two active
Asterisks = a phone registered to node A is unreachable via node B, and an
in-progress call has no shared state — in an emergency that is a safety defect,
not a performance quirk. Likewise, round-robining front-ends that each keep their
own cache multiplies backend load by the number of front-ends.

---

## 2. Current state (why it doesn't scale yet)

The request chain for **every** screen:

```
Browser (renders itself — infinitely scalable, not the problem)
   -> front-end web server (serve-console.py / Serve.ps1)   [no /api cache]
   -> API (api/upes_api.py, FastAPI)                         [/status cached 2.5s; /live NOT cached]
   -> Asterisk CLI (asterisk -rx, ~4-17 subprocess spawns per call)
```

- **`/api/live` is uncached at every layer** and is the *most frequently polled*
  path (TV boards hit it ~every 1.3 s). N boards => N x `asterisk -rx` load on the
  **same CPU that processes calls**. This is the ceiling.
- On the **Windows/QEMU** path the CPU is a single emulated (TCG) vCPU — the
  hard floor under every number.
- Front-end proxies (`serve-console.py` `_proxy_api`, `Serve.ps1` `api/*`) add
  **no cache**, so they can't shield the backend.
- Static assets are re-read per request, **no gzip**, `no-cache` on JS/CSS/HTML —
  so every new PC and every deploy-triggered mass reload re-downloads everything.

What's already right (keep it): `serve-console.py` is threaded; FastAPI `/status`
has a TTL cache + concurrent collectors; the Jetson HA kit gives a VIP, health
checks, config sync, and mDNS failover.

---

## 3. Target architecture

Built on top of the existing **active/standby Jetson cluster** — we add a caching
edge and a fan-in read layer; we do **not** change the PBX HA model.

```
                       Voice/Mgmt VLAN — one L2 subnet
   Phones ──REGISTER──►  VIP  (keepalived MASTER owns it)  ◄── every TV/PC points here
   TVs/PCs ──HTTP────►   http://<VIP>:80  (or ecs.upes.local via mDNS)
                               │
                 ┌─────────────┴──────────────┐   (VIP lives on ONE node at a time)
                 ▼                             ▼
        ┌──────────────────┐          ┌──────────────────┐
        │ Jetson PRIMARY   │  rsync   │ Jetson SECONDARY  │
        │  ── nginx :80 ───┼─ sync ─► │  ── nginx :80     │   EDGE:
        │   • gzip         │          │                   │   - single endpoint
        │   • microcache   │          │                   │   - fan-in cache
        │   • static+SSE   │          │                   │   - (opt) round-robin
        │  serve-console/  │          │  serve-console/   │   ORIGIN (stateless)
        │  FastAPI :8090   │          │  FastAPI :8090    │   READ MODEL (one poller)
        │  Asterisk MASTER │          │  Asterisk BACKUP  │   PBX (active/standby)
        └──────────────────┘          └──────────────────┘
```

- **The VIP is your single endpoint** for both SIP (`:5060`) and the web/API
  (`:80`). "Served by whichever node holds the VIP." You already have this for
  `:8080`/`:5060`; we front it with nginx on `:80`.
- **nginx microcache = fan-in.** It caches `/api/live` ~1 s and `/api/status`
  ~2 s, so the backend gets **at most ~1 request/sec/endpoint regardless of screen
  count**. Same idea as the FastAPI `/status` cache, moved to the edge and applied
  to the hot path too.
- **PBX stays active/standby.** Unchanged. nginx runs on both nodes; only the one
  holding the VIP serves traffic.

---

## 4. Your question, answered precisely

> *"Is there a way I connect multiple servers and join them together — reverse
> proxy or round robin on a single LAN endpoint?"*

**Yes. Use a reverse proxy as the single endpoint. Round-robin only the stateless
tier — and with caching you probably won't even need to.**

### 4.1 Reverse proxy — YES, this is the centerpiece
A caching reverse proxy (recommend **nginx**) in front of the VIP gives you, in one
component:
- **One stable endpoint** for every screen (`http://<VIP>` / `ecs.upes.local`).
- **Fan-in microcache** of `/api/*` — the single biggest scaling win.
- **gzip + static caching** — cheap onboarding of many PCs and mass auto-reloads.
- **A ready path to round-robin** (`upstream {}`) if you ever add nodes.
- **Health checks + failover** that compose with keepalived.

### 4.2 Round-robin — YES for tier A, but usually unnecessary
- The web/render tier is stateless, so it *can* be load-balanced (nginx `upstream`,
  HAProxy, or keepalived+LVS/IPVS, or DNS round-robin across node IPs).
- **But** once `/api/*` is microcached, a single active node serves static +
  cached API for an entire campus of screens trivially. Round-robin adds
  complexity (and, done naively with per-node caches, *multiplies* backend load).
  Recommendation: **don't round-robin the web tier now.** Keep active/standby (VIP)
  + caching. Revisit only if a single node's CPU genuinely can't serve the render
  load — which caching makes very unlikely for a campus.
- If you later *do* want both boards serving web simultaneously (active/active
  web while PBX stays active/standby): add a second **LB VIP** driven by
  keepalived+LVS, or DNS round-robin across the two node IPs. Documented as a
  future option, not part of the core plan.

### 4.3 The PBX — NO round-robin, HA instead
You already have the right answer in `deploy/jetson/`: **active/standby with a
keepalived VIP.** Phones register to the VIP; on failure the standby claims it and
sends gratuitous ARP; short registration expiry (60 s) bounds recovery. Do **not**
put two active Asterisks behind a round-robin — SIP registration and call state
don't split. (The kit's own §11 notes the true active/active path — PJSIP realtime
+ replicated DB sharing registration contacts — as a deliberate future upgrade,
not something to bolt on now.)

### 4.4 Where the proxy runs (air-gapped campus)
On the Jetson nodes themselves — nginx on each board, following the VIP via
keepalived. No internet, no cloud LB. This keeps the edge on the same failover
domain as the PBX. (A separate small Linux box works too, but co-locating on the
HA pair is simpler and one less thing to fail.)

### 4.5 One caveat — the host-side admin endpoints
`Serve.ps1` has Windows-host-specific control endpoints (`api/rebind`,
`api/ivrlang`, `api/users`, `api/vm`, `api/adduser`, `api/deploy`, ...) that run
PowerShell on that specific laptop. Those are **not stateless** and cannot be
round-robined. On the Jetson path they mostly disappear (the API is local; the VIP
handles addressing) or should become proper FastAPI actions. Treat "admin/control
plane" as a **single designated node**, separate from the scalable read/render
path. Achieving admin-endpoint parity on `serve-console.py`/FastAPI is a migration
task tracked in Phase 4.

---

## 5. Phased rollout

Each phase is independently shippable, reversible, and has an exit criterion.
Ordered by leverage-per-risk. **Do not skip Phase 0** — "prod ready" requires
numbers, not estimates.

### Phase 0 — Measure & set targets  *(no code; blocking prerequisite)*
- Define the real capacity target (see §8 — must be filled in):
  how many **TV boards**, **operator dashboards**, **registered phones**,
  **concurrent calls** at peak?
- Build a small **load generator** (fire `/api/live` + `/api/status` from N
  pseudo-clients) and record, per N: backend CPU, `/api/live` p50/p95 latency,
  cache-hit ratio (after later phases), and — critically — whether **live call
  audio/answer times degrade** under screen load.
- Exit: a one-page baseline (current max N before degradation) + agreed targets.

### Phase 1 — Fan-in caching in the read path  *(highest leverage, lowest risk)*
- Add a short **TTL response cache** to the front-end `/api/*` proxy
  (`serve-console.py`; mirror in `Serve.ps1` for the Windows path) — `/api/live`
  ~1 s, `/api/status` ~2 s, shared across all clients/threads.
- Add a **`/live` TTL cache** in `api/upes_api.py` mirroring the existing
  `/status` cache (~0.8 s) — protects the direct/refresher path too.
- Serve-stale-on-error: on an upstream timeout, return the last good snapshot
  rather than blocking/500ing (boards never blank; handlers never pile up).
- Reversible: caches are additive; delete the block to revert (same pattern as the
  existing `_status_cache` "CACHE" lines).
- Exit: at target N, backend `/api/*` request rate is flat (~1/sec/endpoint), p95
  latency within budget, **zero measurable impact on call handling.**

### Phase 2 — Caching reverse-proxy edge (nginx) = the single endpoint
- Put **nginx** on each Jetson node on `:80`, proxying to the local origin
  (`serve-console.py`/FastAPI). Enable: `proxy_cache` microcache for `/api/*`,
  `gzip` for js/css/html/json, static caching with validation, and correct
  **SSE passthrough** (`proxy_buffering off`) for Phase 3.
- Point all screens + mDNS name at `http://<VIP>` (the VIP already floats via
  keepalived; nginx binds it on the MASTER).
- This *supersedes* Phase 1's front-end cache for scaling (Phase 1's cache stays
  as defense-in-depth / the Windows path). Now caching is declarative and
  observable (nginx cache-status header + logs).
- Exit: single endpoint live; cache-hit ratio > ~95% at target N; gzip verified;
  failover still moves the endpoint with the VIP.

### Phase 3 — Push instead of poll (SSE)  *(optional; lowest latency at any scale)*
- One background poller per node reads the backend at a fixed cadence and
  **broadcasts** snapshots to all boards over a Server-Sent Events stream
  (`/api/stream`); nginx passes it through unbuffered.
- Upstream load becomes **constant** (one poller) no matter how many screens, and
  updates are near-instant. TV/dashboard JS switches from polling loops to an
  `EventSource` (keep polling as fallback).
- Note: long-lived SSE connections need a dedicated broadcaster loop, not a
  per-request thread/runspace pool slot.
- Exit: boards update via SSE with polling fallback; backend poll rate independent
  of client count; graceful reconnect on failover.

### Phase 4 — Get off the emulated VM (native PBX) + admin-endpoint parity
- Move production onto the **native Jetson** path (`deploy/jetson/`), which removes
  the single emulated vCPU floor entirely (native ARM Asterisk, local API, no SSH
  tunnel). This is the largest raw-throughput unlock.
- Close the control-plane gap: reimplement the needed `Serve.ps1` admin actions as
  FastAPI actions (or a single designated admin node), so the Console keeps full
  function on Linux.
- Exit: prod runs on the Jetson pair; Console admin features at parity; the
  Windows/QEMU path demoted to lab/dev.

### Phase 5 — HA hardening (already largely built — validate & extend)
- Validate the existing keepalived VIP + config sync + mDNS failover **on real
  hardware** (the kit is unproven on Jetson per its own disclaimer).
- Ensure nginx + serve-console + FastAPI all follow the VIP cleanly and restart
  under systemd.
- (Optional/future) active/active web via a second LB VIP or DNS-RR **only if
  Phase 0/2 data shows one node can't serve the screen load.**
- (Optional/future) the kit's PJSIP-realtime + replicated-DB path for
  registration-preserving PBX failover — big project, only if call HA demands it.
- Exit: documented, tested failover (graceful + hard power-off) with measured
  recovery time; endpoint + calls survive a dead node.

### Phase 6 — Guardrails, observability, runbook
- **Protect the PBX from the dashboards:** cap origin concurrency; consider
  `nice`/cgroup so console+API can never starve Asterisk CPU; keep serve-stale.
- **Observability:** expose request rate, cache-hit ratio, upstream latency, node
  CPU; alert when call-answer metrics degrade.
- **Security:** API stays loopback-bound; nginx only exposes needed paths; lock
  admin/control endpoints to the designated node/operator network; keep CORS tight.
- **Runbook:** update `deploy/jetson/README.md` with the edge/cache/SSE ops and
  rollback steps.

---

## 6. Component choice for the edge

| Option | Fan-in cache | gzip | Round-robin | SSE passthrough | Fit here |
|---|---|---|---|---|---|
| **nginx** (recommended) | `proxy_cache` microcache | yes | `upstream` | yes (`proxy_buffering off`) | Best all-rounder; one component covers every need |
| HAProxy | weak (not a cache) | limited | excellent | yes | Great LB, but you'd still need a cache — extra part |
| Caddy | via plugin | yes | yes | yes | Simple, but caching needs a module; smaller ecosystem |
| Build cache into `serve-console.py`/FastAPI | in-process TTL | manual | no | manual | Zero new parts (this is Phase 1); not a full edge |

**Recommendation:** Phase 1 builds an in-process cache (no new parts, proves the
win); Phase 2 promotes to **nginx** as the real edge. This gives an incremental,
reversible path rather than a big-bang cutover.

---

## 7. Illustrative configs — DO NOT DEPLOY (design reference only)

> These are sketches to make the plan concrete. They are **not** tuned, tested, or
> meant to be applied as-is. Real values come out of Phase 0.

**nginx microcache + gzip + SSE (concept):**
```nginx
# fan-in: one upstream fetch serves all screens within the TTL window
proxy_cache_path /var/cache/nginx/upes levels=1:2 keys_zone=upes:10m inactive=60s;
upstream origin { server 127.0.0.1:8080; }   # add a 2nd server here to round-robin later

server {
  listen 80;                      # bound on the VIP-holding node
  gzip on; gzip_types text/javascript text/css application/json text/html;

  location = /api/live   { proxy_pass http://origin; proxy_cache upes; proxy_cache_valid 200 1s;  add_header X-Cache $upstream_cache_status; }
  location = /api/status { proxy_pass http://origin; proxy_cache upes; proxy_cache_valid 200 2s;  add_header X-Cache $upstream_cache_status; }
  location = /api/stream { proxy_pass http://origin; proxy_buffering off; proxy_read_timeout 1h; }  # SSE: never cache/buffer
  location /api/          { proxy_pass http://origin; }                                             # POST/exec: never cache
  location /              { proxy_pass http://origin; }                                             # static (origin sets cache headers)
}
```

- **Round-robin later** = add another `server` line to `upstream origin`. Only do
  this with the shared edge cache in front (so it stays fan-in, not fan-out).
- **keepalived** already owns the VIP; nginx just listens on it on the MASTER.

---

## 8. Decisions needed from you (fill before Phase 1)

1. **Capacity targets** — peak counts of: TV boards? operator dashboards? registered
   phones? concurrent calls? ("a hell lot" needs a number to design against.)
2. **Production platform** — commit to the **native Jetson pair** for prod (removes
   the emulated-VM floor), keeping Windows/QEMU as dev? (Strongly recommended.)
3. **Latency expectation for boards** — is ~1–2 s (polling + microcache) fine, or do
   you want true push (SSE, Phase 3) from the start?
4. **Edge component** — OK to adopt **nginx** as the edge (Phase 2), or keep it all
   in-process (build caching into `serve-console.py`) to avoid a new component?
5. **Web active/active?** — Default is active/standby (one node serves, VIP fails
   over). Do you have a screen count that would force both nodes to serve web
   simultaneously? (Usually **no** once caching is in.)

---

## 9. Risks & guardrails (emergency-system specific)

- **Dashboards must never starve calls.** The #1 rule: viewing load cannot degrade
  111. Enforced by fan-in cache (bounds backend load) + concurrency caps +
  serve-stale + (Phase 6) CPU isolation. Phase 0 must *measure* this.
- **Never split PBX state.** No active/active Asterisk without a shared
  registration DB. Active/standby + VIP only.
- **Cache TTL must stay below the poll interval** so boards stay effectively live;
  microcache is measured in seconds, not minutes.
- **Failover of the edge:** nginx + cache live on the node holding the VIP; verify
  the endpoint and in-flight SSE reconnect cleanly after a VIP move.
- **Reversibility:** every phase is additive and revertible (cache blocks deletable;
  nginx removable to fall back to direct `serve-console.py`; SSE has a polling
  fallback). Matches the project's existing `.bak-*` / "REVERSIBLE" discipline.

---

## 10. Bottom line

- **Reverse proxy: yes — a caching nginx edge on the VIP is the centerpiece.** It
  is simultaneously your single endpoint and your fan-in cache.
- **Round-robin: only the stateless web tier, and only with the shared edge cache —
  and you probably won't need it once caching is in.**
- **PBX: never round-robin — active/standby + VIP (you already built this).**
- **Biggest raw unlock: get off the emulated VM onto the native Jetson pair.**
- **Sequence:** measure (P0) -> fan-in cache (P1) -> nginx edge/single endpoint (P2)
  -> optional SSE push (P3) -> native prod + HA validation (P4-5) -> guardrails (P6).
```
