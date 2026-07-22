# UPES-ECS — Filled Decision Questionnaire


> THIS IS JUST FOR DIRECTION NOT A RULESET or Locked decisions. we are looking for improvements. 

**Document status:** Recommended Phase 1 answer set  
**System name:** UPES-ECS  
**System type:** LAN-only university emergency and internal SIP communication system  
**Primary user device:** Mobile phone on campus Wi-Fi using SIP app  
**Secondary devices:** ERT desk phones, control-room IP phones, medical/security/warden fixed SIP phones, optional paging devices  
**Primary identity model:** SAP ID as SIP extension and SIP username for every human user  

---

## 0. Locked Baseline Assumptions

1. The system is **LAN-only** in Phase 1.
2. There is **no public SIP exposure**, no SIP trunk, no PSTN, no cloud PBX, and no dependency on internet for emergency calling.
3. Asterisk runs on one local server connected to the campus LAN.
4. Router, switch, access point, and power are available.
5. The primary client is the mobile phone using campus Wi-Fi and a SIP app.
6. IP phones and fixed SIP devices are still required for ERT, control room, medical, security, wardens, and critical locations.
7. SAP ID uniquely identifies every university user and will be used as the SIP extension and SIP username.
8. Students are allowed to call other students directly by SAP ID.
9. Emergency number `111` is the primary campus emergency number.
10. Test/drill number `199` is used for safe testing.

---

# Global System Decisions

## A. Project Naming

| Question                     | Filled Decision                                   |
| ---------------------------- | ------------------------------------------------- |
| Final system name            | **UPES-ECS**                                      |
| Naming tone                  | Official and university-branded                   |
| Internal acronym             | **UPES-ECS**                                      |
| Name in SOP documents        | **UPES-ECS**                                      |
| Name in student instructions | **UPES-ECS**                                      |
| Name on SIP guides/caller ID | **UPES-ECS**                                      |
| Branding model               | University-branded emergency communication system |
|                              |                                                   |

## B. Core Terminology

| Term | Final Name |
|---|---|
| Emergency response team | **Emergency Response Team** |
| Short form | **ERT** |
| Control room | **UPES-ERT-ROOM** |
| Main emergency operator role | **ERT Operator** |
| Emergency lead role | **ERT Lead / Incident Commander** |
| Student users | **Student SIP Users** |
| Staff/faculty users | **Staff SIP Users** |
| Fixed phones/devices | **Fixed Campus SIP Devices** |
| Internal SIP accounts | **UPES-ECS SIP Accounts** |
| Missed emergency records | **Missed Emergency Incidents** |
| Test/drill calls | **Drill Calls** |

## C. Network Naming

| Question                     | Filled Decision                                                                                              |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Local domain for SIP clients | **`pbx.upes.lan`** preferred; direct IP documented as fallback                                               |
| Asterisk server hostname     | **`upes-ecs-pbx-01`**                                                                                        |
| SIP realm/domain             | **`sip.upes.lan`**                                                                                           |
| Local monitoring dashboard   | **UPES-ECS Health Dashboard**                                                                                |
| Local admin panel            | **UPES-ECS Admin Console**                                                                                   |
| Wi-Fi SSID                   | **TBD: campus Wi-Fi SSID to be confirmed by UPES IT**                                                        |
| Wi-Fi model                  | Normal campus Wi-Fi for students, emergency/voice-enabled SSID or VLAN later if available                    |
| Client isolation             | Must be checked before pilot                                                                                 |
| Client isolation action      | If enabled, allow SIP/RTP access from Wi-Fi clients to Asterisk or move clients to a voice-enabled SSID/VLAN |
| Asterisk LAN subnet          | **TBD: assign static IP and subnet during deployment**                                                       |
| Allowed subnets              | Student Wi-Fi, staff Wi-Fi, ERT/control-room LAN, fixed-device LAN; guest Wi-Fi blocked                      |

## D. Identity Model

| Question | Filled Decision |
|---|---|
| SAP ID as SIP extension | **Yes** |
| SAP ID as SIP username | **Yes** |
| Display name includes name and SAP ID | **Yes** |
| Caller ID format | **`Name - SAP ID`** |
| Student directory/search | Phase 1: manual SAP ID dialing; Phase 1.5/2: searchable directory/contact export |
| Fixed devices separate extensions | **Yes** |
| Fixed-device extension range | **4000–4999** |
| Service-code ranges | `111` emergency, `199` drill, `700–799` paging, `9000–9099` conference, `*45/*46` queue status |
| Staff/faculty identity | Use SAP ID if available; otherwise use official employee/staff ID mapped to SIP extension |
| ERT member identity | Personal SAP ID for person-to-person calls; dedicated ERT/fixed extensions for role/device responsibility |
| ERT desk phones | **Yes**, fixed ERT extensions in addition to personal SAP IDs |

---

# Feature 1: Campus Emergency Hotline

## Final Filled Decisions

