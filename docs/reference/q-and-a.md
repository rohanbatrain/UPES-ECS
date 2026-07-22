# Asterisk LAN-only University Emergency System — Decision Questionnaire

## Purpose

This document lists every naming decision, operational decision, technical decision, permission decision, and policy decision required to finalize the Phase 1 system design.

The system currently has 18 locked features:

1. Campus Emergency Hotline
    
2. ERT Emergency Queue
    
3. Emergency Fallback & Escalation Path
    
4. Emergency Call Recording & Incident Logging
    
5. Ready-made SIP Client Deployment
    
6. Emergency Announcement & Paging
    
7. Incident Command Conference Rooms
    
8. Emergency Responder Directory & Numbering Plan
    
9. Responder Status & Availability
    
10. Emergency Voicemail & Missed-call Recovery
    
11. Emergency Call Transfer & Dispatch Workflow
    
12. LAN-only Infrastructure Boundary
    
13. SIP Security & Access Control
    
14. Device Provisioning & Extension Management
    
15. Local Wi-Fi-first Infrastructure Readiness
    
16. Local System Health Monitoring
    
17. Emergency SOP & Drill Mode
    
18. Backup, Restore & Configuration Export
    

---

# Global System Decisions

## A. Project Naming

1. What is the final name of this emergency communication system?
     UPES-ECS
2. Should the name sound official, technical, university-branded, or disaster-response-focused?
    official
3. What short name/acronym should be used internally?
    UPES-ECS
4. What name should appear in SOP documents?
    UPES-ECS
5. What name should appear in student instructions?
    UPES-ECS
6. What name should appear on SIP caller ID or app configuration guides?
    UPES-ECS
7. Should the system be branded under the university name or as a standalone emergency platform?
    UPES-ECS

## B. Core Terminology

1. What will the emergency response team be called?
    
    - Emergency Response Team

2. What short form should be used?
    
    - ERT
        
3. What should the control room be called?
    UPES-ERT-ROOM
4. What should the main emergency operator role be called?
    
5. What should the emergency lead role be called?
    
6. What should student users be called in documentation?
    
7. What should fixed phones/devices be called?
    
8. What should internal SIP accounts be called?
    
9. What should missed emergency records be called?
    
10. What should test/drill calls be called?
    

## C. Network Naming

1. What local domain should SIP clients use?
    
    - `asterisk.local`
        
    - `asterisk.university.lan`
        
    - `pbx.university.lan`
        
    - Direct IP only
        
    - Other?
        
2. What should the Asterisk server hostname be?
    
3. What should the SIP realm/domain be?
    
4. What should the local monitoring dashboard be called?
    
5. What should the local admin panel be called?
    
6. What Wi-Fi SSID will users connect from?
    
7. Will SIP clients use the normal campus Wi-Fi or a separate emergency/campus voice Wi-Fi?
    
8. Is client isolation enabled on the Wi-Fi network?
    
9. Will client isolation need to be disabled or bypassed for SIP access?
    
10. What LAN subnet is Asterisk on?
    
11. Which subnets are allowed to register to Asterisk?
    

## D. Identity Model

1. Confirm: Should SAP ID be the SIP extension for every human user?
    
2. Confirm: Should SIP username also be SAP ID?
    
3. Should display name include both name and SAP ID?
    
4. What exact caller ID format should be used?
    
    - `Name - SAP ID`
        
    - `SAP ID - Name`
        
    - `Name`
        
    - `SAP ID`
        
5. Should students be able to search a directory or only dial SAP IDs manually?
    
6. Should fixed devices use separate extensions instead of SAP IDs?
    
7. What fixed-device extension range should be reserved?
    
8. What service-code ranges should be reserved?
    
9. Should staff/faculty also use SAP ID as SIP extension?
    
10. Should ERT members use their personal SAP ID or dedicated ERT role extensions?
    
11. Should ERT desk phones have fixed device extensions in addition to ERT members’ SAP IDs?
    

---

# Feature 1: Campus Emergency Hotline

## Naming Decisions

1. What should this feature be officially called?
    
2. What should students see in posters/instructions?
    
    - Campus Emergency Hotline
        
    - University Emergency Line
        
    - Emergency 111
        
    - Other?
        
3. What should the emergency number be called in SOPs?
    
4. What should the Asterisk dialplan label/context name be?
    
5. What should the incident log label for this call type be?
    

## Core Decisions

1. Confirm: Is the emergency number **111**?
    
2. Should any alias numbers also route to the same emergency queue?
    
    - 112
        
    - 101
        
    - 911
        
    - None
        
3. Should only authenticated SIP users call 111, or should any LAN SIP device be allowed?
    
