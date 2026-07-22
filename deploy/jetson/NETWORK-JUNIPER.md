# UPES-ECS — Juniper Integration Guide (EX switches + SRX/MX router)

This is the **network side** that makes the two-Jetson HA cluster and its floating
VIP actually work — VLAN, DHCP, QoS, PoE, Wi-Fi, and firewall — with concrete
Junos `set` commands and plain-language explanations for a non-expert.

> **Disclaimer.** These are standard, correct Junos patterns, but syntax varies by
> platform/version (EX2300/EX3400/EX4300 ELS, SRX, MX). **Validate against the
> customer's exact Junos versions** and adapt interface names. Apply in a
> `configure` session and `commit confirmed 5` so a mistake auto-rolls-back.

Assumptions used throughout (match your `deploy/jetson/README.md` IP plan):

| Thing | Value (example) |
|---|---|
| Voice VLAN name / ID | `voice` / `30` |
| Voice subnet | `10.20.30.0/24` |
| Gateway (IRB on the switch/router) | `10.20.30.254` |
| **VIP (phones register here)** | `10.20.30.1` (keepalived-managed) |
| Jetson primary / secondary | `10.20.30.11` / `10.20.30.12` |
| Phone access ports | `ge-0/0/0` … `ge-0/0/23` |
| Jetson ports | primary `ge-0/0/46`, secondary `ge-0/0/47` |
| Switch-to-switch / uplink trunk | `ge-0/0/47` … `xe-0/1/0` |

---

## 1. Big picture — why the network matters here

The whole HA design rests on **one flat Layer-2 voice VLAN that spans both
switches and reaches both Jetsons**. keepalived moves the VIP between the two
boards by sending a **gratuitous ARP**; that only works if both boards are on the
**same broadcast domain (VLAN/subnet)**. If the voice VLAN is not L2-contiguous
across both switches, the VIP cannot fail over. So:

1. Create a **voice VLAN** and put phone access ports + both Jetson ports in it.
2. **Trunk** the voice VLAN across every switch-to-switch / uplink link so it is
   one L2 segment across the whole campus edge.
3. **DHCP** phones on that VLAN; keep the VIP + Jetsons static (outside the pool).
4. **QoS end-to-end** so voice never drops under load.
5. **PoE** for phones; **Wi-Fi** APs on the voice VLAN with client isolation OFF.
6. **Firewall** SIP/RTP inside the VLAN, blocked from the internet (LAN-only).

---

## 2. Voice VLAN + access ports + trunks (EX switches)

**Create the VLAN (do this identically on BOTH switches):**
```
set vlans voice vlan-id 30
set vlans voice description "UPES-ECS voice / phones / Jetson PBX cluster"
```

**Phone access ports** (untagged/access in the voice VLAN). If phones tag their
own voice VLAN and pass a PC through, use `native-vlan` for data + tagged voice;
the simple all-voice case:
```
set interfaces ge-0/0/0 unit 0 family ethernet-switching interface-mode access
set interfaces ge-0/0/0 unit 0 family ethernet-switching vlan members voice
```
Apply to each phone port (`ge-0/0/0`–`ge-0/0/23`). To do a range quickly, use an
`interface-range`:
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
makes VIP failover possible when the two Jetsons hang off different switches):
```
set interfaces ge-0/0/47 description "Uplink/trunk to peer switch"
set interfaces ge-0/0/47 unit 0 family ethernet-switching interface-mode trunk
set interfaces ge-0/0/47 unit 0 family ethernet-switching vlan members voice
```
> Put **every** inter-switch link and the uplink toward the router in trunk mode
> carrying `voice` (plus your other VLANs). The voice VLAN must appear on both
> switches for the VIP to move between boards.

**Gateway (IRB) for the voice subnet** — on the L3 switch or router:
```
set interfaces irb unit 30 description "Voice VLAN gateway"
set interfaces irb unit 30 family inet address 10.20.30.254/24
set vlans voice l3-interface irb.30
```

---

## 3. Both Jetsons + the VIP on the same voice subnet

- Jetson **primary** = `10.20.30.11/24`, **secondary** = `10.20.30.12/24`, both
  set statically on the boards (netplan — see README §4).
- The **VIP `10.20.30.1/24`** is **not** configured on any switch port or on the
  IRB. It is owned by **keepalived** on whichever Jetson is MASTER. The switch
  just needs the voice VLAN present and to pass gratuitous ARP (default behaviour
  — see §6). Nothing Juniper-side "owns" the VIP.
- Keep the VIP, `.11`, `.12`, and `.254` **out of the DHCP pool** (next section).

---

## 4. DHCP for phones (Juniper DHCP server, on the voice VLAN)

