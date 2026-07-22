# Feature 6: Emergency Announcement & Paging

## Purpose

Emergency Announcement & Paging allows the Quick Emergency Response Team to broadcast urgent voice instructions across selected campus areas using Asterisk.

This feature is for outbound emergency communication.

It answers:

```text
How does the emergency response team quickly tell people what to do?
```

## Linked Features

```text
Feature 1: Campus Emergency Hotline
Feature 2: ERT Emergency Queue
Feature 3: Emergency Fallback & Escalation Path
Feature 4: Emergency Call Recording & Incident Logging
Feature 5: Ready-made SIP Client Deployment
```

## Final Decision

```text
Use Asterisk-based emergency paging for fixed/shared campus devices.
Do not auto-page every student's personal SIP app in Phase 1.
```

## Core Concept

Authorized ERT/control-room users can dial a paging code and speak live.

Asterisk will broadcast the voice announcement to selected campus paging zones.

```text
ERT Control Room
        ↓
Dials paging code
        ↓
Asterisk
        ↓
Selected IP speakers / SIP phones / shared devices
        ↓
Emergency announcement plays
```

## Why This Feature Is Needed

Receiving emergency calls is not enough.

During a disaster, the university also needs a way to send instructions quickly.

Example announcements:

```text
Evacuate Hostel B immediately.
Avoid the Mechanical Block.
Report to the football ground assembly point.
Do not use elevators.
Medical assistance is available near Gate 2.
Stay inside your classrooms until further instruction.
```

This system should work over campus LAN/Wi-Fi even if cellular networks or the public internet are unavailable.

## Phase 1 Scope

Paging will be limited to fixed or shared campus devices.

Included devices:

```text
IP speakers
SIP desk phones in offices
Hostel warden desk phones
Security post phones
Admin block phones
Library desk phones
Lab desk phones
Medical room phones
Emergency response point devices
```

Not included in Phase 1:

```text
Auto-answer paging to every student's personal phone
Auto-answer paging to every personal SIP softphone
Room-level paging for every classroom
Large number of overly specific paging zones
```

## Paging Zones

Recommended Phase 1 paging codes:

```text
700  All Campus Emergency Broadcast
701  Hostels
702  Academic Blocks
703  Admin Block
704  Security Gates
705  Medical / Response Points
```

Example:

```text
ERT dials 701
        ↓
Asterisk opens Hostel paging zone
        ↓
ERT speaks live announcement
        ↓
Hostel IP speakers / shared phones play the message
```

## Announcement Mode

Phase 1 will use live announcements.

```text
ERT dials paging code
ERT speaks live
Announcement plays immediately
```

Pre-recorded messages, scheduled repeats, and multilingual announcements can be considered later, but they are not required for Phase 1.

## Access Control

Only authorized emergency users should be allowed to use paging.

Allowed users:

```text
ERT Lead
ERT Control Room
Campus Emergency Coordinator
Security Control Room
Authorized emergency administrators
```

Not allowed:

```text
Students
General staff
Normal SIP extensions
Unauthenticated devices
```

## Security Rule

Paging codes must not be callable by every extension.

Bad design:

```text
Any user can dial 700 and broadcast campus-wide
```

Final rule:

```text
Only whitelisted emergency/control-room extensions can access paging codes.
```

## Call Recording / Logging

Emergency paging attempts should be logged.

Recommended log fields:

```text
Paging code dialed
Paging zone
Caller extension
Caller user/role
Start time
End time
Duration
Success/failure status
```

Recording the broadcast audio can be enabled for audit purposes if required by university policy.

## Asterisk Features Used

```text
Paging groups
SIP auto-answer for supported devices
Dialplan access control
Zone-based extension codes
Optional broadcast recording
Paging event logging
```

## Rejected Designs

```text
Rejected: Auto-answer every student's personal SIP app
Reason: Noisy, unreliable, intrusive, and hard to control.
```

```text
Rejected: Allow every extension to use paging
Reason: High misuse risk.
```

```text
Rejected: Create too many paging zones in Phase 1
Reason: Increases maintenance and operational confusion.
```

```text
Rejected: Depend only on mobile phones for emergency announcements
Reason: The system must remain useful when cellular service is down.
```

## Final Locked Design

```text
Feature Name: Emergency Announcement & Paging
Status: Approved
Phase: Phase 1
Mode: Live voice paging
Paging Codes: 700–705
Scope: Fixed/shared campus devices only
Student Personal Devices: Not auto-paged in Phase 1
Access: ERT/control-room only
Purpose: Broadcast urgent emergency instructions over campus LAN/Wi-Fi
```
