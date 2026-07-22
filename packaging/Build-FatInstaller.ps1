<#
.SYNOPSIS  Build the FULLY-OFFLINE installer deliverable (UPES-ECS-Setup.zip).
.DESCRIPTION
  Produces ONE .zip that stands up the whole emergency PBX on a fresh Windows PC with NO
  internet and NO prerequisites (no Python, no QEMU, no downloads). The user extracts it and
  runs Setup.cmd. It bundles:
    - QEMU runtime         (binaries + DLLs + firmware/BIOS from %USERPROFILE%\qemu)
    - the GOLDEN VM disk    (upes-ecs-server.qcow2, already provisioned: Asterisk +
                             all language packs + the FastAPI status service + sox +
                             fail2ban, all enabled via systemd - so first boot is instant
                             and offline; no apt, no pip, no cloud image)
    - the app payload       (Console, deploy, i18n, api, scripts, config, provisioning,
                             the compiled Deploy-UPES.exe, offline bootstrap)
    - optionally Piper      (-IncludePiper: piper-win + piper-model, ~2.8 GB, only needed
                             to GENERATE new voice packs on the host; the shipped WAVs are
                             already baked into the golden disk, so deploy never needs it)

  WHY A ZIP (not a single .exe): the payload is ~7.5 GB and the golden disk alone is ~4.9 GB.
  Windows CANNOT run an .exe larger than 4 GB - every self-extractor (7-Zip's 32-bit SFX,
  WinRAR's SFX) either fails to run ("This app can't run on your PC") or refuses to build.
  So we ship a ZIP64 archive (built-in Windows Explorer extracts it, no 7-Zip needed on the
  target) containing the loose payload + a Setup.cmd launcher. Final packaging is delegated
  to Build-ProInstaller.ps1; this script only stages the payload.

  SAFETY: copying a LIVE qcow2 corrupts it. This script REFUSES to run while the VM is up
  (a qemu-system process is running) unless -Force is given. Always build in a maintenance
  window with the VM shut down (stop-vm.ps1). We use `qemu-img convert -c` which makes a
  consistent, compressed copy - never a raw byte copy of a mounted disk. Single-threaded
  staging (no parallel heavy disk I/O).

  ASCII-only (Windows PowerShell 5.1). Idempotent: re-runnable, cleans its own staging.
.PARAMETER Base          Where the live QEMU + disk live. Default %USERPROFILE%\qemu.
.PARAMETER OutDir        Where to write the .exe. Default <repo>\dist.
.PARAMETER IncludePiper  Also bundle Piper + voice models (host-side prompt generation).
.PARAMETER Force         Build even if the VM appears to be running (UNSAFE - may corrupt).
#>
param(
  [string]$Base="$env:USERPROFILE\qemu",
  [string]$OutDir="",
  [ValidateSet('Inno','Zip')][string]$Format='Inno',
  [switch]$IncludePiper,
  [switch]$Force
)
$ErrorActionPreference='Stop'
$RepoRoot = Split-Path $PSScriptRoot -Parent
if([string]::IsNullOrWhiteSpace($OutDir)){ $OutDir = Join-Path $RepoRoot 'dist' }
$SevenZip = 'C:\Program Files\7-Zip\7z.exe'
$ProPkg   = Join-Path $PSScriptRoot 'Build-ProInstaller.ps1'   # zip packager
$InnoPkg  = Join-Path $PSScriptRoot 'Build-InnoInstaller.ps1'  # branded Inno installer
$QemuImg  = Join-Path $Base 'qemu-img.exe'
$Disk     = Join-Path $Base 'images\upes-ecs-server.qcow2'

function Need($path,$what){ if(-not (Test-Path $path)){ throw "$what not found: $path" } }
Need $SevenZip '7-Zip (7z.exe)'
Need $QemuImg  'qemu-img.exe'
Need $Disk     'golden VM disk (upes-ecs-server.qcow2)'
if($Format -eq 'Inno'){ Need $InnoPkg 'Build-InnoInstaller.ps1' } else { Need $ProPkg 'Build-ProInstaller.ps1' }

# --- SAFETY GATE: never copy a live qcow2 -------------------------------------------------
$vmUp = @(Get-Process -Name 'qemu-system-x86_64' -EA SilentlyContinue).Count -gt 0
if($vmUp -and -not $Force){
  throw "The VM appears to be RUNNING (qemu-system-x86_64). Copying a live disk corrupts it. Shut it down first:  powershell -File deploy\qemu\stop-vm.ps1   then re-run. (Override with -Force only if you are certain the disk is quiesced.)"
}

# Stage leaf name = the folder the user sees inside the zip after extracting.
$Stage = Join-Path $env:TEMP ("UPES-ECS-Setup")
if(Test-Path $Stage){ Remove-Item $Stage -Recurse -Force }
New-Item -ItemType Directory -Path $Stage | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Stage 'qemu') | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Stage 'qemu\images') | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Stage 'app') | Out-Null
Write-Host "== Building FULLY-OFFLINE installer ==" -ForegroundColor Cyan
Write-Host "staging at $Stage"

