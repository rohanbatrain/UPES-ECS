# UPES-ECS on Jetson Nano — mDNS Name-Failover HA (the SIMPLE, no-VIP path)

Run the UPES campus **Emergency Communication System** (Asterisk PBX + Console) on
**two NVIDIA Jetson Nano boards** as an **active/standby cluster** — but with **no
floating Virtual IP and no Juniper VRRP on the router**. Instead of moving an IP,
the cluster moves a **name**: the active board publishes the mDNS name
**`upes-ecs.local`** and phones (which already point at that name) re-resolve and
re-register to whichever board is active.

> **Status / disclaimer.** This kit is written from standard, proven patterns
> (Asterisk on ARM64 Ubuntu + keepalived VRRP for election/health + Avahi mDNS). It
> is idempotent and passes `shellcheck` / `bash -n`, **but it has not been run on
> real Jetson hardware.** Before go-live you MUST validate on two real Jetson boards
> on the customer's network (see `NETWORK-JUNIPER-MDNS.md`). Treat every command
> below as "expected", then confirm.

---

## 1. What this is — and why (no VIP, no router VRRP)

The system already uses the mDNS name **`upes-ecs.local`** — phones set their SIP
server to that name **once** and never re-point it (see
`deploy/qemu/HOSTNAME-mDNS.md`). This HA variant leans on exactly that mechanism:

- **Both Jetsons run the full stack** (Asterisk, API, Console).
- **keepalived runs VRRP between the two boards** purely for **election** and
  **Asterisk health** (`chk_asterisk`) — **but it owns NO Virtual IP.**
- On becoming **MASTER**, a node's keepalived `notify` hook starts
  `upes-mdns.service`, which **publishes `upes-ecs.local` → that node's own IP** via
  Avahi (`avahi-publish`). On **BACKUP/FAULT** the hook **stops** the service, so the
  node **withdraws** the name.
- Each node advertises **its own IP** as Asterisk
  `external_media_address`/`external_signaling_address`. Because the name always
  resolves to the active node, media/signalling addresses stay correct after
  failover.
- On failover, phones (short SIP registration, ~60 s) **re-resolve `upes-ecs.local`**
  and re-register to the new MASTER.
- **Split-brain is prevented by keepalived**: it elects exactly one MASTER, so
  exactly one node ever publishes the name.

```
                 Voice VLAN (one L2 subnet, spans both switches)
   ┌──────────────────────────────────────────────────────────────────┐
   │  IP phones / Android softphones                                    │
   │      SIP server = upes-ecs.local  ──(re-resolves each REGISTER)──┐ │
   │                                                                  │ │
   │            ┌──────── keepalived VRRP (election + health) ────────┘ │
   │            │            NO VIP — moves a NAME, not an IP           │
   │   ┌────────┴─────────┐                 ┌───────────────────┐       │
   │   │  Jetson PRIMARY   │                 │  Jetson SECONDARY  │      │
   │   │  10.20.30.11      │                 │  10.20.30.12       │      │
   │   │  Asterisk (MASTER)│                 │  Asterisk (BACKUP) │      │
   │   │  publishes name → │                 │  (name withdrawn)  │      │
   │   │  upes-ecs.local=.11                 │                    │      │
   │   └───────────────────┘                 └───────────────────┘      │
   └──────────────────────────────────────────────────────────────────┘
        upes-ecs.local resolves to whichever node is currently MASTER
```

**Why choose this over the VIP variant?** No shared IP to plan, nothing for the
Juniper side to do about a VIP, and it reuses the *exact* mDNS name phones already
trust. The trade-off: it depends on **mDNS working on the voice VLAN** and on phones
being able to resolve `.local` (Linphone does). See §9 (limitations) and the VIP kit
(`../README.md`) if you need an IP-based failover instead.

---

## 2. Files in this kit (`deploy/jetson/mdns/`)

| File | Role |
|---|---|
| `setup-node.sh` | **One-command per-box setup** (`--self`/`--peer`). Runs the base install + the mDNS enabler; hides the `--vip` flag. |
| `enable-mdns-failover.sh` | Per-node enabler. Installs Avahi + the publisher + the no-VIP keepalived. |
| `upes-mdns-publish.sh` | Foreground `avahi-publish` of `upes-ecs.local` → this node's IP. |
| `upes-mdns.service` | systemd unit for the publisher. **Not** enabled at boot — keepalived starts it on MASTER. |
| `upes-mdns-failover.sh` | keepalived `notify` hook: MASTER → start publisher; BACKUP/FAULT → stop it. |
| `keepalived-mdns.conf.tmpl` | keepalived template with **no `virtual_ipaddress`**; rendered per node. |
| `README-MDNS.md` | This runbook. |
| `NETWORK-JUNIPER-MDNS.md` | The simpler Juniper guide (VLAN/QoS/PoE/firewall; no VIP/VRRP). |

