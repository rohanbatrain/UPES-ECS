# UPES-ECS Risk Register & Known Gaps

An honest list of what can make UPES-ECS fail, weaken it, or block go-live — with
severity, impact, and a recommended fix. Some items require a **university decision**
(marked ⚑), not just engineering. Review this at every phase gate.

**Severity:** 🔴 Critical (can defeat the system's purpose) · 🟠 High · 🟡 Medium · ⚪ Low

---

## Decisions applied — 2026-07-04

| Risk | Decision | Result |
|---|---|---|
| **R1 Power** | System deploys via a **self-powered disaster-response van + corner repeaters** ([doc 23](../guides/mobile-van-deployment.md)) | ✅ **Resolved** for field mode (van power autonomy). UPS still recommended for fixed campus mode. |
| **R2 Mobile inbound** | **Battery best-practices** documented ([doc 24](../reference/mobile-app-reliability.md)); fixed phones for critical answer points | ✅ **Mitigated.** Future app solves fully. |
| **R3 After-hours** | "Whoever is available"; staffing handled off-system | ✅ **Out of scope / accepted** by university. |
| **R4 Surge** | **Surge / Declared Incident posture** added to [ERT SOP Part J](ert-sop.md) | ✅ **Documented.** |
| **R5 Location** | Out of scope now; **future UPES VoIP app broadcasts coordinates** to the aggregated workflow | 🔵 **Deferred** with a plan. |
| **R6 Silent calls** | **Keep on 111** + silent-call protocol ([ERT SOP Part I](ert-sop.md)); future app panic button | ✅ **Decided.** No separate line. |
| **R7 Cleartext media** | **Future security enhancement** — not a current concern | 🔵 **Deferred.** |
| **R8 Single PBX** | Fine for now; **van doubles as mobile failover** ([doc 23 §7](../guides/mobile-van-deployment.md)) | ✅ **Mitigated** + plan noted. |

The entries below keep the full detail; the table above is the current status.

---

## A. Mission-level risks

### R1 🔴 ⚑ Power dependency contradicts the mission
- **Gap:** Spec assumes power is available; the system's whole value is working when networks fail — but disasters often cut power too. No UPS in Phase 1.
- **Impact:** PBX / switch / router / APs lose power → **111 is dead** exactly during a real disaster.
- **Fix:** Promote **UPS/battery backup for core infra (server, switch, router, key APs)** from "later" to **Phase 1**. Size for the realistic outage window; monitor UPS as a critical device. Add PoE + UPS for the APs covering ERT/critical zones.
- **Owner:** IT + university (budget). **Decision needed before go-live.**

### R2 🔴 Mobile inbound (ERT callback) unreliable
- **Gap:** LAN-only forbids push notifications, so locked iOS/Android phones often drop the SIP registration and won't ring on an ERT callback. The Missed-Call Recovery SOP depends on callback.
- **Impact:** ERT calls a missed caller back → phone never rings → critical follow-up lost.
- **Fix:** Prefer **fixed phones** as callback/answer targets; tune PJSIP qualify/keepalive; train users on background/battery settings; **document mobile inbound as best-effort**, outbound (dial 111) as reliable. Consider a small on-device keepalive.
- **Owner:** IT + ERT Lead.

### R3 🔴 ⚑ After-hours / zero-staff coverage undefined
- **Gap:** "Same path day and night" + "min 2 responders," but no on-call/night model. Empty queue at night → voicemail with nobody watching.
- **Impact:** A 3 AM emergency escalates to an unwatched voicemail.
- **Fix:** Define a **24/7 on-call rota**; night ERT phone(s) always registered; queue-zero raises an alert that someone is actually on-call to see; document the night dispatch chain.
- **Owner:** ERT Lead + university. **Decision needed.**

### R4 🔴 Mass-casualty surge not modeled
- **Gap:** One queue + few operators + ring-all can't absorb dozens of simultaneous 111 calls in a real event.
- **Impact:** System saturates; real reports blocked; callers dumped to voicemail en masse.
- **Fix:** Define a **"Declared Incident" surge posture** — paging-first to push instructions, pull in extra operators, overflow callers to a triage voicemail with location capture, dedup same-event reports. Capacity-test toward realistic surge, not just 2–5 calls.
- **Owner:** ERT Lead + IT.

### R5 🟠 Location blindness for mobile callers
- **Gap:** SAP ID identifies the person, not their physical location. Panicked/injured/lost callers can't always state it.
- **Impact:** ERT can't dispatch to the right place fast.
- **Fix:** Put **"where are you"** first in the answer script (already in SOP — reinforce); rely on **fixed phones** for location-anchored calls; explore **AP-association → coarse zone** mapping and a caller location field later.
- **Owner:** ERT Lead + IT.

### R6 🟠 ⚑ Voice-only excludes silent / unable-to-speak emergencies
- **Gap:** No path for someone who can't talk (active threat, injury, speech/hearing impairment).
- **Impact:** The people in the most dangerous situations can't signal.
- **Fix:** Define a **silent-call protocol** (dial 111, stay silent → still recorded, located by extension, treated as live/critical, ERT trained to respond to silence); plan a future **text/panic-button** channel and accessibility support.
- **Owner:** ERT Lead + university (policy).

### R7 🟠 Cleartext SIP/RTP on shared campus Wi-Fi
- **Gap:** Plain UDP media is sniffable; inconsistent with "recordings encrypted at rest."
- **Impact:** Emergency call audio interceptable on the LAN.
- **Fix:** **TLS + SRTP** at least for ERT/fixed devices; evaluate for all clients (Linphone supports it). Weigh against setup complexity.
- **Owner:** IT.

### R8 🟠 Single PBX = single point of failure
- **Gap:** One server; restore target 1 hour = up to an hour with no emergency line.
- **Impact:** Hardware/disk/corruption outage removes 111 entirely.
- **Fix:** Keep a **pre-imaged spare/warm-standby server** ready to swap; later, a second PBX (see [Multi-Campus](../guides/multi-campus-wireless.md) Model B). Test the swap.
- **Owner:** IT.

---

## B. Security & compliance

### R9 🟠 SIP registration abuse / DoS not hardened
- **Fix:** fail2ban + registration rate-limiting; disable unused Asterisk modules; concrete LAN firewall rules; lock FreePBX GUI to the management subnet; protect the 111 queue from flooding (per-account call limits, prank-call rate tracking).
- **Owner:** IT.

### R10 🟠 ⚑ Data-protection compliance unnamed
- **Gap:** SAP-ID-linked audio + identity = sensitive personal data; docs defer to "university policy" without naming a regime.
- **Fix:** Map recording/retention/access to **India DPDP Act 2023** (and any UGC/university rules): lawful basis, notice, access logging, breach handling, retention limits. Get legal sign-off.
- **Owner:** University + IT. **Decision needed.**

### R11 🟡 Retention automation + recording verification
- **Fix:** Cron-based 90-day auto-delete with an audit log and preservation flag; periodically verify recordings are **audible**, not merely present.
- **Owner:** IT.

---

## C. Operational & organizational

### R12 🟠 Bus factor / ownership
- **Gap:** If the one admin who built FreePBX leaves, nobody can run it.
- **Fix:** Train a **backup admin**; keep runbooks current; define a **RACI** (who owns config, roster, approvals, backups, health).
- **Owner:** IT + university.

### R13 🟡 No cost / bill of materials
- **Fix:** Produce a BOM + budget: IP phones, APs, PoE switch, UPS units, spare server, cabling, headsets. FreePBX is free; hardware is not.
- **Owner:** IT + university.

### R14 🟡 Prank / false-alarm culture on a campus
- **Fix:** Track repeat false callers; SOP for warnings/escalation; keep 111 always reachable but log abuse; account suspension after review (already in Role Matrix — add a "cry wolf" tracking note).
- **Owner:** ERT Lead + IT.

### R15 ⚪ Documentation aids missing
- **Fix:** [Glossary](../reference/glossary.md) (done); one-page **ERT desk quick-card** and **student quick-card**; a RACI table.
- **Owner:** IT (docs).

---

## D. Risk summary table

| ID | Risk | Sev | Status | Fix owner |
|---|---|:--:|:--:|---|
| R1 | Power/UPS dependency | 🔴 | ✅ Resolved (van) | IT + university |
| R2 | Mobile inbound callback | 🔴 | ✅ Mitigated (doc 24) | IT + ERT |
| R3 | After-hours coverage | 🔴 | ✅ Accepted/out of scope | ERT + university |
| R4 | Mass-casualty surge | 🔴 | ✅ Documented (SOP Part J) | ERT + IT |
| R5 | Location blindness | 🟠 | 🔵 Deferred (future app) | ERT + IT |
| R6 | Voice-only / silent calls | 🟠 | ✅ Decided (stay on 111) | ERT + university |
| R7 | Cleartext SIP/RTP | 🟠 | 🔵 Deferred (future sec) | IT |
| R8 | Single PBX SPOF | 🟠 | ✅ Mitigated (van failover) | IT |
| R9 | SIP abuse / DoS | 🟠 | ✅ Documented (doc 26) | IT |
| R10 | DPDP compliance | 🟠 | ⏸️ Out of scope (deferred by decision) | University + IT |
| R11 | Retention automation | 🟡 | ✅ Scripted (retention-cleanup.sh) | IT |
| R12 | Bus factor / RACI | 🟠 | ✅ Documented (doc 27) | IT + university |
| R13 | Cost / BOM | 🟡 | ⚠️ Open (deferred by request) | IT + university |
| R14 | Prank / false alarms | 🟡 | ✅ Documented (doc 26 §6) | ERT + IT |
| R15 | Doc aids | ⚪ | ✅ Done (glossary + quick-cards) | IT |

---

## E. Recommended actions before go-live

1. **Resolve the five ⚑ decisions** (R1 power, R3 night coverage, R6 silent-call policy, R10 compliance) with the university — these are not engineering choices.
2. **Promote UPS (R1) into Phase 1** infrastructure.
3. **Add TLS/SRTP for ERT/fixed devices (R7)** and basic hardening (R9).
4. **Write the surge posture (R4)** into the ERT SOP.
5. **Prepare a warm-standby server (R8)** and train a backup admin (R12).

None of these block *starting* the build — the Phase 1 MVP is still correct. They block
**declaring the system production-ready and trustworthy for real emergencies.**
