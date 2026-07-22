# Feature 19: AI Emergency Assistant Line 101

## Purpose

The AI Emergency Assistant Line 101 provides an AI-first emergency support and triage path for the UPES-ECS disaster-response voice system.

This feature allows callers to describe an emergency, share their location, and receive immediate AI-guided triage while preserving the main emergency number `111` as the direct human-first ERT emergency hotline.

The purpose of this feature is not to replace the Emergency Response Team.

The purpose is to create a safer secondary emergency help line that can collect structured information, identify urgent situations, and escalate callers to the human ERT emergency queue whenever the situation is serious, unclear, or high-risk.

## Final Decision

```text
Keep 111 as the human-first Campus Emergency Hotline.
Create 101 as the AI Emergency Assistant Line.
101 will be AI-first, but it must always escalate to 111 when the caller reports a serious, unclear, or urgent emergency.
111 must never depend on AI.
101 must never become a blocker for real emergency response.
```

## Important Planning Note

`101` is not a replacement for `111`.

The primary real emergency number remains:

```text
111 = Human-first Campus Emergency Hotline
```

The AI assistant number becomes:

```text
101 = AI Emergency Assistant Line
```

The drill/test number remains:

```text
199 = Drill/Test Emergency Flow
```

The internal AI test number can be:

```text
196 = Internal AI Assistant Test Line
```

This means the user-facing emergency instruction should be:

```text
For immediate emergency: Dial 111
For AI emergency help: Dial 101
For test/drill: Dial 199
```

## Core Concept

The disaster-response voice system should have two different emergency paths.

```text
111  Human-first emergency response
101  AI-first emergency assistant and triage
199  Drill/test emergency simulation
```

`111` is the fastest, simplest, most trusted path to ERT.

`101` is an assistant path that can collect details before escalation.

Example structure:

```text
Caller dials 111
        ↓
ERT emergency queue rings immediately
        ↓
ERT answers / escalation / voicemail
```

```text
Caller dials 101
        ↓
AI Emergency Assistant answers
        ↓
AI asks what happened and where
        ↓
AI decides whether the situation is urgent or unclear
        ↓
If urgent or unclear, AI transfers/escalates to 111
        ↓
If non-critical, AI creates an assistance log or routes to an approved support path
```

The AI assistant should always prefer escalation when uncertain.

## Why This Feature Is Needed

During an emergency, callers may panic, speak unclearly, forget important details, or not know which responder group should be contacted.

The AI Emergency Assistant Line helps by collecting the most important information early.

It can ask:

```text
What happened?
Where are you located?
Is anyone injured?
Is there immediate danger?
Are you safe right now?
Can you stay on the line?
```

This can help the ERT receive a cleaner pre-brief when the call is escalated.

It also creates a safer path for uncertain cases where the caller is not sure whether to call the main emergency hotline.

## What 101 Is For

`101` should be used for AI-assisted emergency help and triage.

Included use cases:

```text
Caller is unsure whether the situation is an emergency
Caller wants to describe a situation before being routed
Caller needs help identifying the right emergency path
Caller reports a possible medical/security/hostel/campus issue
Caller needs emergency guidance while being transferred to ERT
Caller needs to create a structured emergency report
Caller needs AI-assisted missed-call or after-hours emergency capture
```

`101` should immediately escalate if there is any sign of danger.

Escalation triggers include:

```text
Medical emergency
Injury
Unconscious person
Violence
Threat
Fire
Smoke
Accident
Security issue
Harassment or unsafe situation
Panic
Hostel emergency
Infrastructure danger
Caller says emergency
Caller asks for human help
AI cannot understand the caller
AI is unsure
```

## What 101 Is Not For

`101` is not a general chatbot.

Not included:

```text
General university queries
Class timetable questions
Fees questions
Admissions queries
Academic support
Casual conversation
Non-emergency helpdesk support unless explicitly routed later
Replacing human emergency responders
```

If the university later wants a general campus helpdesk bot, that should be a separate feature and a separate number.

## Call Flow: 111 Human-first Emergency Line

`111` remains unchanged.

```text
1. Caller dials 111.
2. Asterisk creates an emergency call flow.
3. ERT emergency queue rings immediately.
4. Emergency call recording starts.
5. ERT answers the call.
6. If ERT does not answer, escalation starts.
7. If escalation fails, emergency voicemail is created.
8. Missed emergency incident is marked critical.
```

No AI should be required for this path.

If the AI system is completely down, `111` must still work.

## Call Flow: 101 AI Emergency Assistant Line

`101` follows an AI-first flow.

```text
1. Caller dials 101.
2. AI answers clearly as the UPES-ECS AI Emergency Assistant.
3. AI tells the caller that immediate emergencies should be escalated to 111.
4. AI asks for location, issue, danger/injury status, and callback availability.
5. AI creates a structured summary.
6. If urgent, unclear, or high-risk, AI transfers/escalates to 111.
7. If non-critical, AI creates an assistance log or routes to an approved support extension.
8. All escalated 101 calls link to an incident record.
9. AI failure falls back to 111.
```

