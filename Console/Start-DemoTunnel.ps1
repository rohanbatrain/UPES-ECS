<#
.SYNOPSIS
  Start-DemoTunnel.ps1 - Put the UPES-ECS Console on a temporary PUBLIC https URL
  for a demo. No static IP, no port-forwarding, no router/SRX changes.

.DESCRIPTION
  Starts a Cloudflare "quick tunnel" (cloudflared) that forwards a public
  https://<random>.trycloudflare.com URL to the local Console (Serve.ps1 on :Port).
  The URL is printed and copied to the clipboard. Press Ctrl+C to end the demo;
  the tunnel closes immediately and nothing stays exposed.

  DEMO ONLY - read this:
    * The URL reaches the Console with NO login. Anyone who has the link can use
      whatever the Console serves, including admin views. Share it narrowly and
      stop the tunnel (Ctrl+C) the moment the demo is done.
    * This does NOT expose SIP/RTP. Phones stay on the LAN; the public URL shows
      the live dashboard reflecting on-campus calls. An http tunnel cannot carry
      SIP, and exposing SIP publicly invites toll fraud even during a short demo.

.PARAMETER Port
  Local Console port. Default 8080 (matches Serve.ps1).

.PARAMETER StartServe
  Also launch Serve.ps1 in a new window if nothing is listening on :Port.
#>
param([int]$Port=8080,[switch]$StartServe)

$ErrorActionPreference='Stop'
$here=Split-Path -Parent $MyInvocation.MyCommand.Path

function Test-LocalPort([int]$p){
  $c=New-Object System.Net.Sockets.TcpClient
  try{ $c.Connect('127.0.0.1',$p); $true } catch { $false } finally { $c.Close() }
}

# --- 1. Make sure the Console is actually up -----------------------------------
if(-not (Test-LocalPort $Port)){
  if($StartServe){
    Write-Host "Console not listening on :$Port - launching Serve.ps1..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList '-NoExit','-File',"$here\Serve.ps1",'-Port',$Port | Out-Null
    for($i=0;$i -lt 20 -and -not (Test-LocalPort $Port);$i++){ Start-Sleep -Milliseconds 500 }
  } else {
    Write-Host "WARNING: nothing is listening on http://localhost:$Port." -ForegroundColor Yellow
    Write-Host "         Start the Console first (Console\Serve.ps1) or re-run with -StartServe." -ForegroundColor Yellow
    Write-Host "         Continuing anyway; the public URL will 502 until the Console is up." -ForegroundColor DarkGray
  }
}

# --- 2. Find (or install) cloudflared ------------------------------------------
$cf=(Get-Command cloudflared -ErrorAction SilentlyContinue).Source
$local="$env:USERPROFILE\qemu\tools\cloudflared.exe"
if(-not $cf -and (Test-Path $local)){ $cf=$local }
if(-not $cf){
  Write-Host "cloudflared not found - installing (one time)..." -ForegroundColor Cyan
  try{
    winget install --id Cloudflare.cloudflared -e --accept-source-agreements --accept-package-agreements | Out-Null
    $cf=(Get-Command cloudflared -ErrorAction SilentlyContinue).Source
  } catch { }
}
if(-not $cf){
  Write-Host "  winget unavailable - downloading cloudflared.exe directly..." -ForegroundColor Cyan
  New-Item -ItemType Directory -Force (Split-Path $local) | Out-Null
  Invoke-WebRequest -Uri 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe' -OutFile $local
  $cf=$local
}
Write-Host "cloudflared: $cf" -ForegroundColor DarkGray

# --- 3. Start the quick tunnel -------------------------------------------------
$out=Join-Path $env:TEMP 'upes-cf-out.log'
$err=Join-Path $env:TEMP 'upes-cf-err.log'
Remove-Item $out,$err -ErrorAction SilentlyContinue
$proc=Start-Process -FilePath $cf `
  -ArgumentList @('tunnel','--no-autoupdate','--url',"http://localhost:$Port") `
  -RedirectStandardOutput $out -RedirectStandardError $err -NoNewWindow -PassThru

# --- 4. Fish the public URL out of cloudflared's output ------------------------
$rx='https://[a-z0-9-]+\.trycloudflare\.com'
$url=$null; $deadline=(Get-Date).AddSeconds(30)
while(-not $url -and (Get-Date) -lt $deadline -and -not $proc.HasExited){
  Start-Sleep -Milliseconds 500
  $txt=((Get-Content $err -ErrorAction SilentlyContinue) + (Get-Content $out -ErrorAction SilentlyContinue)) -join "`n"
  $m=[regex]::Match($txt,$rx); if($m.Success){ $url=$m.Value }
}

if($url){
  try{ $url | Set-Clipboard } catch {}
  Write-Host ""
  Write-Host "  ============================================================" -ForegroundColor Green
  Write-Host "   PUBLIC DEMO URL:  $url" -ForegroundColor Green
  Write-Host "   (copied to clipboard)   ->  local Console http://localhost:$Port" -ForegroundColor Green
  Write-Host "  ============================================================" -ForegroundColor Green
  Write-Host ""
  Write-Host "  No login. Share the link narrowly. SIP is NOT exposed." -ForegroundColor Yellow
  Write-Host "  Press Ctrl+C to end the demo and close the tunnel." -ForegroundColor Cyan
} else {
  Write-Host "Could not read the tunnel URL. Last cloudflared output:" -ForegroundColor Red
  Get-Content $err -Tail 20 -ErrorAction SilentlyContinue
}

# --- 5. Hold the tunnel open; clean up on exit ---------------------------------
try{
  Wait-Process -Id $proc.Id
} finally {
  if(-not $proc.HasExited){ Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
  Write-Host "Tunnel closed - nothing is exposed anymore." -ForegroundColor Green
}
