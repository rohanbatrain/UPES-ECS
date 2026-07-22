# UPES-ECS - gracefully stop the QEMU server VM.
$ErrorActionPreference = 'Continue'
$base = "$env:USERPROFILE\qemu"
$key  = "$base\ssh\upes_key"
$seed = "$base\seed"

Write-Output "Requesting graceful shutdown (sudo poweroff)..."
ssh.exe -q -i $key -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o ConnectTimeout=10 ubuntu@127.0.0.1 "sudo systemctl stop asterisk; sudo poweroff" 2>$null

Start-Sleep -Seconds 20
if (Test-Path "$seed\vm.pid") {
  $vmpid = (Get-Content "$seed\vm.pid" -ErrorAction SilentlyContinue).Trim()
  if ($vmpid -and (Get-Process -Id $vmpid -ErrorAction SilentlyContinue)) {
    Write-Output "Still running; forcing stop (PID $vmpid)"
    Stop-Process -Id $vmpid -Force -ErrorAction SilentlyContinue
  }
  Remove-Item "$seed\vm.pid" -ErrorAction SilentlyContinue
}

# Stop the mDNS hostname responder too (no PBX -> no reason to keep advertising it).
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
  Where-Object { $_.CommandLine -like '*Publish-UpesHostname.ps1*' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

Write-Output "UPES-ECS VM stopped."
