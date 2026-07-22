# UPES-ECS — Project Status

**Project:** UPES Emergency Communication System (ECS) — a LAN-only campus emergency phone system on Asterisk.
**Deployment model:** Asterisk PBX running inside a QEMU Ubuntu VM on a Windows "van laptop"; Android phones register as SIP softphones over the local LAN.
**Status of record:** As of the live field test on an Airtel LAN with real Android phones and four real SAP-ID accounts.
**Last updated:** 2026-07-05

This document is an honest accounting of the project. Its primary job is to answer **"what is NOT done"** clearly, and to separate what is genuinely complete and validated from what remains — and why. Nothing below is aspirational: items marked done were exercised on real hardware. Items not yet proven are called out as such.

---

## TL;DR status

| Area | Status | Note |
|---|---|---|
| Documentation (SOP / Blueprint / Journal) | ✅ Done | 32 SOPs, 8 Blueprint docs, 3 Journal logs |
| Asterisk config + helper scripts + provisioning CSVs | ✅ Done | In [`../config/`](https://github.com/rohanbatrain/UPES-ECS/blob/main/config/), [`../scripts/`](https://github.com/rohanbatrain/UPES-ECS/blob/main/scripts/), [`../provisioning/`](https://github.com/rohanbatrain/UPES-ECS/blob/main/provisioning/) |
| QEMU Ubuntu VM PBX (autostart, LAN-facing, one-command deploy) | ✅ Done | [`../deploy/qemu/`](https://github.com/rohanbatrain/UPES-ECS/blob/main/deploy/qemu/) |
| Operations Console (live status + client generator) | ✅ Done, localhost only | [`../Console/`](https://github.com/rohanbatrain/UPES-ECS/blob/main/Console/); LAN serve not yet enabled |
| SIP registration on real phones | ✅ Validated live | Real Android + real LAN |
| Two-way audio (198 echo, phone-to-phone) | ✅ Validated live | `direct_media=no` + symmetric RTP fix |
| Real `111` recording captured | ✅ Validated live | Recording proven; call went to voicemail |
| Four real SAP-ID accounts provisioned | ✅ Validated live | Placeholders in repo, real secrets set on device |
| Recorded voice prompts | ❌ Not done — buildable | Currently placeholder/TTS; wording ready in [SOP 28](../reference/voice-prompt-scripts.md) |
| QR/profile phone provisioning | 🔄 In progress — buildable | [`../provisioning/linphone/`](https://github.com/rohanbatrain/UPES-ECS/blob/main/provisioning/) being created |
| Real **answered** `111` call (ERT answer point) | ✅ Done | Queue now staffed by the on-shift registered handset (`ert-shift.sh`) — `111` rings a real phone (wallboard READY) |
| Offline panic-coach (`102`) when nobody answers | ✅ Done | Deterministic first-aid decision tree (`ctx_ai_helpline`), fully offline TTS |
| Live status/control API (`upes-api` :8090) | ✅ Done | FastAPI in the VM (`Restart=always`); `GET /status` + whitelisted `POST /exec`; Console proxies `/api/*` over an SSH tunnel |
| Test-evidence sheet filled | ❌ Not done — buildable | [SOP 32](../operations/test-evidence-sheet.md) template ready |
| Console served over LAN | ❌ Not done — buildable | Needs elevated bind + TCP 8080 firewall rule |
| Production networking (off QEMU SLIRP NAT) | ❌ Not done — needs hardware/decision | **#1 production step** |
| TLS + SRTP (encrypted signalling/media) | ❌ Not done — needs decision | Currently plain UDP/RTP |
| Always-on ERT answer-point Androids | ❌ Not done — needs hardware | Battery/background hardening per [SOP 24](../reference/mobile-app-reliability.md) |
| UPS / van power | ❌ Not done — needs hardware | Risk R1, [SOP 21](../operations/risk-register.md) |
| mDNS / DHCP reservation (no reconfig across networks) | ❌ Not done — needs decision | |
| Full pilot + go-live sign-off | ❌ Not done — needs execution | [SOP 17](../operations/pilot-test-plan.md), [SOP 18](../getting-started/go-live-checklist.md) |
| DPDP / legal compliance | ⏸️ Deferred by decision | Out of scope (user choice) |
| Cost / BOM | ⏸️ Deferred by decision | Skipped (user choice) |
| Emergency number `100` vs national police `100` | ✅ Resolved | Sole emergency number moved to **`111`**; the old `100` is deprecated and fully removed — avoids the police-number/OS-interception collision |

Legend: ✅ done & validated · 🔄 in progress · ❌ not done · ⏸️ deferred by decision · ❓ open decision.

---

## 1. Done & validated

These items were exercised end-to-end on real hardware during the live field test — not simulated.

| Item | Evidence / location |
|---|---|
| Full documentation set | 32 SOP docs ([`../SOP/`](../SOP/)), 8 Blueprint docs ([`../Blueprint/`](../Blueprint/)), Journal logs: [Roadblocks-and-Solutions.md](roadblocks-and-solutions.md), [Doc-Fixes.md](doc-fixes.md), [Field-Test-Issues-and-Mitigations.md](field-test-issues.md) |
| Working Asterisk config, helper scripts, provisioning CSVs | [`../config/`](https://github.com/rohanbatrain/UPES-ECS/blob/main/config/), [`../scripts/`](https://github.com/rohanbatrain/UPES-ECS/blob/main/scripts/), [`../provisioning/`](https://github.com/rohanbatrain/UPES-ECS/blob/main/provisioning/) |
| Running QEMU Ubuntu VM PBX | [`../deploy/qemu/`](https://github.com/rohanbatrain/UPES-ECS/blob/main/deploy/qemu/) — autostarts on Windows logon; Asterisk autostarts inside the VM; LAN-facing (SIP 5060 + RTP 10000–10019 on 192.168.1.16) |
| Auto-rebind to current network on boot | [`Set-UpesLanIp.ps1`](https://github.com/rohanbatrain/UPES-ECS/blob/main/deploy/qemu/Set-UpesLanIp.ps1) |
| One-command deploy | [`Deploy-UpesEcsVm.ps1`](https://github.com/rohanbatrain/UPES-ECS/blob/main/deploy/qemu/Deploy-UpesEcsVm.ps1) |
| Operations Console web page | [`../Console/`](https://github.com/rohanbatrain/UPES-ECS/blob/main/Console/) — live status + "register a client" generator |
| SIP registration on real Android phones over Airtel LAN | Live field test |
| `198` echo test — two-way audio confirmed | Live field test |
| Phone-to-phone calls | Live field test |
| Real `111` recording captured | Live field test |
| Four real SAP-ID accounts provisioned | See `../Notes/Confirmed Details.md` and [`../provisioning/pilot-users.csv`](https://github.com/rohanbatrain/UPES-ECS/blob/main/provisioning/pilot-users.csv) |

**Real roster provisioned** (from `../Notes/Confirmed Details.md` — the only source of real IDs):

| SAP ID | Name | Role |
|---|---|---|
| 500120597 | Rohan Batra | Student |
| 500000002 | Student Example Two | Student |
| 500000003 | Student Example Three | Student |
| 500000004 | Student Example Four | Student |
| 40000001 | Staff Member One | Staff |
| 40000002 | Staff Member Two | Staff |
| 40000003 | Staff Member Three | Staff |

**Key fixes that made audio work live:**
- `direct_media=no` + `external_media_address` + `rtp_symmetric` — resolved one-way / no-audio caused by QEMU SLIRP NAT.
- `+91` dialplan strip — normalizes numbers dialed with the India country-code prefix.

---

## 2. Applied live + persisted to repo

Changes made during the field test that are now committed so the next boot reproduces them.

| Change | Where persisted |
|---|---|
| `direct_media=no` | [`../deploy/asterisk/pjsip.conf`](https://github.com/rohanbatrain/UPES-ECS/blob/main/deploy/asterisk/pjsip.conf) |
| `+91` strip in dialplan | [`../config/extensions_custom.conf`](https://github.com/rohanbatrain/UPES-ECS/blob/main/config/extensions_custom.conf) |
| Four real users added | `../Notes/Confirmed Details.md` and [`../provisioning/pilot-users.csv`](https://github.com/rohanbatrain/UPES-ECS/blob/main/provisioning/pilot-users.csv) |

> **Note on secrets:** the CSV carries `__SET_ON_IMPORT__` placeholders, **not** real SIP passwords. Real secrets are set on the device at import time and never stored in the repo.

---

## 3. Deferred by decision

The user explicitly chose to descope these. They are not failures or gaps — they are out of scope for this build.

| Item | Decision |
|---|---|
| DPDP / legal compliance | Out of scope (user decision) |
| Cost / Bill of Materials | Skipped (user decision) — note [Blueprint 05](../architecture/bill-of-materials.md) and [SOP references] remain as reference only |

---

## 4. Remaining — buildable

Things we can still make with the current QEMU test setup, no new hardware or decisions required. These are the near-term backlog.

| # | Item | Why it matters | Reference |
|---|---|---|---|
| B1 | **Real recorded voice prompts** | Currently placeholder/TTS. Real prompts make the system sound production-grade and unambiguous in an emergency. Exact wording is already written. | [SOP 28](../reference/voice-prompt-scripts.md) |
| B2 | **QR / profile phone provisioning** | Eliminates the transport / `+91` / encryption misconfiguration that phones hit today when set up by hand. One scan → correct config. | [`../provisioning/linphone/`](https://github.com/rohanbatrain/UPES-ECS/blob/main/provisioning/) (being created) |
| B3 | ~~**ERT answer point at position `4110`**~~ ✅ **Done** | The ERT queue is now staffed by the on-shift registered handset (`ert-shift.sh` / shift codes `*22`/`*23`), so a `111` call **rings a real phone and is answerable** (wallboard READY). When nobody answers, the call routes to the offline panic-coach (`102`). | [SOP 02](../operations/ert-sop.md), [`../provisioning/responder-positions.csv`](https://github.com/rohanbatrain/UPES-ECS/blob/main/provisioning/responder-positions.csv) |
| B4 | **Filled test-evidence sheet** | Converts "it worked when we tried it" into a documented, repeatable evidence record. | [SOP 32](../operations/test-evidence-sheet.md) |
| B5 | **Console served over LAN** | Console is localhost-only today. LAN serve needs an elevated bind + a TCP 8080 firewall rule. | [`../Console/`](https://github.com/rohanbatrain/UPES-ECS/blob/main/Console/) |

---

## 5. Remaining — needs hardware / decision

These **cannot** be finished inside the QEMU test. They require physical hardware, network changes, or a user decision. This is where the real production work lives.

| # | Item | Why it can't be done now / what it needs | Reference |
|---|---|---|---|
| H1 | **Move production PBX off QEMU SLIRP NAT** — to the van's own Linux box, or bridged networking with a real LAN IP | **The #1 production step.** SLIRP NAT is the root cause of the whole media/NAT class of issues; the `direct_media`/`rtp_symmetric` fixes are workarounds for it. A real LAN IP removes the entire problem category. | [Blueprint 04](../architecture/network-and-deployment.md), [SOP 23](../guides/mobile-van-deployment.md) |
| H2 | **TLS + SRTP** for encrypted signalling and media | Currently plain UDP/RTP — calls are unencrypted on the LAN. Requires cert setup and a client-config decision. | [SOP 26](../guides/security-hardening.md) |
| H3 | **Dedicated always-on ERT answer-point Androids** | Requires physical phones with battery/background hardening so the SIP app never sleeps and always rings. | [SOP 24](../reference/mobile-app-reliability.md) |
| H4 | **UPS / power for the van** | Physical power hardware; without it the PBX dies on any power interruption. Tracked as Risk **R1**. | [SOP 21](../operations/risk-register.md) |
| H5 | **mDNS / DHCP reservation** so phones need no reconfig across networks | Requires network infrastructure config so the PBX has a stable name/address regardless of which LAN the van joins. | [Blueprint 04](../architecture/network-and-deployment.md) |
| H6 | **Full pilot + go-live sign-off** | Requires executing the structured pilot and obtaining formal sign-off — an activity, not a build. | [SOP 17](../operations/pilot-test-plan.md), [SOP 18](../getting-started/go-live-checklist.md) |

---

## 6. Open decisions

These need the user's decision before the dependent work can proceed.

| # | Decision | Context & recommendation |
|---|---|---|
| D1 | ~~**Emergency number `100` vs India's national police number (`100`)**~~ ✅ **Resolved** | `100` is India's police number, and some Android OSes intercept reserved emergency numbers (100 / 112 / 911 / 108) and route them to the native cellular dialer instead of the SIP app. **Decision taken:** the sole campus emergency number is now **`111`** (a non-intercepted, non-reserved code); the old `100` is deprecated and fully removed (no longer dialable). Still worth a quick per-model dial check, but the collision/interception risk is retired. ([SOP 01](../reference/numbering-plan.md)). |
| D2 | **Production networking** | QEMU-on-Windows (current) vs native Linux on the van vs bridged networking. Ties directly to **H1**; the recommendation is to move off QEMU SLIRP NAT. |
| D3 | **TLS / SRTP now or later** | Encrypt signalling/media now, or ship plain UDP/RTP for the pilot and add encryption before wider go-live. Ties to **H2**. |

---

## 7. Recommended next steps (prioritized)

1. ~~Resolve D1 (emergency number).~~ ✅ **Done** — sole number moved to `111` (old `100` deprecated and removed). A quick per-model dial check on `111` is still worth doing, but the interception risk is retired.
2. **Decide D2 and execute H1 — move off QEMU SLIRP NAT** to a real LAN IP (native Linux on the van or bridged networking). This is the single highest-value production step and removes the media/NAT problem class.
3. ~~B3 — stand up the ERT answer point.~~ ✅ **Done** — the queue is staffed by the on-shift handset (`ert-shift.sh` / `*22`/`*23`); `111` rings a real phone and, if unanswered, drops to the offline coach (`102`). Remaining: exercise it under the formal pilot.
4. **B2 — ship QR/profile provisioning** to kill hand-configuration errors before any wider rollout.
5. **B1 — record the real voice prompts** ([SOP 28](../reference/voice-prompt-scripts.md)).
6. **B5 — serve the Console over the LAN** so operators can use it from the van, not just localhost.
7. **B4 — fill the test-evidence sheet** ([SOP 32](../operations/test-evidence-sheet.md)) to lock in repeatable proof.
8. **Decide D3, then H2 — add TLS + SRTP** before go-live.
9. **H3 / H4 / H5 — provision always-on ERT Androids, van UPS, and stable addressing** as production hardware becomes available.
10. **H6 — run the full pilot ([SOP 17](../operations/pilot-test-plan.md)) and complete go-live sign-off ([SOP 18](../getting-started/go-live-checklist.md)).**

---

### Related documents
- Journal: [Roadblocks-and-Solutions.md](roadblocks-and-solutions.md) · [Doc-Fixes.md](doc-fixes.md) · [Field-Test-Issues-and-Mitigations.md](field-test-issues.md)
- [SOP index](../operations/index.md) · [Blueprint index](../architecture/index.md)
- Deploy: [`../deploy/qemu/README.md`](https://github.com/rohanbatrain/UPES-ECS/blob/main/deploy/qemu/README.md) · Console: [`../Console/README.md`](https://github.com/rohanbatrain/UPES-ECS/blob/main/Console/README.md)
