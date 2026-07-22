# Roadblocks & Solutions

The engineering log for UPES-ECS: every roadblock we actually hit building a LAN-only
Asterisk emergency phone system as a QEMU VM on a no-admin Windows laptop, and how we
got past it. Grouped by area. Each entry: **Symptom → Cause → Fix**, plus a **Lesson**
where it earns one.

Key files referenced throughout:
[config/extensions_custom.conf](../config/extensions_custom.conf),
[deploy/qemu/README.md](../deploy/qemu/README.md),
[deploy/README.md](../deploy/README.md),
[SOP 09 – Dialplan Design](../SOP/09-Dialplan-Design.md).

---

## 1. Virtualization & networking on Windows

### 1.1 Docker Desktop can't carry SIP/RTP media

- **Symptom:** Calls signalled fine but audio (RTP) was unreliable/one-way when the PBX
  ran under Docker Desktop.
- **Cause:** Docker Desktop on Windows sits behind a user-mode NAT layer that rewrites
  and blocks UDP media. SIP/RTP is exactly the traffic that NAT mangles — the SDP
  advertises addresses the NAT then breaks.
- **Fix:** Moved the **live-audio** test off Docker. Docker is kept **only** for fast
  dialplan/config validation, not for anything that has to move real media. See
  [deploy/README.md](../deploy/README.md).
- **Lesson:** Container NAT is fine for signalling smoke-tests, wrong for RTP. Prove
  audio on a network path you actually control.

### 1.2 No admin rights on the Windows host

- **Symptom:** Could not install QEMU via `choco`/`winget`, could not add a Windows
  Firewall rule, could not enable the Windows Hypervisor Platform (WHPX/Hyper-V) — every
  path demanded elevation we didn't have.
- **Cause:** The van laptop is a managed, non-admin machine.
- **Fix:** Installed QEMU **portably** — downloaded the official
  [weilnetz](https://qemu.weilnetz.de/) Windows build and extracted it with 7-Zip, no
  installer, no admin. The one-time firewall rule is documented as an elevated command to
  run when an admin is available; acceleration falls back to software (see 1.3). See
  [deploy/qemu/README.md](../deploy/qemu/README.md).
- **Lesson:** "No admin" is a design constraint, not a blocker — portable binaries +
  software emulation get you a working PBX with zero privileges.

### 1.3 QEMU hardware acceleration (WHPX) unavailable

- **Symptom:** QEMU exited instantly. `-accel whpx` failed:

  ```text
  qemu-system-x86_64: -accel whpx: WHPX: Failed to enable partition ...
  ```
- **Cause:** The Windows Hypervisor Platform feature isn't enabled (WSL2 uses Hyper-V but
  not WHPX), and enabling it needs admin.
- **Fix:** Fell back to TCG software emulation: `-accel tcg`. Slower first boot, but works
  with zero privileges.
- **Lesson:** TCG is the universal fallback. Accept the slow boot; the VM only boots once
  per deployment.

### 1.4 Debian 12 dropped the `asterisk` package

- **Symptom:** VM provisioning failed:

  ```text
  Package 'asterisk' has no installation candidate
  ```
- **Cause:** Debian 12 no longer ships an `asterisk` package in the base repos.
- **Fix:** Switched the VM base image to **Ubuntu 22.04**, where `asterisk` is in the
  `universe` repo. Bonus: it matches the WSL distro we test on, so behaviour is
  consistent. See [deploy/qemu/README.md](../deploy/qemu/README.md).
- **Lesson:** Pin the base image to one that actually packages your core dependency —
  verify `apt-cache policy` before committing to a distro.

### 1.5 Building a cloud-init seed ISO on Windows with no mkisofs

- **Symptom:** cloud-init needs a seed ISO, but Windows has no `mkisofs`/`genisoimage`
  and we couldn't install one.
- **Cause:** Standard ISO tooling is Linux-only; installing it needs admin.
- **Fix:** Built ISO9660+Joliet images (`CIDATA` and `UPESDATA` volume labels) using the
  **native Windows IMAPI2 COM API** from PowerShell, driving it with an inline C# `ISOFile`
  writer. No external tools, no admin. See
  [deploy/qemu/build-vm.ps1](../deploy/qemu/build-vm.ps1) and
  [deploy/qemu/README.md](../deploy/qemu/README.md).
- **Lesson:** Windows already ships an ISO burner (IMAPI2) — reach for the OS API before
  assuming you need to install a Unix utility.

### 1.6 Hosting a SIP server behind QEMU user-mode NAT (SLIRP)

