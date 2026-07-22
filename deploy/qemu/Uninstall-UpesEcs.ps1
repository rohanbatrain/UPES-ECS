<#
  UPES-ECS - clean uninstall. Run by the Inno Setup uninstaller (also usable by hand).
  Stops the PBX VM, removes autostart + shortcuts, and deletes the runtime that
  offline-bootstrap.ps1 deployed (%USERPROFILE%\qemu and %LOCALAPPDATA%\Programs\UPES-ECS).
  Safe/idempotent; never touches the internet. ASCII-only (Windows PowerShell 5.1).
#>
$ErrorActionPreference='Continue'
$base = "$env:USERPROFILE\qemu"
$app  = "$env:LOCALAPPDATA\Programs\UPES-ECS"
Write-Host "Uninstalling UPES-ECS Emergency PBX..." -ForegroundColor Cyan

# 1) Stop the VM (graceful, then forced) so the disk is not in use.
$stop = Join-Path $app 'deploy\qemu\stop-vm.ps1'
if(-not (Test-Path $stop)){ $stop = Join-Path $base 'stop-vm.ps1' }
if(Test-Path $stop){ try{ & powershell -NoProfile -ExecutionPolicy Bypass -File $stop | Out-Null }catch{} }
Get-Process -Name 'qemu-system-x86_64' -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue

# 2) Remove logon autostart launchers.
$reg = Join-Path $app 'deploy\qemu\Register-Autostart.ps1'
if(Test-Path $reg){ try{ & powershell -NoProfile -ExecutionPolicy Bypass -File $reg -Remove | Out-Null }catch{} }
$startup = [Environment]::GetFolderPath('Startup')
foreach($n in 'UPES-ECS-VM.cmd','UPES-ECS-Console.cmd'){ Remove-Item (Join-Path $startup $n) -Force -EA SilentlyContinue }

# 3) Remove the "UPES-ECS Repair" shortcuts the bootstrap created.
foreach($dir in ([Environment]::GetFolderPath('Desktop')), ([Environment]::GetFolderPath('Programs'))){
  Remove-Item (Join-Path $dir 'UPES-ECS Repair.lnk') -Force -EA SilentlyContinue
}

# 4) Stop the mDNS responder if still running.
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -EA SilentlyContinue |
  Where-Object { $_.CommandLine -like '*Publish-UpesHostname.ps1*' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -EA SilentlyContinue }

# 5) Delete the runtime (QEMU + golden disk + app payload). ~14 GB reclaimed.
Start-Sleep 2
Remove-Item $base -Recurse -Force -EA SilentlyContinue
Remove-Item $app  -Recurse -Force -EA SilentlyContinue

# 6) Remove the firewall rule.
try{ Get-NetFirewallRule -DisplayName 'UPES-ECS SIP-RTP' -EA SilentlyContinue | Remove-NetFirewallRule -EA SilentlyContinue }catch{}

Write-Host "UPES-ECS removed." -ForegroundColor Green
