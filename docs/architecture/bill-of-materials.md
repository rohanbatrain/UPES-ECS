# UPES-ECS Bill of Materials

Exactly what you buy, use, and stage to run UPES-ECS — for both **Mode A (campus,
fixed)** and **Mode B (van, mobile)**. Software is entirely **free**. Hardware is listed
by **quantity, spec, and purpose**, with **Minimum** vs **Recommended** and a **Status**
(have / need / TBD).

> **Prices are TBD** — the budget is deferred. This BOM deliberately carries a **Cost:
> TBD** column and focuses on *what* and *how many*, not *how much*. Fill Cost once
> quotes are in. Models flagged **TBD** must be confirmed with UPES IT before purchase.

Legend — **Status:** `have` = on hand · `need` = must acquire · `TBD` = spec/model not
yet decided. **Min/Rec:** `M` = minimum to go live · `R` = recommended for a resilient pilot.

---

## (a) Campus fixed deployment — Mode A

The everyday emergency line: one server, the campus network, and dedicated ERT answer
points. Ties to [02 §5–6](02-System-Architecture.md) and [SOP 15](../SOP/15-Local-Infrastructure-Diagram.md).

### a.1 Server (the PBX)

| Item | Qty | Spec / Notes | Purpose | Min/Rec | Status | Cost |
|---|---|---|---|---|---|---|
| PBX server / mini-PC | 1 | x86-64, 4+ cores, 8 GB RAM, SSD; **static IP mandatory**; hostname `upes-ecs-pbx-01` | Runs Asterisk 18+/FreePBX — the whole system | M | need | TBD |
| OS | 1 | Ubuntu Server LTS / Debian stable (free) | Host OS; auto-security-updates recommended | M | have | — |
| Recordings storage | 1 | Tens of GB free (90-day audio + logs); separate disk/partition preferred | Holds recordings, voicemail, CDR/CEL, logs | M | need | TBD |
| Server UPS | 1 | Sized to ride out brief outages + clean shutdown | **Power is not optional** for a disaster system — keeps 111 alive | M | need | TBD |
| Locked rack / cabinet | 1 | Control-room / IT-room placement; **not** a personal machine | Physical security + access control | R | TBD | TBD |

### a.2 Network (router / switch / AP)

| Item | Qty | Spec / Notes | Purpose | Min/Rec | Status | Cost |
|---|---|---|---|---|---|---|
| Router / gateway | 1 | LAN reachable to PBX; **no public SIP/RTP exposure**; model **TBD** | Routes the campus LAN; hosts management subnet | M | TBD | TBD |
| Ethernet switch | 1 | Enough ports for PBX + APs + fixed devices; PoE preferred; model **TBD** | Wired backbone; PoE powers APs/IP phones later | M | TBD | TBD |
| Wi-Fi access point(s) | 1+ | Cover the pilot zone; **client-isolation OFF** or voice-VLAN; SSID **TBD**; model **TBD** | Caller + answer-point connectivity over Wi-Fi | M | TBD | TBD |
| Voice VLAN / QoS | — | Config, not hardware; optional first pilot | Prioritise SIP/RTP under load | R | TBD | — |
| Network UPS | 1–3 | UPS on switch + router + key APs | Keep the LAN up when mains drops | R | need | TBD |

> **TBD to confirm with UPES IT:** server IP / subnet / gateway, Wi-Fi SSID,
> client-isolation status, and the exact router / switch / AP models.

### a.3 ERT answer points (dedicated Androids — Phase 1)

Fixed answer points are **dedicated Android phones running Linphone**, logged in as a
**responder position** (not a person). IP phones come later on the **same extension**
([SOP 14 §3](../SOP/14-Device-Provisioning-Sheet.md)).

| Item | Qty | Spec / Notes | Purpose | Min/Rec | Status | Cost |
|---|---|---|---|---|---|---|
| ERT answer-point Android | **3** min | Android + Linphone; battery-optimization OFF, screen-lock off, on charger | Answer the 111 queue: ERT Lead `4101` + Operators `4110`/`4111` | M | need | TBD |
| ERT answer-point Android (add) | +2 | Same spec | Add Operator `4112`, reserve `4113` (in 111 queue), Control `4120` | R | need | TBD |
| Chargers + wall mounts | 1 per device | Always-on charging; labelled per **position** | Answering never depends on a personal phone's battery | M | need | TBD |
| Headsets (answer points) | 1 per device | Wired; hands-free for logging while talking | Clear audio + note-taking during a call | R | need | TBD |