| Area                      | Decision                                                                                                                                |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Official feature name     | **Campus Emergency Hotline**                                                                                                            |
| Student-facing wording    | **Campus Emergency: Dial 111**                                                                                                          |
| SOP name                  | **UPES Emergency Line 111**                                                                                                             |
| Dialplan context/label    | **`ctx_emergency_111`**                                                                                                                 |
| Incident log label        | **`EMERGENCY_111_CALL`**                                                                                                                |
| Primary emergency number  | **111**                                                                                                                                 |
| Alias numbers             | Enable 112 only if approved by UPES administration. Do not use 101 as an alias to 111. Reserve 101 for the AI Emergency Assistant Line. |
| Who can call 111          | All authenticated SIP users: students, staff, ERT, fixed devices, system devices                                                        |
| Guest access              | Guest Wi-Fi/SIP devices blocked in Phase 1                                                                                              |
| Role restrictions         | 111 reachable from all authenticated role contexts and bypasses normal restrictions                                                     |
| Priority                  | Emergency calls prioritized over normal internal calls                                                                                  |
| Posters/stickers          | Yes: “Campus Emergency: Dial 111 on UPES-ECS”                                                                                           |
| Caller audio              | Short announcement, then queue ringback/hold message                                                                                    |
| Pre-answer prompt         | “You have reached UPES Emergency Response. Your emergency call may be recorded. Please stay on the line.”                               |
| Drill prompt              | Separate prompt: “This is a UPES-ECS drill call. No real emergency response will be dispatched.”                                        |
| Recording notice          | Yes, only for emergency/drill flows                                                                                                     |
| Multiple calls            | Supported using ERT queue                                                                                                               |
| Multiple callers behavior | Calls enter emergency queue; ERT answers in order while available responders ring                                                       |

---

# Feature 2: ERT Emergency Queue

## Final Filled Decisions

| Area                                  | Decision                                                                    |
| ------------------------------------- | --------------------------------------------------------------------------- |
| Queue name                            | **`ert_emergency_queue`**                                                   |
| ERT agents called                     | **ERT Responders**                                                          |
| Queue display name                    | **UPES ERT Emergency Queue**                                                |
| Caller ID label on ERT device         | **`EMERGENCY 111 - Name - SAP ID`**                                         |
| Queue log name                        | **`ERT_EMERGENCY_QUEUE`**                                                   |
| Initial members                       | ERT control-room phone, ERT desk phones, ERT mobile SIP apps                |
| Member type                           | Both fixed desk phones and human SAP ID users                               |
| ERT desk phones in queue              | Yes                                                                         |
| ERT personal mobile SIP apps in queue | Yes                                                                         |
| ERT Lead role                         | Escalation-first; may also be primary member during low-staff pilot         |
| Medical/Security                      | Dispatch targets by default; direct queue members only if assigned ERT duty |
| Time-of-day membership                | Keep static for Phase 1; shift-based membership later                       |
| Active/inactive shifts                | Later enhancement; not mandatory for first pilot                            |
| Healthy queue threshold               | Minimum 2 available responders                                              |
| Minimum go-live agents                | Minimum 2, recommended 3+                                                   |
| Queue strategy                        | **Ring all available**                                                      |
| Ring all devices                      | Yes for emergency queue                                                     |
| Avoid busy responders                 | Yes                                                                         |
| Skip paused/offline                   | Yes                                                                         |
| Escalation timeout                    | 20 seconds recommended                                                      |
| Caller waiting audio                  | Emergency hold message, no music                                            |
| Hold music                            | Disabled for emergency calls                                                |
| Recording                             | Start recording from the beginning of the emergency call flow               |

---

# Feature 3: Emergency Fallback & Escalation Path

## Final Filled Decisions

| Area | Decision |
|---|---|
| Feature name | **Emergency Escalation Path** |
| ERT Lead escalation group | **ERT Lead Escalation** |
| Backup authority group | **Backup Emergency Authority Group** |
| Missed escalation logs | **Missed Escalation Records** |
| Final unanswered status | **Unanswered Critical Emergency** |
| First escalation target | ERT Lead role extension/fixed device |
| ERT Lead type | Role extension mapped to person/device |
| ERT Lead extension | **4101** recommended; final owner TBD |
| Timeout before ERT Lead | 20 seconds after primary queue timeout |
| Backup group members | Security Control Room, Medical Room, Warden/Admin Duty Officer |
| Backup group behavior | Ring all at once in Phase 1 |
| Backup timeout | 20 seconds |
| Drill escalation | Drill uses safe simulated escalation only; no real dispatch unless approved |
| Off-hours escalation | Same path in Phase 1; time-based routing later |
| Stop after answer | Yes, stop escalation once a responder answers |
| Unanswered destination | Emergency voicemail and critical dashboard alert |
| Disconnect without voicemail | No, unless caller hangs up before voicemail starts |
| Voicemail prompt | “No responder is currently available. Please state your name, location, and emergency clearly. Stay near your phone for a callback.” |
| Critical by default | Yes |
| Review owner | ERT Lead / Control Room Duty Officer |
| Required review time | Within 5 minutes during active hours; immediate during drills/pilot |
| Dashboard alert | Yes |
| Failed escalation log | Yes |
| Repeated caller grouping | Yes, group by SAP ID and time window |
| Hangup before prompt | Create missed emergency record even without voicemail |

---

# Feature 4: Emergency Call Recording & Incident Logging

## Final Filled Decisions