Phones get addresses from the switch/router's DHCP server on the voice VLAN.
Reserve the low addresses for infrastructure; hand out a mid-range pool:
```
set system services dhcp-local-server group VOICE interface irb.30
set access address-assignment pool VOICE-POOL family inet network 10.20.30.0/24
set access address-assignment pool VOICE-POOL family inet range VR low 10.20.30.50 high 10.20.30.200
set access address-assignment pool VOICE-POOL family inet dhcp-attributes router 10.20.30.254
set access address-assignment pool VOICE-POOL family inet dhcp-attributes name-server 10.20.30.254
```
> **Do NOT include `10.20.30.1` (VIP), `.11`, `.12`, or `.254` in the range.**
> Optionally push the SIP server to phones via a DHCP option (e.g. option 120 /
> vendor-specific) pointing at the **VIP** so phones auto-learn the registrar; or
> set the registrar in your phone provisioning. If the DHCP server lives on a
> different box, use a **DHCP relay** instead:
```
set forwarding-options dhcp-relay server-group DHCP 10.20.30.254
set forwarding-options dhcp-relay group VOICE interface irb.30
set forwarding-options dhcp-relay group VOICE active-server-group DHCP
```

---

## 5. CoS / QoS end-to-end (so voice never drops under load)

Goal: mark **RTP media as EF (DSCP 46)** and **SIP signalling as CS3/AF31**, put
media into a **strict-priority (expedited-forwarding) queue**, and **honour these
markings across every EX switch and the router**. Mark at the access edge (trust
the PBX/phones minimally, remark to be safe), classify inbound, schedule on egress,
rewrite on egress toward trunks.

**5.1 Forwarding classes → queues** (EX has 8 queues; use EF for voice, a class
for signalling):
```
set class-of-service forwarding-classes class VOICE-RTP queue-num 5
set class-of-service forwarding-classes class VOICE-SIG queue-num 3
set class-of-service forwarding-classes class BEST-EFFORT queue-num 0
```

**5.2 Behaviour-aggregate (DSCP) classifier** — trust DSCP coming in from phones/
PBX and map it to the right forwarding class:
```
set class-of-service classifiers dscp UPES-VOICE forwarding-class VOICE-RTP loss-priority low code-points ef
set class-of-service classifiers dscp UPES-VOICE forwarding-class VOICE-SIG loss-priority low code-points cs3
set class-of-service classifiers dscp UPES-VOICE forwarding-class VOICE-SIG loss-priority low code-points af31
set class-of-service classifiers dscp UPES-VOICE forwarding-class BEST-EFFORT loss-priority low code-points 000000
```

**5.3 Multifield classifier (mark at the edge)** — if phones/softphones don't mark
correctly, remark by port/protocol so voice is trusted from the first hop. Match
RTP UDP 10000–10019 → EF, SIP 5060 → CS3:
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

**5.4 Schedulers** — give RTP **strict priority**, signalling a guaranteed slice,
the rest best-effort:
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

**5.6 Rewrite rules** — re-stamp DSCP on egress (esp. toward trunks/uplinks) so the
next switch/router trusts it:
```
set class-of-service rewrite-rules dscp UPES-REWRITE forwarding-class VOICE-RTP loss-priority low code-point ef
set class-of-service rewrite-rules dscp UPES-REWRITE forwarding-class VOICE-SIG loss-priority low code-point cs3
set class-of-service rewrite-rules dscp UPES-REWRITE forwarding-class BEST-EFFORT loss-priority low code-point 000000
```

**5.7 Apply the map + rewrite to the trunk/uplink egress ports** (carry QoS across
switches and to the router):
```
set class-of-service interfaces ge-0/0/47 scheduler-map UPES-MAP
set class-of-service interfaces ge-0/0/47 unit 0 rewrite-rules dscp UPES-REWRITE
set class-of-service interfaces ge-0/0/47 unit 0 classifiers dscp UPES-VOICE
```
> Do this on **every** inter-switch and router-facing port so EF/CS3 survive the
> whole path. On the **router (MX/SRX)**, mirror the classifier + scheduler-map so
> the EF queue is honoured there too — voice must be strict-priority everywhere it
> transits, or it will drop under congestion.

Match the RTP port range to the PBX: this repo uses **UDP 10000–10019** (see
`deploy/asterisk/rtp.conf`) — adjust the firewall/QoS ranges if that changes.

---

## 6. VRRP note — keep the app VIP separate from gateway VRRP

- The **application VIP** (`10.20.30.1` that phones register to) is provided by
  **keepalived on the Jetsons at Layer 2**. **Juniper does NOT need VRRP for it.**
  The switch only has to (a) carry the voice VLAN across both nodes and (b) pass
  the **gratuitous ARP** keepalived sends on failover — which EX switches do by
  default (they just relearn the VIP's MAC on the new port). Nothing to configure
  for the app VIP beyond the VLAN itself.
- If you *also* want **gateway redundancy** (two routers/L3 switches sharing
  `10.20.30.254`), that is a **separate** Juniper **VRRP** on the IRB — keep it
  distinct from the app VIP and use a different VRID:
  ```
  set interfaces irb unit 30 family inet address 10.20.30.254/24 vrrp-group 30 virtual-address 10.20.30.254
  set interfaces irb unit 30 family inet address 10.20.30.254/24 vrrp-group 30 priority 200
  set interfaces irb unit 30 family inet address 10.20.30.254/24 vrrp-group 30 accept-data
  ```
  > Two independent things: **keepalived VRID (e.g. 51)** for the PBX VIP on the
  > Jetsons, and **Juniper VRRP group 30** for the default gateway. Give them
  > different VRIDs so they never collide on the segment.

---

## 7. PoE for IP phones (EX access ports)

Power the desk phones from the switch:
```
set poe interface ge-0/0/0
set poe interface all                       # or enable per-port
set poe management class                    # allocate by detected PoE class
set poe guard-band 5                         # reserve headroom (watts)
```
Check the budget after phones are up:
```
show poe controller
show poe interface
```
> Confirm the switch's total **PoE budget** covers all phones (sum their class
> wattage). If you overrun the budget, low-priority ports get cut — set
> `set poe interface ge-0/0/0 priority high` on emergency phones so they win
> contention.

