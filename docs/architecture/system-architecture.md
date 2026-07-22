# UPES-ECS — System Architecture

In-depth architecture of the LAN-only emergency communication system: components,
identity model, permission model, storage, and deployment modes. Diagrams are Mermaid
with ASCII fallbacks.

---

## 1. System context (who talks to what)

```mermaid
graph TB
  subgraph LAN["Campus LAN — LAN-only: no internet, cellular, cloud, PSTN"]
    direction TB
    U["Student / Staff phone<br/>Linphone · SAP ID"]
    ERT["ERT answer points<br/>positions 4101/4110/4111<br/>(dedicated Androids)"]
    RESP["Responder positions<br/>Medical 4200 · Security 4300<br/>(ctx_responder)"]
    FIX["Fixed devices<br/>speakers · gate phones"]
    PBX["Asterisk / FreePBX<br/><b>upes-ecs-pbx-01</b>"]
    STORE[("Local storage<br/>recordings · voicemail<br/>CDR/CEL · incident logs")]

    U -->|"dial 111 / 199 / SAP-ID"| PBX
    PBX -->|"ring queue"| ERT
    PBX -->|"dispatch / handoff"| RESP
    PBX -->|"paging"| FIX
    PBX --> STORE
  end

  X["✖ Internet · ✖ Cellular · ✖ Cloud · ✖ PSTN"]:::no
  LAN -.->|excluded by design| X
  classDef no fill:#fee,stroke:#c00,color:#900;
```

**ASCII fallback**

```text
Student/Staff (Linphone, SAP ID) ─┐
ERT positions (4101/4110/4111) ───┤
Medical 4200 / Security 4300 ─────┼──► Asterisk/FreePBX (upes-ecs-pbx-01) ──► Local storage
Fixed devices (speakers/gates) ───┘        │
                                           └─ 111 / 199 / paging / conference
        ✖ no internet · ✖ no cellular · ✖ no cloud · ✖ no PSTN
```

---

## 2. Component architecture (inside the PBX)

```mermaid
graph TB
  subgraph AST["Asterisk / FreePBX"]
    PJSIP["chan_pjsip<br/>SIP registration + transport"]
    DP["Dialplan<br/>(extensions_custom.conf)<br/>ctx_* permission contexts"]
    Q["app_queue<br/>ert_emergency_queue"]
    MM["MixMonitor<br/>call recording"]
    VM["app_voicemail<br/>emergency VM"]
    CB["app_confbridge<br/>rooms 9000-9004"]
    PG["app_page<br/>paging 700-799"]
    CDR["CDR / CEL<br/>call detail + events"]
  end

  subgraph HELP["Helper scripts (/opt/upes-ecs)"]
    IID["incident_id.sh<br/>ERT-YYYYMMDD-NNNN"]
    MI["missed_incident.sh"]
    HC["upes-ecs-healthcheck.sh"]
    RET["retention-cleanup.sh"]
    LOG["log_access_denied / paging / conf"]
  end

  PJSIP --> DP
  DP --> Q --> MM
  DP --> VM
  DP --> CB
  DP --> PG
  DP -->|SHELL/System| IID
  DP -->|on missed| MI
  Q --> CDR
  MM --> STORE[("recordings")]
  VM --> STORE
  MI --> INC[("incident store<br/>/var/lib/upes-ecs")]
  HC --> DASH["Health status<br/>(local only)"]
  RET -.->|90-day purge| STORE
```

**What each part does**

| Component | Role |
|---|---|
| **chan_pjsip** | SIP registration + signalling; enforces auth, LAN-only, per-endpoint context |
| **Dialplan / contexts** | The brain: routes 111/199, includes only the numbers each role may reach |
| **app_queue** | `ert_emergency_queue` — ring-all the available ERT *positions*, 20s |
| **MixMonitor** | Records the whole 111/199 call (not bridge-only) → WAV linked to incident ID |
| **app_voicemail** | Emergency voicemail when all responders miss |
| **app_confbridge** | Incident command rooms 9000–9004 (9000 recorded when active) |
| **app_page** | Live paging to zones 700–799 (PIN on all-campus 700) |
| **CDR/CEL** | Call detail + event logs; carry `EMERGENCY_111_CALL` / `DRILL-ONLY` labels |
| **Helper scripts** | Incident IDs, missed-incident records, health check, retention, access logs |

---

## 3. Identity & permission model

Two orthogonal ideas: **who you are** (the number) and **what you may do** (the context).

