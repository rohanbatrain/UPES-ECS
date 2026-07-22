<#
.SYNOPSIS
  ONE script to stand up the entire UPES-ECS emergency system on a fresh Windows PC.

.DESCRIPTION
  Run this once on a new Windows 10/11 machine (from inside a copy of this repo) and it does
  EVERYTHING:
    1. Installs the host prerequisites it needs (OpenSSH client, 7-Zip) if missing  [1 UAC prompt]
    2. Opens the Windows Firewall for SIP/RTP so LAN phones can reach the PBX          [same prompt]
    3. Builds + boots the QEMU Asterisk PBX VM (downloads QEMU + Ubuntu, self-configures
       Asterisk, the dialplan, all accounts, the status API, fail2ban, nightly backups)
    4. Registers Windows autostart so the VM + Console come back on every logon (no admin)
    5. Generates the LED-TV name directory, starts the Operations Console (:8080)
    6. (optional) Opens the two campus LED-TV wallboards in kiosk mode

  After it finishes: phones register to the shown LAN IP:5060 and dial 111. Everything
  survives reboots. To add a user later:  deploy\qemu\Add-UpesUser.ps1 -SapId <id> -Name "<name>"

  PREREQUISITE: copy this whole repo folder onto the new PC first (USB / git clone), then run
  this script from the repo root. Internet is needed only for the first build (QEMU + Ubuntu).

.PARAMETER LanIp        Phone-LAN IP Asterisk advertises. Default: auto-detected default-route IPv4.
.PARAMETER Base         Runtime dir for the VM + SSH key. Default %USERPROFILE%\qemu.
.PARAMETER Language     Region/prompt language code from i18n\languages.json (default 'en' = English).
                        When set to a non-English pack that exists under deploy\asterisk\sounds\lang\<code>\,
                        those WAVs are pushed into the running VM (downsampled to 8k) so 111/102/paging
                        speak that language. Missing pack -> English is kept and a warning is printed.
.PARAMETER Source       Optional release bundle to deploy INSTEAD of this repo. A URL to a .zip, a local
                        .zip, or a local folder (a repo copy with config/ scripts/ deploy/ Console/ i18n/).
                        A URL/zip is extracted to <Base>\repo (persistent) and everything is deployed from
                        there. Unset = deploy from this repo (offline default).
.PARAMETER DryRun       Validate + resolve the language, write Console\region.json, print the plan, and
                        STOP without touching prerequisites, the VM, autostart, or the Console. Safe test.
.PARAMETER Memory/Cpus  VM sizing. Default 2048 MB / 2 vCPU.
.PARAMETER SkipCallTest Skip the automated test call to 111 at the end of the VM build.
.PARAMETER LaunchTV     After setup, open both LED-TV boards (safety on monitor 0, ops on monitor 1).
.PARAMETER NoConsole    Don't start the Console now (autostart still installed).
.PARAMETER Rebuild      Wipe and rebuild the VM disk from the base image.
.PARAMETER Uninstall    Stop the VM and remove autostart + firewall rule (undo).

.EXAMPLE  powershell -ExecutionPolicy Bypass -File Install-UpesEcs.ps1
.EXAMPLE  powershell -ExecutionPolicy Bypass -File Install-UpesEcs.ps1 -LanIp 192.168.0.3 -LaunchTV
#>
[CmdletBinding()]
param(
  [string]$LanIp,
  [string]$Base = "$env:USERPROFILE\qemu",
  [int]$Memory = 2048,
  [int]$Cpus = 2,
  [string]$Language = 'en',
  [string]$Source,
  [switch]$SkipCallTest,
  [switch]$LaunchTV,
  [switch]$NoConsole,
  [switch]$Rebuild,
  [switch]$DryRun,
  [switch]$Uninstall
)
$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
$qdir = Join-Path $repo 'deploy\qemu'
$cdir = Join-Path $repo 'Console'
$FW   = 'UPES-ECS SIP-RTP'