| Area | Decision |
|---|---|
| Recording name | **Emergency Call Recordings** |
| Log name | **Emergency Incident Logs** |
| Incident ID format | **`ERT-YYYYMMDD-0001`** |
| Recording file format | **`ERT-YYYYMMDD-0001_CALLER-SAPID_YYYYMMDD-HHMMSS.wav`** |
| 111 call log label | **`EMERGENCY_111_CALL`** |
| Missed record name | **Missed Emergency Incident** |
| Calls recorded by default | Only 111 and 199 emergency/drill flows |
| Student-to-student recording | No |
| Conference 9000 recording | Yes for activated incidents |
| Side-room recording | No by default; enable only if incident requires |
| Paging recording | Log paging; record audio only for real emergency broadcast if technically simple |
| Recording start | Immediately when 111 is dialed |
| Recording through transfer | Yes, continue through transfer/bridge where possible |
| Include hold time | Yes |
| Voicemail link | Same incident ID |
| Caller informed | Yes |
| Mandatory log fields | Incident ID, date/time, caller SAP ID, caller name, caller IP/device, caller role, answered by, queue wait, answer time, escalation attempts, transfer/bridge actions, final status, notes, recording path |
| Caller SAP ID/name | Yes |
| Device/IP | Yes |
| Fixed device location | Yes when fixed device calls |
| ERT responder identity | Yes |
| Answer/wait/escalation times | Yes |
| Transfer/bridge actions | Yes |
| Final status mandatory | Yes |
| Every 111 creates incident | Yes |
| False alarms logged | Yes, close as false alarm |
| Incident note editors | ERT Operator, ERT Lead, authorized Admin |
| Incident closer | ERT Lead or authorized Duty Officer |
| Recording retention | 90 days recommended; university may extend |
| Who can listen | ERT Lead, authorized Control Room Admin, approved university authority |
| Who can download | Restricted to authorized Admin/ERT Lead only |
| Access logging | Yes |
| Encryption at rest | Yes for recordings and backups |
| Backup recordings | Yes, under same retention/security policy |
| Deletion approval | ERT Lead + authorized university IT/admin approval |
| Auto deletion | Yes after retention, unless incident is flagged for preservation |
| Logs longer than audio | Yes, keep logs for 1 year recommended |
| University policy | Final retention/legal policy to be approved by UPES administration |

---

# Feature 5: Ready-made SIP Client Deployment

## Final Filled Decisions

| Area | Decision |
|---|---|
| Setup guide name | **UPES-ECS SIP App Setup Guide** |
| Recommended first SIP client | **Linphone** for Android/iOS; MicroSIP for Windows fixed/desktop testing |
| Student setup profile | **UPES-ECS Student Profile** |
| ERT setup profile | **UPES-ECS ERT Profile** |
| Fixed-device profile | **UPES-ECS Fixed Device Profile** |
| Android app | Linphone |
| iOS app | Linphone |
| Windows app | MicroSIP |
| macOS/Linux app | Linphone desktop or Jami/SIP client if tested; Linphone preferred for consistency |
| Same app where possible | Yes |
| ERT client | ERT may use controlled Linphone setup plus fixed IP phone |
| Physical IP phones for ERT/control room | Yes |
| Student self-install | Yes, guided self-install |
| Admin-assisted setup | Only for ERT/fixed devices and support cases |
| QR provisioning | Later enhancement |
| Server address | `pbx.upes.lan` preferred; static IP fallback TBD |
| Username | SAP ID |
| Password delivery | One-time secure delivery by portal, helpdesk, or sealed onboarding sheet |
| Password visibility | Visible once or resettable by authorized admin |
| User password changes | Allowed later through controlled reset flow; not direct Asterisk editing by users |
| Screenshots | Yes, per app/platform |
| Test number | `199` drill/test line plus optional echo test `198` |
| SAP ID dialing training | Yes |
| Directory/search | Later enhancement; CSV/contact list for pilot if needed |
| Setup support | UPES-ECS support/helpdesk runbook |

---

# Feature 6: Emergency Announcement & Paging

## Final Filled Decisions

| Area | Decision |
|---|---|
| Feature name | **Emergency Announcement & Paging** |
| All-campus broadcast | **All-Campus Emergency Broadcast** |
| Paging zones | Campus-wide, Academic Blocks, Hostels, Security Gates, Medical/ERT, Admin/Operations |
| Paging range | **700–799** |
| Paging log name | **Emergency Paging Attempt** |
| 700 | All-campus emergency broadcast |
| 701 | Academic blocks |
| 702 | Hostels |
| 703 | Security gates |
| 704 | Medical/ERT zone |
| 705 | Admin/operations zone |
| Missing zones | Finalize after campus role/location drill |
| Zone finalization | Finalize now as placeholder, validate after drill |
| Zone mapping | Functional areas first; buildings later |
| Who can page all campus | ERT Lead / Incident Commander only |
| Who can page hostels | ERT Lead, Warden-authorized role |
| Who can page academic blocks | ERT Lead / Control Room |
| Who can page security gates | ERT Lead / Security Control Room |
| Direct ERT paging | ERT members can request; ERT Lead/control room approves campus-wide paging |
| Students | Blocked from all paging |
| General staff | Blocked unless assigned emergency role |
| PIN requirement | Yes for high-risk paging codes, especially 700 |
| RBAC | Yes, context-based + PIN for critical zones |
| Log attempts | Yes, successful and denied attempts |
| Live/pre-recorded | Live only in Phase 1; pre-recorded later |
| Multilingual | Later enhancement |
| Paging recording | Log all; record real emergency paging if possible |
| Test frequency | Monthly paging test, with prior notice |
| Start phrase | “Attention. This is UPES Emergency Response.” |
| Approval | ERT Lead / Incident Commander |
| Drill prefix | Yes: “Drill, drill, drill.” |
| Unauthorized attempts | Logged as security/health warning |

---

# Feature 7: Incident Command Conference Rooms

## Final Filled Decisions

