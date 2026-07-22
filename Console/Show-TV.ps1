<#
.SYNOPSIS
  Launch a UPES-ECS LED-TV wallboard fullscreen (kiosk) on a chosen monitor.
.DESCRIPTION
  Opens Microsoft Edge (or Chrome) in kiosk mode pointed at one of the two always-on
  campus screens served by the Console (Serve.ps1 on :8080):
    - safety : public "DIAL 111" awareness board  (tv-safety.html)
    - ops    : control-room operations wallboard    (tv-ops.html)
  Each screen runs in its own isolated browser profile, so you can drive BOTH TVs from
  one PC (one per monitor). The pages self-refresh from the PBX and auto-reload on deploy.

  For a dual-display campus PC:  powershell -File Show-TV.ps1 -Both
  Single screen on monitor 2:    powershell -File Show-TV.ps1 -Screen ops -Monitor 1

.PARAMETER Screen   safety | ops   (ignored when -Both)
.PARAMETER Monitor  0-based display index to place the window on (default 0 = primary)
.PARAMETER Both     Launch safety on monitor 0 and ops on monitor 1
.PARAMETER BaseUrl  Console base URL (default http://localhost:8080)
#>
[CmdletBinding()]
param(
  [ValidateSet('safety','ops')][string]$Screen = 'ops',
  [int]$Monitor = 0,
  [switch]$Both,
  [string]$BaseUrl = 'http://localhost:8080'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms

# --- locate a Chromium browser (Edge preferred, then Chrome) ----------------
$cands = @(
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
  "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
)
$browser = $cands | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $browser) { throw "No Edge/Chrome found. Install Microsoft Edge or Google Chrome." }

$screens = [System.Windows.Forms.Screen]::AllScreens

function Start-Kiosk([string]$scr, [int]$mon) {
  $url  = "$BaseUrl/tv-$scr.html"
  $mon  = [Math]::Max(0, [Math]::Min($mon, $screens.Count - 1))
  $b    = $screens[$mon].Bounds
  # isolated profile per screen so two windows run independently and remember nothing
  $prof = Join-Path $env:LOCALAPPDATA "upes-tv\$scr"
  New-Item -ItemType Directory -Force $prof | Out-Null
  $args = @(
    "--user-data-dir=$prof",
    "--app=$url",                       # chromeless app window (no tabs/address bar)
    "--start-fullscreen",
    "--kiosk",
    "--window-position=$($b.X),$($b.Y)", # place it on the target monitor
    "--window-size=$($b.Width),$($b.Height)",
    "--noerrdialogs","--disable-session-crashed-bubble","--disable-infobars",
    "--no-first-run","--fast","--fast-start","--disable-features=TranslateUI",
    "--autoplay-policy=no-user-gesture-required","--check-for-update-interval=31536000"
  )
  Start-Process $browser -ArgumentList $args | Out-Null
  Write-Host ("  [{0}] -> monitor {1} ({2}x{3}) : {4}" -f $scr, $mon, $b.Width, $b.Height, $url) -ForegroundColor Green
}

Write-Host "UPES-ECS TV - launching kiosk ($browser)" -ForegroundColor Cyan
Write-Host "  Console: $BaseUrl   (make sure Serve.ps1 is running)" -ForegroundColor DarkGray
if ($Both) {
  Start-Kiosk 'safety' 0
  if ($screens.Count -ge 2) { Start-Kiosk 'ops' 1 } else { Write-Warning "Only one monitor detected; run -Screen ops on the second display's PC, or attach a 2nd monitor." }
} else {
  Start-Kiosk $Screen $Monitor
}
Write-Host "  Exit kiosk: Ctrl+W (or Alt+F4). Toggle fullscreen in-page: F." -ForegroundColor DarkGray
