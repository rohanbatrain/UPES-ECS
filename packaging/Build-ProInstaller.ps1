<#
.SYNOPSIS  Package the offline payload into the deliverable: a single UPES-ECS-Setup.zip.
.DESCRIPTION
  Windows cannot run an .exe larger than 4 GB (confirmed: both 7-Zip's 32-bit SFX and WinRAR
  refuse/produce "This app can't run on your PC"). Our payload is ~7.5 GB and the golden disk
  alone is ~4.9 GB, so a single self-extracting .exe is IMPOSSIBLE. Instead we ship one .zip
  the user extracts, then double-clicks Setup.cmd inside it.

  The .zip contains the loose payload (qemu\, app\, piper\, offline-bootstrap.ps1) plus a
  Setup.cmd launcher at the root. It is a ZIP64 archive (the qcow2 is >4 GB), which the
  built-in Windows 10/11 Explorer extracts natively - no 7-Zip needed on the target.

  This script only does the final packaging (add Setup.cmd + zip); it touches no VM disk, so
  it is safe to run while the PBX is up.

  ASCII-only (Windows PowerShell 5.1).
.PARAMETER Payload  Staged payload folder. Its LEAF NAME becomes the folder inside the zip,
                    so name it 'UPES-ECS-Setup'. Default %TEMP%\UPES-ECS-Setup.
.PARAMETER OutZip   Output zip path. Default <repo>\dist\UPES-ECS-Setup.zip.
.PARAMETER Level    Zip deflate level 0-9 (0=store/fastest). Default 1 (payload is mostly
                    pre-compressed, so 1 is a good speed/size balance).
#>
param(
  [string]$Payload = "$env:TEMP\UPES-ECS-Setup",
  [string]$OutZip  = "",
  [ValidateRange(0,9)][int]$Level = 1
)
$ErrorActionPreference='Stop'
$RepoRoot = Split-Path $PSScriptRoot -Parent
if([string]::IsNullOrWhiteSpace($OutZip)){ $OutZip = Join-Path $RepoRoot 'dist\UPES-ECS-Setup.zip' }
$SevenZip = 'C:\Program Files\7-Zip\7z.exe'

function Need($p,$w){ if(-not (Test-Path $p)){ throw "$w not found: $p" } }
Need $SevenZip '7-Zip (7z.exe)'
Need $Payload  'staged payload folder'
Need (Join-Path $Payload 'offline-bootstrap.ps1') 'offline-bootstrap.ps1 in payload root'

# 1) Ensure the Setup.cmd launcher is present at the payload root.
$setup = Join-Path $Payload 'Setup.cmd'
if(-not (Test-Path $setup)){
  Write-Host "adding Setup.cmd launcher..."
  $cmd = @(
    '@echo off'
    'title UPES-ECS Emergency PBX - Setup'
    'echo('
    'echo    UPES-ECS Emergency PBX  -  Offline Setup'
    'echo    ======================================='
    'echo('
    'echo    Installing on this PC. Everything is included - no internet needed.'
    'echo    You will be asked to approve an administrator prompt so the phone'
    'echo    (SIP / RTP) ports can be opened in the Windows firewall.'
    'echo('
    'powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0offline-bootstrap.ps1"'
    'echo('
    'echo    Setup finished. The Operations Console is at http://localhost:8080'
    'echo    Phones register to  upes-ecs.local:5060  (dial 111).'
    'echo('
    'pause'
  ) -join "`r`n"
  [IO.File]::WriteAllText($setup, $cmd, (New-Object Text.ASCIIEncoding))
}

# 2) Zip the payload folder (including its leaf name as the zip root). ZIP64 auto-enabled.
$OutDir = Split-Path $OutZip -Parent
if(-not (Test-Path $OutDir)){ New-Item -ItemType Directory -Path $OutDir | Out-Null }
if(Test-Path $OutZip){ Remove-Item $OutZip -Force }

$parent = Split-Path $Payload -Parent
$leaf   = Split-Path $Payload -Leaf
Write-Host "== Building deliverable zip ==" -ForegroundColor Cyan
Write-Host "  payload : $Payload"
Write-Host "  output  : $OutZip  (deflate -mx$Level, ZIP64)"
Push-Location $parent
try { & $SevenZip a -tzip "-mx$Level" -bd -- "$OutZip" "$leaf" | Out-Null; $code = $LASTEXITCODE }
finally { Pop-Location }
if($code -ne 0){ throw "7z zip failed (exit $code)" }
if(-not (Test-Path $OutZip)){ throw "zip not produced: $OutZip" }

# 3) Verify: integrity test + confirm the launcher and golden disk are inside.
Write-Host "verifying archive integrity..."
& $SevenZip t -bd -- "$OutZip" | Out-Null
if($LASTEXITCODE -ne 0){ throw "zip integrity test FAILED (exit $LASTEXITCODE)" }
$listing = & $SevenZip l -ba -- "$OutZip"
foreach($must in @('Setup.cmd','offline-bootstrap.ps1','upes-ecs-server.qcow2')){
  if(-not ($listing | Select-String -SimpleMatch $must)){ throw "expected '$must' missing from zip" }
}
$sizeGb = [math]::Round((Get-Item $OutZip).Length/1GB,2)
Write-Host "== DONE ==" -ForegroundColor Green
Write-Host "  $OutZip  ($sizeGb GB)"
Write-Host "  Ship this one file. On a fresh PC: extract, then run Setup.cmd." -ForegroundColor Green
