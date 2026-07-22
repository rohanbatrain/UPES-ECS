# Feature 14: Device Provisioning & Extension Management

## Purpose

Device Provisioning & Extension Management defines how SIP accounts, extensions, credentials, devices, roles, and ownership are created, assigned, managed, revoked, and tracked in the LAN-only Asterisk emergency communication system.

This feature becomes especially important because the system will allow authenticated students to call other students internally.

## Linked Features

```text
Feature 5: Ready-made SIP Client Deployment
Feature 8: Emergency Responder Directory & Numbering Plan
Feature 9: Responder Status & Availability
Feature 12: LAN-only Infrastructure Boundary
Feature 13: SIP Security & Access Control
```

## Final Decision

```text
Use the university SAP ID as the SIP extension and SIP username for all human users.

Human users:
Extension = SAP ID

Fixed devices:
Use separate fixed-device extensions.

Service features:
Use reserved short service numbers.
```

## Core Identity Model

The system will use three types of SIP identities:

```text
1. Human user accounts
2. Fixed device accounts
3. Service / feature codes
```

Each type has a different purpose and should not be mixed.

---

## 1. Human User SIP Accounts

For students, staff, faculty, and ERT members who are real university users, the SIP extension will be their SAP ID.

```text
SIP Extension = SAP ID
SIP Username = SAP ID
Owner Identity = University SAP ID
```

Example:

```text
User: Rohan Batra
SAP ID: 500120597
SIP Extension: 500120597
SIP Username: 500120597
Display Name: Rohan Batra - 500120597
```

## Why SAP ID Works Well

Using SAP ID simplifies identity management because the university already uses it as a unique identifier.

Benefits:

```text
No separate extension allocation needed
Easy student/staff mapping
Easy onboarding
Easy offboarding
Easy abuse tracing
Easy log correlation
Easy caller identification
No duplicate human extensions
No confusion about who owns an extension
```

## Human User Role Assignment

A user’s SAP ID identifies the person.

Their permissions come from their assigned role/context.

```text
SAP ID = identity
Role/context = permissions
```

Example:

```text
Same format:
Extension: SAP ID

Different permissions:
Student → student_context
Staff → staff_context
ERT Member → ert_context
ERT Lead → ert_lead_context
Control Room User → control_room_context
```

The number identifies the person.  
The role controls what the person can do.

---

# Student Accounts

Students use their SAP ID as their SIP extension.

```text
Extension: SAP ID
Username: SAP ID
Role: Student
Context: student_context
```

Students can:

```text
Call 111
Call other student SAP ID extensions
Receive calls from other students
Receive calls from ERT or authorized emergency users
Use approved normal internal calling features
```

Students cannot:

```text
Use paging codes
Join incident command rooms
Access ERT queue controls
Access emergency voicemail review
Access emergency recordings
Use emergency dispatch/transfer controls
Access admin functions
```

Student-to-student calls remain normal internal calls.

```text
Student ↔ Student call:
Normal internal call
Not an emergency incident
Not recorded by default
```

---

# Staff / Faculty Accounts

Staff and faculty also use SAP ID as their SIP extension.

```text
Extension: SAP ID
Username: SAP ID
Role: Staff / Faculty
Context: staff_context
```

Staff permissions can be finalized later, but the base model is:

```text
Can call 111
Can call approved internal users
Can receive internal calls
Cannot access emergency-only controls unless assigned an emergency role
```

---

# ERT Member Accounts

If an ERT member is a university user, their SIP extension is still their SAP ID.

```text
Extension: SAP ID
Username: SAP ID
Role: ERT Member
Context: ert_context
```

Their emergency privileges come from the ERT role, not from having a special number.

ERT members can:

```text
Receive 111 queue calls
Call emergency responder extensions
Use approved dispatch workflows
Join approved incident conference rooms
Pause/unpause from ERT queue
Call back students/staff when needed for an incident
```

---

# ERT Lead / Emergency Admin Accounts

ERT Lead and emergency admin users also use SAP ID if they are real university users.

```text
Extension: SAP ID
Username: SAP ID
Role: ERT Lead / Emergency Admin
Context: ert_lead_context or control_room_context
```

They may get access to:

```text
Escalation workflows
Paging codes
Main incident command room
Missed emergency voicemail review
Emergency recording access if policy permits
Responder availability monitoring
Emergency dispatch coordination
```

---

## 2. Fixed Device SIP Accounts

Fixed physical devices should not use a human SAP ID.

