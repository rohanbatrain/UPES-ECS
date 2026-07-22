<#
  UPES-ECS - OFFLINE bootstrap. Runs on the target PC after the SFX extracts.
  Stands up the whole emergency PBX with NO internet and NO prerequisites:
    - copies the bundled QEMU runtime + the pre-provisioned GOLDEN disk into %USERPROFILE%\qemu
    - installs the app payload (Console, deploy scripts, ...) into %LOCALAPPDATA%\Programs\UPES-ECS
    - opens the SIP/RTP firewall rule
    - boots the VM (start-vm.ps1) - the golden disk already has Asterisk + all language packs
      + the FastAPI service enabled via systemd, so it is fully working on first boot; there is
      NO apt, NO pip, NO cloud-image download.
    - starts the Operations Console and registers autostart

  Assumes the built-in Windows OpenSSH client (ssh.exe, present on Windows 10 1809+ / 11) and
  qemu bundled here. No Python is required on the host (all Python runs inside the golden VM,
  already installed there).

  Modes:
    Install (default) - stand up the whole PBX (this is what the double-clicked exe runs).
    Repair            - jump straight to the recovery menu (no re-copy). "Option in case of issue."

  ASCII-only (Windows PowerShell 5.1). Idempotent.
#>
param([ValidateSet('Install','Repair')][string]$Mode='Install')
$ErrorActionPreference='Stop'

