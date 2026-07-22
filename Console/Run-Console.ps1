<#
.SYNOPSIS  Keep the UPES-ECS Operations Console running forever (prod-readiness supervisor).
.DESCRIPTION
  Launches Serve.ps1 and AUTOMATICALLY RESTARTS it whenever it exits - a crash, an
  unhandled error, or a network change that kills the HTTP listener. This is what the
  logon autostart runs so the Console is ALWAYS up without anyone babysitting Serve.ps1.

  - Self-heals: restarts Serve.ps1 with a short backoff (crash-loop guard).
  - Single-instance: takes a lock so a second copy won't double-bind port 8080.
  - Logs restarts to Console\logs\console-supervisor.log (auto-trimmed).

  Serve.ps1 already handles the live pieces (SSH tunnel, /api proxy, status.json
  refresh, and - with the /__build stamp - auto-reloading the dashboard on a deploy),
  so this wrapper only has to guarantee it stays alive.
.PARAMETER Port        Console web port (passed to Serve.ps1). Default 8080.
.PARAMETER RefreshSec  status.json fallback refresh interval (passed to Serve.ps1). Default 20.
.PARAMETER Base        QEMU dir holding the SSH key (passed to Serve.ps1).
#>
param([int]$Port=8080,[int]$RefreshSec=20,[string]$Base="$env:USERPROFILE\qemu")
$ErrorActionPreference='Continue'
$root=$PSScriptRoot
$serve=Join-Path $root 'Serve.ps1'
if(-not (Test-Path $serve)){ Write-Host "Serve.ps1 not found next to this script ($serve)"; exit 1 }

$logDir=Join-Path $root 'logs'
if(-not (Test-Path $logDir)){ New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$log=Join-Path $logDir 'console-supervisor.log'
function Log($m){
  $line="{0}  {1}" -f ([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss')), $m
  try{ Add-Content -LiteralPath $log -Value $line }catch{}
  Write-Host $line
  # keep the log bounded (last ~500 lines)
  try{ if((Get-Item $log).Length -gt 200KB){ $t=Get-Content $log -Tail 500; Set-Content -LiteralPath $log -Value $t } }catch{}
}

# --- single-instance lock: don't let two supervisors fight over port 8080 -----------
$mutex=New-Object System.Threading.Mutex($false, "Global\UPES-ECS-Console-Supervisor")
if(-not $mutex.WaitOne(0)){
  Log "another supervisor already holds the lock - exiting (nothing to do)."
  exit 0
}

Log "supervisor start - port $Port, refresh ${RefreshSec}s"
$fails=0
try{
  while($true){
    $start=Get-Date
    try{
      # Blocks until Serve.ps1 returns (it only returns on crash / listener death).
      & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $serve -Port $Port -RefreshSec $RefreshSec -Base $Base
    }catch{
      Log "Serve.ps1 threw: $($_.Exception.Message)"
    }
    $ran=((Get-Date)-$start).TotalSeconds
    # crash-loop guard: only back off when it keeps dying fast; a long healthy run resets it.
    if($ran -lt 15){ $fails++ } else { $fails=0 }
    $delay=[Math]::Min(30, 2*[Math]::Max(1,$fails))
    Log ("Serve.ps1 exited after {0:N0}s - restarting in {1}s (consecutive fast-exits: {2})" -f $ran,$delay,$fails)
    Start-Sleep -Seconds $delay
  }
}finally{
  $mutex.ReleaseMutex(); $mutex.Dispose()
}
