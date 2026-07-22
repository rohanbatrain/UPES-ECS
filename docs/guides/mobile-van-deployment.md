# UPES-ECS Mobile Disaster-Response Van & Repeater Deployment

The deployment model that makes UPES-ECS survive a real disaster: a **self-powered
van carrying the PBX**, extended across the area by **corner repeaters** that boost
the van's signal. This is what keeps 111 alive when fixed campus power/infra is down.

> This directly resolves the two worst risks in the [Risk Register](21-Risk-Register-and-Gaps.md):
> **R1 (power)** — the van is autonomously powered; **R8 (single point of failure)** —
> the van is deployable and doubles as failover for the campus PBX.

---

## 1. Two deployment modes

| Mode | When | PBX location | Power |
|---|---|---|---|
| **A — Campus (fixed)** | Everyday operation | Campus server `upes-ecs-pbx-01` | Mains (+ UPS recommended) |
| **B — Mobile / Field (van)** | Disaster (earthquake, fire, outage) or off-grid incident | **Inside the van** | Van generator + battery bank (+ solar) |

The two modes run the **same UPES-ECS config** (same numbers, SAP-ID accounts, SOP).
The van can also act as a **warm standby** for the campus PBX — if the campus server
dies, the van takes over.

---

## 2. What's in the van

```text
┌──────────────────────── Disaster-Response Van ────────────────────────┐
│  PBX unit          Rugged mini-PC / server running Asterisk+FreePBX    │
│  Power             Generator + battery bank + (optional) solar          │
│  Wireless          Access point(s) + repeater backhaul radios + mast    │
│  ERT console       Answering device(s), headset, screen for dashboard   │
│  Storage           Local recording + log storage (encrypted)            │
│  Spare kit         Batteries, cabling, spare repeater, fuel             │
└────────────────────────────────────────────────────────────────────────┘
```

- **PBX unit:** low-power mini-PC/server — sips watts, easy to run off battery for hours.
- **Mast/antenna:** raises the van's signal for line-of-sight to the repeaters.
- **Uplink:** stays **LAN-only** by design — the van hosts its own local network; no
  internet needed for 111 to work. (Any optional external uplink is out of scope.)

---

## 3. The repeater network

Corner-mounted repeaters extend the van's coverage across campus / the incident zone.

```text
   Phones ─┐        ┌─ Repeater (corner)        ┌─ Repeater (corner)
           ▼        ▼        ▲                   ▲
        [ Repeater mesh / point-to-point backhaul ] ──► VAN (PBX)
           ▲        ▲                                     │
   Phones ─┘        └─ Repeater (corner)                  ▼
                                                     111 / queue / recording
```

| Aspect | Guidance |
|---|---|
| **Placement** | On corners / high points for line-of-sight; overlap coverage so one failure isn't a dead zone. |
| **Power** | Each repeater self-powered — battery + solar, or PoE where mains survives. Never assume grid. |
| **Backhaul** | Mesh or point-to-point radio back to the van (same tech family as [Multi-Campus Wireless](20-Multi-Campus-Wireless.md)). |
| **SSID** | Single SSID across all repeaters so phones roam seamlessly toward the van. |
| **Redundancy** | Overlapping coverage; a spare repeater in the van; a dead repeater degrades coverage, doesn't kill the system. |
| **Monitoring** | Treat each repeater + the backhaul link as **critical devices** on the Health Dashboard. |

---

## 4. Power autonomy (this is the point)

The van and repeaters must run **independent of the grid**.

| Component | Power source | Note |
|---|---|---|
| Van PBX + AP + console | Battery bank (primary) → generator (top-up) → solar (trickle) | Low total draw; battery gives quiet, hours-long runtime |
| Repeaters | Battery + solar (or PoE if mains alive) | Autonomous at each corner |
| Generator | Fuel-based | For extended events; keep fuel reserve |

**Load budget (do the math before deploying):** PBX mini-PC + AP + console is typically
tens of watts — a modest battery bank runs it for hours; the generator extends to
days. Size battery/fuel to the **realistic disaster window** you must cover.

---

## 5. Deployment SOP (Mode B activation)

```text
1. ERT Lead declares a field deployment.
2. Drive van to the incident zone with coverage/line-of-sight to repeaters.
3. Raise mast / deploy antenna. Start power (battery, generator as needed).
4. Power-on sequence: PBX boots → AP up → repeaters power on → backhaul links up.
5. Verify PBX: FreePBX/Asterisk running; queue has ≥ 2 available responders.
6. Verify coverage: test-register a phone at the far edge of each repeater.
7. Test call: dial 199 (drill) then 111 → ERT console rings → recording OK.
8. Announce coverage is live; page instructions if a declared incident (see ERT SOP surge posture).
```

**Target:** van deployable and 111 answering within a defined setup window (set + drill this).

---

## 6. Pre-staged readiness (so deployment is fast)

Keep the van **always ready**, not assembled on the day:

- [ ] PBX pre-configured with current UPES-ECS config (synced from campus).
- [ ] Batteries charged; generator fueled and tested.
- [ ] Repeaters charged / solar checked; spare repeater onboard.
- [ ] Config backup on the van matches campus (see [Backup & Restore](11-Backup-Restore-Procedure.md)).
- [ ] Antenna/mast/cabling checked.
- [ ] ERT console + headset working.
- [ ] Monthly van deployment drill logged.

---

## 7. Van as campus-PBX failover (resolves R8)

If the campus server fails, the van becomes the live PBX:
```text
Campus PBX down → deploy van on campus → phones re-register to van SSID →
111 answered from the van console → restore campus server in parallel
```
Because the van already carries a synced config + backup, this is a swap, not a rebuild.

---

## 8. Coverage & roaming

- Phones associate to the **nearest repeater**; all traffic reaches the van PBX.
- Same SSID everywhere → seamless roam as responders/callers move.
- Position the van + repeaters to cover the **incident zone first**, then widen.

---

## 9. Ties to other docs & open items

- Extends [Local Infrastructure Diagram](15-Local-Infrastructure-Diagram.md) (Mode A ↔ Mode B).
- Shares wireless backhaul tech with [Multi-Campus Wireless](20-Multi-Campus-Wireless.md).
- Surge/paging behaviour during a declared incident → [ERT SOP](02-ERT-SOP.md).

**TBD to confirm:** van power sizing (battery Ah + generator kW + fuel reserve),
repeater model/backhaul, number + placement of repeaters for full campus coverage,
target van setup time, sync process to keep the van config current with campus.