| Area | Decision |
|---|---|
| Main room name | **Main Incident Command Room** |
| 9000 name | **Main Incident Command Room** |
| 9001 | Security Coordination Room |
| 9002 | Medical Coordination Room |
| 9003 | Warden/Hostel Coordination Room |
| 9004 | Operations/Admin Coordination Room |
| 9000 range | Reserved for emergency conferences |
| Conference logs | **Incident Conference Logs** |
| 9000 as main room | Yes |
| Phase 1 rooms | 9000 mandatory; 9001–9004 staged but reserved |
| Side rooms | Enabled later or pilot-only if needed |
| PINs | 9000 and all side rooms should have PINs |
| Moderator | ERT Lead / Incident Commander |
| Join/leave tones | Enabled for awareness; disable if disruptive later |
| Participant limits | Yes, recommended 20 for 9000, 10 for side rooms |
| 9000 recording | Yes when activated for real incident |
| Side room recording | No by default |
| Availability | Always reachable to authorized roles; activation linked to incident in SOP |
| Link to incident IDs | Yes |
| 9000 access | ERT Lead, ERT Operators, Security, Medical, Warden/Admin emergency roles |
| Security room access | Security + ERT Lead/control room |
| Medical room access | Medical + ERT Lead/control room |
| Warden room access | Wardens + ERT Lead/control room |
| Operations room access | Admin/Operations + ERT Lead/control room |
| Students | No conference access |
| General staff | No, unless assigned emergency role |
| Unauthorized rejection | Yes, clear rejection tone/message |
| Failed joins logged | Yes |
| Control method | Context-based access + PIN |

---

# Feature 8: Emergency Responder Directory & Numbering Plan

## Final Filled Decisions

| Area | Decision |
|---|---|
| Directory name | **UPES-ECS Emergency Responder Directory** |
| Numbering document | **UPES-ECS Numbering Plan** |
| Fixed extensions | **Fixed Campus Extensions** |
| Service numbers | **Emergency Service Codes** |
| SAP ID extensions | **SAP ID Extensions** |
| Role-design drill | **Emergency Role Mapping Drill** |
| Roles in emergency directory | ERT Lead, ERT Operator, Security Control, Medical Room, Warden Duty, Admin/Operations, IT Support |
| Fixed locations | ERT room, security gates/control, medical room, hostel/warden desks, admin office, server/IT support |
| Service codes | 111, 112/911 aliases, 199, 700–705, 9000–9004, *45, *46 |
| All students in general directory | Yes eventually; Phase 1 can use SAP ID manual dialing/import |
| All staff in directory | Yes |
| Emergency vs student directory | Separate emergency directory and general user directory |
| Personal mobile numbers | No in SIP directory; keep external contact list separately under admin control |
| SIP-only directory | Yes for UPES-ECS user-facing directory |
| Room/location phones marked | Yes |
| Directory fields | Role, extension, location, permissions, owner, status |
| Fixed-device range | 4000–4999 |
| Emergency/service codes | 111, 112, 911, 199, *45, *46 |
| Paging range | 700–799 |
| Conference range | 9000–9099 |
| SAP IDs long? | Acceptable because SAP ID is official; support directory/search later |
| Short aliases | Yes for critical fixed devices |
| ERT desk short numbers | 4100–4199 |
| Medical room | 4200 |
| Security control room | 4300 |
| Student dialing | Direct SAP ID dialing enabled; contact search later |
| Role-design participants | ERT, Security, Medical, Wardens, Admin, IT/Network team |
| Approval owner | UPES administration + ERT Lead + IT owner |
| Directory maintainer | UPES-ECS Admin / IT support |
| Review cycle | Monthly in pilot; quarterly after stable rollout |
| Add/remove process | Change request approved by ERT Lead/IT Admin |
| Fixed-device ownership changes | Logged change request with location/owner update |
| Outdated entry detection | Monthly test calls + registration health checks |
| Published location | Local admin panel and controlled PDF/CSV for responders |

---

# Feature 9: Responder Status & Availability

## Final Filled Decisions

| Area | Decision |
|---|---|
| Feature name | **Responder Availability Status** |
| Status labels | Available, Busy, Offline, Paused, On Incident later |
| Pause/unpause codes | **Queue Pause / Queue Resume** |
| Dashboard name | **ERT Availability Dashboard** |
| SOP meaning of unavailable | Not currently eligible to receive emergency queue calls |
| Phase 1 statuses | Available, Busy, Offline, Paused |
| On Incident | Later enhancement |
| Field Responding | Later enhancement |
| Source of status | Asterisk status only in Phase 1 |
| Manual updates | Avoid in Phase 1 except pause/unpause |
| Self pause | Yes for ERT members |
| ERT Lead pause others | Yes |
| Pause reason | Optional in Phase 1; mandatory later through admin UI |
| Offline critical devices | Trigger health warning |
| Queue with zero responders | Still accept calls, immediately escalate and create alert |
| Pause code | `*45` |
| Unpause code | `*46` |
| Restrict codes | ERT users only |
| Log actions | Yes |
| Prevent accidental pause | Confirmation prompt recommended |
| Auto-unpause | Later enhancement; Phase 1 no auto-unpause unless agreed |
| Lead visibility | ERT Lead can see all paused/offline users |
| Direct calls while paused | Yes, pause only affects queue |
| Conferences while paused | Yes |

---

# Feature 10: Emergency Voicemail & Missed-call Recovery

## Final Filled Decisions

| Area | Decision |
|---|---|
| Voicemail name | **Emergency Voicemail** |
| Missed incident name | **Missed Emergency Incident** |
| Missed list | **Missed Emergency Review Queue** |
| Status labels | Pending Review, Reviewed, Callback Attempted, Converted to Active Incident, Closed as Duplicate, Closed as False Alarm |
| Prompt file | **`prompt_emergency_voicemail.wav`** |
| Unanswered calls to voicemail | Yes |
| Exact prompt | “No UPES Emergency Response member is available at this moment. Please state your name, SAP ID, location, and emergency clearly. Stay near your phone for a callback.” |
| Prompt mentions name/location/emergency | Yes |
| Ask caller to stay near phone | Yes |
| Max duration | 60 seconds |
| Caller says nothing | Save silent voicemail and mark Pending Review |
| Caller hangs up early | Create missed emergency record without voicemail |
| Link to incident ID | Yes |
| Critical by default | Yes |
| Restricted access | Yes |
| Review owner | ERT Lead / Control Room Duty Officer |
| Required review time | Within 5 minutes |
| Pending until reviewed | Yes |
| Callback mandatory | Yes when caller identity is known |
| Callback attempts logged | Yes |
| Closer | ERT Lead / authorized Duty Officer |
| Dashboard visibility | Yes |
| Repeated missed calls | Group by SAP ID/time window |
| Drill testing | Yes, drill voicemail records labelled drill only |

