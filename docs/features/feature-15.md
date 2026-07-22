# Feature 15: Local Wi-Fi-first Infrastructure Readiness

## Purpose

Local Wi-Fi-first Infrastructure Readiness defines the physical and network foundation required to run the LAN-only Asterisk emergency communication system inside the university.

This feature ensures that the system works from the device most people already have: their mobile phone connected to university Wi-Fi, using a ready-made SIP app.

At the same time, it keeps fixed IP phones, ERT desk phones, security phones, medical phones, and other dedicated devices as required infrastructure for emergency operations.

## Linked Features

```text
Feature 1: Campus Emergency Hotline
Feature 2: ERT Emergency Queue
Feature 3: Emergency Fallback & Escalation Path
Feature 4: Emergency Call Recording & Incident Logging
Feature 5: Ready-made SIP Client Deployment
Feature 6: Emergency Announcement & Paging
Feature 7: Incident Command Conference Rooms
Feature 8: Emergency Responder Directory & Numbering Plan
Feature 9: Responder Status & Availability
Feature 10: Emergency Voicemail & Missed-call Recovery
Feature 11: Emergency Call Transfer & Dispatch Workflow
Feature 12: LAN-only Infrastructure Boundary
Feature 13: SIP Security & Access Control
Feature 14: Device Provisioning & Extension Management
```

## Final Decision

```text
The primary user access model is mobile phone + university Wi-Fi + SIP app.

The system will run on the local LAN using:
- router
- switch
- access point
- local Asterisk server

Fixed IP phones and dedicated emergency devices remain required for ERT and critical emergency locations.
```

## Primary Deployment Assumption

The system is designed around the device that most students and staff already have.

```text
Primary client:
Mobile phone

Primary network:
University Wi-Fi

Primary calling app:
Ready-made SIP softphone app

Primary SIP identity:
SAP ID-based SIP account

Primary server:
Local Asterisk server
```

## Core Architecture

```text
Student / Staff Mobile Phone
        ↓
Ready-made SIP App
        ↓
University Wi-Fi AP
        ↓
Router / Switch
        ↓
Local Asterisk Server
        ↓
111 Emergency Hotline / ERT Queue / Internal Calling
```

This is the main system path.

## Existing Infrastructure

The current base infrastructure is:

```text
Router
Switch
Access Point
One local server running Asterisk
```

This is enough for a Phase 1 pilot.

The first goal is not to overbuild.  
The first goal is to prove reliable SIP calling over the existing university LAN/Wi-Fi setup.

## Primary User Experience

A student or staff member should be able to:

```text
1. Connect phone to university Wi-Fi.
2. Open SIP app.
3. Register using SAP ID credentials.
4. Dial 111 for emergency.
5. Dial another user's SAP ID for internal calling.
```

Example:

```text
SIP Server: asterisk.university.lan
Username: SAP ID
Extension: SAP ID
Password: strong SIP password
```

## Primary Use Cases

The mobile-first system must support:

```text
Student calls 111 from mobile SIP app.
Staff calls 111 from mobile SIP app.
Student calls another student using SAP ID.
ERT receives emergency call from 111 queue.
ERT calls back a student using SAP ID.
ERT joins conference room if needed.
ERT dispatches responders using internal extensions.
Emergency calls are recorded and logged.
```

## Required ERT and Critical Location Devices

Although mobile phones are the primary user device, dedicated IP phones and fixed SIP devices are still required for emergency operations.

These are not removed from the plan.

Required fixed or semi-fixed devices include:

```text
ERT control room phone
ERT lead phone
Security control room phone
Medical room phone
Hostel warden desk phone
Admin emergency desk phone
IT/network support phone
Operations/infrastructure phone
Security gate phone where needed
```

Reason:

```text
ERT and critical locations should not depend only on personal mobile phones.
```

Dedicated devices improve:

```text
Availability
Accountability
Caller identity clarity
Location clarity
Operational reliability
Emergency desk readiness
```

## Infrastructure Priority Model

The infrastructure priority order is:

```text
Priority 1:
Mobile phones on university Wi-Fi using SIP apps.

Priority 2:
ERT/control room answering setup with stable SIP devices.

Priority 3:
Fixed emergency devices at critical locations.

Priority 4:
Paging speakers and dedicated emergency announcement hardware.

Priority 5:
Network segmentation, emergency VLANs, PoE planning, and further hardening.
```

This keeps the first implementation practical while preserving the full emergency infrastructure roadmap.

## Minimum Phase 1 Infrastructure

The minimum Phase 1 stack is:

```text
1 local Asterisk server
1 router
1 switch
1 access point
SIP apps on selected mobile phones
SAP ID-based SIP accounts
ERT answering device or SIP app
111 emergency hotline
ERT queue
Student-to-student calling
Emergency recording/logging
```

This is the smallest valid pilot.

