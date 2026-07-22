# UPES-ECS × Juniper — Live Network Discovery (read-only)

> **What this is.** A snapshot of what is *actually on the wire* right now, extracted
> **read-only and without credentials** from the PBX laptop. No device configuration was
> changed and nothing was logged into. Companion to the planning docs
> ([Juniper-Integration-Plan.md](Juniper-Integration-Plan.md), [Juniper.md](Juniper.md),
> [Juniper-Feature-Catalogue.md](Juniper-Feature-Catalogue.md)) — those say what we *could*
> build; this says what is *present today*.

**Captured:** 2026-07-18 · **From:** laptop `192.168.1.6` (Realtek GbE `Ethernet`, MAC `04:7C:16:A8:06:FA`) · **Method:** ICMP/ARP sweep, TCP port probing, SSH/TLS banner grab, SNMP/NTP/mDNS queries — all unauthenticated. **Scope:** the one subnet the laptop's wired link is on, `192.168.1.0/24`.

---

## 1. Executive summary

- The Juniper kit is **online and healthy** on a **single flat `192.168.1.0/24`** — this is the **"flat pilot"** stage ([Juniper.md](Juniper.md)), **not** the VLAN/Virtual-Chassis architecture from the plan. So we are effectively at **Phase 0**.
- **Confirmed devices:** 1× **Juniper SRX** (gateway/firewall/DHCP/NTP), 2× **Juniper EX2300-C** switches, 1× **HP ProDesk 600 G4** desktop (admin PC), and 1 **unidentified endpoint**. Plus this PBX laptop.
- **The 2× Mist AP32s are NOT on this segment yet** (no ARP presence) — they appear undeployed/unpowered here.
- **Management is wide open to us (read-only-capable):** **NETCONF (830) + SSH (22)** on all three Junos boxes, **J-Web (443)** on the SRX. This is exactly what the plan's app-integration ideas (caller-location, network-health panel, evac-mode) need — the transport is ready today.
- **Good security posture:** SNMP `public` is **off**; J-Web is TLS 1.2/AES256. **To harden:** telnet (23) is **open on both switches**; the network is flat (no segmentation yet).

---

## 2. Topology (as discovered)

```text
                         Internet / uplink (via SRX; WARP VPN active on the laptop)
                                   |
                        ┌──────────┴───────────┐
                        │  Juniper SRX          │  192.168.1.1   (A4:7F:1B:96:85:3B)
                        │  gateway · DHCP · NTP  │  J-Web, NETCONF, SSH
                        │  serial CV3225AX0113   │  OpenSSH_7.5 (older Junos)
                        └──────────┬───────────┘
                                   │  (flat L2 — one subnet, no VLANs)
        ┌──────────────┬──────────┴─────┬───────────────┬─────────────────┐
        │              │                │               │                 │
   ┌────┴────┐   ┌─────┴────┐     ┌─────┴────┐    ┌──────┴─────┐    ┌──────┴──────┐
   │ EX2300-C │   │ EX2300-C │     │ HP ProDesk│    │ endpoint   │    │ PBX laptop  │
   │  #1 .3   │   │  #2 .4   │     │ 600 G4 .2 │    │  .5 (?)    │    │  .6 (this)  │
   │ E8:A5:5A │   │ E8:A5:5A │     │ F4:39:09  │    │ 7C:B6:8D   │    │ 04:7C:16    │
   │ SSH/telnet│  │ SSH/telnet│    │ admin PC  │    │ unknown    │    │ Realtek GbE │
   │ NETCONF   │  │ NETCONF   │    │ (firewalled)│  │ no ports   │    │             │
   │ OpenSSH_9.7│ │ OpenSSH_9.7│   └───────────┘    └────────────┘    └─────────────┘
   └───────────┘  └───────────┘
   (identical units; consecutive MACs .9A:77 / .A4:72)

   NOT SEEN on this segment: 2× Mist AP32  (undeployed / unpowered here)
```

