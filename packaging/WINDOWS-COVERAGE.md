# Windows binary — coverage & airtight proof

What the Windows distributable of UPES-ECS contains, what the build **proves**, and what
still needs real hardware / a live VM to validate. Produced by `packaging\Build-Installer.ps1`.

## The deliverable

| Artifact | What it is |
|---|---|
| `dist\UPES-ECS-Setup.exe` | The single self-extracting installer end users download. Whole payload + GUI inside. Double-click -> extracts to `%LOCALAPPDATA%\Programs\UPES-ECS` -> desktop shortcut -> launches the GUI. |
| `dist\stage\Deploy-UPES.exe` | The WinForms GUI compiled to a native exe (ps2exe). Runs standalone if the app folder is already present. |

## What the binary INCLUDES
- `Deploy-UPES.exe` — the operator GUI (pick language -> Deploy).
- `deploy\` — the whole PBX definition: QEMU builder, Asterisk config/dialplan, cloud-init,
  the language sound packs under `deploy\asterisk\sounds\`, `Add-UpesUser.ps1`, autostart, backups.
- `Console\` — Operations Console + the two LED-TV wallboards + `Run-Console.ps1` / `Show-TV.ps1`.
- `i18n\` — `languages.json` (drives the GUI language list) + the translation catalog.
- `api\`, `scripts\`, `config\`, `provisioning\` — status API, helper scripts, provisioning.
- Root scripts: `Install-UpesEcs.ps1`, `Deploy-UPES.ps1/.cmd`, `README.md`, `RUNBOOK.md`, etc.

## What the binary EXCLUDES (by design)
- The ~1.4 GB Flutter `app\` and `UPES-Safe.apk` — not needed to run the PBX.
- `secrets\` — never staged (robocopy `/XD secrets` + verified absent).
- Real SIP credentials — `pjsip_accounts.conf` ships as a **clean stub**; `*.filled.csv`,
  `*users*.csv`, `TEAM-CREDENTIALS.md` are stripped. The installed PBX starts with **no accounts**;
  they are added post-install one command at a time (`Add-UpesUser.ps1`, pins the secret once).
- `-IncludeSecrets` overrides this for **private same-org rebuilds only** (secret-scan asserts skipped).

## What "airtight" was PROVEN (automated, every build)
The build fails loudly (exit non-zero) unless ALL of these pass:

1. **Valid executables** — both `Deploy-UPES.exe` and `UPES-ECS-Setup.exe` start with the `MZ`
   PE header; the GUI exe is non-empty and tiny; the Setup.exe is within a sane size band (60-260 MB).
2. **No secrets in the clean build** — a whole-tree scan of every text file finds **0** lines
   matching `(password|secret)\s*=\s*[0-9a-f]{10,}`; `pjsip_accounts.conf` is the stub with no secret lines.
3. **No credential files** — 0 `*.filled.csv` / `*users*.csv` / `TEAM-CREDENTIALS.md` in the payload.
4. **No `app\` / no `secrets\`** — neither directory (nor any nested `secrets\`) is present in the payload.
5. **Payload completeness** — every functional dir (`deploy Console i18n api scripts config provisioning`)
   and `Install-UpesEcs.ps1` are staged.
6. **End-to-end deploy dry-run (no live VM touched)** — the build **extracts the packaged payload**
   to a throwaway folder and runs the real `Install-UpesEcs.ps1 -DryRun` for `-Language en` and `-Language hi`.
   `-DryRun` resolves the language, validates every path the deploy needs
   (`Deploy-UpesEcsVm.ps1`, `Register-Autostart.ps1`, `Add-UpesUser.ps1`, the accounts file,
   `Run-Console.ps1`, `Show-TV.ps1`, `languages.json`), prints the prerequisite + firewall PLAN
   read-only (installs/changes NOTHING), writes `region.json`, and exits 0 **without building,
   booting, or modifying the QEMU VM**.

Re-run just the checks against an existing build: `Build-Installer.ps1 -VerifyOnly`.

### Evidence (last verified build)
```
<<EVIDENCE>>
```

## What still needs real hardware / a live VM (NOT provable in packaging)
These are validated by the deploy itself and the runbooks, not by the Windows packaging step:
- Actually building + booting the QEMU Asterisk VM (downloads QEMU + Ubuntu; minutes).
- A real SIP phone registering to `upes-ecs.local:5060` and a live 111 call / DTMF / RTP audio.
- Language-pack overlay into the running VM (`sox` downsample), fail2ban, nightly backups.
- The firewall rule actually admitting LAN phones; multi-NIC / network-switch NAT behavior.
- Code-signing: not applied unless `-CertThumbprint` is supplied (then SmartScreen is satisfied).

## End-user steps
1. Download `UPES-ECS-Setup.exe`.
2. Double-click it. (Unsigned -> SmartScreen "More info -> Run anyway"; a signed build skips this.)
   It extracts to `%LOCALAPPDATA%\Programs\UPES-ECS`, makes a desktop shortcut, and opens the GUI.
3. In the GUI: pick the **Region / language**.
4. Click **Deploy**. The GUI shells out to `Install-UpesEcs.ps1 -Language <code>`, which self-elevates
   once (UAC) to install OpenSSH/7-Zip + the firewall rule, then builds + boots the PBX VM and starts the Console.
5. When it finishes: phones register to `upes-ecs.local:5060` and dial **111**. Everything auto-starts on logon.
6. Add users afterward: `powershell -File deploy\qemu\Add-UpesUser.ps1 -SapId <id> -Name "<name>"`.
