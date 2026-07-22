# UPES-ECS × Juniper — Complete Feature Catalogue (the full menu)

**Volume II — the exhaustive enumeration.** Where [Docs/Juniper-Integration-Plan.md](Juniper-Integration-Plan.md)
is the *curated* plan (top ideas, tiered by impact), **this** document is the *complete menu*: every
Juniper feature on your three device types that could plausibly be switched on, graded for the
**air-gap**, and mapped to the emergency-calling system. Use it to pick — nothing here is
prescriptive on its own.

**Your hardware:** 1× **SRX300/320** · 2× **EX2300-C-12P** · 2× **Mist AP32** · **fully
air-gapped** (no Internet at runtime; APs commissioned once via Mist then run on config
persistence).

### How to read this

Every row is: **feature → Junos/Mist config family → supported on *your* model? → works on the
air-gapped LAN? → one-line emergency relevance.** Grading legend:

| Grade | Meaning |
|---|---|
| 🟢 **yes** | Runs entirely on-box / against on-prem servers. **No cloud, ever.** The backbone. |
| 🟡 **persisted** | Authored in Mist cloud once (bench), then held by config-persistence and enforced locally offline. |
| 🟠 **local-collector** | Works offline **only if** you run the receiver (syslog/sFlow/RADIUS/NTP) on the LAN — which we do (the VM/Jetson). |
| 🔴 **needs-cloud** | Requires live cloud (Mist) or a subscription feed. Commissioning-time / Option-B only. **111 never depends on these.** |
| ⛔ **needs-2nd-unit / n-a** | Needs hardware you don't have (2nd SRX, Mist Edge) or isn't on this model. |

> **Licensing note (EX):** several EX L3/multicast features need the **EFL/AFL** entitlement
> (OSPF, VRRP, PIM/IGMP-routing, RPM, BFD, RIPng). These are **honour-based, work fully offline**
> (no call-home). Buy the entitlement; no Internet needed to use it.

