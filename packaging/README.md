# Packaging — real Windows executables

Turns the deployment app into distributable `.exe` files. One command:

```powershell
powershell -ExecutionPolicy Bypass -File packaging\Build-Installer.ps1
```

The build is **self-verifying**: after producing the exes it automatically asserts they are valid PE files, the payload carries **no secrets/credentials** and no `app\`/`secrets\`, and it extracts the packaged payload and runs `Install-UpesEcs.ps1 -DryRun` end-to-end (never touching the live VM). It prints a **PASS/FAIL** summary and exits non-zero on any failure. See `WINDOWS-COVERAGE.md` for exactly what is proven.

## Outputs (`dist\`)

| File | What it is |
|---|---|
| **`UPES-ECS-Setup.exe`** (~114 MB) | **The distributable.** One self-extracting installer with the *whole* payload + the GUI inside. Double-click → extracts to `%LOCALAPPDATA%\Programs\UPES-ECS` → makes a desktop shortcut → launches the GUI. Nothing else needed on the target PC. |
| `dist\stage\Deploy-UPES.exe` (~45 KB) | The WinForms GUI compiled to a native exe (ps2exe). Runs standalone if the app folder is already present. |

## What's inside the installer
The functional payload only — `deploy\` (incl. the 205 voice WAVs = 41 × 5 langs), `Console\`, `i18n\`, `api\`, `scripts\`, `config\`, `provisioning\`, the root scripts, and `Deploy-UPES.exe`. The 1.4 GB Flutter `app\`, `secrets\`, and `UPES-Safe.apk` are **excluded**.

## Security — no secrets by default
The build ships a **clean `pjsip_accounts.conf` stub** (no SIP passwords) and strips any `*.filled.csv` / credential files. The installed system starts with **no user accounts**; add them after install:
```powershell
powershell -File deploy\qemu\Add-UpesUser.ps1 -SapId <id> -Name "<full name>"
```
`-IncludeSecrets` bakes your *current* accounts into the installer — **private, same-org rebuilds only**, never for anything you hand out.

```powershell
powershell -File packaging\Build-Installer.ps1 -IncludeSecrets   # DANGER: real secrets in the exe
```

## Flags

| Flag | Effect |
|---|---|
| `-Version 1.2.3` | Stamp the exe version. |
| `-IncludeSecrets` | Bake current SIP accounts in (private builds only). The secret-scan asserts are skipped for this mode. |
| `-VerifyOnly` | Re-run **only** the verification + dry-run against the existing `dist\` (no rebuild). |
| `-SkipGui` | Reuse the already-staged `Deploy-UPES.exe` (skip the ps2exe compile) — faster payload-only rebuilds. |
| `-NoDryRun` | Skip the extracted-payload dry-run step (the static verification still runs). |
| `-CertThumbprint <hex>` | Authenticode-sign `Deploy-UPES.exe` **before** packaging and `UPES-ECS-Setup.exe` **after**, then verify both signatures. |
| `-TimestampUrl <url>` | RFC-3161 timestamp server for signing (default DigiCert). |

Re-verify an existing build without rebuilding:
```powershell
powershell -ExecutionPolicy Bypass -File packaging\Build-Installer.ps1 -VerifyOnly
```
Signed production build:
```powershell
powershell -File packaging\Build-Installer.ps1 -CertThumbprint <hex> -TimestampUrl http://timestamp.digicert.com
```

## Requirements
- **ps2exe** — auto-installed from PSGallery on first run (needs internet once).
- **iexpress.exe** — built into Windows (no install).
- Windows PowerShell 5.1. Keep this script ASCII-only. Every step is idempotent / re-runnable.

## Notes
- Not code-signed by default → SmartScreen may warn on first run ("More info → Run anyway"). Supply `-CertThumbprint` (see above) for a signed build — it signs the GUI exe before packaging and the Setup.exe after, and verifies both.
- Bump the version: `-Version 1.1.0`.