> **Wiring caveat:** whether `.3`/`.4` are cabled to each other, to the SRX, and which physical
> ports the endpoints use is **not** knowable without reading the switch (LLDP / MAC table). The
> diagram shows L3 adjacency (all on one subnet), not the physical cabling. See §7 to close this.

---

## 3. Device inventory

| IP | MAC (OUI) | Identity | Confidence | Open TCP | Fingerprint evidence |
|---|---|---|---|---|---|
| **192.168.1.1** | `A4:7F:1B:96:85:3B` | **Juniper SRX** — gateway, firewall, DHCP server, NTP server | **Confirmed** | 22, 443, 830 | J-Web `<title>Juniper Web Device Manager`, CSP → `download.juniper.net`; TLS cert **CN=CV3225AX0113** (serial); `SSH-2.0-OpenSSH_7.5`; is our DHCP + NTP server |
| **192.168.1.3** | `E8:A5:5A:28:9A:77` (Juniper) | **Juniper EX2300-C** switch #1 | **Confirmed** | 22, 23, 830 | Juniper OUI; NETCONF 830; `SSH-2.0-OpenSSH_9.7 with CVE-2024-6387/39894 fixes` (modern, patched Junos) |
| **192.168.1.4** | `E8:A5:5A:28:A4:72` (Juniper) | **Juniper EX2300-C** switch #2 | **Confirmed** | 22, 23, 830 | Identical banner + sibling MAC to #1 |
| **192.168.1.2** | `F4:39:09:02:F2:6C` (HP) | **HP ProDesk 600 G4 SFF** desktop (admin PC) | **Confirmed** | (none) | mDNS/PTR name `administrator-HP-ProDesk-600-G4-SFF-IDS-APJ.local`; HP OUI; host firewall closed |
| **192.168.1.5** | `7C:B6:8D:20:0E:32` | **Unidentified endpoint** — possibly an AP32, an IP phone, or another PC | Unknown | (none) | Alive at L2 (ARP), answers ICMP, no listening TCP ports probed |
| 192.168.1.6 | `04:7C:16:A8:06:FA` (Realtek) | **This PBX laptop** | self | — | Serve.ps1 console host |

*Ports probed: 21,22,23,25,53,80,110,135,139,143,443,445,514,548,830,902,993,3389,5060,5901,8080,8443,9100.*

---

## 4. Per-device detail

