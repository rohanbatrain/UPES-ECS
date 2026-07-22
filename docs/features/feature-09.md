# Feature 9: Responder Status & Availability

## Purpose

Responder Status & Availability defines how the system understands whether emergency responders are available, busy, offline, or temporarily unavailable for emergency calls.

This feature supports reliable emergency call routing and gives the response team better operational visibility.

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
```

## Final Decision

```text
Use lightweight Asterisk-based responder status in Phase 1.
Do not build a complex responder attendance or field-tracking system in Phase 1.
```

## Core Concept

ERT members and emergency responders should not be treated as simple ringing extensions only.

The system should understand basic operational states such as:

```text
Available
Busy
Offline
Paused
```

A later phase may add incident-specific statuses such as:

```text
On Incident
Assigned to Incident
Responding on Ground
At Location
Unavailable for Field Duty
```

These later statuses should come from the disaster-response backend, not from Asterisk alone.

## Phase 1 Status Types

### Available

```text
Responder is online, registered, and able to receive emergency queue calls.
```

### Busy

```text
Responder is currently on another call.
```

### Offline

```text
Responder SIP device/app is not registered or not reachable.
```

### Paused

```text
Responder is online but temporarily not accepting emergency queue calls.
```

Example:

```text
ERT member is at desk but temporarily unavailable.
They pause themselves from receiving emergency queue calls.
```

## Phase 1 Behavior

Responder status should be derived mainly from Asterisk.

```text
Available → SIP device registered and not on a call
Busy → responder is already on a call
Offline → SIP device is not registered
Paused → responder manually paused from queue
```

This keeps the system simple and reliable.

## Queue Impact

Responder status should affect who receives calls to **111**.

```text
Available responders can receive emergency queue calls.
Busy responders should not receive new queue calls.
Offline responders cannot receive calls.
Paused responders should not receive queue calls until unpaused.
```

## Pause / Unpause

ERT members should be able to temporarily pause or resume receiving emergency queue calls.

Example feature codes:

```text
*45  Pause from emergency queue
*46  Return to emergency queue
```

These codes are examples only. The final feature codes can be decided later.

## Visibility

The system should eventually show a simple responder status view.

Example:

```text
ERT Desk 1       Available
ERT Desk 2       Busy
ERT Lead         Available
Security Lead    Offline
Medical Desk     Paused
```

In Phase 1, this can be available through Asterisk/queue tooling or a basic backend/dashboard view.

A polished responder management dashboard is not required in Phase 1.

## What This Feature Enables

This feature improves:

```text
Emergency queue routing
Escalation reliability
ERT operational visibility
Missed call diagnosis
Responder accountability
Future incident assignment workflows
```

## What This Feature Does Not Do in Phase 1

Phase 1 will not include:

```text
GPS tracking of responders
Field movement tracking
Complex duty roster management
Attendance tracking
Manual status updates every few minutes
Full incident assignment lifecycle
```

Those are later-phase features if needed.

## Rejected Designs

```text
Rejected: Treat every ERT extension as always available
Reason: Calls may be routed to offline, busy, or unavailable responders.
```

```text
Rejected: Build a complex responder tracking system in Phase 1
Reason: Too much operational and engineering complexity for the first deployment.
```

```text
Rejected: Require responders to manually update status frequently in a separate app
Reason: Likely to fail during real emergencies.
```

```text
Rejected: Use WhatsApp or personal communication as availability source of truth
Reason: Not reliable during cellular/internet disruption.
```

## Asterisk Features Used

```text
Queue member status
Device registration status
Extension state
Busy / in-use detection
Pause / unpause queue member
AMI / ARI events for backend sync
```

## Phase Split

### Phase 1

```text
Asterisk-based status:
Available
Busy
Offline
Paused
```

### Later Phase

```text
Backend incident lifecycle status:
On Incident
Assigned to Incident
Responding on Ground
At Location
Field Unavailable
```

## Final Locked Design

```text
Feature Name: Responder Status & Availability
Status: Approved
Phase: Phase 1
Status Source: Asterisk
Included Statuses: Available, Busy, Offline, Paused
Later Statuses: On Incident, Assigned, Responding, At Location
Purpose: Improve emergency call routing and responder visibility
```
