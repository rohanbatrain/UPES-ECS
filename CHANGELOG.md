# Changelog — UPES-ECS

All notable changes to the UPES Emergency Communication System. Newest first.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this
project adheres to [Semantic Versioning](https://semver.org/). Dates are absolute.

---

## [Unreleased]

### Changed
- Repository restructured for public release: all narrative docs consolidated into a
  MkDocs Material site under `docs/` (Diátaxis-organised); enterprise scaffolding added
  (LICENSE, CONTRIBUTING, SECURITY, CODE_OF_CONDUCT, CODEOWNERS, CI workflows, Dependabot,
  pre-commit); line-ending discipline via `.gitattributes`/`.editorconfig`.

### Security
- Removed all real PII and secrets from tracked files: rosters, `directory.json`, live
  `pjsip_accounts.conf`, and provisioning CSVs are now git-ignored and shipped as
  sanitized `*.example.*` templates.

### Changed
- Generated Piper TTS voice prompts (~1 GB) are **no longer committed** — they are
  regenerated at setup (`scripts/gen-*-prompts.*`). The repository has **no Git LFS
  dependency**, so clones stay lightweight and anyone can clone and set up directly.

### Added
- Self-contained landing page in 44 languages (`landing/`), highlighting the HPE Juniper
  networking infrastructure that powers the system (SRX300/320, EX2300-C-12P, Mist AP32).

### Removed
- Archived the Flutter mobile app (removed feature); recoverable from the
  `mobile-app-archive` git tag.

## [1.0.0] - 2026-07-22

First public baseline release.

### Added — per-caller voice language (dynamic routing by user preference) (2026-07-10)
- **The campus now speaks each caller's own language on 111 / 102 / 199, routed per caller —
  not one language pinned per deployment.** The dialplan resolves `CHANNEL(language)` once at
  each entry point via a new `sub_setlang` subroutine (config/extensions_custom.conf): an offline
  astdb lookup `DB(lang/<ext>)` (personal preference) → `DB(lang/_default)` (campus default) →
  `en`. Because `CHANNEL(language)` is inherited across `Goto`, setting it once at 111 localises
  the entire flow — queue, escalation, and the offline panic-coach — and Asterisk falls back to
  `sounds/en/` **per file**, so any untranslated prompt degrades to English on its own (safe for
  a life-safety system). No internet, no AI, no DB server.
- **Prompt packs now install into their own `sounds/<code>/` folder — English is never
  overwritten.** This replaces the old "regional" mode, which overlaid one pack onto `sounds/en`
  and pinned the whole PBX to a single language. `Install-UpesEcs.ps1` now pushes *every* built
  pack (`Push-AllLangPacks`), keeps `sounds/en` pristine as the fallback, and `-Language` sets only
  the campus **default** (`lang/_default`) rather than clobbering English.
- **Per-user language is a first-class, pinned setting.** New source of truth
  `provisioning/user-languages.csv` (`ext,lang`) survives directory regeneration; `Install-UpesEcs.ps1`
  (`Sync-LangDb`) syncs it plus the default into astdb, and merges `lang` into `directory.json` for
  the Console/app. `Add-UpesUser.ps1 -Lang <code>` upserts the CSV + directory and applies it live
  (`database put lang <ext> <code>`), so a new user is routed immediately.
- **In-call override:** pressing `*` in the panic-coach plays a language chooser
  (`upes-ecs/coach/pick-language`, new prompt #42 in the catalog + both `gen-coach` generators + en/hi
  translations) and re-speaks the menu in the chosen language — ephemeral to that call. It uses
  single-digit `Read()` capture (not digit extensions), so the 1/2 pressed here can never collide
  with the coach's 1–9 first-aid topics. The emergency fast path is deliberately NOT gated behind a
  language menu.
- **100% prompt coverage across all 43 languages.** The new `pick-language` prompt was translated
  into every language (`i18n/translations/*.csv`), so every shipped language now covers all 42
  catalog prompts with zero English-fallback holes. New `i18n/Check-PromptCoverage.ps1` is the
  durable gate: it parses each CSV *positionally* (immune to the duplicate-header quirk that breaks
  `Import-Csv` on `en.csv`/`id.csv`) and reports/fails on any gap (`-FailOnGap` for CI). Also fixed a
  latent generator bug — `gen-lang-prompts.win.ps1` read the translation by column *name* (`$r.$Lang`),
  which silently returned the wrong column for Indonesian (`id` collides with the prompt-`id` column);
  it now reads column 5 positionally, so `id` (and any future name-colliding code) generates correctly.
  Non-en/hi translations are AI-draft tier (consistent with the existing catalog) — native-speaker
  review of the safety-critical coach prompts is still required before a language goes live.
- **Audio built for every language (42/43).** Regenerated the packs on the host with Piper: all 42
  non-English languages now ship a complete 42-prompt WAV pack under
  `deploy/asterisk/sounds/lang/<code>/` (incl. the new `pick-language`), so per-caller routing plays
  real native audio, not English fallback. The 5 priority Indian languages (hi/te/ml/ur/ne) are
  complete. Chinese (`zh`) is the sole exception: the `zh_CN-chaowen-medium` model is incompatible
  with this Piper build's phonemizer (`"ai" is not a single codepoint`) — a pre-existing issue (zh was
  never generated), its translation text is present, and it safely falls back to English per file
  until a compatible zh TTS is used. English (`sounds/en`) is generated by its own base pipeline
  (`gen-coach`/`gen-rest`, incl. the in-VM `gen-coach-prompts.sh` which now emits `pick-language`).

