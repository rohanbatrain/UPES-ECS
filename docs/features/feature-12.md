# Feature 12: LAN-only Infrastructure Boundary

## Purpose

LAN-only Infrastructure Boundary defines the technical scope of the university emergency communication system.

This feature makes it clear that the system is designed to operate only inside the university’s local network.

The goal is to prevent unnecessary scope creep into cellular, internet, cloud, PSTN, or external communication systems.

## Final Decision

```text
The disaster-response voice system is LAN-only.
All core emergency communication features must work within the university LAN/Wi-Fi.
External communication systems are out of scope for Phase 1.
```

## System Boundary

The system will run on:

```text
University LAN
University Wi-Fi
Local Asterisk server
Local SIP clients
Local SIP IP phones
Local IP speakers / paging devices
Local emergency response devices
```

The system will not depend on:

```text
Public internet
Cellular network
Cloud PBX
External SIP provider
PSTN phone lines
SMS gateways
WhatsApp / Telegram / email alerts
Public DNS
Remote access from outside campus
```

## Core LAN-only Services

The following approved features must remain inside the LAN boundary:

```text
111 emergency hotline
ERT emergency queue
Fallback and escalation path
Emergency voicemail
Emergency call recording
Incident call logging
Ready-made SIP client registration
Emergency paging
Incident command conference rooms
Responder directory and extensions
Responder status and availability
Emergency call transfer and dispatch workflow
```

## Asterisk Placement

Asterisk should run on local university-controlled infrastructure.

Examples:

```text
On-premise server
Campus mini PC
Local VM
Local data-center node
Control room server
```

Asterisk should not be cloud-only in Phase 1.

## Addressing Model

SIP clients and IP phones should connect to Asterisk using a local address.

Examples:

```text
asterisk.local
asterisk.university.lan
192.168.x.x
10.x.x.x
```

The system should not require public DNS resolution.

## Network Rule

```text
SIP and RTP traffic must remain inside the university network.
```

Phase 1 should not expose SIP/RTP ports to the public internet.

## Registration Rule

Only authorized LAN devices and approved SIP clients should be allowed to register to Asterisk.

The system should reject:

```text
Unauthenticated SIP clients
Unknown external devices
Public internet SIP attempts
Guest devices without permission
Extensions outside their allowed role/context
```

## Storage Boundary

Emergency recordings, voicemails, queue logs, and incident call logs should be stored locally inside the university-controlled environment.

Included local data:

```text
Call recordings
Emergency voicemails
CDR/CEL records
Queue logs
Conference logs
Paging logs
Missed emergency records
Incident-linked call metadata
```

No cloud storage dependency is required for Phase 1.

## Explicitly Out of Scope

The following are not part of Phase 1:

```text
Cellular fallback
PSTN calling
External emergency number routing
SMS alerts
WhatsApp alerts
Telegram alerts
Email alerts
Cloud PBX
External SIP trunk
Remote users outside campus
Multi-campus routing
Internet-based failover
Anycast SIP
Satellite backup
```

These may be discussed in a future architecture, but they are not part of the current LAN-only system.

## Security Implication

Because the system is LAN-only, the security model should focus on:

```text
Internal firewall rules
SIP account security
Strong extension passwords
Device authorization
Role-based dialplan contexts
Restricted paging and conference access
Local recording access control
Network segmentation if possible
```

## Rejected Designs

```text
Rejected: Expose Asterisk SIP/RTP directly to the public internet
Reason: Not required for LAN-only system and increases attack surface.
```

```text
Rejected: Depend on cloud PBX or external SIP provider
Reason: Violates the LAN-only boundary.
```

```text
Rejected: Add SMS/WhatsApp/email alerts in Phase 1
Reason: External alerting is outside the current LAN-only scope.
```

```text
Rejected: Support remote users outside campus in Phase 1
Reason: Current design is campus-network-bound only.
```

## Final Locked Design

```text
Feature Name: LAN-only Infrastructure Boundary
Status: Approved
Phase: Phase 1
Network Scope: University LAN/Wi-Fi only
Asterisk Location: Local university-controlled infrastructure
External Dependencies: None for core voice system
Public SIP/RTP Exposure: Not allowed
Cloud/PSTN/SMS/WhatsApp: Out of scope
Purpose: Keep the emergency communication system local, controlled, and scope-limited
```
