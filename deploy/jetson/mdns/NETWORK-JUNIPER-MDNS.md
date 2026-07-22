# UPES-ECS — Juniper Integration Guide (mDNS name-failover variant, NO VIP)

This is the **network side** for the *simpler* two-Jetson HA cluster that fails over a
**name** (`upes-ecs.local`) instead of a floating VIP — VLAN, DHCP, QoS, PoE, Wi-Fi,
and firewall — with concrete Junos `set` commands and plain-language explanations.

Because there is **no Virtual IP and no router VRRP** in this design, this guide is
shorter than the VIP one (`../NETWORK-JUNIPER.md`): there is **nothing to configure
on the Juniper side for a VIP or gratuitous ARP**. The only extra requirement is that
the voice VLAN passes the **multicast** that mDNS and keepalived-VRRP use — which an
ordinary L2 switched VLAN already does.

> **Disclaimer.** These are standard, correct Junos patterns, but syntax varies by
> platform/version (EX2300/EX3400/EX4300 ELS, SRX, MX). **Validate against the
> customer's exact Junos versions** and adapt interface names. Apply in a `configure`
> session and `commit confirmed 5` so a mistake auto-rolls-back.

Assumptions used throughout (match `deploy/jetson/mdns/README-MDNS.md`):

| Thing | Value (example) |
|---|---|
| Voice VLAN name / ID | `voice` / `30` |
| Voice subnet | `10.20.30.0/24` |
| Gateway (IRB on the switch/router) | `10.20.30.254` |
| **mDNS name (phones register here)** | `upes-ecs.local` (published by the MASTER Jetson) |
| Jetson primary / secondary | `10.20.30.11` / `10.20.30.12` |
| Phone access ports | `ge-0/0/0` … `ge-0/0/23` |
| Jetson ports | primary `ge-0/0/46`, secondary `ge-0/0/47` |
| Switch-to-switch / uplink trunk | `ge-0/0/47` … `xe-0/1/0` |

---

## 1. Big picture — why the network matters here

The HA design rests on **one flat Layer-2 voice VLAN that spans both switches and
reaches both Jetsons**. Unlike the VIP variant, nothing here relies on gratuitous ARP
moving an IP. Instead two kinds of **link-local multicast** must flow on the voice
VLAN between the boards (and to the phones):

- **mDNS** — UDP `224.0.0.251:5353`. Avahi on the MASTER publishes `upes-ecs.local`
  and phones resolve it. This must reach every phone that resolves the name.
- **keepalived VRRP** — IP protocol 112 to `224.0.0.18`. The two boards elect one
  MASTER over this; it must flow **board ↔ board** on the voice VLAN.

Both are **default-passed on an ordinary L2 switched VLAN** — a switch floods
link-local multicast within the VLAN — so **typically there is nothing extra to
configure**. The one real gotcha is **Wi-Fi AP client isolation** (see §7), which
breaks phone↔PBX and phone↔mDNS. So:

1. Create a **voice VLAN** and put phone access ports + both Jetson ports in it.
2. **Trunk** the voice VLAN across every switch-to-switch / uplink link so it is one
   L2 segment (so VRRP and mDNS flow board↔board even across switches).
3. **DHCP** phones on that VLAN; keep the Jetsons static (outside the pool).
4. **QoS end-to-end** so voice never drops under load.
5. **PoE** for phones; **Wi-Fi** APs on the voice VLAN with client isolation **OFF**.
6. **Firewall** SIP/RTP (and mDNS) inside the VLAN, blocked from the internet.

---

## 2. Voice VLAN + access ports + trunks (EX switches)

**Create the VLAN (identically on BOTH switches):**
```
set vlans voice vlan-id 30
set vlans voice description "UPES-ECS voice / phones / Jetson PBX cluster (mDNS name-failover)"
```

**Phone access ports** (untagged/access in the voice VLAN):
```
set interfaces interface-range PHONES member-range ge-0/0/0 to ge-0/0/23
set interfaces interface-range PHONES unit 0 family ethernet-switching interface-mode access
set interfaces interface-range PHONES unit 0 family ethernet-switching vlan members voice
```