4. Should students, staff, ERT, fixed devices, and system devices all be able to call 111?
    
5. Should guest devices ever be allowed to call 111?
    
6. Should 111 be reachable from all role contexts?
    
7. Should 111 always bypass normal calling restrictions?
    
8. Should 111 calls be prioritized over normal student-to-student calls?
    
9. Should 111 be shown as the primary emergency number everywhere?
    
10. Should there be posters/stickers for “Campus Emergency: Dial 111”?
    

## Caller Experience Decisions

1. What should the caller hear when dialing 111?
    
    - Ringback only
        
    - Short announcement
        
    - Emergency hold message
        
2. Should the caller hear a message before ERT answers?
    
3. What should that message say?
    
4. Should there be different prompts for real calls and drill/test calls?
    
5. Should the caller be told that the call is recorded?
    
6. Should the system support multiple simultaneous 111 calls?
    
7. What should happen if multiple students call 111 at the same time?
    

---

# Feature 2: ERT Emergency Queue

## Naming Decisions

1. What should the emergency queue be named?
    
    - `emergency_queue`
        
    - `ert_queue`
        
    - `campus_111_queue`
        
    - Other?
        
2. What should ERT agents be called?
    
3. What should the queue display name be?
    
4. What should the caller ID label show when 111 rings ERT?
    
5. What should queue logs call this queue?
    

## Queue Membership Decisions

1. Who are the initial ERT queue members?
    
2. Will queue members be human SAP ID users, fixed desk phones, or both?
    
3. Should ERT desk phones be queue members?
    
4. Should ERT personal mobile SIP apps be queue members?
    
5. Should the ERT Lead be in the primary queue or escalation-only?
    
6. Should Medical/Security be direct queue members or dispatch targets only?
    
7. Should queue membership change by time of day?
    
8. Should there be active/inactive ERT shifts?
    
9. How many available responders are required for the queue to be considered healthy?
    
10. What is the minimum number of ERT agents for go-live?
    

## Queue Behavior Decisions

1. What queue strategy should be used?
    
    - Ring all available
        
    - Round robin
        
    - Least recent
        
    - Fewest calls
        
    - Other?
        
2. Should all ERT devices ring at once?
    
3. Should the system avoid ringing busy responders?
    
4. Should paused responders be skipped?
    
5. Should offline responders be skipped?
    
6. How long should the queue ring before escalation?
    
    - 15 seconds
        
    - 20 seconds
        
    - Other?
        
7. What should the caller hear while waiting?
    
8. Should there be hold music?
    
9. Should hold music be disabled for emergency calls?
    
10. Should queue calls be recorded from the beginning?
    

---

# Feature 3: Emergency Fallback & Escalation Path

## Naming Decisions

1. What should this escalation feature be called?
    
2. What should the ERT Lead escalation group be named?
    
3. What should the backup emergency authority group be named?
    
4. What should missed escalation logs be called?
    
5. What should the final unanswered emergency status be called?
    

## Escalation Structure Decisions

1. Who is the first escalation target after the ERT queue fails?
    
2. Is the ERT Lead a person, role extension, or fixed device?
    
3. What is the ERT Lead extension?
    
4. What is the timeout before calling the ERT Lead?
    
5. Who belongs to the backup emergency authority group?
    
6. Should the backup group ring all at once or in sequence?
    
7. What is the backup group timeout?
    
8. Should escalation be different during drills?
    
9. Should escalation be different during off-hours?
    
10. Should escalation stop after one person answers?
    

## Final Fallback Decisions

1. Should unanswered calls go to emergency voicemail?
    
2. Should unanswered calls ever disconnect without voicemail?
    
3. What should the voicemail prompt say?
    
4. Should the missed call be marked Critical by default?
    
5. Who is responsible for reviewing unanswered emergency calls?
    
6. How quickly should missed emergency calls be reviewed?
    
7. Should missed escalation trigger a visible dashboard alert?
    
8. Should failed escalation be recorded in incident logs?
    
9. Should repeated calls from the same caller be grouped?
    
10. Should voicemail still be created if the caller hangs up before the prompt?
    

---

# Feature 4: Emergency Call Recording & Incident Logging

## Naming Decisions

1. What should emergency call recordings be called?
    
2. What should emergency call logs be called?
    
3. What should the incident ID format be?
    
    - `INC-YYYY-00001`
        
    - `ERT-YYYYMMDD-0001`
        
    - Other?
        
4. What should the recording file naming format be?
    
5. What should the log entry label for 111 calls be?
    
6. What should missed emergency records be called?
    

## Recording Decisions

1. Confirm: Should only calls to 111 be recorded by default?
    
2. Should student-to-student calls be recorded?
    
