# UPES-ECS on Jetson Nano — High-Availability Runbook

Run the UPES campus **Emergency Communication System** (Asterisk PBX + Console)
on **two NVIDIA Jetson Nano boards** as an **active/standby cluster** with a
floating **Virtual IP (VIP)**. Phones register to the VIP; if the active board
dies, the standby takes the VIP and calls to **111** keep working.

> **Status / disclaimer.** This kit is written from standard, proven patterns
> (Asterisk on ARM64 Ubuntu + keepalived VRRP + rsync sync). It is idempotent and
> passes `shellcheck`, **but it has not been run on real Jetson hardware.** Before
> go-live you MUST validate on two real Jetson boards on the customer's network,
> with the customer's exact Junos switch/router versions (see
> `NETWORK-JUNIPER.md`). Treat every command below as "expected", then confirm.

---

## 0. Why native Jetson beats the Windows/QEMU VM

| | Windows host + QEMU VM (today) | **Two Jetson Nano (this kit)** |
|---|---|---|
| Asterisk runs | Emulated (TCG), slow — PJSIP reload 60–90 s | **Native ARM64 — no emulation, instant reload** |
| Media/DTMF | Behind QEMU SLIRP NAT; needs `external_media_address` fix, calls drop ~32 s if wrong | Native L2 on the voice VLAN; no NAT hop |
| Availability | Single laptop = single point of failure | **Two boards, VIP failover** — one dies, calls continue |
| Console API | Reached over an SSH tunnel from the host | **Local** on the board (`127.0.0.1:8090`) — no tunnel |
| Power/footprint | A laptop | Two ~10 W appliances, no moving parts |

A Jetson Nano is just an ARM64 Ubuntu computer, so Asterisk installs from `apt`
and runs at full speed. Two of them give **real** redundancy that a single VM
cannot.

---

## 1. What you are building (architecture)

```
                 Voice VLAN (one L2 subnet, spans both switches)
   ┌──────────────────────────────────────────────────────────────────┐
   │                                                                    │
   │   IP phones / Android softphones  ──REGISTER──►  VIP 10.20.30.1    │
   │                                                     ▲              │
   │            ┌──────────────── keepalived VRRP ───────┘              │
   │            │  (VIP lives on whichever node is MASTER)              │
   │   ┌────────┴─────────┐                 ┌───────────────────┐       │
   │   │  Jetson PRIMARY   │  rsync/SSH →    │  Jetson SECONDARY  │      │
   │   │  10.20.30.11      │  (config sync)  │  10.20.30.12       │      │
   │   │  Asterisk (MASTER)│                 │  Asterisk (BACKUP) │      │
   │   │  API :8090        │                 │  API :8090         │      │
   │   │  Console :8080    │                 │  Console :8080     │      │
   │   └───────────────────┘                 └───────────────────┘      │
   └──────────────────────────────────────────────────────────────────┘
```

- **keepalived (VRRP)** puts the **VIP** on the MASTER. A `track_script`
  (`chk-asterisk.sh`) health-checks Asterisk; if it fails, this node's priority
  drops and the BACKUP claims the VIP, sending **gratuitous ARP** so the Juniper
  switches relearn where the VIP lives. Phones then re-register (fast, because we
  use a short registration expiry).
- **Asterisk advertises the VIP** as `external_media_address` on both nodes, so
  media follows the VIP after failover.
- **Config sync** (`upes-ha-sync`) pushes `/etc/asterisk` (esp.
  `pjsip_accounts.conf` = accounts source of truth), sounds, groups, and Console
  runtime data **primary → secondary** on a 2-minute timer and on demand, so a
  new user added on the primary shows up on the standby.

---

## 2. Files in this kit (`deploy/jetson/`)

