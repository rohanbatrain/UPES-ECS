# Feature 2: ERT Emergency Queue

## Purpose

The ERT Emergency Queue defines how calls to the campus emergency number are received by the Quick Emergency Response Team.

This feature ensures that emergency calls are handled in a controlled, trackable, and reliable way instead of simply ringing random phones.

## Linked Feature

This feature depends on the finalized Campus Emergency Hotline.

```text
Feature 1: Campus Emergency Hotline
Emergency Number: 111
Receiver: Quick Emergency Response Team
```

## Final Decision

```text
Use an Asterisk Queue for emergency calls.
Do not use a basic ring group as the primary receiving model.
```

## Reasoning

A ring group is simple, but it is not ideal for disaster response because it does not properly manage responder availability, simultaneous calls, call distribution, missed calls, or accountability.

An emergency queue is better because it supports:

```text
Responder availability
Multiple simultaneous emergency calls
Call answer tracking
Missed call tracking
Escalation
Queue statistics
Operational accountability
```

## Call Flow

```text
Caller dials 111
        ↓
Asterisk receives the call
        ↓
Call enters the Emergency Response Queue
        ↓
Asterisk rings available ERT agents
        ↓
First available ERT agent answers
        ↓
Call is recorded and logged
        ↓
ERT handles triage and dispatch
```

## ERT Queue Members

Example queue agents:

```text
201  ERT Desk 1
202  ERT Desk 2
203  ERT Desk 3
204  ERT Lead
```

These members are not random departments. They are trained emergency response contacts.

## Agent States

ERT members can have operational states such as:

```text
Available
Busy
Offline
Paused
On another emergency call
```

The queue should prefer available responders and avoid repeatedly sending calls to unavailable agents.

## Queue Behavior

When a user dials **111**:

```text
1. Call enters the emergency queue.
2. Available ERT agents are called.
3. First available responder answers.
4. If no one answers within the timeout, escalation starts.
5. If all responders are busy, the caller hears a short emergency hold message.
```

## Maximum Wait Time

Emergency callers should not wait for a long time.

Recommended maximum waiting time before escalation:

```text
15–20 seconds
```

After this, the call should move to the fallback/escalation path.

## Hold Message

If the caller has to wait briefly, the system should play a short message:

```text
Campus emergency line. Please stay on the call. A responder will answer shortly.
```

## Rejected Design

The following design is rejected:

```text
111 → Ring all ERT phones together as a basic ring group
```

Reason for rejection:

```text
Weak tracking
Poor simultaneous call handling
No proper agent availability
Less operational accountability
Harder disaster-response management
```

## Asterisk Feature Used

```text
Asterisk Queue
```

## Final Locked Design

```text
Feature Name: ERT Emergency Queue
Status: Approved
Asterisk Feature: Queue
Main Emergency Number: 111
Receiver: Quick Emergency Response Team
Fallback Timeout: 15–20 seconds
Ring Group: Rejected as primary model
Purpose: Controlled emergency call handling with tracking and escalation
```
