# Feature 18: Backup, Restore & Configuration Export

## Purpose

Backup, Restore & Configuration Export ensures that the LAN-only Asterisk emergency communication system can be recovered quickly if configuration breaks, data is corrupted, the server fails, or an administrator needs to roll back a bad change.

This feature protects the emergency hotline, ERT queue, SIP accounts, SAP ID mappings, dialplan, paging, conference rooms, voicemail, recordings, logs, and access-control rules.

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
Feature 13: SIP Security & Access Control
Feature 14: Device Provisioning & Extension Management
Feature 15: Local Wi-Fi-first Infrastructure Readiness
Feature 16: Local System Health Monitoring
Feature 17: Emergency SOP & Drill Mode
```

## Final Decision

```text
Create a local-first backup, restore, and configuration export process for the Asterisk emergency system.

Backups must cover:
- Asterisk configuration
- SIP accounts
- SAP ID mappings
- Fixed device mappings
- Dialplan
- Queues
- Voicemail
- Prompts
- Recordings
- Logs
- Health monitoring configuration
- Emergency directory exports
```

## Core Principle

The emergency communication system must be restorable.

A broken configuration should not permanently break:

```text
111 emergency hotline
ERT emergency queue
Fallback and escalation
Emergency voicemail
Call recording
Student-to-student calling
SAP ID-based SIP accounts
Paging
Incident command conference rooms
Transfer/dispatch workflows
Access-control restrictions
Health monitoring
Drill/test mode
```

## Backup Scope

## 1. Asterisk Configuration Backup

The system must back up all Asterisk configuration files required to rebuild the PBX.

Included:

```text
pjsip.conf
extensions.conf
queues.conf
voicemail.conf
confbridge.conf
features.conf
rtp.conf
logger.conf if customized
modules.conf if customized
Other custom Asterisk config files
```

Any file required for emergency routing, SIP registration, queue behavior, conference rooms, voicemail, or paging should be included.

## 2. SIP Account and Identity Backup

Because human SIP extensions use SAP ID, the backup must preserve identity mappings.

Included:

```text
SAP ID extension mappings
Display names
User roles
Dialplan contexts
SIP usernames
SIP credential data or hashes/secrets if stored
Account status
Student/staff/ERT role mapping
Fixed device extension mappings
Caller ID names
```

Identity model:

```text
Human users → SAP ID extensions
Fixed devices → fixed-device extensions
Service features → reserved short numbers
```

## 3. Emergency Dialplan Backup

The emergency dialplan is the heart of the system.

Back up logic for:

```text
111 emergency hotline
199 drill/test line
ERT queue routing
Fallback/escalation flow
Emergency voicemail fallback
700–705 paging codes
9000–9004 conference rooms
Warm transfer/dispatch rules
Three-way bridge support
Access-control restrictions
Student-to-student calling rules
```

## 4. Queue Configuration Backup

Back up the ERT queue configuration.

Included:

```text
ERT queue members
Queue strategy
Timeout values
Queue announcements
Pause/unpause behavior
Escalation target logic
Queue access rules
```

If the queue configuration is lost, the emergency number may not reach responders.

## 5. Audio Prompt Backup

Back up all emergency audio prompts.

Included:

```text
Emergency voicemail prompt
Queue hold prompt
Drill/test prompt
Paging test prompt if used
Any future pre-recorded emergency messages
```

Even if Phase 1 mostly uses live voice, voicemail and test prompts are important.

## 6. Recordings and Voicemail Backup

Emergency audio records should be protected according to university policy.

Included:

```text
Emergency call recordings
Emergency voicemails
Missed emergency voicemail files
Conference recordings if enabled
Paging recordings if enabled
```

Important separation:

```text
Configuration backups → needed for quick restore
Recording/voicemail backups → needed for audit, review, and history
```

## 7. Logs and Metadata Backup

Back up operational and security logs.

Included:

```text
CDR records
CEL records
Queue logs
Paging logs
Conference logs
Missed emergency logs
Access-control violation logs
SIP registration logs if stored
Health check logs if stored
```

These logs help with review, debugging, abuse investigation, and post-incident analysis.

## 8. Health Monitoring Configuration Backup

Feature 16 depends on health checks, so monitoring configuration must also be backed up.

Included:

```text
Health check scripts
Monitoring thresholds
Critical device list
ERT queue health rules
Storage thresholds
Local dashboard configuration if used
```

## Backup Types

## 1. Pre-change Backup

Before any production configuration change, take a backup.

```text
Backup first
Apply change
Test
Rollback if broken
```

This is mandatory for changes to:

```text
111 routing
ERT queue
SIP accounts
Dialplan contexts
Paging codes
Conference rooms
Voicemail
Recording paths
Access control
```

## 2. Daily Local Configuration Backup

A daily local backup should capture:

```text
Asterisk configuration
SIP account data
SAP ID mappings
Fixed device mappings
Dialplan
Queue configuration
Voicemail configuration
Prompt files
```

## 3. Weekly Export Backup

Weekly exports should include:

```text
Responder directory
Device list
Role/context mapping
Extension ownership list
Health monitoring config
Relevant logs
```

## 4. Policy-based Recording Backup

Emergency recordings and voicemails should follow a university-approved retention policy.

The feature does not define the final retention period. That should be decided separately by policy.

## Backup Storage

The backup model is local-first.

Recommended storage:

```text
Primary: local backup folder or second disk on Asterisk server
Better: separate LAN machine or local NAS
Emergency copy: encrypted offline USB/local copy held by authorized admin
```

No cloud dependency is required.

## Backup Security

Backups are sensitive because they may contain:

```text
SIP credentials
SAP ID mappings
User identity data
Emergency call recordings
Emergency voicemails
Call logs
Access-control logs
```

Allowed access:

```text
IT admin
Emergency system administrator
Authorized university technical owner
```

Not allowed:

```text
Students
General staff
Normal ERT users
Unauthenticated users
```

## Encryption Rule

Backups containing credentials, recordings, voicemail, or sensitive logs should be encrypted.

```text
Config-only backup: restricted access required
Credential/recording backup: restricted access + encryption required
```

## Versioning

Asterisk configuration should be versioned.

Recommended approach:

```text
LAN-local Git repository
Config snapshots
Change notes
Rollback tags
Release/version labels
```

Example versions:

```text
v1.0 - Initial 111 emergency hotline
v1.1 - Added ERT queue
v1.2 - Added fallback escalation
v1.3 - Added paging restrictions
v1.4 - Added SAP ID-based user accounts
```

## Change Control

Every production change should record:

```text
What changed
Who changed it
When it changed
Why it changed
Backup taken before change
Test result after change
Rollback plan
```

This keeps emergency configuration changes controlled and auditable.

## Restore Requirements

A backup is not valid unless restore has been tested.

The restore plan must answer:

```text
Where is the backup?
Who can restore it?
How long does restore take?
Which files are restored?
How do we verify the system after restore?
```

## Minimum Restore Test

After restoring, verify:

```text
Asterisk starts
SIP users can register
Student-to-student calling works
111 reaches ERT queue
Emergency recording works
Emergency voicemail works
Paging access rules work
9000 conference works
Unauthorized paging is blocked
Unauthorized conference access is blocked
Health monitoring reports correctly
```

## Phase 1 Scope

Phase 1 includes:

```text
Config backup script
Pre-change backup rule
Daily local config backup
SIP account/export backup
SAP ID mapping backup
Fixed device mapping backup
Responder directory export
Emergency prompt backup
Basic log backup
Restore checklist
Manual restore test after major changes
Restricted backup access
Encrypted backup for sensitive data
```

## Later Phase

Later improvements may include:

```text
Full backup dashboard
Automated encrypted backup rotation
Restore button
Scheduled restore simulation
NAS replication
Immutable backups
Detailed audit trail
Automated config validation before reload
```

These are not required for the first working deployment.

## Suggested Backup Schedule

```text
Before every config change:
Take immediate backup snapshot.

