# UPES-ECS — Linux-native single-node install

A LAN-only campus **emergency PBX** (Asterisk) packaged as **one self-extracting
binary** for x86_64 Ubuntu/Debian. Asterisk runs **natively** on the node — no
QEMU, no Jetson/ARM, no HA/VIP. One command installs the emergency dialplan (dial
**111**), the PJSIP transport/endpoints, the voice prompts (English + an optional
regional language pack), the status **API** (:8090) and the operations **Console**
(:8080).

This is the generalisation of `deploy/jetson/install-jetson.sh` to a single
x86_64 node, minus keepalived/VIP/config-sync.

---

## 1. Install (the one command)

Copy `upes-ecs-linux-installer.run` to the target node and run:

```bash
sudo ./upes-ecs-linux-installer.run --iface eth0
```

Options:

| Flag | Meaning | Default |
|------|---------|---------|
| `--iface <nic>` | NIC whose IPv4 becomes the SIP/media address | *(required unless `--lan-ip`)* |
| `--lan-ip <ip>` | Set the LAN IP explicitly (skips iface lookup) | derived from `--iface` |
| `--language <code>` | Voice + Console language: `en hi te ml ur ne` | `en` |
| `--lang <code>` | Language of the **installer's own** on-screen messages | auto-detected from `$LC_ALL`/`$LC_MESSAGES`/`$LANG`, else `en` |
| `--no-start` | Install but don't start services (systemd only) | *(start)* |

> `--language` is what **callers hear** (voice prompts) and what the Console shows.
> `--lang` is only the language of the text **this installer prints** while it runs;
> the two are independent.

Example with Hindi prompts on `ens33`:

```bash
sudo ./upes-ecs-linux-installer.run --iface ens33 --language hi
```

The `.run` is a single executable that extracts the whole payload to a temp dir
and runs `deploy/linux/install-linux.sh`. It is **idempotent** — re-running it
re-lays config and restarts services without duplicating anything. Any existing
`/etc/asterisk/*.conf` it overwrites is first backed up to
`/etc/asterisk/upes-backup-<timestamp>/`.

When it finishes you'll see:

```
  Dial 111 ............ campus emergency hotline (test with 199 first)
  Console ............. http://<lan-ip>:8080
  API (loopback) ..... http://127.0.0.1:8090/health
  Phones register to .. <lan-ip>:5060  (SIP/UDP)
```

---

## 2. What gets installed

| Path | What |
|------|------|
| `/etc/asterisk/*.conf` | dialplan (`extensions*.conf`), `pjsip.conf` + `pjsip_accounts.conf`, `queues.conf`, `rtp.conf`, `http.conf`, … |
| `/usr/share/asterisk/sounds/en` + `/<lang>` | voice prompts (English base + chosen language pack) |
| `/opt/upes-ecs/` | helper scripts, `groups/`, `api/upes_api.py`, `console/`, `venv/`, `serve-console.py` |
| `/var/lib/upes-ecs/` | runtime state (incidents, alerts, rollcall, safety, …) |
| `/etc/systemd/system/{upes-api,serve-console}.service` | services (systemd hosts only) |

The status API runs from a **Python venv** (`/opt/upes-ecs/venv`) with
`fastapi` + `uvicorn[standard]` — nothing is installed into the system Python.

---

## 3. systemd vs foreground

The installer detects the init system:

* **systemd present** (`/run/systemd/system` exists) → installs and starts
  `asterisk`, `upes-api`, `serve-console` units (plus an `asterisk` auto-restart
  drop-in). Manage them the usual way:

  ```bash
  systemctl status upes-api serve-console asterisk
  journalctl -u upes-api -f
  ```

* **no systemd** (containers, minimal WSL) → installs
  `/opt/upes-ecs/run-foreground.sh`. Start everything with:

  ```bash
  sudo /opt/upes-ecs/run-foreground.sh      # Ctrl-C to stop; logs in /var/log/upes-ecs/
  ```

---

## 4. Add a user (post-install)

**No SIP accounts and no passwords ship in the installer** (security rule). The
packaged `pjsip_accounts.conf` is a clean stub. Add users on the node:

1. Edit `/etc/asterisk/pjsip_accounts.conf` and append an endpoint/auth/aor
   triple (the templates `(endpoint-tpl)`, `(auth-tpl)`, `(aor-tpl)` are defined
   in `pjsip.conf`):

   ```ini
   [4130](endpoint-tpl)
   context=ctx_ert
   auth=4130
   aors=4130
   callerid=ERT Operator 5 <4130>
   [4130](auth-tpl)
   username=4130
   password=<a strong unique secret>
   [4130](aor-tpl)
   ```

2. Reload:

   ```bash
   asterisk -rx 'pjsip reload'
   asterisk -rx 'pjsip show endpoints'
   ```

Use a strong, unique secret per account. Record secrets in your own out-of-band
store — never commit them.

---

## 5. Switch language later

Re-run the installer with a different `--language`, or manually:

```bash
# copy the pack + point region.json at it
sudo cp -a deploy/asterisk/sounds/lang/te/. /usr/share/asterisk/sounds/te/
# edit /opt/upes-ecs/console/region.json  ->  "language": "te"
```

