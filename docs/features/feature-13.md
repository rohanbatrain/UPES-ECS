# Feature 13: SIP Security & Access Control

## Purpose

SIP Security & Access Control defines who can register to the LAN-only Asterisk system and what each type of user/device is allowed to do.

The goal is to allow useful campus-wide internal communication while protecting emergency-only features from misuse.

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
```

## Final Decision

```text
Allow authenticated students to call other students internally.
Allow all authenticated campus users to call 111.
Restrict emergency control features to authorized emergency roles only.
```

This means the system is not only an emergency hotline. It can also act as a LAN-only campus communication layer.

## Core Security Principle

The system should separate **normal internal calling** from **emergency authority functions**.

```text
Normal campus communication:
Allowed for authenticated users.

Emergency control functions:
Restricted to ERT, ERT Lead, control room, and authorized emergency roles.
```

## User Categories

The system should support role-based SIP access.

Example categories:

```text
Students
General staff
ERT members
ERT Lead
Control room / emergency admin
Security / medical / warden / operations responders
System devices
```

The exact roles and mappings will be finalized later in the role-design drill.

## Student Calling Permissions

Students should be allowed to use the LAN-only SIP system for internal student-to-student communication.

### Students Can

```text
Call 111
Call other student extensions
Receive calls from other students
Receive calls from ERT or authorized emergency users
Use normal internal SIP calling features approved for students
```

### Students Cannot

```text
Use emergency paging codes
Join incident command conference rooms
Access ERT queue controls
Pause/unpause queue members
Access emergency voicemail review
Access emergency call recordings
Use emergency transfer/dispatch controls
Access admin/configuration functions
Call restricted emergency-only numbers unless approved
```

## Student-to-student Call Rule

Student-to-student calls are treated as normal internal calls.

```text
Student ↔ Student call:
Normal internal call
Not an emergency incident
Not recorded by default
Logged only as normal call metadata if CDR logging is enabled
```

This protects privacy and keeps emergency incident records clean.

## General Staff Permissions

General staff permissions can be similar to students, with optional extra access depending on policy.

### Staff Can

```text
Call 111
Call other allowed internal campus extensions
Receive internal calls
Call student/staff extensions if approved
```

### Staff Cannot by Default

```text
Use paging
Join command rooms
Access emergency recordings
Control emergency queues
Use emergency dispatch controls
Access restricted responder-only extensions
```

Any staff role requiring emergency privileges should be explicitly assigned to a responder or emergency role.

## ERT Member Permissions

ERT members are operational emergency responders.

### ERT Members Can

```text
Receive calls from the 111 emergency queue
Call emergency responder directory extensions
Use approved dispatch workflows
Perform warm transfers
Participate in approved three-way bridges
Join assigned incident conference rooms
Pause/unpause themselves from the emergency queue
Call students/staff back when required for an incident
```

### ERT Members Cannot Automatically

```text
Use campus-wide paging unless specifically allowed
Access all emergency recordings unless policy permits
Change system configuration
Create/delete SIP accounts
Access full admin functions
```

## ERT Lead Permissions

ERT Lead has higher emergency authority than a normal ERT member.

### ERT Lead Can

```text
Use all approved ERT member functions
Access escalation workflows
Use emergency paging if approved
Join and control the main incident command room
Review missed emergency voicemails
Access emergency recordings if policy permits
Coordinate dispatch and handoff ownership
```

## Control Room / Emergency Admin Permissions

Control room and emergency admin users have operational command permissions.

### Control Room / Emergency Admin Can

```text
Use paging codes
Monitor active emergency calls
Review emergency logs
Access emergency recordings based on policy
Monitor responder availability
Coordinate conference rooms
Manage live incident communication
Access missed emergency recovery list
```

They should not automatically receive full Linux/server admin access unless they are also part of the IT operations role.

## System Device Permissions

System devices should have minimum required permissions only.

Examples:

```text
IP speaker:
Receive paging only.

Security gate phone:
Call 111 and selected security/ERT extensions.

Medical room phone:
Receive emergency handoffs and call ERT/security.

Hostel warden desk phone:
Call 111, ERT, and approved warden/security/medical extensions.

Student softphone:
Call 111 and other allowed student/internal extensions.
```

## Access Control Areas

## 1. SIP Registration Control

Only approved accounts and devices should be able to register.

Required controls:

```text
No anonymous SIP registration
No guest SIP access
Unique SIP credentials per user/device
Strong random SIP passwords
Registration restricted to university LAN/Wi-Fi
Lost or misused accounts can be revoked
Shared accounts avoided except for controlled fixed devices
```

## 2. Dialplan Context Control

Asterisk should separate users using dialplan contexts.

Example contexts:

```text
student_context
staff_context
ert_context
ert_lead_context
control_room_context
system_device_context
```

Each context gets only the numbers and features it is allowed to access.

Example:

```text
student_context:
Can call 111
Can call student extension range
Can call approved internal user ranges