3. Should emergency conference 9000 be recorded?
    
4. Should side conference rooms be recorded?
    
5. Should emergency paging audio be recorded?
    
6. Should recording start immediately when 111 is dialed?
    
7. Should recording continue through transfer/bridge?
    
8. Should recordings include caller hold time?
    
9. Should voicemail recordings be linked to the same incident ID?
    
10. Should callers be informed that emergency calls may be recorded?
    

## Incident Logging Decisions

1. What fields are mandatory in every emergency log?
    
2. Should caller SAP ID be captured?
    
3. Should caller display name be captured?
    
4. Should caller device/IP be captured?
    
5. Should caller location be captured if fixed device?
    
6. Should ERT responder identity be captured?
    
7. Should answer time be captured?
    
8. Should queue wait time be captured?
    
9. Should escalation attempts be captured?
    
10. Should transfer/bridge actions be captured?
    
11. Should final incident status be mandatory?
    
12. Should every 111 call create an incident automatically?
    
13. Should false alarms still be logged?
    
14. Who can edit incident notes?
    
15. Who can close an incident?
    

## Retention and Access Decisions

1. How long should emergency recordings be retained?
    
2. Who can listen to recordings?
    
3. Who can download recordings?
    
4. Should recording access be logged?
    
5. Should recordings be encrypted at rest?
    
6. Should recordings be backed up?
    
7. Who approves recording deletion?
    
8. Should recordings be deleted automatically after retention?
    
9. Should logs remain longer than audio recordings?
    
10. What is the university policy requirement for emergency records?
    

---

# Feature 5: Ready-made SIP Client Deployment

## Naming Decisions

1. What should the SIP app setup guide be called?
    
2. What SIP client will be recommended first?
    
    - Linphone
        
    - Zoiper
        
    - MicroSIP
        
    - Other?
        
3. What should the student setup profile be named?
    
4. What should the ERT setup profile be named?
    
5. What should the fixed-device configuration profile be named?
    

## Client Selection Decisions

1. Which SIP app should be recommended for Android?
    
2. Which SIP app should be recommended for iOS?
    
3. Which SIP app should be recommended for Windows?
    
4. Which SIP app should be recommended for macOS/Linux?
    
5. Should all users use the same app where possible?
    
6. Should ERT use a different/more controlled client?
    
7. Should physical IP phones be used for ERT/control room?
    
8. Should students self-install SIP apps?
    
9. Should setup be admin-assisted?
    
10. Should QR provisioning be supported later?
    

## User Setup Decisions

1. What server address should users enter?
    
2. What username should users enter?
    
3. What password delivery method will be used?
    
4. Will password be visible once or resettable?
    
5. Should users be allowed to change SIP passwords?
    
6. Should users be given screenshots for setup?
    
7. Should students be given a test number to verify registration?
    
8. Should users be trained to dial SAP IDs?
    
9. Should there be a student directory/search method?
    
10. Should support be available for SIP app setup issues?
    

---

# Feature 6: Emergency Announcement & Paging

## Naming Decisions

1. What should emergency paging be called?
    
2. What should all-campus broadcast be called?
    
3. What should each paging zone be named?
    
4. What should the paging extension range be?
    
5. What should paging attempts be called in logs?
    

## Paging Code Decisions

1. Confirm: Should paging codes use the 700 range?
    
2. What should 700 do?
    
3. What should 701 do?
    
4. What should 702 do?
    
5. What should 703 do?
    
6. What should 704 do?
    
7. What should 705 do?
    
8. Are any zones missing?
    
9. Should paging codes be finalized now or after the roles/location drill?
    
10. Should paging zones map to buildings, hostels, or functional areas?
    

## Access Decisions

1. Who can page all campus?
    
2. Who can page hostels?
    
3. Who can page academic blocks?
    
4. Who can page security gates?
    
5. Should ERT members page directly or only ERT Lead/control room?
    
6. Should students be blocked from all paging?
    
7. Should staff be blocked from paging?
    
8. Should paging require PIN?
    
9. Should paging require role-based access only?
    
10. Should paging attempts be logged?
    

## Operational Decisions

1. Should paging be live only in Phase 1?
    
2. Should pre-recorded messages be added later?
    
3. Should multilingual announcements be added later?
    
4. Should paging audio be recorded?
    
5. Should paging be tested weekly/monthly?
    
6. Should paging tests require prior notice?
    
7. What exact phrase should paging messages begin with?
    
8. Who approves campus-wide paging?
    
9. Should paging be allowed during drills only with drill prefix?
    
10. Should unauthorized paging attempts trigger health/security logs?
    

---

# Feature 7: Incident Command Conference Rooms

## Naming Decisions