# --- Self-elevate (Install only) --------------------------------------------------------
# The install opens the SIP/RTP firewall rule, which needs admin. If we are not elevated,
# relaunch THIS script elevated and WAIT for it (the -Wait matters: the 7-Zip SFX deletes
# its temp extract dir as soon as this process returns, so we must not return until the
# elevated copy has finished reading files out of it). If the user declines UAC, we fall
# through and keep going unelevated - everything installs except the firewall rule, which
# then just prints a warning.
function Test-Admin { ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator) }
if($Mode -eq 'Install' -and -not (Test-Admin)){
  Write-Host "requesting administrator rights (needed to open the SIP/RTP firewall)..." -ForegroundColor Cyan
  try{
    $ps = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
    Start-Process -FilePath $ps -Verb RunAs -Wait -ArgumentList `
      '-NoProfile','-ExecutionPolicy','Bypass','-File',$PSCommandPath,'-Mode','Install'
    return
  }catch{
    Write-Host "  elevation declined - continuing without admin. If LAN phones cannot register," -ForegroundColor Yellow
    Write-Host "  re-run this installer as administrator (right-click > Run as administrator)." -ForegroundColor Yellow
  }
}

$Src   = $PSScriptRoot                       # where the SFX extracted us
$Base  = "$env:USERPROFILE\qemu"
$AppDir= Join-Path $env:LOCALAPPDATA 'Programs\UPES-ECS'

function Ensure-Dir($p){ if(-not (Test-Path $p)){ New-Item -ItemType Directory -Path $p -Force | Out-Null } }

# REPAIR shortcut: if the user asked for repair, run the installed recovery tool and stop.
$RepairPs1 = Join-Path $AppDir 'deploy\qemu\Repair-UpesEcs.ps1'
if($Mode -eq 'Repair'){
  if(Test-Path $RepairPs1){ & powershell -NoProfile -ExecutionPolicy Bypass -File $RepairPs1 -Base $Base; return }
  Write-Host "Repair tool not found ($RepairPs1). Run the installer first." -ForegroundColor Yellow; return
}

Write-Host "== UPES-ECS offline setup ==" -ForegroundColor Cyan

# 1) QEMU runtime + golden disk -> %USERPROFILE%\qemu
Ensure-Dir $Base
Write-Host "installing QEMU runtime..."
& robocopy (Join-Path $Src 'qemu') $Base /E /XO /NFL /NDL /NJH /NJS /NP | Out-Null
Ensure-Dir (Join-Path $Base 'images')
# robocopy already brought qemu\images\upes-ecs-server.qcow2 across (it is inside qemu\).
if(-not (Test-Path (Join-Path $Base 'images\upes-ecs-server.qcow2'))){
  throw "golden disk missing after copy - the bundle may be incomplete."
}
# Keep a PRISTINE golden copy so 'Repair -> reset' can re-provision the system exactly as
# shipped, fully offline. Copy from the SFX source (guaranteed pristine), only if absent, so
# re-running the installer never clobbers a good golden with an already-used working disk.
$goldenSrc = Join-Path $Src 'qemu\images\upes-ecs-server.qcow2'
$goldenDst = Join-Path $Base 'images\upes-ecs-server.golden.qcow2'
if((Test-Path $goldenSrc) -and -not (Test-Path $goldenDst)){
  Write-Host "keeping a pristine golden copy for recovery..."
  Copy-Item -LiteralPath $goldenSrc -Destination $goldenDst -Force
}

# 2) App payload -> install dir
Ensure-Dir $AppDir
Write-Host "installing app files..."
& robocopy (Join-Path $Src 'app') $AppDir /E /XO /NFL /NDL /NJH /NJS /NP | Out-Null

# 3) Optional Piper -> %USERPROFILE%
if(Test-Path (Join-Path $Src 'piper')){
  Write-Host "installing Piper (host-side prompt generation)..."
  if(Test-Path (Join-Path $Src 'piper\piper-win')){ & robocopy (Join-Path $Src 'piper\piper-win') "$env:USERPROFILE\piper-win" /E /XO /NFL /NDL /NJH /NJS /NP | Out-Null }
  if(Test-Path (Join-Path $Src 'piper\piper-model')){ & robocopy (Join-Path $Src 'piper\piper-model') "$env:USERPROFILE\piper-model" /E /XO /NFL /NDL /NJH /NJS /NP | Out-Null }
}

# 4) Firewall (SIP 5060/udp + RTP 10000-10019/udp). Offline, no download.
Write-Host "opening SIP/RTP firewall rule..."
try{
  if(-not (Get-NetFirewallRule -DisplayName 'UPES-ECS SIP-RTP' -EA SilentlyContinue)){
    New-NetFirewallRule -DisplayName 'UPES-ECS SIP-RTP' -Direction Inbound -Action Allow -Protocol UDP -LocalPort 5060,10000-10019 | Out-Null
  }
}catch{ Write-Host "  (could not add firewall rule - run once elevated if phones cannot register)" -ForegroundColor Yellow }

# 5) Sanity: ssh.exe present (built into Windows 10 1809+/11)
if(-not (Get-Command ssh.exe -EA SilentlyContinue)){
  Write-Host "WARNING: Windows OpenSSH client (ssh.exe) not found. Enable it:" -ForegroundColor Yellow
  Write-Host "  Settings > Apps > Optional Features > OpenSSH Client" -ForegroundColor Yellow
}

# 6) Boot the VM from the golden disk (no build, no download)
$startVm = Join-Path $AppDir 'deploy\qemu\start-vm.ps1'
if(Test-Path $startVm){
  Write-Host "booting the emergency PBX VM..."
  & powershell -NoProfile -ExecutionPolicy Bypass -File $startVm -Base $Base
} else { Write-Host "start-vm.ps1 not found in payload - cannot boot VM" -ForegroundColor Yellow }

# 7) Autostart + Console
$reg = Join-Path $AppDir 'deploy\qemu\Register-Autostart.ps1'
if(Test-Path $reg){ try{ & powershell -NoProfile -ExecutionPolicy Bypass -File $reg -Base $Base }catch{} }
$serve = Join-Path $AppDir 'Console\Serve.ps1'
if(Test-Path $serve){
  Write-Host "starting the Operations Console on http://localhost:8080 ..."
  Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',$serve,'-Base',$Base
  Start-Sleep 2
  try{ Start-Process 'http://localhost:8080' }catch{}
}

# 8) Discoverable recovery: Desktop + Start Menu "UPES-ECS Repair" shortcut. "Option in case of issue."
if(Test-Path $RepairPs1){
  Write-Host "creating the Repair shortcut..."
  try{
    $ws = New-Object -ComObject WScript.Shell
    $targets = @(
      (Join-Path ([Environment]::GetFolderPath('Desktop')) 'UPES-ECS Repair.lnk'),
      (Join-Path ([Environment]::GetFolderPath('Programs')) 'UPES-ECS Repair.lnk')
    )
    foreach($lnkPath in $targets){
      Ensure-Dir (Split-Path $lnkPath -Parent)
      $lnk = $ws.CreateShortcut($lnkPath)
      $lnk.TargetPath       = (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe')
      $lnk.Arguments        = "-NoProfile -ExecutionPolicy Bypass -File `"$RepairPs1`""
      $lnk.WorkingDirectory = (Split-Path $RepairPs1 -Parent)
      $lnk.Description       = 'Fix the UPES-ECS emergency PBX (no audio, calls dropping, phones cannot register) or reset it to the shipped state.'
      $lnk.IconLocation      = "$env:WINDIR\System32\shell32.dll,77"
      $lnk.Save()
    }
  }catch{ Write-Host "  (could not create Repair shortcut: $($_.Exception.Message))" -ForegroundColor Yellow }
}

Write-Host "== UPES-ECS is up. Console: http://localhost:8080 ==" -ForegroundColor Green
Write-Host "In case of any issue: double-click 'UPES-ECS Repair' on the Desktop (rebind network / reset to golden)." -ForegroundColor Green
