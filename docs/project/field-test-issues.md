# Field-Test Issues & Production Mitigations

Engineering write-up of the SIP / registration / audio issues hit during a **live
multi-phone field test** of UPES-ECS, and the production-grade fixes that stop each one
recurring at scale.

**Context of the test**

| Item | Value |
|---|---|
| System | UPES-ECS — LAN-only campus emergency phone system on **Asterisk (PJSIP)** |
| Deployment under test | Asterisk in a **QEMU VM** on a Windows "van laptop", QEMU **user-mode NAT (SLIRP)** + port-forward |
| PBX reachable IP (this test) | **`192.168.1.16`** : UDP `5060`, forwarded RTP `10000–10019` |
| Endpoints | Real Android phones running **Linphone** on campus Wi-Fi |
| Testers (real roster) | Rohan Batra `500120597`, Student Example Two `500000002`, Student Example Three `500000003`, Student Example Four `500000004`; staff e.g. Staff Member One `40000001` |
| Server codecs / media | **G.711 only** (`ulaw`/`alaw`), **plain RTP** (no SRTP configured) |

> **How to read this doc.** Each issue is written as **Symptom → Root cause → Immediate
> fix (what we did in the field) → Production mitigation (how to prevent it entirely at
> scale)**. The build-time roadblocks that pre-date this test live in
> [Roadblocks-and-Solutions.md](roadblocks-and-solutions.md); this doc is the *field-test*
> companion and cross-references it where the same root cause recurs.

