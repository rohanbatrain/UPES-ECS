# UPES-ECS Student & Staff SIP Setup Guide

Set up your phone to make **campus emergency and internal calls over Wi-Fi** — no
SIM, no data plan, no internet needed. Works anywhere on the UPES campus network.

> **In an emergency, just dial `111`.** That's all you ever need to remember.

---

## What you'll need

- Your phone on the **campus Wi-Fi** (TBD: SSID confirmed by UPES IT).
- Your **SAP ID** — this is your phone number on this system.
- Your **UPES-ECS password** — delivered to you once, securely (portal / helpdesk / onboarding sheet).
- The free **Linphone** app (Android / iOS). Windows PC users: **MicroSIP**.

---

## Step 1 — Install the app

| Device | App | Where |
|---|---|---|
| Android | **Linphone** | Play Store |
| iPhone / iPad | **Linphone** | App Store |
| Windows PC | **MicroSIP** | microsip.org |
| Mac / Linux | **Linphone** | linphone.org |

---

## Step 2 — Connect to campus Wi-Fi

Connect your phone to the campus Wi-Fi network first. The system **only works on the
campus network** — this is intentional, so it keeps working during emergencies.

---

## Step 3 — Log in with your SAP ID

Open Linphone → **Assistant / Use SIP Account** and enter:

```text
Username     : <your SAP ID>          e.g. 500120597
Password     : <your UPES-ECS password>
Domain / SIP : pbx.upes.lan           (or the IP given by IT)
Transport    : UDP  (unless IT tells you otherwise)
Display name : Your Name              e.g. Rohan Batra
```

> MicroSIP (Windows): **Add Account** → SIP Server / Domain `pbx.upes.lan`,
> Username = SAP ID, Password = your password, Display name = your name.

When it shows **Registered / Connected (green)**, you're ready.

---

## Step 4 — Test it (do this now, not during an emergency)

1. Dial **198** → you should hear your own voice echoed back (mic + speaker OK).
2. Dial **199** → the drill/test line. Safe to try. It will **not** dispatch any real response.
3. Dial another student's **SAP ID** to make a normal call.

If any test fails, see **Troubleshooting** below.

---

## How to use it

| To do this | Dial |
|---|---|
| **Emergency — reach UPES Emergency Response** | **111** |
| Call another student / staff member | their **SAP ID** |
| Test your setup safely | **199** (drill) or **198** (echo) |

**When you dial 111:**
1. You'll hear a short message; the call may be recorded.
2. Trained UPES Emergency Response answers.
3. Tell them **what happened and exactly where you are.**
4. Stay on the line if it's safe to.

---

## What you can and can't do

**You can:** call 111, call other students/staff, receive calls, test with 199/198.

**You can't** (these are for the Emergency Response Team only): campus paging,
incident conference rooms, listening to recordings. This keeps the emergency system
safe and prevents panic.

**Your privacy:** normal student-to-student calls are **not recorded**. Only calls to
**111** (and **199** drills) are recorded, for emergency accountability.

---

## Keep it working

- Keep the app **running/registered** in the background (allow background + battery exceptions).
- Allow **microphone** permission.
- Stay on **campus Wi-Fi** — the system won't work off-campus (by design).
- If your call quality is poor, move to a stronger Wi-Fi spot or use a nearby fixed phone.

---

## Troubleshooting

| Problem | Try this |
|---|---|
| Not "Registered" | Confirm you're on campus Wi-Fi; re-check SAP ID, password, and domain `pbx.upes.lan`. |
| Can't reach the server | Wi-Fi "client isolation" may be blocking you — report to UPES-ECS helpdesk. |
| One-way / no audio | Grant mic permission; try a stronger Wi-Fi location. |
| Call drops when screen locks | Enable background running + disable battery optimisation for the app. |
| Forgot / lost password | Contact the **UPES-ECS helpdesk** for a secure reset. Never share your password. |

---

## Rules

- Your account is **yours** — don't share credentials. Misuse is traceable and can be suspended.
- Don't misuse **111**. It's for real emergencies. Use **199** to test.
- Lost your phone? Tell the helpdesk immediately so your credential can be reset.

**Emergency = Dial 111. On UPES-ECS.**
