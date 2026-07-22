# UPES-ECS Local Infrastructure Diagram

**Title:** UPES-ECS Local Infrastructure Diagram · **Boundary:** UPES-ECS LAN (LAN-only)
**Primary path:** Mobile phone → campus Wi-Fi → SIP app → local Asterisk.

---

## 1. Core architecture

```text
 Student / Staff Mobile (Linphone)        ERT Mobile (Linphone)
            │                                     │
            └──────────────┐        ┌─────────────┘
                           ▼        ▼
                    ┌──────────────────────┐
                    │  Campus Wi-Fi AP(s)  │   (client isolation OFF / voice VLAN)
                    └──────────┬───────────┘
                               │
                        ┌──────▼──────┐
                        │   Switch    │──── Fixed answer points (4xxx)*:
                        └──────┬──────┘      ERT Lead 4101, Medical 4200,
                               │             Security 4300
                               │        (* Phase 1: dedicated Android on Wi-Fi;
                               │           wired IP phones later, same extensions)
                        ┌──────▼──────┐
                        │   Router    │──── (management subnet → FreePBX GUI)
                        └──────┬──────┘
                               │
                 ┌─────────────▼──────────────┐
                 │  upes-ecs-pbx-01 (Asterisk)│  static IP · pbx.upes.lan / sip.upes.lan
                 │  FreePBX · queues · VM ·   │  local recording + log storage
                 │  recordings · confbridge   │
                 └────────────────────────────┘

           ✖ No public internet · ✖ No PSTN/SIP trunk · ✖ No cloud · ✖ No cellular dependency
```

---

## 2. Minimum Phase-1 stack

`1 Asterisk/FreePBX server` · `1 router` · `1 switch` · `1 access point` · SIP apps on
selected mobiles · SAP-ID accounts · 1 ERT answering device · local recording/log storage.

**Recommended pilot stack** adds: ERT desk phone, Medical `4200`, Security/control `4300`, local voicemail storage, selected student + ERT mobile users.

---

## 3. Server

| Item | Value |
|---|---|
| Hostname | `upes-ecs-pbx-01` |
| OS | Ubuntu Server LTS / Debian stable |
| IP | **static (mandatory)** — TBD |
| Names | `pbx.upes.lan`, `sip.upes.lan` (IP fallback documented) |
| Placement | Control room / IT room / secure rack — **not** a student/personal machine |
| Storage | Local: recordings, voicemail, CDR/CEL, queue/paging/conference logs |

---

## 4. Networks & segmentation

| Network | Access |
|---|---|
| Student Wi-Fi | SIP/RTP to PBX only |
| Staff Wi-Fi | SIP/RTP to PBX |
| ERT / control-room LAN | Full emergency device access |
| Fixed-device LAN/VLAN | Fixed phones/speakers (static IPs) |
| Management/admin subnet | FreePBX GUI + monitoring — **never** student Wi-Fi |
| **Guest Wi-Fi** | **Blocked** |

- **Client isolation** must be checked; if on, allow SIP/RTP from Wi-Fi clients to the PBX or move them to a voice-enabled SSID/VLAN.
- Static IP for Asterisk is **mandatory**; DNS fallback documented.
- VLAN/QoS is optional for the first pilot, recommended later.

---

## 5. Priority model (build order)

```text
1. Mobile phones on Wi-Fi (primary user access)
2. ERT/control-room answering with stable SIP devices
3. Fixed emergency devices at critical locations
4. Paging speakers / announcement hardware
5. Segmentation, emergency VLANs, PoE, hardening
```

---

## 6. Network quality targets

| Metric | Target |
|---|---|
| One-way latency | < 150 ms |
| Packet loss | < 1% (warn > 1%, critical > 3–5%) |
| Jitter | Low / stable |
| Call setup (internal) | < 3 s (warn > 5 s) |
| Two-way audio | Clear, no frequent drops |

Test before rollout: registration over Wi-Fi, 111/199 calling, SAP-ID calling, two-way audio, screen-lock behaviour, recording, simultaneous calls, and that emergency calls stay priority under normal load.

---

## 7. Power

Power is **assumed available** and is not a current blocker, but the system depends on
powered PBX, router, switch, AP, and ERT devices. UPS/backup power is a later
production enhancement, not a Phase-1 gate.

---

## 8. Out of scope (Phase 1)

Public internet · cellular fallback · PSTN · cloud PBX · external SIP trunk ·
SMS/WhatsApp/email alerts · remote off-campus users · multi-campus routing ·
HA cluster · satellite/anycast. (Multi-campus wireless is a **later** phase — see
[20-Multi-Campus-Wireless.md](20-Multi-Campus-Wireless.md).)