Fixed devices include:

```text
ERT desk phones
Control room phones
Security gate phones
Medical room phones
Hostel warden desk phones
Admin emergency desk phones
IP speakers
Paging devices
Shared lab/library/security phones
```

These should use separate fixed-device extensions.

Example:

```text
Extension: fixed-device number
Owner: Main Gate Security Phone
Location: Main Gate
Role: Fixed Security Device
Context: security_device_context
Status: Active
```

## Why Fixed Devices Should Not Use SAP IDs

A fixed device belongs to a location or function, not to one person.

```text
Human user → SAP ID extension
Fixed location/device → fixed-device extension
Service feature → short service code
```

This prevents confusion when multiple people use one desk phone.

Example:

```text
Medical Room Phone should show:
Medical Room

Not:
A random nurse's SAP ID
```

---

## 3. Service / Feature Codes

Short numbers remain reserved for emergency features.

Examples:

```text
111   Campus Emergency Hotline
700   All Campus Broadcast
701   Hostels Paging
702   Academic Blocks Paging
9000  Main Incident Command Room
9001  Security Coordination Room
9002  Medical Coordination Room
```

These are not user accounts.

They are service codes handled by the dialplan.

---

# Extension Structure Summary

```text
Human users:
SAP ID

Fixed devices:
Separate fixed-device extension range

Service features:
Reserved short service numbers
```

Final fixed-device ranges and service-code ranges will be finalized later in the numbering/design drill.

---

## Provisioning Flow for Human Users

For each student/staff/faculty/ERT member:

```text
1. Pull or enter SAP ID.
2. Create SIP account using SAP ID.
3. Assign role/context.
4. Generate strong random SIP password.
5. Set caller ID display name.
6. Provide setup instructions or QR/config.
7. User registers SIP app on LAN.
8. Account appears in internal directory.
```

Example:

```text
SIP Server: asterisk.university.lan
Username: 500120597
Extension: 500120597
Password: strong-random-password
Display Name: Rohan Batra - 500120597
```

---

## Provisioning Flow for Fixed Devices

For each fixed phone/device:

```text
1. Assign fixed-device extension.
2. Set owner/location name.
3. Assign role/context.
4. Generate strong random SIP password.
5. Configure physical device or softphone.
6. Lock permissions to required use only.
7. Document physical location.
8. Add to responder directory if required.
```

Example:

```text
Extension: 4301
Name: Main Gate Security
Location: Main Gate
Role: Fixed Security Device
Context: security_device_context
Allowed: Call 111, call ERT/security, receive emergency calls
```

The number range above is only an example.

---

## Caller ID Rules

Caller ID must be readable and traceable.

For human users:

```text
Display Name + SAP ID
```

Example:

```text
Rohan Batra - 500120597
```

For fixed devices:

```text
Location / Role Name
```

Example:

```text
Main Gate Security
Medical Room
ERT Desk 1
Hostel A Warden Desk
```

Bad caller ID examples:

```text
Unknown
Phone 1
User
Extension 1234 only
```

---

## Credential Policy

Every SIP account must have unique credentials.

```text
Username: SAP ID or fixed-device extension
Password: strong random password
```

Rejected passwords:

```text
student123
sapid123
100100
password
same password for everyone
```

Shared generic accounts should be avoided except for controlled fixed devices.

---

## SIP Client Setup

Since Phase 1 uses ready-made SIP apps, users need a clear setup method.

Supported provisioning methods:

```text
Manual setup guide
QR code configuration
Pre-filled SIP profile
Admin-assisted setup
Device-specific setup sheet
```

Recommended Phase 1 approach:

```text
Start with manual setup guide for pilot users.
Add QR/config provisioning when scaling.
```

---

## Device Binding

The system should avoid uncontrolled credential sharing.

Recommended rules:

```text
One human SIP account belongs to one SAP ID.
A human account may have a limited number of registered devices if allowed.
Fixed device accounts are tied to physical locations.
Lost devices require password reset or account revocation.
Abusive accounts can be disabled.
```

Exact device limits can be decided later.

---

## Account Lifecycle States

Each SIP account should have a status.

Recommended statuses:

```text
Pending Setup
Active
Disabled
Password Reset Required
Lost Device
Archived
```

## Lifecycle Behavior

### Pending Setup

```text
Account exists but user/device has not completed setup.
```

### Active

```text
Account can register and use allowed SIP features.
```

### Disabled

```text
Account cannot register or place calls.
```

### Password Reset Required