```mermaid
graph LR
  subgraph ID["Identity (the number)"]
    H["Humans → SAP ID<br/>9-digit student · 8-digit staff"]
    POS["Responder positions → 4xxx<br/>(staffed by shift, not people)"]
    FX["Fixed devices → 4700s"]
    SVC["Service codes → 111/199/700s/9000s"]
  end
  subgraph PERM["Permissions (the context)"]
    CS["ctx_student"]
    CST["ctx_staff"]
    CE["ctx_ert / ctx_ert_lead"]
    CR["ctx_responder"]
    CC["ctx_control_room"]
    CF["ctx_fixed_device"]
    CA["ctx_admin"]
  end
  H --> CS & CST
  POS --> CE & CR & CC
  FX --> CF
```

- **Humans use SAP ID** as extension + username. Same person, different job = same SAP ID, different context.
- **Responder roles are POSITIONS** (`4101`, `4110`, `4200`, …) staffed by trained
  officers per shift — never a personal account ([SOP 30](../operations/ert-roles-and-shifts.md)).
- **ERT positions answer the 111 queue**; `ctx_responder` (Medical/Security/…) are
  **dispatch targets**, not queue answerers.
- Full capability grid: [SOP 04](../reference/sip-account-role-matrix.md).

---

## 4. Emergency call path (logical)

```mermaid
flowchart TD
  D["Caller dials 111"] --> REC["MixMonitor starts<br/>incident ID assigned"]
  REC --> Q{"ert_emergency_queue<br/>ring-all available positions, 20s<br/>(press 1 → first-aid)"}
  Q -->|answered| ANS["ERT handles<br/>classify · dispatch · log"]
  Q -->|no answer point free| P{"In parallel — no dead-air"}
  P --> BG["Background alert:<br/>Lead 4101 + backup ring<br/>'press 1 to join queue'"]
  P --> K["Offline panic-coach 102<br/>(ctx_ai_helpline)<br/>+ log Missed Incident"]
  K -->|"9 retry"| Q
  K -->|"8 message"| VM["Emergency voicemail (60s)"]
  VM --> MI["Missed Emergency Incident<br/>severity: critical · pending review"]
  ANS --> CL["Incident logged + recording linked"]
```

Detailed sequence diagrams for every call type: [03-Call-Flows.md](call-flows.md).

---

## 5. Storage & data (where things live)

| Data | Location | Retention |
|---|---|---|
| Emergency recordings | `/var/spool/asterisk/monitor/upes-ecs/` | 90 days |
| Emergency voicemail | `/var/spool/asterisk/voicemail/upes-ecs/` | 90 days |
| Incident / missed records | `/var/lib/upes-ecs/incidents/` | 1 year |
| CDR / CEL | Asterisk CDR (csv/db) | 1 year |
| Access/paging/conf logs | `/var/lib/upes-ecs/{security,paging,conference}/` | 1 year |
| Health status | `/var/lib/upes-ecs/health.txt` | live |
| Config (versioned) | git `upes-ecs-config` + FreePBX backup | 30 daily + 12 weekly |

Full data map + incident schema: [06-Numbering-and-Data-Map.md](numbering-and-data-map.md).

---

## 6. Deployment modes

```mermaid
graph TB
  subgraph A["Mode A — Campus (fixed)"]
    A1["PBX on campus server<br/>mains + UPS"] --> A2["Everyday emergency line"]
  end
  subgraph B["Mode B — Mobile / Field (van)"]
    B1["PBX-in-a-van<br/>generator + battery + solar"] --> B2["Corner repeaters extend coverage"]
    B2 --> B3["Disaster / off-grid / campus-PBX failover"]
  end
  A -. same config / numbers / SOP .- B
```

- **Mode A** — normal operation on the campus server.
- **Mode B** — self-powered van + rooftop repeaters for disasters or as **failover** for
  the campus PBX ([SOP 23](../guides/mobile-van-deployment.md)). Same config and numbers.
- Both are **LAN-only**. Multi-campus (Bidholi↔Kandoli) uses a rooftop wireless bridge
  ([SOP 20](../guides/multi-campus-wireless.md)).

Network topology detail: [04-Network-and-Deployment.md](network-and-deployment.md).

---

## 7. Design principles (the "why")

1. **LAN-only** — survives internet/cellular/cloud failure; the whole point.
2. **111 is human-first** — never depends on AI; AI (101) is a separate, later, always-falls-back-to-111 path.
3. **Positions, not people** — continuity through shift handover; no crisis-time provisioning.
4. **Record + log everything on 111** — accountability; student calls stay private.
5. **Least privilege by context** — emergency controls locked to emergency roles.
6. **Fixed answer points** — dedicated Androids (later IP phones) so answering never depends on a personal phone's battery.
7. **Provable** — the whole flow is testable via 199 and has been validated with real SIP/RTP.