1. What should the main conference room be called?
    
2. Should 9000 be called “Main Incident Command Room”?
    
3. What should 9001 be called?
    
4. What should 9002 be called?
    
5. What should 9003 be called?
    
6. What should 9004 be called?
    
7. Should the 9000 range be reserved for emergency conferences?
    
8. What should conference logs be called?
    

## Room Decisions

1. Confirm: Should 9000 be the main command room?
    
2. How many conference rooms are needed in Phase 1?
    
3. Should side rooms be enabled immediately or later?
    
4. Should every emergency room have a PIN?
    
5. Should only 9000 have a PIN?
    
6. Should ERT Lead be moderator for 9000?
    
7. Should participants hear join/leave tones?
    
8. Should maximum participant limits be set?
    
9. Should 9000 be recorded by default?
    
10. Should side rooms be recorded?
    
11. Should conference rooms be available all the time or activated per incident?
    
12. Should conference activity link to incident IDs?
    

## Access Decisions

1. Who can join 9000?
    
2. Who can join security room?
    
3. Who can join medical room?
    
4. Who can join warden room?
    
5. Who can join operations room?
    
6. Can students join any conference room?
    
7. Can general staff join any conference room?
    
8. Can unauthorized users dial 9000 and hear rejection?
    
9. Should failed join attempts be logged?
    
10. Should conference access be controlled by context, PIN, or both?
    

---

# Feature 8: Emergency Responder Directory & Numbering Plan

## Naming Decisions

1. What should the responder directory be called?
    
2. What should the final numbering plan document be called?
    
3. What should fixed-device extensions be called?
    
4. What should service numbers be called?
    
5. What should SAP ID extensions be called?
    
6. What should the role-design drill be called?
    

## Directory Scope Decisions

1. Which roles must appear in the emergency directory?
    
2. Which fixed locations must appear?
    
3. Which service codes must appear?
    
4. Should all students appear in the general directory?
    
5. Should all staff appear in the general directory?
    
6. Should emergency directory and student directory be separate?
    
7. Should personal mobile numbers be included?
    
8. Should only SIP extensions be included?
    
9. Should room/location phones be clearly marked?
    
10. Should directory entries show role, location, and permissions?
    

## Numbering Decisions

1. What extension ranges are reserved for fixed devices?
    
2. What service codes are reserved?
    
3. What range is reserved for paging?
    
4. What range is reserved for conferences?
    
5. Are SAP IDs too long for manual dialing?
    
6. Should short aliases exist for critical fixed devices?
    
7. Should ERT desks have short numbers?
    
8. Should Medical Room have a short fixed extension?
    
9. Should Security Control Room have a short fixed extension?
    
10. Should students dial SAP IDs directly or use contact search?
    

## Role-design Drill Decisions

1. Who will participate in the role-design drill?
    
2. What departments/teams need representation?
    
3. When will the final role list be created?
    
4. Who approves final extension assignments?
    
5. Who maintains the directory after launch?
    
6. How often should the directory be reviewed?
    
7. What is the process to add/remove emergency roles?
    
8. What is the process to change fixed-device ownership?
    
9. How will outdated directory entries be detected?
    
10. Where will the approved directory be published?
    

---

# Feature 9: Responder Status & Availability

## Naming Decisions

1. What should responder status be called?
    
2. What status labels should be used?
    
3. What should pause/unpause feature codes be named?
    
4. What should the responder status dashboard be called?
    
5. What should “unavailable” mean in SOP terms?
    

## Status Decisions

1. Confirm Phase 1 statuses:
    
    - Available
        
    - Busy
        
    - Offline
        
    - Paused
        
2. Should “On Incident” be included in Phase 1 or later?
    
3. Should “Field Responding” be included later?
    
4. Should status come from Asterisk only in Phase 1?
    
5. Should manual status updates be avoided in Phase 1?
    
6. Should ERT members be allowed to pause themselves?
    
7. Should ERT Lead be able to pause/unpause others?
    
8. Should paused status require a reason?
    
9. Should offline critical devices trigger health warnings?
    
10. Should queue accept calls if zero responders are available?
    

## Feature Code Decisions

1. What code pauses an ERT member from queue?
    
2. What code unpauses an ERT member?
    
3. Should codes be `*45` and `*46` or different?
    
4. Should only ERT users be able to use these codes?
    
5. Should pause/unpause actions be logged?
    
6. Should accidental pause be prevented?
    
7. Should a paused responder auto-unpause after some time?
    
8. Should ERT Lead see all paused users?
    
9. Should paused users still receive direct calls?
    
10. Should paused users still join conferences?
    

---

# Feature 10: Emergency Voicemail & Missed-call Recovery

