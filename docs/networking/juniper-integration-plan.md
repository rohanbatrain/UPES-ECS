# UPES-ECS × Juniper — Integration Plan & Idea Catalogue

**What this is.** An exhaustive, *Juniper-specific* plan for how to fold the actual gear you
have — **1× SRX (300/320), 2× EX2300-C-12P, 2× Mist AP32** — into the UPES Emergency
Communication System so the network stops being "just cabling" and starts being an active,
resilient, *sense-making* part of the emergency platform.

It is deliberately **not generic**. Every idea below names a real Junos/Mist feature, says
whether it works **on your air-gapped LAN with no cloud**, ties back to a real file in this
repo, and is graded by impact/effort so you can pick.

> **Scope note.** This is a *planning + ideas* document — the catalogue, the architecture, the
> decisions, and config *sketches*. It complements (does not replace) the three existing
> hands-on Juniper guides:
> - [Docs/Juniper.md](Juniper.md) — the flat, no-VLAN pilot (current QEMU-on-laptop deployment).
> - [deploy/jetson/NETWORK-JUNIPER.md](../deploy/jetson/NETWORK-JUNIPER.md) — voice VLAN + CoS + PoE + firewall for the **VIP** HA cluster.
> - [deploy/jetson/mdns/NETWORK-JUNIPER-MDNS.md](../deploy/jetson/mdns/NETWORK-JUNIPER-MDNS.md) — same, for the **name-failover** (no-VIP) cluster.
>
> Where those already carry a full `set`-command block (CoS, the SRX zone policy), this plan
> *references* them rather than repeating them, and spends its length on **new** ideas.
>
> **Want the complete menu, not just the curated picks?** See the companion
> [Docs/Juniper-Feature-Catalogue.md](Juniper-Feature-Catalogue.md) — *every* addable Juniper
> feature on your exact hardware, each graded for the air-gap (🟢 offline / 🟡 persisted / 🔴 cloud).

---

## Table of contents

