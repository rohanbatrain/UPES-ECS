# Feature 8: Emergency Responder Directory & Numbering Plan

## Purpose

The Emergency Responder Directory & Numbering Plan defines the internal calling structure for the disaster-response voice system.

This feature ensures that emergency responders can quickly reach the right internal people, rooms, and services without depending on personal mobile numbers or searching through contact lists during an incident.

## Final Decision

```text
Create a structured internal emergency directory and numbering plan.
Use example roles and numbers for planning only.
Finalize actual roles, users, and extension mappings later in a separate design drill.
```

## Important Planning Note

All roles, names, departments, and extension numbers mentioned in this feature are currently **examples only**.

The final directory will be decided later through a dedicated design exercise with the university/team.

That later design drill will decide:

```text
Actual emergency roles
Actual responder groups
Actual extension numbers
Actual permissions
Actual campus locations
Actual escalation contacts
Actual ownership of each emergency function
```

## Core Concept

The Asterisk system should have a predictable internal emergency numbering structure.

Example structure:

```text
111    Campus Emergency Hotline
200s   ERT / Control Room
300s   Security
400s   Medical
500s   Hostel / Wardens
600s   Admin / Operations
700s   Paging
9000s  Conference Rooms
```

This example is not final. It only shows the kind of structured plan we want.

## Why This Feature Is Needed

During a disaster, responders should not depend on:

```text
Personal mobile contact lists
Random WhatsApp groups
Unclear department numbers
Memory-based calling
Searching for names during panic
```

Instead, responders should have a clean internal directory where every critical emergency function has a known extension.

## Example Numbering Plan

The following is only an example and not the final approved directory.

```text
111   Campus Emergency Hotline

201   ERT Desk 1
202   ERT Desk 2
203   ERT Desk 3
204   ERT Lead

301   Security Control Room
302   Main Gate Security
303   Hostel Gate Security

401   Medical Room
402   Nurse Desk
403   First Aid Response Team

501   Chief Warden
502   Hostel A Warden
503   Hostel B Warden

601   Admin Emergency Coordinator
602   Campus Operations Head
603   Power / Electrical Team
604   IT / Network Team

700   All Campus Broadcast
701   Hostels Paging
702   Academic Blocks Paging

9000  Main Incident Command Room
9001  Security Coordination Room
9002  Medical Coordination Room
```

These are placeholders to guide the architecture.

## Scope

This feature covers emergency communication roles and critical campus points only.

Included:

```text
ERT / Control Room
Security
Medical
Hostel / Wardens
Admin emergency authority
Operations / Infrastructure
IT / Network emergency support
Paging codes
Conference rooms
Critical fixed campus points
```

Not included in Phase 1:

```text
Every student
Every faculty member
Every classroom
Every department extension
Every non-emergency office
Large full-campus PBX directory
```

## Access Model

The directory should support role-based calling permissions.

Example model:

```text
Students/staff:
Can call 111.

ERT:
Can call emergency responder extensions.

ERT Lead/Admin:
Can access paging, conference rooms, escalation contacts, and emergency authority extensions.
```

This exact permission model will be finalized later.

## Directory Formats

The finalized directory should eventually exist in multiple formats:

```text
Asterisk dialplan
Responder SOP document
Printed emergency contact sheet
Control room reference sheet
Internal dashboard page
```

For Phase 1, a simple printed sheet and Asterisk configuration may be enough.

## What This Enables

This feature makes emergency workflows predictable.

Example:

```text
ERT receives call on 111
        ↓
ERT contacts security extension
        ↓
ERT contacts medical extension
        ↓
ERT asks team leads to join command room
        ↓
ERT uses paging code if public announcement is needed
```

The actual numbers and roles will be finalized later.

## Rejected Designs

```text
Rejected: Build a huge full-campus phone directory in Phase 1
Reason: Too much scope and not necessary for disaster-response MVP.
```

```text
Rejected: Depend on personal mobile numbers as the primary emergency directory
Reason: Cellular service may be unavailable and personal contacts are hard to manage.
```

```text
Rejected: Give all users access to paging and conference codes
Reason: High risk of misuse, confusion, and panic.
```

```text
Rejected: Finalize exact roles and numbers without a separate design drill
Reason: The real emergency structure must be decided carefully with stakeholders.
```

## Asterisk Features Used

```text
Internal extensions
Dialplan contexts
PJSIP endpoints
Permission-based routing
Caller ID labels
Extension groups
Access control by role/context
```

## Final Locked Design

```text
Feature Name: Emergency Responder Directory & Numbering Plan
Status: Approved
Phase: Phase 1 planning
Exact Roles: Not finalized yet
Exact Numbers: Not finalized yet
Current Numbers/Roles: Examples only
Finalization Method: Separate design drill
Purpose: Create a structured internal emergency calling system for responders
```