```text
Old credential is invalid or must be rotated.
```

### Lost Device

```text
Device or credential may be compromised.
Access should be revoked/reset immediately.
```

### Archived

```text
User/device is no longer active, but historical logs remain preserved.
```

---

## Revocation and Reset

The system must support quick action when a device is lost or a user misuses the system.

Actions:

```text
Disable extension
Reset SIP password
Remove active registration
Block old credentials
Update account state
Preserve historical logs
Document reason for action
```

This directly supports SIP Security & Access Control.

---

## Bulk Onboarding

Using SAP ID makes bulk onboarding easier.

Later, the system can support:

```text
CSV import
SAP ID import
Student batch import
Staff/faculty import
Role assignment by type
Hostel/course/department grouping if needed
Bulk SIP password generation
Bulk QR/config generation
Bulk account disabling/offboarding
```

Phase 1 does not need full automation, but the model should allow it later.

---

## Directory Mapping

The provisioning system should feed the internal directory.

Examples:

```text
SAP ID 500120597 → Rohan Batra → Student
SAP ID 500987654 → ERT Member → ERT context
Fixed 4301 → Main Gate Security
Fixed 4401 → Medical Room
111 → Campus Emergency Hotline
9000 → Main Incident Command Room
```

The directory should support:

```text
Caller ID lookup
Incident log identity mapping
Emergency callback
Responder directory
Abuse investigation
Account ownership tracking
```

---

## Admin Interface Need

For a small pilot, raw config files may be acceptable.

For university-scale rollout, a local admin interface is strongly recommended.

The admin interface should support:

```text
Create SIP account
Disable SIP account
Reset SIP password
Assign role/context
Assign owner/name/location
View registration status
View last seen
View current device/IP
Export directory
Generate QR/config
Archive user/device
Revoke lost device credentials
```

The admin panel must remain LAN-only according to Feature 12.

---

## Phase 1 Scope

Phase 1 should start with a controlled rollout.

Create accounts for:

```text
ERT members
ERT Lead
Control room users
Security points
Medical room
Hostel/warden desks
Operations/IT emergency contacts
Selected pilot students/staff
```

Do not onboard the entire university on day one.

## Why Not Entire University Immediately

Before full rollout, validate:

```text
SIP app setup process
SAP ID login clarity
Password handling
Call quality
Student-to-student calling behavior
Abuse controls
Emergency call priority
Directory correctness
Support workload
```

Once stable, scale to more users.

---

## Emergency Priority

Normal student-to-student calling must not interfere with emergency use.

```text
Emergency calls to 111 must remain highest priority.
Normal internal calls must not degrade ERT queue handling.
```

Possible controls:

```text
Channel limits for normal users
Separate emergency contexts
Dedicated ERT devices
Monitoring call capacity
Restricting high-risk features for normal users
```

---

## Rejected Designs

```text
Rejected: Create separate random SIP extensions for every student
Reason: SAP ID already uniquely identifies every university user.
```

```text
Rejected: Use human SAP ID for fixed shared devices
Reason: Fixed devices belong to locations/functions, not individual people.
```

```text
Rejected: One shared SIP account for all students
Reason: No accountability, no revocation, no abuse tracing.
```

```text
Rejected: Manually maintain thousands of users only in raw Asterisk config forever
Reason: Works for small pilots, not university-scale lifecycle management.
```

```text
Rejected: Reuse extensions without preserving identity history
Reason: Old call logs and new user identity can get mixed.
```

```text
Rejected: Give emergency-role permissions to normal student accounts
Reason: Paging, command rooms, recordings, and dispatch workflows must remain restricted.
```

---

## Asterisk Features Used

```text
PJSIP endpoints
PJSIP auth objects
AORs
Dialplan contexts
Caller ID naming
Device registration status
Config reloads
CDR/CEL identity mapping
Realtime database integration later if needed
```

---

## Final Locked Design

```text
Feature Name: Device Provisioning & Extension Management
Status: Approved
Phase: Phase 1
Human Extension Model: SAP ID as SIP extension and username
Student Calling: SAP ID-to-SAP ID internal calling
Fixed Devices: Separate fixed-device extensions
Service Codes: Reserved short numbers like 111, 700s, 9000s
Credential Model: Unique strong SIP credentials per account/device
Role Control: Permissions assigned by role/context, not by number alone
Rollout: Controlled pilot first, full rollout later
Purpose: Manage SIP identities, devices, roles, and ownership cleanly at university scale
```