# Feature 1: Campus Emergency Hotline

## Purpose

The Campus Emergency Hotline provides one internal emergency number for the university during situations where cellular networks, public internet, or normal communication channels may be unavailable.

The system allows any authorized campus user connected to the university LAN, Wi-Fi, or emergency network to reach the Quick Emergency Response Team immediately using Asterisk-based internal calling.

## Emergency Number

```text
111
```

The number **111** will be used as the internal campus emergency hotline.

This number should be clearly communicated across campus as:

```text
Campus Emergency: Dial 111
```

## Primary Receiver

All calls to **111** will be received by the university’s **Quick Emergency Response Team**, also called the **ERT**.

The call will not go directly to individual departments such as security, medical, hostel, or administration.

Instead, the ERT will act as the first human response layer.

## Reasoning

During a real emergency, the caller may be confused, panicked, injured, or unable to decide which department is responsible.

So the system should not expect the caller to choose between departments.

The caller’s only responsibility is:

```text
Dial 111
Explain the emergency
Share location
Stay on the call if possible
```

The ERT will handle triage and decide which team needs to be dispatched.

## Call Flow

```text
User dials 111
        ↓
Asterisk receives the call
        ↓
Asterisk rings the Quick Emergency Response Team
        ↓
First available ERT member answers
        ↓
ERT gathers emergency details
        ↓
ERT dispatches the required internal team
        ↓
Call and incident details are logged
```

## IVR Decision

There will be **no IVR** on the main emergency hotline.

Rejected flow:

```text
Dial 111
Press 1 for fire
Press 2 for medical
Press 3 for security
Press 4 for hostel
```

This is rejected because it adds delay, increases confusion, and can cause wrong routing during high-stress situations.

The emergency hotline must connect the caller to a human as quickly as possible.

## Final IVR Decision

```text
IVR on 111: No
Human pickup: Yes
ERT first response: Yes
```

## Asterisk Features Used

The finalized version of this feature uses the following Asterisk capabilities:

```text
Internal extension dialing
Ring group or queue
Call recording
Missed call logging
Call answer tracking
Fallback escalation if no ERT member answers
```

## Minimum Required Extensions

Example internal extensions:

```text
111  Campus Emergency Hotline

201  ERT Desk 1
202  ERT Desk 2
203  ERT Desk 3
204  ERT Lead
```

When someone dials **111**, Asterisk will ring the ERT members.

## Recommended Routing Logic

```text
When 111 is dialed:

1. Ring active ERT members.
2. First available ERT member answers.
3. Start or continue call recording.
4. Log caller extension, time, answering responder, and duration.
5. If no one answers within a defined timeout, escalate to backup ERT members or senior emergency contacts.
```

## Timeout and Escalation

Recommended timeout:

```text
15–20 seconds
```

If no ERT member answers:

```text
111 → Primary ERT group
        ↓ no answer
Backup ERT group / ERT Lead
        ↓ no answer
Campus senior emergency authority
```

The exact escalation contacts can be finalized later.

## Data to Log

For every call to **111**, the system should log:

```text
Caller extension
Caller device/user if known
Time of call
Answered or missed status
Responder who answered
Call duration
Recording reference
Escalation status
```

## Caller Experience

The caller should experience this:

```text
Dial 111
Hear ringing
ERT member answers
Caller explains issue
ERT handles response
```

No menu. No department selection. No unnecessary steps.

## Final Decision

```text
Feature Name: Campus Emergency Hotline
Status: Approved
Emergency Number: 111
Receiver: Quick Emergency Response Team
IVR: No
Routing: Direct to ERT
Purpose: Fast human emergency response over campus LAN/Wi-Fi
```