## Naming Decisions

1. What should emergency voicemail be called?
    
2. What should missed emergency incidents be called?
    
3. What should the missed emergency list be named?
    
4. What status labels should be used for missed calls?
    
5. What should the voicemail prompt file be named?
    

## Voicemail Decisions

1. Confirm: Should unanswered emergency calls go to voicemail?
    
2. What exact prompt should be used?
    
3. Should the prompt mention name, location, and emergency?
    
4. Should caller be asked to stay near the phone?
    
5. What is maximum voicemail duration?
    
6. What happens if caller says nothing?
    
7. What happens if caller hangs up before recording?
    
8. Should voicemail be automatically linked to incident ID?
    
9. Should voicemail be marked Critical by default?
    
10. Should voicemail access be restricted?
    

## Review Workflow Decisions

1. Who reviews missed emergency voicemails?
    
2. What is the required review time?
    
3. Should every missed emergency remain pending until reviewed?
    
4. Should callback be mandatory when caller is known?
    
5. Should callback attempts be logged?
    
6. What statuses should be used?
    
    - Pending Review
        
    - Reviewed
        
    - Callback Attempted
        
    - Converted to Active Incident
        
    - Closed as Duplicate
        
    - Closed as False Alarm
        
7. Who can close missed emergency incidents?
    
8. Should missed voicemail appear on local dashboard?
    
9. Should repeated missed calls from same SAP ID be grouped?
    
10. Should missed voicemail be included in drill testing?
    

---

# Feature 11: Emergency Call Transfer & Dispatch Workflow

## Naming Decisions

1. What should this feature be called in SOP?
    
2. What should each dispatch mode be called?
    
3. What should dispatch logs be named?
    
4. What should handoff status labels be?
    
5. What should incident ownership be called?
    

## Dispatch Mode Decisions

1. Confirm supported modes:
    
    - Dispatch without transfer
        
    - Warm transfer
        
    - Three-way bridge
        
2. Should dispatch without transfer be the default?
    
3. Should warm transfer be the preferred transfer method?
    
4. Should three-way bridge be used for serious/unclear cases?
    
5. Should blind transfer be restricted?
    
6. Should blind transfer be disabled entirely or only discouraged?
    
7. Who is allowed to use warm transfer?
    
8. Who is allowed to create a three-way bridge?
    
9. Can students transfer calls?
    
10. Can staff transfer calls?
    

## Ownership Decisions

1. Who owns an incident after ERT answers?
    
2. When can ownership be reassigned?
    
3. Who can reassign ownership?
    
4. How is handoff confirmation recorded?
    
5. What happens if target responder does not answer?
    
6. Should ERT stay on call during critical handoffs?
    
7. Should ERT always log dispatch actions?
    
8. Should caller ever be transferred directly without explanation?
    
9. Should ERT be trained on dispatch modes?
    
10. Should dispatch workflow be tested during drills?
    

## Logging Decisions

1. What fields are required for dispatch logs?
    
2. Should target extension/team be captured?
    
3. Should target answer status be captured?
    
4. Should transfer type be captured?
    
5. Should bridge participants be captured?
    
6. Should failed transfers be incidents?
    
7. Should dispatch notes be mandatory?
    
8. Should dispatch actions link to recording timestamps?
    
9. Should all dispatch events appear in incident timeline?
    
10. Who can edit dispatch logs?
    

---

# Feature 12: LAN-only Infrastructure Boundary

## Naming Decisions

1. What should the LAN-only boundary be called?
    
2. What should the internal network be called?
    
3. What should the local Asterisk server be called?
    
4. What should the SIP domain be called?
    
5. What should the system boundary diagram be titled?
    

## Scope Decisions

1. Confirm: Is the system LAN-only?
    
2. Confirm: No public internet dependency?
    
3. Confirm: No external SIP trunk?
    
4. Confirm: No PSTN calling?
    
5. Confirm: No SMS/WhatsApp/email alerts in Phase 1?
    
6. Confirm: No remote users outside campus?
    
7. Confirm: No cloud PBX?
    
8. Confirm: No public SIP/RTP exposure?
    
9. Confirm: All core records stored locally?
    
10. Confirm: Local DNS or local IP only?
    

## Network Boundary Decisions

1. Which LAN/Wi-Fi networks are allowed?
    
2. Which subnets can register SIP clients?
    
3. Which subnets can access admin/monitoring?
    
4. Which subnets contain fixed devices?
    
5. Should student Wi-Fi be allowed to reach Asterisk?
    
6. Should guest Wi-Fi be blocked?
    
7. Should management access be separated?
    
8. Should Asterisk have a static IP?
    
9. Should DNS fallback to IP be documented?
    