### Added — stable hostname `upes-ecs.local` (set the SIP server ONCE) + CardDAV directory (2026-07-08)
- **Phones no longer need re-pointing when the laptop's IP changes.** The server-side rebind
  (`Set-UpesLanIp.ps1`) already followed the network, but every handset still had the raw IP typed
  into its Linphone profile. New `deploy/qemu/Publish-UpesHostname.ps1` is a pure-PowerShell mDNS
  responder (RFC 6762, UDP 5353, no admin) that answers `upes-ecs.local` with the laptop's **current**
  LAN IP — the *same* IP `Set-UpesLanIp.ps1` computes, so name and advertised media address always
  agree. Provision `server = upes-ecs.local` once; phones re-resolve on each REGISTER (120 s) and
  follow the laptop across every router / OTG hotspot, fully offline. mDNS is used (not a `.lan` DNS
  name) because you don't control DHCP on arbitrary networks. Verified end-to-end on the host:
  `Resolve-DnsName upes-ecs.local` returns the live IP from the responder's multicast answer.
  - Launched hidden by `start-vm.ps1` (covered by existing autostart), stopped by `stop-vm.ps1`,
    staged to `%USERPROFILE%\qemu` by `Deploy-UpesEcsVm.ps1`. Recomputes the IP live, so a
    mid-session network switch needs **nothing**. Log: `qemu\seed\mdns.log`. Docs:
    `deploy/qemu/HOSTNAME-mDNS.md`. The Linphone template `__DOMAIN__` now defaults to `upes-ecs.local`.
  - Caveat: fixed SIP devices that can't resolve `.local` (some gate phones/speakers) stay on a raw IP.
- **Contacts sync — shared campus phonebook over CardDAV (Radicale on the VM, `:5232`).** New
  `api/carddav/` stands up a LAN-only, read-only address book generated from `directory.json`
  (`gen_vcards.py`): ERT + responder + staff positions, **students excluded by design**. Every contact
  dials `sip:<ext>@upes-ecs.local`, so the phonebook survives IP changes too. A 2-minute systemd timer
  regenerates the book from `directory.json`, and `Add-UpesUser.ps1` pushes the directory + kicks the
  sync so a new user appears on every phone within seconds. Installed automatically on fresh builds
  (`setup-in-vm.sh` → `install-carddav.sh`) and via a standalone installer for existing VMs. Validated
  end-to-end locally against Radicale 3.7.6 (auth, read-only rights, per-contact GET, PROPFIND
  enumeration). Docs: `api/carddav/README.md`.