**Jetson ports** — the boards are plain hosts in the voice VLAN (access ports):
```
set interfaces ge-0/0/46 description "UPES-ECS Jetson PRIMARY"
set interfaces ge-0/0/46 unit 0 family ethernet-switching interface-mode access
set interfaces ge-0/0/46 unit 0 family ethernet-switching vlan members voice
```
(Repeat for the secondary's port on its switch.)

**Trunk / uplinks — carry the voice VLAN so it spans BOTH switches** (this is what
lets VRRP election and mDNS flow between the two Jetsons when they hang off different
switches):
```
set interfaces ge-0/0/47 description "Uplink/trunk to peer switch"
set interfaces ge-0/0/47 unit 0 family ethernet-switching interface-mode trunk
set interfaces ge-0/0/47 unit 0 family ethernet-switching vlan members voice
```
> Put **every** inter-switch link and the uplink toward the router in trunk mode
> carrying `voice` (plus your other VLANs). The voice VLAN must appear on both
> switches so the two boards share one L2 segment.

**Gateway (IRB) for the voice subnet** — on the L3 switch or router:
```
set interfaces irb unit 30 description "Voice VLAN gateway"
set interfaces irb unit 30 family inet address 10.20.30.254/24
set vlans voice l3-interface irb.30
```

---

## 3. Both Jetsons on the same voice subnet — and NO VIP

- Jetson **primary** = `10.20.30.11/24`, **secondary** = `10.20.30.12/24`, both set
  statically on the boards (netplan — see README §4).
- There is **no Virtual IP** in this design. `upes-ecs.local` resolves (via mDNS) to
  whichever board is currently MASTER — `.11` normally, `.12` after a failover.
  **Nothing on the switch or IRB owns or configures any VIP**, and there is **no
  gratuitous-ARP dependency**.
- Keep `.11`, `.12`, and `.254` **out of the DHCP pool** (next section).

---

## 4. DHCP for phones (Juniper DHCP server, on the voice VLAN)

Phones get addresses from the switch/router's DHCP server on the voice VLAN. Reserve
the low addresses for infrastructure; hand out a mid-range pool:
```
set system services dhcp-local-server group VOICE interface irb.30
set access address-assignment pool VOICE-POOL family inet network 10.20.30.0/24
set access address-assignment pool VOICE-POOL family inet range VR low 10.20.30.50 high 10.20.30.200
set access address-assignment pool VOICE-POOL family inet dhcp-attributes router 10.20.30.254
set access address-assignment pool VOICE-POOL family inet dhcp-attributes name-server 10.20.30.254
```
> **Do NOT include `.11`, `.12`, or `.254` in the range.** You do **not** need a DHCP
> option to push the SIP server here: phones use the **name `upes-ecs.local`**, set
> once in provisioning (see `deploy/qemu/HOSTNAME-mDNS.md`). If the DHCP server lives
> on another box, use a **DHCP relay** instead:
```
set forwarding-options dhcp-relay server-group DHCP 10.20.30.254
set forwarding-options dhcp-relay group VOICE interface irb.30
set forwarding-options dhcp-relay group VOICE active-server-group DHCP
```

---

## 5. CoS / QoS end-to-end (so voice never drops under load)

Identical to the VIP variant — QoS does not care whether failover is by name or VIP.
Mark **RTP media as EF (DSCP 46)** and **SIP signalling as CS3/AF31**, put media in a
**strict-priority queue**, and honour the markings across every EX switch and the
router.

**5.1 Forwarding classes → queues:**
```
set class-of-service forwarding-classes class VOICE-RTP queue-num 5
set class-of-service forwarding-classes class VOICE-SIG queue-num 3
set class-of-service forwarding-classes class BEST-EFFORT queue-num 0
```

**5.2 Behaviour-aggregate (DSCP) classifier** — trust DSCP from phones/PBX:
```
set class-of-service classifiers dscp UPES-VOICE forwarding-class VOICE-RTP loss-priority low code-points ef
set class-of-service classifiers dscp UPES-VOICE forwarding-class VOICE-SIG loss-priority low code-points cs3
set class-of-service classifiers dscp UPES-VOICE forwarding-class VOICE-SIG loss-priority low code-points af31
set class-of-service classifiers dscp UPES-VOICE forwarding-class BEST-EFFORT loss-priority low code-points 000000
```

**5.3 Multifield classifier (mark at the edge)** — remark by port/protocol so voice is
trusted from the first hop. RTP UDP 10000–10019 → EF, SIP 5060 → CS3:
```
set firewall family ethernet-switching filter MARK-VOICE term RTP from destination-port-range 10000 10019
set firewall family ethernet-switching filter MARK-VOICE term RTP from protocol udp
set firewall family ethernet-switching filter MARK-VOICE term RTP then forwarding-class VOICE-RTP
set firewall family ethernet-switching filter MARK-VOICE term RTP then loss-priority low
set firewall family ethernet-switching filter MARK-VOICE term SIP from destination-port 5060
set firewall family ethernet-switching filter MARK-VOICE term SIP from protocol udp
set firewall family ethernet-switching filter MARK-VOICE term SIP then forwarding-class VOICE-SIG
set firewall family ethernet-switching filter MARK-VOICE term DEFAULT then accept
```
Apply the classifier + edge filter to access ports (phones + Jetson):
```
set class-of-service interfaces ge-0/0/0 unit 0 classifiers dscp UPES-VOICE
set interfaces ge-0/0/0 unit 0 family ethernet-switching filter input MARK-VOICE
```
(Apply to the PHONES interface-range and the Jetson ports.)

**5.4 Schedulers** — RTP strict priority, signalling a guaranteed slice, rest best-effort:
```
set class-of-service schedulers SCH-RTP priority strict-high
set class-of-service schedulers SCH-RTP transmit-rate percent 30
set class-of-service schedulers SCH-RTP buffer-size percent 10
set class-of-service schedulers SCH-SIG priority high
set class-of-service schedulers SCH-SIG transmit-rate percent 5
set class-of-service schedulers SCH-BE priority low
set class-of-service schedulers SCH-BE transmit-rate percent 65
```

**5.5 Scheduler-map** — bind schedulers to forwarding classes:
```
set class-of-service scheduler-maps UPES-MAP forwarding-class VOICE-RTP scheduler SCH-RTP
set class-of-service scheduler-maps UPES-MAP forwarding-class VOICE-SIG scheduler SCH-SIG
set class-of-service scheduler-maps UPES-MAP forwarding-class BEST-EFFORT scheduler SCH-BE
```

**5.6 Rewrite rules** — re-stamp DSCP on egress (esp. toward trunks):
```
set class-of-service rewrite-rules dscp UPES-REWRITE forwarding-class VOICE-RTP loss-priority low code-point ef
set class-of-service rewrite-rules dscp UPES-REWRITE forwarding-class VOICE-SIG loss-priority low code-point cs3
set class-of-service rewrite-rules dscp UPES-REWRITE forwarding-class BEST-EFFORT loss-priority low code-point 000000
```

**5.7 Apply the map + rewrite to the trunk/uplink egress ports:**
```
set class-of-service interfaces ge-0/0/47 scheduler-map UPES-MAP
set class-of-service interfaces ge-0/0/47 unit 0 rewrite-rules dscp UPES-REWRITE
set class-of-service interfaces ge-0/0/47 unit 0 classifiers dscp UPES-VOICE
```
> Do this on **every** inter-switch and router-facing port so EF/CS3 survive the whole
> path. On the **router (MX/SRX)**, mirror the classifier + scheduler-map so the EF
> queue is honoured there too. Match the RTP port range to the PBX: this repo uses
> **UDP 10000–10019** (`deploy/asterisk/rtp.conf`).

---

## 6. Multicast for mDNS + VRRP — usually nothing to configure

This variant replaces the VIP with a name, so **there is no application VIP and no
gratuitous-ARP requirement** on the Juniper side. What the voice VLAN must pass is the
**link-local multicast** the design uses:

- **mDNS** — UDP destination `224.0.0.251` port `5353` (RFC 6762). Avahi on the
  MASTER Jetson answers `upes-ecs.local`; phones send/receive on this group.
- **keepalived VRRP** — IP protocol `112`, destination `224.0.0.18`. The two boards
  elect one MASTER over this between themselves.

Both are **link-local (TTL 1) multicast that a Layer-2 switch floods within the VLAN
by default**, so on a normal switched voice VLAN **no extra configuration is needed**.
Verify (don't assume) these two points on the customer's gear:

- **IGMP snooping must not black-hole them.** These groups are in the
  `224.0.0.0/24` link-local range, which IGMP snooping is required to **flood** (never
  prune). Most EX switches do this correctly out of the box. If you have aggressive
  multicast filtering, explicitly allow `224.0.0.251` and `224.0.0.18` on the voice
  VLAN. Simplest confirmation: from a phone on the VLAN, `ping upes-ecs.local` reaches
  the MASTER, and `avahi-resolve -4 -n upes-ecs.local` on the standby board returns the
  MASTER's IP.
- **No inter-switch multicast filter** strips link-local groups on the trunks — the
  two boards must both see VRRP `224.0.0.18` for the election to work across switches.

> There is deliberately **no VIP/VRRP-on-the-router content** in this guide. If you
> want **gateway** redundancy (two routers sharing `10.20.30.254`), that is a
> *separate* Juniper VRRP on the IRB and is unrelated to the PBX failover — see the
> VIP guide (`../NETWORK-JUNIPER.md` §6) if you need it. It does **not** interact with
> this design.

---

## 7. PoE for IP phones (EX access ports)

Power the desk phones from the switch:
```
set poe interface all                       # or enable per-port
set poe management class                    # allocate by detected PoE class
set poe guard-band 5                         # reserve headroom (watts)
set poe interface ge-0/0/0 priority high     # emergency phones win contention
```
Check the budget after phones are up:
```
show poe controller
show poe interface
```
> Confirm the switch's total **PoE budget** covers all phones (sum their class
> wattage). Set emergency phones to `priority high` so they are not the ones cut if the
> budget is overrun.

---

## 8. Wi-Fi / Android softphones — the #1 gotcha (worse here than with a VIP)

If staff use the Android softphone over Wi-Fi:
- Put the **SSID/AP on the voice VLAN**, same subnet as the Jetsons
  (`10.20.30.0/24`) — the AP's switch port is a **trunk** carrying `voice`, and the
  SSID maps to VLAN 30.
- **DISABLE client/station isolation** on that SSID. This matters **even more** in the
  mDNS design: with client isolation ON, wireless clients cannot receive the mDNS
  multicast, so they **cannot resolve `upes-ecs.local` at all** — registration and
  media both fail, and failover cannot be seen. Turn it **off**.
- Ensure the AP/controller **forwards multicast to wireless clients** (some
  controllers have a "multicast enhancement"/"drop multicast" toggle — mDNS must be
  allowed). Many enterprise APs offer an "mDNS gateway/bonjour" feature; if the AP and
  the Jetsons are on the **same VLAN** you do **not** need it (plain L2 flooding
  suffices) — but if it is enabled, make sure it does not *restrict* `upes-ecs.local`.

Example (AP switch port as a voice trunk):
```
set interfaces ge-0/0/40 description "AP - voice SSID"
set interfaces ge-0/0/40 unit 0 family ethernet-switching interface-mode trunk
set interfaces ge-0/0/40 unit 0 family ethernet-switching vlan members voice
set class-of-service interfaces ge-0/0/40 unit 0 classifiers dscp UPES-VOICE
```

---

## 9. Firewall — LAN-only, internet-free (SRX / router)

Campus-internal emergency system: allow SIP/RTP (and mDNS) **within** the voice VLAN
and **block SIP/RTP from the internet / other zones**. On an SRX:

```
# Address book: the voice subnet + the mDNS group.
set security zones security-zone VOICE address-book address VOICE-NET 10.20.30.0/24
set security zones security-zone VOICE address-book address MDNS-GRP 224.0.0.251/32

# Custom apps for the PBX ports + mDNS.
set applications application SIP-UDP protocol udp destination-port 5060
set applications application RTP-UDP protocol udp destination-port 10000-10019
set applications application MDNS-UDP protocol udp destination-port 5353

# Intra-voice-VLAN: permit SIP + RTP + mDNS (phones <-> Jetsons).
set security policies from-zone VOICE to-zone VOICE policy voice-allow match source-address VOICE-NET
set security policies from-zone VOICE to-zone VOICE policy voice-allow match destination-address [ VOICE-NET MDNS-GRP ]
set security policies from-zone VOICE to-zone VOICE policy voice-allow match application [ SIP-UDP RTP-UDP MDNS-UDP ]
set security policies from-zone VOICE to-zone VOICE policy voice-allow then permit

# Block SIP/RTP crossing to/from the untrusted/internet zone (LAN-only design).
set security policies from-zone VOICE to-zone untrust policy voice-no-internet match source-address VOICE-NET
set security policies from-zone VOICE to-zone untrust policy voice-no-internet match destination-address any
set security policies from-zone VOICE to-zone untrust policy voice-no-internet match application [ SIP-UDP RTP-UDP ]
set security policies from-zone VOICE to-zone untrust policy voice-no-internet then deny
set security policies from-zone untrust to-zone VOICE policy inbound-voice-block match source-address any
set security policies from-zone untrust to-zone VOICE policy inbound-voice-block match destination-address VOICE-NET
set security policies from-zone untrust to-zone VOICE policy inbound-voice-block match application any
set security policies from-zone untrust to-zone VOICE policy inbound-voice-block then deny
```
> **Do not enable the SRX SIP ALG** — the PBX handles media on a flat LAN and an ALG
> often mangles SIP: `set security alg sip disable`. Note mDNS is **link-local
> multicast** and normally stays on the L2 VLAN — it usually never reaches the SRX at
> all; the `MDNS-UDP`/`MDNS-GRP` entries above are only relevant if intra-VLAN traffic
> is inspected by a firewall-on-a-stick. If the "firewall" is just an EX switch,
> enforce the same with a `family ethernet-switching` filter that permits SIP/RTP/mDNS
> between voice-VLAN hosts and drops it elsewhere.

---

## 10. "Works 100%" pre-go-live checklist

Tick every box on the **customer's real gear** before handover:

- [ ] Voice VLAN (30) exists on **both** switches and is **trunked across every
      inter-switch/uplink** — it is one L2 segment spanning both Jetsons.
- [ ] Both Jetsons (`.11`, `.12`) are in the **same voice subnet** and are **excluded
      from DHCP**. (No VIP to plan.)
- [ ] **QoS end-to-end:** RTP = EF (strict-priority queue), SIP = CS3/AF31, marked at
      the edge, classifier + scheduler-map + rewrite applied on access **and**
      trunk/router ports; verified under a load test (voice stays clean).
- [ ] **No AP client isolation** on the voice SSID; Wi-Fi clients can reach the PBX
      **and receive mDNS** (they can resolve `upes-ecs.local`).
- [ ] **mDNS multicast** (`224.0.0.251:5353`) and **keepalived-VRRP multicast**
      (`224.0.0.18`) are allowed on the voice VLAN (default on an L2 switched VLAN —
      confirm IGMP snooping floods link-local groups; verify with
      `avahi-resolve -4 -n upes-ecs.local` from the standby board and a phone).
- [ ] **PoE budget** covers all phones; emergency phones set to high PoE priority.
- [ ] **Firewall**: SIP `5060/udp` + RTP `10000-10019/udp` permitted **within** the
      voice VLAN, **blocked from the internet**; SIP ALG disabled.
- [ ] Phones register to **`upes-ecs.local`** with a **short registration expiry
      (≈60 s)** and can resolve `.local` (Linphone can).
- [ ] **Failover tested** (README-MDNS §7): stop Asterisk on the active node →
      `avahi-resolve upes-ecs.local` flips to the survivor's IP → **dial 111 still
      works**; then power off the active node → survivor publishes the name → 111 still
      works. Record failover + re-registration times.

Cross-reference: IP plan and failover procedure are in
`deploy/jetson/mdns/README-MDNS.md`; the RTP port range lives in
`deploy/asterisk/rtp.conf`; SIP port/transport in `deploy/asterisk/pjsip.conf`; the
mDNS name mechanism is documented in `deploy/qemu/HOSTNAME-mDNS.md`.