It **reuses** the VIP kit's `chk-asterisk.sh` (the enable script copies it if the
installer hasn't). It does **not** modify any VIP-kit file.

---

## 3. IP plan (fill in with the customer)

There is **no VIP** to plan — just the two boards on the voice VLAN.

| Item | Value (example) | Notes |
|---|---|---|
| Voice VLAN ID | `30` | Same L2 segment on both switches. |
| Voice subnet | `10.20.30.0/24` | Both Jetsons live here. |
| Default gateway | `10.20.30.254` | Juniper IRB on the voice VLAN. |
| Jetson **PRIMARY** IP | `10.20.30.11` | `--role primary` (VRRP MASTER). |
| Jetson **SECONDARY** IP | `10.20.30.12` | `--role secondary` (VRRP BACKUP). |
| **mDNS name (phones use this)** | `upes-ecs.local` | Published by whichever node is MASTER. |
| NIC name on the boards | `eth0` | Confirm with `ip -br link`; pass `--iface`. |
| VRRP router id (VRID) | `51` | Must match on both nodes; unique on the segment. |
| DHCP pool for phones | `10.20.30.50–200` | Keep the Jetsons OUT of the pool. |

> Both Jetsons **must** be in the same subnet on the same VLAN, and that VLAN must be
> **L2-contiguous** across both switches — otherwise VRRP election (multicast
> `224.0.0.18`) and mDNS (`224.0.0.251`) can't flow between them.

---

## 4. Install — ONE command per box

> **Prep on both boards** exactly as in the VIP runbook (`../README.md` §4): flash
> JetPack/Ubuntu ARM64, `apt update && upgrade`, set a **static IP** on `eth0` via
> netplan, set the hostname, ensure NTP, and get the repo checkout onto each board.
> You do **not** need the SSH key exchange or the config-sync steps unless you also
> want config replication (see §8).

`setup-node.sh` wraps both install steps so you never touch the word "vip" — you
just tell each box its **own** IP (`--self`) and the **other** box's IP (`--peer`):

**On BOX A (primary):**
```bash
cd /path/to/UPES/deploy/jetson/mdns
sudo ./setup-node.sh --role primary   --self 10.20.30.11 --peer 10.20.30.12 --iface eth0
```

**On BOX B (secondary):**
```bash
cd /path/to/UPES/deploy/jetson/mdns
sudo ./setup-node.sh --role secondary --self 10.20.30.12 --peer 10.20.30.11 --iface eth0
```

That's the whole install. Each box comes up advertising `upes-ecs.local` → its own
IP when it is the live node. Optional: `--host <name>` (default `upes-ecs.local`),
`--vrid N`, `--priority N`.

<details><summary>What <code>setup-node.sh</code> runs under the hood (two steps)</summary>

It calls the base installer then the mDNS enabler. You can run these by hand instead:
```bash
cd /path/to/UPES/deploy/jetson
sudo ./install-jetson.sh --role primary --vip <THIS-BOX-IP> --peer <OTHER-BOX-IP> --iface eth0
sudo ./mdns/enable-mdns-failover.sh --role primary --iface eth0 --host upes-ecs.local
```
The base installer requires a `--vip`; in mDNS mode a node just advertises its **own**
IP, so the wrapper passes `--self` there. `enable-mdns-failover.sh` then overwrites
`external_media_address`/`external_signaling_address` with this node's own IP **and
replaces `/etc/keepalived/keepalived.conf` with the no-VIP config**, so the final state
has no floating VIP.
</details>

`enable-mdns-failover.sh` flags: `--role primary|secondary` and `--iface` are
required; `--vrid N` (default 51), `--priority N` (default 150 primary / 100
secondary), `--peer <ip>` (optional; recorded for reference — VRRP here is multicast
so a peer IP is not required), `--host <name>` (default `upes-ecs.local`). It is
**idempotent** — safe to re-run.

