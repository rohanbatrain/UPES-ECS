# UPES-ECS Blueprint

A self-contained, in-depth engineering blueprint for the **UPES Emergency
Communication System** — architecture, diagrams, the bare-minimum to go operational,
bill of materials, network maps, data model, and the deployment runbook.

> This Blueprint is the **deep technical companion** to the operational docs in
> [../SOP/](../SOP/). Where SOP tells people *how to operate*, Blueprint shows *how it
> is built and wired*. Diagrams are Mermaid (render in VS Code / GitHub preview) with
> ASCII fallbacks.

---

## Read in this order

| # | Document | Answers |
|---|---|---|
| 01 | [Bare-Minimum Operational Checklist](bare-minimum-checklist.md) | *What is the least I need to be live?* |
| 02 | [System Architecture](system-architecture.md) | *How is it built? What are the parts?* |
| 03 | [Call Flows](call-flows.md) | *What happens on every call type?* |
| 04 | [Network & Deployment Topology](network-and-deployment.md) | *How is the network wired? Campus vs van?* |
| 05 | [Bill of Materials](bill-of-materials.md) | *Exactly what hardware/software do I buy/use?* |
| 06 | [Numbering & Data Map](numbering-and-data-map.md) | *Every number, and where every byte of data lives.* |
| 07 | [Deployment Runbook](deployment-runbook.md) | *Step-by-step from bare metal to a live 111.* |
| 08 | [Responder Department Architecture & Live Map](responder-department-architecture.md) | *How the departments wire together, and how the Console maps them live.* |

---

## The system in one paragraph

Students/staff run a **SIP softphone (Linphone) on campus Wi-Fi**, logging in with their
**SAP ID** as their extension. They dial **111** and reach the **Emergency Response
Team**, who answer on **dedicated Android answer points** (generic positions staffed by
shift). Everything runs on **one local Asterisk/FreePBX server** — **LAN-only**, no
internet, cellular, or cloud — so it keeps working in a disaster. Calls to 111 are
recorded from the first second; if no answer point is free the caller is coached
immediately by an **offline panic-coach (102)** while the ERT Lead and backup are alerted
in the background — every unanswered call becomes a tracked Missed Incident. The
same system can deploy from a **self-powered van + rooftop repeaters** when campus infra
is down.

---

## Proven, not just designed

The emergency core has been **run and validated** (see [../deploy/](https://github.com/rohanbatrain/UPES-ECS/blob/main/deploy/)):
Docker (config/dialplan/flow) and **WSL2 with live SIP registration + RTP audio + a real
11.56s recording**. This Blueprint documents the validated system.

---

## Status of what's here

- **Architecture, diagrams, minimum-viable list, BOM, data map, runbook:** complete.
- **Real data only:** roster from ../Notes/; numbers from the
  [Numbering Plan](../reference/numbering-plan.md). No fabricated names/IDs.
- **TBD items** (collect from UPES IT) are flagged where they occur: server IP/subnet,
  Wi-Fi SSID, client-isolation status, final roster/locations, van power sizing.
