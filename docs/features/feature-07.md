# Feature 7: Incident Command Conference Rooms

## Purpose

Incident Command Conference Rooms allow emergency responders to coordinate with each other during an active incident using internal Asterisk voice conference bridges.

This feature is for responder-to-responder coordination after an incident has started.

It answers:

```text
How do ERT, security, medical, wardens, admin, and operations coordinate during an emergency?
```

## Linked Features

```text
Feature 1: Campus Emergency Hotline
Feature 2: ERT Emergency Queue
Feature 3: Emergency Fallback & Escalation Path
Feature 4: Emergency Call Recording & Incident Logging
Feature 5: Ready-made SIP Client Deployment
Feature 6: Emergency Announcement & Paging
```

## Final Decision

```text
Use fixed Asterisk conference rooms for emergency responder coordination.
Students and general users will not use these rooms to report emergencies.
```

Students and staff should still report emergencies by dialing:

```text
111
```

Conference rooms are only for authorized responders and emergency coordination roles.

## Core Concept

Asterisk will provide fixed internal conference extensions.

Responders can dial a room number and join the live voice bridge.

Example:

```text
Emergency incident starts
        ↓
ERT Lead activates coordination
        ↓
Responders are told to join 9000
        ↓
Security, medical, wardens, admin, and operations coordinate live
```

## Phase 1 Conference Rooms

Recommended conference room numbers:

```text
9000  Main Incident Command Room
9001  Security Coordination Room
9002  Medical Coordination Room
9003  Hostel / Warden Coordination Room
9004  Operations / Infrastructure Room
```

## Main Incident Command Room

```text
9000  Main Incident Command Room
```

This is the primary emergency coordination bridge.

Recommended participants:

```text
ERT Lead
Security Lead
Medical Lead
Hostel/Warden Representative
Admin Emergency Representative
Operations/Infrastructure Lead
IT/Network Emergency Representative if needed
```

The Main Incident Command Room is used when an incident requires multi-team coordination.

## Team-specific Rooms

Side rooms are available for focused team coordination.

```text
9001  Security Coordination
9002  Medical Coordination
9003  Hostel / Warden Coordination
9004  Operations / Infrastructure
```

Example usage:

```text
Security guards coordinate movement in 9001.
Medical staff coordinate triage in 9002.
Wardens coordinate hostel evacuation in 9003.
Operations handles power, network, and building issues in 9004.
```

## Usage Model

The recommended usage model is:

```text
ERT Lead and team leads join 9000.
Individual teams use their own side rooms only if needed.
```

Rejected usage model:

```text
Everyone joins every conference room.
```

Reason:

```text
Too much noise, confusion, and cross-talk during emergencies.
```

## Access Control

Conference rooms must be restricted.

Allowed users:

```text
ERT members
Security leads
Medical staff
Hostel wardens
Admin emergency staff
Operations staff
IT/network emergency staff
Authorized emergency coordinators
```

Not allowed:

```text
Students
General staff
Unauthenticated SIP clients
Normal extensions without emergency role
```

## Access Method

Access can be controlled using:

```text
Whitelisted emergency extensions
Conference PINs
Role-based dialplan rules
Separate responder-only context
```

The preferred Phase 1 model is:

```text
Whitelisted responder extensions + optional PIN for sensitive rooms
```

## Recording Policy

Recommended recording behavior:

```text
9000 Main Incident Command Room: Record by default during active incidents
9001–9004 Side Rooms: Recording optional / policy-based
```

Reason:

```text
The main command room may contain critical decisions, timeline details, and response instructions.
```

Recordings should follow the same access and retention controls defined in Feature 4.

## Logging

Conference activity should be logged.

Recommended log fields:

```text
Conference room number
Conference room name
Participant extension
Participant role if known
Join time
Leave time
Duration
Recording reference if recorded
Linked incident ID if applicable
```

## Asterisk Features Used

```text
ConfBridge
Conference access rules
Conference PINs if needed
Role-based dialplan restrictions
Optional conference recording
Join/leave tracking
Participant limits
```

## Rejected Designs

```text
Rejected: Allow any campus user to join 9000
Reason: High risk of noise, misuse, panic, and misinformation.
```

```text
Rejected: Create a separate conference room for every department, floor, hostel, or classroom in Phase 1
Reason: Too much operational complexity.
```

```text
Rejected: Use conference rooms for emergency reporting
Reason: Emergency reporting must remain simple: dial 111.
```

```text
Rejected: Force every responder into every room
Reason: Creates cross-talk and confusion.
```

## Final Locked Design

```text
Feature Name: Incident Command Conference Rooms
Status: Approved
Phase: Phase 1
Main Room: 9000
Side Rooms: 9001–9004
Access: Emergency roles only
Student Access: Not allowed
Emergency Reporting: Still through 111
Recording: 9000 recorded by default during active incidents
Purpose: Live responder coordination during emergency response
```