- **Symptom:** With QEMU's default user-mode networking, the guest PBX advertised its
  private `10.0.2.15` address in SIP/SDP, so external LAN phones couldn't get media back.
- **Cause:** QEMU SLIRP user-mode NAT hides real client IPs from the guest and the guest
  has no idea what the laptop's LAN address is.
- **Fix:** Configured Asterisk to run **behind NAT**:
  - `external_media_address` / `external_signaling_address` = the laptop's real LAN IP
  - `rtp_symmetric = yes`, `force_rport = yes`
  - a small **fixed RTP range 10000–10019**, forwarded on all interfaces

  Proven: a softphone registering to the laptop's real LAN IP (`192.168.1.16`)
  registered and exchanged live RTP. See
  [deploy/asterisk/pjsip.conf](../deploy/asterisk/pjsip.conf),
  [deploy/asterisk/rtp.conf](../deploy/asterisk/rtp.conf).
- **Lesson:** A NAT'd PBX must be told its own public-facing address and a *fixed*,
  small RTP range you can forward — never let it advertise the private guest IP.

### 1.7 "Dynamic across routers" — the LAN IP moves with the laptop

- **Symptom:** Every time the van laptop joins a new network, its LAN IP changes, and the
  behind-NAT config from 1.6 points at the old address.
- **Cause:** The advertised LAN IP is the one piece of config that is environment-dependent.
- **Fix:** [deploy/qemu/Set-UpesLanIp.ps1](../deploy/qemu/Set-UpesLanIp.ps1) auto-detects
  the current LAN IP and rebinds Asterisk on every boot (and on demand). Documented that
  bridged networking / native Linux is the zero-touch production alternative.
- **Lesson:** Isolate the one value that changes per-site and automate it; don't hand-edit
  config on every move.

### 1.8 Windows Firewall blocks inbound by default

- **Symptom:** External LAN phones couldn't reach the PBX at all until a firewall rule was
  added — and adding one needs admin.
- **Cause:** Windows Firewall blocks inbound connections by default; SIP (UDP 5060) and the
  RTP range are dropped before they reach QEMU.
