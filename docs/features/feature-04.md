# Feature 4: Emergency Call Recording & Incident Logging

## Purpose

This feature ensures that every call made to the campus emergency number is recorded, tracked, and converted into a structured incident record.

The goal is to create accountability, preserve critical information, and give the emergency response team a reliable incident history during and after a disaster.

## Linked Features

```text
Feature 1: Campus Emergency Hotline
Emergency Number: 111

Feature 2: ERT Emergency Queue
111 routes to the Quick Emergency Response Team

Feature 3: Emergency Fallback & Escalation Path
Unanswered calls escalate automatically
```

## Final Decision

```text
Record and log only emergency calls made to 111.
Do not record normal internal campus calls by default.
```

## Scope

This feature applies to:

```text
Calls to 111
Escalated emergency calls
Emergency voicemail recordings
Emergency queue events
Missed emergency calls
```

This feature does not apply to:

```text
Normal internal extension-to-extension calls
General department calls
Non-emergency campus communication
```

## Call Recording Behavior

When a caller dials **111**, recording should start immediately.

```text
Caller dials 111
        ↓
Recording starts
        ↓
Call enters ERT Emergency Queue
        ↓
ERT answers or call escalates
        ↓
Recording continues until call ends
```

Recording should not wait until an ERT member answers because the caller may speak useful information before pickup, during hold, or during voicemail fallback.

## Incident Logging Behavior

For every emergency call, the system should create an incident log.

The log should include:

```text
Incident ID
Caller extension
Caller user/name if known
Caller device if known
Caller location if known
Call start time
Call answer time
Answered by which ERT member
Call duration
Answered / missed / escalated status
Queue attempt status
Escalation attempt status
Recording reference
Voicemail reference if applicable
Final disposition
```

Example incident record:

```text
Incident ID: INC-2026-00041
Caller: Extension 315
Location: Hostel B, Floor 2
Time: 14:32
Answered by: ERT Desk 1
Duration: 02:41
Status: Answered
Recording: Available
```

## System Architecture

Asterisk should handle the telephony side.

The disaster response backend should handle the structured incident system.

```text
Asterisk
    ↓
CDR / CEL / Queue Logs / AMI / ARI Events
    ↓
Disaster Response Backend
    ↓
Incident Dashboard
```

Asterisk is the voice engine.  
The custom disaster response app is the incident-management layer.

## Storage and Retention

Emergency recordings should be stored in a controlled location.

The system should support:

```text
Recording retention policy
Restricted access
Audit logs for recording access
Secure storage
Incident-linked recording references
```

The exact retention duration can be finalized according to university policy.

## Access Control

Recording access should be limited.

Recommended access roles:

```text
ERT Lead
Campus Emergency Coordinator
Authorized university administration
Audit/review authority
```

Regular users should not have access to recordings.

Regular ERT members may see incident details, but recording access can be permission-based.

## Rejected Designs

```text
Rejected: Record all internal campus calls
Reason: Privacy-heavy, unnecessary, and storage-heavy.
```

```text
Rejected: Store recordings as unmanaged random files
Reason: Difficult to audit, search, secure, and link to incidents.
```

```text
Rejected: Depend only on raw Asterisk logs
Reason: Asterisk logs are technical; emergency teams need readable incident records.
```

## Asterisk Features Used

```text
MixMonitor
CDR
CEL
Queue logs
Voicemail recording
AMI / ARI event integration
```

## Final Locked Design

```text
Feature Name: Emergency Call Recording & Incident Logging
Status: Approved
Scope: Calls to 111 only
Recording Start: Immediately when 111 is dialed
Logging System: Disaster response backend
Recording Access: Restricted
Retention: Policy-based
Purpose: Emergency accountability, review, and incident history
```