### a.4 Responder devices (dispatch targets)

`ctx_responder` positions receive dispatch/handoff — they do **not** answer the 111 queue.

| Item | Qty | Spec / Notes | Purpose | Min/Rec | Status | Cost |
|---|---|---|---|---|---|---|
| Responder Android | 0 (M) / 2+ (R) | Android + Linphone as `4200` Medical, `4300` Security | Receive dispatch; Medical/Security can start as dispatch-by-mobile | R | need | TBD |
| Fixed-device phones | later | `4700s` IP speakers / gate phones (`ctx_fixed_device`) | Location-bound announce / gate points | R | TBD | TBD |

### a.5 Storage & backup media

| Item | Qty | Spec / Notes | Purpose | Min/Rec | Status | Cost |
|---|---|---|---|---|---|---|
| Backup target | 1 | Local disk / NAS on university infra; **no cloud** | 30 daily + 12 weekly config snapshots; encrypted at rest | R | need | TBD |
| Git repo host (LAN) | 1 | `upes-ecs-config` on local infra | Versioned custom config; never carries secrets | R | have | — |

---

## (b) Van / mobile deployment — Mode B

Self-powered PBX-in-a-van + corner repeaters — disaster operation **and** failover for
the campus PBX. Same config, numbers, SOP. Ties to [SOP 23](../SOP/23-Mobile-Van-Deployment.md).

### b.1 Van core

| Item | Qty | Spec / Notes | Purpose | Min/Rec | Status | Cost |
|---|---|---|---|---|---|---|
| Rugged PBX mini-PC | 1 | Low-power x86-64; runs Asterisk/FreePBX; pre-synced with campus config | The van's PBX — hosts 111 off-grid | M | need | TBD |
| ERT console + screen | 1 | Answering Android/laptop + headset + dashboard screen | Answer + monitor from the van | M | need | TBD |
| Van storage | 1 | Encrypted local recording + log storage | Same retention/security as campus | M | need | TBD |
| Van AP | 1+ | Access point for local phones; single SSID with repeaters | Phones associate to the van network | M | need | TBD |

### b.2 Van power (autonomy is the point)

| Item | Qty | Spec / Notes | Purpose | Min/Rec | Status | Cost |
|---|---|---|---|---|---|---|
| Battery bank | 1 | Ah **TBD** — size to the realistic disaster window; primary source | Quiet, hours-long runtime for PBX + AP + console | M | need | TBD |
| Generator | 1 | kW **TBD**; fuel reserve | Top-up / extended events (days) | R | need | TBD |
| Solar panel(s) + charge controller | 1 set | Trickle charge; sizing **TBD** | Extend battery runtime; grid-independent | R | need | TBD |
| Inverter / DC-DC | 1 | Match device input; sized to load | Clean power to PBX + network gear | M | need | TBD |

> **TBD to confirm:** van **power sizing** — battery Ah + generator kW + fuel reserve —
> sized to the disaster window UPES must cover. Do the load math before deploying
> ([SOP 23 §4](../SOP/23-Mobile-Van-Deployment.md)).

### b.3 Mast / antenna + corner repeaters

| Item | Qty | Spec / Notes | Purpose | Min/Rec | Status | Cost |
|---|---|---|---|---|---|---|
| Mast / antenna | 1 | Raises van signal for line-of-sight to repeaters | Backhaul + coverage from the van | M | need | TBD |
| Corner repeaters | N (**TBD**) | Corner/high-point mount; overlapping coverage; model/backhaul **TBD** | Extend van coverage across the incident zone | R | need | TBD |
| Repeater power (per repeater) | 1 per repeater | Battery + solar, or PoE where mains survives | Each repeater autonomous at its corner | R | need | TBD |
| Spare repeater | 1 | Onboard spare | A dead repeater degrades coverage, doesn't kill 111 | R | need | TBD |

> **TBD to confirm:** repeater **model / backhaul radio**, **number + placement** for
> full campus coverage, and target van setup time. Multi-campus Bidholi↔Kandoli rooftop
> wireless is a later phase ([SOP 20](../SOP/20-Multi-Campus-Wireless.md)).

### b.4 Van spare kit

