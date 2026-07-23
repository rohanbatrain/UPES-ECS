# UPES-ECS on macOS (native, single node)

A macOS-native install of the UPES-ECS campus emergency PBX. Asterisk runs
**natively via Homebrew** — no QEMU, no VM, no HA cluster. One Mac = one PBX.
Supports **Apple Silicon** (arm64, brew prefix `/opt/homebrew`) and **Intel**
(x86_64, `/usr/local`).

This is a LAN-only appliance: it must sit on a trusted, internet-isolated campus
network, exactly like the Windows/QEMU and Linux/Jetson deployments.

---

## What you get

| Component | Where | Port |
|-----------|-------|------|
| Asterisk (PJSIP) | `$(brew --prefix)/etc/asterisk` | SIP 5060/udp, WebSocket 8088 |
| FastAPI status/control API | `/opt/upes-ecs/api` (venv `/opt/upes-ecs/venv`) | 127.0.0.1:8090 |
| Console dashboard + `/api` proxy | `/opt/upes-ecs/console` | 8080 |
| Sounds (all packed language packs) | `$(brew --prefix)/share/asterisk/sounds` | — |
| State / incidents / safety | `/var/lib/upes-ecs` | — |

All three run as **launchd LaunchAgents** in your user session, with a
**foreground fallback** (`/opt/upes-ecs/run-foreground.sh`) for debugging.

---

## Install (one command)

You received a single self-extracting file: **`upes-ecs-macos-installer.command`**.

### Option A — Terminal
```sh
chmod +x upes-ecs-macos-installer.command
./upes-ecs-macos-installer.command                 # English
./upes-ecs-macos-installer.command --language hi   # Hindi voice + Console
./upes-ecs-macos-installer.command --lang hi       # Hindi installer MESSAGES (see below)
./upes-ecs-macos-installer.command --lan-ip 10.20.30.5   # pin the LAN IP
```

> Two independent language knobs:
> `--language <code>` sets the deployed **PBX voice + Console** pack (all 44 codes);
> `--lang <code>` sets the language of the **installer's own progress/error output**
> (auto-detected from your macOS locale — see "Installer language" below).

### Option B — Finder double-click
Double-click `upes-ecs-macos-installer.command`. Because it is unsigned, macOS
Gatekeeper will block the first launch (see next section).

**Prerequisite:** Homebrew must be installed. If it is missing the installer
stops and prints the official one-liner — it will **not** silently pipe a script
into your shell:
```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# Apple Silicon: then add brew to PATH
eval "$(/opt/homebrew/bin/brew shellenv)"
```

The installer will run `brew install asterisk python@3`, and will `sudo mkdir`
the system state dirs `/opt/upes-ecs` and `/var/lib/upes-ecs` (chowned to you),
so it may prompt for your password once.

---

## Gatekeeper / quarantine (unsigned build)

This installer is **not code-signed or notarized**, so macOS quarantines it on
first download. Pick one:

- **Right-click → Open** (Finder), then confirm **Open** in the dialog. macOS
  remembers the choice.
- Or strip the quarantine attribute from Terminal:
  ```sh
  xattr -dr com.apple.quarantine upes-ecs-macos-installer.command
  ```
- On recent macOS you may instead approve it under
  **System Settings → Privacy & Security → "Open Anyway"** after the first block.

**Production path (recommended):** sign and notarize the artifact so no user has
to touch quarantine at all:
```sh
codesign --force --deep --sign "Developer ID Application: <YourOrg> (<TEAMID>)" upes-ecs-macos-installer.command
xcrun notarytool submit upes-ecs-macos-installer.command --keychain-profile <profile> --wait
# .command files are not staple-able; notarization alone clears Gatekeeper.
```

---

## Apple Silicon vs Intel

The installer auto-detects the arch and Homebrew prefix — nothing to configure:

| | Apple Silicon (arm64) | Intel (x86_64) |
|---|---|---|
| brew prefix | `/opt/homebrew` | `/usr/local` |
| asterisk binary | `/opt/homebrew/sbin/asterisk` | `/usr/local/sbin/asterisk` |
| config | `/opt/homebrew/etc/asterisk` | `/usr/local/etc/asterisk` |