10. Should VLAN segmentation be added later?
    

---

# Feature 13: SIP Security & Access Control

## Naming Decisions

1. What should each role/context be named?
    
2. What should the student context be called?
    
3. What should the staff context be called?
    
4. What should the ERT context be called?
    
5. What should the ERT Lead context be called?
    
6. What should the control room context be called?
    
7. What should the fixed-device context be called?
    
8. What should restricted feature attempts be called in logs?
    

## Student Access Decisions

1. Confirm: Can students call 111?
    
2. Confirm: Can students call other students?
    
3. Can students call staff/faculty?
    
4. Can students call fixed public campus phones?
    
5. Can students call ERT directly?
    
6. Can students receive calls from ERT?
    
7. Can students join conferences?
    
8. Can students use paging?
    
9. Can students transfer calls?
    
10. Can students access recordings/voicemail?
    

## Staff Access Decisions

1. Can staff call students?
    
2. Can staff call other staff?
    
3. Can staff call 111?
    
4. Can staff call ERT directly?
    
5. Can staff use paging?
    
6. Can staff join conference rooms?
    
7. Can staff access recordings?
    
8. Which staff roles need emergency permissions?
    
9. Should faculty coordinators have special permissions?
    
10. Should staff access be same as students by default?
    

## Emergency Role Decisions

1. Who can receive 111 queue calls?
    
2. Who can use paging?
    
3. Who can join 9000?
    
4. Who can review voicemails?
    
5. Who can access recordings?
    
6. Who can warm transfer emergency calls?
    
7. Who can create three-way bridges?
    
8. Who can pause/unpause queue status?
    
9. Who can manage SIP accounts?
    
10. Who can view health monitoring?
    

## Security Policy Decisions

1. Should anonymous SIP be disabled?
    
2. Should every user have unique credentials?
    
3. Should shared credentials be banned except fixed devices?
    
4. What is the minimum password strength?
    
5. How are passwords delivered?
    
6. How are lost devices revoked?
    
7. Should failed registration attempts be logged?
    
8. Should unknown devices be blocked?
    
9. Should account abuse lead to suspension?
    
10. Who approves role elevation?
    

---

# Feature 14: Device Provisioning & Extension Management

## Naming Decisions

1. What should the provisioning process be called?
    
2. What should human SIP accounts be called?
    
3. What should fixed device accounts be called?
    
4. What should service codes be called?
    
5. What should the user onboarding guide be named?
    
6. What should the SIP password reset process be called?
    

## SAP ID Decisions

1. Confirm: SAP ID is SIP extension for all human users?
    
2. Confirm: SAP ID is SIP username?
    
3. Should SAP ID be visible in caller ID?
    
4. Should display name include full name?
    
5. What happens if a SAP ID changes?
    
6. What happens when a student leaves?
    
7. What happens when a staff member leaves?
    
8. Can one SAP ID register on multiple devices?
    
9. What is the maximum devices per SAP ID?
    
10. Should device registration count be monitored?
    

## Fixed Device Decisions

1. What extension range should fixed devices use?
    
2. How are fixed devices named?
    
3. Who owns each fixed device?
    
4. Where is each fixed device physically located?
    
5. Who can request a new fixed device extension?
    
6. Who can disable a fixed device?
    
7. Should fixed phones have static IPs?
    
8. Should fixed phones have restricted dialing?
    
9. Should fixed phones show location as caller ID?
    
10. Should fixed devices appear in the emergency directory?
    

## Provisioning Decisions

1. Will users be manually provisioned first?
    
2. Will SAP ID import be CSV-based?
    
3. Will account creation be automated later?
    
4. How are SIP passwords generated?
    
5. How are SIP passwords delivered securely?
    
6. Should QR setup be supported?
    
7. Should there be setup guides per OS/app?
    
8. Who handles user support?
    
9. Who resets passwords?
    
10. Who revokes lost devices?
    

## Lifecycle Decisions

1. What account states are needed?
    
    - Pending Setup
        
    - Active
        
    - Disabled
        
    - Password Reset Required
        
    - Lost Device
        
    - Archived
        
2. Who can move accounts between states?
    
3. Should disabled users retain historical logs?
    
4. Should extension reuse be allowed?
    
5. Should SAP ID ownership history be preserved?
    
6. What is the offboarding process?
    
7. What is the lost-device process?
    
8. What is the abuse process?
    
9. What is the bulk import process?
    
10. What is the audit/export process?
    

---

# Feature 15: Local Wi-Fi-first Infrastructure Readiness

## Naming Decisions

1. What should this infrastructure feature be called?
    
2. What should the mobile-first user path be called?
    
3. What should the ERT fixed-device path be called?
    