Related documents:
[SOP 05 – Student SIP Setup Guide](../guides/student-sip-setup.md) ·
[SOP 14 – Device Provisioning Sheet](../guides/device-provisioning.md) ·
[SOP 24 – Mobile App Reliability & Battery](../reference/mobile-app-reliability.md) ·
[QEMU deployment README](https://github.com/rohanbatrain/UPES-ECS/blob/main/deploy/qemu/README.md) ·
[config/extensions_custom.conf](https://github.com/rohanbatrain/UPES-ECS/blob/main/config/extensions_custom.conf) ·
[deploy/asterisk/pjsip.conf](https://github.com/rohanbatrain/UPES-ECS/blob/main/deploy/asterisk/pjsip.conf) ·
[Roadblocks-and-Solutions.md](roadblocks-and-solutions.md)

---

## Issue 1 — Registration hangs on "Operation in progress" (wrong transport)

**Symptom.** A phone opened Linphone, entered SAP ID + password + domain, and the account
sat forever on **"Operation in progress…"** and never went green/Registered. No error, no
timeout, just a hang. On the server there was **zero trace** of the phone.

**Root cause.** Linphone defaulted the account **Transport** to **TLS** (or TCP). The
UPES-ECS test server is **UDP-only** (`transport-udp`, `bind=0.0.0.0:5060`, protocol
`udp` — see [deploy/asterisk/pjsip.conf](https://github.com/rohanbatrain/UPES-ECS/blob/main/deploy/asterisk/pjsip.conf)). The phone's
`REGISTER` was sent over a transport the server never listens on, so it got **no reply**
and the client just kept "in progress." Because nothing UDP left the phone for 5060, **not
a single SIP packet reached the PBX** — from the server's point of view the phone did not
exist.

**Immediate fix (field).** Forced the account transport to **UDP**:

- In Linphone: **Account → Transport = UDP**, or
- Encode it in the domain/proxy: `192.168.1.16;transport=udp`

The phone registered within a second and went green.

**Production mitigation.**

1. **Provision, don't ask users to pick.** Ship a **pre-built Linphone profile / QR /
   `.rc` config file** (see [Section A](#a-production-phone-provisioning-do-it-once-right))
   so the transport is baked in and no user ever chooses TLS/TCP by hand. This is the
   single highest-value fix — it removes the entire class of "wrong transport" errors.
2. **Or** stand up **TLS + SRTP properly** and standardize on it end-to-end (server cert,
   `transport-tls`, matching endpoints, phones provisioned for TLS). Do this *only* if you
   commit to it fully — a half-configured TLS server is exactly what produced this hang.
3. **Document the exact Linphone settings** (table in Section A) and treat "Transport =
   UDP" as a hard field, not "unless IT tells you otherwise."
4. **Validate reachability first.** Step 1 of onboarding is **`ping 192.168.1.16`** (or the
   site PBX IP) from the phone's network tools — prove L3 reachability *before* debugging
   SIP. See the runbook.

Related: [SOP 05 – Student SIP Setup Guide](../guides/student-sip-setup.md) (the
Transport line there must read **UDP**, not "unless IT tells you otherwise").

---

## Issue 2 — `+91` country code auto-prepended to SAP IDs

**Symptom.** A tester dialed another student's SAP ID (e.g. `500120597`) and the call
**failed / hit no such extension**, even though both phones were registered. The call log
showed the dialed number as **`+91500120597`**.

**Root cause.** Linphone's **international prefix / dial-plan (dial assistant)** feature
was on. It treats dialed strings as phone numbers and **auto-prepends the country code
`+91`**. UPES-ECS extensions are **SAP IDs, not phone numbers** — `+91500120597` matches no
extension pattern (`_5XXXXXXXX` expects exactly the 9 digits), so the dialplan rejected it.

**Immediate fix (field).** Two-sided fix:

- **Server** — added a strip rule to `ctx_student` so a mis-dialed `+91…` is normalized
  back to the bare extension (now committed in
  [config/extensions_custom.conf](https://github.com/rohanbatrain/UPES-ECS/blob/main/config/extensions_custom.conf)):

  ```asterisk
  ; strip the +91 country code some softphones auto-prepend, then re-enter
  exten => _+91X.,1,Goto(${EXTEN:3},1)
  exten => _5XXXXXXXX,1,Dial(PJSIP/${EXTEN},30)   ; student-to-student
   same => n,Hangup()
  ```

  `${EXTEN:3}` drops the 3-character `+91` prefix and re-enters the dialplan at the real
  SAP ID.
- **Client** — disabled the **country / international prefix** in the phone's Linphone
  settings so it stops mangling the dialed digits in the first place.

**Production mitigation.**

1. **Ship the strip rule by default.** The `_+91X.` normalizer is now in the reference
   dialplan and belongs in every deployment's `ctx_student` (and any context students dial
   from) as a safety net.
2. **Disable the international prefix in the provisioned profile** so the client never
   prepends `+91` — belt *and* suspenders with rule 1.
3. **Consider an explicit numbering-vs-dialing scheme.** SAP IDs are identifiers, not
   E.164 numbers; the provisioning profile should mark the account as "not a phone number"
   (no dial assistant, no prefix) so no OS/app "helpfully" reformats it.

---

## Issue 3 — "Connected but no voice" on a phone-to-phone call (NAT media)

**Symptom.** Two registered phones placed a call. **Signalling worked** — it rang, both
sides showed **Connected** — but **neither side heard the other** (dead air, both ways).

**Root cause — QEMU SLIRP NAT + direct media.** The PBX runs behind **QEMU user-mode
networking (SLIRP)**, a user-mode NAT. Asterisk, by default, tries **direct media**: once
the call is up it sends a **re-INVITE** telling the two phones to stream **RTP directly to
each other**, taking the PBX out of the media path. Behind SLIRP that fails:

- Asterisk (and the phones) advertise addresses in SDP that the **NAT rewrites or that are
  simply not routable** between the two clients as the PBX described them.
- SLIRP **hides real client IPs** from the guest, so the addresses handed to each phone for
  "send your audio here" are wrong. Signalling (which the PBX relays) is fine; **media
  (which it told the phones to send peer-to-peer) goes into a black hole.**

This is the same class of problem as build-time roadblock **1.6** (SLIRP hides real client
IPs) in [Roadblocks-and-Solutions.md](roadblocks-and-solutions.md#16-hosting-a-sip-server-behind-qemu-user-mode-nat-slirp)
and **1.1** (container NAT mangles RTP).

**Immediate fix (field).** Force the PBX to **relay** the RTP (stay in the media path) and
tell it its real reachable address. On the endpoint template in
[deploy/asterisk/pjsip.conf](https://github.com/rohanbatrain/UPES-ECS/blob/main/deploy/asterisk/pjsip.conf):

```ini
[endpoint-tpl](!)
type=endpoint
disallow=all
allow=ulaw
allow=alaw
rewrite_contact=yes
rtp_symmetric=yes      ; return media to where it actually came from (Wi-Fi/NAT)
force_rport=yes        ; reply to the source port, not the SDP-claimed port
direct_media=no        ; <-- RELAY RTP through the PBX; do NOT re-INVITE peers together

[transport-udp]
; the PBX's reachable LAN IP so Asterisk advertises the right address to phones
external_media_address=192.168.1.16
external_signaling_address=192.168.1.16
```

Plus a **fixed, forwarded RTP range `10000–10019`** (`rtp.conf`) so the media ports are the
ones the QEMU port-forward + firewall actually open. With `direct_media=no` the two phones
each talk RTP **only to the PBX**, and the PBX bridges — no peer-to-peer path through SLIRP
is ever attempted. Audio came up both ways immediately.

**Production mitigation.**

1. **Run the production PBX natively / bridged with a real LAN IP.** The whole media
   problem is an artifact of **SLIRP user-mode NAT**. Deploy Asterisk on the **van's own
   Linux box** (or the VM on **bridged networking** with a TAP adapter) so it pulls its
   **own DHCP LAN address** and sits on the LAN as a first-class host. That **removes SLIRP
   entirely** and with it this entire class of NAT-media failures — no `external_*_address`,
   no port-forward, no fixed-range juggling. This is already flagged as the "truly
   zero-touch" target in the [QEMU deployment README](https://github.com/rohanbatrain/UPES-ECS/blob/main/deploy/qemu/README.md).
2. **On native/bridged, `direct_media` can even be re-enabled** (phones on the same flat LAN
   can legitimately talk peer-to-peer), reducing PBX CPU/bandwidth — but keep
   `direct_media=no` unless you have a specific reason and have tested it, because relaying
   is the robust default across Wi-Fi client-isolation and NAT.
3. **Standardize `Media encryption = None`.** The server offers **plain RTP**. If a phone
   insists on SRTP/ZRTP and the server does not, media negotiation breaks (see Issue 5).
   Provision **encryption = None** everywhere *unless* SRTP is configured **end-to-end**.

---

## Issue 4 — One phone "couldn't register" while another worked (per-phone config)

**Symptom.** On the same Wi-Fi, at the same time, one tester's phone registered fine while
another's **would not register** — despite identical network conditions.

**Root cause.** Because **ping to the failing phone worked** and other phones on the same
subnet registered, the **network was ruled out**. The fault was **per-phone config**: a
wrong **transport** (Issue 1), a **typo** in SAP ID / password / domain, or a stale
international-prefix setting (Issue 2) — an individual-device problem, not an infrastructure
one.

**Immediate fix (field).**

1. Confirmed L3 reachability: **`ping 192.168.1.16`** from the phone and **ping the phone**
   from the laptop — both succeeded, so the LAN was fine.
2. Verified the **on-file password** for that SAP ID against the roster.
3. **Forced Transport = UDP** and corrected the typo → registered.

**Production mitigation.**

1. **Profile / QR provisioning removes per-phone manual error.** If SAP ID, password,
   domain, and transport come from a **scanned config**, there is nothing to typo. See
   [Section A](#a-production-phone-provisioning-do-it-once-right) and
   [SOP 14 – Device Provisioning Sheet](../guides/device-provisioning.md).
2. **A reachability + registration self-test is the onboarding gate.** Before a device is
   marked **Active**, it must pass: `ping PBX` → **Registered (green)** → **dial 198**
   (echo) → **dial 199** (drill) → **dial 111** (or a directory SAP ID). No green + no echo
   = device is not provisioned, regardless of what the user says.

---

## Issue 5 — Media-encryption / codec mismatch risk

**Symptom (risk class).** A call **connects** (signalling completes, both sides say
Connected) but there is **no audio or one-way audio** — not because of NAT (Issue 3) but
because the two ends could not agree on **how** to encode/encrypt the media.

**Root cause.** UPES-ECS servers **allow only G.711** (`disallow=all; allow=ulaw;
allow=alaw`) and offer **plain RTP** (no SRTP). If a phone is configured to offer **only**:

- a **codec the server does not allow** (e.g. Opus/G.729-only), or
- **mandatory SRTP/ZRTP** while the server speaks plain RTP,

then SDP negotiation yields **no common media** → the call sets up on signalling but the
audio stream never establishes (or one leg does and the other doesn't).

**Immediate fix (field).** Not hit as a hard failure in this test (Linphone offered G.711
+ plain RTP by default once transport/NAT were fixed), but called out because it is the
next failure mode if a phone's media settings drift.

**Production mitigation.**

1. **Standardize codecs in the provisioned profile: G.711 (`ulaw`/`alaw`) only** — match
   the server exactly. Leaving Opus enabled is harmless *if* G.711 is also offered, but the
   safe default is to pin G.711.
2. **Standardize `Media encryption = None`** to match the plain-RTP server — or configure
   **SRTP end-to-end** and provision SRTP on every phone. Never leave it mixed.
3. **Document both** in the settings table (Section A) so a re-imaged phone is rebuilt
   identically.

---

## Issue 6 — Battery / background suspension silently deregisters the app

**Symptom.** A phone that registered fine **stopped ringing for incoming calls** after
sitting idle / locked for a while. Outbound (open app, dial 111) still worked; **incoming
ERT callbacks never rang.**

**Root cause.** Android **battery optimization / background app suspension** froze or killed
the SIP app, which **dropped its SIP registration**. With no live registration the PBX has
no contact to ring — so inbound calls (exactly the ERT-callback path) silently fail. This
is **Risk R2** and the whole reason [SOP 24](../reference/mobile-app-reliability.md)
exists.

**Immediate fix (field).** Applied the per-OS battery/background exceptions (Unrestricted,
allow background, allow auto-start, don't swipe-kill) and re-registered the app.

**Production mitigation.**

1. **Follow the per-OS steps in
   [SOP 24 – Mobile App Reliability & Battery](../reference/mobile-app-reliability.md)**
   — summarized in [Section B](#b-keep-the-phone-registered-battery--background).
2. **Dedicated always-on-charger answer points.** Critical inbound roles (ERT, control
   room, medical, security) run on **fixed dedicated Android devices on the charger**, not
   personal phones — treat them like appliances (SOP 24 §6, and
   [SOP 14 §3](../guides/device-provisioning.md)).
3. **Tune keepalive / register expiry server-side** so drops are detected fast and the
   registration path stays warm:

   | PJSIP setting | Recommended | Why |
   |---|---|---|
   | `qualify_frequency` | ~30–60 s | Keepalive OPTIONS keep the NAT path open + detect a dead endpoint quickly |
   | Registration expiry | ~120–300 s | Short enough to notice a drop, long enough to avoid re-REGISTER thrash |
   | `rewrite_contact` | `yes` | Replies reach the phone's actual source address on Wi-Fi/NAT |
   | `rtp_symmetric` / `force_rport` | `yes` | Media/replies return to where packets really came from |

---

## A. Production phone provisioning (do it once, right)

Every config issue above (1, 2, 4, 5 — and the *setting* half of 6) collapses to the same
root cause: **a human typed or picked a setting by hand.** The production answer is to
**provision the phone from a controlled artifact** so the user never touches transport,
prefix, codec, or encryption.

### A.1 Ship a pre-built account artifact

Deliver one of these instead of a written setup sheet:

| Method | What it is | Best for |
|---|---|---|
| **QR / config-URI** | Linphone opens `linphone-config://…` (or scanned QR) that imports the account | Fast per-user onboarding at a desk |
| **`.rc` / provisioning file** | A Linphone remote-provisioning `.rc` fetched at first launch (account + transport + codecs + encryption baked in) | Fleet / bulk rollout |
| **Pre-configured device image** | Dedicated fixed-role Androids imaged identically | ERT / control-room appliances |

The artifact **must** set: **Domain** = site PBX IP (`192.168.1.16` in this test),
**Transport = UDP**, **Media encryption = None**, **codecs = G.711 (ulaw/alaw)**,
**international/dial-assistant prefix OFF**. Credentials (SAP ID + one-time secret) come
from [SOP 14](../guides/device-provisioning.md); secrets are per-account, never a
shared password.

### A.2 Onboarding self-test (the gate to "Active")

A device is not **Active** until it passes, in order:

```text
1. ping <PBX IP>            -> L3 reachable        (e.g. ping 192.168.1.16)
2. app shows Registered     -> green / Connected
3. dial 198  (echo)         -> hear your own voice  => mic + speaker + media path OK
4. dial 199  (drill)        -> drill prompt         => dialplan reachable, NO real dispatch
5. dial 111 or a SAP ID     -> reaches ERT / peer   => two-way audio confirmed
```

Record the result per device model (some Android brands need the SOP 24 battery steps
before step 2 will *stay* green). This mirrors [SOP 05 Step 4](../guides/student-sip-setup.md).

### A.3 The exact correct Linphone settings

| Setting | Correct value | Why (which issue it prevents) |
|---|---|---|
| **Username** | your **SAP ID** (e.g. `500120597`) | Identity = extension (SOP 14) |
| **Password** | your one-time UPES-ECS secret | Per-account, never shared |
| **Domain / SIP proxy** | site PBX IP — **`192.168.1.16`** in this test (`pbx.upes.lan` where DNS exists) | Reachability |
| **Transport** | **UDP** | Issue 1 — server is UDP-only |
| **Media encryption** | **None** | Issue 3 / 5 — server is plain RTP |
| **Audio codecs** | **G.711 only** — `ulaw` (PCMU) + `alaw` (PCMA) | Issue 5 — server allows only G.711 |
| **International / country prefix (dial assistant)** | **OFF / disabled** | Issue 2 — no `+91` prepend |
| **Register expiration** | ~120–300 s | Issue 6 — drop detection vs. thrash |
| **Background / battery** | app Unrestricted, auto-start on | Issue 6 / SOP 24 |

> **One-line domain form that pins the transport regardless of the UI:**
> `500120597@192.168.1.16;transport=udp`

---

## B. Keep the phone registered (battery & background)

Full detail lives in
**[SOP 24 – Mobile App Reliability & Battery](../reference/mobile-app-reliability.md)**
(Risk **R2**). This is a pointer + the essentials — **do not treat this as the source of
truth; SOP 24 is.**

**The 7 essential rules (SOP 24 §1):**

1. **Allow background running** for the SIP app.
2. **Turn OFF battery optimization** — set the app to **Unrestricted**.
3. **Allow auto-start / start-on-boot.**
4. **Don't swipe-kill** the app from recents.
5. **Allow microphone + notifications** permissions.
6. **Stay on campus Wi-Fi** (LAN-only by design).
7. **Keep the phone charged** — dead phone = no emergency line.

**Per-brand pointers (SOP 24 §2 has the full steps):**

| Brand | Key setting |
|---|---|
| **Samsung (One UI)** | Add Linphone to **Never sleeping apps**; ensure it is not in Sleeping/Deep-sleeping apps |
| **Xiaomi / Redmi / POCO** | **Autostart ON** + battery **No restrictions**; lock the app in recents |
| **Oppo / Realme / OnePlus / Vivo / iQOO** | Allow **auto-launch / auto-start** + allow background activity; disable sleep-standby optimization |

> **Inbound is never 100% guaranteed on a personal phone.** Critical answer points (ERT,
> control room, medical, security) run on **dedicated always-on-charger devices** —
> SOP 24 §6 and [SOP 14 §3](../guides/device-provisioning.md). See SOP 24 for iOS
> guidance and the per-phone pilot checklist.

---

## Field troubleshooting runbook

Fast triage for the live-test symptoms above. Work top-to-bottom; most faults are transport,
NAT-media, or battery.

| Symptom | Quick check | Fix |
|---|---|---|
| **Won't register** ("Operation in progress" / not green) | `ping <PBX IP>` from the phone; is **Transport = UDP**?; SAP ID + password + domain correct? | Force **Transport = UDP** (`…@192.168.1.16;transport=udp`); correct typos; confirm campus Wi-Fi. Issue 1 / 4 |
| **Registers then can't place calls** (no such extension) | Look at the *dialed* number in the log — is it `+91…`? | Disable Linphone **international prefix**; server strip rule `_+91X. → ${EXTEN:3}` (already in dialplan). Issue 2 |
| **Connected but no voice** (both ways dead) | Is the PBX behind **QEMU SLIRP NAT**? Is `direct_media` off? | Set `direct_media=no`, `external_media_address=<PBX IP>`, `rtp_symmetric=yes`, `force_rport=yes`, fixed RTP `10000–10019`. Long-term: **native/bridged LAN IP**. Issue 3 |
| **One-way audio** | Codec/encryption offer vs. server (**G.711 + plain RTP**)? Wi-Fi client-isolation? | Provision **encryption = None**, **G.711 only**; confirm `rtp_symmetric=yes`; check AP client-isolation. Issue 5 / 3 |
| **Drops / won't ring when phone locked** | App still **Registered** after idle? Battery optimization on? | Apply SOP 24 battery steps (**Unrestricted**, auto-start, don't swipe-kill); use a fixed charger device for critical roles. Issue 6 |
| **`+91` prepended to a SAP ID** | Dialed string shows `+91` in front | Turn OFF the **country / dial-assistant prefix** in Linphone; server `_+91X.` strip is the safety net. Issue 2 |

---

*This log covers the SIP/registration/audio issues that actually occurred during the live
multi-phone field test, with production mitigations. It is the field-test companion to
[Roadblocks-and-Solutions.md](roadblocks-and-solutions.md) and is maintained alongside the
config it references —
[deploy/asterisk/pjsip.conf](https://github.com/rohanbatrain/UPES-ECS/blob/main/deploy/asterisk/pjsip.conf),
[config/extensions_custom.conf](https://github.com/rohanbatrain/UPES-ECS/blob/main/config/extensions_custom.conf).*