| Item | Qty | Spec / Notes | Purpose | Min/Rec | Status | Cost |
|---|---|---|---|---|---|---|
| Spare batteries | as needed | Charged, pre-staged | Swap-in during extended events | R | need | TBD |
| Cabling + connectors | 1 kit | Power, Ethernet, antenna feed | Field assembly + repair | M | need | TBD |
| Fuel reserve | as needed | For the generator | Extended-window runtime | R | need | TBD |
| Fuses / spares / tools | 1 kit | Basic field repair | Keep the van deployable | R | need | TBD |

---

## (c) Software — all free

Nothing here costs money; it is the whole software stack.

| Item | Qty | Spec / Notes | Purpose | Min/Rec | Status | Cost |
|---|---|---|---|---|---|---|
| Asterisk 18+ / FreePBX | 1 | Free; official FreePBX distro or `freepbx` on Asterisk 18+/20+ | The PBX — queues, recording, dialplan, GUI | M | have | free |
| Linphone | per device | Free; Android / iOS / macOS / Linux | Softphone for callers **and** ERT answer points | M | have | free |
| MicroSIP | per Windows desk | Free; Windows only | Softphone for any Windows desk / control room | R | have | free |
| This repo (config + scripts) | 1 | `config/`, `scripts/`, `provisioning/`, `setup.sh`, `deploy/` | Dialplan, helper scripts, CSVs, bootstrap, validation harness | M | have | free |

Reference: [config/README.md](../config/README.md) · [provisioning/README.md](../provisioning/README.md) · [deploy/README.md](../deploy/README.md).

---

## (d) Consumables & misc

| Item | Qty | Spec / Notes | Purpose | Min/Rec | Status | Cost |
|---|---|---|---|---|---|---|
| Ethernet cabling (Cat5e/6) | as needed | PBX ↔ switch ↔ router ↔ APs / fixed devices | Wired backbone | M | need | TBD |
| Device labels | 1 set | Label each answer point by **position** (`ERT-Lead-4101`, `Medical-4200`) | Traceability; right person answers the right line | M | need | TBD |
| Headsets | per answer point | Wired, hands-free | Talk + log at once | R | need | TBD |
| Wall mounts / stands | per answer point | Fixed, visible, on-charger | Answer points don't wander or die | R | need | TBD |
| Printed desk references | per position | [ERT SOP](../SOP/02-ERT-SOP.md) + [Quick-Cards](../SOP/25-Quick-Cards.md) | Answer script + dispatch at the desk | M | need | TBD |
| Sealed credential sheets | per account | For one-time secret delivery | Deliver SIP secrets once, securely ([SOP 14 §5](../SOP/14-Device-Provisioning-Sheet.md)) | R | need | TBD |

---

## People (not a purchase, but a hard prerequisite)

The confirmed roster is real people only — **no fabricated names**. They are normal
staff/student accounts **and** trained officers who occupy a **position** on their shift
([SOP 30](../SOP/30-ERT-Roles-and-Shifts.md), [provisioning/pilot-users.csv](../provisioning/pilot-users.csv)):

| SAP ID | Name | Account context (by ID length) |
|---|---|---|
| 40000001 | Staff Member One | `ctx_staff` (8-digit) |
| 40000002 | Staff Member Two | `ctx_staff` (8-digit) |
| 40000003 | Staff Member Three | `ctx_staff` (8-digit) |
| 500120597 | Rohan Batra | `ctx_student` (9-digit) |

Per shift you need: **2 ERT operators available + 1 Lead reachable + 1 IT admin**
(recommended: 3+ operators, Lead + reserves, and a trained backup admin for bus factor).

---

## Absolute minimum (if you have nothing but the network)

```text
1 × mini-PC/server (Ubuntu, static IP)      + 1 × UPS
3 × dedicated Android phones                + 3 × chargers/wall mounts   (ERT 4101/4110/4111)
   (use existing router/switch/AP)
Free software: Asterisk/FreePBX, Linphone, MicroSIP, this repo's config/scripts
People: 2 ERT operators + 1 Lead + 1 IT admin (per shift)
```

**One line:** a server + UPS, three dedicated Androids + chargers, the existing network,
and the free software in this repo is enough to answer real emergencies on **111** —
everything else in this BOM is resilience (van, repeaters, extra answer points) and reach.

> **Prices deferred:** every Cost cell is **TBD** until quotes are gathered. This BOM
> commits to quantity, spec, and purpose only. See the minimum-viable view in
> [01-Bare-Minimum-Checklist.md](01-Bare-Minimum-Checklist.md).