4. What should the local infrastructure diagram be titled?
    
5. What should the pilot environment be called?
    

## Existing Infrastructure Decisions

1. What router is used?
    
2. What switch is used?
    
3. What access point is used?
    
4. What server runs Asterisk?
    
5. What OS runs on the Asterisk server?
    
6. What is the Asterisk server IP?
    
7. Is the Asterisk server static IP configured?
    
8. What Wi-Fi SSID is used?
    
9. Is Wi-Fi client isolation enabled?
    
10. Are SIP/RTP ports allowed inside LAN?
    

## Mobile-first Decisions

1. Which mobile SIP app is primary?
    
2. Which phones will be used for pilot?
    
3. How many mobile users in pilot?
    
4. How many simultaneous calls should be tested?
    
5. Should student-to-student calls be enabled in pilot?
    
6. Should all pilot users use SAP ID login?
    
7. Should calls work when phone screen locks?
    
8. Should users keep SIP app running in background?
    
9. How will mobile app setup be supported?
    
10. How will mobile call quality be evaluated?
    

## ERT / Fixed Device Decisions

1. Which fixed IP phones are required at launch?
    
2. Where will ERT answering device be placed?
    
3. Will ERT use IP phone, mobile SIP app, or both?
    
4. Will medical room have a fixed SIP phone?
    
5. Will security have a fixed SIP phone?
    
6. Will warden/admin have fixed SIP phones?
    
7. Will IP speakers be deployed in Phase 1?
    
8. Will paging devices be deployed in Phase 1?
    
9. Which devices are mandatory for go-live?
    
10. Which devices are staged for later?
    

## Capacity and Reliability Decisions

1. How many users must register simultaneously?
    
2. How many simultaneous student calls should be supported?
    
3. How many simultaneous emergency calls should be supported?
    
4. How many ERT devices should be online?
    
5. What is acceptable call quality?
    
6. What is acceptable latency/jitter?
    
7. What happens if Wi-Fi is weak?
    
8. What happens if AP is overloaded?
    
9. Should emergency calls have priority over normal calls?
    
10. What minimum test results are required for rollout?
    

---

# Feature 16: Local System Health Monitoring

## Naming Decisions

1. What should the health dashboard be called?
    
2. What should health statuses be called?
    
    - OK
        
    - Warning
        
    - Critical
        
    - Offline
        
3. What should the daily readiness check be called?
    
4. What should the weekly drill health report be called?
    
5. What should a failed health check be called?
    

## Monitoring Decisions

1. Should there be a local dashboard?
    
2. Is CLI/script-based monitoring enough for MVP?
    
3. Who checks system health daily?
    
4. Who checks system health before drills?
    
5. What devices are critical?
    
6. Which SIP registrations must always be online?
    
7. What makes the system unhealthy?
    
8. What makes the system degraded?
    
9. What makes the system ready?
    
10. Who can view health status?
    

## Health Check Decisions

1. Should Asterisk service be checked?
    
2. Should SIP registrations be checked?
    
3. Should ERT queue availability be checked?
    
4. Should mobile SIP registration be checked?
    
5. Should fixed phones be checked?
    
6. Should recording path be checked?
    
7. Should voicemail be checked?
    
8. Should disk usage be checked?
    
9. Should paging be checked?
    
10. Should conference rooms be checked?
    
11. Should access-control violations be checked?
    
12. Should test call result be checked?
    

## Threshold Decisions

1. What disk usage is Warning?
    
2. What disk usage is Critical?
    
3. What is minimum available ERT agents?
    
4. What is maximum acceptable queue wait time?
    
5. What is maximum acceptable failed SIP registrations?
    
6. What is acceptable AP/user load?
    
7. What is acceptable packet loss?
    
8. What is acceptable call setup time?
    
9. What should happen if recording fails?
    
10. What should happen if 111 test call fails?
    

---

# Feature 17: Emergency SOP & Drill Mode

## Naming Decisions

1. What should the SOP be called?
    
2. What should Drill Mode be called?
    
3. What should the test line be called?
    
4. What should the drill label be?
    
5. What should the post-drill review document be called?
    

## SOP Decisions

1. What exact sentence should ERT say when answering 111?
    
2. What are the mandatory questions?
    
3. What are optional questions?
    
4. What incident categories should be used?
    
5. What is the dispatch decision tree?
    
6. When is paging allowed?
    
7. Who approves paging?
    
8. When is 9000 activated?
    
9. Who joins 9000?
    
10. How are missed voicemails reviewed?
    
11. How are incidents closed?
    
12. Who writes incident notes?
    
13. Who conducts post-incident review?
    
14. What response-time expectations exist?
    
