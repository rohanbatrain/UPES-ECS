# Feature 11: Emergency Call Transfer & Dispatch Workflow

## Purpose

Emergency Call Transfer & Dispatch Workflow defines how the Quick Emergency Response Team handles a live emergency call after answering **111** and deciding that another responder or team must be involved.

This feature ensures that the caller is connected to the right help without being lost between departments, extensions, or teams.

## Linked Features

```text
Feature 1: Campus Emergency Hotline
Feature 2: ERT Emergency Queue
Feature 3: Emergency Fallback & Escalation Path
Feature 4: Emergency Call Recording & Incident Logging
Feature 8: Emergency Responder Directory & Numbering Plan
Feature 9: Responder Status & Availability
Feature 10: Emergency Voicemail & Missed-call Recovery
```

## Final Decision

```text
Support three emergency dispatch modes:

1. Dispatch Call Without Transfer
2. Warm Transfer
3. Three-way Bridge

Do not use blind transfer as the normal emergency workflow.
ERT keeps incident ownership unless explicitly reassigned.
```

## Core Principle

The ERT should remain the first owner of the emergency incident.

Bad model:

```text
Caller dials 111
        ↓
ERT answers
        ↓
ERT blindly transfers caller to another extension
        ↓
ERT leaves the call
        ↓
Caller may get lost if the target does not answer
```

Approved model:

```text
Caller dials 111
        ↓
ERT answers
        ↓
ERT understands the emergency
        ↓
ERT decides the correct dispatch mode
        ↓
ERT contacts the right responder/team
        ↓
ERT keeps ownership until proper handoff or resolution
```

## Supported Dispatch Modes

## Mode 1: Dispatch Call Without Transfer

### Status

```text
Supported: Yes
Recommended as default for many emergencies
```

### Meaning

ERT talks to the caller, collects the required details, gives basic safety instructions, and then separately contacts the required responder team.

The caller is not transferred to another department.

### Example Flow

```text
Caller dials 111
        ↓
ERT answers
        ↓
Caller reports smoke near a lab
        ↓
ERT asks location, severity, people affected
        ↓
ERT gives immediate safety instruction
        ↓
ERT separately calls security / operations / medical
        ↓
ERT logs dispatch action
```

### Best Used For

```text
Fire or smoke reports
Infrastructure issues
Power failure
Network failure
Crowd control
Building access issue
Situations where caller should not be passed around
Cases where ERT can dispatch help without making caller talk to another team
```

### Rule

```text
ERT stays responsible for the incident and dispatches responders separately.
```

## Mode 2: Warm Transfer

### Status

```text
Supported: Yes
Preferred transfer method when another responder must directly speak to caller
```

### Meaning

ERT does not blindly transfer the caller.  
ERT first contacts the target responder, explains the situation, confirms they can take over, and then transfers the caller.

### Example Flow

```text
Caller dials 111
        ↓
ERT answers
        ↓
Caller needs medical guidance
        ↓
ERT places caller on brief hold
        ↓
ERT calls Medical Room
        ↓
ERT explains: "Caller from Hostel B, possible injury"
        ↓
Medical confirms availability
        ↓
ERT transfers caller to Medical
        ↓
Transfer action is logged
```

### Best Used For

```text
Medical handoff
Security handoff
Hostel warden handoff
Operations handoff
Cases where the target responder must speak directly with the caller
Cases where responsibility can be safely handed over
```

### Rule

```text
ERT must confirm target responder availability before transferring.
```

## Mode 3: Three-way Bridge

### Status

```text
Supported: Yes
Recommended for serious, unclear, or high-risk cases
```

### Meaning

ERT keeps the caller and another responder in the same live call.

Instead of leaving the call, ERT creates or joins a three-way conversation.

### Example Flow

```text
Caller dials 111
        ↓
ERT answers
        ↓
Caller is panicked and location is unclear
        ↓
ERT brings Medical/Security into the same call
        ↓
Caller + ERT + Responder speak together
        ↓
ERT stays involved until the situation is clear
```

### Best Used For