Prompt playback resolves `sounds/<channel-lang>/upes-ecs/<file>` and falls back to
`sounds/en/...`, so English is always the safety net. The Console localises its UI
from `region.json` + `ui-lang/<code>.json`.

Available packs in this build: **en** (base), **hi, te, ml, ur, ne**.

---

## 6. Installer messages (operator UI) + robustness

The installer localises **its own output** (banners, section headers, preflight
errors, the final summary) so a non-English operator can read what it's doing. It
picks the language from `$LC_ALL` → `$LC_MESSAGES` → `$LANG` (stripping the
encoding/territory, e.g. `hi_IN.UTF-8` → `hi`), or you can force it with
`--lang <code>`. English is always the guaranteed fallback: any string a catalog
doesn't translate is printed in English, and an unknown/absent locale simply runs
in English (with a one-line note).

Translated installer catalogs shipped in this build (AI first-pass drafts —
native-review before go-live, same posture as the voice packs):
**en** (built in) + **hi, te, ml, ur, ne, es, fr, de, pt, ar**. Catalogs live in
`deploy/linux/i18n/<code>.sh` — one `MSG[key]="..."` per line — so adding a
language is just dropping in another file; no change to `install-linux.sh`.

```bash
sudo ./upes-ecs-linux-installer.run --iface eth0 --language hi --lang hi   # audio + messages in Hindi
sudo ./upes-ecs-linux-installer.run --iface eth0 --lang fr                 # English audio, French installer output
```

**Robustness.** The script runs under `set -euo pipefail` with an `ERR` trap that
names the failing line and cleans up temp state, and an `EXIT` trap that always
tidies up. Preflight fails **early with an actionable message** when: not run as
root, `deploy/asterisk`/`api` not found (wrong cwd), a core tool
(`awk`/`sed`/`grep`/`df`/`ip`) is missing, less than 256 MB is free under
`/var/lib`, or `--iface` yields no IPv4. Re-runs stay idempotent (config backed
up, groups/venv/PIN left in place).

---

## 7. Firewall / LAN-only posture

Nothing here is meant to face the internet. On a campus LAN leave it open; if the
node is multi-homed or you want a belt-and-braces filter, allow only the LAN:

| Port | Proto | Service |
|------|-------|---------|
| 5060 | UDP | SIP signalling (phones register) |
| 10000–10019 | UDP | RTP media (`rtp.conf`) |
| 8088 | TCP | WebSocket for the UPES Safe mobile app |
| 8080 | TCP | Console (operators) |
| 8090 | TCP | **loopback only** — status API (never expose) |

The API binds `127.0.0.1:8090`; the Console proxies `/api/*` to it, so the API is
never reachable from the LAN directly.

---

## 8. Building the installer

From the Windows host (or inside WSL/Linux):

```bash
wsl -- bash -lc '/mnt/c/Users/Rohan/UPES/deploy/linux/build-linux-binary.sh'
```

Output: `dist/upes-ecs-linux-installer.run`. The build stages the payload,
**replaces `pjsip_accounts.conf` with a clean stub**, strips
`secrets/`, `*.filled.csv`, `TEAM-CREDENTIALS.md`, `*users*.csv`, then **scans the
payload for secret-looking lines and aborts if any survive**. It prefers
`makeself`; if unavailable/offline it hand-rolls a `#!/bin/sh` + appended `tar.gz`
self-extractor. The Flutter `app/`, the APK, `.git`, and `secrets/` are never
staged.

---

## 9. Airtight WSL test — results

Built and installed fresh in WSL (Ubuntu-22.04, x86_64, systemd on, Asterisk
18.10). See the delivery report for the full transcript. Summary:

* `sudo ./upes-ecs-linux-installer.run --iface <nic>` → exit 0.
* `asterisk -rx 'core show version'` → Asterisk 18.10, our config loaded.
* `asterisk -rx 'dialplan show ctx_emergency_111'` → the **111** hotline context
  present.
* `pjsip show endpoints` / `pjsip show aors` → transports load, **no** config
  errors (accounts empty by design — the stub ships no users).
* `dialplan reload` → no ERROR lines in the CLI/log.
* `curl -s localhost:8090/health` → `{"ok":true,"service":"upes-api"}`; `/status`
  returns the full JSON snapshot.
* `curl -s localhost:8080/` → dashboard HTML; `curl -s localhost:8080/api/health`
  proxies to the API.
* Chosen language pack in `/usr/share/asterisk/sounds/<code>` and reflected in
  `region.json`.

### WSL-specific quirks handled

* **systemd** — WSL2 may or may not run systemd. The installer detects
  `/run/systemd/system` and falls back to `run-foreground.sh` when it's absent.
* **RTP ports** — kept to the small fixed range `10000–10019` (`rtp.conf`); no
  port-forwarding needed for a native node.
* **`/mnt/c` perms** — the build reads the repo from `/mnt/c/...`, but *installs*
  into native Linux paths (`/etc`, `/opt`, `/usr/share`), so DrvFs permission
  quirks never affect the running system.
* **CRLF** — every shipped `.sh`/`.conf` is `sed -i 's/\r$//'` normalised on
  install, so Windows-checkout line endings don't break Asterisk or bash.