---

# Feature 11: Emergency Call Transfer & Dispatch Workflow

## Final Filled Decisions

| Area | Decision |
|---|---|
| SOP feature name | **Emergency Dispatch and Handoff Workflow** |
| Dispatch modes | Dispatch Without Transfer, Warm Transfer, Three-Way Bridge |
| Dispatch logs | **Emergency Dispatch Logs** |
| Handoff statuses | Pending, Accepted, Failed, Completed, Escalated |
| Incident ownership | **Incident Owner** |
| Supported modes | Dispatch without transfer, warm transfer, three-way bridge |
| Default mode | Dispatch without transfer |
| Preferred transfer | Warm transfer |
| Serious/unclear cases | Three-way bridge |
| Blind transfer | Disabled or strongly restricted |
| Warm transfer users | ERT Operators, ERT Lead |
| Three-way bridge users | ERT Lead and trained ERT Operators |
| Students transfer | No |
| Staff transfer | No by default; only emergency roles |
| Owner after answer | Answering ERT Operator becomes initial Incident Owner |
| Reassignment | Allowed after handoff confirmation |
| Reassign authority | ERT Lead / Incident Commander |
| Handoff confirmation | Logged note/status in incident timeline |
| Target no-answer | Return to ERT operator and escalate if needed |
| ERT stays on critical handoff | Yes |
| Dispatch logging | Mandatory |
| Direct transfer without explanation | No |
| Training | Required |
| Drill testing | Required |
| Required fields | Incident ID, source responder, target extension/team, target answer status, transfer type, bridge participants, timestamp, notes |
| Failed transfers | Logged as incident timeline events |
| Dispatch notes | Mandatory for real emergency dispatch |
| Recording timestamps | Link when technically available |
| Timeline | All dispatch events appear in incident timeline |
| Edit permission | ERT Lead / authorized Admin |

---

# Feature 12: LAN-only Infrastructure Boundary

## Final Filled Decisions

| Area | Decision |
|---|---|
| Boundary name | **UPES-ECS LAN Boundary** |
| Internal network | **UPES-ECS Campus LAN** |
| Local server name | **UPES-ECS PBX Server** |
| SIP domain | **`sip.upes.lan`** |
| Diagram title | **UPES-ECS LAN-only System Boundary** |
| LAN-only | Yes |
| Public internet dependency | No |
| External SIP trunk | No |
| PSTN calling | No |
| SMS/WhatsApp/email alerts | No in Phase 1 |
| Remote users | No outside-campus users in Phase 1 |
| Cloud PBX | No |
| Public SIP/RTP exposure | No |
| Core records stored locally | Yes |
| DNS/IP | Local DNS preferred; direct IP fallback documented |
| Allowed networks | Student Wi-Fi, staff Wi-Fi, ERT/control-room LAN, fixed-device LAN |
| Allowed SIP subnets | TBD from UPES IT network plan |
| Admin/monitoring subnet | Management/admin subnet only; not student Wi-Fi |
| Fixed device subnet | Fixed-device LAN/VLAN if available; otherwise static IP list |
| Student Wi-Fi access to Asterisk | Yes for SIP/RTP only |
| Guest Wi-Fi | Blocked |
| Management separation | Yes |
| Static IP for Asterisk | Yes, mandatory |
| DNS fallback | Yes |
| VLAN segmentation | Add later or immediately if UPES IT supports it |

---

# Feature 13: SIP Security & Access Control

## Final Filled Decisions

| Area | Decision |
|---|---|
| Role/context names | `ctx_student`, `ctx_staff`, `ctx_ert`, `ctx_ert_lead`, `ctx_control_room`, `ctx_fixed_device`, `ctx_admin` |
| Restricted attempts log | **Access Denied Event** |
| Students call 111 | Yes |
| Students call students | Yes |
| Students call staff/faculty | Yes only if approved; otherwise Phase 1 restrict to student-student + emergency |
| Students call fixed public campus phones | Yes for approved public/helpdesk/fixed devices |
| Students call ERT directly | No, use 111; direct ERT short numbers restricted |
| Students receive from ERT | Yes |
| Students join conferences | No |
| Students use paging | No |
| Students transfer calls | No |
| Students access recordings/voicemail | No |
| Staff call students | Yes if approved by university policy |
| Staff call staff | Yes |
| Staff call 111 | Yes |
| Staff call ERT directly | Restricted; emergency roles only |
| Staff use paging | No unless emergency role |
| Staff join conferences | Emergency roles only |
| Staff access recordings | No unless authorized |
| Special staff roles | Wardens, medical staff, security, admin duty officer, IT support |
| Staff default access | Similar to students plus staff-staff calling; special permissions by role |
| Receive 111 queue calls | ERT Operators, ERT desk phones, approved responders |
| Paging permission | ERT Lead/control room/security/warden as zone-appropriate |
| 9000 access | ERT Lead, ERT Operators, approved emergency roles |
| Voicemail review | ERT Lead/control room only |
| Recording access | ERT Lead/authorized admin only |
| Warm transfer | ERT Operators/ERT Lead |
| Three-way bridge | ERT Lead/trained ERT Operators |
| Pause/unpause queue | ERT members for self; ERT Lead for others |
| SIP account management | UPES-ECS Admin / IT admin |
| Health monitoring | ERT Lead, control room, IT admin |
| Anonymous SIP | Disabled |
| Unique credentials | Yes |
| Shared credentials | Banned except fixed devices |
| Password strength | Minimum 12 characters random; unique per account/device |
| Password delivery | One-time secure delivery/reset workflow |
| Lost devices | Immediately revoke/reset SIP credential |
| Failed registrations | Logged |
| Unknown devices | Block if possible; monitor initially |
| Abuse | Suspend account after review |
| Role elevation approval | ERT Lead + IT Admin/university authority |

