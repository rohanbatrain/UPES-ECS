<#
.SYNOPSIS
  Link a PARENT/guardian account to a student (child) for the UPES Safe app's family view.
  Idempotent -- re-running the same link is a no-op. Mirrors Add-UpesUser.ps1's model:
  the repo copy (provisioning/family/families.csv) is the source of truth, and the same
  row is pushed to the live VM (/opt/upes-ecs/family/families.csv), so they never drift.

.DESCRIPTION
  Both the parent and the child must already be real SIP accounts (create them with
  Add-UpesUser.ps1 first). This script ONLY records the relationship; it never touches
  passwords. Once linked, the parent -- logged into the app with their own SAP ID +
  SIP password -- sees the child on the Family tab: online, last location, on-campus,
  and (during an emergency) whether the child has tapped "I'm safe".

.PARAMETER ParentSap  SAP ID of the parent/guardian account. Digits only.
.PARAMETER ChildSap   SAP ID of the student. Digits only.
.PARAMETER Base       QEMU runtime dir holding ssh\upes_key. Default $env:USERPROFILE\qemu.
.PARAMETER NoVm       Update the repo source of truth only; skip the live VM push.

.EXAMPLE  powershell -File Add-UpesFamily.ps1 -ParentSap 40009001 -ChildSap 500120597
.EXAMPLE  powershell -File Add-UpesFamily.ps1 -ParentSap 40009001 -ChildSap 500120597  # re-run: no-op
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$ParentSap,
  [Parameter(Mandatory)][string]$ChildSap,
  [string]$Base = "$env:USERPROFILE\qemu",
  [switch]$NoVm
)
$ErrorActionPreference = 'Stop'
function Info($m){ Write-Host "    $m" }
function Ok($m){ Write-Host "    $m" -ForegroundColor Green }
function Warn($m){ Write-Host "  ! $m" -ForegroundColor Yellow }

if ($ParentSap -notmatch '^\d{3,}$') { throw "ParentSap must be digits only (got '$ParentSap')." }
if ($ChildSap  -notmatch '^\d{3,}$') { throw "ChildSap must be digits only (got '$ChildSap')." }
if ($ParentSap -eq $ChildSap) { throw "Parent and child cannot be the same SAP ID." }

$repo = (Resolve-Path "$PSScriptRoot\..\..").Path
$csv  = Join-Path $repo 'provisioning\family\families.csv'
$key  = Join-Path $Base 'ssh\upes_key'
$utf8 = New-Object System.Text.UTF8Encoding($false)
if (-not (Test-Path $csv)) { throw "source of truth not found: $csv" }

Write-Host "`n==> Link parent $ParentSap  ->  child $ChildSap" -ForegroundColor Cyan

$row  = "$ParentSap,$ChildSap"
$text = [System.IO.File]::ReadAllText($csv)
$rows = ($text -split "`r?`n" | ForEach-Object { $_.Trim() })
$exists = $rows | Where-Object { $_ -eq $row }

if ($exists) {
  Info "families.csv : link already present (unchanged)."
} else {
  if ($text -notmatch "`n$") { $text += "`n" }
  $text += "$row`n"
  [System.IO.File]::WriteAllText($csv, $text, $utf8)
  Ok "families.csv <- added $row"
}

if ($NoVm) { Warn "-NoVm: skipped live VM push."; return }
if (-not (Test-Path $key)) { Warn "SSH key not found ($key); repo updated but VM not pushed."; return }

$sshOpt = @('-o','StrictHostKeyChecking=no','-o','UserKnownHostsFile=NUL','-o','ConnectTimeout=12','-o','BatchMode=yes')
$remote = @'
set -e
F=/opt/upes-ecs/family/families.csv
ROW="__ROW__"
sudo mkdir -p /opt/upes-ecs/family
sudo touch "$F"
if grep -qxF "$ROW" "$F"; then
  echo "VM: link already present"
else
  printf '%s\n' "$ROW" | sudo tee -a "$F" >/dev/null
  echo "VM: appended $ROW"
fi
'@
$remote = $remote.Replace('__ROW__', $row)
$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($remote -replace "`r","")))
$out = & ssh.exe -q -i $key -p 2222 @sshOpt ubuntu@127.0.0.1 "echo $b64 | base64 -d | bash" 2>$null
$out | ForEach-Object { Info $_ }

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host " Family link ready" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  Parent $ParentSap can now see child $ChildSap in the UPES Safe app."
Write-Host "  (The safety-api picks up families.csv live -- no restart needed.)`n"