On both, `install-macos.sh` writes a self-contained `asterisk.conf` whose
`[directories]` all point under the brew prefix (the stock `/var/...` defaults do
not exist on macOS).

---

## launchd vs foreground

**launchd (default, survives logout/reboot of the session):**
```sh
UID=$(id -u)
launchctl print   gui/$UID/com.upes-ecs.asterisk      # status
launchctl kickstart -k gui/$UID/com.upes-ecs.asterisk # restart
launchctl bootout gui/$UID/com.upes-ecs.console       # stop one
```
Plists live in `~/Library/LaunchAgents/com.upes-ecs.{asterisk,api,console}.plist`.
Logs: `$(brew --prefix)/var/log/asterisk/com.upes-ecs.*.log`.

**Foreground (debugging, no launchd):**
```sh
/opt/upes-ecs/run-foreground.sh      # Ctrl-C stops all three
```

> LaunchAgents run in your **user** session. For a headless always-on box, log
> the operator account in with auto-login, or promote the plists to
> `/Library/LaunchDaemons` (system context) — note that then Asterisk runs as
> root and the `/opt/upes-ecs` + `/var/lib/upes-ecs` owners should be adjusted
> accordingly.

---

## Add a user (post-install)

**No SIP secrets ship in the installer.** The packaged `pjsip_accounts.conf` is a
clean stub with zero accounts. Add users after install by appending a block to
`$(brew --prefix)/etc/asterisk/pjsip_accounts.conf`:

```ini
[4201](endpoint-tpl)
context=ctx_responder
auth=4201
aors=4201
callerid=Medical Responder 1 <4201>
[4201](auth-tpl)
username=4201
password=<CHOOSE-A-STRONG-SECRET>
[4201](aor-tpl)
```
then reload:
```sh
asterisk -rx "pjsip reload"
asterisk -rx "pjsip show endpoints"   # confirm it registered
```
Record the secret in your own secrets store (never commit it). Contexts:
`ctx_student`, `ctx_staff`, `ctx_ert`, `ctx_ert_lead`, `ctx_control_room`,
`ctx_responder`, `ctx_responder_lead`.

---

## Switch language

```sh
./upes-ecs-macos-installer.command --language te   # re-run with a new language
```
Or in place: set `"language"` in `/opt/upes-ecs/console/region.json` and confirm
the pack exists under `$(brew --prefix)/share/asterisk/sounds/<code>/`.
Packed languages: `en hi te ml ur ne ar bg ca cs cy da de el es eu fa fi fr hu`.

---

## Installer language (operator messages)

Separate from the PBX voice/Console language, the **installer localizes its own
progress and error output**. It auto-detects the operator locale in this order:

1. `--lang <code>` if you pass it (explicit override),
2. macOS `defaults read -g AppleLocale` (e.g. `en_IN` → `en`, `hi_IN` → `hi`),
3. `$LC_ALL` / `$LANG`,
4. English as the guaranteed fallback.

The locale is normalized to a short code (`hi_IN.UTF-8` → `hi`). If no catalog
ships for the detected code, the installer silently prints English — nothing
breaks. Every user-facing line is routed through a small `msg <key>` function; a
key missing in a given language falls back to its English text (so partial
catalogs are safe).

**Message catalogs live in `deploy/macos/i18n/<code>.sh`** — a clean, extensible
mechanism. To add a language, copy an existing catalog, translate the templates
(keep the `%s` placeholders and technical tokens like `brew`, `sudo`, `SIP`,
`111`, `ERT`, paths and URLs untranslated), and name the file `<code>.sh`.

**Translated installer languages (curated core set, 11):**

| Code | Language | Code | Language |
|------|----------|------|----------|
| `en` | English (built-in fallback) | `ne` | Nepali |
| `hi` | Hindi | `es` | Spanish |
| `te` | Telugu | `fr` | French |
| `ml` | Malayalam | `de` | German |
| `ur` | Urdu (RTL) | `pt` | Portuguese |
|      |          | `ar` | Arabic (RTL) |

All non-English catalogs are **AI first-pass drafts** and must be native-reviewed
before go-live (consistent with the voice/UI packs in `i18n/languages.json`).
Only these curated codes have translated **installer messages**; any other
`--lang` value (or an OS locale outside this set) falls back to English output.
This is deliberate: ~10 solid catalogs beat 44 sloppy ones. The English text is
embedded in `install-macos.sh` itself, so English never depends on a catalog file.

