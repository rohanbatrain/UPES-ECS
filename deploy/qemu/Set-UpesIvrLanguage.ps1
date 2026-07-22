<#
.SYNOPSIS
  Set the campus DEFAULT emergency-IVR language on the running UPES-ECS PBX, from Windows.

.DESCRIPTION
  The deployed dialplan resolves each call's language PER CALLER (config\extensions_custom.conf
  [sub_setlang]): DB(lang/<caller-ext>) -> DB(lang/_default) -> 'en'. This script sets the
  campus-wide DEFAULT (DB(lang/_default)) that every un-mapped caller hears. Effective on the
  NEXT call (per-caller routing reads astdb per call; no res_sound reload, no reboot/redeploy).

  It does NOT touch any sound files. (The previous version copied a language's prompts OVER
  /usr/share/asterisk/sounds/en, which DESTROYS the pristine-English per-file fallback that every
  other language depends on, and its prompt stores were never created so it always failed. That
  file-swap model is retired in favour of the per-caller routing above.)

  Every language pack installed by Install-UpesEcs.ps1 / Deploy-LangPacks.ps1 is selectable here.
  The Operations Console calls this (with -Json) from its Region & language view; it also has the
  equivalent api/deflang endpoint.

.PARAMETER Language  Any language code from i18n\languages.json (e.g. en, hi, te, fr). Omit to just show the current default.
.PARAMETER Status    Report the current default IVR language and exit (no change).
.PARAMETER Json      Emit ONE compressed JSON line ({ok,language,languageName,output}) and nothing else - for the Console.
.PARAMETER Base      Runtime dir holding the SSH key. Default %USERPROFILE%\qemu.
.EXAMPLE  powershell -File Set-UpesIvrLanguage.ps1 -Language hi
.EXAMPLE  powershell -File Set-UpesIvrLanguage.ps1 -Status -Json
#>
[CmdletBinding()]
param(
  [string]$Language,
  [switch]$Status,
  [switch]$Json,
  [string]$Base = "$env:USERPROFILE\qemu"
)
$ErrorActionPreference = 'Continue'
$key    = "$Base\ssh\upes_key"
$sshOpt = @('-o','StrictHostKeyChecking=no','-o','UserKnownHostsFile=NUL','-o','ConnectTimeout=10','-o','BatchMode=yes')

# --- language name lookup (from i18n\languages.json; ASCII-safe fallback table) --------------
$langsPath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'i18n\languages.json'
$NAME = @{ en='English'; hi='Hindi'; unknown='unknown/custom' }
$KNOWN = @('en')
try {
  if (Test-Path $langsPath) {
    $j = [IO.File]::ReadAllText($langsPath) | ConvertFrom-Json
    $KNOWN = @($j.languages | ForEach-Object { "$($_.code)" })
    foreach ($l in $j.languages) { $NAME["$($l.code)"] = "$($l.name)" }
  }
} catch { }

# Single exit point: emit either a JSON line (for the Console) or human text, then stop.
function Respond([bool]$ok, [string]$lang, [string]$msg) {
  $nm = if ($NAME.ContainsKey($lang)) { $NAME[$lang] } else { $lang }
  if ($Json) {
    $o = [ordered]@{ ok=$ok; language=$lang; languageName=$nm; output=$msg }
    Write-Output ($o | ConvertTo-Json -Compress)
  } elseif ($ok) {
    Write-Host "    [ok] $msg" -ForegroundColor Green
  } else {
    Write-Host "[FAIL] $msg" -ForegroundColor Red
  }
  exit ([int](-not $ok))
}

if (-not (Test-Path $key)) { Respond $false 'unknown' "SSH key not found: $key (is the VM built? run Install-UpesEcs.ps1)" }
if (-not ((Get-Command ssh -EA SilentlyContinue) -or (Test-Path "$env:WINDIR\System32\OpenSSH\ssh.exe"))) {
  Respond $false 'unknown' "ssh.exe not available. Install the OpenSSH client (Settings > Optional features)."
}

# Run a base64-encoded bash payload in the VM. Returns captured stdout.
function Invoke-Vm([string]$bash, [string]$arg) {
  $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($bash -replace "`r","")))
  $cmd = if ($arg) { "echo $b64 | base64 -d | bash -s '$arg'" } else { "echo $b64 | base64 -d | bash" }
  return (ssh.exe -q -i $key -p 2222 @sshOpt ubuntu@127.0.0.1 $cmd 2>$null)
}

# Confirm the VM answers before doing anything.
if ((("" + (Invoke-Vm 'echo UP')) -notmatch 'UP')) {
  Respond $false 'unknown' "VM not reachable over SSH (is it running? start-vm.ps1). Base=$Base"
}

# --- current default: read DB(lang/_default) from astdb -----------------------
$statusSh = @'
cur=$(sudo asterisk -rx 'database get lang _default' 2>/dev/null | sed -n 's/.*Value:[[:space:]]*//p' | tr -d "[:space:]")
[ -n "$cur" ] && echo "$cur" || echo en
'@
function Get-DefLang { $v = ("" + (Invoke-Vm $statusSh)).Trim(); if ($v) { $v } else { 'en' } }

$cur = Get-DefLang

# No -Language (or -Status): just report.
if ($Status -or -not $Language) {
  $nm = if ($NAME.ContainsKey($cur)) { $NAME[$cur] } else { $cur }
  if (-not $Json) {
    Write-Host "`nUPES-ECS default IVR language" -ForegroundColor Cyan
    Write-Host ("    current : {0} ({1})" -f $cur, $nm)
    Write-Host  "    switch  : Set-UpesIvrLanguage.ps1 -Language <code>   (e.g. -Language hi)"
  }
  Respond $true $cur ("current default IVR language: {0} ({1})" -f $cur, $nm)
}

$Language = "$Language".Trim().ToLower()
if ($KNOWN -notcontains $Language) { Respond $false $cur ("'{0}' is not a known language code (see i18n\languages.json)." -f $Language) }

# Already there?
if ($cur -eq $Language) { Respond $true $Language ("default IVR language is already {0} ({1}) - nothing to do." -f $Language, $NAME[$Language]) }

# --- set the campus default in astdb (no file changes; per-caller routing reads it per call) ---
if (-not $Json) { Write-Host ("`n==> setting default IVR language: {0} -> {1}" -f $cur, $Language) -ForegroundColor Cyan }
$setSh = @'
L="${1:?language required}"
sudo asterisk -rx "database put lang _default $L" >/dev/null 2>&1
sudo asterisk -rx 'database get lang _default' 2>/dev/null | sed -n 's/.*Value:[[:space:]]*//p' | tr -d "[:space:]"
'@
$now = ("" + (Invoke-Vm $setSh $Language)).Trim()
if ($now -eq $Language) {
  Respond $true $Language ("default IVR language is now {0} ({1}) - effective on the next call. Callers with a personal language keep theirs." -f $Language, $NAME[$Language])
} else {
  Respond $false $now ("set ran but verification shows '{0}', not '{1}'. Check the VM (astdb)." -f $now, $Language)
}
