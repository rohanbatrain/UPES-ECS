<#
.SYNOPSIS  Make UPES-ECS survive a laptop reboot: auto-start the PBX VM and the
           Operations Console at user logon. NO admin required - uses the per-user
           Startup folder (not Task Scheduler, which needs elevation).
.DESCRIPTION
  Writes two launchers into the user's Startup folder:
    UPES-ECS-VM.cmd       -> start-vm.ps1      (boots the QEMU Asterisk server, headless)
    UPES-ECS-Console.cmd  -> Run-Console.ps1   (SUPERVISED console: serves + auto-restarts
                                                Serve.ps1 forever, refreshes status.json)
  The console launcher runs the supervisor (Run-Console.ps1), not Serve.ps1 directly, so
  the Console self-heals if it ever crashes and picks up deploys automatically (Serve.ps1
  serves assets no-cache + a /__build stamp the dashboard reloads on). Run this ONCE and
  you never launch the console by hand again.
  Re-run any time to update. Use -Remove to unregister.
.PARAMETER Remove   Delete the launchers instead of creating them.
#>
param(
  [switch]$Remove,
  [string]$QemuDir    = "$env:USERPROFILE\qemu",
  [string]$ConsoleDir = (Join-Path (Split-Path (Split-Path $PSScriptRoot)) 'Console')  # repo\Console, derived
)
$ErrorActionPreference = 'Stop'
$startup = [Environment]::GetFolderPath('Startup')
$items = @(
  @{ Name='UPES-ECS-VM.cmd';      Script="$QemuDir\start-vm.ps1"; Args=''; Delay=0 },
  @{ Name='UPES-ECS-Console.cmd'; Script="$ConsoleDir\Run-Console.ps1";  Args='-Port 8080 -RefreshSec 20'; Delay=25 }
)

if ($Remove) {
  foreach ($it in $items) {
    $p = Join-Path $startup $it.Name
    if (Test-Path $p) { Remove-Item $p -Force; Write-Host "removed $($it.Name)" } else { Write-Host "not present: $($it.Name)" }
  }
  return
}

foreach ($it in $items) {
  if (-not (Test-Path $it.Script)) { Write-Host "SKIP $($it.Name): $($it.Script) not found" -ForegroundColor Yellow; continue }
  # small stagger so the VM has a head start before the Console begins polling it
  $wait = if ($it.Delay -gt 0) { "timeout /t $($it.Delay) /nobreak >nul`r`n" } else { "" }
  $cmd  = "@echo off`r`n$wait" +
          "start """" /min powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ""$($it.Script)"" $($it.Args)`r`n"
  [System.IO.File]::WriteAllText((Join-Path $startup $it.Name), $cmd, (New-Object Text.ASCIIEncoding))
  Write-Host "installed $($it.Name) -> $($it.Script) $($it.Args)"
}
Write-Host "`nDone. At each logon the PBX VM starts, then the Console ~25s later."
Write-Host "Startup folder: $startup"
Write-Host "To undo: Register-Autostart.ps1 -Remove"