- **Fix:** Documented a **one-time elevated** command to open the ports, to run when an
  admin is available:

  ```powershell
  New-NetFirewallRule -DisplayName "UPES-ECS SIP/RTP" -Direction Inbound `
    -Protocol UDP -LocalPort 5060,10000-10019 -Action Allow
  ```

  See [deploy/qemu/README.md](../deploy/qemu/README.md).
- **Lesson:** Inbound reachability is a hard prerequisite — call it out as a one-time admin
  step in the runbook so it isn't discovered during a live drill.

---

## 2. Asterisk / SIP / audio

### 2.1 WSL2 headless softphone has no working audio source

- **Symptom:** Trying to prove audio with a headless `baresip` softphone failed two ways:

  ```text
  ausine: supports only 48kHz samplerate
  aufile: start_source failed ... Function not implemented
  ```
- **Cause:** The call negotiated **PCMU 8 kHz** (G.711) but baresip's `ausine` module only
  emits 48 kHz; `aufile` had no working source. WSL2/QEMU are headless — there is **no mic
  hardware** for a softphone to open.
- **Fix:** Proved the media path from the **server side** instead of the softphone's mic:
  - `pjsip show channelstats` RTP counters (~48 packets/s ≈ the G.711 20 ms frame rate)
  - the **server-side MixMonitor recording** as the audio artefact

  See [deploy/wsl-rtp-proof.sh](../deploy/wsl-rtp-proof.sh),
  [deploy/wsl-call-test.sh](../deploy/wsl-call-test.sh).
- **Lesson:** On headless VMs, don't fight for a fake mic — measure RTP at the PBX and let
  the recording be your proof of audio.

### 2.2 MixMonitor `,b` flag silently dropped unanswered recordings *(real defect we found)*

- **Symptom:** An **unanswered** 111 call produced a 44-byte empty WAV — a WAV header and
  no audio.
- **Cause:** The dialplan recorded with `MixMonitor(${FILE},b)`. The `b` flag records
  **only while the call is BRIDGED**, so anything before answer (ringing, queue, hold) and
  the whole voicemail leg were never captured. This directly contradicts **Feature 4**,
  which requires recording hold + voicemail too.
- **Fix:** Changed to `MixMonitor(${FILE})` — records the **whole call**. Verified: the
  same scenario went from **44 bytes → ~185 KB / 9.98 s** of real audio. Fixed in both
  [config/extensions_custom.conf](../config/extensions_custom.conf) and
  [SOP 09 – Dialplan Design](../SOP/09-Dialplan-Design.md); see also
  [Feature 4](../Docs/Feature-4.md).

  ```asterisk
  ; before (bug): only records the bridged segment
  same => n,MixMonitor(${MIXMONITOR_FILENAME},b)
  ; after (fix): records the whole call incl. hold + voicemail
  same => n,MixMonitor(${MIXMONITOR_FILENAME})
  ```
- **Lesson:** Test the *unhappy* path. A "recording works" check on an answered call would
  never have caught this; the empty WAV only appeared when nobody picked up.

### 2.3 `func_shell` `SHELL()` disabled by default

- **Symptom:** Incident-ID generation returned nothing — `SHELL()` produced no output.
- **Cause:** Asterisk gates `SHELL()` (and other risky functions) behind
  `live_dangerously`, which is off by default.
- **Fix:** Enabled `live_dangerously = yes` in `asterisk.conf` (applied by the VM setup
  script, [deploy/qemu/seed/setup-in-vm.sh](../deploy/qemu/seed/setup-in-vm.sh)). Incident
  IDs in the form `ERT-YYYYMMDD-NNNN` then generated correctly via
  [scripts/incident_id.sh](../scripts/incident_id.sh).
- **Lesson:** If a dialplan function silently does nothing, check whether Asterisk has
  gated it behind `live_dangerously` before debugging your script.

---

## 3. PowerShell & tooling gotchas

### 3.1 Auto-mode classifier blocked piping a remote script into `Invoke-Expression`

- **Symptom:** The plan to bootstrap via `irm get.scoop.sh | iex` was blocked.
- **Cause:** Two problems: piping an unseen **remote script straight into execution** is
  arbitrary remote code, and Scoop wasn't the tool the user asked for anyway.
- **Fix:** Downloaded the QEMU binary **directly** — the tool actually named — instead of
  bootstrapping a package manager we didn't want.
- **Lesson:** `curl | iex` / `irm | iex` is a code-execution smell. Fetch the exact
  artefact you need and verify it, rather than running someone else's installer blind.

### 3.2 `$pid` is a read-only automatic variable

- **Symptom:** `stop-vm.ps1` errored on assignment, and the fallback logic then tried to
  kill the **wrong** PID — nearly the shell itself.
- **Cause:** `$pid` is a **read-only automatic variable** in PowerShell (the current
  process ID). Assigning to it fails, leaving the variable holding the shell's own PID.
- **Fix:** Renamed the variable to `$vmpid`. See
  [deploy/qemu/stop-vm.ps1](../deploy/qemu/stop-vm.ps1).
- **Lesson:** Never reuse PowerShell automatic-variable names (`$pid`, `$input`, `$host`,
  `$error`, …). A shadowed automatic can turn a bug into a process-kill.

### 3.3 PowerShell 5.1 mangles embedded double-quotes when calling `ssh.exe`

- **Symptom:** The remote host received `asterisk -rx core` with the inner quotes stripped:

  ```text
  No such command 'core' (type 'core show help ...')
  ```
- **Cause:** Windows PowerShell 5.1's native-command argument passing strips/reorders
  embedded double-quotes before they reach `ssh.exe`, so `asterisk -rx "core show ..."`
  loses its quoting.
- **Fix:** **Base64-encode** the remote script and run it quote-free on the far side:

  ```powershell
  ssh $target "echo $b64 | base64 -d | bash"
  ```

  No quotes have to survive the PowerShell → ssh → shell trip.
- **Lesson:** When PS 5.1 quoting fights you, stop escaping — encode the payload so there's
  nothing left to mangle.

### 3.4 Git Bash (MSYS) path conversion mangles Linux paths

- **Symptom:** Linux paths handed to `docker`/`wsl` were rewritten, e.g. `/opt/...` became
  `C:/Program Files/Git/opt/...`.
- **Cause:** MSYS auto-converts anything that looks like a Unix path into a Windows path
  before passing it to the child process.
- **Fix:** Prefixed the affected commands with `MSYS_NO_PATHCONV=1`.
- **Lesson:** In Git Bash, guard container/WSL commands that carry Linux paths with
  `MSYS_NO_PATHCONV=1`.

### 3.5 UTF-8-without-BOM `.ps1` files break the PS 5.1 parser

- **Symptom:** Scripts failed to parse at lines unrelated to the real problem, e.g.:

  ```text
  Unexpected token 'G' in expression or statement
  ```
- **Cause:** The `.ps1` files were saved **UTF-8 without BOM** and contained em-dashes.
  PowerShell 5.1 assumes ANSI without a BOM, misreads the multi-byte characters, and the
  parser then derails on a *later, innocent* line.
- **Fix:** Re-saved every `.ps1` as **UTF-8 with BOM**, and added a parse-check step so a
  bad encoding is caught before the script is trusted.
- **Lesson:** For PS 5.1, always save scripts as UTF-8 **with BOM** — and distrust a parse
  error whose location makes no sense; suspect the encoding first.

---

## 4. Design corrections

### 4.1 SAP IDs come in two formats — 9-digit student *and* 8-digit staff

- **Symptom:** A dialplan that only matched the 9-digit student pattern would have silently
  broken all staff calling.
- **Cause:** UPES issues **two** real ID formats: 9-digit student SAP IDs (`5xxxxxxxx`,
  e.g. `500120597`) and 8-digit staff/employee IDs (`4xxxxxxx`, e.g. `40000001`). An
  early pattern assumed one length.
- **Fix:** The dialplan matches **both** (`_5XXXXXXXX` for students, `_4XXXXXXX` for staff).
  Confirmed the 4-**digit** fixed-device range (`4xxx`) does not collide — it's a different
  length. See [config/extensions_custom.conf](../config/extensions_custom.conf) and
  [SOP 09 – Dialplan Design](../SOP/09-Dialplan-Design.md).
- **Lesson:** Enumerate the *real* identifier formats before writing match patterns; one
  assumed length can exclude an entire user population.

### 4.2 Generalising ERT-only "positions" into `ctx_responder`

- **Symptom:** The early model treated only ERT roles as staffed "positions," leaving
  Medical / Security / Warden / Ops / IT modelled inconsistently.
- **Cause:** Those departments are **also** generic positions staffed by shift, not people
  — but they are **dispatch targets**, not 111-queue answerers.
- **Fix:** Introduced a dedicated **`ctx_responder`** context for Medical/Security/Warden/
  Ops/IT: they receive handoffs and join coordination rooms, but do **not** answer the ERT
  queue, page all-campus, or control the queue. See
  [config/extensions_custom.conf](../config/extensions_custom.conf),
  [provisioning/responder-positions.csv](../provisioning/responder-positions.csv), and
  [SOP 30 – ERT Roles & Shifts](../SOP/30-ERT-Roles-and-Shifts.md).
- **Lesson:** Distinguish "answers the emergency queue" from "gets dispatched to" — they
  need different contexts and different permissions.

---

## 5. Data integrity

### 5.1 Fabricated placeholder data had crept into CSVs and docs

- **Symptom:** Invented people and a wrong SAP ID (`500123456`) had appeared in CSVs and
  documentation.
- **Cause:** Placeholder/example data written before the real roster was confirmed, never
  cleaned out.
- **Fix:** Removed all of it. The system now uses **only** the confirmed roster in
  [../Notes/Confirmed Details.md](../Notes/Confirmed%20Details.md) (the real SAP ID example
  is `500120597`). Secrets ship as `__SET_ON_IMPORT__`, are generated with `openssl`, and
  are **never committed**. See [provisioning/pilot-users.csv](../provisioning/pilot-users.csv)
  and [provisioning/README.md](../provisioning/README.md). The stale `500123456` in the docs
  was corrected — logged in [Doc-Fixes.md](./Doc-Fixes.md).
- **Lesson:** Placeholder identities are a data-integrity risk. Keep a single source of
  truth for the roster and purge invented values before anything ships.

### 5.2 Status monitoring reported wrong numbers (disk % and registrations)

- **Symptom:** The health/status output showed an **empty disk %** and a **null
  registration count**.
- **Cause:** Two distinct parsing traps:
  - `df` on the recordings path was **permission-denied** to the non-root status user
    because the parent dir is `750`, so the query returned nothing.
  - `pjsip show contacts` prints `No objects found` — **not** `Objects found: 0` — when
    empty, so the count parsed as `null`.
- **Fix:** Query the **root filesystem** for disk usage instead of the locked-down
  recordings path, and count `Contact:` lines directly rather than trusting the summary
  string. See [scripts/upes-ecs-healthcheck.sh](../scripts/upes-ecs-healthcheck.sh).
- **Lesson:** A monitor that silently reports empty/null is worse than one that errors —
  validate parsers against the *empty* and *permission-denied* cases, not just the happy one.

---

*This log covers the roadblocks that actually occurred during build and test. It is
maintained alongside the code and config it references.*
