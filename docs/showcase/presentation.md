---
title: Presentation & demo day
---

# Presentation & demo day

A ready-to-run script for showing UPES-ECS live — the same story told at HPE's Bangalore
University Networking Day. Total run time ~5 minutes.

## Watch the demo

<div style="position:relative;padding-bottom:56.25%;height:0;overflow:hidden;border-radius:12px;margin:1.25rem 0;box-shadow:0 12px 32px -12px rgba(10,40,30,.35);">
  <iframe src="https://drive.google.com/file/d/1wChZgK9p-VcRLDymdN1WhYhCtbZqNE88/preview"
    style="position:absolute;top:0;left:0;width:100%;height:100%;border:0;"
    allow="autoplay; encrypted-media; fullscreen; picture-in-picture" allowfullscreen
    title="UPES-ECS demo video" loading="lazy"></iframe>
</div>

*A short walkthrough — from a caller dialing 111 to the response team answering on the live
operations console. Video shot & edited by [@harshdeepsinghin](https://www.instagram.com/harshdeepsinghin/).*

!!! tip "Before you start"
    Seed the demo (`Install-UpesEcs.ps1 -Demo`), register two softphones, and put the ERT
    desk on shift (`*22` on `4190`) so the board is green. See [Try the demo](../getting-started/demo.md).

## The narrative (talking track)

**1 · Open (0:00–0:20).** *"UPES-ECS is a resilient emergency communication system designed
to keep critical communication working even during network failures. The core idea is simple:
in an emergency, communication should not depend on the internet or cellular availability."*

**2 · The infrastructure (0:20–1:00).** *"The backbone of this solution is enterprise
networking infrastructure from HPE — SRX at the edge, EX2300-C switches as the voice fabric,
and Mist AP32 access points. They give us high availability, low latency, and complete local
network control."* → point at the [HPE networking](hpe-networking.md) topology.

**3 · The emergency call (1:00–2:30).** *"A student dials one number — `111`."* Place the call
from `500000001`. *"It's routed entirely through the local HPE-powered network to the PBX,
into the response-team queue, and to a responder — with no internet and no cellular."* The ERT
desk (`4190`) rings; answer it.

**4 · The dashboard (2:30–3:30).** Open the **Operations Console** (`:8080`) and the LED-TV
wallboards. *"Responders monitor incidents, track communication, and coordinate faster —
centralised visibility that helps them make quicker, better-informed decisions."*

**5 · Depth (3:30–4:30).** Show one differentiator: dial `102` for the **offline coach**, or
`500000002` to hear `111` answered in **Hindi** (per-caller language), or mention
**caller-location-by-switch-port**.

**6 · Scale & close (4:30–5:00).** *"The same architecture scales beyond one campus — to
universities, disaster-response sites, and any critical-communication zone. When networks
fail, we don't."*

## The 60-second demo checklist

| # | Action | Shows |
|---|---|---|
| 1 | `*22` on `4190` | Responder goes on shift; board turns **READY** |
| 2 | `111` from `500000001` → answer on `4190` | The one-number hotline + dispatch, fully local |
| 3 | `111` from `500000002` | Per-caller language (Hindi prompts) |
| 4 | `102` from any phone | Offline panic-coach (no human/internet) |
| 5 | Open `:8080` + `/tv-ops.html` | Live console + wallboards |
| 6 | `199` | Drill mode (safe to repeat) |

## Assets for the pitch

- **Landing page** (44 languages): <https://rohanbatrain.github.io/UPES-ECS/>
- **One-pager PDFs**: [A4 overview](../assets/UPES-ECS-Overview-A4.pdf) ·
  [one-pager](../assets/UPES-ECS-Overview-OnePager.pdf)
- **HPE networking story**: [Built on HPE Juniper Networking](hpe-networking.md)
- **Architecture**: [System architecture](../architecture/system-architecture.md) ·
  [Call flows](../architecture/call-flows.md)

> **Tagline:** *When networks fail, we don't.*
