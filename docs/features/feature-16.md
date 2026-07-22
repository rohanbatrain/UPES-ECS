# Feature 16: Local System Health Monitoring

## Purpose

Local System Health Monitoring defines how the university verifies that the LAN-only Asterisk emergency communication system is actually working before it is needed.

This feature ensures that the system does not silently fail because of SIP registration issues, ERT queue problems, recording failures, voicemail failures, Wi-Fi issues, or critical device outages.

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
```

## Final Decision

```text
Add LAN-only system health monitoring for Asterisk, SIP clients, ERT queue, mobile Wi-Fi calling, fixed devices, recording, voicemail, storage, paging, and conference readiness.
```

This feature is required before calling the system production-ready.

## Core Principle

The emergency communication system should not be trusted only because it was configured once.

It must be possible to check:

```text
Can users call 111 right now?
Can ERT receive emergency calls right now?
Are mobile SIP clients registering over Wi-Fi?
Are critical ERT/fixed devices online?
Are recordings working?
Is voicemail working?
Is local storage available?
Are paging and conference features usable?
```

## Monitoring Scope

The system should monitor:

```text
Asterisk server status
SIP registrations
ERT queue health
Mobile SIP client readiness
Fixed IP phone/device health
Emergency number 111 test flow
Emergency call recording
Emergency voicemail
Local storage
Network reachability
Paging readiness
Conference room readiness
Access-control failures
Restricted feature attempts
```

## LAN-only Monitoring Rule

Monitoring must remain inside the LAN boundary.

Allowed:

```text
Local dashboard
Local admin page
Asterisk CLI
Local scripts
Local logs
Control room display
LAN-only monitoring service
```

Out of scope:

```text
Cloud monitoring
SMS alerts
WhatsApp alerts
Telegram alerts
Email alerts
External push notifications
Remote public dashboard
```

## 1. Asterisk Service Monitoring

The system should verify whether Asterisk is running.

Monitor:

```text
Asterisk service status
Asterisk uptime
Last restart time
Asterisk version
Basic call-processing availability
```

Critical condition:

```text
Asterisk down = emergency voice system down.
```

## 2. SIP Registration Monitoring

The system should track whether important users and devices are registered.

Monitor groups:

```text
ERT members
ERT Lead
Control room devices
Security phones
Medical phones
Warden phones
Operations/IT emergency devices
Selected student pilot users
Fixed devices
IP speakers / paging devices if used
```

Example status:

```text
ERT Desk 1: Registered
ERT Lead: Registered
Medical Room: Registered
Security Room: Offline
Student pilot users: 18/25 registered
```

Because the system is mobile-first, SIP registration reliability over Wi-Fi is important.

## 3. ERT Queue Health

The emergency queue must be continuously checkable.

Monitor:

```text
Number of ERT agents registered
Number of ERT agents available
Number of ERT agents busy
Number of ERT agents paused
Number of ERT agents offline
Current waiting calls
Missed queue calls
Average answer time if available
```

Critical condition:

```text
ERT queue has zero available responders.
```

This must be visible locally.

## 4. Emergency Number 111 Test

The system should support a controlled test of the emergency call path.

Test flow:

```text
Test user calls 111
        ↓
Call enters ERT queue
        ↓
ERT test device rings
        ↓
Call is answered
        ↓
Recording is created
        ↓
Call log is generated
```

The test must be planned so it does not create panic or confusion.

## 5. Emergency Recording Health

Since Feature 4 requires emergency call recording, monitoring must verify that recording works.

Check:

```text
Recording directory exists
Recording directory is writable
Latest emergency test call produced a recording
Recording file is linked to call/incident metadata
Recording storage is not full
```

Critical condition:

```text
111 call completes but recording fails.
```

## 6. Emergency Voicemail Health

Since missed emergency calls go to voicemail, voicemail must be monitored.

Check:

```text
Emergency voicemail prompt exists
Voicemail storage is writable
Emergency voicemail can be recorded
Voicemail file can be retrieved
Pending missed emergency voicemail count
```

Critical condition:

```text
Emergency voicemail cannot record.
```

## 7. Local Storage Health

The Asterisk server must have enough local storage for emergency data.

Monitor storage for:

```text
Emergency call recordings
Emergency voicemail
CDR/CEL logs
Queue logs
Conference recordings if enabled
Paging logs
Missed emergency call records
```

Recommended thresholds:

```text
Warning: 75% disk used
Critical: 90% disk used
```

Critical condition:

```text
Disk full or nearly full.
```

The system should not silently lose recordings, voicemails, or logs because storage is full.

## 8. Network Reachability Health

Because the system is LAN-only, the local network path must be tested.

Check reachability from:

```text
Wi-Fi network to Asterisk
ERT/control room network to Asterisk
Fixed device network to Asterisk
Critical AP/router/switch path
```

Minimum checks:

```text
Mobile phone can reach Asterisk IP/domain
SIP app can register
SIP signaling works
RTP audio works both ways
```

## 9. Mobile Wi-Fi SIP Readiness

Because mobile phones are the primary client, monitoring/testing must include mobile behavior.

Check:

```text
SIP app registration over Wi-Fi
Mobile call to 111
Mobile call to another SAP ID
Two-way audio
Call behavior when screen locks
Reconnect behavior after Wi-Fi reconnect
Registration stability
Mic permission behavior
```

This may not be fully automated in Phase 1, but it must be part of the readiness process.

## 10. Fixed IP Phone and Critical Device Health

Although mobile phones are primary for users, fixed IP phones are required for ERT and critical locations.

Monitor:

```text
ERT desk phone registered
Control room phone registered
Medical room phone registered
Security phone registered
Warden phone registered
Operations/IT emergency phone registered
IP speakers or paging devices reachable if deployed
```

Critical condition:

```text
ERT answering device offline.
```

## 11. Paging Health

Since emergency paging is approved, paging must be testable.

Check:

```text
Paging codes exist
Authorized user can use paging
Unauthorized user is blocked
Target devices are reachable
Paging audio works
Paging attempt is logged
```

Paging tests should happen only during planned checks or drills.

## 12. Conference Room Health

Incident command conference rooms must be testable.

Check:

```text
9000 Main Incident Command Room exists
Authorized responder can join
Unauthorized user is blocked
Participant join/leave is logged
Recording works if enabled
```

## 13. Access-control Monitoring

Feature 13 requires access boundaries. Monitoring should capture attempts to violate them.

Log:

```text
Unauthorized paging attempt
Unauthorized conference join attempt
Unauthorized recording access attempt
Unauthorized voicemail access attempt
Restricted number denied
Failed SIP registration
Unknown device registration attempt
```

This helps detect misuse and misconfiguration.

## Recommended Local Dashboard

A simple LAN-only dashboard should eventually show:

```text
System Health