Recommended opening prompt:

```text
You have reached the UPES-ECS AI Emergency Assistant.
If this is an immediate emergency, say emergency or dial 111 at any time.
Please tell me what happened and where you are located.
```

Recommended escalation prompt:

```text
This sounds urgent. I am connecting you to UPES Emergency Response now.
Please stay on the line.
```

Recommended failure prompt:

```text
The AI Emergency Assistant is currently unavailable.
Connecting you to UPES Emergency Response now.
```

## AI Triage Questions

The AI assistant should ask only short and necessary questions.

Mandatory questions:

```text
What happened?
Where are you located?
Is anyone injured or in danger?
Are you safe right now?
Can you stay on the line?
What is your name or SAP ID?
```

Optional questions:

```text
How many people are involved?
Is the situation still ongoing?
Do you need medical help?
Do you need security help?
Is there fire, smoke, electricity, water, or infrastructure danger?
Is there a nearby landmark?
```

The AI should not over-question the caller.

If the call sounds serious, the AI should escalate quickly.

## AI Output / Pre-brief

When the AI escalates a call to ERT, it should generate a simple pre-brief.

Example:

```text
AI Pre-brief
Caller: Name / SAP ID if available
Location: Hostel A, near main gate
Category: Medical
Urgency Hint: High
Summary: Caller reports a student fainted and is not responding.
Caller Status: Caller can stay on line
Recommended Path: ERT + Medical Room
```

The pre-brief is only an aid.

ERT makes the final decision.

## Incident Logging

Escalated 101 calls should create or attach to an incident record.

Recommended fields:

```text
incident_id
source_number = 101
ai_triage_enabled = true
caller_sap_id
caller_name
caller_extension
caller_ip_or_device
ai_detected_location
ai_detected_category
ai_urgency_hint
ai_summary
ai_questions_completed
action_taken
transferred_to_111 = true/false
transfer_time
human_responder_answered = true/false
recording_path
final_status
human_override = true/false
```

The AI summary should be editable or correctable by ERT.

## Access Model

The access model should keep the AI assistant controlled.

```text
Students:
Can call 101.
Can be transferred from 101 to 111.
Cannot directly control AI routing.
Cannot access AI logs, summaries, recordings, or transcripts.

Staff:
Can call 101.
Can be transferred from 101 to 111.
Cannot access AI logs unless assigned an emergency role.

ERT:
Can receive escalated 101 calls.
Can view AI pre-briefs.
Can override AI summary and category.
Can mark AI output as incorrect.

ERT Lead / Incident Commander:
Can review AI-assisted emergency incidents.
Can approve AI prompt changes.
Can approve AI routing rules.
Can disable 101 AI mode if unsafe.

IT / UPES-ECS Admin:
Can manage AI service configuration.
Can monitor health checks.
Can restart or disable the AI service.
Cannot change emergency SOP without approval.
```

## Safety Model

The AI assistant must follow strict emergency-safety rules.

```text
AI can collect information.
AI can summarize.
AI can route to approved emergency destinations.
AI can escalate to 111.
AI can create assistance logs.
AI can support drill/testing.

AI cannot replace ERT.
AI cannot delay 111.
AI cannot reject an emergency.
AI cannot mark a call as false alarm.
AI cannot close an incident.
AI cannot suppress escalation.
AI cannot page all campus directly.
AI cannot give medical diagnosis.
AI cannot give risky physical instructions.
AI cannot call unauthorized users.
AI cannot access unrelated student data.
```

Golden rule:

```text
If AI is unsure, escalate to 111.
```

## Failure Handling

The AI assistant must never become a single point of failure.

Required fallback behavior:

```text
If AI service is down:
Transfer 101 to 111.

If AI takes too long:
Transfer 101 to 111.

If speech recognition fails:
Transfer 101 to 111.

If caller says emergency:
Transfer 101 to 111.

If caller asks for human:
Transfer 101 to 111.

If AI cannot classify the situation:
Transfer 101 to 111.

If transfer fails:
Create critical missed AI emergency record and alert ERT/control room.
```

`111` must continue working even if every AI component is offline.

## Directory / Numbering Impact

The numbering plan should reserve `101` for the AI Emergency Assistant Line.

Updated emergency numbering:

```text
111   Campus Emergency Hotline / Human-first ERT line
101   AI Emergency Assistant Line
196   Internal AI assistant test line
198   Echo/audio test line, optional
199   Drill/Test Emergency Flow
```

Previous idea to use `101` as an alias to `111` is rejected.

`101` now has its own dedicated function.

## Scope

Included in this feature:

```text
AI-first emergency assistant line on 101
Basic caller triage
Location and emergency-type collection
Urgency hint generation
AI summary / ERT pre-brief
Escalation to 111
Fallback to 111 if AI fails
AI-assisted drill testing
AI health checks
AI incident logging
```

Not included in Phase 1:

```text
AI replacing ERT
AI making final emergency decisions
AI closing incidents
AI making campus-wide announcements
AI directly accessing all student records
AI-based surveillance
AI-only emergency response
AI on the primary 111 line
Full public helpdesk chatbot
```

## Phase Plan

This feature should not be mandatory for the first UPES-ECS emergency go-live.

Recommended rollout:

```text
Phase 1:
Build and prove 111 human-first emergency calling without AI.

Phase 1.5:
Deploy 101 in test mode for ERT/internal users.
Use 196 for internal AI testing.
Use 199 for drill integration.

Phase 2:
Allow students/staff to call 101 after successful testing.
101 can escalate urgent/unclear cases to 111.

Phase 3:
Add better routing, dashboard summaries, analytics, and approved integrations.
```

## Deployment Model

The AI assistant should run inside the campus environment wherever possible.

Recommended approach:

```text
Asterisk PBX
        ↓
AI voice-agent service
        ↓
Local or approved STT/LLM/TTS pipeline
        ↓
Incident logging / AI summary output
        ↓
Transfer/escalation back to Asterisk emergency queue
```

Preferred privacy posture:

```text
Keep emergency audio local/on-campus unless UPES explicitly approves cloud AI processing.
```

## Health Checks

The health monitoring system should check AI readiness separately from the main emergency line.

Required checks:

```text
AI engine running
AI agent reachable from Asterisk
101 test call works
196 internal AI test works
STT working
TTS working
LLM/local model working
Transfer from 101 to 111 works
AI fallback to 111 works
AI response time acceptable
AI logs being written
AI summary generation working
```

Failure severity:

```text
111 failure = Critical
101 AI failure = Warning or Degraded if 111 still works
101 unable to transfer to 111 = Critical for AI feature
```

## Prompts

Main 101 prompt:

```text
You have reached the UPES-ECS AI Emergency Assistant.
If this is an immediate emergency, say emergency or dial 111 at any time.
Please tell me what happened and where you are located.
```

Escalation prompt:

```text
This sounds urgent. I am connecting you to UPES Emergency Response now.
Please stay on the line.
```

Non-critical closure prompt:

```text
I have recorded your request and will route it to the appropriate support path if available.
If this becomes urgent, dial 111 immediately.
```

Failure prompt:

```text
The AI Emergency Assistant is currently unavailable.
Connecting you to UPES Emergency Response now.
```

Drill prompt:

```text
This is a UPES-ECS AI emergency drill.
No real emergency response will be dispatched unless the drill controller approves it.
```

## Rejected Designs

```text
Rejected: Put AI directly in front of 111
Reason: The primary emergency line must remain human-first and should not depend on AI availability or AI correctness.
```

```text
Rejected: Use 101 as a simple alias to 111
Reason: 101 is now reserved for the AI Emergency Assistant Line.
```

```text
Rejected: Allow AI to decide that a call is not an emergency
Reason: AI may misunderstand the caller. If uncertain, it must escalate.
```

```text
Rejected: Allow AI to close incidents
Reason: Incident closure must remain a human ERT/admin responsibility.
```

```text
Rejected: Allow AI to page all campus directly
Reason: Paging can create panic and must require ERT Lead or Incident Commander approval.
```

```text
Rejected: Make 101 mandatory for emergency response
Reason: 101 is an assistant path only. 111 remains the official emergency path.
```

```text
Rejected: Depend on cloud AI by default
Reason: Emergency audio and incident details are sensitive. Local/on-campus processing is preferred unless officially approved.
```

## Asterisk Features Used

```text
Internal extension 101
Internal extension 196 for testing
Dialplan contexts
PJSIP endpoints
ARI / Stasis integration if using an AI voice-agent service
AudioSocket or RTP-based media integration if supported by implementation
Queue transfer to 111 / ERT emergency queue
Caller ID labels
Call recording
Incident log hooks
Fallback routing
Permission-based contexts
Health-check test calls
```

## Implementation Technology Note

An Asterisk-compatible AI voice-agent project can be used as the implementation base if it satisfies the UPES-ECS safety, privacy, and fallback requirements.

The selected implementation must support:

```text
Asterisk integration
AI call handling
STT / LLM / TTS pipeline
Transfer to approved extensions or queues
Local or approved deployment mode
Health monitoring
Logging
Safe fallback to 111
```

The implementation is replaceable.

The locked feature is the emergency design, not a permanent dependency on one specific AI project.

## Final Locked Design

```text
Feature Name: AI Emergency Assistant Line 101
Status: Approved for UPES-ECS feature backlog
Phase: Phase 1.5 / Phase 2
Primary Emergency Line: 111
AI Assistant Line: 101
Internal AI Test Line: 196
Drill/Test Line: 199
111 Behavior: Human-first, no AI dependency
101 Behavior: AI-first, escalate to 111 when urgent or unclear
AI Authority: Assistant only
ERT Authority: Final decision-maker
Fallback Rule: AI failure transfers to 111
Safety Rule: If AI is unsure, escalate to 111
Purpose: Provide AI-assisted emergency triage without weakening the main human emergency line
```