**Jump to:** [Part A — EX2300-C](#part-a--ex2300-c-12p-the-switch) · [Part B — SRX300/320](#part-b--srx300320-the-firewall--router) · [Part C — AP32](#part-c--mist-ap32-the-wi-fi) · [Part D — Automation & telemetry](#part-d--automation-telemetry--integration-glue-cross-device) · [Part E — New emergency integrations this research surfaced](#part-e--new-emergency-specific-integrations-this-research-surfaced) · [Part F — Recommended air-gapped feature set](#part-f--the-recommended-air-gapped-feature-set-what-to-actually-turn-on) · [Part G — Skip list, hard limits & unlock-upgrades](#part-g--skip-list-hard-limits--unlock-upgrades)

---

## Part A — EX2300-C-12P (the switch)

The programmable heart of the design: 12× 1G PoE+ (124 W), 2× SFP+, 8 CoS queues, Junos ELS.

### A1 · Layer 2 switching
| Feature | Config family | On EX2300-C? | Air-gap | Emergency relevance |
|---|---|---|:--:|---|
| 802.1Q VLANs (4093 cfg / 2044 active) | `vlans` | yes | 🟢 | Separate voice / ERT / softphone-Wi-Fi / mgmt |
| Voice VLAN (auto) | `switch-options voip` | yes | 🟢 | Auto-place IP phones + apply CoS |
| MAC-based VLAN | `switch-options`/`vlans` | yes | 🟢 | Dynamic phone→voice-VLAN by MAC |
| Private VLAN / port isolation | `vlans … no-local-switching` | yes | 🟢 | Phones reach only gateway/PBX, not each other |
| Q-in-Q / 802.1ad | `input/output-vlan-map` | yes | 🟢 | Transport stacking (rarely needed) |
| L2 Protocol Tunneling | `protocols layer2-control` | yes | 🟢 | Tunnel STP/LLDP across a provider VLAN |
| RSTP / MSTP (64) / VSTP (253) / STP | `protocols {rstp,mstp,vstp,stp}` | yes | 🟢 | Loop-free edge; fast reconverge |
| **Redundant Trunk Group (RTG)** | `switch-options redundant-trunk-group` | yes | 🟢 | STP-free **sub-second uplink failover** for signaling |
| **LAG / LACP** (128 groups, cross-member) | `interfaces aeX` | yes | 🟢 | Bonded, member-resilient uplink to PBX/core |
| LLDP | `protocols lldp` | yes | 🟢 | Discover phones/APs; feeds location ([E](#part-e--new-emergency-specific-integrations-this-research-surfaced)) |
| **LLDP-MED** | `protocols lldp-med` | yes | 🟢 | **Zero-touch** phone: voice-VLAN + PoE + DSCP |
| MAC limiting / allowed-MAC | `interface-mac-limit` | yes | 🟢 | Cap MACs/port; block MAC-flood DoS |
| **Persistent (sticky) MAC** | `persistent-learning` | yes | 🟢 | Pin known phone MAC; block rogue swap |
| **MAC move / notification** | `mac-notification`, `mac-move-limit` | yes | 🟢 | **Alert when a fixed emergency phone is unplugged/moved** |
| MVRP (802.1ak) | `protocols mvrp` | yes | 🟢 | Dynamic VLAN registration on trunks |
| IRB / RVI | `interfaces irb` | yes | 🟢 | Inter-VLAN gateway for voice/data |
| Jumbo / flow-control / EEE | `interfaces … mtu/flow-control/eee` | yes | 🟢 | Tuning knobs (not needed for RTP) |
| GVRP | — | **no** (ELS→MVRP) | ⛔ | Use MVRP |

### A2 · Layer 3 / routing
| Feature | Config family | On EX2300-C? | Air-gap | Emergency relevance |
|---|---|---|:--:|---|
| Static routes (v4/v6) | `routing-options static` | yes (base) | 🟢 | Simplest, most robust for air-gap |
| Routing policy | `policy-options` | yes | 🟢 | Redistribution / filtering |
| OSPFv2/v3 | `protocols ospf(3)` | yes (**EFL**) | 🟢 | Campus IGP if multi-hop L3 |
| RIP / RIPng | `protocols rip(ng)` | yes (RIPng=EFL) | 🟢 | Tiny dynamic routing |
| **DHCP server (local)** | `system services dhcp-local-server` | yes | 🟢 | Address phones **with no external DHCP** |
| DHCP relay (v4/v6) | `forwarding-options dhcp-relay` | yes | 🟢 | Relay to a central pool |
| **DHCP snooping** | `forwarding-options … dhcp-security` | yes | 🟢 | Block rogue DHCP that misdirects phones |
| ARP static/proxy/gratuitous (1500) | `interfaces … arp` | yes | 🟢 | Pin the PBX gateway ARP |
| **VRRP** | `irb … vrrp-group` | yes (**EFL**) | 🟢 | Gateway redundancy (slow timers on this box) |
| Filter-based forwarding (PBR) | `firewall … then routing-instance` | yes | 🟢 | Policy-route emergency traffic |
| BFD (slow timers >3 s) | `protocols bfd` | limited (**EFL**) | 🟢 | Coarse L3 liveness |
| **MPLS / EVPN-VXLAN / L2-L3VPN** | — | **no** | ⛔ | Hard limit — not needed |
| Scale: 512 prefixes / 4096 host / 1500 ARP | — | capped | 🟢 | Fine for one flat campus |

### A3 · Virtual Chassis (HA stacking)
| Feature | Config family | On EX2300-C? | Air-gap | Emergency relevance |
|---|---|---|:--:|---|
| Virtual Chassis (≤4 members) | `virtual-chassis` | yes | 🟢 | Two switches = one logical unit |
| VCP over SFP+ | `request virtual-chassis vc-port set` | yes | 🟢 | The uplink pair becomes the stack link |
| Mastership priority / preprovision | `virtual-chassis member …` | yes | 🟢 | Deterministic master |
| Split/merge detection | `no-split-detection` (2-member) | yes | 🟢 | Avoid dual-master lockout |
| Cross-member LAG | `interfaces aeX` | yes | 🟢 | Uplink survives a whole member loss |
| **GRES** | `chassis redundancy graceful-switchover` | yes (VC) | 🟢 | Master failover without dropping calls |
| **NSR** | `routing-options nonstop-routing` | yes (VC) | 🟢 | Preserve routing/VRRP state on switchover |
| **NSSU** | `request system software nonstop-upgrade` | yes (VC) | 🟢 | Upgrade the stack with minimal call disruption |
| Single-chassis ISSU | — | **no** | ⛔ | Standalone reloads on upgrade — plan a window |

### A4 · PoE (124 W budget)
| Feature | Config family | On EX2300-C-12P? | Air-gap | Emergency relevance |
|---|---|---|:--:|---|
| 802.3af / 802.3at (all 12 ports) | `poe interface` | yes | 🟢 | Power phones + APs (AP32 wants PoE+ 19.5 W) |
| Per-port enable/disable | `poe interface … disable` | yes | 🟢 | Kill power to rogue/unused ports (+ [self-heal](#part-d--automation-telemetry--integration-glue-cross-device)) |
| **Per-port priority** | `poe interface … priority high` | yes | 🟢 | Emergency phones/APs win contention |
| Max-power / class / guard-band | `poe … maximum-power / management class / guard-band` | yes | 🟢 | Budget-plan the 124 W; reserve headroom |
| LLDP-MED PoE negotiation | `lldp-med` + `poe` | yes | 🟢 | Fractional-watt = more devices per budget |
| Perpetual/Fast PoE (power thru reboot) | — | **no** | ⛔ | Phones lose power during a switch reboot — note for UPS |

### A5 · CoS / QoS (8 queues)
| Feature | Config family | On EX2300-C? | Air-gap | Emergency relevance |
|---|---|---|:--:|---|
| 8 egress queues/port | `class-of-service` | yes | 🟢 | Dedicated **EF** queue for RTP |
| BA classifier (DSCP/802.1p) | `class-of-service classifiers` | yes | 🟢 | Trust phone EF(46)/CS3 |
| MF classifier (firewall-based) | `firewall … then forwarding-class` | yes | 🟢 | Classify RTP by UDP port when unmarked |
| Forwarding classes / schedulers / maps | `class-of-service …` | yes | 🟢 | Map voice→strict-priority |
| Strict-priority + SDWRR | scheduler `priority strict-high` | yes | 🟢 | RTP never queues behind data |
| Rewrite rules | `class-of-service rewrite-rules` | yes | 🟢 | Re-mark toward core/PBX |
| WRED / tail-drop | `class-of-service drop-profiles` | yes | 🟢 | Protect voice queue under congestion |
| Policer / rate-limit | `firewall policer` | yes | 🟢 | Cap non-voice / storm sources |
| Shaping | scheduler `shaping-rate` | yes | 🟢 | Smooth egress to a constrained uplink |

### A6 · Port / access security
| Feature | Config family | On EX2300-C? | Air-gap | Emergency relevance |
|---|---|---|:--:|---|
| 802.1X single/multiple/multiple-secure | `protocols dot1x … supplicant` | yes | 🟠 | Auth phone/PC per port (needs LAN RADIUS) |
| MAC-RADIUS | `dot1x … mac-radius` | yes | 🟠 | Auth phones that can't do 802.1X |
| Dynamic VLAN (RADIUS VSA) | RADIUS → `vlan` | yes | 🟠 | Push voice VLAN from RADIUS |
| **server-fail / server-reject / guest VLAN** | `dot1x … server-fail vlan` | yes | 🟢 | **Keep phones usable if RADIUS is down — key for 111** |
| Static MAC bypass / whitelist | `authentication-whitelist` | yes | 🟢 | Emergency phones never blocked by auth |
| Captive portal (on-prem) | `services captive-portal` | yes | 🟠 | Guest/unauth redirect |
| **DHCP snooping** | `dhcp-security` | yes | 🟢 | Block rogue DHCP |
| **Dynamic ARP Inspection** | `… arp-inspection` | yes | 🟢 | **Stop ARP-spoof of the VIP/PBX** (protects failover) |
| **IP Source Guard** | `… ip-source-guard` | yes | 🟢 | Drop spoofed src IP/MAC on phone ports |
| IPv6 RA-Guard / ND-inspection | `… ipv6-ra-guard` | yes | 🟢 | Block rogue IPv6 router/ND |
| **Storm control** (on by default) | `storm-control-profiles` | yes | 🟢 | Cap broadcast storms that starve RTP |
| Root guard / BPDU block / loop protect | `protocols rstp …` | yes | 🟢 | Keep STP root off edge; kill loops |
| Control-plane DoS protection | `system ddos-protection` (basic) | limited | 🟢 | Protect the RE/CPU during a flood |
| MACsec (802.1AE) | `security macsec` | limited (uplink/release-dep.) | 🟢 | Encrypt switch-to-switch if riser is untrusted |
| Firewall filters L2–L4 (2000 ACE) | `firewall family …` | yes | 🟢 | Restrict who reaches SIP/PBX |

### A7 · Multicast (**paging!**)
| Feature | Config family | On EX2300-C? | Air-gap | Emergency relevance |
|---|---|---|:--:|---|
| **IGMP snooping (v1/v2/v3, 2000)** | `protocols igmp-snooping` | yes | 🟢 | **Contain multicast paging / MoH to subscribers** |
| IGMP querier / routing | `protocols igmp` | yes (**EFL**) | 🟢 | On-box querier for paging groups |
| **PIM (SM/SSM/DM)** | `protocols pim` | yes (**EFL**) | 🟢 | **Routed overhead paging across VLANs** (700s zones) |
| MLD / MLD-snooping | `protocols mld(-snooping)` | yes (MLD=EFL) | 🟢 | IPv6 multicast |

### A8 · Monitoring / telemetry
| Feature | Config family | On EX2300-C? | Air-gap | Emergency relevance |
|---|---|---|:--:|---|
| SNMP v2c/v3 (+ traps/informs) | `snmp`, `snmp v3` | yes | 🟠 | Poll PoE/port/CPU/temp from the Console |
| **RMON alarms/events + health-monitor** | `snmp rmon`, `snmp health-monitor` | yes | 🟢 | Switch self-watches thresholds → trap on breach |
| **sFlow v5** (4 collectors, 6343) | `protocols sflow` | yes | 🟠 | Top-talkers on the voice VLAN → Console |
| **Port mirroring / analyzer** (1 active) | `forwarding-options analyzer` | yes | 🟢 | Tap SIP/RTP to a local capture/IDS |
| RSPAN / ERSPAN | `analyzer … output vlan/ip` | yes | 🟢 | Mirror to a remote sensor |
| Syslog (RFC 5424 structured) | `system syslog` | yes | 🟠 | Network events beside call events |
| CFM / LFM (Ethernet OAM) | `protocols oam ethernet …` | yes | 🟢 | Continuity/loopback on the PBX uplink |
| **RPM probes** (ICMP/TCP/UDP/HTTP) | `services rpm` | yes (**EFL**) | 🟢 | **Switch actively probes the PBX; breach→trap** |
| JTI native-UDP + gRPC sensors (limited) | `services analytics` / gRPC | yes (**20.2R1**, limited) | 🟠 | Stream port/chassis stats to a LAN collector |
| **gNMI** | OpenConfig gNMI | **no** (only EX4650) | ⛔ | Use JTI-gRPC/UDP or SNMP instead |
| Cable diag (TDR) / optical DOM | `diagnostics tdr` | yes | 🟢 | Detect a failing cable to a phone |

### A9 · HA / resilience & A10 · automation & A11 · services
See **[Part D](#part-d--automation-telemetry--integration-glue-cross-device)** for the full
automation/telemetry surface (NETCONF, scripts, ZTP, event-options, RPM→trap) shared across EX+SRX.
EX-specific resilience: **UFD** (`switch-options uplink-failure-detection` — down access ports when
the uplink dies so phones re-home), 50 rollbacks, dual boot volumes, rescue config. Services: **NTP,
DNS, config archival, FTP/TFTP/SCP** — all 🟢.

### A12 · EX hard limits (flag & skip)
`MPLS/EVPN-VXLAN/OpenFlow`, single-chassis ISSU, gNMI, perpetual/fast-PoE, scaled BGP, BFD fast
timers (<1 s), full DDoS-policer suite, MACsec on access ports — **not on EX2300-C**. None are
needed for a single flat campus.

---

## Part B — SRX300/320 (the firewall / router)

Runs the full Junos "security" image — nearly every branch feature is present. The real gates are
**(1) subscription/cloud feeds** (dead weight air-gapped) and **(2) chassis-cluster HA** (needs a
2nd unit). **#1 change: `set security alg sip disable`** (SIP ALG is ON by default and breaks
Asterisk).

### B1 · Zones & policies
| Feature | Config family | On SRX300/320? | Air-gap | Emergency relevance |
|---|---|---|:--:|---|
| Security zones (+ host-inbound-traffic) | `security zones security-zone` | yes | 🟢 | Segment phones/PBX/Wi-Fi/mgmt; permit only SIP/RTP/DHCP/NTP to the SRX |
| Zone / global stateful policies | `security policies from-zone…/global` | yes | 🟢 | Allow phone↔PBX, deny lateral movement |
| Address book / sets | `security address-book` | yes | 🟢 | Named phone subnets, PBX host, ERT desks |
| Application objects/sets | `applications application` | yes | 🟢 | Define SIP 5060 / RTP 10000-10019 |
| Policy scheduler (time-of-day) | `schedulers` | yes | 🟢 | Time-box admin access; 111 path stays 24/7 |
| Policy count / log (init/close) | `policy … then log/count` | yes | 🟠 | Audit trail of call signaling |
| Unified L7 policy (dynamic-application) | `policies … match dynamic-application` | yes | 🔴 (app-DB stale) | L7 SIP control — DB won't update offline |
| Integrated user firewall (source-identity) | `policies … match source-identity` | yes | 🟠 | Per-user rules with local auth |

### B2 · Screens (DoS/attack prevention) — all 🟢, all supported
`security screen ids-option` → apply per-zone. **All run fully offline** (local logic, no feed):
ICMP flood/fragment/large/ping-death/sweep, IP bad-option/block-frag/source-route/spoofing/
teardrop/unknown-protocol/IPv6-ext-header, **TCP SYN-flood/SYN-ACK-ACK/SYN-FIN/land/winnuke/
port-scan/sweep**, **UDP flood** (guard RTP/SIP-UDP), UDP scan/sweep, **session-limit
source/dest-IP based**, and **`alarm-without-drop`** (tune thresholds without dropping live 111
calls). *This is a large, entirely-offline hardening surface — turn it on.*

### B3 · ALGs
`security alg`. **Disable SIP ALG** (`set security alg sip disable`) — the single most important
change. Also present (leave default or disable per need): DNS, FTP, H.323, MGCP, MS-RPC, Sun-RPC,
PPTP, RTSP, SCCP, TALK, **TFTP** (keep if phones TFTP-provision), RSH, SQL, IKE-ESP, TWAMP. All 🟢.

### B4 · NAT (prefer **none** for internal SIP)
Source / destination / static / **persistent** NAT, proxy-ARP / proxy-NDP, NAT64/46, hairpinning —
all `security nat …`, all 🟢. On a flat LAN you usually want **no NAT** in the SIP path (preserve
headers → no ALG dependency); NAT rows are for multi-subnet/edge cases.

### B5 · Threat prevention — mostly ⛔/🔴 offline (know the ceiling)
| Feature | Config family | On SRX300/320? | Air-gap | Note |
|---|---|---|:--:|---|
| IDP/IPS inline engine | `security idp` | yes | 🟢 (engine) | Runs; **bundled signatures go stale** |
| IDP daily signature feed | `request security idp security-package` | yes | 🔴 | No feed reachable offline |
| **Custom IDP attack objects** | `security idp custom-attack` | yes | 🟢 | **Write your own SIP/toll-fraud signatures offline** |
| UTM antivirus / antispam / enhanced-web-filter | `security utm feature-profile …` | license | 🔴 | Feed/cloud — unusable offline |
| **UTM local web-filter / content-filter** | `utm … juniper-local / content-filtering` | yes | 🟢 | Allow/block URLs + file types from a local list |
| AppID engine | `services application-identification` | yes | 🔴 (DB stale) | Bundled sigs only |
| **Custom AppID signatures** | `application-identification application (custom)` | yes | 🟢 | Define your PBX's SIP app locally |
| **AppTrack / AppFW / AppQoS** | `security application-tracking` / policy / `class-of-service application-traffic-control` | yes | 🟢 | Log & prioritise the SIP app (not just port) |
| ATP Cloud / SecIntel feeds | `services advanced-anti-malware`, `security intelligence` | enroll | 🔴 | Cloud — N/A air-gapped |

### B6 · Flow, routing, L2, DHCP, VPN, CoS, HA
- **Flow/sessions** (`security flow`): flow-based (default), packet-based, selective stateless, TCP session checks, **TCP MSS clamp**, aggressive aging, session logging, flow traceoptions/pcap — all 🟢. Watch live 111 sessions; root-cause one-way audio.
- **Routing** (`protocols`, `routing-instances`): static/OSPF/RIP/BGP/IS-IS, **VRF/virtual-router** (isolate a voice VRF), VRRP, PBR/APBR, ECMP, IRB, IGMP/PIM, **BFD**, GRE/IP-IP tunnels — all 🟢.
- **Integrated switching / transparent mode** (`ethernet-switching`, L2 transparent): VLANs, trunk/access, LAG, **transparent (drop-in) firewall**, secure-wire, RSTP/MSTP/VSTP, LLDP-MED, DHCP-snooping/DAI, 802.1X — 🟢. *Transparent mode = insert the SRX without re-IP-ing phones/PBX.*
- **DHCP** (`dhcp-local-server` / `dhcp-relay`): server, relay, reservations, and **provisioning options 66/43/120/125/150 + option 42 (NTP)** — 🟢. *Hand phones their SIP server + NTP automatically.*
- **VPN** (`security ike/ipsec`): route/policy IPsec, IKEv1/2, PSK or **local-CA certs**, AutoVPN, ADVPN, DPD/VPN-monitor, **CoS-based IPsec (EF preserved)**, Secure-Connect remote-access (local auth) — all 🟢 over a **private** link (no Internet needed). *For a van / building-to-building voice tunnel.*
- **CoS**: BA/MF classifiers, EF forwarding-class, strict-high scheduler, rewrite, shaping, 2-/3-color policers, RED, **AppQoS** — 🟢. Mirror the switch's EF marking end-to-end.
- **HA — chassis cluster** (`chassis cluster`): active/passive, redundancy groups, **reth** interfaces, interface/IP-monitor failover, cluster ISSU — **⛔ needs a 2nd identical SRX**. Single-box resilience still comes from VRRP, graceful-restart, snapshot/rescue, commit-confirmed.

### B7 · SRX monitoring & services
Syslog (**stream** mode → LAN collector, or event mode), SNMP v2c/v3 + traps + RMON, **J-Flow
v5/v9 & inline IPFIX** (20.1R1+; SRX has **no sFlow** — use J-Flow), RPM + **TWAMP client/server**
(18.1R1+), packet-capture, IP-monitoring/service-tracking, Ethernet OAM, port-mirroring — all 🟢/🟠.
**Services:** **NTP server** (serve time to the whole air-gapped campus), DNS proxy (split/
conditional), J-Web, SSH, local/RADIUS/TACACS+ admin auth, access profiles/captive-portal, **PoE on
SRX320-POE**, config archival to a LAN server. **Control-plane hardening:** per-zone
host-inbound-traffic, **lo0 RE-protect filter**, policers, connection-limits, dedicated
mgmt-instance/fxp0, **unicast RPF** (anti-spoof). All 🟢.

---

## Part C — Mist AP32 (the Wi-Fi)

**Governing facts:** data-plane is **always local** (softphone→PBX never touches the cloud, so
voice works air-gapped); **AP Config Persistence must be enabled on the bench before the air-gap**;
management/visibility/config-change all need cloud (frozen once offline). Grades: 🟡 persisted =
authored in Mist once, runs offline; 🟢 = autonomous on the AP; 🔴 = needs live cloud.

### C1 · Radio / RF (Wi-Fi 6, 2.4+5 GHz, no 6 GHz)
| Feature | Mechanism | Air-gap | Emergency relevance |
|---|---|:--:|---|
| 802.11ax: OFDMA, MU-MIMO, 1024-QAM, TWT, BSS-color | on-chip | 🟢 | Capacity/latency headroom for concurrent callers |
| 5 GHz 4×4 + 2.4 GHz 2×2 concurrent | two client radios | 🟢 | Dual-band coverage |
| **Dedicated 3rd scanning radio** | always-on sensor | 🟢 (reporting 🔴) | 24×7 rogue/interference scan without stealing call airtime |
| **Static channel/power plan** | per-radio, pushed | 🟡 | **Lock a clean non-DFS voice channel plan** (see below) |
| Local (event-driven) RRM + DFS backoff | on-AP | 🟢 | AP still reacts to radar/interference offline |
| Global RRM (overnight ML) | cloud | 🔴 | No overnight re-optimisation offline → pre-plan channels |
| **Band steering / min-RSSI geofence** | per-WLAN | 🟡 | Push handsets to 5 GHz; reject weak far clients |
| Airtime fairness / min-rate (kill low legacy rates) | per-WLAN | 🟡 | Protect voice airtime in a crowd (muster point) |
| Multiple SSIDs · per-SSID VLAN · VLAN pool | WLAN→VLAN | 🟡 | Voice SSID isolated from data/guest |
| Dynamic VLAN (RADIUS) | 802.1X VSA | 🔴 (unless local RADIUS) | Avoid for voice offline |

### C2 · QoS / voice
**WMM (AC_VO/VI/BE/BK)** 🟢 core air-prioritisation; **DSCP→WMM mapping** 🟢 honours softphone EF(46)
into AC_VO; **Override-QoS** 🟡 pins the whole voice SSID to AC_VO regardless of client marking;
**per-SSID/client/app rate-limit** 🟡 throttle data so voice keeps headroom. *Note: the AP re-marks
upstream DSCP from the AC — verify the switch/PBX trust boundary.* No hard call-admission-control
(size cells manually).

### C3 · Roaming (moving caller)
**802.11r (FT)** 🟡 sub-50 ms roam keeps a walking 111 call's RTP alive · **802.11k/v** 🟢 default ·
**OKC** 🟡 for Android clients lacking .11r · **local PMK caching** 🟢 fast re-assoc with no cloud.
Roaming is entirely client-driven + AP-assisted — **no cloud in the roam path.**

### C4 · Security / auth
| Feature | Mechanism | Air-gap | Emergency relevance |
|---|---|:--:|---|
| WPA2-Personal (PSK) | AP-local | 🟡 | Simplest robust voice-SSID choice |
| WPA3-Personal (SAE) / transition | AP-local | 🟡 | Stronger PSK, handshake is AP-local |
| Enhanced Open / OWE | AP-local | 🟡 | Encrypted open SSID (no portal) |
| **MPSK/PPSK — local lookup (≤5000 keys)** | on-AP cache | 🟡 | **Per-device Wi-Fi keys with no RADIUS, works offline** |
| MPSK cloud lookup (>5000) | cloud per-join | 🔴 | Avoid — new joins fail offline |
| 802.1X/EAP · MAC-auth | AP→RADIUS | 🟠 (local RADIUS) / 🔴 | Only with an on-prem RADIUS |
| Guest/captive portal (Mist-hosted or external) | cloud | 🔴 | Don't use for emergency SSID; **portal-bypass-on-unreachable** 🟢 as a safety valve |
| **Rogue/honeypot/WIDS detection** | 3rd radio | 🟢 detect / 🔴 alert | Detects an evil-twin "upes-voice" locally; alerts need cloud |
| WIPS containment | cloud/Marvis | 🔴 | No auto-containment offline |
| **Client isolation** (off/same-AP/same-subnet) | per-WLAN | 🟡 | Isolate handsets; allow only PBX/gateway |
| **WxLAN L3 access policy** | label allow/deny on AP | 🟡 | **Restrict voice VLAN to PBX/SIP only, on the AP** |
| ARP / broadcast-multicast filtering | per-WLAN | 🟡 | Protect voice airtime — **but keep mDNS** (project uses `upes-ecs.local`) |
| Banned-client blocklist | list snapshot | 🟡 | Enforced offline (can't update list offline) |

### C5 · NAC / Access-Assurance, C6 · forwarding, C7 · mesh
- **Access Assurance (cloud RADIUS/NAC)** 🔴 — unusable on a permanent air-gap **unless** you add a **Mist Edge** appliance (Site Survivability: cached clients + local RadSec) ⛔/🟡. For this deployment, use **local PSK/WPA3-Personal or MPSK-Local** instead.
- **Forwarding:** local bridging (SSID→VLAN on the AP's trunk) 🟢 is the correct model; Mist-Edge L2TPv3 tunnelling ⛔ (adds a dependency — skip for voice).
- **Wireless mesh** 🟡→🟢: base/relay, auto-failover, mesh-groups — **the "corner repeaters" for the van/courtyard**; cable-commission each mesh AP on the bench first, then it runs offline. Keep ≤4 relays for voice latency.

### C8 · Location / BLE — mostly 🔴 (honest)
x/y location engine, vBLE virtual beacons, wayfinding/SDK, BLE asset tags, proximity, zones/
occupancy — **all cloud** 🔴 (and AP32 has an *omnidirectional* BLE antenna, not the directional
array of AP43/45 → lower accuracy anyway). The **one offline "geofence"** is per-WLAN **min-RSSI**
🟡. *Offline substitute for "locate the caller" = the switch-port method in
[Part E](#part-e--new-emergency-specific-integrations-this-research-surfaced).*

### C9 · Marvis / AIOps & C10 · Mist-managed EX & C11 · API
- **Marvis / SLE / anomaly / dynamic-PCAP** — **all 🔴**. No AI troubleshooting, dashboards, or auto-PCAP offline.
- **Mist-managed EX**: Junos runs locally so forwarding/PoE/VLANs/VC persist 🟡→🟢, but **config changes need cloud** 🔴 — so if you let Mist manage the EX, you can't edit the switch offline. **Recommendation: manage the EX by NETCONF/CLI (self-hosted), not Mist**, precisely so it stays editable air-gapped.
- **Mist cloud dashboard / REST API / webhooks / firmware** — **all 🔴**, commissioning/Option-B only.

### C12 · Power / onboarding
PoE+ (19.5 W) = full function 🟢; 802.3af = reduced (drops 5 GHz to 2×2) 🟢 — **give APs PoE+**.
Claim/adopt/ZTP-config/firmware = one-time cloud 🔴→ then **persisted** 🟡. Static IP 🟡, BLE/console
local onboarding 🟢, **reboot survivability with persistence** 🟡.

---

## Part D — Automation, telemetry & integration glue (cross-device)

The layer that turns "network gear" into "part of the emergency app." Almost all 🟢 — it's on-box
Junos + on-prem collectors (the VM/Jetson runs the receivers). This is where the *impactful*
integration lives.

### D1 · On-box scripting & reaction
| Capability | Junos mechanism | EX / SRX | Air-gap | Integration with PBX + Console |
|---|---|---|:--:|---|
| **Op scripts** (SLAX/Python) | `system scripts op` | both | 🟢 | One-command diagnostics (voice-path check, PoE audit) |
| **Commit scripts** | `system scripts commit` | both | 🟢 | **Guardrails** — refuse a commit that re-enables SIP ALG or drops NTP |
| **Event scripts + event-options** | `event-options policy`, `event-script` | both | 🟢 | React to link/PoE/LLDP/RPM/config events → run a local action or hit the Console |
| SNMP scripts | `system scripts snmp` | both | 🟢 | Custom OIDs for voice health |
| **On-box Python 3 + `requests`** | `set … scripts language python3` (19.4R1+) | both | 🟢 | Script does `requests.post()` — no external agent needed |
| **Reaction hook → local HTTP** | event-script `then` runs a Python `requests.post()` to the Console `/exec` (or Asterisk ARI/AGI) | both | 🟢 | **Network event → PBX action** (page ERT, start followup) |

### D2 · Programmatic config / management
| Capability | Junos mechanism | EX / SRX | Air-gap | Integration |
|---|---|---|:--:|---|
| **NETCONF over SSH** (TCP 830) | `system services netconf ssh` | both | 🟢 | The Console/collector reads state & pushes config |
| **On-box REST API** (HTTP 3000 / HTTPS 3443) | `system services rest`; lock `control allowed-sources` to the Console IP | both | 🟢 | PowerShell `Invoke-RestMethod http://<sw>:3000/rpc/get-…` — no NETCONF client needed |
| **PyEZ (junos-eznc) Tables/Views** | NETCONF client on the PBX host | both | 🟢 | Structured `get-poe/lldp/arp/ethernet-switching` → JSON for the board |
| Ansible (junos collection) | NETCONF/SSH | both | 🟢 | Config-as-code from an air-gapped control node |
| **apply-groups / configuration groups** | `groups`, `apply-groups` | both | 🟢 | Template port/PoE/CoS/zone config |
| **commit confirmed / commit at / check** | `commit confirmed N` | both | 🟢 | Auto-rollback if a change breaks 111 |
| **Config archival (transfer-on-commit)** | `system archival` → LAN SCP | both | 🟢 | **Auto-back-up switch/SRX config into the nightly backup** |
| Rescue config / 50 rollbacks | `rollback`, rescue | both | 🟢 | Instant revert to known-good |
| **ZTP** (DHCP opt 43/66/150 → LAN file server) | ZTP | both | 🟢 | **Swap a dead switch → self-configures from the VM**, no Internet |

### D3 · Telemetry to a local collector (the Console's data feed)
| Capability | Junos mechanism | EX / SRX | Air-gap | Integration |
|---|---|---|:--:|---|
| SNMP v2c/v3 (jnxBoxAnatomy, IF-MIB, POWER-ETHERNET-MIB, ENTITY-MIB) | `snmp` | both | 🟠 | Poll PoE watts/budget, port up/down, PSU/temp → health tiles |
| **RMON + health-monitor** (self-thresholding) | `snmp rmon`, `snmp health-monitor` | both | 🟢 | One line → box watches CPU/mem/temp/errors, traps on breach |
| **SNMP traps/informs → PBX-host listener** | `snmp trap-group` | both | 🟠 | link-down / PoE / RMON breach → Asterisk originate/alert |
| **sFlow v5** (EX) / **J-Flow v5-9 & IPFIX** (SRX) | `protocols sflow` / `forwarding-options sampling` | EX / SRX | 🟠 | Top-talkers + flow audit on the voice VLAN, no cloud SIEM |
| **Syslog RFC 5424 structured → LAN** | `system syslog host` | both | 🟠 | Typed network events beside call events; `match` → trigger |
| Security-log stream mode (SRX) | `security log mode stream` | SRX | 🟠 | High-volume session/screen/IDP logs to the LAN |
| **RPM probes + thresholds → syslog/trap** | `services rpm` | both (EX=EFL) | 🟢 | **Box actively probes the PBX/SIP; breach → trap → followup** |
| **TWAMP client/server** | `services rpm twamp` | SRX (EX unverified) | 🟢 | Standards-based voice-path delay/jitter/loss SLA |
| RPM/RMON results via MIB | DISMAN-PING-MIB / jnxPing | both | 🟠 | Console plots RTT/jitter history, no cloud APM |
| **JTI native-UDP + gRPC** (limited sensors) | `services analytics` / gRPC | **EX2300 only** (20.2R1) | 🟠 | Real-time port/chassis/LLDP/ARP streams to a LAN collector |
| gNMI | OpenConfig gNMI | **neither** (EX4650+/SRX1500+) | ⛔ | Not on this gear — use JTI/SNMP |
| Port mirroring / analyzer | `forwarding-options analyzer` (EX 1 active) / SRX pcap | both | 🟢 | On-demand SIP/RTP capture to the PBX host / IDS |

### D4 · Time & name services (air-gap essentials)
**NTP** (`system ntp`, SRX as master) 🟢 — no Internet clock, so a local NTP master keeps call
records/fail2ban/logs honest; **DNS proxy / static-host-mapping** 🟢 — resolve `upes-ecs.local` and
PBX/RADIUS names locally.

---

## Part E — New emergency-specific integrations this research surfaced

Beyond the plan's Tier-3 ideas, these fall out of the full feature scan and are **all offline**:

1. **Overhead / multicast paging done on the network** — the system already has paging (700s). Carry it as **IP multicast** with **IGMP-snooping** (contain it) + **IGMP querier/PIM** (route it across zones). Paging audio reaches only subscribed speakers, doesn't flood the voice VLAN. *(EX A7; PIM/IGMP = EFL.)*
2. **Fixed-phone tamper/loss alert** — **MAC-move/MAC-notification** + **PoE-draw watch** (POWER-ETHERNET-MIB): if a fixed emergency phone (e.g. `4301 Main Gate`) is unplugged or stops drawing PoE, the switch traps → Console flags *"Main Gate phone offline"* against that extension. A silent dead emergency phone becomes a visible alarm.
3. **The network probes the PBX and drives the follow-up workflow** — **RPM** (ICMP/UDP) from the EX/SRX to the PBX/SIP, with **thresholds → SNMP trap / event-script**. On loss/RTT breach the box hits the Console `/exec` (existing followup action) or pages the ERT desk — *the network watches the emergency service and escalates itself.*
4. **Commit-script guardrails for the emergency invariants** — a commit script that **rejects any config** which re-enables SIP ALG, removes the NTP master, or deletes the voice EF scheduler. The rules that keep 111 working become un-break-able by a careless change.
5. **Auto-backup of network config into the existing nightly backup** — `system archival transfer-on-commit` (or a NETCONF `get-config` in `backup/pull-configs.sh`) drops EX+SRX config into the VM's nightly set, so a full rebuild restores the network too.
6. **Per-device Wi-Fi keys with no server (MPSK-Local)** — up to ~5000 per-device pre-shared keys cached **on the AP**, works fully offline: every responder handset / fixed device gets its own revocable Wi-Fi key without standing up RADIUS.
7. **Transparent-mode SRX drop-in** — insert the SRX's screens/policies in front of the PBX **without re-IP-ing** anything (bump-in-the-wire), so hardening doesn't disturb a working flat design.
8. **UFD + RTG for phone re-homing** — if the PBX-side uplink fails, **Uplink-Failure-Detection** downs the affected access ports so Wi-Fi/roaming phones immediately re-home via the other AP/path; **RTG** gives sub-second uplink failover for signaling.
9. **Custom IDP + custom AppID for SIP abuse** — write **offline** signatures for SIP scanning / REGISTER floods / toll-fraud patterns; a network-layer complement to the PBX's fail2ban.
10. **DHCP as the phone auto-provisioner** — options **120/125/43/66/150** hand phones the **SIP server**, and option **42** the **NTP** server — so a factory phone self-points at the PBX and the campus clock with zero manual entry.

---

## Part F — The recommended air-gapped feature SET (what to actually turn on)

If you want "a lot of Juniper," here's the **consolidated on-profile** — every item is 🟢/🟡 and
adds real value, grouped by device. (This is the union of the plan's tiers + the gems above.)

**EX2300-C VC (both members):** Virtual Chassis + GRES/NSR + NSSU · voice/mgmt/guest VLANs + IRB
gateway + VRRP · LLDP-MED voice auto-assign · CoS (EF strict-priority + rewrite + WRED) · PoE
priority + guard-band · RSTP-edge + BPDU/root-guard + storm-control + MAC-limit/persistent-MAC +
**MAC-move alert** · **DHCP-snooping + DAI + IP-source-guard** · 802.1X/MAC-RADIUS (server-fail→voice,
static-bypass for emergency phones) · **IGMP-snooping (+PIM/IGMP for paging)** · UFD + RTG + LAG to
PBX · SNMP v3 + **RMON/health-monitor** + **RPM→trap** + sFlow + structured syslog + (optional) JTI
· NETCONF + op/commit/event scripts + apply-groups + commit-confirmed + config-archival + ZTP · NTP
client.

**SRX300/320:** zones (VOICE/MGMT/GUEST/UNTRUST) + host-inbound-traffic · LAN-only voice policy ·
**`security alg sip disable`** · **full screen suite** (UDP/SYN flood, spoofing, scans, session
limits, alarm-without-drop) · DHCP server + **provisioning options 120/125/66/42** · **NTP master** ·
DNS proxy · CoS EF mirror · **custom IDP + custom AppID + AppFW/AppTrack/AppQoS** · UTM local
web/content filter · unicast-RPF + lo0 RE-protect filter + connection-limits · J-Flow/IPFIX + stream
syslog + SNMP + RPM/TWAMP · NETCONF + scripts + commit-confirmed + rescue · (later) IPsec for a van
link.

**AP32 (persist on the bench):** **Config Persistence ON** · voice SSID (WPA3-Personal or
**MPSK-Local**, isolation on, **WxLAN → PBX/SIP only**, keep mDNS) + guest SSID (isolated→GUEST
VLAN) · **WMM + DSCP→WMM + Override-QoS(AC_VO)** · **802.11r/k/v + OKC + local PMK** · band-steering +
min-RSSI + airtime/min-rate · **static non-DFS channel plan** + local RRM · 3rd-radio WIDS (detect) ·
**mesh** for van/corner coverage · static IP · PoE+ · firmware pinned.

**On the VM/Jetson (the collectors that make it offline-capable):** rsyslog:514, SNMP poller +
**trap listener:162**, sFlow/J-Flow/IPFIX collector, NETCONF/PyEZ pollers (`net_health`,
`caller_locate`), FreeRADIUS (for 802.1X/MAC-RADIUS), NTP (fallback), a ZTP file/DHCP server, and
the Console `/network`, `/locate`, `/exec:evac-network-*` routes.

---

## Part G — Skip list, hard limits & unlock-upgrades

**Deliberately skip on a permanent air-gap (dead weight or unavailable):**
- **Mist cloud runtime:** Marvis, SLE, dashboards, REST API, webhooks, dynamic-PCAP, Location/vBLE/
  wayfinding/asset-tracking, global RRM, firmware push, **any AP/switch config change**, Mist-hosted
  captive portal, cloud-MPSK, Access-Assurance cloud RADIUS. *(All 🔴 — commissioning/Option-B only.)*
- **SRX subscription/cloud:** ATP Cloud, SecIntel, UTM antivirus/antispam/enhanced-web-filter, IDP &
  AppID **signature feeds**, unified-policy app-DB freshness. *(Engines run; feeds don't update.)*
- **Needs hardware you don't have:** SRX **chassis-cluster HA** (⛔ 2nd SRX), Mist **Access-Assurance
  offline** (⛔ Mist Edge appliance).
- **Not on this silicon:** EX **MPLS/EVPN-VXLAN/OpenFlow/gNMI/single-chassis-ISSU/perpetual-PoE**;
  SRX/EX **gNMI**; long-range **point-to-point** Wi-Fi (AP32 is indoor omni, not a PtP bridge — the
  Bidholi↔Kandoli rooftop link needs different gear).

**"Add one thing" upgrades that unlock a lot:**
| Add | Unlocks | Grade after |
|---|---|---|
| **A 2nd SRX320** (identical Junos) | Firewall **chassis-cluster HA** (active/passive, reth, sub-second failover) — removes the single-SRX SPOF | 🟢 |
| **A brief, firewalled maintenance uplink** (Option B) | Marvis, Location/BLE, webhooks→Console, firmware & signature updates — during a window; voice stays LAN-only | 🔴→available |
| **A Mist Edge appliance** | On-prem **Access-Assurance Site Survivability** (offline 802.1X with cached clients) | 🟡 |
| **Directional/outdoor radios** | The Bidholi↔Kandoli campus bridge AP32 can't do | n/a→🟢 |

---

## Corrections to the Integration Plan

Research updated one claim in [Docs/Juniper-Integration-Plan.md](Juniper-Integration-Plan.md): the
EX2300 **does** support limited **JTI streaming telemetry** (gRPC dial-in + native-UDP sensors,
Junos 20.2R1+; PFE CPU/mem/filter stats, physical-interface traffic, RE LACP/chassis-env/LLDP/ARP) —
it only lacks **gNMI**. **SRX300/320 have no streaming telemetry at all** (lowest is SRX1500). So the
"no streaming telemetry on EX2300" note there should read *"limited JTI on EX2300, no gNMI; none on
SRX300 — use SNMP/RMON/RPM/J-Flow/syslog."* Everything else in the plan stands.

---

*Volume II of the UPES-ECS Juniper docs. Compiled from a full feature-surface scan of the exact
hardware (1× SRX300/320, 2× EX2300-C-12P, 2× Mist AP32) for a fully air-gapped deployment. Every
`set`/RPC is a sketch — validate syntax per Junos version + Feature Explorer; apply with
`commit confirmed`; test 199 before 111.*
