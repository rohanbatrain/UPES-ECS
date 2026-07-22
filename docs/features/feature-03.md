# Feature 3: Emergency Fallback & Escalation Path

## Purpose

The Emergency Fallback & Escalation Path defines what happens when a call to the campus emergency number is not answered by the Quick Emergency Response Team within the allowed response time.

This feature ensures that the emergency hotline does not silently fail.

## Linked Features

```text
Feature 1: Campus Emergency Hotline
Emergency Number: 111
Receiver: Quick Emergency Response Team

Feature 2: ERT Emergency Queue
Asterisk Feature: Queue
```

## Final Decision

```text
If no ERT member answers within 15–20 seconds,
the call must escalate automatically.
```

## Final Call Flow

```text
Caller dials 111
        ↓
Emergency Response Queue
        ↓ no answer in 15–20 seconds
ERT Lead
        ↓ no answer in 15 seconds
Backup Emergency Authority Group
        ↓ no answer in 20 seconds
Emergency Voicemail
        ↓
Critical missed emergency incident logged
```

## Escalation Layer 1: Primary ERT Queue

The first layer remains the finalized ERT Emergency Queue.

```text
111 → Emergency Response Queue
```

Recommended timeout:

```text
15–20 seconds
```

If no active ERT member answers within this time, the call moves to the next escalation layer.

## Escalation Layer 2: ERT Lead

The second layer is the ERT Lead.

Example:

```text
204  ERT Lead
```

The ERT Lead is responsible for taking ownership when the main ERT queue fails to answer.

Recommended timeout:

```text
15 seconds
```

## Escalation Layer 3: Backup Emergency Authority Group

If the ERT Lead also does not answer, the call escalates to a small backup authority group.

This group should contain only people with actual authority to activate emergency response.

Example roles:

```text
Chief Warden
Security Head
Admin Emergency Coordinator
Campus Operations Head
```

This should not be a random department ring list.

Recommended timeout:

```text
20 seconds
```

## Final Fallback: Emergency Voicemail

If nobody answers even after escalation, the call should not disconnect silently.

The caller should hear:

```text
No responder is currently available.
Please state your name, location, and emergency after the tone.
```

The system then records the message.

## Critical Missed Emergency Log

After emergency voicemail, the system must create a critical missed emergency event.

The log should include:

```text
Caller extension
Caller device/user if known
Time of call
Queue attempt status
ERT Lead attempt status
Backup group attempt status
Voicemail recording reference
Final status: Unanswered emergency
Severity: Critical
```

## Rejected Designs

The following designs are rejected:

```text
111 rings forever
```

Reason:

```text
No accountability and no clear failure state.
```

```text
111 forwards randomly to departments
```

Reason:

```text
Creates confusion and poor emergency ownership.
```

```text
Mobile phone fallback as the main fallback path
```

Reason:

```text
The system is meant to remain useful when cellular networks may be unavailable.
```

## Asterisk Features Used

```text
Queue timeout
Dial fallback
Escalation routing
Voicemail
Call recording
Missed call logging
Critical event tagging
```

## Final Locked Design

```text
Feature Name: Emergency Fallback & Escalation Path
Status: Approved
Primary Number: 111
Primary Receiver: ERT Emergency Queue
Queue Timeout: 15–20 seconds
Escalation 1: ERT Lead
ERT Lead Timeout: 15 seconds
Escalation 2: Backup Emergency Authority Group
Backup Timeout: 20 seconds
Final Fallback: Emergency Voicemail
Final Log Severity: Critical
```