function Head($m){ Write-Host "`n============================================================" -ForegroundColor Cyan; Write-Host " $m" -ForegroundColor Cyan; Write-Host "============================================================" -ForegroundColor Cyan }
function Step($m){ Write-Host "`n==> $m" -ForegroundColor Cyan }
function Info($m){ Write-Host "    $m" }
function Ok($m){ Write-Host "    [ok] $m" -ForegroundColor Green }
function Warn($m){ Write-Host "    [!] $m" -ForegroundColor Yellow }
function Die($m){ Write-Host "`n[FAIL] $m" -ForegroundColor Red; exit 1 }
function Test-Admin { ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator) }
function Have($cmd){ [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }
function SshOk { (Have 'ssh') -or (Test-Path "$env:WINDIR\System32\OpenSSH\ssh.exe") }
function SevenZip { @("$env:ProgramFiles\7-Zip\7z.exe","${env:ProgramFiles(x86)}\7-Zip\7z.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1 }
function FwPresent { [bool](Get-NetFirewallRule -DisplayName $FW -ErrorAction SilentlyContinue) }

# --- regional / language helpers -------------------------------------------
# SSH into the (already-built, running) VM the same way Deploy-UpesEcsVm.ps1 does.
$SshOpt = @('-o','StrictHostKeyChecking=no','-o','UserKnownHostsFile=NUL','-o','ConnectTimeout=12','-o','BatchMode=yes')

function Get-LangInfo($code) {
  # Return @{ name; native } for a code from i18n\languages.json, or $null if not listed.
  try {
    $p = Join-Path $repo 'i18n\languages.json'
    if (-not (Test-Path $p)) { return $null }
    # Read as UTF-8 explicitly: PS5.1 Get-Content defaults to ANSI and would mojibake native names.
    $j = [IO.File]::ReadAllText($p) | ConvertFrom-Json
    $e = $j.languages | Where-Object { $_.code -eq $code } | Select-Object -First 1
    if ($e) { return @{ name = "$($e.name)"; native = "$($e.native)" } }
  } catch { Warn "could not read i18n\languages.json: $($_.Exception.Message)" }
  return $null
}

function Write-Region($code,$name,$native,$prompts,$source) {
  # The record of the ACTIVE deployed region (Console dashboard reads this).
  $obj = [ordered]@{
    schema       = 'upes-ecs.region/v1'
    language     = $code
    languageName = $name
    native       = $native
    prompts      = $prompts                 # 'packed' | 'english-fallback'
    source       = $source                  # 'local' | '<url-or-path>'
    deployedAt   = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
  }
  New-Item -ItemType Directory -Force $cdir | Out-Null
  $path = Join-Path $cdir 'region.json'
  # ConvertTo-Json (PS5.1) escapes non-ASCII natives to \uXXXX -> file stays ASCII-safe + valid JSON.
  [IO.File]::WriteAllText($path, ($obj | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
  Ok ("region.json - {0} ({1}), prompts={2}, source={3}" -f $name, $code, $prompts, $source)
}

function Wait-VmSsh($key) {
  # Return $true once the VM answers over SSH (a fresh build normally leaves it up already).
  if (-not (Test-Path $key)) { Warn "SSH key not found ($key)"; return $false }
  if (-not (Have 'ssh') -and -not (Test-Path "$env:WINDIR\System32\OpenSSH\ssh.exe")) { Warn "ssh.exe not available"; return $false }
  for ($i=0; $i -lt 6; $i++) {
    $r = ssh.exe -q -i $key -p 2222 @SshOpt ubuntu@127.0.0.1 'echo UP' 2>$null
    if (($r -join '') -match 'UP') { return $true }
    Start-Sleep -Seconds 5
  }
  Warn "VM SSH not reachable"; return $false
}

function Push-LangPrompts($key,$code,$langDir) {
  # Install ONE language pack into its OWN language folder  sounds/<code>/upes-ecs/...
  # (NEVER sounds/en -- English stays the pristine per-file fallback), downsampling to
  # Asterisk 8k with sox in-VM. The dialplan's Set(CHANNEL(language)=<code>) then serves
  # these automatically. Returns $true only if the copy + install succeeded.
  ssh.exe -q -i $key -p 2222 @SshOpt ubuntu@127.0.0.1 'rm -rf /tmp/upes-lang-stage' 2>$null | Out-Null
  scp.exe -q -r -i $key -P 2222 @SshOpt "$langDir" ubuntu@127.0.0.1:/tmp/upes-lang-stage 2>$null
  if ($LASTEXITCODE -ne 0) { Warn "copying the '$code' pack to the VM failed (that language falls back to English)"; return $false }
  # Single-quoted here-string = literal bash; the language code is passed as $1 (bash -s <code>)
  # so it can never be shell-injected from PowerShell string interpolation.
  $sh = @'
set -e
CODE="${1:?language code required}"
STAGE=/tmp/upes-lang-stage
DEST="/usr/share/asterisk/sounds/${CODE}"
mkdir -p "$DEST"
find "$STAGE" -type f -name '*.wav' | while read -r f; do
  rel="${f#$STAGE/}"; out="$DEST/$rel"; mkdir -p "$(dirname "$out")"
  if command -v sox >/dev/null 2>&1; then sox "$f" -r 8000 -c 1 -b 16 "$out" 2>/dev/null || cp -f "$f" "$out"; else cp -f "$f" "$out"; fi
done
N=$(find "$STAGE" -type f -name '*.wav' | wc -l)
chown -R asterisk:asterisk "$DEST" 2>/dev/null || true
asterisk -rx 'module reload res_sound.so' >/dev/null 2>&1 || true
echo "installed $N wav(s) into sounds/${CODE}"
'@
  $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($sh -replace "`r","")))
  $res = ssh.exe -q -i $key -p 2222 @SshOpt ubuntu@127.0.0.1 "echo $b64 | base64 -d | sudo bash -s '$code'" 2>$null
  Info ("[$code] " + ($res -join ' '))
  return $true
}

function Push-EnglishBase($key,$enDir) {
  # Install the COMMITTED, complete English base pack (deploy\asterisk\sounds\en\) into the box's
  # sounds/en/ (downsampled to 8k). English is the always-complete per-file fallback for EVERY
  # language, so it must never be partial. This overwrites whatever first-boot TTS produced with
  # the shipped, verified 42-prompt set -- removing the "first-boot TTS half-failed -> the coach
  # plays the intro then silence" failure mode. Returns $true on success.
  if (-not (Test-Path $enDir)) { Warn "committed English base not found at $enDir - keeping on-box-generated English"; return $false }
  if (-not (Get-ChildItem $enDir -Recurse -Filter *.wav -EA SilentlyContinue | Select-Object -First 1)) { Warn "committed English base has no WAVs - keeping on-box-generated English"; return $false }
  if (-not (Wait-VmSsh $key)) { Warn "VM SSH not reachable - English base not refreshed"; return $false }
  ssh.exe -q -i $key -p 2222 @SshOpt ubuntu@127.0.0.1 'rm -rf /tmp/upes-en-stage' 2>$null | Out-Null
  scp.exe -q -r -i $key -P 2222 @SshOpt "$enDir" ubuntu@127.0.0.1:/tmp/upes-en-stage 2>$null
  if ($LASTEXITCODE -ne 0) { Warn "copying the English base to the VM failed (on-box English kept)"; return $false }
  $sh = @'
set -e
STAGE=/tmp/upes-en-stage
DEST=/usr/share/asterisk/sounds/en
mkdir -p "$DEST"
find "$STAGE" -type f -name '*.wav' | while read -r f; do
  rel="${f#$STAGE/}"; out="$DEST/$rel"; mkdir -p "$(dirname "$out")"
  if command -v sox >/dev/null 2>&1; then sox "$f" -r 8000 -c 1 -b 16 "$out" 2>/dev/null || cp -f "$f" "$out"; else cp -f "$f" "$out"; fi
  # Remove any placeholder .gsm the first-boot provision dropped for this name (e.g.
  # drill-prompt.gsm, emergency-voicemail-prompt.gsm) so it can't shadow the real .wav.
  rm -f "${out%.wav}.gsm" 2>/dev/null || true
done
N=$(find "$DEST" -type f -name '*.wav' | wc -l)
chown -R asterisk:asterisk "$DEST" 2>/dev/null || true
asterisk -rx 'module reload res_sound.so' >/dev/null 2>&1 || true
echo "english base: $N wav(s) in sounds/en"
'@
  $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($sh -replace "`r","")))
  $res = ssh.exe -q -i $key -p 2222 @SshOpt ubuntu@127.0.0.1 "echo $b64 | base64 -d | sudo bash" 2>$null
  Info ("[en] " + ($res -join ' '))
  return $true
}

function Test-PromptCoverage($repo) {
  # Verify every SHIPPED language folder has all catalog prompts (audio) BEFORE we deploy, so a
  # partial pack (e.g. a half-finished TTS run) can never ship silently. A missing coach prompt
  # is NOT a dropped call (Asterisk plays silence and the menu loops), but it degrades the flow,
  # so we surface it loudly. Returns the list of "lang:file" gaps ([] = all complete). Packs with
  # ZERO wavs (e.g. zh, voice pack pending) are skipped -- they intentionally fall back to English.
  $gaps = @()
  try {
    $cat = [IO.File]::ReadAllText((Join-Path $repo 'i18n\prompts.catalog.json')) | ConvertFrom-Json
    $files = @($cat.prompts | ForEach-Object { $_.file -replace '/','\' })
    $enDir = Join-Path $repo 'deploy\asterisk\sounds\en'
    foreach ($f in $files) { if (-not (Test-Path (Join-Path $enDir $f))) { $gaps += "en:$f" } }
    $langRoot = Join-Path $repo 'deploy\asterisk\sounds\lang'
    if (Test-Path $langRoot) {
      foreach ($d in (Get-ChildItem $langRoot -Directory -EA SilentlyContinue)) {
        if (-not (Get-ChildItem $d.FullName -Recurse -Filter *.wav -EA SilentlyContinue | Select-Object -First 1)) { continue }
        foreach ($f in $files) { if (-not (Test-Path (Join-Path $d.FullName $f))) { $gaps += ("{0}:{1}" -f $d.Name, $f) } }
      }
    }
  } catch { $gaps += "verify-error: $($_.Exception.Message)" }
  return $gaps
}

function Push-AllLangPacks($langRoot,$key) {
  # Install EVERY built pack under deploy\asterisk\sounds\lang\<code>\ into its own
  # sounds/<code>/ folder, so per-caller routing can reach any of them. English is the
  # built-in base and is never touched. Returns the list of codes actually installed.
  $installed = @()
  if (-not (Test-Path $langRoot)) { return $installed }
  $packs = Get-ChildItem $langRoot -Directory -EA SilentlyContinue | Where-Object {
    $_.Name -ne 'en' -and (Get-ChildItem $_.FullName -Recurse -Filter *.wav -EA SilentlyContinue | Select-Object -First 1)
  }
  if (-not $packs) { Info "no non-English packs found under $langRoot"; return $installed }
  if (-not (Wait-VmSsh $key)) { Warn "VM SSH not reachable - language packs not applied (English kept)"; return $installed }
  foreach ($p in $packs) {
    if (Push-LangPrompts $key $p.Name $p.FullName) { $installed += $p.Name }
  }
  return $installed
}

function Sync-LangDb($key,$csvPath,$defaultCode) {
  # Push the per-user language map (provisioning\user-languages.csv: ext,lang) plus the
  # campus default into Asterisk's astdb, so the dialplan's DB(lang/<ext>) lookups resolve
  # offline and instantly. Idempotent: re-running just re-asserts the same keys.
  if (-not (Wait-VmSsh $key)) { Warn "VM SSH not reachable - language map not synced"; return $false }
  $cmds = @()
  if ($defaultCode) { $cmds += ("database put lang _default {0}" -f $defaultCode) }
  if ($csvPath -and (Test-Path $csvPath)) {
    foreach ($row in (Import-Csv -Path $csvPath)) {
      $ext = "$($row.ext)".Trim(); $lang = "$($row.lang)".Trim()
      if ($ext -match '^\d{3,}$' -and $lang -match '^[a-z]{2,3}$') { $cmds += ("database put lang {0} {1}" -f $ext, $lang) }
    }
  }
  if ($cmds.Count -eq 0) { Info "no language mappings to sync"; return $true }
  $script = ($cmds | ForEach-Object { "asterisk -rx `"$_`"" }) -join "`n"
  $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($script -replace "`r","")))
  ssh.exe -q -i $key -p 2222 @SshOpt ubuntu@127.0.0.1 "echo $b64 | base64 -d | sudo bash" 2>$null | Out-Null
  Ok ("language map synced - default '{0}', {1} user mapping(s)" -f ($(if($defaultCode){$defaultCode}else{'en'})), ($cmds.Count - $(if($defaultCode){1}else{0})))
  return $true
}

function Resolve-Bundle($src) {
  # -Source resolver: URL/.zip -> extract to <Base>\repo (persistent); folder -> use as-is.
  $dest = Join-Path $Base 'repo'
  function _extract($zip,$to) {
    if (Test-Path $to) { Remove-Item $to -Recurse -Force }
    New-Item -ItemType Directory -Force $to | Out-Null
    try { Expand-Archive -Path $zip -DestinationPath $to -Force }
    catch { Add-Type -AssemblyName System.IO.Compression.FileSystem; [IO.Compression.ZipFile]::ExtractToDirectory($zip,$to) }
  }
  function _root($dir) {
    if (Test-Path (Join-Path $dir 'Install-UpesEcs.ps1')) { return $dir }
    $sub = Get-ChildItem $dir -Directory -EA SilentlyContinue | Where-Object { Test-Path (Join-Path $_.FullName 'Install-UpesEcs.ps1') } | Select-Object -First 1
    if ($sub) { return $sub.FullName }
    return $dir
  }
  if ($src -match '^(?i)https?://') {
    New-Item -ItemType Directory -Force $Base | Out-Null
    $zip = Join-Path $env:TEMP ('upes-bundle-{0}.zip' -f (Get-Date -Format 'yyyyMMddHHmmss'))
    Info "downloading bundle: $src"
    try { Invoke-WebRequest -Uri $src -OutFile $zip -UseBasicParsing } catch { Die "download failed: $($_.Exception.Message)" }
    _extract $zip $dest
    return (_root $dest)
  }
  if (Test-Path $src -PathType Leaf) {
    if ($src -notmatch '(?i)\.zip$') { Die "a -Source file must be a .zip bundle: $src" }
    _extract (Resolve-Path $src).Path $dest
    return (_root $dest)
  }
  if (Test-Path $src -PathType Container) { return (Resolve-Path $src).Path }
  Die "-Source not found: $src"
}

# ---------------------------------------------------------------------------
# UNINSTALL
# ---------------------------------------------------------------------------
if ($Uninstall) {
  Head "UPES-ECS - uninstall"
  if (Test-Path "$Base\stop-vm.ps1") { Step "Stopping VM"; & powershell -NoProfile -ExecutionPolicy Bypass -File "$Base\stop-vm.ps1" 2>$null; Ok "VM stopped" }
  Step "Removing autostart"; & powershell -NoProfile -ExecutionPolicy Bypass -File "$qdir\Register-Autostart.ps1" -Remove 2>$null
  # also drop Deploy's own logon task + startup launcher if present
  schtasks /Delete /TN "UPES-ECS VM" /F 2>$null | Out-Null
  Remove-Item (Join-Path ([Environment]::GetFolderPath('Startup')) 'upes-ecs-vm.cmd') -ErrorAction SilentlyContinue
  if (FwPresent) {
    Step "Removing firewall rule (needs admin)"
    $rm = "Remove-NetFirewallRule -DisplayName '$FW' -EA SilentlyContinue"
    if (Test-Admin) { Invoke-Expression $rm } else { Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-Command',$rm }
    Ok "firewall rule removed"
  }
  Head "Uninstalled. (The VM disk under $Base is kept - delete it by hand to reclaim space.)"
  return
}

# ---------------------------------------------------------------------------
# 0. PREFLIGHT  (+ optional bundle fetch, + language resolution)
# ---------------------------------------------------------------------------
Head "UPES-ECS - full setup on this Windows PC"

# 0a. -Source: deploy a fetched bundle instead of this repo. Everything that defines the
#     PBX (config/ scripts/ deploy/ Console/ i18n/) is then read from the bundle root.
$regionSource = 'local'
if ($Source) {
  Step "Fetch deployment bundle (-Source)"
  $repo = Resolve-Bundle $Source
  $qdir = Join-Path $repo 'deploy\qemu'
  $cdir = Join-Path $repo 'Console'
  $regionSource = $Source
  Ok "using bundle at $repo"
}

Info "repo : $repo"
Info "base : $Base   (VM disk, SSH key, runtime)"
Info "lang : $Language"
if (-not (Test-Path "$qdir\Deploy-UpesEcsVm.ps1")) { Die "Not a UPES-ECS repo (missing deploy\qemu\Deploy-UpesEcsVm.ps1). Run this from the repo root (or point -Source at a valid bundle)." }
if ([Environment]::OSVersion.Version.Major -lt 10) { Die "Windows 10 or 11 required." }

# 0b. Resolve the requested language against i18n\languages.json. Unknown -> English.
$li = Get-LangInfo $Language
if (-not $li) {
  if ($Language -ne 'en') { Warn "language '$Language' is not listed in i18n\languages.json - falling back to English" }
  $Language = 'en'; $langName = 'English'; $langNative = 'English'
} else {
  $langName = $li.name; $langNative = $li.native
}
# Does a prompt pack exist for this language? (English is built in -> always 'packed'.)
$langDir  = Join-Path $repo "deploy\asterisk\sounds\lang\$Language"
$hasPack  = ($Language -ne 'en') -and (Test-Path $langDir) -and `
            [bool](Get-ChildItem $langDir -Recurse -Filter *.wav -EA SilentlyContinue | Select-Object -First 1)
if ($Language -eq 'en') { $promptState = 'packed' }
elseif ($hasPack)       { $promptState = 'packed' }
else                    { $promptState = 'english-fallback' }

# 0c. -DryRun: validate + write region.json + print the plan, then stop (no VM changes).
if ($DryRun) {
  Step "DRY RUN - no prerequisites, VM, autostart, or Console will be touched"
  Info ("repo      : {0}" -f $repo)
  Info ("base      : {0}" -f $Base)
  Info ("language  : {0} ({1}) [{2}]" -f $langNative, $langName, $Language)
  if ($Language -ne 'en') {
    if ($hasPack) { Info "prompt pack: FOUND at $langDir (would be pushed into the VM + downsampled to 8k)" }
    else          { Warn "prompt pack: MISSING at $langDir (English would be kept)" }
  } else { Info "prompt pack: English (built in)" }

  # Payload / path validation (read-only) - confirm the deploy logic has what it needs.
  Step "Path + payload checks"
  $paths = [ordered]@{
    'deploy\qemu\Deploy-UpesEcsVm.ps1'  = (Join-Path $repo 'deploy\qemu\Deploy-UpesEcsVm.ps1')
    'deploy\qemu\Register-Autostart.ps1'= (Join-Path $repo 'deploy\qemu\Register-Autostart.ps1')
    'deploy\qemu\Add-UpesUser.ps1'      = (Join-Path $repo 'deploy\qemu\Add-UpesUser.ps1')
    'deploy\asterisk\pjsip_accounts.conf'= (Join-Path $repo 'deploy\asterisk\pjsip_accounts.conf')
    'Console\Run-Console.ps1'           = (Join-Path $cdir 'Run-Console.ps1')
    'Console\Show-TV.ps1'               = (Join-Path $cdir 'Show-TV.ps1')
    'i18n\languages.json'               = (Join-Path $repo 'i18n\languages.json')
  }
  $missing = 0
  foreach ($k in $paths.Keys) {
    if (Test-Path $paths[$k]) { Ok $k } else { Warn "MISSING: $k"; $missing++ }
  }
  if ($missing -gt 0) { Warn "$missing expected path(s) missing - a real deploy from here would fail." }

  # Prerequisite + firewall PLAN (read-only; nothing is installed or changed).
  Step "Prerequisite + firewall plan (nothing will be changed)"
  if (SshOk)    { Ok  "OpenSSH client: present" } else { Info "OpenSSH client: ABSENT -> would be installed (Add-WindowsCapability)" }
  if (SevenZip) { Ok  "7-Zip: present" }          else { Info "7-Zip: ABSENT -> would be installed (winget/msi)" }
  if (FwPresent){ Ok  "firewall rule '$FW': present" } else { Info "firewall rule '$FW': ABSENT -> would add UDP 5060 + RTP 10000-10019 inbound" }
  if ((SshOk) -and (SevenZip) -and (FwPresent)) { Info "elevation plan: none needed (no UAC prompt)" }
  else { Info "elevation plan: ONE UAC prompt to install missing prereqs + add the firewall rule" }

  Write-Region $Language $langName $langNative $promptState $regionSource
  if ($missing -gt 0) { Head "Dry run complete WITH WARNINGS (see MISSING paths above)." }
  else { Head "Dry run complete - deploy logic validated. Re-run without -DryRun to actually deploy." }
  return
}

# ---------------------------------------------------------------------------
# 1+2. PREREQUISITES + FIREWALL  (batched into a single elevation)
# ---------------------------------------------------------------------------
Step "1/6  Prerequisites (OpenSSH, 7-Zip) + firewall"
$need = @()
if (-not (SshOk))      { $need += 'ssh' }
if (-not (SevenZip))   { $need += '7zip' }
if (-not (FwPresent))  { $need += 'firewall' }

if ($need.Count -eq 0) {
  Ok "OpenSSH + 7-Zip present, firewall rule present - nothing to install."
} else {
  Info ("needed: " + ($need -join ', '))
  # One elevated batch: install missing prereqs + add the firewall rule.
  $adminSteps = @'
$ErrorActionPreference = 'Continue'
Write-Host '  [admin] applying prerequisites...'
# OpenSSH client
if (-not ((Get-Command ssh -EA SilentlyContinue) -or (Test-Path "$env:WINDIR\System32\OpenSSH\ssh.exe"))) {
  Write-Host '  [admin] installing OpenSSH client...'
  Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0 -EA SilentlyContinue | Out-Null
}
# 7-Zip
$sz = @("$env:ProgramFiles\7-Zip\7z.exe","${env:ProgramFiles(x86)}\7-Zip\7z.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $sz) {
  Write-Host '  [admin] installing 7-Zip...'
  $done = $false
  if (Get-Command winget -EA SilentlyContinue) {
    try { winget install --id 7zip.7zip -e --silent --accept-source-agreements --accept-package-agreements | Out-Null; $done = $true } catch {}
  }
  if (-not (Test-Path "$env:ProgramFiles\7-Zip\7z.exe")) {
    try {
      $msi = "$env:TEMP\7z-x64.msi"
      curl.exe -L -s -o $msi "https://www.7-zip.org/a/7z2409-x64.msi"
      Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /qn /norestart" -Wait
    } catch {}
  }
}
# Firewall: allow SIP 5060 + RTP 10000-10019 inbound (LAN phones -> PBX)
if (-not (Get-NetFirewallRule -DisplayName 'UPES-ECS SIP-RTP' -EA SilentlyContinue)) {
  Write-Host '  [admin] adding firewall rule...'
  New-NetFirewallRule -DisplayName 'UPES-ECS SIP-RTP' -Direction Inbound -Protocol UDP -LocalPort 5060,10000-10019 -Action Allow -Profile Any -EA SilentlyContinue | Out-Null
}
Write-Host '  [admin] done.'
'@
  if (Test-Admin) {
    Invoke-Expression $adminSteps
  } else {
    Info "requesting elevation (one UAC prompt) to install prerequisites + firewall..."
    $b64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($adminSteps))
    Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$b64
  }
  # re-check the hard requirements
  if (-not (SshOk))    { Die "OpenSSH client still missing. Install 'OpenSSH Client' (Settings > Optional features) and re-run." }
  if (-not (SevenZip)) { Die "7-Zip still missing. Install it from https://www.7-zip.org and re-run." }
  Ok "prerequisites ready" ; if (FwPresent) { Ok "firewall rule present" } else { Warn "firewall rule not confirmed (LAN phones may be blocked until it's added)" }
}

# ---------------------------------------------------------------------------
# 3. BUILD + BOOT THE PBX VM  (the heavy step: downloads + cloud-init, minutes)
# ---------------------------------------------------------------------------
Step "2/6  Build + boot the Asterisk PBX VM  (first run downloads QEMU + Ubuntu; ~5-12 min on TCG)"
$deployArgs = @('-Base', $Base, '-Memory', "$Memory", '-Cpus', "$Cpus")
if ($LanIp)        { $deployArgs += @('-LanIp', $LanIp) }
if ($Rebuild)      { $deployArgs += '-Rebuild' }
if ($SkipCallTest) { $deployArgs += '-SkipCallTest' }
# firewall already handled above, so don't pass -AddFirewallRule (avoids a 2nd UAC).
& powershell -NoProfile -ExecutionPolicy Bypass -File "$qdir\Deploy-UpesEcsVm.ps1" @deployArgs
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { Die "VM build failed (see output above)." }
Ok "PBX VM built and running"

# ---------------------------------------------------------------------------
# 3b. REGIONAL LANGUAGE PROMPTS  (overlay the chosen pack onto the VM, else English)
# ---------------------------------------------------------------------------
Step "Language prompts + per-caller routing ($langNative / $langName default)"
# NEW MODEL: every built pack is installed into its OWN sounds/<code>/ folder (English is
# never overwritten), and each call resolves CHANNEL(language) from the caller's preference
# -> campus default -> English. So the campus can speak many languages at once, routed per
# caller, instead of the whole PBX being pinned to one region's language.
$key      = Join-Path $Base 'ssh\upes_key'
$langRoot = Join-Path $repo 'deploy\asterisk\sounds\lang'
$csvPath  = Join-Path $repo 'provisioning\user-languages.csv'

# Verify the shipped prompt sets are COMPLETE before pushing (a partial pack must never ship silently).
$covGaps = Test-PromptCoverage $repo
if ($covGaps.Count -gt 0) {
  Warn ("prompt coverage GAP: {0} missing file(s). First few: {1}" -f $covGaps.Count, (($covGaps | Select-Object -First 8) -join ', '))
  Warn "  (a missing coach prompt plays as silence, never a drop -- rebuild with scripts\gen-lang-prompts.win.ps1 before go-live)"
} else { Ok "prompt coverage: every shipped language has all catalog prompts" }

# Install the committed, complete English BASE first. English is the per-file fallback for every
# language, so it must be complete and identical everywhere -- this makes it authoritative over
# whatever the VM's first-boot TTS produced (which could be partial => coach intro then silence).
[void](Push-EnglishBase $key (Join-Path $repo 'deploy\asterisk\sounds\en'))

$installedCodes = Push-AllLangPacks $langRoot $key
if ($installedCodes.Count -gt 0) { Ok ("installed language packs: " + ($installedCodes -join ', ')) }
else { Info "no non-English packs installed (English serves every call until packs are built with scripts\gen-lang-prompts.win.ps1)" }

# The campus DEFAULT (unmapped callers) = -Language. It needs its own pack unless it's English.
if ($Language -eq 'en') {
  $promptState = 'packed'
} elseif ($installedCodes -contains $Language) {
  $promptState = 'packed'; Ok "campus default '$Language' pack is live"
} else {
  $promptState = 'english-fallback'
  Warn "no pack for the default language '$Language' - unmapped callers hear English. Build it: scripts\gen-lang-prompts.win.ps1 -Lang $Language, then re-run."
}

# Sync the offline language map (user prefs + campus default) into astdb for the dialplan.
Sync-LangDb $key $csvPath $Language | Out-Null

# Record the ACTIVE region for the Console dashboard.
Write-Region $Language $langName $langNative $promptState $regionSource

# ---------------------------------------------------------------------------
# 4. LED-TV NAME DIRECTORY (ext -> name, from the source of truth)
# ---------------------------------------------------------------------------
Step "3/6  Generate the wallboard name directory"
try {
  $conf = Join-Path $repo 'deploy\asterisk\pjsip_accounts.conf'
  # Per-user language preference lives in its own source of truth (survives directory
  # regeneration); merge it in so the Console + app can show/set each caller's language.
  $langMap = @{}
  if (Test-Path $csvPath) {
    foreach ($row in (Import-Csv -Path $csvPath)) {
      $e = "$($row.ext)".Trim(); $l = "$($row.lang)".Trim()
      if ($e -and $l) { $langMap[$e] = $l }
    }
  }
  $dir = [ordered]@{}
  foreach ($line in Get-Content $conf) {
    if ($line -match '^\s*callerid\s*=\s*(.+?)\s*<(\d+)>\s*$') {
      $nm = $Matches[1].Trim(); $ext = $Matches[2]
      $kind = if ($ext -match '^5\d{8}$') {'student'} elseif ($ext -match '^\d{8}$') {'staff'} elseif ($ext -eq '4101') {'ert-lead'} elseif ($ext -match '^411\d$') {'ert'} elseif ($ext -eq '4120') {'control'} elseif ($ext -match '^4[2-6]\d\d$') {'responder'} else {'other'}
      $entry = [ordered]@{ name = $nm; kind = $kind }
      if ($langMap.ContainsKey($ext)) { $entry.lang = $langMap[$ext] }   # empty/absent = campus default
      $dir[$ext] = $entry
    }
  }
  [IO.File]::WriteAllText((Join-Path $cdir 'directory.json'), ($dir | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding($false)))
  Ok ("directory.json - {0} names" -f $dir.Count)
} catch { Warn "could not generate directory.json: $($_.Exception.Message) (boards fall back to raw extensions)" }

# ---------------------------------------------------------------------------
# 5. AUTOSTART (VM + supervised Console at every logon) + start the Console now
# ---------------------------------------------------------------------------
Step "4/6  Register autostart (VM + Console on every logon)"
& powershell -NoProfile -ExecutionPolicy Bypass -File "$qdir\Register-Autostart.ps1" -QemuDir $Base -ConsoleDir $cdir
Ok "autostart installed"

if (-not $NoConsole) {
  Step "5/6  Start the Operations Console (:8080)"
  # stop any stale console listener, then launch the supervised console in the background
  Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"$cdir\Run-Console.ps1",'-Base',$Base | Out-Null
  $up = $false
  for ($i=0; $i -lt 20; $i++) {
    try { if ((Invoke-WebRequest 'http://localhost:8080/tv-ops.html' -UseBasicParsing -TimeoutSec 3).StatusCode -eq 200) { $up = $true; break } } catch {}
    Start-Sleep -Seconds 1
  }
  if ($up) { Ok "Console live at http://localhost:8080" } else { Warn "Console not confirmed on :8080 yet - it may still be starting (check in a few seconds)." }
} else {
  Info "5/6  (console start skipped - it will still auto-start at next logon)"
}

# ---------------------------------------------------------------------------
# 6. LED-TV boards
# ---------------------------------------------------------------------------
Step "6/6  Campus LED-TV boards"
if ($LaunchTV) {
  & powershell -NoProfile -ExecutionPolicy Bypass -File "$cdir\Show-TV.ps1" -Both
  Ok "boards launched (kiosk)"
} else {
  Info "not launched. To open them on the TVs:"
  Info "    powershell -File `"$cdir\Show-TV.ps1`" -Both"
}

# ---------------------------------------------------------------------------
# SUMMARY
# ---------------------------------------------------------------------------
$ip = $LanIp
if (-not $ip) { try { $r = Get-NetRoute -DestinationPrefix 0.0.0.0/0 | Sort-Object RouteMetric | Select-Object -First 1; $ip = (Get-NetIPAddress -InterfaceIndex $r.ifIndex -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254\.)' } | Select-Object -First 1).IPAddress } catch {} }
Head "UPES-ECS is UP on this PC"
Write-Host ("  Region / language       :  {0} ({1})   prompts: {2}" -f $langNative, $langName, $promptState)
Write-Host "  Emergency number        :  111   (drill: 199 / panic-coach: 102)"
Write-Host "  Phones register to      :  upes-ecs.local : 5060   (UDP, G.711)   <- SIP server on each handset"
Write-Host "                             (stable mDNS name; auto-follows this laptop's IP. Raw IP now: $ip)"
Write-Host "  Contacts (CardDAV)      :  http://upes-ecs.local:5232/upes/directory/   (Linphone address book)"
Write-Host "  Operations Console      :  http://localhost:8080"
Write-Host "  LED-TV boards           :  http://localhost:8080/tv-safety.html   (public)"
Write-Host "                             http://localhost:8080/tv-ops.html      (control room)"
Write-Host "  Launch boards (kiosk)   :  powershell -File `"$cdir\Show-TV.ps1`" -Both"
Write-Host "  Add a user              :  powershell -File `"$qdir\Add-UpesUser.ps1`" -SapId <id> -Name `"<name>`""
Write-Host "  Credentials (secret)    :  secrets\TEAM-CREDENTIALS.md"
Write-Host "  Moved networks?         :  nothing to do -- upes-ecs.local re-points itself (or Set-UpesLanIp.ps1 / Console 'Rebind')"
Write-Host "  Check the network       :  powershell -File `"$Base\Test-UpesNetwork.ps1`"   (proves phones can register + sync)"
Write-Host "  Uninstall               :  powershell -File `"$repo\Install-UpesEcs.ps1`" -Uninstall"
Write-Host ""
Write-Host "  Everything auto-starts on the next Windows logon - no further action needed." -ForegroundColor Green
Write-Host ""
