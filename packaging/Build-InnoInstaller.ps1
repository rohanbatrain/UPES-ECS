<#
.SYNOPSIS  Compile the PROFESSIONAL branded installer (UPES-ECS-Setup.exe + .bin slices) with
           Inno Setup, from a staged payload folder.
.DESCRIPTION
  Why Inno + disk slices: Windows cannot run an .exe >4 GB, and the payload is ~10 GB. Inno's
  DiskSpanning ships a tiny always-runnable UPES-ECS-Setup.exe (branded wizard, runs as admin)
  plus UPES-ECS-Setup-N.bin data slices (each <2 GB, FAT32-safe). The wizard extracts the
  payload to a temp folder and runs offline-bootstrap.ps1, which deploys + boots the PBX.

  This only compiles; it touches no VM disk, so it is safe while the PBX is up. It regenerates
  the brand artwork first if missing.
.PARAMETER Payload  Staged payload folder (must contain offline-bootstrap.ps1, qemu\, app\).
.PARAMETER Iss      The Inno script. Default <repo>\packaging\UPES-ECS.iss.
#>
param(
  [Parameter(Mandatory=$true)][string]$Payload,
  [string]$Iss = '',            # defaulted in body (param-default $PSScriptRoot can be empty under -File)
  [switch]$Sign,                # Authenticode-sign Setup + uninstaller (needs a configured Sign Tool)
  [string]$SignToolCmd = ''     # e.g. 'signtool.exe sign /sha1 <THUMB> /fd sha256 /tr http://timestamp.digicert.com /td sha256 /d $qUPES-ECS$q $f'
)
$ErrorActionPreference='Stop'
if([string]::IsNullOrWhiteSpace($Iss)){ $Iss = Join-Path $PSScriptRoot 'UPES-ECS.iss' }
$Brand = Join-Path $PSScriptRoot 'brand'
$Iscc  = @('C:\Program Files (x86)\Inno Setup 6\ISCC.exe','C:\Program Files\Inno Setup 6\ISCC.exe') |
         Where-Object { Test-Path $_ } | Select-Object -First 1

function Need($p,$w){ if(-not (Test-Path $p)){ throw "$w not found: $p" } }
if(-not $Iscc){ throw "Inno Setup (ISCC.exe) not found. Install Inno Setup 6 first." }
Need $Iss     'Inno script (UPES-ECS.iss)'
Need $Payload 'staged payload folder'
Need (Join-Path $Payload 'offline-bootstrap.ps1') 'offline-bootstrap.ps1 in payload root'

# Regenerate brand artwork if any is missing.
$assets = 'brand.ico','wizard-large.bmp','wizard-small.bmp' | ForEach-Object { Join-Path $Brand $_ }
if($assets | Where-Object { -not (Test-Path $_) }){
  Write-Host "generating brand assets..."
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Brand 'Make-BrandAssets.ps1') | Out-Null
}

$isccArgs = @("/DPayload=$Payload", "/DBrand=$Brand")
if($Sign){
  $isccArgs += '/DSign'
  # A Sign Tool named "upessign" must exist (Inno IDE Tools->Configure Sign Tools, or pass one here).
  if($SignToolCmd){ $isccArgs += "/Supessign=$SignToolCmd" }
  Write-Host "  signing : enabled (SignedUninstaller + Setup)" -ForegroundColor Yellow
}
Write-Host "== Compiling branded installer with Inno Setup ==" -ForegroundColor Cyan
Write-Host "  payload : $Payload"
& $Iscc @isccArgs $Iss
if($LASTEXITCODE -ne 0){ throw "ISCC failed (exit $LASTEXITCODE)" }

$RepoRoot = Split-Path $PSScriptRoot -Parent
# OutputBaseFilename is versioned (UPES-ECS-Setup-<ver>-x64.exe); find the produced exe.
$exe = Get-ChildItem (Join-Path $RepoRoot 'dist') -Filter 'UPES-ECS-Setup-*-x64.exe' -EA SilentlyContinue |
       Sort-Object LastWriteTime -Descending | Select-Object -First 1 | ForEach-Object { $_.FullName }
if(-not $exe -or -not (Test-Path $exe)){ throw "installer exe not produced in $RepoRoot\dist" }
$exeLen = (Get-Item $exe).Length
if($exeLen -ge 4GB){ throw "setup exe is >=4 GB ($exeLen) - it will not run. Reduce DiskSliceSize." }
$slices = Get-ChildItem (Join-Path $RepoRoot 'dist') -Filter 'UPES-ECS-Setup-*.bin' -EA SilentlyContinue
$total  = [math]::Round((($exeLen + ($slices | Measure-Object Length -Sum).Sum)/1GB),2)
Write-Host "== DONE ==" -ForegroundColor Green
Write-Host ("  {0}  ({1:N0} bytes) + {2} data slices = {3} GB total" -f $exe,$exeLen,$slices.Count,$total)
Write-Host "  Ship the .exe + all .bin files together. On a fresh PC: run UPES-ECS-Setup.exe." -ForegroundColor Green