```text
Serious injuries
Caller is panicked
Location is unclear
Multiple responders need live context
Medical/security needs to ask caller questions directly
ERT wants to monitor the handoff
High-risk incidents where losing caller context is dangerous
```

### Rule

```text
ERT remains in the call until the situation is clear or ownership is formally reassigned.
```

## Rejected Normal Workflow: Blind Transfer

### Status

```text
Supported as normal workflow: No
Restricted / discouraged
```

### Meaning

Blind transfer means ERT transfers the caller to another extension without confirming that the target responder is available.

Rejected example:

```text
Caller dials 111
        ↓
ERT answers
        ↓
ERT directly transfers caller to Medical
        ↓
Medical does not answer
        ↓
Caller is stuck, disconnected, or lost
```

### Reason for Rejection

```text
Caller can get lost
Target responder may not answer
ERT loses visibility
Incident ownership becomes unclear
Emergency response becomes unreliable
```

Blind transfer may exist technically in Asterisk, but it should not be the standard emergency workflow.

## Dispatch Mode Selection Rule

ERT should choose the dispatch mode based on the situation.

```text
Default:
Dispatch Call Without Transfer

When another responder must speak directly to caller:
Warm Transfer

When case is serious, unclear, or needs shared live context:
Three-way Bridge

Avoid:
Blind Transfer
```

## Incident Ownership Rule

The incident remains owned by ERT unless clearly reassigned.

```text
Incident Owner: ERT member who answered 111
Current Action: Medical contacted
Dispatch Mode: Warm Transfer
Target: Medical Room
Handoff Status: Confirmed
Final Owner: ERT / Medical Lead / ERT Lead, depending on reassignment
```

This prevents the failure case:

```text
"I thought someone else handled it."
```

## Transfer and Dispatch Permissions

Only authorized emergency roles should be able to transfer or bridge emergency calls.

Allowed:

```text
ERT members
ERT Lead
Security Control Room
Medical Room
Campus Emergency Coordinator
Authorized emergency administrators
```

Not allowed:

```text
Students
General users
Unauthenticated SIP clients
Normal extensions without emergency role
```

## Logging Requirements

Every emergency dispatch action should be logged.

Recommended log fields:

```text
Incident ID
Original caller extension
Caller user/name if known
ERT member who answered
Dispatch mode used
Target extension/team
Target answered status
Transfer/bridge success or failure
Time of dispatch action
Final call status
Incident owner after handoff
Notes added by ERT
```

Example log:

```text
Incident ID: INC-2026-0051
Caller: Extension 315
Answered by: ERT Desk 1
Dispatch Mode: Warm Transfer
Target: Medical Room
Target Answered: Yes
Transfer Completed: Yes
Incident Owner: ERT Desk 1
Handoff Status: Medical connected
```

## Asterisk Features Used

```text
Attended transfer
Call transfer controls
Three-way calling / bridging
Call parking if needed
Dialplan transfer permissions
CDR / CEL transfer tracking
AMI / ARI event sync
Queue and call state tracking
```

## Rejected Designs

```text
Rejected: Blind transfer as default emergency workflow
Reason: Caller can get lost and ERT loses ownership.
```

```text
Rejected: Caller bounces between departments
Reason: Emergency caller should not be passed around repeatedly.
```

```text
Rejected: Transfer completed but incident owner unknown
Reason: Creates accountability failure.
```

```text
Rejected: Any user can transfer or bridge emergency calls
Reason: Emergency call control must be restricted to authorized roles.
```

## Final Locked Design

```text
Feature Name: Emergency Call Transfer & Dispatch Workflow
Status: Approved
Phase: Phase 1
Supported Modes: Dispatch Without Transfer, Warm Transfer, Three-way Bridge
Default Mode: Dispatch Without Transfer
Preferred Transfer Method: Warm Transfer
Serious/Unclear Cases: Three-way Bridge
Blind Transfer: Restricted / discouraged
Incident Ownership: ERT owns until explicit reassignment
Purpose: Connect emergency callers and responders without losing control or accountability
```