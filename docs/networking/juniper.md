# UPES-ECS on Juniper — simple flat network (no VLANs)

This is the **fresh, keep-it-simple** setup: all emergency phones **and** the PBX laptop on
**one flat subnet**, Juniper switches acting as plain L2 switches, one Juniper router as the
gateway/DHCP. No VLANs. That is a perfectly good design for an emergency pilot — and it is the
*easiest* one to make bulletproof.

**Why flat is actually the reliable choice here:** on a single subnet the phones and the PBX
laptop talk **directly at layer 2** — the router/firewall is never in the SIP or RTP path. So the
two classic Juniper voice landmines (the SRX **SIP ALG** and inter-VLAN ACLs) simply don't apply.
And `upes-ecs.local` (mDNS) works because it's one broadcast domain. Do the four things below and
it works 100%.

> The PBX is a QEMU VM on the laptop; phones reach it at the **laptop's LAN IP** (SIP `5060/udp`,
> RTP `10000–10019/udp`, CardDAV `5232/tcp`). The stable name `upes-ecs.local` follows that IP
> automatically — see [../deploy/qemu/HOSTNAME-mDNS.md](../deploy/qemu/HOSTNAME-mDNS.md).

---

## The 4 things to get right

### 1. Wi-Fi **client isolation OFF** — the one setting that silently breaks everything
On the same subnet as the PBX, "client/AP isolation" blocks a phone from reaching the laptop.
Turn it **off** on the SSID your responders use. Keep **guest** Wi-Fi isolated and blocked from
the PBX.
- **Juniper Mist APs:** WLAN → the SSID → **Isolation = None** (do not use "Isolate clients").
- Any other AP: disable "client isolation" / "AP isolation" / "station isolation" on that SSID.

### 2. Give the PBX laptop a **stable IP** (DHCP reservation)
Reserve the laptop's IP on the Juniper router keyed to its Wi-Fi/Ethernet MAC. Then the IP never
moves on campus. (`upes-ecs.local` would follow a change anyway, but a reservation also pins the
raw-IP fallback.) Find the laptop MAC in PowerShell: `Get-NetAdapter | ft Name,MacAddress,Status`.

### 3. Switch **port hygiene** (Juniper EX)
No port isolation on the ports where phones/APs/laptop connect; RSTP **edge** so a rebooted phone
comes up instantly instead of waiting ~30 s for spanning tree; PoE for the APs.

### 4. Only if your router is an **SRX in the path:** disable SIP ALG
On a flat subnet the SRX is **not** in the phone↔PBX path, so this usually doesn't apply. But if
any voice traffic does traverse it, the ALG will mangle SIP — disable it (below).

---

## Copy-paste Junos config

> Replace interface names (`ge-0/0/x`), the subnet, and the MAC with your site's values.
> Apply on the console/SSH, review with `show | compare`, then `commit`.

### EX switch — access ports (phones / APs / the PBX laptop)
```junos
# Plain access ports on the default VLAN (no VLANs, no isolation)
set interfaces ge-0/0/0 unit 0 family ethernet-switching interface-mode access
set interfaces ge-0/0/0 unit 0 family ethernet-switching vlan members default
# Fast bring-up: treat access ports as spanning-tree edge, and guard against loops
set protocols rstp interface ge-0/0/0 edge
set protocols rstp bpdu-block-on-edge
# PoE for the ports feeding Wi-Fi APs (skip on the laptop/phone ports if not PoE)
set poe interface ge-0/0/0
```
Repeat the interface lines for each access port (or use an interface-range).

### Juniper router — DHCP reservation for the laptop
```junos
# Legacy simple DHCP server (works on many SRX/EX). Pool + a fixed lease for the PBX laptop.
set system services dhcp pool 172.16.16.0/24 address-range low 172.16.16.100 high 172.16.16.200
set system services dhcp pool 172.16.16.0/24 router 172.16.16.1
set system services dhcp static-binding aa:bb:cc:dd:ee:ff fixed-address 172.16.16.20
```
(Newer Junos uses `access address-assignment pool … family inet … host … hardware-address …`;
either is fine — the point is a fixed IP for the laptop's MAC.)

### SRX — disable SIP ALG (**only if the SRX is in the voice path**)
```junos
set security alg sip disable
commit
# verify:
run show security alg status | match sip     # expect: SIP : Disabled
```

---

## Prove it works (before you rely on it)

On the **PBX laptop**, run the built-in readiness check — it verifies the LAN IP, the hostname,
SIP/RTP/CardDAV reachability, and the firewall, and prints the exact fix for anything red:

```powershell
powershell -File deploy\qemu\Test-UpesNetwork.ps1
```

Then, on a **phone on the responder Wi-Fi**:
1. It registers with SIP server `upes-ecs.local` (or the reserved IP) — green/registered.
2. Dial **199** (drill) → hear the prompt → two-way audio.
3. The campus phonebook appears in Contacts (CardDAV) with ERT/responder/staff names.
4. Reboot the phone → it re-registers on its own (proves the edge-port + isolation settings).

Quality targets (latency < 150 ms, loss < 1 %, call setup < 3 s) and the full pre-rollout test
list are in [../Blueprint/04-Network-and-Deployment.md](../Blueprint/04-Network-and-Deployment.md).

---

## Windows firewall on the laptop (once)

Phones are blocked until the laptop allows them in. The installer adds these when run elevated;
otherwise run once in an **admin** PowerShell:
```powershell
New-NetFirewallRule -DisplayName 'UPES-ECS SIP-RTP' -Direction Inbound -Protocol UDP -LocalPort 5060,10000-10019 -Action Allow -Profile Any
New-NetFirewallRule -DisplayName 'UPES-ECS CardDAV' -Direction Inbound -Protocol TCP -LocalPort 5232 -Action Allow -Profile Any
```

---

## Growing later (optional, not needed now)
A dedicated **voice VLAN** and QoS become worthwhile once the network carries a lot of other
traffic — see the campus topology and VLAN notes in
[../Blueprint/04-Network-and-Deployment.md](../Blueprint/04-Network-and-Deployment.md). Not
required for the flat pilot.

## Future — multi-campus link
Juniper can provide **site-to-site wireless connectivity from rooftop, Bidholi to Kandoli, without
centralised infra** — the later point-to-point bridge phase (Blueprint §3 / SOP 20).