- **CardDAV made reachable on the LAN + Juniper flat-network support.** The QEMU forwards only
  exposed SSH/SIP/RTP, so `5232/tcp` (CardDAV) was unreachable by phones — added
  `hostfwd=tcp:0.0.0.0:5232` (start-vm.ps1 + Deploy-UpesEcsVm.ps1) and a matching Windows firewall
  rule so `upes-ecs.local:5232` works. New `deploy/qemu/Test-UpesNetwork.ps1` is a read-only
  readiness self-check (LAN IP, hostname/mDNS, SIP/RTP/CardDAV reachability, firewall, advertised
  media address) that prints the exact fix for anything red. New `Docs/Juniper.md` is a flat-network
  (no-VLAN) runbook: Wi-Fi client-isolation OFF, DHCP reservation, EX access-port hygiene (RSTP edge),
  and the SRX SIP-ALG-disable note — with copy-paste Junos and a verify section.
- **Prod hardening.** `upes-ecs-healthcheck.sh` now checks the CardDAV server + contact count;
  `upes-ecs-backup.sh` includes `/var/lib/radicale` + `/etc/radicale`; services run with
  `Restart=always` and systemd sandboxing; the directory password is generated once and recorded to
  `generated-secrets.txt` (bcrypt when available, else plain on the closed LAN).

