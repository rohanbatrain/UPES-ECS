# UPES-ECS — QEMU Server VM (Windows host)

A **persistent, headless Linux server** running the full UPES-ECS stack inside **QEMU
on Windows** — installed and run **without admin rights**. This treats the current
Windows node as the server: the VM auto-starts on logon, Asterisk auto-starts in the
VM (`systemd Restart=always`), a live status/control API (`upes-api`) runs in the VM on
port **8090**, and the emergency line has been **validated with a real registered softphone
+ live audio call to 111** (the sole campus emergency number).
The offline panic-coach is on **102**.

> This is the "current node = our server" deployment the WSL test pointed to — but now
> a real, self-contained, reproducible VM instead of a WSL install.

---

## Validated results (this VM)

Proven over SSH into the running VM:

| Check | Result |
|---|---|
| OS / host | Ubuntu 22.04.5, hostname `upes-ecs-pbx-01` |
| Asterisk | 18.10 running; **all 17 contexts** incl. `ctx_responder`; 8 endpoints; 7 helper scripts |
| ERT queue | `ert_emergency_queue` with positions 4110/4111/4112 |
| SIP registration | softphone `1001` registered → `Objects found: 1` |
| Call to 111 | CDR: `1001 → 111`, **ANSWERED, 10s**, `EMERGENCY_CALL`, incident `ERT-20260704-0001` |
| Live RTP | ulaw, ~45 pkts/s streamed to the phone (G.711 rate) |
| Recording | **9.98s WAV, max amplitude 0.605 / RMS 0.060** (real audio) |
| `SHELL()` incident IDs | working (`live_dangerously` enabled) |
| Health check | runs; reports CRITICAL until real answer-point phones register (correct) |

---

## File layout (on the Windows host)

```text
C:\Users\Rohan\qemu\
  qemu-system-x86_64.exe, qemu-img.exe   portable QEMU 11.0 (extracted, no admin)
  images\
    jammy-base.img                       Ubuntu 22.04 cloud image (pristine)
    upes-ecs-server.qcow2                THE SERVER DISK (20G, persistent)
  seed\
    seed.iso (CIDATA)                    cloud-init user-data/meta-data (first boot only)
    data.iso (UPESDATA)                  our config/scripts payload (first boot only)
    serial.log, vm.pid                   runtime
  ssh\upes_key[.pub]                     SSH key to drive the VM
  start-vm.ps1, stop-vm.ps1              lifecycle
```

Repo copies (versioned) live here in [deploy/qemu/](.): scripts + cloud-init seed + `build-vm.ps1`.

---

## Lifecycle

```powershell
# start (headless, backgrounded)
powershell -File C:\Users\Rohan\qemu\start-vm.ps1
# stop (graceful)
powershell -File C:\Users\Rohan\qemu\stop-vm.ps1
```

- **Autostart on Windows logon:** run [`Register-Autostart.ps1`](Register-Autostart.ps1)
  **once** — see the step-by-step [Autostart Setup Notes](Autostart-Setup.md). It installs
  Startup-folder launchers (no admin) that boot the VM and start the **supervised** Console
  (`Run-Console.ps1`, which keeps `Serve.ps1` alive and auto-reloads the dashboard on
  deploy). `start-vm.ps1` is idempotent.
- **Asterisk autostart in the VM:** `systemctl is-enabled asterisk` = **enabled** with
  **`Restart=always`** — it comes up on every VM boot and is auto-restarted if it crashes.
- **Live status/control API in the VM:** the `upes-api` `systemd` unit (`Restart=always`)
  serves `GET /health`, `GET /status`, and the whitelisted `POST /exec` on **port 8090**,
  querying Asterisk locally. The Console reaches it over an SSH tunnel; it binds locally /
  tunnel-only with restricted CORS.
- **Nightly backups:** `upes-ecs-backup.sh` runs from cron and writes snapshots to
  `/var/backups/upes-ecs/`.
- **Persistence:** all state lives in `upes-ecs-server.qcow2` (config, recordings,
  logs, incidents). Reboots keep everything.

---

## Access

```powershell
# shell into the server
ssh -i C:\Users\Rohan\qemu\ssh\upes_key -p 2222 ubuntu@localhost

# Asterisk CLI in the VM
sudo asterisk -rvvv

# SIP: udp/5060 is forwarded to the VM (for a softphone on THIS Windows host)
```