---

## Robustness (production hardening)

`install-macos.sh` is hardened for unattended production runs:

- **`set -euo pipefail`** plus an **`ERR` trap** that prints the failing line and
  exit code (localized) and makes clear nothing was force-started — then you can
  safely re-run, because every step is **idempotent**.
- **`EXIT` trap** cleans up the scratch temp dir.
- **Preflight checks** before any mutation: macOS version (warns below the tested
  minimum, macOS 11), CPU arch / Homebrew-prefix awareness (Apple Silicon vs
  Intel), required core commands (fatal with an `xcode-select --install` hint if
  missing), free disk space (warns below ~1.5 GB), and a heads-up that `sudo` may
  prompt once.
- **Homebrew** is required, never auto-`curl|bash`-ed: if `brew` is absent the
  installer prints the official one-liner and the Apple-Silicon PATH line, then
  stops.
- **Gatekeeper/quarantine** guidance is printed in the summary and documented
  above, for the unsigned self-extractor case.

## Validation status — BUILT ON WINDOWS, NOT YET RUN ON A MAC

**Honest disclosure:** this deployment was authored and packaged on a Windows
host. There is no macOS/Darwin available here, so it could **not** be executed
end-to-end. What *was* done:

- `bash -n` syntax check — **pass** (installer, foreground fallback, and all
  `i18n/*.sh` message catalogs).
- The localization router (locale detection/normalization, catalog loading,
  per-key English fallback, `printf` template formatting incl. RTL) was
  **exercised in isolation** and verified.
- `shellcheck` — **was not available in the environment that produced this
  hardened revision**, so it could not be re-run here; the change was manually
  reviewed and is written to stay shellcheck-clean (`SC2059` is suppressed with
  an inline directive where a controlled template is used as a format string).
  Re-run `shellcheck -x deploy/macos/install-macos.sh` on a box that has it.
- Self-extractor **built and its archive extraction dry-run verified** via WSL
  (Ubuntu, x86_64). WSL exercises only the *platform-independent* extract/copy
  logic; the Homebrew/launchd/`ipconfig` steps are macOS-only and were **not**
  run there. **WSL is NOT a macOS test.**
- Secret scan of the packaged payload — **0** secret-looking lines, **0**
  credential files.

### A Mac owner MUST run these to confirm it is airtight
(the same checks the Linux/Jetson agent runs)

```sh
# 1. Install
chmod +x upes-ecs-macos-installer.command && ./upes-ecs-macos-installer.command

# 2. Dialplan really has the 111 emergency entry
#    (defined in [ctx_emergency_111]; included by every user context e.g. ctx_student)
asterisk -rx "dialplan show 111@ctx_emergency_111" | head
asterisk -rx "dialplan show 111@ctx_student" | head

# 3. PJSIP transport + endpoints loaded, external addr = LAN IP
asterisk -rx "pjsip show transports"
asterisk -rx "pjsip show endpoints"
grep external_media_address $(brew --prefix)/etc/asterisk/pjsip.conf

# 4. API is up
curl -s http://127.0.0.1:8090/health

# 5. Console serves + proxies the API
curl -s -o /dev/null -w '%{http_code}\n' http://<lan-ip>:8080/
curl -s http://<lan-ip>:8080/api/health

# 6. A real SIP softphone registers to <lan-ip>:5060 and dialing 111 reaches
#    the ERT queue with 2-way audio (this is the only true end-to-end proof).
```

### Known residual gaps (need a real Mac to close)
- Homebrew asterisk module set / formula version differences vs Debian could
  surface a missing `res_*` module — verify with `asterisk -rx "module show"`.
- The API's Linux-style CDR/recording paths (`/var/log/asterisk/cdr-csv`,
  `/var/spool/asterisk/monitor`) are re-homed under the brew prefix by our
  `asterisk.conf`; the API reads the old absolute paths defensively (degrades to
  empty, never 500s) — CDR/recording panels may be blank until reconciled.
- Codesign/notarize for a clean Gatekeeper experience (see above) — optional but
  recommended for production distribution.