Asterisk: OK
Emergency Number 111: OK
ERT Queue: 3 available, 1 busy, 0 waiting
Recording: OK
Voicemail: OK
Storage: 42% used
Medical Room Phone: OK
Security Phone: Offline
Paging: OK
Conference 9000: OK
Last Test Call: Passed at 10:32
```

The dashboard should be accessible only inside the university LAN.

```text
No public access.
No cloud dependency.
No external alerts required.
```

## Phase 1 Monitoring Implementation

Phase 1 can start simple.

Allowed Phase 1 methods:

```text
Asterisk CLI checks
Local shell scripts
Local status page
Manual readiness checklist
Queue status checks
Registration status checks
Storage checks
Recording/voicemail test calls
Local dashboard if available
```

A polished dashboard is useful, but not required for the first working pilot.

## Daily Readiness Checklist

Before relying on the system, the team should check:

```text
Asterisk is running
ERT queue has available members
ERT device is registered
111 test call works
Emergency recording works
Emergency voicemail works
Storage is not full
Critical fixed phones are registered
Mobile SIP test works over Wi-Fi
```

## Weekly Drill Checklist

During planned drills, test:

```text
Student mobile calls 111
ERT answers
Call recording is verified
Missed-call voicemail is tested
Warm transfer is tested
Three-way bridge is tested
Conference 9000 is tested
Paging is tested from authorized device
Unauthorized paging is blocked
Unauthorized conference access is blocked
```

## Critical Failure Conditions

The following should be treated as serious local health failures:

```text
Asterisk down
ERT queue has zero available responders
111 does not route correctly
Recording fails for 111 calls
Emergency voicemail cannot save messages
Disk usage critical
ERT answering device offline
Mobile SIP clients cannot register over Wi-Fi
One-way audio on SIP calls
Paging authorization broken
Unauthorized users can access paging or conference rooms
```

## What This Feature Does Not Do

This feature does not include:

```text
Cloud monitoring
SMS alerts
WhatsApp alerts
Email alerts
Remote public admin access
External uptime monitoring
Internet-based alerting
```

Those are outside the LAN-only Phase 1 boundary.

## Rejected Designs

```text
Rejected: No health checks
Reason: The system can silently fail before a real emergency.
```

```text
Rejected: Treat Asterisk running as the only health signal
Reason: Asterisk can run while queue, recording, voicemail, or mobile calling is broken.
```

```text
Rejected: Only test fixed desk phones
Reason: Mobile phones over Wi-Fi are the primary client path.
```

```text
Rejected: Require cloud monitoring
Reason: Violates the LAN-only scope.
```

```text
Rejected: Ignore unauthorized access attempts
Reason: Access-control failures can create misuse or panic.
```

## Asterisk Features / Data Used

```text
Asterisk service status
PJSIP endpoint registration status
Queue member status
Queue logs
CDR/CEL records
Voicemail status
Recording file checks
ConfBridge status
Paging dialplan tests
AMI/ARI events if backend/dashboard is used
```

## Final Locked Design

```text
Feature Name: Local System Health Monitoring
Status: Approved
Phase: Phase 1
Scope: LAN-only local monitoring
Primary Focus: Asterisk, mobile Wi-Fi SIP users, ERT queue, recordings, voicemail, storage, paging, conferences, and critical devices
Primary Client Path Monitored: Mobile phone → Wi-Fi → SIP app → Asterisk
External Alerts: Out of scope
Dashboard: Local-only, optional for MVP but recommended
Purpose: Verify that the emergency communication system is actually ready before it is needed
```