15. What is the escalation instruction if ERT is unsure?
    

## Drill Mode Decisions

1. Confirm: Should test number be 199?
    
2. Should 199 simulate the 111 flow?
    
3. Should 199 avoid real escalation?
    
4. Should 199 create drill logs only?
    
5. Should 199 be recorded?
    
6. Who can call 199?
    
7. How often should drills happen?
    
8. Should real 111 be tested during planned drills?
    
9. Should paging drills require prior notice?
    
10. Who approves full incident drills?
    
11. Should drill records be kept?
    
12. Should drill failures create action items?
    
13. Who owns action items?
    
14. What is the post-drill review format?
    
15. How are responders trained?
    

---

# Feature 18: Backup, Restore & Configuration Export

## Naming Decisions

1. What should the backup process be called?
    
2. What should backup snapshots be named?
    
3. What should config versions be called?
    
4. What should restore checklists be called?
    
5. What should export files be named?
    
6. What should the local Git repo be called?
    

## Backup Scope Decisions

1. Should Asterisk config be backed up?
    
2. Should SIP account data be backed up?
    
3. Should SAP ID mappings be backed up?
    
4. Should fixed device mappings be backed up?
    
5. Should dialplan be backed up?
    
6. Should queue config be backed up?
    
7. Should voicemail config be backed up?
    
8. Should prompts be backed up?
    
9. Should recordings be backed up?
    
10. Should logs be backed up?
    
11. Should health monitoring config be backed up?
    
12. Should SOP/drill docs be backed up?
    

## Backup Schedule Decisions

1. Should backup happen before every config change?
    
2. Should config be backed up daily?
    
3. Should logs be exported weekly?
    
4. Should directory be exported weekly?
    
5. Should recordings follow separate retention?
    
6. Should backups rotate automatically?
    
7. How many backup versions should be kept?
    
8. Where is the primary backup stored?
    
9. Where is the secondary backup stored?
    
10. Is there an encrypted offline copy?
    

## Restore Decisions

1. Who can restore the system?
    
2. Where are restore instructions stored?
    
3. What is acceptable restore time?
    
4. What files are restored first?
    
5. What is the restore verification checklist?
    
6. Should restore be tested after major changes?
    
7. Should restore be tested monthly/quarterly?
    
8. Who signs off successful restore?
    
9. What happens if backup fails?
    
10. What happens if restore fails?
    

## Security Decisions

1. Should backups be encrypted?
    
2. Which backups require encryption?
    
3. Who has backup access?
    
4. Where are credentials stored?
    
5. Are recordings included in encrypted backup?
    
6. Are SIP passwords stored as secrets?
    
7. Should backup access be logged?
    
8. Should USB/offline backup be locked physically?
    
9. Who approves deletion of old backups?
    
10. What retention policy applies?
    

---

# Final Cross-feature Decisions

## Go-live Decisions

1. What is the minimum feature set required before pilot?
    
2. Which features must be fully tested before real use?
    
3. Which features can be staged later?
    
4. How many pilot users are needed?
    
5. Which ERT members participate in pilot?
    
6. Which fixed devices are mandatory for pilot?
    
7. Which buildings/areas are included in pilot?
    
8. What is the go-live date?
    
9. Who approves go-live?
    
10. What are rollback conditions?
    

## Phase 1 Success Criteria

1. Can mobile SIP clients register over Wi-Fi?
    
2. Can users call SAP ID to SAP ID?
    
3. Can any authenticated user call 111?
    
4. Does 111 reach ERT queue?
    
5. Does fallback/escalation work?
    
6. Does emergency voicemail work?
    
7. Does recording work for 111?
    
8. Are student calls not recorded by default?
    
9. Are paging codes restricted?
    
10. Are conference rooms restricted?
    
11. Can ERT dispatch using transfer/bridge?
    
12. Can health checks show system status?
    
13. Can config be backed up and restored?
    
14. Can drill mode test the system safely?
    
15. Are SOPs understood by responders?
    

## Documents to Create After You Answer This

1. Final Feature Specification
    
2. Asterisk Dialplan Design
    
3. SIP Account and Role Matrix
    
4. Numbering Plan
    
5. ERT SOP
    
6. Drill/Test SOP
    
7. Student SIP Setup Guide
    
8. ERT SIP Setup Guide
    
9. Local Infrastructure Diagram
    
10. Health Monitoring Checklist
    
11. Backup and Restore Procedure
    
12. Rollout Plan
    
13. Pilot Test Plan
    
14. Security and Access Control Matrix
    
15. Incident Logging Schema
    
16. Emergency Recording and Retention Policy
    
17. Device Provisioning Sheet
    
18. Final Go-live Checklist