Cannot call 700 paging codes
Cannot call 9000 incident command rooms
Cannot access ERT queue controls
```

## 3. Paging Access Control

Paging is restricted.

Allowed:

```text
ERT Lead
Control Room
Campus Emergency Coordinator
Authorized emergency administrators
```

Not allowed:

```text
Students
General staff
Unauthenticated devices
Normal SIP accounts
```

## 4. Conference Room Access Control

Incident command rooms are restricted.

Allowed:

```text
ERT members
ERT Lead
Security/medical/warden/operations responders
Control room
Authorized emergency coordinators
```

Not allowed:

```text
Students
General users
Unauthenticated devices
Normal staff without emergency role
```

The main command room can optionally require a PIN in addition to role-based access.

## 5. Emergency Recording Access Control

Emergency recordings are sensitive.

Allowed:

```text
ERT Lead
Authorized ERT reviewers
Campus Emergency Coordinator
Approved audit/admin role
```

Not allowed:

```text
Students
General staff
Normal SIP users
Unauthenticated users
Non-emergency roles
```

Student-to-student calls are not recorded by default.

## 6. Emergency Voicemail Access Control

Emergency voicemail review is restricted.

Allowed:

```text
ERT Lead
Authorized ERT members
Control room
Campus Emergency Coordinator
Approved emergency admin role
```

Not allowed:

```text
Students
General staff
Normal SIP accounts
Unauthenticated users
```

## 7. Transfer and Dispatch Control

Emergency call transfer/dispatch controls are restricted.

Allowed:

```text
ERT members
ERT Lead
Control room
Medical/security/warden/operations responders if approved
```

Not allowed:

```text
Students
General users
Normal SIP accounts
Unauthenticated devices
```

Students can make normal internal calls, but they cannot control emergency call dispatch workflows.

## Student-to-student Calling Safety Rules

Student calling should be allowed, but still traceable.

Required rules:

```text
No anonymous internal calls
Caller ID must show real extension/user
Each student should have a unique SIP account
Abusive accounts can be disabled
Call metadata can be logged for abuse investigation
Emergency number 111 must always remain reachable
Normal student calls must not interfere with emergency queue priority
```

## Emergency Priority Rule

Emergency calls must have priority over normal internal calling.

```text
Calls to 111 are priority emergency traffic.
Student-to-student calling must not block or degrade 111 emergency handling.
```

Implementation may include:

```text
Dedicated ERT queue capacity
Separate emergency contexts
Call limits for normal users if needed
Emergency device priority
Monitoring of channel capacity
```

## Logging Requirements

Security-relevant events should be logged locally.

Recommended logs:

```text
Successful SIP registration
Failed SIP registration
Unknown device registration attempt
Restricted number denied
Emergency call attempt
Student-to-student call metadata
Paging attempt
Conference join attempt
Transfer/dispatch attempt
Emergency voicemail access
Emergency recording access
Admin/configuration change
Account disabled/revoked event
```

Normal internal calls should not become emergency incidents unless routed through emergency workflows.

## Abuse Handling

The system should support revocation and investigation.

If a user misuses the system:

```text
Identify extension/user from caller ID and logs
Disable or reset SIP account
Block device if necessary
Review call metadata
Escalate according to university policy
```

## Security Rules

Phase 1 security rules:

```text
1. LAN-only SIP/RTP.
2. No anonymous SIP.
3. Unique SIP credentials.
4. Strong random passwords.
5. Role-based dialplan contexts.
6. Students can call 111 and other students.
7. Emergency paging restricted to authorized roles.
8. Incident conference rooms restricted to emergency roles.
9. Emergency recordings and voicemail restricted.
10. Lost/misused accounts can be revoked.
11. SIP registration limited to approved campus networks.
12. Emergency call flow must not depend on public internet or cellular.
```

## Rejected Designs

```text
Rejected: Students can only call 111
Reason: Too restrictive; student-to-student LAN calling is useful and reasonable.
```

```text
Rejected: Students can access all internal numbers and emergency controls
Reason: Creates misuse risk and operational disruption.
```

```text
Rejected: One shared SIP username/password for many users
Reason: No accountability, no revocation control, and poor abuse tracking.
```

```text
Rejected: Anonymous SIP calling
Reason: Emergency and abuse events must be traceable.
```

```text
Rejected: Allow all users to dial paging codes
Reason: High risk of panic, misinformation, and disruption.
```

```text
Rejected: Allow students to join incident command rooms
Reason: Incident command rooms are for authorized responders only.
```

```text
Rejected: Record student-to-student calls by default
Reason: Privacy-heavy and not required for emergency response.
```

```text
Rejected: Expose SIP/RTP publicly
Reason: Violates the LAN-only infrastructure boundary.
```

## Asterisk Features Used

```text
PJSIP authentication
PJSIP endpoint contexts
PJSIP ACLs
Named ACLs
Dialplan contexts
Role-based dialplan routing
Caller ID controls
Feature-code restrictions
Queue permission controls
Conference access controls
Voicemail access controls
CDR/CEL logging
AMI/ARI event sync if backend is used
```

## Final Locked Design

```text
Feature Name: SIP Security & Access Control
Status: Approved
Phase: Phase 1
Network Scope: LAN-only
Student Calling: Student-to-student calling allowed
Emergency Number Access: All authenticated users can call 111
Emergency Controls: Restricted to authorized roles
Paging Access: Restricted
Conference Access: Restricted
Recording/Voicemail Access: Restricted
Anonymous SIP: Not allowed
Shared Credentials: Avoided
Purpose: Allow useful internal campus communication while protecting emergency functions from misuse
```