Dev credentials (⚠ change for production): user `ubuntu`, password `upesecs`, plus the
SSH key. The cloud-init `user-data` sets these.

---

## Van-laptop LAN networking (this deployment)

Treating the Windows host as **the van's PBX laptop on the network** (Wi-Fi
`192.168.1.16/24`, gw `.1`). The VM is set up **LAN-facing without admin** using
QEMU port-forwarding + Asterisk-behind-NAT config (identical to running Asterisk
behind a home/office router):

- **QEMU forwards on all interfaces** (`start-vm.ps1`): `udp 0.0.0.0:5060` (SIP) +
  `udp 0.0.0.0:10000-10019` (RTP) → reachable on the laptop's LAN IP. SSH stays host-local.
- **Asterisk advertises the LAN IP** (`pjsip.conf` transport):
  `external_media_address` / `external_signaling_address = 192.168.1.16`,
  plus `rtp_symmetric=yes` + `force_rport=yes` on endpoints (mobile/Wi-Fi NAT traversal).
- **RTP pinned** to `10000-10019` (`rtp.conf`) so it matches the forwarded range.

**Proven:** a softphone registering to **`192.168.1.16:5060`** (not localhost) → `200 OK`,
contact bound at `192.168.1.16`, call to **111** → live RTP (G.711, ~48 pkts/s). The van
laptop **is a working PBX on the network.**

### The one remaining step for OTHER phones on the LAN — Windows Firewall (admin, once)

Inbound is blocked by default and adding a rule needs admin. Run **once, elevated**:

```powershell
New-NetFirewallRule -DisplayName "UPES-ECS SIP-RTP" -Direction Inbound -Protocol UDP `
  -LocalPort 5060,10000-10019 -Action Allow -Profile Any