### Fixed — roll-call ACTUAL root cause: `System()` append truncated by an unescaped `;` (2026-07-08)
- **The real reason every roll-call CSV was 0 bytes since day one — a dialplan parse bug, not
  permissions.** In `ctx_callout`'s `log` step the append was written as
  `System(mkdir -p …/rollcall; printf '…' >> …/<run>.csv)`. In `extensions.conf` a **bare `;`
  starts a comment**, so Asterisk loaded only `System(mkdir -p …/rollcall)` and **silently discarded
  the `printf` that writes the response** — the write literally never existed in the running dialplan.
  Proven with `dialplan show log@ctx_callout`: before, priority 5 was just the `mkdir`; after, the
  full `printf … >> …csv`. Fix: escape the separator as `\;` so both commands reach `/bin/sh`.
  (The earlier "permission" theory below was a red herring — the append never ran to *hit* a
  permission check; the isolated shell test that "passed" didn't go through the dialplan parser.)
- **Same trap fixed in the `105` callback logger** (`ctx_callback`) — its `printf`+`logger` were
  being stripped identically, so callback requests never logged. Escaped there too.
- **Roll-call attribution fixed.** The append logged `${CALLERID(num)}`, but the call file forces
  CallerID to `"UPES-EAS" <111>`, so *every* response would record as `111` and `get_rollcall()`
  could never match it to the roster (everyone stays "unaccounted" even after pressing 1). The call
  file now passes `Setvar: CALLOUT_MEMBER=<ext>` and the dialplan logs that member ext (falling back
  to CallerID for manual calls).
- **Verified end-to-end (headless).** Drove the real `mass_callout.sh` → `ctx_callout,rollcall` and
  let `WaitExten` time out: the run CSV now records `1001,none,<time>` (the exact `System()` append
  line, previously a no-op) and the API reconciles it (`called=1 responded=1 unaccounted=0`) with the
  correct member ext. The `press-1` path is that same append with `RESP=1`; DTMF capture through
  `Background`/`WaitExten` is independently proven (the coach IVR navigates on real-phone RFC4733).
  A fully-synthetic keypress could not be reproduced in the emulated VM (no usable audio backend for
  a test UA), so confirm the final `safe` tick with one real-phone roll-call.

### Fixed — roll-call responses silently dropped (permission bug — SUPERSEDED, see 2026-07-08), + robustness (2026-07-06)
- **Every roll-call "press 1 safe" response was lost — a file-permission bug, not DTMF.** Traced
  via CDR: the keypress *was* captured (calls reached `dst=log` in `ctx_callout`), but the
  `System()` append that records `ext,response,time` runs as the **`asterisk`** user, while
  `mass_callout.sh` runs as **root** (via the API) and created each `/var/lib/upes-ecs/rollcall/<run>.csv`
  **root-owned `644`** → the append hit `Permission denied` and every response was silently dropped
  (CSV stayed 0 bytes → dashboard showed 0 safe). Fix: `mass_callout.sh` now `chown`s the response
  CSV (and state dir) to `asterisk`. Verified the `asterisk` user can now append.
- **Roll-call digit capture hardened.** Replaced the two-`Read` structure (whose timeout gap could
  drop a press landing between the two reads) with the canonical `Background(${CALLOUT_SOUND})` +
  `WaitExten(12)` + `exten => 1` / `_[02-9]` handlers — one continuous capture window.
- **Dashboard now shows roll-call results live.** Added `rollcall` to the API `/status`
  (`get_rollcall()` reads the latest run: called / safe / responded / unaccounted + the ext lists);
  the Console Roll-call section renders a live panel (safe count, unaccounted names, roster-matched)
  and auto-fills the tally, refreshing on the 4 s poll.
- **DTMF confirmed working** end-to-end via a live SIP/RTP trace (RFC4733 received, coach digits
  navigate); set `dtmf_mode=auto` on endpoints as belt-and-suspenders.

### Added — one-click network rebind, from anywhere, no internet (2026-07-06)
- **Move the van to any new router / mobile OTG hotspot and rebind the PBX in one action** —
  three equivalent front doors, all offline-safe:
  1. **Console → Network → “Rebind PBX to this network”** button (confirm-before-run). New
     host-side endpoint [`Serve.ps1`](Console/Serve.ps1) `POST /api/rebind` runs
     `Set-UpesLanIp.ps1` on the laptop (only the host knows its own LAN IP — this can't be a
     VM `/exec` action). It runs **detached** and returns immediately, then the UI polls
     `GET /api/rebind` until done — so the slow (~60–90 s on the TCG-emulated PBX) PJSIP
     reload **never blocks `Serve.ps1`'s single-threaded listener / freezes the wallboard**
     (verified: `/api/status` held ~1 s latency throughout a live rebind). The new IP shows
     on the wallboard within ~4 s regardless (the host reports it via `/api/status`).
  2. **Double-click** [`Rebind-Network.cmd`](deploy/qemu/Rebind-Network.cmd) — for the van
     operator, no PowerShell knowledge needed.
  3. **Command line** `powershell -File Set-UpesLanIp.ps1` — unchanged, still auto-runs on boot.
- **OTG / no-internet-safe IP detection.** [`Set-UpesLanIp.ps1`](deploy/qemu/Set-UpesLanIp.ps1)
  now detects the LAN IP from the default route first (normal case), and **falls back** to the
  active private-range interface (Wi-Fi preferred, then USB-tether/Ethernet, virtual
  WSL/Hyper-V/Docker switches excluded) when a mobile hotspot advertises **no default gateway**.
  Also fixes a latent bug where an interface with multiple IPv4s could produce a malformed
  `external_media_address`.

### Changed — one consistent voice (Piper en_US-lessac-high, 2026-07-06)
- **All 41 spoken prompts standardized on a single neural voice** (`en_US-lessac-high`), replacing
  the robotic pico2wave used on the coach/emergency prompts and unifying the mixed voices across
  the paging announcements, EAS set, roll-call, and system prompts (`drill-prompt`,
  `emergency-voicemail-prompt`, `not-authorized`, `queue-hold/paused/resumed`).
- **Generation must run on the host, not the VM.** The QEMU VM runs under software emulation
  (no hardware virtualization), so Piper inference there measured **RTF ~437** (258 s of compute
  per 0.6 s of audio) — regenerating the set would take days. New host-side generators
  `scripts/gen-coach-prompts.win.ps1` and `scripts/gen-rest-prompts.win.ps1` synthesize on the
  laptop's native CPU (RTF ~0.5, whole set in ~5 min); the WAVs are copied into the VM and
  downsampled to Asterisk 8 kHz with sox. `scripts/gen-coach-prompts.sh` now prefers Piper and
  keeps pico2wave only as an **offline fallback** so a build never fails to produce life-safety audio.
- **Authored wording** (flagged for review): `announce-avoid-area`, `callout-notify`, and the six
  system prompts had no version-controlled text; wording was written in the EAS house style (SOP 28)
  and is easy to re-voice — edit the text in the host generator and re-run.

### Added — always-on, self-updating Console (2026-07-06)
- **No more launching `Serve.ps1` by hand.** New supervisor
  [`Console/Run-Console.ps1`](Console/Run-Console.ps1) runs `Serve.ps1` and **auto-restarts
  it** on any crash / network-change / listener death (crash-loop backoff + a global mutex
  so a second copy can't double-bind port 8080; restarts logged to
  `Console/logs/console-supervisor.log`).
- **Autostart now launches the supervisor**, not `Serve.ps1` directly
  ([`deploy/qemu/Register-Autostart.ps1`](deploy/qemu/Register-Autostart.ps1)) — run it
  **once** and the console comes up supervised at every logon (still no admin; Startup folder).
- **Auto-picks-up deploys.** `Serve.ps1` now serves front-end assets `no-cache` and exposes a
  `/__build` stamp (newest mtime of `app.js`/`app.css`/`index.html`); the dashboard polls it
  and **reloads itself within ~4 s** when you deploy an edit — no browser hard-refresh, no
  stale `app.js`. (`.wav` recordings still cache — they're immutable.)

### Added — live Department Map + responder architecture doc (2026-07-06)
- **New Console view: Department Map** (Operations group) — a real-time SVG of the whole
  responder topology. A caller dials 111 → the ERT hub → departments; every position node
  is coloured live from `presence[]` (green on-shift · amber pulse ringing · red on-call ·
  grey off), and animated call edges stream **caller → ERT → receiving department** the
  moment a call connects. A live table lists each call in words
  (`caller → Medical Resp 1 (4201) · on call 0:42`). Refreshes on the existing 4 s poll;
  degrades cleanly to presence-only colouring on the static `status.json` path.
- **New realtime signal `liveCalls[]`** in `/status` — active channel legs parsed from
  `core show channels concise`, paired by Asterisk bridge id into caller↔responder edges.
  Added to both the live API ([`api/upes_api.py`](api/upes_api.py) `get_live_calls()`) and
  the SSH snapshot generator ([`Console/Update-Status.ps1`](Console/Update-Status.ps1)).
- **New doc:** [Blueprint 08 — Responder Department Architecture & Live Map](Blueprint/08-Responder-Department-Architecture.md)
  (topology, per-department positions, the realtime data contract, graceful degradation);
  linked from the Blueprint index and the Console's in-app doc library.
- **Console reference refreshed** to the multi-position model: Numbering table, `roleFor()`,
  `isResponderExt()` (now matches all seats), the Register form (adds the dept-lead context),
  and the contexts list (`ctx_responder_lead`).

### Added — responder departments expanded to multi-position (2026-07-06)
- **Every responder department now mirrors the ERT model: a dispatch front-door + answer
  seats**, instead of a single shared login. Medical `4200` + `4201-4202`; Security
  `4300` + `4302-4303`; Warden `4400` + `4401-4402`; Operations `4500` + `4501-4502`;
  IT/Network `4600` + `4601-4602`. Seat count kept minimal (2/dept) — add more within each
  hundred-block only when a shift staffs them. The round number is the always-reachable
  front door and the 111 background-alert / backup target (`UPES_BACKUP` unchanged).
- **New `ctx_responder_lead` context + Security Lead position `4301`.** Security is the one
  department that coordinates others, so it gets a lead. `ctx_responder_lead` currently
  `include`s `ctx_responder` (identical base capabilities) but is a **distinct** context so
  the lead seat is identifiable in logs and is the seam for future elevated department-lead
  grants (own-zone paging, room moderation). It is **not** an ERT role — no 111-queue
  answer, no all-campus paging, no ERT-queue control.
- **Wired end-to-end (single source of truth kept in sync):** `deploy/asterisk/pjsip_accounts.conf`
  (11 new accounts, real secrets), `provisioning/responder-positions.csv`,
  `secrets/TEAM-CREDENTIALS.md`, `config/extensions_custom.conf` (`ctx_responder_lead`),
  SOP 01 / 04 / 30, Blueprint 06, `Notes/DEMO-TEAM-ASSIGNMENTS.md`, and per-department
  call-out groups (`provisioning/callout-groups/{medical,security,operations,it-network}.example.csv`).
- Front-door display names normalized `…responder/Control/Duty` → `…Dispatch`; extension
  numbers (the identity) unchanged, so dialplan and scripts are unaffected.

### Audit patches (parallel full-system audit, 2026-07-06)
- **CRITICAL — `111` used `QUEUE_MEMBER(...,available)`, an option Asterisk 18 doesn't have**
  (`ERROR: Invalid option 'available'`) → `QAVAIL` was empty and the "no free agent → coach" test
  misfired. Changed to **`ready`** (device 'Not in use', not paused). Verify this survives edits:
  `extensions_custom.conf` `Set(QAVAIL=${QUEUE_MEMBER(${UPES_QUEUE},ready)})`.
- **Security — API** bound to `127.0.0.1` (tunnel-only, off the LAN), wildcard CORS removed, `/exec`
  `sound` regex hardened. **`Serve.ps1`** serves only known-safe web types (no `*.ps1` source leak);
  doc viewer blocks `javascript:` links.
- **Fixed** the 199 drill dialing a phantom `PJSIP/ert-test-target` (now confirm-only unless
  `UPES_DRILL_TARGET` set); defined missing speaker/drill globals; `status.json` analytics fallback
  now counts **111**; CDR read capped.
- **Docs** swept ~30 files → 111-primary, coach-in-parallel flow, local-first AI (last Gemini refs
  gone), `102`/`*22`/`*23` in numbering/glossary/flow; Console/deploy/security docs updated for the
  live API + Execute buttons + prod hardening.
- **Build reproducibility** — a rebuild now recreates callout group CSVs, sshd speed fixes, fail2ban
  + jail, and host-side `start-vm`/`stop-vm`/`Set-UpesLanIp`. Removed dead `_exec.ps1`.

### Fixed
- **A student could self-join the emergency (111) queue as an "ERT" answerer.** The `*22`/`*23`
  shift-login context (`ctx_shift`) was `include`d into **`ctx_student`**, so any student dialing
  `*22` ran `AddQueueMember(ert_emergency_queue, PJSIP/<their SAP ID>)` and started answering real
  emergencies (this is how a student showed up as `ERT-OnShift-500120597` on the wallboard). ERT is
  a **role** staffed by a **trained** person on a **position account** (4101 / 4110–4113 / 4120),
  never a personal SAP ID. Moved `ctx_shift` to **`ctx_ert` only**; students can no longer go on
  shift. (Existing persisted student members must be removed once from astdb — see below.)
- **Every call dropped at ~32 s AND "press 1" did nothing — same root cause: broken NAT media
  return path.** `external_media_address` / `external_signaling_address` were **empty** on the live
  transport, so behind QEMU SLIRP NAT Asterisk advertised its internal `10.0.2.15` address. The
  phone therefore sent all inbound RTP — **including the RFC2833 DTMF that carries "press 1"** — to
  an unroutable address; DTMF never reached Asterisk (dead keypad) and the half-broken media stream
  was torn down at ~32 s (confirmed: even the plain `198` echo test died at exactly 32 s, proving it
  was transport-level, not dialplan). Fix: set `external_media_address`/`external_signaling_address`
  to the LAN IP (`Set-UpesLanIp.ps1` does this at boot; it must run/persist on the deployed VM).
  This is the same class as Field-Test Issue 3.
- **Emergency prompts weren't interruptible.** The front-door `emergency-preanswer` and the coach
  `intro` / `fastpath-intro` / `intro-test` were non-interruptible **`Playback`**, despite saying
  "press 1 at any time." Coach entries → **`Background`**; front door → **`Read(FA,…)`** (stores the
  digit without creating an ambiguous `exten => 1` that collides with `102`/`111` — with the
  bare extension, pressing 1 three times literally dialled `111` and restarted the call).
- **The offline coach auto-hung-up a live emergency caller.** On repeated silence the coach fell
  through to voicemail + `Hangup()` (≈30–36 s), dropping the caller — against the golden rule
  "never drop an emergency call silently." It now **loops indefinitely, keeps the line open and
  recording, and re-pages a responder every 3rd silent cycle**; voicemail is only reached by an
  explicit press-8.
- **PJSIP hardening.** Added `timers=no` (disable SIP session-timers, RFC 4028) to the endpoint
  template — a defensive change for the isolated LAN; it was *not* the cause of the ~32 s drop
  (the drop was identical before and after), which the media-address fix above actually resolves.
- **Mass call-out (EAS) delivered no message and showed ANONYMOUS.** `mass_callout.sh` used
  `channel originate`, which cannot attach a caller ID (→ ANONYMOUS) and could only pass the
  sound name as a shared global whose propagation raced the answer — the callee reached
  `Playback(${CALLOUT_SOUND})` with an empty sound and the call dropped silently. Rewrote the
  script to place each call via an Asterisk **call file** (same mechanism as
  `alert_responders.sh`): it carries `CallerID: "UPES-EAS" <111>` (the **Emergency Alert
  Service** identity, never ANONYMOUS) and passes `CALLOUT_SOUND` / `CALLOUT_RUNID` /
  `CALLOUT_MODE` as per-call `Setvar:` variables that exist the instant the callee answers.
  The flock/globals/grace machinery is gone (runs are now independent). Dialplan `ctx_callout`
  is unchanged in behaviour; only its header comment and `FEATURES.md` were updated. Default
  EAS caller-ID number is **111** (the primary campus emergency number); override via `EAS_CID_NUM`.
- **Feature dialplan never loaded in the container build.** `deploy/asterisk/extensions.conf`
  `#include`s `extensions_features.conf` (which defines **`ctx_callout`**), plus
  `extensions_features_wiring.conf` and `extensions_aihelpline.conf` — but none were baked into
  the image or mounted by compose, so Asterisk silently skipped the missing includes and the
  whole feature layer (mass call-out, departments, intercom, silent-SOS, roll-call, offline
  coach) was absent from a clean build. `deploy/Dockerfile` now COPYs `extensions.conf` + all
  four dialplan files (self-contained image); `deploy/docker-compose.yml` bind-mounts the three
  feature files alongside `extensions_custom.conf`. Rebuild with `docker compose up -d --build`.

### Added
- **EAS announcement audio (Piper), shipped in the image.** New `scripts/gen-callout-prompts.sh`
  generates the mass call-out / roll-call prompts with the **professional on-prem Piper neural TTS**
  (voice `en_US-lessac-high`; the family the AI-101 stack + Paridyum `pd-ai-speech` standardize on)
  rather than the robotic pico2wave used by the panic-coach:
  `custom/upes-{evacuate,shelter,allclear,assemble,rollcall,test}` and the roll-call control
  prompts `upes-ecs/rollcall-{press1,thanks,noack}`. The rendered 8 kHz-mono WAVs are committed
  under `deploy/asterisk/sounds/` (hi-fi masters kept) and `COPY`d into the image, so callouts
  have real audio out of the box. Point `PIPER_MODEL` at another voice to re-render; wording is
  source-controlled in the script and documented in SOP 28.

### Audit
- Full-system audit (dialplan, Console+API code, docs, build persistence, live VM) — see the
  dated patch entries below for what it fixed.

---

## 2026-07-06 — Live API, realtime, 111 primary, emergency-line fixes

### Added
- **Live status/control API** — a FastAPI service (`api/upes_api.py`) running inside the VM on
  `:8090`, querying Asterisk locally (no SSH per request). Endpoints: `GET /health`, `GET /status`
  (full wallboard schema), `POST /exec` (strict whitelist: shift / callout / drill / reload).
  Runs as a `systemd` service (`upes-api`, Restart=always).
- **Realtime Console** — the Console now polls `GET /api/status` (proxied by `Serve.ps1` through a
  persistent SSH tunnel `localhost:18090 → VM:8090`), refreshing every **4 s** and immediately on
  connect. Latency dropped from ~75 s (SSH) to **~1.5 s**. `status.json` retained as automatic
  fallback when the API/tunnel is down.
- **Execute buttons** on Mass Callout, Roll-call and Announcements — each opens a **confirmation
  modal** (shows exactly what will happen + the command, requires a second click) then runs it via
  the API. Demo call-groups under `/opt/upes-ecs/groups/`.
- **111** is now the **primary** campus emergency number (people associate 100 with Police). The old
  `100` was kept as a working alias at the time and has since been deprecated and fully removed;
  Console display, CDR classifier and diagrams updated to 111.

### Fixed
- **Emergency line dropped in dead air** — when no answer point was free, the queue rang nobody and
  the call abandoned at ~18 s before reaching the coach. The `111` flow now checks
  `QUEUE_MEMBER(...,available)` and, when none are free, jumps **straight to the offline coach**
  (`nostaff` → `ctx_escalation`) instead of waiting in silence. Also fixes self-testing from the
  only on-shift phone.
- **Call recordings showed 0:00** — `<audio preload="none">` → `preload="metadata"` so duration
  loads without pressing play.
- **~75 s SSH logins** — disabled `UseDNS`/`GSSAPIAuthentication` in the VM's sshd and Ubuntu
  `motd-news`; and stopped using SSH-per-request in favour of the API.

---

## 2026-07-05 — Offline panic-coach, disaster-ready flow, prod hardening, Console analytics

### Added
- **Offline panic-coach (`102` / `ctx_ai_helpline`)** — deterministic first-aid guidance (CPR,
  bleeding, choking, fire, lockdown, recovery position, trapped), fully offline TTS
  (`gen-coach-prompts.sh`), reached automatically when no responder answers; dial `102` to test.
- **Disaster-ready 111 flow** — press **1** during the queue for immediate first-aid
  (`ctx_111_fastpath`); when no human answers, the ERT Lead + backup are alerted in the
  **background** (`alert_responders.sh` call-files, "press 1 to join the queue") **while** the
  caller is coached — no serial ring-out, no dead-air.
- **Shift login** — responders dial `*22` to go on shift (join the emergency queue) / `*23` off;
  events logged (`shift_event.sh`) and shown in the Console **Presence & Shifts** panel.
- **Console sections**: Incident Timeline, Presence & Shifts (+ shift log), Call Records (in-browser
  recording playback), **Insights** (CDR analytics: answer-rate/time, drill pass-rate, volume,
  busy-hour, top callers), **Emergency Call Flow**, **Architecture** (SVG diagrams), and an in-app
  **Markdown doc viewer** (renders SOP/Blueprint/etc.; `secrets/` blocked).
- **Team credentials** — `secrets/TEAM-CREDENTIALS.md` with real per-person and per-position SIP
  logins; source of truth `deploy/asterisk/pjsip_accounts.conf` (19 endpoints). Not web-served.
- **Production hardening** — asterisk `systemd Restart=always` (crash auto-recovery), nightly
  backups (`upes-ecs-backup.sh` + cron), boot auto-start of the VM + Console (Startup folder,
  no admin), a real all-campus paging PIN, fail2ban (asterisk + sshd). See
  `Journal/Production-Readiness.md`.
- **`Notes/DEMO-TEAM-ASSIGNMENTS.md`** — a fill-in coordination sheet for assigning a demo team.

### Changed
- **AI-101 (extension 101) is now local-first** — the online AI triage design switched from cloud
  Gemini to a fully-local stack (Ollama/llama.cpp + faster-whisper/Vosk + Piper), no cloud, no API
  keys, audio stays on-prem. It sits *above* the offline 102 coach and is still a future phase.
- **111 made answerable** — the on-shift registered handset joins the ERT queue; wallboard state
  logic uses a configurable `MinAgents` (default 1) with a "no backup" thin-cover note.

### Fixed
- Registration count over-counted by one (CLI header line) — now accurate.

---

## 2026-07-04 — Deployment, LAN calling, feature pack, Console v2

### Added
- Running **Asterisk PBX in a QEMU Ubuntu VM** on the Windows van laptop (no admin, TCG accel),
  LAN-reachable so real phones register and call; dynamic across routers (server IP auto-updates).
- **Feature pack** — department hunt groups (`211-215`), dial-by-name (`411`), intercom (`*80`),
  one-tap incident bridge (`*9`), silent SOS/duress (`*77`), request-callback (`105`), pre-recorded
  announcements (`720-723`), mass callout and roll-call scripts.
- **Operations Console v2** — vanilla-JS feature-registry web app (LAN-only, no CDN), live wallboard.

### Fixed
- **MixMonitor** recorded only the bridged segment → 44-byte empty files; now records the whole call.
- Softphones auto-prepending **+91** → stripped in the dialplan.
- No two-way audio behind NAT → `direct_media=no`, `rtp_symmetric`, `force_rport`.

[Unreleased]: https://github.com/rohanbatrain/UPES-ECS/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/rohanbatrain/UPES-ECS/releases/tag/v1.0.0