**What the enabler does per board:** apt-installs `avahi-daemon avahi-utils
keepalived`; sets Asterisk `external_media_address`/`external_signaling_address` to
**this node's** `eth0` IP and reloads PJSIP; installs `upes-mdns-publish.sh`,
`upes-mdns-failover.sh`, and `upes-mdns.service`; writes `/etc/default/upes-mdns`
(HOST/IFACE); renders `/etc/keepalived/keepalived.conf` from the **no-VIP** template
(state by role, `track_script chk_asterisk`, `notify …upes-mdns-failover.sh`, **no
`virtual_ipaddress`**); enables + restarts keepalived; leaves `upes-mdns.service`
**stopped** (keepalived starts it on the MASTER).

---

## 5. Verify (per board, then the pair)

```bash
# Services healthy?
systemctl status asterisk keepalived avahi-daemon --no-pager
systemctl is-active upes-mdns          # active ONLY on the current MASTER

# Asterisk answering?
sudo asterisk -rx "core show uptime"
sudo asterisk -rx "pjsip show endpoints" | head

# Who is MASTER? (state file written by the notify hook)
cat /var/lib/upes-ecs/ha/state
```

**The important check — the name resolves to the MASTER, and only the MASTER
publishes it:**
```bash
# From either board or any host on the voice VLAN:
avahi-resolve -4 -n upes-ecs.local     # -> the PRIMARY's IP (10.20.30.11) while it is MASTER
ping -c1 upes-ecs.local

# On the PRIMARY (MASTER):   upes-mdns should be ACTIVE
systemctl is-active upes-mdns          # -> active
# On the SECONDARY (BACKUP): upes-mdns should be INACTIVE
systemctl is-active upes-mdns          # -> inactive
```

**Dial 111** from a registered phone (see §6) — you should reach the emergency flow.
Watch live: `sudo asterisk -rvvv`.

---

## 6. Point phones at the name (with SHORT registration)

Configure phones / Android softphones with:

- **SIP server / registrar / proxy = `upes-ecs.local`**, port `5060/udp`. (This is
  already the provisioned default — see `deploy/qemu/HOSTNAME-mDNS.md` and the
  Linphone template.) **Set it once; never re-point it.**
- **Username / password** = the account from `pjsip_accounts.conf`.
- **Registration expiry: SHORT — 60 seconds.** This is the single biggest lever for
  fast failover: after the name moves, a phone re-resolves `upes-ecs.local` and
  re-registers within one expiry cycle, so **111 recovers in well under a minute**.
  Long expiries (e.g. 3600 s) mean a phone can keep talking to a dead node for an
  hour.

> Phones must be able to resolve `.local` (Linphone does). Fixed SIP devices that
> **cannot** resolve mDNS (some gate phones/speakers) are the documented exception —
> keep them on a raw IP or a controlled-router DNS entry. With no VIP, those devices
> would point at one board's IP and would NOT follow a failover; if you have such
> devices and need them to fail over, use the **VIP variant** (`../README.md`) instead.

---

## 7. TEST FAILOVER (do this before go-live — twice)

**Test A — graceful (stop Asterisk on the active node):**
```bash
# On the PRIMARY (current MASTER):
sudo systemctl stop asterisk
```
Expected within ~5–10 s:
- `chk-asterisk.sh` fails → the primary's VRRP priority drops → the **secondary is
  elected MASTER**.
- The secondary's notify hook **starts `upes-mdns`** and **publishes
  `upes-ecs.local` → the secondary's IP** (`10.20.30.12`); the primary's hook
  **stops `upes-mdns`** (withdraws the name).
- Confirm: `avahi-resolve -4 -n upes-ecs.local` now returns **`10.20.30.12`**;
  `systemctl is-active upes-mdns` is **active** on the secondary, **inactive** on the
  primary; `/var/lib/upes-ecs/ha/state` shows `MASTER` on the secondary;
  `journalctl -u keepalived -f` logs the transition.
- Phones re-resolve + re-register within one expiry cycle; **dial 111 — it still
  works.**

Recover:
```bash
sudo systemctl start asterisk    # on the primary
```
With `nopreempt` (default in the template), the name **stays on the secondary** until
you fail back deliberately — this avoids a second re-registration storm mid-incident.
To fail back on purpose, briefly `systemctl restart keepalived` (or stop Asterisk) on
the secondary during a quiet moment.

**Test B — hard (power off the active node):**
```
Physically power off / pull the network on the node currently publishing the name.
```
Expected: the surviving node is elected MASTER within a few seconds, starts
`upes-mdns`, and **publishes `upes-ecs.local` → its own IP**. Phones re-resolve and
**111 works**. This proves the cluster survives a dead board, not just a stopped
service.

