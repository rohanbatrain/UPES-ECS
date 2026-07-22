# Feature 10: Emergency Voicemail & Missed-call Recovery

## Purpose

Emergency Voicemail & Missed-call Recovery defines what happens when a call to the campus emergency number is not answered even after the fallback and escalation path.

This feature ensures that unanswered emergency calls are not lost and are reviewed as critical incidents.

## Linked Features

```text
Feature 1: Campus Emergency Hotline
Feature 2: ERT Emergency Queue
Feature 3: Emergency Fallback & Escalation Path
Feature 4: Emergency Call Recording & Incident Logging
Feature 9: Responder Status & Availability
```

## Final Decision

```text
If a call to 111 is not answered after escalation,
the caller is sent to emergency voicemail.
The voicemail creates a critical missed emergency incident.
The incident must remain pending until reviewed.
```

## Scope

This feature applies only to emergency communication paths.

Included:

```text
Missed calls to 111
Emergency voicemails
Failed ERT queue attempts
Failed escalation attempts
Unanswered emergency calls
```

Not included:

```text
Normal internal missed calls
Department missed calls
Personal extension missed calls
Non-emergency voicemail
```

## Emergency Voicemail Flow

```text
Caller dials 111
        ↓
Emergency Response Queue does not answer
        ↓
ERT Lead does not answer
        ↓
Backup Emergency Authority Group does not answer
        ↓
Emergency voicemail starts
        ↓
Caller leaves message
        ↓
System creates critical missed emergency incident
        ↓
ERT reviews and takes action
```

## Voicemail Prompt

The voicemail prompt should be short and direct.

```text
No responder is currently available.
Please say your name, location, and emergency after the tone.
Stay near your phone if possible.
```

The prompt should not include long menus, unnecessary instructions, or IVR-style choices.

## Missed Emergency Incident Creation

After the voicemail is recorded, the system must create a missed emergency incident.

The incident should include:

```text
Incident ID
Caller extension
Caller user/name if known
Caller device/location if known
Time of missed call
Queue attempt status
Escalation attempt status
Voicemail recording reference
Final call status
Severity
Review status
```

Default severity:

```text
Critical
```

Default review status:

```text
Pending Review
```

## Missed Emergency Recovery List

The ERT should have a dedicated list for missed emergency calls.

Example:

```text
Missed Emergency Calls

INC-2026-0042
Time: 14:36
Caller: Extension 315
Status: Unanswered
Voicemail: Available
Severity: Critical
Review Status: Pending
```

This list should not mix emergency missed calls with normal missed calls.

## Review Workflow

When an ERT member reviews a missed emergency:

```text
1. Open the missed emergency incident.
2. Listen to the voicemail.
3. Check caller extension and known location.
4. Call the person back if possible.
5. Dispatch responders if the location and issue are clear.
6. Add action notes.
7. Mark the incident as reviewed or convert it to an active incident.
```

Example action note:

```text
Voicemail reviewed by ERT Desk 1.
Caller reported smoke near Mechanical Lab.
Security and medical team dispatched.
Status changed to Active Incident.
```

## Mandatory Review Rule

Missed emergency voicemails must not auto-close.

Final rule:

```text
Every missed emergency call remains pending until reviewed by an authorized responder.
```

Rejected behavior:

```text
Save voicemail and forget it.
```

## Callback Support

If the caller extension is known, the ERT should be able to call back internally.

```text
ERT opens missed incident
        ↓
Sees caller extension
        ↓
Calls back through Asterisk
```

If the caller used a fixed SIP phone, callback goes to that device.

If the caller used a shared location phone, the extension can help identify the likely physical location.

## Missed Emergency Status Values

Recommended statuses:

```text
Pending Review
Reviewed
Callback Attempted
Converted to Active Incident
Closed as Duplicate
Closed as False Alarm
```

The status model should remain simple in Phase 1.

## Access Control

Emergency voicemail access should be restricted.

Allowed:

```text
ERT Lead
Authorized ERT members
Campus Emergency Coordinator
Authorized emergency administration
```

Not allowed:

```text
Students
General staff
Unauthenticated users
Normal SIP extensions
```

Emergency voicemail recordings should follow the same recording access and retention policy defined in Feature 4.

## Asterisk Features Used

```text
Voicemail
Voicemail recording
CDR / CEL missed-call events
Queue timeout result
Escalation routing result
AMI / ARI event sync
Callback using caller extension
```

## Rejected Designs

```text
Rejected: No answer → call disconnects
Reason: Emergency information may be lost.
```

```text
Rejected: Voicemail exists but has no review workflow
Reason: A recorded emergency is useless if nobody is required to review it.
```

```text
Rejected: Treat all missed internal calls as emergency incidents
Reason: Creates noise and hides real missed emergencies.
```

```text
Rejected: Public access to emergency voicemail recordings
Reason: Emergency recordings are sensitive and must be restricted.
```

## Final Locked Design

```text
Feature Name: Emergency Voicemail & Missed-call Recovery
Status: Approved
Phase: Phase 1
Scope: Missed emergency calls to 111 only
Fallback: Emergency voicemail after escalation failure
Default Severity: Critical
Default Review Status: Pending Review
Review Requirement: Mandatory
Callback: Supported when caller extension is known
Purpose: Ensure unanswered emergency calls are recovered and acted upon
```
