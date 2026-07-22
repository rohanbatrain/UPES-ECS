# UPES-ECS Multi-Campus Wireless Bridge (Later Phase)

**Status:** Future / later phase — **not** part of Phase 1.
**Goal:** extend UPES-ECS from Bidholi to Kandoli over a **rooftop point-to-point
wireless link**, keeping the system "LAN-only" (no public internet, no PSTN, no cloud).

> Source note (Juniper.md): *"site-to-site wireless connectivity from rooftop, Bidholi
> to Kandoli, without centralised infra."* This document turns that into a plan.

---

## 1. Concept

```text
   BIDHOLI campus LAN                         KANDOLI campus LAN
 ┌────────────────────┐   rooftop PtP wireless  ┌────────────────────┐
 │ upes-ecs-pbx-01    │◄══════ Layer-2/3 ═══════►│ SIP phones / APs   │
 │ (Asterisk/FreePBX) │        bridge link       │ ERT/fixed devices  │
 └────────────────────┘                          └────────────────────┘
```

The wireless bridge makes the two campuses behave like **one LAN**, so existing
UPES-ECS features (111, SAP-ID calling, queue, paging, conferences) work across sites
without a second PBX or any cloud dependency.

---

## 2. Two possible models

| Model | How | When |
|---|---|---|
| **A. Single PBX (bridge only)** | One Asterisk at Bidholi; Kandoli devices register across the wireless link | Simplest; link must be stable + low-latency |
| **B. Second PBX (resilient)** | A PBX per campus, linked by inter-PBX trunk over the bridge; each site survives a link outage | More robust; more to manage |

**Recommendation:** start with **Model A** (matches "without centralised infra" and
minimal added complexity); move to **Model B** only if the link proves unreliable or
each campus needs independent survivability.

---

## 3. Link requirements

The wireless bridge must meet voice-grade quality **end to end**:

| Metric | Target |
|---|---|
| One-way latency (site-to-site) | < 150 ms |
| Packet loss | < 1% |
| Jitter | Low / stable |
| Throughput | Comfortably above peak concurrent RTP (each call ≈ 80–100 kbps) + headroom |
| Availability | Line-of-sight, weather-tolerant, monitored |

- **Line of sight** rooftop-to-rooftop is mandatory for PtP wireless.
- Prioritise **RTP (voice)** with QoS/DSCP across the link.
- Treat the link itself as a **critical monitored device** in Health Monitoring.

---

## 4. Numbering & identity across campuses

- SAP-ID identity model is unchanged — one directory spans both campuses.
- Fixed-device ranges may be **split by site** for clarity, e.g. Bidholi `4000–4499`,
  Kandoli `4500–4999` (finalize in the numbering drill).
- Emergency numbers (111/101/199, paging, conferences) stay **identical** at both sites.
- Paging zones extend with Kandoli-specific zones (new 70x codes).

---

## 5. Resilience considerations (Model B)

- Each campus PBX can answer **local 111** even if the link drops.
- ERT queue membership can be **site-aware** so a caller reaches nearest responders first.
- Cross-site conference/paging degrade gracefully when the link is down (local-only).
- Config + backups replicated to both sites.

---

## 6. Security

- The wireless link carries only UPES-ECS LAN traffic — **encrypted** (WPA3/enterprise
  or link-layer encryption on the PtP radios) and firewalled to allowed subnets.
- No public exposure introduced by the bridge; it is an internal campus-to-campus link.
- Guest traffic never traverses the emergency bridge.

---

## 7. Rollout

```text
1. Survey line-of-sight Bidholi ↔ Kandoli rooftops
2. Install + align PtP radios; measure latency/loss/jitter/throughput
3. Bridge the two LANs; verify cross-site SIP registration + 2-way audio
4. Pilot Model A: Kandoli devices on the Bidholi PBX
5. Cross-site test: 111, SAP-ID calling, paging, conference, recording
6. If link reliability is marginal → move to Model B (PBX per site + trunk)
7. Add link monitoring to the Health Dashboard
```

---

## 8. Out of scope (still)

Even multi-campus, UPES-ECS stays **LAN/wireless-LAN only**: no public internet
dependency, no PSTN, no cloud PBX, no cellular reliance. The wireless bridge is an
**extension of the campus LAN**, not an internet link.

---

## 9. TBD

Rooftop survey + line-of-sight confirmation · PtP radio model/vendor · link
throughput vs. expected concurrent calls · Model A vs B decision · site-split
numbering · QoS support on the radios and switches.
