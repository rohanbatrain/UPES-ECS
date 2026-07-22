<#
.SYNOPSIS
  Seed a ready-to-try UPES-ECS demo: known-credential accounts + Linphone profiles.

.DESCRIPTION
  Provisions a small demo roster through deploy\qemu\Add-UpesUser.ps1 (the single
  source of truth: repo + credentials + live VM + directory + CardDAV), links a
  parent/child for the family feature, and writes importable Linphone provisioning
  profiles you can hand to softphones. Idempotent - safe to re-run.

  DEMO ONLY. The demo password is public and intentionally simple. Never use these
  accounts or this password in production; add real users with Add-UpesUser.ps1.

.EXAMPLE
  powershell -File demo\Seed-Demo.ps1
.EXAMPLE
  powershell -File demo\Seed-Demo.ps1 -NoVm          # update repo/creds only
.EXAMPLE
  powershell -File demo\Seed-Demo.ps1 -Domain 192.168.0.3   # non-mDNS devices
#>
[CmdletBinding()]
param(
  [string]$Base = "$env:USERPROFILE\qemu",
  [string]$Secret = 'updemo123',
  [string]$Domain,               # SIP server for profiles (default: upes-ecs.local)
  [string]$OutProfiles,          # dir for Linphone .filled.xml (default: demo\linphone-profiles)
  [switch]$NoVm,                 # update repo/creds only; skip the live VM push
  [switch]$Remove                # print how to remove the demo accounts
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path "$PSScriptRoot\..").Path
$add  = Join-Path $repo 'deploy\qemu\Add-UpesUser.ps1'
if (-not (Test-Path $add)) { throw "Add-UpesUser.ps1 not found at $add" }

# Demo roster - FRESH extensions that do not collide with the shipped pilot accounts.
# ert  = responder desk (ctx_ert, can dial *22 to answer 111).
# device = fixed device (gate phone / speaker).
$demo = @(
  @{ Ext = '500000001'; Name = 'Demo Student One';   Role = 'student'; Lang = 'en' }
  @{ Ext = '500000002'; Name = 'Demo Student Two';   Role = 'student'; Lang = 'hi' }
  @{ Ext = '500000003'; Name = 'Demo Student Three'; Role = 'student'; Lang = 'te' }
  @{ Ext = '40000001';  Name = 'Demo Staff One';     Role = 'staff';   Lang = 'en' }
  @{ Ext = '4190';      Name = 'Demo ERT Desk 1';    Role = 'ert' }
  @{ Ext = '4191';      Name = 'Demo ERT Desk 2';    Role = 'ert' }
  @{ Ext = '4390';      Name = 'Demo Gate Phone';    Role = 'device' }
  @{ Ext = '590000001'; Name = 'Demo Parent One';    Role = 'student' }
)
$famParent = '590000001'
$famChild  = '500000001'

if ($Remove) {
  Write-Host "`nThe demo is additive. To remove it, delete these extensions from the" -ForegroundColor Yellow
  Write-Host "running PBX and reload:" -ForegroundColor Yellow
  Write-Host ("  Extensions: {0}" -f (($demo | ForEach-Object { $_.Ext }) -join ', '))
  Write-Host "  On the VM:  edit /etc/asterisk/pjsip_accounts.conf (remove those [ext] blocks),"
  Write-Host "              then:  sudo asterisk -rx 'pjsip reload'"
  Write-Host "  SSH in:     ssh -i $Base\ssh\upes_key -p 2222 ubuntu@localhost"
  return
}

Write-Host "`n=== Seeding the UPES-ECS demo (password for every account: $Secret) ===`n" -ForegroundColor Cyan
foreach ($u in $demo) {
  $a = @('-SapId', $u.Ext, '-Name', $u.Name, '-Role', $u.Role, '-Secret', $Secret, '-Base', $Base)
  if ($u.Lang) { $a += @('-Lang', $u.Lang) }
  if ($NoVm)   { $a += '-NoVm' }
  & powershell -NoProfile -ExecutionPolicy Bypass -File $add @a
}

# family link (parent -> child) so the family feature has demo data
$famScript = Join-Path $repo 'provisioning\family\Add-UpesFamily.ps1'
if (Test-Path $famScript) {
  try {
    $fa = @('-ParentSap', $famParent, '-ChildSap', $famChild, '-Base', $Base)
    if ($NoVm) { $fa += '-NoVm' }
    & powershell -NoProfile -ExecutionPolicy Bypass -File $famScript @fa
  } catch { Write-Host "  ! family link skipped: $_" -ForegroundColor Yellow }
}

# --- importable Linphone provisioning profiles -----------------------------
if (-not $Domain)      { $Domain = 'upes-ecs.local' }
if (-not $OutProfiles) { $OutProfiles = Join-Path $repo 'demo\linphone-profiles' }
$tpl = Join-Path $repo 'provisioning\linphone\linphone-provisioning-template.xml'
if (Test-Path $tpl) {
  New-Item -ItemType Directory -Force -Path $OutProfiles | Out-Null
  $raw = Get-Content $tpl -Raw
  foreach ($u in $demo) {
    $xml = $raw -replace '__DOMAIN__', $Domain `
                -replace '__SAPID__', $u.Ext `
                -replace '__SECRET__', $Secret `
                -replace '__CARDDAV_USER__', '' `
                -replace '__CARDDAV_PASS__', ''
    Set-Content -Path (Join-Path $OutProfiles "$($u.Ext).filled.xml") -Value $xml -Encoding UTF8
  }
  Write-Host "`nLinphone profiles written to: $OutProfiles" -ForegroundColor Green
} else {
  Write-Host "`n! Linphone template not found - skipped profile generation." -ForegroundColor Yellow
}

# --- the demo card ---------------------------------------------------------
Write-Host "`n================= UPES-ECS DEMO READY =================" -ForegroundColor Cyan
Write-Host ("SIP server : {0}  (or the LAN IP the installer showed) - transport UDP" -f $Domain)
Write-Host ("Password   : {0}   (every demo account)" -f $Secret)
Write-Host ""
foreach ($u in $demo) { Write-Host ("  {0,-11} {1,-20} [{2}]" -f $u.Ext, $u.Name, $u.Role) }
Write-Host ""
Write-Host "Try it:" -ForegroundColor Cyan
Write-Host "  1) In Linphone, register 500000001 and 4190 (import the profiles above,"
Write-Host "     or enter username = extension, password = $Secret, server = $Domain)."
Write-Host "  2) On 4190 dial *22 to go ON SHIFT (start answering 111)."
Write-Host "  3) On 500000001 dial 111  ->  4190 rings. Answer it."
Write-Host "     Also try: 102 (offline coach), 199 (drill), *23 (off shift)."
Write-Host "  4) Open the Operations Console:  http://localhost:8080"
Write-Host ""
Write-Host "Full walkthrough: demo\README.md"
Write-Host "=======================================================" -ForegroundColor Cyan
