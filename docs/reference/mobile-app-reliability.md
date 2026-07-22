# UPES-ECS Mobile App Reliability & Battery Best Practices

How to keep the SIP app **registered and reachable** so emergency calls — especially
**incoming ERT callbacks** — actually work on a phone. Addresses Risk **R2**.

> **Why this matters:** dialing *out* to 111 always works when you open the app.
> The weak spot is *incoming* — phone OSes aggressively kill background apps to save
> battery, which silently logs the SIP app out. Then an ERT callback never rings.
> These settings prevent that.

> **Provision the app, don't hand-configure it.** Registration/transport/encryption/codec
> errors (wrong transport, `+91` prefix, SRTP mismatch) are best eliminated with a
> **pre-built Linphone profile / QR / `.rc` config** — standardize **Transport = UDP**,
> **Media encryption = None**, and **G.711** once, so no user picks them wrong. See
> [Field-Test Issues & Mitigations](../project/field-test-issues.md).

---

## 1. The 7 rules everyone must follow

1. **Allow background running** for the SIP app (Linphone / MicroSIP).
2. **Turn OFF battery optimization** for the app (set it to "Unrestricted").
3. **Allow auto-start** / start-on-boot.
4. **Don't swipe-kill** the app from recents — leave it running.
5. **Allow microphone + notifications** permissions.
6. **Stay on campus Wi-Fi** (the system is LAN-only).
7. **Keep the phone charged** — dead phone = no emergency line.

Print these as a card for pilot users. The per-OS steps below make rules 1–3 stick.

---

## 2. Android (brand-specific — this is where phones differ)

Android battery savers vary a lot by manufacturer. Do the generic steps **and** the
brand steps.

**Generic (all Android):**
- Settings → Apps → **Linphone** → **Battery** → **Unrestricted** (not "Optimized").
- Settings → Apps → Linphone → **Allow background activity** → ON.
- Turn OFF "**Remove permissions / pause app if unused**."
- Lock the app in the recents view if your phone supports it.

**Samsung (One UI):**
- Settings → Battery → **Background usage limits** → add Linphone to **Never sleeping apps**; ensure it's **not** in "Sleeping apps" / "Deep sleeping apps."
- Settings → Apps → Linphone → Battery → **Unrestricted**.

**Xiaomi / Redmi / POCO (MIUI/HyperOS):**
- Settings → Apps → Linphone → **Autostart** → ON.
- Battery saver → Linphone → **No restrictions**.
- Lock the app in recents (pull down on the card → lock).

**Oppo / Realme / OnePlus (ColorOS/OxygenOS):**
- Settings → Battery → Linphone → **Allow background activity** / **Allow auto-launch**.
- Disable "**Sleep standby optimization**."

**Vivo / iQOO (Funtouch/OriginOS):**
- Settings → Battery → **High background power consumption** → allow Linphone.
- **Auto-start manager** → enable Linphone.

> Aggressive killers (Xiaomi, Oppo, Vivo, Realme, some Samsung) are the usual cause of
> "my phone didn't ring." If a pilot phone keeps deregistering, this is the first check.

---

## 3. iOS (iPhone / iPad)

iOS is stricter — it suspends background network sockets, and without push
notifications (which need internet, out of scope for LAN-only) **incoming calls to a
locked/backgrounded iPhone are best-effort, not guaranteed.**

**Do:**
- Settings → Linphone → **Background App Refresh** → ON.
- Settings → Battery → **Low Power Mode** → **OFF** (it kills background activity).
- Keep the app **open in the foreground** when you're expecting an ERT callback.
- Allow **Microphone** + **Local Network** permissions.

**Honest guidance for iPhone users:**
- **Outbound (dial 111) is reliable.**
- **Inbound (ERT callback) is not guaranteed** when the phone is locked. If you may
  need a callback, keep the app open, or use a **fixed phone** as the answer point.

---

## 4. Windows / desktop (MicroSIP, Linphone)

- Set the app to **start with Windows** and keep it running.
- Disable sleep on ERT/desk machines that must stay reachable, or use a real IP phone.
- Fixed/desk devices should be **always-on** — that's their advantage over mobiles.

---

## 5. What IT configures on the PBX (server side)

Tuning that helps mobiles stay registered and detects drops fast:

| PJSIP / FreePBX setting | Recommended | Why |
|---|---|---|
| `qualify_frequency` | ~30–60 s | Keepalive pings keep the path open + detect dead endpoints |
| Registration expiry | ~120–300 s | Short enough to notice a drop, long enough to avoid thrashing |
| `rewrite_contact` | yes | Handles Wi-Fi/NAT so replies reach the phone |
| `qualify_timeout` | tuned to Wi-Fi latency | Avoid false "unreachable" on slow Wi-Fi |
| NAT/keepalive | enabled | Keeps the registration path alive on Wi-Fi |

Monitor registration health on the [Health Dashboard](../operations/health-monitoring.md);
repeated drops from a device → apply the battery steps above or move that role to a fixed phone.

---

## 6. Design principle — belt and suspenders

Because mobile inbound can never be 100% guaranteed on every phone:

- **Critical answer points (ERT, control room, medical, security) are FIXED devices** —
  always powered, always registered.
  - **Phase 1 (now):** each is a **dedicated Android** on the charger with
    battery-optimization off, auto-start on, and screen-lock disabled/stay-awake —
    treat it like an appliance, not a personal phone.
  - **Later:** wired **IP phones** on the same extensions remove the battery problem entirely.
- **Mobiles are the primary path for reaching 111 outbound** — which is the common case and works reliably.
- Missed-call recovery ([ERT SOP Part F](../operations/ert-sop.md)) exists precisely because a
  callback might not connect first try — the incident stays open until reviewed.

---

## 7. Pilot checklist (per phone)

- [ ] App installed, registered (green), stays registered after 30 min idle + screen lock.
- [ ] Battery optimization disabled / Unrestricted.
- [ ] Auto-start enabled; app not in a "sleeping apps" list.
- [ ] Test **outbound**: dial 199 → works.
- [ ] Test **inbound**: have ERT call the phone **while locked** → does it ring? Record result per device model.
- [ ] Document any brand quirks for the support runbook.

The **future UPES VoIP app** (see [Risk Register R2/R5](../operations/risk-register.md))
can solve inbound properly with app-level wake + coordinate broadcast — until then,
these practices + fixed-phone answer points are the mitigation.
