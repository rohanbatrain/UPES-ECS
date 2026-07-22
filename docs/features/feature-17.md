# Feature 17: Emergency SOP & Drill Mode

## Purpose

Emergency SOP & Drill Mode defines how people actually use the LAN-only Asterisk emergency communication system during real incidents and planned tests.

This feature ensures that ERT members, control room users, security, medical, wardens, operations, and other emergency roles know what to do when the system is used.

The goal is to make the system operationally reliable, not just technically functional.

## Linked Features

```text
Feature 1: Campus Emergency Hotline
Feature 2: ERT Emergency Queue
Feature 3: Emergency Fallback & Escalation Path
Feature 4: Emergency Call Recording & Incident Logging
Feature 6: Emergency Announcement & Paging
Feature 7: Incident Command Conference Rooms
Feature 8: Emergency Responder Directory & Numbering Plan
Feature 9: Responder Status & Availability
Feature 10: Emergency Voicemail & Missed-call Recovery
Feature 11: Emergency Call Transfer & Dispatch Workflow
Feature 13: SIP Security & Access Control
Feature 16: Local System Health Monitoring
```

## Final Decision

```text
Create an Emergency SOP and Drill Mode for the LAN-only Asterisk emergency communication system.

The SOP defines real incident usage.
Drill Mode defines safe testing and training usage.
```

## Core Principle

A working Asterisk setup is not enough.

The emergency system must also define:

```text
Who answers 111
What ERT asks the caller
How incidents are categorized
When responders are dispatched
When transfer/bridge is used
When paging is allowed
When conference room 9000 is activated
How missed emergency voicemails are reviewed
How drills are performed safely
How post-incident review happens
```

## Part A: Emergency Call Answering SOP

When the ERT answers a call to **111**, they should follow a simple call-handling script.

Recommended opening line:

```text
Campus Emergency Response.
What is your emergency and where are you located?
```

## Required Call Questions

ERT should quickly capture:

```text
Caller name / SAP ID if known
Current location
Type of emergency
What is happening right now
Number of people affected
Any injury
Immediate danger yes/no
Fire/smoke/electrical risk yes/no
Whether caller can safely stay on the call
```

The script must stay short.  
In emergencies, long forms slow down response.

## Minimum Call Flow

```text
1. Answer 111.
2. Identify emergency type.
3. Confirm caller location.
4. Ask if anyone is injured or in immediate danger.
5. Keep caller on line if useful.
6. Dispatch correct responder/team.
7. Log action taken.
8. Escalate if required.
```

## Part B: Incident Classification

ERT should classify incidents into simple categories.

Recommended Phase 1 categories:

```text
Medical
Fire / Smoke
Security threat
Violence / fight
Missing person
Infrastructure failure
Power / electrical issue
Crowd / panic
Hostel emergency
Other
```

The category list should remain simple in Phase 1.

Rejected approach:

```text
Too many incident categories that slow down the operator.
```

## Part C: Dispatch Decision SOP

ERT chooses the correct action after understanding the emergency.

Available actions:

```text
Dispatch without transfer
Warm transfer
Three-way bridge
Call responder directory
Activate 9000 Main Incident Command Room
Use paging zone
Escalate to ERT Lead
Give caller immediate safety instruction
```

## Example Dispatch Rules

```text
Medical injury:
Contact medical responder / medical room.

Fire or smoke:
Contact security and operations.
Consider paging only if evacuation or area avoidance is needed.

Security threat:
Contact security control room.
Keep caller on the line if safe.

Hostel emergency:
Contact warden/security.
Use hostel paging only if authorized.

Major multi-team incident:
Activate 9000 Main Incident Command Room.
```

## Part D: Paging SOP

Paging is powerful and must be used carefully.

Paging should be used only when:

```text
There is verified or high-confidence danger.
A specific area must evacuate.
A specific area must avoid a location.
People need immediate safety instructions.
ERT Lead or control room approves.
```

Paging should not be used for:

```text
Unverified rumors
Minor incidents
Personal disputes
General announcements
Testing without drill notice
Non-emergency communication
```

## Paging Message Format

Paging messages should be short, calm, and action-oriented.

Template:

```text
Attention. This is Campus Emergency Response.
[Instruction].
[Location/area affected].
[What to do].
Await further instructions.
```

Example:

```text
Attention. This is Campus Emergency Response.
Students in Hostel B should evacuate using the main staircase.
Move to the football ground assembly point.
Do not use elevators.
Await further instructions.
```

## Part E: Incident Command Conference SOP

The main conference room **9000** should be used only when coordination is needed.

Use **9000 Main Incident Command Room** when:

```text
More than one response team is involved.
ERT Lead needs live coordination.
Security, medical, admin, wardens, or operations need shared updates.
Paging or evacuation decision is being considered.
Incident is active and evolving.
```

Do not open 9000 for every small call.

Rejected approach:

```text
Every 111 call automatically opens conference 9000.
```

Approved approach:

```text
ERT handles simple incidents directly.
ERT activates 9000 only when multi-team coordination is required.
```

## Part F: Missed Emergency SOP

Missed emergency voicemails must be reviewed.

Workflow:

```text
1. Open missed emergency list.
2. Listen to voicemail.
3. Identify caller and location.
4. Call back if possible.
5. Dispatch responder if needed.
6. Add action notes.
7. Mark reviewed or convert to active incident.
```

Mandatory rule:

```text
Missed emergency voicemails must never remain unreviewed.
```

## Part G: Drill Mode

Drill Mode allows the system to be tested safely without creating panic or polluting real emergency operations.

Drill Mode should support testing:

```text
Emergency call flow
ERT queue
Call recording
Emergency voicemail
Warm transfer
Three-way bridge
Conference room 9000
Paging
Access restrictions
Responder training
```

## Drill Labeling

Drill calls and drill logs should be clearly marked.

Example label:

```text
DRILL - Test Emergency Call
```

This prevents confusion between real incidents and practice events.

## Drill/Test Extension

Create a separate test number.

Recommended example:

```text
199  Emergency Test Line
```

Purpose:

```text
Simulate emergency call flow without triggering real escalation or panic.
```

Possible behavior:

```text
199 routes to test ERT queue.
199 records test call.
199 creates drill log.
199 does not trigger real escalation.
199 does not create a real emergency incident unless explicitly configured.
```

The exact number can be finalized later.

## Real 111 Testing

The real **111** line should also be tested occasionally, but only during planned drill windows.

Rule:

```text
Real 111 testing must be planned and announced to ERT/control room before execution.
```

## Drill Types

### 1. Technical Test

Purpose:

```text
Verify SIP registration, 111 routing, ERT answer, recording, voicemail, and logs.
```

### 2. ERT Call-handling Drill

Purpose:

```text
Train ERT to answer, ask correct questions, classify incident, dispatch, and log action.
```

### 3. Missed-call Drill

Purpose:

```text
Test emergency voicemail and missed-call recovery workflow.
```

### 4. Paging Drill

Purpose:

```text
Test authorized paging and audibility in selected zones.
```

Rule:

```text
Paging drills require prior notice.
```

### 5. Full Incident Drill

Purpose:

```text
Test 111 call, ERT queue, dispatch, conference 9000, paging, recording, logging, and review.
```

## Part H: Post-incident / Post-drill Review

After a real incident or drill, the team should review:

```text
Was 111 answered quickly?
Was caller location captured?
Was the right team dispatched?
Was recording saved?
Were logs correct?
Was paging used correctly?
Was conference 9000 useful?
Were any devices offline?
Did mobile SIP calling work properly?
Did access control work?
What needs improvement?
```

## Post-review Output

Each drill or serious incident should produce a short review note.

Example:

```text
Drill Date:
Scenario:
What worked:
What failed:
Response time:
Recording/log status:
Device issues:
Training gaps:
Action items:
Owner:
Due date:
```

## Phase 1 SOP Scope

Phase 1 SOP should include:

```text
ERT call-answering script
Basic incident categories
Dispatch decision rules
Paging usage rules
Conference room activation rules
Missed emergency review SOP
Drill/test number such as 199
Weekly/monthly test checklist
Post-drill review template
```

## What This Feature Does Not Do

This feature does not create a huge emergency manual in Phase 1.

It does not try to cover every possible disaster scenario in detail.

It creates the minimum operational discipline required to use the Asterisk system correctly.

## Rejected Designs

```text
Rejected: ERT relies only on memory and informal knowledge
Reason: Emergency response needs repeatable operating procedure.
```

```text
Rejected: Surprise campus-wide paging tests
Reason: Can create panic and distrust.
```

```text
Rejected: Use 111 casually for random testing
Reason: Pollutes the real emergency flow and creates confusion.
```

```text
Rejected: Open conference 9000 for every emergency call
Reason: Creates unnecessary noise and responder fatigue.
```

```text
Rejected: Create a huge SOP nobody reads
Reason: Phase 1 SOP must be short, usable, and drillable.
```

## Asterisk Features Used

```text
Dedicated test extension
Queue routing
Call recording
Voicemail
Conference rooms
Paging codes
Dialplan labels for drill calls
CDR/CEL logs
Access control
AMI/ARI event sync if backend/dashboard is used
```

## Final Locked Design

```text
Feature Name: Emergency SOP & Drill Mode
Status: Approved
Phase: Phase 1
Real Emergency Number: 111
Recommended Test Number: 199
SOP Scope: Call answering, incident classification, dispatch, paging, conference activation, missed-call review
Drill Scope: Test calls, recordings, voicemail, transfer, conference, paging, access control
Paging Tests: Planned only
Purpose: Ensure people can correctly operate and safely test the LAN-only Asterisk emergency system
```