---

# Feature 14: Device Provisioning & Extension Management

## Final Filled Decisions

| Area | Decision |
|---|---|
| Provisioning process | **UPES-ECS SIP Provisioning** |
| Human accounts | **SAP ID SIP Accounts** |
| Fixed device accounts | **Fixed Device SIP Accounts** |
| Service codes | **UPES-ECS Service Codes** |
| Onboarding guide | **UPES-ECS User Onboarding Guide** |
| Password reset | **SIP Credential Reset Process** |
| SAP ID as extension | Yes |
| SAP ID as username | Yes |
| SAP ID in caller ID | Yes |
| Full name in display | Yes |
| SAP ID changes | Old mapping archived; new SIP account created/migrated with history preserved |
| Student leaves | Disable account; keep logs/history |
| Staff leaves | Disable account; remove role permissions |
| Multiple devices per SAP ID | Yes |
| Max devices | 2 for students, 3 for ERT/staff; adjust after pilot |
| Monitor device count | Yes |
| Fixed range | 4000–4999 |
| Fixed naming | `Location-Role-Extension`, e.g., `Security-Control-4300` |
| Ownership | Assigned to department/role, not individual only |
| Physical location | Mandatory field |
| Request new extension | Department owner through IT/UPES-ECS Admin |
| Disable fixed device | IT Admin / ERT Lead approval |
| Static IPs | Yes for fixed phones where possible |
| Restricted dialing | Yes by role/context |
| Fixed caller ID location | Yes |
| Directory inclusion | Yes |
| Manual provisioning first | Yes |
| SAP import | CSV-based Phase 1 |
| Automation later | Yes |
| Password generation | Random generated secrets |
| Secure delivery | One-time reveal/reset process |
| QR setup | Later |
| OS/app guides | Yes |
| User support | UPES-ECS support/helpdesk |
| Password resets | IT Admin/helpdesk with authorization |
| Lost device revocation | IT Admin/helpdesk immediately resets SIP password |
| Account states | Pending Setup, Active, Disabled, Password Reset Required, Lost Device, Archived |
| State transitions | IT Admin/helpdesk; ERT Lead for emergency-role accounts |
| Disabled users retain logs | Yes |
| Extension reuse | Human SAP IDs not reused; fixed extensions reusable only after history archived |
| Ownership history | Preserved |
| Offboarding | Disable account, remove roles, preserve logs |
| Lost-device process | Reset password, force re-provision, log event |
| Abuse process | Temporarily disable, review, reinstate or keep suspended |
| Bulk import | CSV import with validation and backup |
| Audit/export | Monthly export of accounts, roles, fixed devices, service codes |

---

# Feature 15: Local Wi-Fi-first Infrastructure Readiness

## Final Filled Decisions

| Area | Decision |
|---|---|
| Feature name | **Local Wi-Fi-first Infrastructure Readiness** |
| Mobile-first path | **Mobile SIP over Campus Wi-Fi** |
| ERT fixed-device path | **ERT Fixed Response Path** |
| Diagram title | **UPES-ECS Local Infrastructure Diagram** |
| Pilot environment | **UPES-ECS Pilot LAN** |
| Router | TBD: record model/name during deployment |
| Switch | TBD: record model/name during deployment |
| Access point | TBD: record model/name during deployment |
| Asterisk server | Existing dedicated server; hostname `upes-ecs-pbx-01` |
| Server OS | Ubuntu Server LTS or Debian stable recommended |
| Server IP | TBD static IP |
| Static IP | Mandatory before pilot |
| Wi-Fi SSID | TBD by UPES IT |
| Client isolation | Must be checked and disabled/bypassed for SIP access to PBX |
| SIP/RTP LAN ports | Allow SIP signaling and RTP inside LAN only |
| Primary mobile app | Linphone |
| Pilot phones | Android first; iOS if available |
| Pilot user count | 10–25 users initial pilot |
| Simultaneous calls test | Minimum 5 normal calls + 2 emergency calls; increase after successful baseline |
| Student-to-student pilot | Yes |
| SAP ID login | Yes |
| Screen lock behavior | Must be tested; document battery/background restrictions |
| Background running | Users trained to keep SIP app registered/running |
| Mobile support | Setup guide + helpdesk support |
| Call quality evaluation | Registration success, call setup time, audio clarity, drop rate, jitter/latency |
| Fixed IP phones at launch | ERT room, security control, medical room recommended minimum |
| ERT answering location | UPES-ERT-ROOM / control room |
| ERT devices | Both IP phone and mobile SIP app |
| Medical fixed phone | Yes, extension 4200 |
| Security fixed phone | Yes, extension 4300 |
| Warden/admin fixed phones | Recommended if in pilot area |
| IP speakers | Later unless hardware already exists |
| Paging devices | Later or pilot-only |
| Mandatory go-live devices | PBX server, ERT answering device, at least 2 ERT SIP clients, security/medical fixed devices if included |
| Later devices | IP speakers, extra building phones, wardens/admin phones, QR provisioning kiosk |
| Registered users target | Pilot 25; scalable to all users after test |
| Simultaneous student calls | Pilot target 10; scale after LAN capacity testing |
| Simultaneous emergency calls | Pilot target 2–5 |
| ERT online devices | Minimum 2, recommended 3+ |
| Call quality | Clear two-way audio without frequent drops |
| Latency/jitter | Target under 150 ms one-way latency; low jitter; packet loss under 1% |
| Weak Wi-Fi | Move caller, use fixed phone, or ERT callback from nearest fixed device |
| AP overloaded | Escalate to IT; reduce pilot load; add AP/voice VLAN later |
| Emergency priority | Yes at dialplan/queue level; network QoS later if supported |
| Minimum rollout tests | Registration, SAP-ID calling, 111 queue, escalation, voicemail, recording, fixed devices, health check, backup/restore |