```

After that, any phone on the LAN registers to **`192.168.1.16` : port `5060`** and calls 111.

### Recommended for a real van

- **Static IP / DHCP reservation** for the laptop so `external_media_address` stays valid (Wi-Fi DHCP can change it — update the transport if the IP changes).
- **Bridged networking (cleanest):** install a Windows **TAP adapter** (one-time admin), then swap `start-vm.ps1`'s `-netdev user,...` for `-netdev tap,...`. The VM then gets its **own** LAN IP, sees real phone IPs, and needs no external-address/RTP-range tricks. Config + dialplan are identical.
- **Native Linux / the van PBX:** running this same disk/config on real Linux hardware avoids QEMU + NAT entirely — the production target ([Blueprint 04](../../Blueprint/04-Network-and-Deployment.md), [SOP 23](../../SOP/23-Mobile-Van-Deployment.md)).

| Mode | Phones reach it via | Admin needed | Status |
|---|---|---|---|
| **QEMU port-forward** *(now)* | laptop LAN IP `192.168.1.16:5060` | firewall rule (once) | ✅ configured + proven |
| **Bridged (TAP)** | VM's own LAN IP | TAP driver (once) | documented |
| **Native Linux / van** | server/van LAN IP | — | production target |

---

## Dynamic across routers (moving the van laptop to another network)

The **only** thing that changes when you plug into a different router / Wi-Fi is the
laptop's LAN IP that Asterisk advertises for media. QEMU's forwards bind **all**
interfaces and the firewall rule is **port-based**, so nothing else changes.

**Server side — handled automatically.** `start-vm.ps1` runs [`Set-UpesLanIp.ps1`](Set-UpesLanIp.ps1)
on every boot: it detects the current LAN IP and rebinds Asterisk (`external_media_address`
+ PJSIP reload). So on a new network, just start the laptop. Switched networks **while
running**? Rebind live — three ways, all equivalent, **no internet required** (works on a
mobile OTG hotspot that hands out DHCP but has no upstream):

```powershell
powershell -File C:\Users\Rohan\qemu\Set-UpesLanIp.ps1        # 1) command line — auto-detects the new IP
```

- **2) Double-click** [`Rebind-Network.cmd`](Rebind-Network.cmd) on the laptop (for the van
  operator — no PowerShell knowledge needed; prints the new IP, then waits).
- **3) From the Console** → **Network** section → **“Rebind PBX to this network”** button
  (confirm-before-run). It runs host-side (only the host knows its own LAN IP), returns
  immediately, and the new IP appears on the wallboard automatically within seconds. The
  PJSIP reload finishes in ~60–90 s on the emulated PBX **without freezing the dashboard**.

> **OTG / no-internet detection.** `Set-UpesLanIp.ps1` picks the LAN IP from the default
> route first (the normal case — DHCP still gives a gateway on most hotspots). If there is
> **no** default route at all, it falls back to the active private-range interface (Wi-Fi
> preferred, then USB-tether/Ethernet), skipping virtual switches (WSL/Hyper-V/Docker). Pass
> `-LanIp <address>` to override.

**Phone side — so you don't reconfigure the Androids each move. Pick one:**

| Approach | How | Trade-off |
|---|---|---|
| **Static IP / DHCP reservation** | Reserve a fixed IP for the laptop on each router you use | Phones use one known IP; one setting per router |
| **Bridged + mDNS hostname** *(best, zero-touch)* | Bridged NIC (TAP, one-time admin) + Avahi in the VM → phones register to `upes-ecs-pbx-01.local` | No per-network config at all; needs the TAP install once |
| **Update phones per move** | Set the SIP server to the new IP on the few ERT Androids | Fine for a handful of answer points |

**Check on every new router (~30 s):**
- [ ] Wi-Fi **client isolation OFF** (AP isolation blocks phone ↔ PBX — the #1 gotcha)
- [ ] The laptop's **firewall rule** is present (one-time per laptop)
- [ ] Phones and laptop are on the **same subnet**

> **Truly zero-touch = bridged networking.** With a TAP adapter the VM pulls its **own**
> DHCP lease from each router and advertises its own IP automatically — no `Set-UpesLanIp`,
> no external-address, no port-forwards. That (or native Linux / the van's own router) is
> the real multi-network answer; the auto-rebind above is the no-admin equivalent for today.

---

## Production hardening

**Already done (in this VM):**

- [x] **Asterisk `Restart=always`** — crash auto-recovery on top of boot autostart.
- [x] **`upes-api` service** on :8090 (`Restart=always`) — live status/control, tunnel-only.
- [x] **Nightly backups** — `upes-ecs-backup.sh` + cron → `/var/backups/upes-ecs/` (per [SOP 11](../../SOP/11-Backup-Restore-Procedure.md)).
- [x] **Boot autostart of the VM + Console** — Startup-folder launchers, **no admin required**
  (one-time [`Register-Autostart.ps1`](Register-Autostart.ps1); see [Autostart Setup Notes](Autostart-Setup.md)).
  The Console runs **supervised** (`Run-Console.ps1` self-heals `Serve.ps1`) and auto-reloads on deploy.
- [x] **fail2ban** — Asterisk **and** sshd jails active.
- [x] **Real all-campus paging PIN** set (no placeholder).
- [x] **Coach / emergency TTS prompts generated** — the offline panic-coach (`102`) and the `111` press-1 flow ship real generated audio (pico2wave/sox), not silent placeholders.
- [x] **SSH sped up** — `UseDNS`/GSSAPI off, `motd-news` disabled.

**Still remaining:**

- [ ] **Change** the `ubuntu` password + regenerate the SSH key (rotate the dev defaults).
- [ ] Switch to **bridged networking** (or deploy on real hardware/van) so LAN phones connect.
- [ ] Enable **WHPX** acceleration (needs admin: `Enable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform`) — turns slow TCG emulation into near-native speed. Then change `-accel tcg` → `-accel whpx,kernel-irqchip=off` in `start-vm.ps1`.
- [ ] Give the VM more resources for load (`-m 4096 -smp 4`).
- [ ] Add a **UPS** on the Windows host (emergency system — see [Risk R1](../../SOP/21-Risk-Register-and-Gaps.md)).
- [ ] Replace generated TTS with **studio-recorded prompts** where desired ([SOP 28](../../SOP/28-Voice-Prompt-Scripts.md)).
- [ ] Register the ERT answer-point Androids as the `4101/4110/4111` positions; run the [Pilot Test Plan](../../SOP/17-Pilot-Test-Plan.md).

---

## Rebuild from scratch

Everything is reproducible via [build-vm.ps1](build-vm.ps1) (downloads QEMU + Ubuntu
image, builds the cloud-init ISOs from [seed/](seed/), boots). The VM configures itself
on first boot from the real repo [config/](../../config/) + [scripts/](../../scripts/)
baked into `data.iso`.

> The QEMU VM proves the **whole server**, end to end, on this node. For campus
> production, the same disk/config runs on real Linux hardware or the van — see the
> [Blueprint](../../Blueprint/00-README.md).