## Recommended Phase 1 Infrastructure

The recommended Phase 1 stack is stronger:

```text
1 local Asterisk server
Router
Switch
Access point
ERT desk SIP phone or dedicated ERT SIP app device
Medical room SIP phone
Security/control room SIP phone
Hostel/warden SIP phone if available
Selected student/staff mobile SIP users
Selected ERT mobile SIP users
Local call recording storage
Local voicemail storage
Local call logs
```

This gives both mobile-first access and critical responder reliability.

## Mobile-first Requirements

Because mobile phones are the primary client, the system must validate these carefully:

```text
SIP app can register over university Wi-Fi.
SIP app can call 111.
SIP app can call another SAP ID extension.
SIP app can receive calls.
Audio works both ways.
Calls do not drop immediately on screen lock.
SIP registration remains stable enough for the use case.
Emergency call reaches ERT queue.
Caller ID shows SAP ID/name correctly.
Call recording works for 111.
Student-to-student calls are not recorded by default.
```

## Wi-Fi Requirements

The Wi-Fi network becomes the primary access layer.

The system should validate:

```text
Wi-Fi signal strength in target areas
AP capacity for simultaneous SIP clients
Latency between phones and Asterisk server
Packet loss
Jitter
Roaming behavior between APs if multiple APs exist
Voice quality during active calls
Reachability to Asterisk from student/staff Wi-Fi
Firewall rules allowing SIP/RTP inside LAN
```

## Router and Switch Requirements

The router and switch must allow LAN communication between SIP clients and Asterisk.

They should support:

```text
Reachability from Wi-Fi clients to Asterisk
SIP signaling inside LAN
RTP audio inside LAN
Stable local routing
No unnecessary client isolation for SIP users
Firewall rules that permit allowed SIP/RTP traffic
Separation/restriction where required for security
```

Important check:

```text
If Wi-Fi client isolation is enabled, SIP clients may not be able to reach Asterisk or each other.
```

Client isolation may need to be disabled or selectively configured for the emergency SIP network.

## Asterisk Server Requirements

The local Asterisk server is the communication core.

It should provide:

```text
PJSIP registration
SAP ID-based user extensions
Student-to-student calling
111 emergency hotline routing
ERT emergency queue
Fallback and escalation
Emergency voicemail
Emergency call recording
Incident command conference rooms
Paging support
Responder status
Call transfer and dispatch workflows
CDR/CEL logging
```

The server should be placed in a controlled location.

Recommended placement:

```text
Control room
IT room
Secure network room
Local server rack
University-controlled infrastructure area
```

Rejected placement:

```text
Student laptop
Personal desktop
Random classroom machine
Unsecured lab PC
Temporary machine without ownership
```

## Power Assumption

For the current scope, power is assumed to be available.

```text
Power is not treated as a current blocking concern.
Router, switch, AP, and Asterisk server are assumed to remain powered.
```

However, the system still depends on powered local infrastructure.

Required powered components:

```text
Asterisk server
Router
Switch
Access point
ERT answering device
Critical SIP phones/devices
```

Detailed UPS or backup power planning is not the focus of this feature, but future production deployment can still add it.

## Fixed IP Phones and Dedicated Devices

Fixed IP phones are required for operational roles even if mobile phones are the primary user access method.

Recommended fixed device locations:

```text
ERT/control room
Security room
Medical room
Hostel warden office
Admin emergency desk
Main gate/security gate
IT/network support point
Operations/infrastructure desk
```

Why they matter:

```text
They are always at the same location.
They can show clear caller ID.
They do not depend on personal phone battery.
They are easier to train around.
They are easier to audit.
They are better for emergency desks.
```

## Mobile Phones vs Fixed Devices

The system uses both.

```text
Mobile phones:
Primary access method for students and general users.

Fixed IP phones:
Required for ERT, control room, security, medical, wardens, and critical locations.
```

This is the final balance.

## IP Speakers and Paging Devices

IP speakers and paging devices remain part of the plan because Feature 6 is approved.

They are not required for the smallest pilot, but they are required for full emergency announcement capability.

Paging devices may include:

```text
IP speakers
SIP paging adapters
SIP-capable desk phones with auto-answer
Zone paging devices
PoE-powered announcement devices
```

Their deployment can be staged.

## Emergency VLAN / Segmentation

A separate emergency voice VLAN or controlled subnet is useful but not mandatory for the first pilot.

Recommended later:

```text
Emergency voice VLAN for ERT/fixed devices
Controlled access for IP phones and IP speakers
Restricted registration to approved subnets
Separate rules for student SIP clients
Cleaner security and monitoring
```

Phase 1 can start with a simpler network if the router/switch/AP setup allows stable SIP traffic.

## Storage Requirements

Asterisk must have local storage for emergency records.

Storage should cover:

```text
Emergency call recordings
Emergency voicemail
Conference recording if enabled
CDR/CEL logs
Queue logs
Paging logs
Missed emergency call records
```

Student-to-student calls should not be recorded by default.

Storage concern:

```text
The system should not silently fail because disk space is full.
```

This links to the later health monitoring feature.

## Local Addressing

SIP clients should connect to Asterisk using a LAN-only address.

Examples:

```text
asterisk.university.lan
asterisk.local
10.x.x.x
192.168.x.x
```

No public DNS dependency is required.

For critical devices, direct local IP configuration can be used if simpler.

## Network Testing Checklist

Before rollout, test:

```text
Phone registers to Asterisk over Wi-Fi.
Phone can call 111.
Phone can call another SAP ID extension.
ERT device receives queue call.
Two-way audio works.
Call recording works for 111.
Emergency voicemail works.
Student-to-student call is not recorded.
Conference room can be joined by authorized responder.
Paging code works from authorized device.
Unauthorized user cannot access paging/conference.
Multiple simultaneous calls work.
Call quality is acceptable.
```

## Capacity Testing

Because student-to-student calling is allowed, capacity matters.

Test:

```text
Number of simultaneous SIP registrations
Number of simultaneous student calls
Number of simultaneous emergency calls
Impact of normal calls on 111 queue
AP behavior under multiple voice calls
Asterisk CPU/RAM usage
Recording storage growth
```

Emergency calls must remain priority.

```text
Normal internal calling must not degrade emergency calling.
```

## Phase 1 Rollout Plan

### Stage 1: Core Lab Test

```text
Asterisk server
Router/switch/AP
2–3 mobile SIP clients
1 ERT SIP client/device
Test student-to-student calling
Test 111 calling
Test recording/logging
```

### Stage 2: ERT Pilot

```text
Add ERT users/devices
Add ERT queue
Add fallback/escalation
Add emergency voicemail
Test missed-call recovery
Test responder availability
```

### Stage 3: Critical Device Pilot

```text
Add security phone
Add medical room phone
Add warden/admin phone if available
Test warm transfer
Test three-way bridge
Test command conference rooms
```

### Stage 4: Student/Staff Pilot

```text
Add selected student SAP ID accounts
Add selected staff SAP ID accounts
Test student-to-student calls
Test call quality
Test misuse controls
Test support process
```

### Stage 5: Paging/Announcement Expansion

```text
Add paging zones/devices
Test authorized paging
Test blocked paging from student accounts
Test emergency announcement audibility
```

## What This Feature Does Not Try to Solve

This feature does not focus on:

```text
Public internet access
Cellular fallback
PSTN calling
Cloud PBX
External SIP trunks
SMS/WhatsApp/email alerts
Remote users outside campus
Multi-campus routing
Full high-availability cluster
Anycast SIP
Satellite backup
Detailed backup power design
```

Those are outside the LAN-only Phase 1 scope.

## Rejected Designs

```text
Rejected: Make wired IP phones the only primary access method
Reason: Most users already have mobile phones, so mobile + Wi-Fi should be the primary access model.
```

```text
Rejected: Remove IP phones and fixed devices entirely
Reason: ERT, security, medical, wardens, and control room need stable dedicated devices.
```

```text
Rejected: Depend only on personal mobile phones for ERT operations
Reason: Emergency desks need dedicated, accountable, stable devices.
```

```text
Rejected: Run Asterisk on an unsecured or personal machine
Reason: The system needs a controlled local server.
```

```text
Rejected: Ignore Wi-Fi quality
Reason: Mobile SIP calling depends heavily on Wi-Fi stability.
```

```text
Rejected: Allow normal calls to degrade emergency calls
Reason: 111 emergency calling must remain priority.
```

```text
Rejected: Treat power design as a current blocker
Reason: Power is assumed available in the current deployment context.
```

## Asterisk-related Components Affected

```text
PJSIP registration
Student-to-student calling
111 emergency hotline
ERT queue
Emergency recording
Voicemail
Conference rooms
Paging
Transfer/dispatch workflows
CDR/CEL logging
Responder status
```

## Final Locked Design

```text
Feature Name: Local Wi-Fi-first Infrastructure Readiness
Status: Approved
Phase: Phase 1
Primary Client: Mobile phones using ready-made SIP apps
Primary Network: University Wi-Fi
Core Infrastructure: Router, switch, access point, local Asterisk server
Human Identity Model: SAP ID-based SIP accounts
Primary User Flow: Phone → Wi-Fi → SIP app → Asterisk
ERT/critical Devices: Fixed IP phones and dedicated SIP devices required
Paging/IP Speakers: Included as staged enhancement for announcements
Power: Assumed available; not a current blocker
External Dependencies: None
Purpose: Make the LAN-only Asterisk system usable through mobile phones first while maintaining dedicated emergency infrastructure for responders and critical locations
```