- [0. TL;DR — the shape of it](#0-tldr--the-shape-of-it)
- [1. The hardware you actually have](#1-the-hardware-you-actually-have)
- [2. The one big constraint: air-gapped + a cloud-managed AP](#2-the-one-big-constraint-air-gapped--a-cloud-managed-ap)
- [3. Target architecture](#3-target-architecture)
- [4. Key design decisions (decide these first)](#4-key-design-decisions-decide-these-first)
- [5. The integration catalogue (7 tiers)](#5-the-integration-catalogue)
  - [Tier 0 — Foundational correctness](#tier-0--foundational-correctness-voice-just-works)
  - [Tier 1 — Resilience & self-healing](#tier-1--resilience--self-healing)
  - [Tier 2 — Security & access control at the edge](#tier-2--security--access-control-at-the-edge)
  - [Tier 3 — App ⇄ Juniper integration (the differentiators)](#tier-3--app--juniper-integration-the-differentiators)
  - [Tier 4 — Wi-Fi / Mist AP32](#tier-4--wi-fi--mist-ap32)
  - [Tier 5 — Location, BLE & safety-asset visibility](#tier-5--location-ble--safety-asset-visibility-cloud-dependent-be-honest)
  - [Tier 6 — Van, mesh & multi-site](#tier-6--van-mesh--multi-site)
  - [Tier 7 — Lifecycle, config-as-code & ZTP](#tier-7--lifecycle-config-as-code--ztp)
- [6. PoE budget worksheet (real numbers)](#6-poe-budget-worksheet-real-numbers)
- [7. Air-gapped Mist commissioning workflow](#7-air-gapped-mist-commissioning-workflow)
- [8. What this hardware can't do — honest limits](#8-what-this-hardware-cant-do--honest-limits)
- [9. Phased roadmap](#9-phased-roadmap)
- [10. Proposed repo additions (`deploy/juniper/`)](#10-proposed-repo-additions-deployjuniper)
- [11. Legend & cross-references](#11-legend--cross-references)

---

## 0. TL;DR — the shape of it

**The thesis:** on this campus the network *is* the 111 path. Two AP32s carry the softphones,
two EX2300-Cs power and switch everything, and one SRX guards the edge. Making that "senseful
and impactful" means three moves:

1. **Make the voice fabric bulletproof and zero-touch** — Virtual-Chassis the two EX's into one
   logical switch, auto-onboard phones with **LLDP-MED**, protect the ARP/mDNS failover with
   **DHCP-snooping + Dynamic ARP Inspection**, and give RTP a strict-priority queue everywhere.
2. **Make the network *self-heal and self-report* with zero cloud** — Junos `event-options`
   power-cycles a hung AP/phone by itself; NETCONF/PyEZ feeds a live **Network Health** panel to
   the Ops Console and TV board; syslog and sFlow land in the VM next to the call data.
3. **Wire the app to the network both ways** — the single most impactful, *fully-offline* idea in
   this doc: **locate a 111 caller by the switch port they're plugged into** (IP→MAC→port→room),
   and let an **evacuation** on the PBX flip the network into an "evacuation mode" that frees
   Wi-Fi airtime and prioritises emergency phones.

Top picks by impact (detail in the tiers):

| # | Idea | Tier | Offline? | Impact | Effort |
|---|------|------|:---:|:---:|:---:|
| ⭐⭐ | **Caller location by switch port** (IP→MAC→port→room) | [T3.2](#t32--offline-caller-location-by-switch-port-) | 🟢 | Very high | Med |
| ⭐ | **Network Health panel** on Console/TV via NETCONF | [T3.1](#t31--network-health-on-the-console--tv-board-via-netconf-) | 🟢 | High | Med |
| ⭐ | **Evacuation network mode** (PBX → Junos op script) | [T3.3](#t33--evacuation-network-mode-asterisk--junos-) | 🟢 | High | Med |
| ⭐ | **EX Virtual Chassis** (2 → 1 logical switch) | [T0.1](#t01--virtual-chassis-two-ex2300-c-as-one-switch) | 🟢 | High | Low |
| ⭐ | **LLDP-MED zero-touch phone onboarding** | [T0.2](#t02--lldp-med-zero-touch-voice-vlan--poe--dscp) | 🟢 | High | Low |
| ⭐ | **Self-healing PoE** (`event-options` bounces a dead AP) | [T1.3](#t13--self-healing-poe-junos-event-options) | 🟢 | High | Low |
| ⭐ | **DHCP-snooping + DAI + IP source guard** (protect failover) | [T2.2](#t22--protect-the-failover-dhcp-snooping--dai--ip-source-guard) | 🟢 | High | Low |
| ⭐ | **Mist wireless mesh** = the van's "corner repeaters" | [T6.1](#t61--wireless-mesh--the-corner-repeaters-you-already-planned) | 🟡 | Med | Low |

Legend: 🟢 works on the air-gapped LAN with **no cloud** · 🟡 needs a **brief maintenance
uplink** (commission/update) then persists · 🔴 needs **live cloud**. Full legend at the
[bottom](#11-legend--cross-references).

---

## 1. The hardware you actually have

| Device | Qty | What it is (model-specific) | Its job in UPES-ECS | Watch-outs |
|---|:--:|---|---|---|
| **SRX300 / SRX320** | 1 | Branch services gateway. 8× GE; SRX320 adds a MPIM slot. ~1 Gbps FW / low-hundreds Mbps IPS. Zones, DHCP, NAT, NTP, screens, no HA (single unit). | Edge firewall + DHCP + **LAN-only enforcement** + local NTP master + (optional) Internet during maintenance. | Single unit = no chassis-cluster HA. **SIP ALG must be OFF.** Keep it *out of the 111 audio path* (see §2). |
| **EX2300-C-12P** | 2 | Compact **fanless** L3 switch: 12× 1GbE **PoE+/PoE** (802.3af/at), **124 W** PoE budget each, 2× **SFP+** (10 G) uplinks, single internal PSU. Supports **Virtual Chassis (up to 4), LLDP-MED, 802.1X, DHCP-snooping/DAI, sFlow, CoS (8 queues), RSTP**. | The voice fabric: powers + switches phones, APs and the PBX; carries the voice VLAN; enforces QoS and edge security. | **124 W is not huge** — budget it (§6). Fanless = silent but no PSU redundancy → put it on a UPS. No streaming-telemetry/gNMI on EX2300 — use **sFlow + NETCONF + syslog**. |
| **Mist AP32** | 2 | Wi-Fi 6 (802.11ax), **4×4:4** @5 GHz (2.4 Gbps) + 2×2 @2.4 GHz, a **dedicated 3rd scanning radio** (security/location/synthetic-test), and **BLE** (asset/location). **Cloud-managed only.** Wants **802.3at (19.5 W)**; on 802.3af it drops 5 GHz to 2×2. | Carries the Android/Linphone softphones that dial **111** over campus Wi-Fi. BLE + 3rd radio unlock location/WIDS *when cloud-connected*. | **Managed from the Mist cloud.** Air-gapped, it runs on **configuration persistence** but you lose Marvis/Location/webhooks at runtime (see §2). |

**Roles in one line:** *AP = how students reach 111 over Wi-Fi; EX = powers/switches/prioritises
everything and is your programmable integration surface; SRX = the guard that keeps it
LAN-only and the clock that keeps it honest.*

---

## 2. The one big constraint: air-gapped + a cloud-managed AP

You chose **fully offline / air-gapped**, and the golden rule of this project is *"111 never
depends on AI, internet, or cellular"* ([README](../README.md#golden-rules)). That is exactly
right — **and it collides head-on with the AP32 being a cloud-managed access point.** Facing
that squarely is what keeps this plan honest.

**What actually happens to an AP32 with no Internet:**

- **It keeps serving Wi-Fi.** With **configuration persistence** enabled, the AP stores its full
  config on-board and, even if it can never reach the Mist cloud, it boots and forwards on that
  stored config. Your 111-over-Wi-Fi path *survives* an air-gap. This is the linchpin — **it must
  be turned on during commissioning** (§7).
- **You lose the cloud brain at runtime.** No **Marvis** (AI troubleshooting), no **Location**
  live-view / wayfinding, no **webhooks**, no config changes, no firmware pushes, no SLE metrics.
  The AP marks itself "disconnected" after ~90 s without cloud and just… keeps working, blind.
- **Initial claim/config *requires* the cloud once.** A Mist AP cannot be configured with no
  cloud ever. It must be **commissioned through Mist at least once** (a bench with temporary
  Internet), then deployed offline (§7).

**The consequence for this plan:** ideas that need the cloud (Tier 5 location, Mist webhooks) are
graded 🔴/🟡 and treated as *"if you ever grant a maintenance uplink"* bonuses — **never** as
things 111 relies on. The **weight of the plan is on Junos features on the EX/SRX that need no
cloud at all** (Tiers 0–3, 6–7), plus one offline substitute for the headline cloud feature:
**[T3.2 caller-location by switch port](#t32--offline-caller-location-by-switch-port-)** replaces
"Mist located the caller" with "the switch knows which room the call is plugged into."

**Two honest options to widen what you get** (pick per your security posture):

- **Option A — pure air-gap (what you chose).** Commission APs on a bench, enable persistence,
  deploy. Runtime = zero cloud. Everything 🟢/🟡-*persisted* in this doc works; everything 🔴 does
  not. *This is a perfectly defensible emergency-grade choice.*
- **Option B — occasional maintenance window.** A **firewalled, scheduled** SRX egress (NTP/DNS +
  Mist's IPs only, closed the rest of the time) lets you pull Marvis insights, firmware and
  Location during a maintenance slot, then close it. Voice/111 stays LAN-only the whole time.
  This unlocks the 🔴 tier without weakening the emergency guarantee. *Recommend considering this
  later; not required for go-live.*

> **Design honesty:** if the site is *truly, permanently* air-gapped and you want zero cloud
> dependency **even for commissioning**, a cloud-managed AP is an awkward fit and a controller-
> based/autonomous AP would be philosophically cleaner. But since you already own AP32s, the
> **commission-once + persistence** path is the correct, supported way to make them behave as
> offline emergency Wi-Fi. Just know the trade you're making.

---

## 3. Target architecture

One voice fabric, two Wi-Fi cells, one guarded edge. Works for **both** current deployment
shapes: the single **QEMU-PBX-on-a-laptop** (flat, [Docs/Juniper.md](Juniper.md)) *and* the
**2-Jetson HA cluster** ([deploy/jetson](../deploy/jetson/README.md)).

```text
              Internet  (absent by default; maintenance-window only — Option B)
                  │
             ┌────┴─────┐  ge-0/0/0 = untrust/WAN
             │  SRX300  │  zones: UNTRUST | VOICE | MGMT | GUEST
             │  / 320   │  DHCP · NTP master · LAN-only voice policy · SIP ALG OFF · screens
             └────┬─────┘  ge-0/0/1 → EX (1G copper uplink)
                  │
     ┌────────────┴─────────────────────────────────┐
     │        EX2300-C-12P   VIRTUAL CHASSIS         │   member0 + member1 = ONE logical switch
     │   ┌───────────┐            ┌───────────┐      │   VCP = SFP+ DAC between the two members
     │   │  member0  │═══ VCP ════│  member1  │      │   irb.30 = voice-VLAN gateway (10.20.30.254)
     │   │  124 W PoE│  (10G DAC) │  124 W PoE│      │   CoS: RTP=EF strict-priority everywhere
     │   └─┬───┬───┬─┘            └─┬───┬───┬─┘      │
     └─────┼───┼───┼────────────────┼───┼───┼────────┘
        AP32-A │   │             AP32-B │   │
       (PoE+)  │   └── PBX/Jetson ──────┘   └── wired fixed emergency phones (4xxx)
               │        (LAG ae0 across BOTH members — link + member resilient)
        wired IP phones ── LLDP-MED auto → voice VLAN + PoE class + DSCP  → dial 111

   Wi-Fi:  AP32-A/B  →  SSID "upes-voice" (client isolation OFF, WMM=voice)  → Linphone → 111
                        SSID "upes-guest" (isolated, GUEST VLAN, blocked from voice)
```

**VLAN / IP plan** (reuse the existing convention so nothing else changes):

| VLAN | ID | Subnet | Purpose | Notes |
|---|:--:|---|---|---|
| `voice` | 30 | `10.20.30.0/24` | Phones, APs' voice SSID, PBX/Jetsons, VIP | GW `.254` (irb.30). VIP `.1` / Jetsons `.11/.12` **outside** DHCP. Matches the jetson guides. |
| `mgmt` | 99 | `10.20.99.0/24` | EX VC mgmt, SRX mgmt, AP mgmt IP | SSH-only, RE-protect filter, no user traffic. |
| `guest` | 40 | `10.20.40.0/24` | Guest/student Wi-Fi (non-responders) | **Blocked from voice**, internet-only (or nothing, air-gapped). Isolated SSID. |

The RTP range (`10000–10019/udp`), SIP (`5060/udp`), CardDAV (`5232/tcp`), status API (`:8090`),
Console (`:8080`) all come from this repo — keep the firewall/QoS ranges pinned to
[deploy/asterisk/rtp.conf](../deploy/asterisk/rtp.conf) and
[deploy/asterisk/pjsip.conf](../deploy/asterisk/pjsip.conf).

---

## 4. Key design decisions (decide these first)

These four choices shape everything downstream. Recommendations given; each is reversible.

**D1 — Virtual Chassis vs. two independent switches.**
*Recommend: **Virtual Chassis**.* One config, one management IP, the voice VLAN spans both members
by definition (no manual trunk to get wrong), and the PBX can LAG across members. Trade-off: a VC
is one control-plane failure domain and one upgrade domain. For a 2-switch emergency edge the
operational simplicity wins, *provided* you keep `commit confirmed` discipline and dual VCP links.
(If you prefer hard failure-isolation, run them independent + RSTP + trunk the voice VLAN as the
jetson guides already describe — both are documented paths.)

**D2 — Where does Layer 3 / the default gateway live?**
*Recommend: **gateway on the EX VC** (`irb.30`), SRX as pure edge.* Because the EX VC is your most
available element (two members, on a UPS) and the SRX is a single unit, hosting the voice-subnet
gateway on the EX keeps intra-campus routing alive even if the SRX is down. The SRX then only does
untrust/edge + DHCP-relay/NTP. On the flat pilot there's no inter-VLAN at all, so this only matters
once you split voice/guest/mgmt.

**D3 — 802.1X now, or later?**
*Recommend: **structure for it, enable it after go-live**, and always fail-open to voice for
emergency phones.* A campus swims in unknown devices; port access control is genuinely valuable
(Tier 2). But an emergency system must **never** let a RADIUS outage block 111. So: emergency
phones get **MAC-bypass static allow**, and the port's **server-fail action = permit to voice**.
Needs a **local** RADIUS (FreeRADIUS in the VM/Jetson) since there's no cloud. See [T2.1](#t21--8021x--mac-radius-with-a-local-server-fail-open-for-111).

**D4 — DHCP + NTP location.**
*Recommend: **DHCP on the EX VC IRB or the SRX; NTP master on the SRX** (fallback: a Jetson).*
Air-gapped means **there is no internet clock** — call records, fail2ban, TLS and logs all drift
without a local time source. Make the SRX the stratum-1-ish local NTP master and point every
device (EX, APs, PBX, phones) at it. This is a small change with outsized correctness value.

---

## 5. The integration catalogue

Seven tiers, roughly in dependency order. Each idea: **what it is (Juniper feature)** → **why it
matters for *this* system** → **offline grade** → pointer/sketch. ⭐ = spotlight (config sketch
below the table).

### Tier 0 — Foundational correctness (voice just works)

| ID | Idea | Juniper feature | Why it matters here | Offline |
|---|---|---|---|:---:|
| **T0.1** ⭐ | Virtual Chassis: 2 EX → 1 switch | `virtual-chassis`, VCP on SFP+ | Voice VLAN spans both members automatically; one config; PBX can LAG across members ([T1.2](#tier-1--resilience--self-healing)). | 🟢 |
| **T0.2** ⭐ | Zero-touch phone onboarding | **LLDP-MED** + voice VLAN | Plug an IP phone in → it's auto-placed in VLAN 30, gets its PoE class and DSCP. No per-port hand-config for 4xxx phones. | 🟢 |
| **T0.3** | RTP strict-priority end-to-end | **CoS** (EF/queue 5, CS3 sig) | Voice never drops under load. Full block already written — reuse it. | 🟢 |
| **T0.4** | PoE with emergency priority | `poe interface … priority high`, `guard-band` | If the 124 W budget is tight, emergency phones + APs win contention, best-effort loads get cut first. | 🟢 |
| **T0.5** | Loop/rogue safety on access ports | **RSTP edge + `bpdu-block-on-edge`**, **root-guard**, **storm-control**, **mac-limiting** | A student plugging a cheap switch/loop into a wall port could take down the emergency LAN. These make the edge tamper-tolerant. | 🟢 |
| **T0.6** | LAN-only edge + no SIP ALG + DHCP + NTP | SRX **zones/policies**, `security alg sip disable`, DHCP, `system ntp` | Keeps SIP/RTP inside the campus, off the internet; the ALG-off rule is the classic Juniper voice landmine. Full SRX block already written. | 🟢 |
| **T0.7** | Voice SSID reachability | Mist WLAN **isolation = None** | The #1 Wi-Fi gotcha: client isolation ON = phones can't reach the PBX. Off on responder SSID; guest stays isolated. | 🟡 |

For T0.3 / T0.6 config, use the ready blocks in
[deploy/jetson/NETWORK-JUNIPER.md §5 & §9](../deploy/jetson/NETWORK-JUNIPER.md). New spotlights:

#### T0.1 — Virtual Chassis (two EX2300-C as one switch)
Cable the two members with a **DAC on the SFP+ ports** and make those ports VCPs. Result: one
logical switch, `member0`/`member1`, single config, voice VLAN present on both by nature.

```junos
## On each member's SFP+ ports, convert to Virtual-Chassis ports (run once):
request virtual-chassis vc-port set pic-slot 1 port 0        ## the two SFP+ become VCPs
## Preprovision so member IDs/roles are deterministic:
set virtual-chassis preprovisioned
set virtual-chassis member 0 role routing-engine serial-number <SW1-serial>
set virtual-chassis member 1 role routing-engine serial-number <SW2-serial>
set virtual-chassis no-split-detection            ## 2-member VC: avoid split-brain lockout
```
> With **both** SFP+ used as VCP, uplink to the SRX over a **1 G copper** port — fine, VoIP is
> tiny. If you'd rather keep a 10 G uplink, use *one* SFP+ as VCP (less-resilient single VC link)
> and one as uplink. **Validate exact `vc-port`/PIC syntax on your Junos version.**

#### T0.2 — LLDP-MED zero-touch (voice VLAN + PoE + DSCP)
The EX auto-detects a VoIP phone via LLDP-MED and drops it in the voice VLAN with the right power
and marking — so a fixed 4xxx phone is truly plug-and-play, and a data-PC behind the phone lands
on a separate VLAN.

```junos
set vlans voice vlan-id 30
set vlans data  vlan-id 20
set switch-options voip interface ge-0/0/0.0 vlan voice
set switch-options voip interface ge-0/0/0.0 forwarding-class VOICE-RTP
set protocols lldp interface all
set protocols lldp-med interface all
## data VLAN carries the phone's pass-through PC port:
set interfaces ge-0/0/0 unit 0 family ethernet-switching interface-mode access
set interfaces ge-0/0/0 unit 0 family ethernet-switching vlan members data
```

---

### Tier 1 — Resilience & self-healing

| ID | Idea | Juniper feature | Why it matters here | Offline |
|---|---|---|---|:---:|
| **T1.1** | Gateway redundancy | **IRB on EX VC** (+ optional VRRP if you keep 2 L3 boxes) | Voice-subnet gateway survives an SRX outage (D2). VRRP only if you add a second L3 device. | 🟢 |
| **T1.2** | PBX/Jetson dual-homed LAG | **aggregated-ethernet `ae0` + LACP** across VC members | The PBX keeps a link if one VC member or one cable dies — the thing 111 depends on most gets the most link resilience. | 🟢 |
| **T1.3** ⭐ | Self-healing PoE | **`event-options`** policy + op script | An AP/phone that hangs gets its PoE power-cycled automatically — no human, no cloud. | 🟢 |
| **T1.4** | Local telemetry that survives air-gap | **syslog** + **sFlow** to the VM; **NTP** master | With no cloud, on-LAN syslog/sFlow/NTP are your *only* observability + a correct clock. | 🟢 |
| **T1.5** | Wi-Fi cell survivability | One AP32 **per** VC member + overlapping coverage | Lose a member or an AP and the other still lights the area; put each AP's PoE on a different member. | 🟡 |
| **T1.6** | Safe change control | **`commit confirmed`**, **rescue config**, `commit` archival | Auto-rollback if a change breaks the emergency LAN — already the house style in the jetson guides. | 🟢 |
| **T1.7** | Power continuity | EX2300-C single PSU → **UPS**; PoE priority ([T0.4](#tier-0--foundational-correctness-voice-just-works)) | Fanless/compact means no PSU redundancy; a UPS on each EX keeps 111 up through a blip. | 🟢 (ops) |

#### T1.3 — Self-healing PoE (Junos `event-options`)
When the switch sees an LLDP neighbour drop on an AP/phone port (device hung), run a script that
bounces PoE on just that port. Turns a "walk to the closet and re-plug the AP" incident into a
self-heal — and it needs **no cloud and no Mist**.

```junos
## Sketch — validate script/action syntax for your Junos version.
set event-options policy heal-poe events [ SNMP_TRAP_LINK_DOWN lldpd_neighbor_down ]
set event-options policy heal-poe within 60 trigger on 1
set event-options policy heal-poe then event-script bounce-poe.py arguments interface "{$interface}"
set event-options event-script file bounce-poe.py
## bounce-poe.py: deactivate then reactivate `poe interface <if>` (or set/delete `poe interface <if> disable`),
## with a guard so it only fires for known AP/phone ports and rate-limits itself.
```
> Ship `bounce-poe.py` in the proposed [`deploy/juniper/scripts/`](#10-proposed-repo-additions-deployjuniper).
> Pair with a syslog line so the Console shows *"auto-recovered AP-B PoE at 14:03"* ([T3.4](#tier-3--app--juniper-integration-the-differentiators)).

---

### Tier 2 — Security & access control at the edge

| ID | Idea | Juniper feature | Why it matters here | Offline |
|---|---|---|---|:---:|
| **T2.1** ⭐ | Port access control, fail-open for 111 | **802.1X + MAC-RADIUS**, `server-fail permit`, MAC-bypass | Only known phones/APs onto the voice VLAN; unknown devices → guest/deny. But emergency phones are **never** blocked by a RADIUS outage. | 🟢¹ |
| **T2.2** ⭐ | Protect the failover itself | **DHCP-snooping + Dynamic ARP Inspection + IP source guard** | Your whole HA rests on gratuitous-ARP / mDNS. DAI stops an attacker (or a misbehaving host) ARP-spoofing the VIP or the PBX. Directly hardens the mechanism the jetson guides depend on. | 🟢 |
| **T2.3** | Rogue-port containment | **persistent-MAC**, `mac-limit … action drop`, port-error-disable + auto-recovery | A hijacked wall port can't impersonate 10 phones or flood the segment. | 🟢 |
| **T2.4** | Edge hygiene | SRX **screens** (SYN/ICMP/spoof), guest-zone policy | Blunt the untrust/guest zone; anti-spoof so nothing forges voice-subnet source IPs. | 🟢 |
| **T2.5** | Guest ≠ responders | Guest SSID → GUEST VLAN → SRX, **denied to voice** | Students on Wi-Fi can never reach the PBX/VIP; only responder SSID/phones can. | 🟡 |
| **T2.6** | Encrypt the trunk (optional) | **MACsec** on VCP/uplink | If switch-to-switch cabling crosses an untrusted riser, encrypt it. Usually overkill for a pilot — note and skip. | 🟢 |
| **T2.7** | Management-plane lockdown | mgmt VLAN 99, **RE-protect firewall filter**, SSH-only, no telnet | The EX/SRX/AP mgmt never shares a broadcast domain with users; the RE only accepts mgmt from known hosts. | 🟢 |

¹ RADIUS runs **locally** (FreeRADIUS in the VM/Jetson) — no cloud. If that server is down,
server-fail keeps 111 working.

#### T2.1 — 802.1X + MAC-RADIUS, with a local server, fail-open for 111
```junos
set access radius-server 10.20.30.11 secret "<shared>"        ## FreeRADIUS on the PBX/Jetson (LAN)
set access profile UPES-DOT1X authentication-order [ dot1x mac-radius ]
set protocols dot1x authenticator authentication-profile-name UPES-DOT1X
set protocols dot1x authenticator interface ge-0/0/0.0 supplicant multiple
set protocols dot1x authenticator interface ge-0/0/0.0 mac-radius            ## phones that can't do .1X
## SAFETY: if RADIUS is unreachable, DON'T lock the port — permit to voice so 111 still works:
set protocols dot1x authenticator interface ge-0/0/0.0 server-fail permit
## Emergency fixed phones: static MAC allow / bypass so auth can never block them at all.
```
> **Rule:** emergency phones must be reachable even with the auth server dead. Model this as
> "structure now, switch on after go-live," per [D3](#4-key-design-decisions-decide-these-first).

#### T2.2 — Protect the failover (DHCP-snooping + DAI + IP source guard)
The VIP move (keepalived gratuitous-ARP) and `upes-ecs.local` (mDNS) are *trust-the-LAN*
mechanisms. DAI makes the switch verify ARP against the DHCP-snooping table, so nothing can
poison the segment and steal the VIP or the PBX identity.

```junos
set vlans voice forwarding-options dhcp-security                      ## enable DHCP snooping on voice
set vlans voice forwarding-options dhcp-security arp-inspection       ## Dynamic ARP Inspection
set ethernet-switching-options secure-access-port interface ge-0/0/46 dhcp-trusted   ## PBX/Jetson & uplink = trusted
set ethernet-switching-options secure-access-port interface ge-0/0/0 ip-source-guard  ## phones = source-guarded
```
> **Caveat worth field-testing:** the Jetsons/VIP use **static** IPs, and DAI/IP-source-guard key
> off DHCP leases. Add **static bindings** for the VIP/Jetson/PBX addresses (or mark those ports
> `dhcp-trusted`) so DAI never drops the very traffic it's meant to protect. Test failover with
> DAI on *before* relying on it. **Validate exact `dhcp-security` syntax for your EX/Junos.**

---

### Tier 3 — App ⇄ Juniper integration (the differentiators)

This is where "senseful and impactful" actually lives: the network and the emergency app talking
to each other. All of the ⭐ ideas here are **fully offline** and **unique to having programmable
Junos on the LAN**.

| ID | Idea | Mechanism | Why it matters here | Offline |
|---|---|---|---|:---:|
| **T3.1** ⭐ | Network Health on the Console/TV | **NETCONF/PyEZ** poll → new `/network` route in [Console/Serve.ps1](../Console/README.md) → panel on `tv-ops.html` | Ops board shows which APs/phones are up, PoE draw vs 124 W budget, LLDP neighbours, CoS queue drops — beside the call KPIs. One glass. | 🟢 |
| **T3.2** ⭐⭐ | **Caller location by switch port** | Asterisk caller IP → EX ARP/MAC table (NETCONF) → port → room map | Replaces the cloud "locate the caller" with an **offline** room-level fix for wired 4xxx phones. Enormous for dispatch. | 🟢 |
| **T3.3** ⭐ | **Evacuation network mode** | PBX roll-call/evac → NETCONF op script on EX | On evacuation the *network itself* reconfigures: free Wi-Fi airtime, raise emergency-phone PoE/CoS, quiet the guest SSID. | 🟢 |
| **T3.4** | Network events beside call events | EX/SRX **syslog → rsyslog in the VM** | Correlate *"AP-B down 14:03"* with *"3 missed 111 from Block C 14:04"* in one timeline. | 🟢 |
| **T3.5** | Congestion visibility | **sFlow** → collector in VM → Ops board | See a link saturating before it hurts a call; top-talkers on the voice path. | 🟢 |
| **T3.6** | Mist events into the Console | **Mist webhooks** (AP up/down, client count, location) → `/mist` route | Real-time Wi-Fi health/location on the board — *only when a maintenance uplink exists*. | 🔴/🟡 |
| **T3.7** | Config-as-code for APs | **Mist API** org/site templates; commissioning automation | Reproducible AP builds; scripted claim/provision at staging. | 🟡 |

#### T3.1 — Network Health on the Console / TV board (via NETCONF)
The Console already runs a PowerShell proxy with a runspace pool and a `/status` cache, and shells
to the VM over SSH. Add a **`/network`** route that runs a tiny PyEZ/NETCONF collector against the
EX VC + SRX and returns JSON the existing `tv-ops.html` can render as a "Network" tile.

```python
# deploy/juniper/collectors/net_health.py  (runs on the PBX/Jetson, LAN-only, no cloud)
from jnpr.junos import Device
with Device(host="10.20.99.10", user="upes-ro", ssh_private_key_file="…") as ex:
    poe   = ex.rpc.get_poe_interface_information()      # draw vs 124 W budget, per-port priority
    lldp  = ex.rpc.get_lldp_neighbors_information()     # which phones/APs are actually present
    intf  = ex.rpc.get_interface_information(terse=True)# up/down
    cos   = ex.rpc.get_cos_queue_statistics()           # RTP queue drops = voice pain
# → emit {aps_up, phones_up, poe_watts, poe_budget:124, queue_drops, member_status} as JSON
```
> Read-only user, mgmt VLAN, cached like `/status`. This turns the EX into a first-class data
> source for the Ops board — no SNMP server, no cloud.

#### T3.2 — Offline caller location by switch port ⭐⭐
**The headline offline idea.** When a phone dials 111, Asterisk knows its **contact IP**. The EX
knows **IP → MAC** (ARP on `irb.30`) and **MAC → port** (`show ethernet-switching table`). A port
maps to a **room** — and this repo *already carries a `location` column* in
[provisioning/fixed-devices.csv](../provisioning/fixed-devices.csv) (`Main Gate`, `Hostel B
Corridor`, …). Chain them and the responder sees **"111 from ge-0/0/7 → Hostel B Corridor"** with
**zero cloud**.

```text
Asterisk 111 event ──▶ caller IP (e.g. 10.20.30.63)
        │
        ▼  NETCONF to EX VC
  get-arp-table-information         → 10.20.30.63  = MAC aa:bb:cc:dd:ee:ff
  get-ethernet-switching-table-info → MAC          = interface ge-0/0/7.0
        │
        ▼  join to a port→room map (extend fixed-devices.csv / a new port-map.csv)
  ge-0/0/7  = "Hostel B Corridor, Floor 2"
        │
        ▼  push onto the Ops Console + the TV evacuation board next to the live call
```

- **Wired fixed phones (4xxx):** exact **port-level → room-level** location, fully offline. This is
  precisely why the plan says put real IP phones at fixed emergency points.
- **Wi-Fi softphones:** the EX only sees "behind AP-A's trunk port," i.e. **which AP / zone**, not
  which room. AP-level zone is still useful ("caller is on the Hostel-B AP"). *Room-level for
  Wi-Fi* needs Mist Location (🔴, Tier 5) — an honest gap, and a good reason to keep fixed wired
  phones at critical points.
- **Build:** a `port-map.csv` (port ↔ room) + a collector that the Console calls when a 111 rings;
  surface it on `tv-safety.html`'s evacuation view and the responder's Console.

#### T3.3 — Evacuation network mode (Asterisk → Junos) ⭐
The system already flips the safety TV board into an **evacuation** view during a roll-call. Extend
that trigger to the *network*: a NETCONF op script that, for the duration of the incident, makes the
LAN prioritise life-safety traffic and stops non-essential load.

```text
PBX roll-call/evac starts ──▶ /exec action "evac-network-on" ──▶ NETCONF op script on EX VC:
   • raise PoE priority = high on all emergency-phone + AP ports (nothing gets power-starved)
   • ensure RTP EF scheduler at strict-high (it already is; assert it)
   • rate-limit / disable the GUEST SSID's VLAN uplink to free Wi-Fi airtime + backhaul
   • (optional) shorten phone DHCP/registration timers so re-homing is fast
"all-clear" ──▶ "evac-network-off" ──▶ op script restores the saved baseline (commit rollback N)
```
> Implement as two op scripts (`evac-on.slax/py`, `evac-off`) invoked from the same place the TV
> board is toggled (Console `/exec`). Guard with `commit confirmed` so it always self-restores.
> *This is the kind of cross-domain move you can only make because the switch is programmable and
> on the same LAN as the PBX.*

---

### Tier 4 — Wi-Fi / Mist AP32

Wireless is how most students reach 111. These make the softphone path solid. Grades reflect the
air-gap: the AP config is authored in Mist (🟡) but **persists and runs offline** once pushed.

| ID | Idea | Mist/Wi-Fi feature | Why it matters here | Offline |
|---|---|---|---|:---:|
| **T4.1** ⭐ | Wireless voice priority | **WMM**, DSCP↔WMM map: RTP→**AC_VO**, SIP→AC_VI | The airtime equivalent of wired CoS — without it, one video stream starves a 111 call over Wi-Fi. | 🟡→🟢 |
| **T4.2** | Seamless roaming mid-call | **802.11r / OKC**, band-steering, **min-RSSI** | A caller walking across campus (or the van moving) shouldn't drop the call at a cell edge. | 🟡→🟢 |
| **T4.3** | Survive the air-gap | **Configuration persistence ON** | The single setting that makes 111-over-Wi-Fi keep working with no cloud (see §2, §7). | 🟡→🟢 |
| **T4.4** | Responder vs guest separation | Two WLANs → VLAN 30 / VLAN 40, isolation policy | Responder SSID reaches PBX (isolation off); guest can't (isolation on). Ties to [T2.5](#tier-2--security--access-control-at-the-edge). | 🟡→🟢 |
| **T4.5** | Rogue-AP / WIDS | AP32 **3rd radio** as security sensor | Detects an evil-twin "upes-voice" trying to harvest responders. **But alerting is cloud** → limited offline. | 🔴 |
| **T4.6** | Density at muster points | Airtime fairness, 2.4/5 GHz steering, channel plan | When everyone crowds a muster point during an incident, the AP must not collapse. Plan the RF for the crowd, not the average. | 🟡→🟢 |

#### T4.1 — DSCP↔WMM so voice wins the air
Mark RTP as **EF/DSCP 46** on the PBX (Asterisk already can) and configure the WLAN's QoS map so
EF → **WMM AC_VO** and SIP → AC_VI. Now the AP schedules the 111 call's packets ahead of best-effort
in the RF, matching the wired EF queue. Set this in the Mist WLAN (persists offline). Verify the
2× SFP+/1 G backhaul is never the bottleneck by keeping guest traffic off the voice backhaul
([T3.3](#t33--evacuation-network-mode-asterisk--junos-)).

---

### Tier 5 — Location, BLE & safety-asset visibility (cloud-dependent — be honest)

The AP32's BLE + 3rd radio are genuinely special, and this is where a vendor deck would over-promise.
**On a permanent air-gap these do not run at runtime** (🔴). They become real under **Option B**
(maintenance uplink) or a future Mist-connected phase. Listed so you know the ceiling — and so the
offline substitute ([T3.2](#t32--offline-caller-location-by-switch-port-)) is understood as the
*air-gapped answer* to most of it.

| ID | Idea | Mist feature | The emergency win | Offline |
|---|---|---|---|:---:|
| **T5.1** | Wayfinding to nearest AED/exit/muster | **vBLE virtual beacons + Mist SDK** in the UPES-Safe app | "Guide me to the nearest AED / exit" on a phone during a fire. | 🔴 |
| **T5.2** | Safety-asset tracking | **BLE tags** on AEDs, extinguishers, first-aid kits, the response van, wheelchairs → Live View + `asset-raw` webhook | Always know where the AED is; get alerted if it leaves its zone. | 🔴 |
| **T5.3** | Locate a Wi-Fi 111 caller | **Wi-Fi/BLE client location** → x,y → responder map | Room-level fix for a *Wi-Fi* caller (the gap [T3.2](#t32--offline-caller-location-by-switch-port-) can't close offline). | 🔴 |
| **T5.4** | Proximity messaging | vBLE proximity | Push "you are in a muster zone — check in" as people arrive. | 🔴 |

> **Straight talk:** if location matters to you *and* you want it offline, the realistic answer is
> **wired fixed phones + [T3.2](#t32--offline-caller-location-by-switch-port-)** for room-level,
> and treat Mist Location as a Phase-2 upgrade gated on Option B. Don't design 111 around it.

---

### Tier 6 — Van, mesh & multi-site

The project ships a **disaster-response van with "corner repeaters"** and a future
**Bidholi↔Kandoli** link ([SOP/23](../SOP/23-Mobile-Van-Deployment.md), SOP/20). Juniper fits the
van cleanly; the long-range link honestly does not fit *this* hardware.

| ID | Idea | Juniper feature | Why it matters here | Offline |
|---|---|---|---|:---:|
| **T6.1** ⭐ | The "corner repeaters," done right | **Mist wireless mesh** (AP-to-AP) | Extend the emergency SSID to a courtyard/van with no cable run — exactly the "corner repeater" the van plan describes. Mesh config persists offline. | 🟡→🟢 |
| **T6.2** | Van as a self-contained cell | SRX + one EX + one AP32 as a mobile kit | The van becomes a portable UPES-ECS: its own voice VLAN, DHCP, PoE, Wi-Fi bubble — same configs, different chassis. | 🟢 |
| **T6.3** | Roam between van and campus | Same SSID + 802.11r across both | A responder keeps their call as they move from building Wi-Fi to the van's. | 🟡→🟢 |
| **T6.4** | Bidholi↔Kandoli rooftop link | *(not AP32)* | **Honest:** AP32 is an indoor omni AP, **not** a point-to-point bridge. A rooftop campus link needs outdoor/directional radios — out of scope for this kit. See [§8](#8-what-this-hardware-cant-do--honest-limits). | N/A |

---

### Tier 7 — Lifecycle, config-as-code & ZTP

Make the Juniper layer as reproducible and backed-up as the rest of this repo already is.

| ID | Idea | Juniper feature | Why it matters here | Offline |
|---|---|---|---|:---:|
| **T7.1** | Config-as-code | Per-device `.conf` in `deploy/juniper/` + NETCONF apply/rollback | The switch/router/AP builds live in git next to the Asterisk config; reviewable, diffable, restorable. | 🟢 |
| **T7.2** | Fast switch replacement | **ZTP** (DHCP option 43/66 → local config server on the VM) | Swap a dead EX and it self-configures from a LAN file server — no console jockey, minutes not hours. | 🟢 |
| **T7.3** | Junos config in the nightly backup | NETCONF `get-config` → the existing nightly backup set | The project already backs up nightly; add the switch/router configs so a rebuild is total. | 🟢 |
| **T7.4** | Safe-by-default changes | `commit confirmed`, `rescue`, `system commit archive` | Every network change auto-rolls-back if it breaks 111. Already the documented discipline. | 🟢 |
| **T7.5** | Fold into existing health/admin | Extend [scripts/](../scripts/) health check + Console **Admin** views (Serve.ps1) | One place to see PBX **and** network health; one place to trigger a rebind or a PoE bounce. | 🟢 |

---

## 6. PoE budget worksheet (real numbers)

**124 W per EX2300-C-12P**, and each member powers its own ports. Plan **one AP per member** so the
Wi-Fi survives a member loss, and spread phones.

| Load | Class / draw | Notes |
|---|---|---|
| AP32 (full 4×4) | **802.3at, 19.5 W** | On 802.3af it *works* but 5 GHz drops to 2×2 — **give APs PoE+**. |
| Basic IP desk phone | Class 1–2, ~4–7 W | Fixed 4xxx emergency phones. |
| Video/PoE+ endpoint | up to 30 W | Only if you add door stations / PoE cameras later. |

**Per-member example (member0):** 1× AP32 (19.5 W) + 6× IP phones (~7 W) ≈ **~62 W** → comfortably
inside 124 W. Even both APs on one member (39 W) + 8 phones (56 W) = 95 W fits. **Constraint to
respect:** the EX2300-C-12P can serve full **30 W PoE+ to at most 4 ports** or 15.4 W to at most 8 —
so keep 30 W devices to ≤4/member. Set:

```junos
set poe interface all
set poe management class          ## allocate by detected PoE class
set poe guard-band 5              ## reserve 5 W headroom
set poe interface ge-0/0/46 priority high    ## AP + emergency phones win contention
```
Verify after everything's up: `show poe controller`, `show poe interface`.

---

## 7. Air-gapped Mist commissioning workflow

Because AP32 needs the cloud **once**, do this on a bench with temporary Internet, then deploy
offline. This is the procedure that makes cloud APs behave as offline emergency Wi-Fi.

1. **Bench + temporary uplink.** Put both AP32s on a switch with Internet. Claim them into the Mist
   org (claim code / activation code).
2. **Author the full WLAN config in Mist:** SSID `upes-voice` (isolation **None**), SSID
   `upes-guest` (isolated → VLAN 40), VLAN mapping (voice=30), **WMM/QoS map** (RTP→AC_VO, T4.1),
   **band-steering + 802.11r + min-RSSI** (T4.2), channel/power plan (T4.6), and **mesh** if the van
   uses it (T6.1).
3. **Enable Configuration Persistence** (the critical step — T4.3). Confirm each AP has stored its
   full config on-board.
4. **Update firmware** while you have the uplink (you won't get another chance offline).
5. **Set a static mgmt IP** (VLAN 99) or a DHCP reservation so the AP is addressable offline.
6. **Prove offline behaviour on the bench:** pull the Internet, reboot each AP, confirm it comes
   back on stored config and still bridges `upes-voice` to the PBX. Only then deploy.
7. **Deploy to campus**, power over PoE+ from the EX, one AP per VC member.
8. **(Option B, optional)** If you later allow a maintenance window, the same APs will re-sync to
   Mist, and Marvis/Location/webhooks (Tier 5, T3.6) light up for that window.

> Record this as `deploy/juniper/AP32-COMMISSIONING.md` so it's repeatable for a replacement AP.

---

## 8. What this hardware can't do — honest limits

Naming the ceiling is part of a *senseful* plan.

- **No runtime cloud features on a permanent air-gap.** Marvis, Location/wayfinding (T5.x), Mist
  webhooks (T3.6), dynamic PCAP, SLE dashboards — all need the cloud. They are commissioning-time or
  Option-B only. 111 must not depend on them (it doesn't, by design).
- **AP32 is not a point-to-point bridge.** The Bidholi↔Kandoli rooftop link (T6.4) needs outdoor
  directional radios; this kit can't do a multi-km campus bridge. Mesh (T6.1) extends *local*
  coverage only.
- **Single SRX = no firewall HA.** Acceptable **only because** the flat/L2 voice design keeps the
  SRX out of the 111 audio path — losing the SRX loses Internet/maintenance, not emergencies. If you
  later route voice *through* the SRX, that assumption breaks; keep the gateway on the EX VC (D2).
- **124 W PoE per switch is modest.** Fine for 2 APs + a couple dozen basic phones (§6), but don't
  hang PoE+ cameras/door-stations off these without re-budgeting or adding injectors.
- **EX2300 has only a thin streaming-telemetry sliver, no gNMI.** It *does* support limited **JTI**
  (gRPC dial-out + native-UDP sensors, Junos 20.2R1+: PFE CPU/mem/filter stats, physical-interface
  traffic, RE LACP/chassis-env/LLDP/ARP) but **not gNMI**; **SRX300/320 have no streaming telemetry
  at all**. So lean on **SNMP/RMON + RPM + sFlow(EX)/J-Flow(SRX) + structured syslog** (T1.4, T3.x),
  not model-driven telemetry. Full detail in the [Feature Catalogue](Juniper-Feature-Catalogue.md).
- **Virtual Chassis = one upgrade/control-plane domain.** The convenience (D1) costs you failure
  isolation; mitigate with `commit confirmed`, dual VCP, and staged upgrades — or run independent
  switches if you value isolation more than simplicity.

---

## 9. Phased roadmap

Map the catalogue onto delivery. Each phase is independently shippable and leaves 111 working.

| Phase | Goal | Includes | Outcome |
|---|---|---|---|
| **P0 — Fabric** | Voice just works, zero-touch | T0.1 VC · T0.2 LLDP-MED · T0.3 CoS · T0.4/§6 PoE · T0.5 loop-safety · T0.6 SRX/NTP · T0.7 SSID | Phones auto-onboard; RTP protected; edge is LAN-only; clock is right. |
| **P1 — Resilience** | Survive failures unattended | T1.2 LAG · T1.3 self-heal PoE · T1.4 syslog/sFlow · T1.6 commit-confirmed · T1.7 UPS | A dead AP self-recovers; a cut cable doesn't drop the PBX; changes auto-roll-back. |
| **P2 — App integration** | The differentiators | **T3.1 Network panel · T3.2 caller-location · T3.3 evac-mode · T3.4 syslog-correlation** | The Ops board shows the network; a 111 call shows its room; evacuation reshapes the LAN. |
| **P3 — Access control** | Lock the edge without risking 111 | T2.2 DAI/snooping (do early — cheap, high value) · T2.1 802.1X fail-open · T2.5/2.7 segmentation | Rogues can't spoof the VIP; only known devices on voice; 111 still fails-open. |
| **P4 — Wi-Fi polish + van** | Roaming, density, mobility | T4.1 WMM · T4.2 roaming · T4.6 density · T6.1 mesh · T6.2 van kit | Solid softphone calls on the move; van becomes a portable cell. |
| **P5 — Cloud bonus (opt.)** | If Option B is approved | T3.6 webhooks · T3.7 API-as-code · T5.x location/BLE | Marvis + Location during maintenance windows; asset tracking. |

> Do **T2.2 (DAI/snooping)** in P1/P3-early regardless — it's low-effort and directly protects the
> failover mechanism the whole HA story depends on.

---

## 10. Proposed repo additions (`deploy/juniper/`)

Give the Juniper layer the same config-as-code home the rest of the system has. Suggested layout:

```text
deploy/juniper/
├── README.md                     # index + apply/rollback runbook (commit confirmed discipline)
├── ex-vc/
│   ├── 00-virtual-chassis.conf   # T0.1
│   ├── 10-vlans-irb.conf         # voice/mgmt/guest + irb.30 gateway
│   ├── 20-lldp-med-voip.conf     # T0.2 zero-touch phones
│   ├── 30-cos.conf               # T0.3 (or reuse jetson block)
│   ├── 40-poe.conf               # §6 budget + priorities
│   ├── 50-port-security.conf     # T0.5 + T2.2 DAI/snooping/IP-source-guard
│   └── 60-dot1x.conf             # T2.1 (staged; server-fail permit)
├── srx/
│   ├── 00-zones-policies.conf    # T0.6 LAN-only + screens (reuse jetson block)
│   ├── 10-dhcp.conf              # DHCP/relay
│   └── 20-ntp.conf               # D4 local NTP master
├── mist/
│   ├── AP32-COMMISSIONING.md     # §7 offline commissioning
│   └── wlan-templates.md         # SSID/QoS/roaming/mesh settings (authored in Mist)
├── scripts/
│   ├── bounce-poe.py             # T1.3 self-heal
│   ├── evac-on.py / evac-off.py  # T3.3 evacuation network mode
│   └── ztp/                      # T7.2 zero-touch replacement config server bits
├── collectors/
│   ├── net_health.py             # T3.1 → Console /network
│   ├── caller_locate.py          # T3.2 IP→MAC→port→room
│   └── port-map.csv              # port ↔ room (pairs with provisioning/fixed-devices.csv)
└── backup/
    └── pull-configs.sh           # T7.3 NETCONF get-config into the nightly backup set
```

Console/API touch-points (small, additive):
- **`Console/Serve.ps1`** → add read-only **`/network`** (calls `collectors/net_health.py`) and a
  **`/locate?ip=`** route (calls `caller_locate.py`); render a **Network** tile on `tv-ops.html`
  and a location line on `tv-safety.html`'s evacuation view. Mirror the existing runspace-pool +
  `/status` TTL-cache pattern so it stays snappy.
- **`/exec`** → add `evac-network-on/off` actions wired to the same trigger as the TV evacuation
  board.
- **`scripts/` health check** → include EX/SRX reachability + PoE headroom + AP-up count.

---

## 11. Legend & cross-references

**Offline grades:**
- 🟢 **Works on the air-gapped LAN with no cloud** — Junos/EX/SRX features; the backbone of this plan.
- 🟡 **Needs a brief maintenance uplink to configure, then persists** — Mist WLAN settings authored
  once, run offline (config persistence).
- 🔴 **Needs live cloud** — Mist Marvis/Location/webhooks; commissioning-time or Option-B only; 111
  never depends on these.

**Existing docs this plan builds on:**
- [Docs/Juniper.md](Juniper.md) — flat no-VLAN pilot (current QEMU-on-laptop deployment).
- [deploy/jetson/NETWORK-JUNIPER.md](../deploy/jetson/NETWORK-JUNIPER.md) — VIP-HA VLAN/CoS/PoE/firewall (reuse the CoS + SRX blocks).
- [deploy/jetson/mdns/NETWORK-JUNIPER-MDNS.md](../deploy/jetson/mdns/NETWORK-JUNIPER-MDNS.md) — name-failover variant + the multicast/mDNS notes.
- [deploy/qemu/Test-UpesNetwork.ps1](../deploy/qemu/Test-UpesNetwork.ps1) — the readiness check to extend with switch/AP checks.
- [deploy/asterisk/rtp.conf](../deploy/asterisk/rtp.conf) · [pjsip.conf](../deploy/asterisk/pjsip.conf) — the RTP/SIP ranges that pin the QoS/firewall values.
- [provisioning/fixed-devices.csv](../provisioning/fixed-devices.csv) — the `location` column [T3.2](#t32--offline-caller-location-by-switch-port-) joins against.

**Blanket disclaimer (same as the jetson guides):** every `set`/RPC block here is a *sketch* in
standard Junos/Mist patterns. **Syntax varies by platform and Junos version (EX2300-C ELS, SRX300/
320, AP32 firmware).** Validate on the real gear, apply with `commit confirmed 5`, and test **199
(drill)** before trusting **111**.

---

*Authored as a planning companion to the UPES-ECS Juniper guides. Hardware in scope: 1× SRX300/320,
2× EX2300-C-12P, 2× Mist AP32, deployed fully air-gapped.*
