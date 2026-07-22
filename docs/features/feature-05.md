# Feature 5: Ready-made SIP Client Deployment

## Purpose

This feature defines how students, staff, and emergency responders will place and receive internal emergency calls without requiring a custom-built calling app in Phase 1.

The goal is to make the disaster-response voice system usable quickly using existing SIP clients that can connect to the university Asterisk server.

## Final Decision

```text
Use ready-made SIP softphone apps and SIP IP phones in Phase 1.
Do not build a custom web or mobile calling app in Phase 1.
```

## Reasoning

Building a custom calling app is useful later, but it is not required for the first working version.

The core emergency system can work with:

```text
Asterisk server
SIP extensions
Ready-made SIP apps
ERT queue
Call recording
Incident logging
Escalation flow
```

This reduces engineering complexity and lets the university test the emergency workflow earlier.

## Phase 1 Calling Model

Each authorized user/device receives a SIP extension.

Example:

```text
Extension: 315
SIP Server: asterisk.university.local
Username: 315
Password: ********
```

The user opens a SIP app and dials:

```text
111
```

Asterisk receives the call and routes it into the ERT Emergency Queue.

## Recommended Client Options

For Phase 1, the system can support commonly available SIP clients.

```text
Android/iOS: Linphone or Zoiper
Windows: MicroSIP or Linphone
macOS/Linux: Linphone or Zoiper
Control room desks: Physical SIP IP phones
```

Linphone is a SIP-compatible softphone, MicroSIP is a Windows SIP softphone that can connect to a PBX, and Zoiper supports VoIP softphone use across desktop and mobile platforms.

## Asterisk Configuration Model

Asterisk will manage users/devices as SIP endpoints.

Each device will map to an Asterisk PJSIP configuration set:

```text
Endpoint
Authentication
Address of Record
Dialplan extension
```

Asterisk’s PJSIP configuration is organized using sections such as endpoint, auth, and related objects in `pjsip.conf`.

## Example Extension Plan

```text
111  Campus Emergency Hotline

201  ERT Desk 1
202  ERT Desk 2
203  ERT Desk 3
204  ERT Lead

301  Hostel A Warden Office
302  Hostel B Warden Office
315  Student/Staff Device Example
```

## User Experience

The caller experience is simple:

```text
Open SIP app
Dial 111
Call connects to ERT queue
Talk to emergency responder
```

The ERT experience is:

```text
SIP phone/app rings
ERT member answers
Asterisk records/logs the call
Incident record is created
```

## Required Setup

The university needs:

```text
Asterisk server on LAN
SIP accounts/extensions
SIP client installation guide
Preconfigured QR/config files if possible
ERT desk devices
Campus LAN/Wi-Fi reachability
Basic user training
```

## Deployment Strategy

The rollout should happen in stages.

### Stage 1: ERT-only

Install SIP clients/IP phones for:

```text
ERT Desk 1
ERT Desk 2
ERT Lead
Security Control Room
Medical Room
```

Purpose: prove that **111 → ERT Queue** works.

### Stage 2: Critical Campus Points

Deploy SIP clients or IP phones at:

```text
Hostel warden offices
Admin block
Library desk
Labs
Security gates
Medical room
Department offices
```

Purpose: ensure emergency calling works from important fixed locations.

### Stage 3: Selected Staff/Volunteers

Give SIP accounts to:

```text
Faculty coordinators
Hostel wardens
Security supervisors
Emergency volunteers
IT support team
```

Purpose: expand coverage without forcing every student to install anything immediately.

### Stage 4: Wider Campus Rollout

Optionally allow students to install SIP clients and register with controlled permissions.

Purpose: increase reach, but only after security and support processes are stable.

## Security Rules

The SIP system should be restricted.

```text
Only campus LAN/Wi-Fi access
Strong SIP passwords
No guest SIP access
No public internet exposure in Phase 1
Firewall restricts SIP/RTP to campus network
Separate emergency SIP network/VLAN if possible
Device-level account control
```

## Permissions

Not every extension needs the same permissions.

Recommended model:

```text
Student/staff extensions:
Can call 111 only, or limited internal numbers

ERT extensions:
Can receive emergency calls
Can call internal emergency contacts
Can transfer calls

Admin/lead extensions:
Can access escalation and management functions
```

This prevents misuse and keeps the system focused.

## What We Still Get Without a Custom App

Even without a custom web/mobile app, the system still supports:

```text
Dial 111
ERT queue
Fallback escalation
Emergency voicemail
Call recording
Incident logging
Missed call tracking
Internal LAN-based voice calling
```

## What We Do Not Get Yet

Without the custom app, Phase 1 will not have:

```text
Custom branded Call 111 button
Automatic rich caller profile from app login
Automatic GPS/location from app
ERT browser popup from custom app
One-click browser calling
Native mobile emergency interface
```

These are useful but not required for the first deployment.

## Future Upgrade

The custom app should be moved to a later phase.

```text
Future Feature: Custom Disaster Response Web Calling App
Status: Later Phase / Optional Upgrade
```

That future feature can add:

```text
Browser-based WebRTC calling
ERT dashboard popup
Logged-in caller context
Location-aware emergency calling
One-tap emergency button
Custom branded interface
```

## Rejected Phase 1 Design

```text
Rejected: Build custom web/mobile calling app before testing SIP-based emergency calling
```

Reason:

```text
It delays the core disaster-response system and adds unnecessary early complexity.
```

## Final Locked Design

```text
Feature Name: Ready-made SIP Client Deployment
Status: Approved
Phase: Phase 1
Calling Method: SIP softphone apps and SIP IP phones
Telephony Engine: Asterisk
Emergency Number: 111
Custom Calling App: Not Phase 1
Purpose: Fast deployment of LAN-based emergency calling using proven SIP clients
```