---

# Feature 16: Local System Health Monitoring

## Final Filled Decisions

| Area | Decision |
|---|---|
| Dashboard name | **UPES-ECS Health Dashboard** |
| Health statuses | OK, Warning, Critical, Offline |
| Daily readiness check | **Daily ECS Readiness Check** |
| Weekly drill report | **Weekly ECS Drill Health Report** |
| Failed check name | **Health Check Failure** |
| Local dashboard | Yes |
| CLI/script MVP | Acceptable for MVP if dashboard is not ready |
| Daily checker | IT/Admin duty owner or ERT control room assignee |
| Pre-drill checker | ERT Lead + IT owner |
| Critical devices | PBX server, ERT desk phone, ERT mobile clients, security phone, medical phone, AP/switch/router |
| Always-online registrations | ERT desk, ERT Lead, security control, medical room |
| Unhealthy system | PBX down, emergency queue unavailable, zero ERT devices, recording path failed, 111 test failed |
| Degraded system | Low ERT count, high failed registrations, high packet loss, one critical fixed phone offline |
| Ready system | PBX running, required registrations online, test 111/199 passes, recording/voicemail OK, backup recent |
| View health | ERT Lead, control room, IT admin |
| Check Asterisk | Yes |
| Check SIP registrations | Yes |
| Check queue availability | Yes |
| Check mobile registration | Yes |
| Check fixed phones | Yes |
| Check recording path | Yes |
| Check voicemail | Yes |
| Check disk usage | Yes |
| Check paging | Yes if enabled |
| Check conference rooms | Yes |
| Check access violations | Yes |
| Check test call | Yes |
| Disk warning | 75% usage |
| Disk critical | 90% usage |
| Min available ERT agents | 2 |
| Max queue wait | 20 seconds before escalation |
| Failed registrations threshold | Warning after repeated failures from same account/IP; Critical if ERT/fixed devices fail |
| AP/user load | TBD after AP model capacity; warning if pilot call quality degrades |
| Packet loss | Warning above 1%; critical above 3–5% during calls |
| Call setup time | Target under 3 seconds internal; warning over 5 seconds |
| Recording fails | Mark system degraded/critical and alert IT/ERT Lead |
| 111 test fails | Critical; do not go live until fixed |

---

# Feature 17: Emergency SOP & Drill Mode

## Final Filled Decisions

| Area | Decision |
|---|---|
| SOP name | **UPES-ECS Emergency Response SOP** |
| Drill Mode name | **UPES-ECS Drill Mode** |
| Test line name | **UPES-ECS Test Emergency Line** |
| Drill label | **DRILL-ONLY** |
| Post-drill review | **UPES-ECS Post-Drill Review Report** |
| ERT answer sentence | “UPES Emergency Response, this is [Name]. What is your emergency and where are you located?” |
| Mandatory questions | What happened? Exact location? Is anyone injured/in danger? Caller name/SAP ID? Callback extension? Is the situation ongoing? |
| Optional questions | Number of people involved, visible hazards, security/medical/fire need, nearest landmark, whether caller can stay on line |
| Incident categories | Medical, Security, Fire/Smoke, Accident/Injury, Violence/Threat, Infrastructure, Hostel/Warden, Other |
| Dispatch decision tree | Life/safety risk → dispatch immediately + bridge/9000 if needed; unclear → keep caller on line + three-way bridge; non-critical → dispatch without transfer + log |
| Paging allowed | Only when public safety announcement is needed |
| Paging approval | ERT Lead / Incident Commander |
| 9000 activation | Major incident, multi-team coordination, serious/unclear emergency |
| 9000 participants | ERT Lead, ERT Operator, Security, Medical, Warden/Admin as needed |
| Missed voicemail review | Check dashboard, listen, callback, convert/close, log result |
| Incident closure | ERT Lead/Duty Officer reviews notes and status before closure |
| Incident notes | ERT Operator writes initial notes; ERT Lead finalizes |
| Post-incident review | ERT Lead + relevant departments + IT if system issue |
| Response-time expectations | Answer within 20 seconds if possible; escalation after 20 seconds; missed callback within 5 minutes |
| If ERT unsure | Escalate to ERT Lead and keep caller on line |
| Test number | 199 |
| 199 simulates 111 | Yes |
| 199 avoids real escalation | Yes by default |
| 199 drill logs only | Yes |
| 199 recording | Yes, labelled drill |
| Who can call 199 | All authenticated users for setup testing; drill mode controlled by ERT |
| Drill frequency | Monthly basic drill; quarterly full scenario drill |
| Real 111 during drills | Only planned and announced; prefer 199 for routine testing |
| Paging drill notice | Required |
| Full drill approval | ERT Lead + university authority |
| Drill records | Kept |
| Drill failures | Create action items |
| Action item owner | ERT Lead for SOP issues, IT Admin for technical issues |
| Post-drill format | Scenario, participants, timings, pass/fail, issues, action items, owner, due date |
| Responder training | Setup training + SOP walk-through + periodic drills |