---

## 8. Wi-Fi / Android softphones — the #1 gotcha

If staff use the Android softphone over Wi-Fi:
- Put the **SSID/AP on the voice VLAN**, same subnet as the Jetsons
  (`10.20.30.0/24`) — the AP's switch port is a **trunk** carrying `voice`, and the
  SSID maps to VLAN 30.
- **DISABLE client/station isolation** on that SSID. This is the most common
  failure: with client isolation ON, a phone can reach the gateway but **cannot
  reach the Jetson PBX or the VIP**, so registration/media silently fail. Turn it
  **off** so wireless clients can talk to the PBX on the same subnet.
- Allow the voice VLAN to pass gratuitous ARP over the WLAN so the VIP move is seen
  by wireless clients too (default on most controllers; verify).

Example (AP switch port as a voice trunk):
```
set interfaces ge-0/0/40 description "AP - voice SSID"
set interfaces ge-0/0/40 unit 0 family ethernet-switching interface-mode trunk
set interfaces ge-0/0/40 unit 0 family ethernet-switching vlan members voice
set class-of-service interfaces ge-0/0/40 unit 0 classifiers dscp UPES-VOICE
```

---

## 9. Firewall — LAN-only, internet-free (SRX / router)

This is a **campus-internal** emergency system. Allow SIP/RTP **within** the voice
VLAN and **block it from the internet / other zones**. On an SRX:

```
# Address book: the voice subnet.
set security zones security-zone VOICE address-book address VOICE-NET 10.20.30.0/24

# Custom apps for the PBX ports.
set applications application SIP-UDP protocol udp destination-port 5060
set applications application RTP-UDP protocol udp destination-port 10000-10019

# Intra-voice-VLAN: permit SIP + RTP (phones <-> Jetsons/VIP).
set security policies from-zone VOICE to-zone VOICE policy voice-allow match source-address VOICE-NET
set security policies from-zone VOICE to-zone VOICE policy voice-allow match destination-address VOICE-NET
set security policies from-zone VOICE to-zone VOICE policy voice-allow match application [ SIP-UDP RTP-UDP ]
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
> **Do not enable the SRX SIP ALG** for this design — the PBX handles NAT/media on
> a flat LAN and an ALG often mangles SIP. Disable it if present:
> `set security alg sip disable`. Keep the system with **no internet path** for
> SIP/RTP; only management (SSH/updates) needs egress, and that can be tightly
> scoped or done offline.

If the "firewall" is really just an EX switch (no SRX), enforce the same with a
`family ethernet-switching` filter that only permits SIP/RTP between voice-VLAN
hosts and drops it elsewhere.

---

## 10. "Works 100%" pre-go-live checklist

Tick every box on the **customer's real gear** before handover:

- [ ] Voice VLAN (30) exists on **both** switches and is **trunked across every
      inter-switch/uplink** — it is one L2 segment spanning both Jetsons.
- [ ] Both Jetsons (`.11`, `.12`) and the **VIP** (`.1`) are in the **same voice
      subnet**; VIP + Jetsons are **excluded from DHCP**.
- [ ] Phones get DHCP on the voice VLAN and register to the **VIP** with a **short
      registration expiry (≈60 s)**.
- [ ] **No AP client isolation** on the voice SSID; Wi-Fi clients can reach the VIP.
- [ ] **QoS end-to-end:** RTP = EF (strict-priority queue), SIP = CS3/AF31, marked
      at the edge, classifier + scheduler-map + rewrite applied on access **and**
      trunk/router ports; verified under a load test (voice stays clean).
- [ ] **Gratuitous ARP** passes on the voice VLAN (default) so the VIP move is seen
      by phones and APs.
- [ ] **PoE budget** covers all phones; emergency phones set to high PoE priority.
- [ ] **Firewall**: SIP `5060/udp` + RTP `10000-10019/udp` permitted **within** the
      voice VLAN, **blocked from the internet**; SIP ALG disabled.
- [ ] **Failover tested** (README §9): stop Asterisk on the active node → VIP moves
      → **dial 111 still works**; then power off the active node → survivor holds
      the VIP → 111 still works. Record failover + re-registration times.

Cross-reference: IP plan and failover procedure are in
`deploy/jetson/README.md`; the RTP port range lives in `deploy/asterisk/rtp.conf`;
SIP port/transport in `deploy/asterisk/pjsip.conf`.