| File | Role |
|---|---|
| `install-jetson.sh` | One-shot native installer, run once per board with `--role`. |
| `keepalived.conf.tmpl` | VRRP config template; rendered per node by the installer. |
| `chk-asterisk.sh` | keepalived health check — Asterisk unit active **and** answering. |
| `upes-failover-notify.sh` | keepalived notify hook — logs/timestamps state changes. |
| `upes-ha-sync.sh` + `.service` + `.timer` | Config replication primary → secondary over SSH. |
| `serve-console.py` + `serve-console.service` | Linux Console web server on `:8080` (replaces `Serve.ps1`). |
| `README.md` | This runbook. |
| `NETWORK-JUNIPER.md` | Juniper switch/router integration (VLAN, DHCP, QoS, PoE, firewall). |

---

## 3. IP / VIP plan (fill this in with the customer)

Pick one subnet on the **voice VLAN** for both boards **and** the VIP. Example:

| Item | Value (example) | Notes |
|---|---|---|
| Voice VLAN ID | `30` | Same on both Juniper switches (see NETWORK-JUNIPER.md). |
| Voice subnet | `10.20.30.0/24` | Both Jetsons + VIP live here. |
| Default gateway | `10.20.30.254` | Juniper IRB / router on the voice VLAN. |
| **VIP (phones use this)** | `10.20.30.1` | Floating, owned by keepalived MASTER. |
| Jetson **PRIMARY** static IP | `10.20.30.11` | `--role primary`. |
| Jetson **SECONDARY** static IP | `10.20.30.12` | `--role secondary`. |
| NIC name on the boards | `eth0` | Confirm with `ip -br link`; pass `--iface`. |
| VRRP router id (VRID) | `51` | Must match on both nodes; unique on the L2 segment. |
| DHCP pool for phones | `10.20.30.50–200` | Juniper DHCP; keep the VIP + Jetsons OUT of the pool. |

> The VIP and both Jetsons **must** be in the same subnet on the same VLAN, and
> that VLAN must be L2-contiguous across both switches — otherwise VRRP/gratuitous
> ARP cannot move the VIP between boards.

---

## 4. Hardware / OS prep (do on BOTH boards)

1. **Flash the OS.** Use NVIDIA SDK Manager / the JetPack SD-card image (Ubuntu
   20.04 or 22.04, ARM64). Boot each board, finish first-boot setup, create the
   `ubuntu` (or your admin) user.
2. **Update:** `sudo apt-get update && sudo apt-get -y upgrade`
3. **Set a static IP** on the voice-VLAN NIC (`eth0`). On Ubuntu use netplan,
   e.g. `/etc/netplan/01-voice.yaml` on the **primary**:
   ```yaml
   network:
     version: 2
     ethernets:
       eth0:
         addresses: [10.20.30.11/24]
         routes:
           - to: default
             via: 10.20.30.254
         nameservers:
           addresses: [10.20.30.254]
   ```
   Secondary is identical but `10.20.30.12/24`. Apply: `sudo netplan apply`.
   Confirm: `ip -br addr show eth0`.
4. **Hostname (optional but tidy):** `sudo hostnamectl set-hostname upes-ecs-1`
   (and `-2` on the other).
5. **Get the repo onto each board** (git clone, `scp`, or a USB stick) so the
   path `…/UPES/deploy/jetson/install-jetson.sh` exists locally. The installer
   reads all config straight from this checkout.
6. **Time sync:** ensure NTP is on (`timedatectl`) — VRRP and logs want correct
   time.

---

## 5. SSH key exchange (primary → secondary, for config sync)

Config sync PUSHes from the **primary** to the **secondary** over key-based SSH.
Do this once, **as root on the primary**:

```bash
# On the PRIMARY, as root:
sudo ssh-keygen -t ed25519 -N '' -f /root/.ssh/upes_ha        # creates the key pair
sudo ssh-copy-id -i /root/.ssh/upes_ha.pub ubuntu@10.20.30.12  # push pubkey to SECONDARY
# Test:
sudo ssh -i /root/.ssh/upes_ha ubuntu@10.20.30.12 true && echo OK
```

The sync applies changes on the secondary with `sudo`, so the SSH user on the
**secondary** needs passwordless sudo for the apply step. On the **secondary**:

```bash
echo 'ubuntu ALL=(root) NOPASSWD: /bin/bash, /usr/bin/rsync, /usr/bin/asterisk' \
  | sudo tee /etc/sudoers.d/upes-ha
sudo chmod 440 /etc/sudoers.d/upes-ha
```

> The key path/user the sync uses (`/root/.ssh/upes_ha`, `ubuntu`) are written to
> `/opt/upes-ecs/ha/ha.env` by the installer — edit there if your admin user
> differs.

---

## 6. Install — the two commands

Run **on each board**, from inside the repo checkout, as root.

**Primary (becomes VRRP MASTER, priority 150):**
```bash
cd /path/to/UPES/deploy/jetson
sudo ./install-jetson.sh --role primary   --vip 10.20.30.1 --peer 10.20.30.12 --iface eth0
```

**Secondary (becomes VRRP BACKUP, priority 100):**
```bash
cd /path/to/UPES/deploy/jetson
sudo ./install-jetson.sh --role secondary --vip 10.20.30.1 --peer 10.20.30.11 --iface eth0
```

Optional flags: `--priority N` (override VRRP priority), `--vrid N` (VRRP router
id, default 51). The installer is **idempotent** — safe to re-run after a config
change.

What it does per board: apt-installs Asterisk/sox/python3/keepalived/rsync/fail2ban;
lays down Asterisk config from the repo (with CRLF strip); copies the
pre-generated voice prompts incl. language packs; installs the API service
(`:8090`), the Console server (`:8080`), and keepalived for the role; sets
`external_media_address=VIP`; enables fail2ban and Asterisk auto-restart. On the
primary it also enables the `upes-ha-sync` timer.

---

## 7. Verify (per board, then the pair)

```bash
# Services healthy?
systemctl status asterisk upes-api serve-console keepalived --no-pager

# API answering locally?
curl -s http://127.0.0.1:8090/health

# Asterisk answering?
sudo asterisk -rx "core show uptime"
sudo asterisk -rx "pjsip show endpoints" | head

# Console reachable?
#   On the board:   http://<this-board-ip>:8080
#   Via the VIP:    http://10.20.30.1:8080   (served by whichever node holds the VIP)
```

**VIP check — the important one.** The VIP must be on the **primary** and NOT on
the secondary:

```bash
# On PRIMARY  -> should LIST the VIP:
ip -4 addr show eth0 | grep 10.20.30.1
# On SECONDARY -> should NOT list it (empty output is correct):
ip -4 addr show eth0 | grep 10.20.30.1
```

**Dial 111** from a registered phone (see §8) — you should reach the emergency
flow. Watch it live: `sudo asterisk -rvvv`.

---

## 8. Point phones at the VIP (with SHORT registration)

Configure phones / Android softphones with:

- **SIP server / registrar / proxy = the VIP** (`10.20.30.1`), port `5060/udp`.
- **Username / password** = the account from `pjsip_accounts.conf`.
- **Registration expiry: SHORT — 60 seconds** (some clients call it "register
  refresh" or "expiry"). This is the single biggest lever for fast failover: after
  the VIP moves, a phone re-registers within one expiry cycle, so **111 recovers
  in well under a minute**. Long expiries (e.g. 3600 s) mean a phone can appear
  "registered" to a dead node for an hour.

Why short expiry + qualify matters: keepalived moves the VIP in ~3–5 s, but the
phone still has to notice and re-REGISTER to the new MASTER. Short expiry bounds
that. On the server side, PJSIP `qualify` (OPTIONS keepalive) lets Asterisk prune
stale contacts quickly; the failover-notify hook also runs `pjsip qualify` when a
node becomes MASTER to speed convergence.

> DHCP for phones is handled by the Juniper side (see `NETWORK-JUNIPER.md`). Set
> the phones' registrar to the VIP either by hand, by DHCP option, or via your
> provisioning server.

---

## 9. TEST FAILOVER (do this before go-live — twice)

**Test A — graceful (stop Asterisk on the active node):**
```bash
# On the PRIMARY:
sudo systemctl stop asterisk
```
Expected within ~5–10 s:
- `chk-asterisk.sh` fails → primary's VRRP priority drops → **secondary takes the VIP**.
- `ip -4 addr show eth0 | grep 10.20.30.1` now shows the VIP on the **secondary**.
- `journalctl -u keepalived -f` on the secondary logs the MASTER transition;
  `/var/lib/upes-ecs/ha/state` shows `MASTER` on the secondary.
- Phones re-register within one expiry cycle; **dial 111 — it still works.**

Recover:
```bash
sudo systemctl start asterisk    # on the primary
```
With `nopreempt` set (default in the template), the VIP **stays on the secondary**
until you fail it back deliberately — this avoids a second call-drop during a busy
incident. To fail back on purpose, briefly stop Asterisk (or `systemctl restart
keepalived`) on the secondary during a quiet moment.

**Test B — hard (power off the active node):**
```
Physically power off / pull the network on the node currently holding the VIP.
```
Expected: the surviving node claims the VIP within a few seconds and 111 works.
This proves the cluster survives a dead board, not just a stopped service.

> Record the observed failover time and the phone re-registration time. If 111
> recovery is slow, shorten the phone registration expiry first.

---

## 10. Day-2 operations

**Add a user (and propagate it):**
1. Add the account on the **primary** (your existing `Add-UpesUser` flow / edit
   `/etc/asterisk/pjsip_accounts.conf`, then `sudo asterisk -rx "pjsip reload"`).
2. Sync now (or wait ≤2 min for the timer):
   ```bash
   sudo systemctl start upes-ha-sync      # on the primary
   journalctl -u upes-ha-sync -n 30 --no-pager
   ```
   The sync rsyncs `/etc/asterisk`, sounds, groups, and Console data to the
   secondary and reloads its Asterisk, so the new user is registrable on both.

**Update voice prompts / language packs:** regenerate them into
`deploy/asterisk/sounds/**` on the host as you do today, re-run
`install-jetson.sh` on the primary (idempotent — it re-copies the sounds), then
`sudo systemctl start upes-ha-sync` to push to the secondary. `gen-coach-prompts.sh`
remains available on each board as an offline fallback generator.

**Watch HA health:**
```bash
cat /var/lib/upes-ecs/ha/state           # who thinks it is MASTER
journalctl -u keepalived -u upes-ha-sync -f
```

**Backups / retention / healthcheck** run from cron exactly as on the VM (the
installer reuses those scripts).

---

## 11. Limitations & the zero-touch upgrade path

**What this design does NOT do (by intent, to keep it simple and robust):**

- **SIP registrations do not replicate.** On failover, phones must **re-register**
  to the new MASTER (that's why §8 mandates a short expiry). A call **in progress**
  on the node that dies **will drop** — the caller redials and reaches the survivor.
  Emergency calls to 111 are short; this is an acceptable trade-off for a simple,
  bullet-proof active/standby.
- **Config sync is one-way (primary → secondary).** Make changes on the primary.
  If you edited the secondary directly, the next sync overwrites it.
- **`nopreempt`** means failback is manual/observed, not automatic — deliberate, to
  avoid a second mid-incident drop.

**Zero-touch upgrade path (design only — NOT built here):** to make failover fully
seamless (no phone re-registration, no dropped in-progress calls), move to **PJSIP
realtime with a replicated database**:
- Store endpoints/auths/aors and **registration contacts** in a shared DB (MariaDB
  Galera or PostgreSQL with streaming replication) via `res_pjsip` realtime / ODBC.
- Both nodes read the same DB, so a phone registered anywhere is known everywhere
  — after the VIP moves, the survivor already has the contact and no re-REGISTER is
  needed.
- Add PJSIP realtime, point both nodes at the DB VIP, and replicate the DB. Keep
  keepalived for the VIP. This removes the "re-register on failover" limitation at
  the cost of running and monitoring a replicated database. We deliberately did not
  build this; the file-sync + short-expiry approach is simpler and adequate for a
  LAN emergency PBX, and this is the clean path to grow into.

See `NETWORK-JUNIPER.md` for the switch/router side that makes VIP failover and
voice QoS actually work end-to-end.