> Record the observed failover time and the phone re-registration time. If 111
> recovery is slow: shorten the phone registration expiry first; then confirm the
> phone's mDNS cache honours the short record TTL (Avahi publishes with a short TTL,
> but some clients cache A records for the OS default — a 60 s SIP re-register forces
> a fresh resolve regardless).

---

## 8. Day-2 operations

- **Who is active:** `cat /var/lib/upes-ecs/ha/state` and `avahi-resolve -4 -n
  upes-ecs.local`.
- **Watch HA health:** `journalctl -u keepalived -u upes-mdns -f`.
- **Config replication (optional):** this mDNS kit does **not** set up config sync.
  If you want accounts/sounds added on the primary to appear on the secondary, use
  the VIP kit's `upes-ha-sync` timer + SSH key exchange (`../README.md` §5, §10) — it
  is independent of the failover mechanism and works fine alongside this variant.
  Otherwise, apply account/sound changes on **both** boards (re-run
  `install-jetson.sh`, or edit + `pjsip reload` on each).
- **DHCP address change on a board:** the publisher **re-reads the IP on each
  (re)start**, so `sudo systemctl restart upes-mdns` (on the MASTER) re-publishes the
  new IP. Also re-run `enable-mdns-failover.sh` to refresh Asterisk's
  `external_media_address` to the new IP. Prefer **static IPs** on the boards to avoid
  this.

---

## 9. Limitations & the zero-touch upgrade path

**By intent, to keep it simple and robust:**

- **SIP registrations do not replicate.** On failover, phones must **re-resolve +
  re-register** to the new MASTER (that's why §6 mandates a short expiry). A call
  **in progress** on the node that dies **will drop** — the caller redials and reaches
  the survivor. Emergency 111 calls are short; acceptable for a simple active/standby.
- **Depends on mDNS on the voice VLAN.** `.local` resolution must work end-to-end:
  same L2 segment, multicast `224.0.0.251:5353` allowed, **no AP client isolation** on
  Wi-Fi (see `NETWORK-JUNIPER-MDNS.md`). Devices that can't resolve `.local` won't
  follow the failover — keep them on a raw IP or use the VIP variant.
- **Client A-record caching.** A phone that caches the old A record beyond its SIP
  re-register could briefly try the dead node. The short SIP expiry forces a fresh
  resolve each cycle, which bounds this; Avahi also publishes a short TTL.
- **`nopreempt`** means failback is manual/observed, not automatic — deliberate, to
  avoid a second mid-incident re-registration.

**Zero-touch upgrade path (design only — NOT built here):** to make failover fully
seamless (no re-registration, no dropped in-progress calls), move to **PJSIP realtime
with a replicated database** (MariaDB Galera / PostgreSQL streaming replication) so
endpoints/auths/aors **and registration contacts** live in a shared DB both nodes
read. After the active node changes, the survivor already has every contact and no
re-REGISTER is needed. Keep keepalived for election. This removes the "re-register on
failover" limitation at the cost of running and monitoring a replicated database.

---

## 10. How this differs from the VIP variant (`../README.md`)

| | **mDNS variant (this kit)** | VIP variant (`../`) |
|---|---|---|
| What moves on failover | The **name** `upes-ecs.local` (Avahi publish/withdraw) | A floating **Virtual IP** (keepalived owns it) |
| keepalived role | **Election + health only** (no `virtual_ipaddress`) | Election + health **+ owns the VIP** |
| Phones point at | `upes-ecs.local` (a name) | The VIP (an IP) |
| Asterisk `external_media_address` | **This node's own IP** (name resolves to active) | The **VIP** (same on both nodes) |
| Network requirement | mDNS multicast + `.local` resolution on the VLAN | Gratuitous ARP on the VLAN (VIP relearn) |
| Fixed devices that can't resolve `.local` | **Won't follow failover** — exception | Follow the VIP automatically |
| Juniper side | VLAN/QoS/PoE/firewall + allow mDNS multicast — **no VIP/VRRP** | Same + pass gratuitous ARP for the VIP |
| Config sync | Optional (reuse VIP kit's `upes-ha-sync`) | Built in (`upes-ha-sync` timer) |

Pick **mDNS** when phones already use `upes-ecs.local`, you want nothing extra on the
router, and every relevant phone can resolve `.local`. Pick **VIP** when you must
support devices that can only be given a raw IP, or you want a mechanism that does not
depend on multicast mDNS. See `NETWORK-JUNIPER-MDNS.md` for the (simpler) network side.
