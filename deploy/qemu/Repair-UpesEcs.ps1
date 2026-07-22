<#
  UPES-ECS - RECOVERY / REPAIR.  "The option in case of issue."
  Run this on a target PC if the emergency PBX is misbehaving after the offline install
  (no audio, calls dropping at ~32s, phones cannot register, VM stuck, etc.).

  It never compiles, never downloads, never touches the internet. Every action works from
  the already-bundled QEMU runtime + the pristine GOLDEN disk that the fat installer left
  on this PC. Safe and idempotent.

  ACTIONS
    rebind   Restart the VM and re-bind it to THIS PC's current network (re-runs the LAN-IP
             media fix + mDNS hostname). Fixes the classic "moved to a new network / no audio
             / call drops at 32s / phones cannot find the server" problem. Non-destructive.
    reset    Restore the VM disk from the pristine bundled golden image (re-provision the
             system exactly as shipped), then boot. Wipes any local VM state. Destructive to
             VM state only; the golden copy is untouched.
    test     Run the network self-test (Test-UpesNetwork.ps1) and print SIP/RTP reachability.
    console  Open the Operations Console (http://localhost:8080).
    menu     Interactive menu (default when double-clicked).

  ASCII-only (Windows PowerShell 5.1). No admin required for rebind/reset/test.
#>
param(
  [ValidateSet('menu','rebind','reset','test','console')]
  [string]$Action='menu',
  [string]$Base="$env:USERPROFILE\qemu"
)
$ErrorActionPreference='Stop'
$Here     = $PSScriptRoot                                  # ...\deploy\qemu in the install dir
$StartVm  = Join-Path $Here 'start-vm.ps1'
$StopVm   = Join-Path $Here 'stop-vm.ps1'
$TestNet  = Join-Path $Base 'Test-UpesNetwork.ps1'
$Images   = Join-Path $Base 'images'
$Working  = Join-Path $Images 'upes-ecs-server.qcow2'
$Golden   = Join-Path $Images 'upes-ecs-server.golden.qcow2'

function Info($m){ Write-Host $m -ForegroundColor Cyan }
function Ok($m){ Write-Host $m -ForegroundColor Green }
function Warn($m){ Write-Host $m -ForegroundColor Yellow }

function Stop-Vm(){
  if(Test-Path $StopVm){
    Info 'Stopping the VM...'
    try{ & powershell -NoProfile -ExecutionPolicy Bypass -File $StopVm | Out-Host }catch{ Warn "  stop-vm reported: $($_.Exception.Message)" }
  }
  # Backstop: make sure no qemu-system process is left holding the disk.
  for($i=0;$i -lt 10;$i++){
    if(-not (Get-Process -Name 'qemu-system-x86_64' -EA SilentlyContinue)){ break }
    Start-Sleep 2
  }
  if(Get-Process -Name 'qemu-system-x86_64' -EA SilentlyContinue){
    Warn '  forcing VM process down...'
    Get-Process -Name 'qemu-system-x86_64' -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
    Start-Sleep 2
  }
}

function Start-Vm(){
  if(-not (Test-Path $StartVm)){ throw "start-vm.ps1 not found at $StartVm - install may be incomplete." }
  Info 'Booting the emergency PBX VM (auto-binds to this network)...'
  & powershell -NoProfile -ExecutionPolicy Bypass -File $StartVm -Base $Base | Out-Host
}

function Do-Rebind(){
  Info '== Repair: restart + re-bind network =='
  Stop-Vm
  Start-Vm
  Ok 'VM restarted. It is re-advertising its address on THIS network (media fix + mDNS applied).'
  if(Test-Path $TestNet){ Info 'Running network self-test...'; try{ & powershell -NoProfile -ExecutionPolicy Bypass -File $TestNet | Out-Host }catch{ Warn "  test reported: $($_.Exception.Message)" } }
  Ok 'Phones register to  upes-ecs.local:5060  (dial 111).'
}

function Do-Reset(){
  Info '== Repair: reset VM to the pristine golden disk (re-provision as-is) =='
  if(-not (Test-Path $Golden)){
    Warn "No pristine golden copy found at:"
    Warn "  $Golden"
    Warn "Cannot reset. (Re-run the offline installer to restore the golden copy.)"
    return
  }
  Warn 'This restores the emergency PBX to its shipped state and DISCARDS local VM changes'
  Warn '(added users, recordings, config edits made on this PC).'
  $ans = Read-Host 'Type RESET to confirm (anything else cancels)'
  if($ans -ne 'RESET'){ Warn 'Cancelled - nothing changed.'; return }
  Stop-Vm
  Info 'Restoring golden disk...'
  Copy-Item -LiteralPath $Golden -Destination $Working -Force
  Ok 'Golden disk restored.'
  Start-Vm
  Ok 'PBX re-provisioned from the golden image and running.'
}

function Do-Test(){
  if(Test-Path $TestNet){ & powershell -NoProfile -ExecutionPolicy Bypass -File $TestNet | Out-Host }
  else { Warn "Test-UpesNetwork.ps1 not found at $TestNet" }
}

function Do-Console(){
  try{ Start-Process 'http://localhost:8080' }catch{ Warn 'Could not open the browser. Go to http://localhost:8080' }
}

function Show-Menu(){
  while($true){
    Write-Host ''
    Write-Host '==== UPES-ECS Repair ====' -ForegroundColor Cyan
    Write-Host '  1) Restart + re-bind network   (no audio / calls drop at 32s / phones cannot register)'
    Write-Host '  2) Reset VM to golden          (re-provision exactly as shipped; wipes local VM state)'
    Write-Host '  3) Network self-test'
    Write-Host '  4) Open Operations Console'
    Write-Host '  5) Exit'
    $c = Read-Host 'Choose 1-5'
    switch($c){
      '1'{ Do-Rebind }
      '2'{ Do-Reset }
      '3'{ Do-Test }
      '4'{ Do-Console }
      '5'{ return }
      default{ Warn 'Enter 1, 2, 3, 4, or 5.' }
    }
  }
}

switch($Action){
  'rebind' { Do-Rebind }
  'reset'  { Do-Reset }
  'test'   { Do-Test }
  'console'{ Do-Console }
  default  { Show-Menu }
}