# 1) QEMU runtime (everything EXCEPT the disk images and any secrets/logs)
Write-Host "staging QEMU runtime..."
& robocopy $Base (Join-Path $Stage 'qemu') /E /XD 'images' '$PLUGINSDIR' /XF '*.log' '*.qcow2' '*.img' /NFL /NDL /NJH /NJS /NP | Out-Null

# 2) Golden disk: consistent, COMPRESSED copy (safe because VM is off). This also shrinks it.
Write-Host "converting golden disk (qemu-img convert -c; compresses 7.5 GB -> a few GB)..."
& $QemuImg convert -O qcow2 -c $Disk (Join-Path $Stage 'qemu\images\upes-ecs-server.qcow2')
if($LASTEXITCODE -ne 0){ throw "qemu-img convert failed (exit $LASTEXITCODE)" }

# 3) App payload (idempotent robocopy of each dir)
Write-Host "staging app payload..."
$dirs = @('deploy','Console','i18n','api','scripts','config','provisioning')
foreach($d in $dirs){
  $src = Join-Path $RepoRoot $d
  if(Test-Path $src){ & robocopy $src (Join-Path $Stage "app\$d") /E /XF '*.log' /XD '__pycache__' '.git' /NFL /NDL /NJH /NJS /NP | Out-Null }
}
# strip anything sensitive from the payload copy (belt-and-suspenders; golden disk is the runtime)
Get-ChildItem (Join-Path $Stage 'app') -Recurse -Include 'TEAM-CREDENTIALS.md','*users*.csv','*.filled.csv' -EA SilentlyContinue | Remove-Item -Force -EA SilentlyContinue
# clean pjsip_accounts.conf secrets from the payload copy (runtime lives on the golden disk)
$pj = Join-Path $Stage 'app\deploy\asterisk\pjsip_accounts.conf'
if(Test-Path $pj){ Set-Content -Path $pj -Value '; secrets live on the provisioned golden disk; add users with Add-UpesUser.ps1' -Encoding ascii }
# top-level helper scripts
foreach($f in @('Deploy-UPES.ps1','Deploy-UPES.cmd','Install-UpesEcs.ps1','README.md','CHANGELOG.md')){
  $src = Join-Path $RepoRoot $f; if(Test-Path $src){ Copy-Item $src (Join-Path $Stage 'app') -Force }
}
# compiled GUI exe if the standard build produced one
$gui = Join-Path $RepoRoot 'dist\stage\Deploy-UPES.exe'
if(Test-Path $gui){ Copy-Item $gui (Join-Path $Stage 'app') -Force }

# 4) Optional Piper (host-side prompt generation)
if($IncludePiper){
  Write-Host "staging Piper + voice models (~2.8 GB)..."
  if(Test-Path "$env:USERPROFILE\piper-win"){ & robocopy "$env:USERPROFILE\piper-win" (Join-Path $Stage 'piper\piper-win') /E /NFL /NDL /NJH /NJS /NP | Out-Null }
  if(Test-Path "C:\Users\Rohan\piper-model"){ & robocopy "C:\Users\Rohan\piper-model" (Join-Path $Stage 'piper\piper-model') /E /NFL /NDL /NJH /NJS /NP | Out-Null }
}

# 5) Offline bootstrap (runs on the target after extraction)
Copy-Item (Join-Path $PSScriptRoot 'offline\offline-bootstrap.ps1') (Join-Path $Stage 'offline-bootstrap.ps1') -Force

# 6) Package the staged payload into the deliverable (this is the long part).
if(-not (Test-Path $OutDir)){ New-Item -ItemType Directory -Path $OutDir | Out-Null }
if($Format -eq 'Inno'){
  # Branded Inno wizard: UPES-ECS-Setup.exe + .bin slices. See the header for WHY not one .exe.
  Write-Host "packaging branded installer (Inno DiskSpanning)..."
  & powershell -NoProfile -ExecutionPolicy Bypass -File $InnoPkg -Payload $Stage
  if($LASTEXITCODE -ne 0){ throw "installer packaging failed (exit $LASTEXITCODE)" }
  if(-not (Test-Path (Join-Path $OutDir 'UPES-ECS-Setup.exe'))){ throw "failed to produce UPES-ECS-Setup.exe" }
  Write-Host "  Ship the .exe + all .bin files together. On a fresh PC: run UPES-ECS-Setup.exe." -ForegroundColor Green
} else {
  # Plain ZIP64 fallback (extract, then run Setup.cmd).
  $zip = Join-Path $OutDir 'UPES-ECS-Setup.zip'
  Write-Host "packaging deliverable zip (ZIP64)..."
  & powershell -NoProfile -ExecutionPolicy Bypass -File $ProPkg -Payload $Stage -OutZip $zip
  if($LASTEXITCODE -ne 0){ throw "installer packaging failed (exit $LASTEXITCODE)" }
  if(-not (Test-Path $zip)){ throw "failed to produce $zip" }
  Write-Host "  Ship this one file. On a fresh PC: extract, then run Setup.cmd." -ForegroundColor Green
}
# tidy large temporaries
Remove-Item $Stage -Recurse -Force -EA SilentlyContinue