---

# Feature 18: Backup, Restore & Configuration Export

## Final Filled Decisions

| Area | Decision |
|---|---|
| Backup process name | **UPES-ECS Backup Procedure** |
| Backup snapshots | **ECS Snapshot YYYYMMDD-HHMM** |
| Config versions | **ECS Config Version** |
| Restore checklist | **UPES-ECS Restore Checklist** |
| Export files | **`upes-ecs-export-YYYYMMDD.zip`** |
| Local Git repo | **`upes-ecs-config`** |
| Back up Asterisk config | Yes |
| SIP account data | Yes |
| SAP mappings | Yes |
| Fixed device mappings | Yes |
| Dialplan | Yes |
| Queue config | Yes |
| Voicemail config | Yes |
| Prompts | Yes |
| Recordings | Yes, under retention policy |
| Logs | Yes |
| Health monitoring config | Yes |
| SOP/drill docs | Yes |
| Backup before config change | Yes |
| Daily config backup | Yes |
| Weekly logs export | Yes |
| Weekly directory export | Yes |
| Recording retention | Separate 90-day retention unless extended |
| Automatic rotation | Yes |
| Versions kept | Minimum 30 daily config backups + 12 weekly exports |
| Primary backup | Local server backup directory or NAS/TBD |
| Secondary backup | Encrypted offline USB/NAS/TBD |
| Encrypted offline copy | Yes |
| Who can restore | IT Admin + approved UPES-ECS owner |
| Restore instructions | Local admin docs + printed/offline copy |
| Acceptable restore time | MVP target under 1 hour for config-only restore |
| Restore order | OS/network → Asterisk config → SIP accounts → dialplan/queues → prompts/voicemail → logs/recordings as needed |
| Verification checklist | Service running, SIP registrations, test 199, test 111, recording, voicemail, queue, fixed phones, backup status |
| Restore after major changes | Yes |
| Restore test frequency | Quarterly recommended; monthly during pilot |
| Sign-off | IT Admin + ERT Lead |
| Backup failure | Critical alert; fix before config changes/go-live |
| Restore failure | Escalate to IT lead, use previous snapshot/manual rebuild plan |
| Backup encryption | Yes |
| Encrypted backup scope | Recordings, logs, SIP account data, SAP mapping, full exports |
| Backup access | IT Admin and approved university authority only |
| Credential storage | Secrets manager/offline sealed credential store; not plain text in docs |
| Recordings in backup | Yes, encrypted |
| SIP passwords | Stored as secrets/hashes/config backups with restricted access |
| Backup access logging | Yes |
| Offline media security | Physically locked |
| Deletion approval | IT Admin + university authority/ERT Lead |
| Retention policy | Config 30 daily + 12 weekly; logs 1 year; recordings 90 days unless preserved |

---

# Final Cross-feature Decisions

## Go-live Decisions

| Question | Filled Decision |
|---|---|
| Minimum feature set before pilot | SIP registration, SAP ID dialing, 111 queue, ERT answering, escalation, voicemail, recording, basic logs, fixed ERT/security/medical devices, health check, backup |
| Must be fully tested | 111, 199, queue, escalation, voicemail, recording, access restrictions, fixed devices, backup/restore |
| Staged later | QR provisioning, full directory UI, multilingual prompts, IP speakers, VLAN/QoS, shift automation, advanced dashboard |
| Pilot users | 10–25 users |
| ERT pilot members | Minimum 2, recommended 3+ |
| Mandatory fixed devices | ERT room phone, security phone, medical phone if those teams are part of pilot |
| Pilot buildings/areas | Start with ERT room + one academic area + one hostel/security/medical path if possible; final locations TBD |
| Go-live date | TBD after successful pilot |
| Go-live approval | UPES administration + ERT Lead + IT owner |
| Rollback conditions | 111 fails, queue unavailable, recording fails, PBX unstable, Wi-Fi unable to support calls, unauthorized access risk, no available ERT coverage |

## Phase 1 Success Criteria

| Success Criterion | Target Decision |
|---|---|
| Mobile SIP registration over Wi-Fi | Must pass |
| SAP ID to SAP ID calling | Must pass |
| Any authenticated user can call 111 | Must pass |
| 111 reaches ERT queue | Must pass |
| Escalation works | Must pass |
| Emergency voicemail works | Must pass |
| Recording for 111 works | Must pass |
| Student calls not recorded by default | Must pass |
| Paging restricted | Must pass if paging enabled |
| Conference rooms restricted | Must pass |
| Dispatch transfer/bridge works | Must pass for ERT pilot |
| Health checks work | Must pass at least script/CLI level |
| Backup/restore works | Must pass config restore test |
| Drill mode safe | Must pass using 199 |
| SOP understood | Must pass responder drill/training |

---

# Documents to Create After This Decision Set

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

---

# Open TBD Items You Must Collect From UPES/IT

| Item | Why Needed |
|---|---|
| Router model/name | Capacity, firewall, VLAN/QoS support |
| Switch model/name | PoE/IP phone/VLAN support |
| Access point model/name | SIP over Wi-Fi capacity and client isolation behavior |
| Asterisk server specs | Capacity and backup planning |
| Asterisk server OS | Installation and support plan |
| Static server IP/subnet/gateway | SIP client configuration |
| Campus Wi-Fi SSID | Student setup guide |
| Whether client isolation is enabled | SIP/RTP connectivity requirement |
| Allowed subnets | Firewall/access-control rules |
| Final ERT member list | Queue membership |
| Final fixed-phone locations | Numbering and device provisioning |
| University recording retention policy | Legal/admin compliance |
| Go-live approval authority | Operational sign-off |
