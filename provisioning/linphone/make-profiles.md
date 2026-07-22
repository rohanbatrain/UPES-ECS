# Make per-user Linphone profiles (recipe)

Turn the one template + the roster into one **filled XML per user**, serve the folder
on the LAN, and point each phone at its own URL (or a QR of it). Everything here is
**LAN-only** — no internet at runtime.

Inputs:
- [`linphone-provisioning-template.xml`](linphone-provisioning-template.xml) — the standardized profile with `__DOMAIN__` / `__SAPID__` / `__SECRET__` placeholders.
- [`users.csv`](users.csv) — the confirmed roster (`sapid,name,context,secret`), secrets held as `__SET_ON_IMPORT__`.

> **Secrets never go in git.** The committed template and CSV keep the literal
> placeholders. You generate the **filled** copies (`*.filled.xml`, `users.filled.csv`)
> at provisioning time, serve them, deliver the secret once, then delete them — the same
> `*.filled` pattern as [../README.md](../README.md#generating-secrets).

---

## 0. Prerequisites

- The PBX IP for **this** network — e.g. `192.168.1.16` (the Console shows it; or run
  `Set-UpesLanIp.ps1`). This becomes `__DOMAIN__`.
- The per-user SIP secret each account was created with (from the FreePBX import / the
  Console "Register a Client" generator). This becomes `__SECRET__`.

---

## 1. Generate one filled XML per user (PowerShell, Windows host)

Run from this folder. It reads `users.csv`, prompts for the PBX IP, and — because
secrets are **not** in the CSV — pulls each user's secret from a local, git-ignored
`secrets.txt` (`sapid=secret` per line) that you create by hand and delete after.

```powershell
# secrets.txt (create locally, DO NOT commit, delete after):
#   500120597=<that user's secret>
#   500000002=<...>
$domain  = Read-Host "PBX IP for this network (e.g. 192.168.1.16)"
$tpl     = Get-Content .\linphone-provisioning-template.xml -Raw
$secrets = @{}; Get-Content .\secrets.txt | ForEach-Object { $k,$v = $_ -split '=',2; $secrets[$k.Trim()] = $v }

Import-Csv .\users.csv | Where-Object sapid | ForEach-Object {
  $sap = $_.sapid.Trim()
  $sec = $secrets[$sap]; if (-not $sec) { Write-Warning "no secret for $sap — skipped"; return }
  ($tpl -replace '__DOMAIN__',$domain -replace '__SAPID__',$sap -replace '__SECRET__',$sec) |
    Set-Content -Encoding UTF8 ".\$sap.filled.xml"
  Write-Host "wrote $sap.filled.xml  ($($_.name))"
}
```

Bash/awk equivalent (Linux/Git-Bash):

```bash
domain=192.168.1.16
tail -n +2 users.csv | while IFS=, read -r sap name ctx _; do
  sec=$(grep "^$sap=" secrets.txt | cut -d= -f2-)
  [ -z "$sec" ] && { echo "no secret for $sap"; continue; }
  sed "s/__DOMAIN__/$domain/g; s/__SAPID__/$sap/g; s/__SECRET__/$sec/g" \
    linphone-provisioning-template.xml > "$sap.filled.xml"
done
```

Result: `500120597.filled.xml`, `500000002.filled.xml`, … — one profile per phone.
The `.filled.xml` glob is already secret-bearing; keep it out of git (see step 4).

---

## 2. Serve this folder over HTTP (LAN-only)

Any static file server works — the phone just needs to GET its `.filled.xml`.

**Option A — reuse the Console server** ([../../Console/Serve.ps1](../../Console/Serve.ps1)).
Point it at this folder (run elevated once so it binds all interfaces for LAN access):

```powershell
powershell -File ..\..\Console\Serve.ps1 -Port 8080 -RefreshSec 0
# then copy the .filled.xml files next to it, or run Serve.ps1 from a copy in this folder
```

**Option B — Python one-liner**, from inside this folder:

```bash
python -m http.server 8080 --bind 0.0.0.0
```

Either way the profiles are at `http://<PBX-or-laptop-IP>:8080/<SAPID>.filled.xml`,
e.g. `http://192.168.1.16:8080/500120597.filled.xml`. Same subnet, Wi-Fi client
isolation OFF (the #1 LAN gotcha).

---

## 3. Point each phone at its URL (or a QR)

On the phone, in Linphone: **Settings → Advanced → Remote provisioning** → paste the
user's URL → **restart the app**. Linphone fetches the XML and applies the whole
profile.

Faster at a desk: make a **QR of the URL** and let the user scan it (Linphone's
Assistant → *Scan QR code* / *Fetch remote configuration*). Any offline QR generator
works; keep the QR image out of git too — the URL points at a secret-bearing file.

```powershell
# print the per-user URLs to hand out / turn into QRs
$base = "http://192.168.1.16:8080"
Import-Csv .\users.csv | Where-Object sapid | ForEach-Object {
  "{0,-12} {1,-24} {2}/{0}.filled.xml" -f $_.sapid, $_.name, $base
}
```

---

## 4. Clean up (mandatory)

```powershell
Remove-Item .\*.filled.xml, .\secrets.txt, .\users.filled.csv -ErrorAction SilentlyContinue
```

Add to `.gitignore` so a filled copy can never be committed:

```gitignore
provisioning/linphone/*.filled.xml
provisioning/linphone/*.filled.csv
provisioning/linphone/secrets.txt
```

Deliver each secret **once, securely** (helpdesk / sealed sheet), then finish the
onboarding **self-test gate** in [README.md](README.md#4-onboarding-self-test-the-gate-to-active):
register → 198 → 199 → 111 → a peer SAP ID.
