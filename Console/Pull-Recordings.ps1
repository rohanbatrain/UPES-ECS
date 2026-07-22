<#
.SYNOPSIS  Sync recent call recordings from the VM into Console\recordings\ so the
           Console's Call Records player can play them over the LAN.
.DESCRIPTION
  Recordings live in /var/spool/asterisk/monitor/upes-ecs/ owned by the asterisk user
  (not readable by the ssh 'ubuntu' user). This stages the newest N via `sudo cp` into a
  world-readable dir, then scp's only the files we don't already have locally.
#>
param(
  [string]$Base = "$env:USERPROFILE\qemu",
  [string]$Out  = "$PSScriptRoot\recordings",
  [int]$Keep    = 20
)
$ErrorActionPreference = 'Continue'
$key    = "$Base\ssh\upes_key"
$sshOpt = @('-o','StrictHostKeyChecking=no','-o','UserKnownHostsFile=NUL','-o','ConnectTimeout=10','-o','BatchMode=yes')
New-Item -ItemType Directory -Force $Out | Out-Null

# 1. stage newest $Keep recordings into a readable dir on the VM (base64'd to avoid quote-mangling)
$bash = @'
set -e
S=/home/ubuntu/recstage
sudo mkdir -p "$S"
sudo rm -f "$S"/*.wav 2>/dev/null || true
sudo bash -c 'ls -1t /var/spool/asterisk/monitor/upes-ecs/*.wav 2>/dev/null | head -__KEEP__ | while read f; do cp -f "$f" /home/ubuntu/recstage/; done'
sudo chown ubuntu:ubuntu "$S"/*.wav 2>/dev/null || true
ls -1 "$S"/*.wav 2>/dev/null | xargs -n1 basename 2>/dev/null
'@ -replace '__KEEP__', "$Keep"
$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($bash -replace "`r","")))
$remoteList = ssh.exe -q -i $key -p 2222 @sshOpt ubuntu@127.0.0.1 "echo $b64 | base64 -d | bash" 2>$null
$want = @($remoteList | Where-Object { $_ -match '\.wav$' } | ForEach-Object { $_.Trim() })

# 2. scp only the ones we don't already have
$pulled = 0
foreach ($f in $want) {
  $dest = Join-Path $Out $f
  if (Test-Path $dest) { continue }
  scp.exe -q -i $key -P 2222 @sshOpt "ubuntu@127.0.0.1:/home/ubuntu/recstage/$f" "$dest" 2>$null
  if (Test-Path $dest) { $pulled++ }
}

# 3. prune local files no longer on the VM's recent list
$keepSet = @{}; $want | ForEach-Object { $keepSet[$_] = $true }
Get-ChildItem $Out -Filter *.wav -ErrorAction SilentlyContinue | Where-Object { -not $keepSet[$_.Name] } | Remove-Item -Force -ErrorAction SilentlyContinue

Write-Host "recordings -> $Out  ($($want.Count) available, $pulled newly pulled)"