### 4.1 SRX — `192.168.1.1` (the edge, and the most feature-rich box for us)
- **Roles proven live:** default gateway; **DHCP server** (handed this laptop `.6`, 24 h lease, obtained 2026-07-18 12:52 → expires 2026-07-19 12:52); **NTP server** (answered a client query on 123/udp).
  - ⚠️ NTP reply came back **stratum 0** = *not synced to an upstream clock*. Air-gapped means no internet time source; if the SRX is meant to be the campus clock ([plan D4](Juniper-Integration-Plan.md#4-key-design-decisions-decide-these-first)) it likely needs a local-clock (`server 127.127.1.0`) or GPS reference so it serves a *defined* stratum. Worth verifying.
- **Management:** SSH (`OpenSSH_7.5` → older Junos, normal for SRX300/320), **J-Web** on 443 (TLS 1.2 / AES256), **NETCONF** on 830.
- **Serial (from J-Web cert):** `CV3225AX0113`.

### 4.2 EX2300-C ×2 — `192.168.1.3`, `192.168.1.4`
- Two **identical** units (Juniper OUI `E8:A5:5A`, consecutive MACs) — matches the 2× EX2300-C inventory.
- **Modern, CVE-patched Junos** (`OpenSSH_9.7 with CVE-2024-6387,CVE-2024-39894 fixes`) — good; these are current.
- **Management:** SSH (22), **telnet (23) — open**, NETCONF (830). No J-Web observed (443 closed) — either web-management off or not licensed on the switch.
- **Not yet a Virtual Chassis that we can prove from here** — need `show virtual-chassis` (§7). Both having their own management IP on the flat subnet is consistent with **two independent switches** right now (not yet VC'd per plan T0.1).

### 4.3 HP ProDesk 600 G4 SFF — `192.168.1.2`
- A Windows desktop (`administrator-HP-ProDesk-600-G4-SFF-IDS-APJ`), HP OUI, host firewall closed to all probed ports. Likely the **admin/management workstation** on the bench. Not part of the emergency data path.

### 4.4 Unidentified endpoint — `192.168.1.5`
- Alive (ICMP + ARP), OUI `7C:B6:8D`, no listening services. Could be a **Mist AP32** (cloud-managed APs expose no local TCP), an **IP phone**, or another PC. **Resolve via the switch** (`show ethernet-switching table` + `show lldp neighbors` will name it and give its port). Flagged as the top unknown.

---

## 5. Services & management-surface map

| Capability | Where | Status | Use for UPES-ECS |
|---|---|---|---|
| **NETCONF (830/SSH)** | SRX, EX#1, EX#2 | **Open on all three** | The transport for **T3.1 network-health panel, T3.2 caller-location, T3.3 evac-mode, T7.3 config backup** — ready today, just needs a read-only user + collector scripts. |
| **SSH (22)** | all three Junos | Open | `show`/config-as-code, backups. |
| **J-Web (443)** | SRX only | Open, TLS 1.2 | GUI inspection of the SRX. |
| **DHCP** | SRX `.1` | Serving (24 h leases) | Where phone/laptop reservations live ([Juniper.md §2](Juniper.md)). |
| **NTP (123)** | SRX `.1` | Serving, **stratum 0** | Intended campus clock (plan D4) — verify it's actually synced/defined. |
| **DNS** | *WARP on the laptop* (`127.0.2.2`) | n/a | The laptop resolves via **Cloudflare WARP**, not the SRX — so the SRX's own DNS zone is invisible from here. Unrelated to the Juniper gear. |
| **SNMP (161)** | — | `public` **refused** everywhere | Good (not wide open). If we want SNMP/RMON telemetry later it must be explicitly enabled with a community/user. |
| **Telnet (23)** | EX#1, EX#2 | **Open** | **Hardening item** — disable in favour of SSH-only (plan T2.7). |

---

## 6. What this means (readout against the plan)

- **We are at Phase 0 (flat pilot).** No VLANs, no Virtual Chassis, no LLDP-MED/CoS/PoE policy *provable from here*. The whole [Tier 0 fabric](Juniper-Integration-Plan.md#tier-0--foundational-correctness-voice-just-works) (VC, voice VLAN, zero-touch phones, RTP priority, PoE budgeting) is still to build.
- **The differentiators are unblocked at the transport layer.** NETCONF being live on all three boxes means [T3.1/T3.2/T3.3](Juniper-Integration-Plan.md#tier-3--app--juniper-integration-the-differentiators) are buildable now — the only missing pieces are a **read-only Junos user** and the **collector scripts** (`deploy/juniper/collectors/`).
- **The APs are the gap.** With the 2× AP32 absent, the Wi-Fi 111 path isn't live on this segment. Commissioning them ([plan §7](Juniper-Integration-Plan.md#7-air-gapped-mist-commissioning-workflow)) is prerequisite to the wireless tiers.

---

## 7. How to extract *more* (read-only) — the next data we can't get without login/elevation

Everything above was unauthenticated. The deep inventory needs **either** a read-only login **or** a local elevation, both still read-only:

**A. Sniff one LLDP frame (no switch login; needs local admin on the laptop).** The EX sends LLDP every ~30 s on the laptop's port; capturing one reveals the **switch hostname, the exact port the laptop is on, and the switch's mgmt address** — the single highest-value missing datum. Run in an **elevated** PowerShell:
```powershell
pktmon start --capture --pkt-size 0 -c 1
# wait ~35 s for an LLDP frame, then:
pktmon stop
pktmon pcap PktMon.etl -o lldp.pcap    # open in Wireshark; filter: lldp
```
*(Or plug the laptop into a mirror port / use Wireshark directly on ethertype 0x88CC.)*

**B. Read-only Junos login (needs a read-only user/creds).** With a `class read-only` user (or view-only NETCONF), these give the full picture — **all read-only, zero config change:**
```text
# Identity / hardware
show version | show chassis hardware | show chassis routing-engine | show system uptime
# The fabric
show virtual-chassis                     # are .3/.4 a VC or independent?
show vlans | show ethernet-switching table   # what MAC is on which port  -> identifies .5
show lldp neighbors                      # what's plugged into each port (phones/APs/PBX)
show interfaces terse | show spanning-tree bridge
# Power (the 124 W budget)
show poe controller | show poe interface     # draw vs budget, per-port priority
# Edge / services (SRX)
show configuration | display set             # full config as set-commands (for git)
show security zones | show security policies | show security alg status   # is SIP ALG off?
show dhcp server binding | show ntp status | show ntp associations
show configuration system syslog             # where logs go
```

**C. NETCONF collector (read-only, scriptable — the plan's `net_health.py` seed).** PyEZ/`ncclient` against 830 with a read-only user pulls `get_poe_interface_information`, `get_lldp_neighbors_information`, `get_interface_information`, `get_chassis_inventory`, `get_virtual_chassis_information` as structured data — the basis for the Console **/network** panel ([plan T3.1](Juniper-Integration-Plan.md#t31--network-health-on-the-console--tv-board-via-netconf-)).

> None of A/B/C changes anything on the devices. If/when you want the deep pull, provide a
> **read-only** login (or run B yourself and paste the output) and this doc gets a §4 addendum
> with the real hardware/PoE/neighbor data.

---

## 8. Security & hygiene observations (read-only findings)

1. **Telnet open on both EX switches** — plaintext management. Disable, SSH-only (`delete system services telnet`) per plan T2.7.
2. **Flat L2, no segmentation** — every device (incl. the admin PC) shares one broadcast domain with the (future) phones/PBX. Fine for a pilot; the voice/mgmt/guest VLAN split (plan §3) is the growth path.
3. **SNMP `public` refused** — good. Keep it explicit-only if enabled later.
4. **SRX NTP stratum 0** — verify the campus clock is actually defined/synced (air-gap has no internet time).
5. **J-Web exposed on the SRX** — fine on a trusted bench; lock to the mgmt network before go-live (plan T2.7).
6. **Laptop DNS is Cloudflare WARP, not the SRX** — a laptop-side VPN, unrelated to the Juniper gear, but it *did* skew the very first scan (phantom `172.16.16.x` hosts via the default route while Wi-Fi was down). Noted so it isn't mistaken for campus infrastructure.

---

## 9. Open questions to resolve next

- **Identify `192.168.1.5`** (AP32? phone? PC?) — needs switch MAC table / LLDP.
- **Where are the 2× AP32s?** Not on this segment — undeployed, unpowered, or on another port/VLAN.
- **Are `.3`/`.4` a Virtual Chassis or two independent switches?** — `show virtual-chassis`.
- **Physical cabling / port map** — which device is on which `ge-0/0/x` (feeds [T3.2 caller-location](Juniper-Integration-Plan.md#t32--offline-caller-location-by-switch-port-)).
- **SRX config specifics** — SIP ALG state, zones, DHCP reservations, NTP source.

---

*Read-only discovery. No Juniper device was authenticated to or modified. Reproduce with the
techniques in §7 (elevation) or a read-only Junos login. Pairs with the planning trilogy in
`Docs/Juniper*.md`.*