Daily:
Back up active configuration and SIP account data.

Weekly:
Back up logs, directory exports, device lists, and role mappings.

Policy-based:
Retain/back up emergency recordings and voicemails according to university policy.
```

## Rejected Designs

```text
Rejected: Edit production config with no backup
Reason: A bad change can break the emergency system.
```

```text
Rejected: Keep the only backup on the same disk
Reason: If the disk fails, original and backup are both lost.
```

```text
Rejected: Store emergency recordings in unsecured folders
Reason: Emergency recordings are sensitive.
```

```text
Rejected: Assume backup works without restore testing
Reason: Untested backups may fail during actual recovery.
```

```text
Rejected: Restore user mappings without preserving SAP ID ownership history
Reason: Call logs and identity history must remain accurate.
```

## Asterisk Components Covered

```text
Asterisk config files
PJSIP endpoint/auth/AOR config
Dialplan contexts
Queue config
Voicemail config
ConfBridge config
Feature codes
Audio prompts
CDR/CEL logs
Queue logs
Recording folders
Voicemail folders
Paging/conference logs
Health monitoring scripts/config
```

## Final Locked Design

```text
Feature Name: Backup, Restore & Configuration Export
Status: Approved
Phase: Phase 1
Backup Model: Local-first
Cloud Dependency: None
Sensitive Data: Restricted and encrypted where required
Restore Testing: Required
Pre-change Backup: Mandatory
Purpose: Ensure the LAN-only emergency communication system can recover quickly from misconfiguration, data loss, or server failure
```