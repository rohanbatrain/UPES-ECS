<#
.SYNOPSIS
  Bind the UPES-ECS PBX to whatever network the laptop is currently on.
  Auto-detects the current LAN IP and updates Asterisk's advertised media/signalling
  address, then reloads PJSIP. Run this after moving to a new router/Wi-Fi.
.DESCRIPTION
  The only per-network variable is the IP Asterisk advertises to phones. QEMU's port
  forwards already bind all interfaces, so nothing else changes across routers.
  start-vm.ps1 calls this automatically on boot; run it by hand (or from the Console's
  Network section) after a live network switch.

  OTG / no-internet safe: a mobile phone-hotspot / OTG router hands out DHCP leases but
  may advertise no default gateway (no upstream internet). We therefore detect the LAN IP
  from the default route FIRST (normal case) and fall back to the active private-range
  interface (Wi-Fi preferred, then Ethernet/USB-tether) when there is no default route --
  so the rebind still works with zero internet.
.PARAMETER LanIp     Override the auto-detected LAN IP.
.PARAMETER WaitForVm Poll until the VM's SSH is up before rebinding (used at boot).
.EXAMPLE  powershell -File Set-UpesLanIp.ps1
.EXAMPLE  powershell -File Set-UpesLanIp.ps1 -LanIp 10.0.5.20
#>
param([string]$LanIp, [string]$Base = "$env:USERPROFILE\qemu", [switch]$WaitForVm)
$ErrorActionPreference = 'Continue'
$key = "$Base\ssh\upes_key"
$sshOpt = @('-o','StrictHostKeyChecking=no','-o','UserKnownHostsFile=NUL','-o','ConnectTimeout=10','-o','BatchMode=yes')

# Pick the LAN IPv4 phones should register to. Works with NO internet (OTG hotspot).
function Resolve-LanIp {
  # Only consider interfaces whose adapter is actually CONNECTED. A disconnected Wi-Fi can
  # keep a stale IP AND a stale default route (metric 0) -- that is exactly what made the PBX
  # advertise a dead 10.x address while the phones were on the live Ethernet 192.168.x.
  $upIdx = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' } | Select-Object -ExpandProperty ifIndex)

  # 1) Normal case: the (UP) interface carrying the default route. Multiple default routes
  #    (e.g. wired + Wi-Fi on the SAME LAN) can tie on metric and make the pick FLAP between
  #    the two IPs, which churns the advertised media address (calls then break on each flip).
  #    Break ties deterministically: lowest EFFECTIVE metric (route + interface), then WIRED
  #    before wireless, then lowest ifIndex; and on the chosen NIC prefer a Preferred (not
  #    Deprecated) address so we never advertise a half-torn-down IP.
  $ranked = foreach ($rt in (Get-NetRoute -DestinationPrefix 0.0.0.0/0 -ErrorAction SilentlyContinue | Where-Object { $upIdx -contains $_.ifIndex })) {
    $ifm = (Get-NetIPInterface -InterfaceIndex $rt.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1).InterfaceMetric
    if ($null -eq $ifm) { $ifm = 0 }
    $al = (Get-NetAdapter -InterfaceIndex $rt.ifIndex -ErrorAction SilentlyContinue).Name
    $wired = if ($al -match 'Wi-?Fi|Wireless|WLAN') { 1 } else { 0 }
    [pscustomobject]@{ ifIndex = [int]$rt.ifIndex; Eff = ([int]$rt.RouteMetric + [int]$ifm); Wired = $wired }
  }
  $pick = $ranked | Sort-Object Eff, Wired, ifIndex | Select-Object -First 1
  if ($pick) {
    $ip = Get-NetIPAddress -InterfaceIndex $pick.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
          Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254\.)' } |
          Sort-Object @{ Expression = { if ($_.AddressState -eq 'Preferred') { 0 } else { 1 } } } |
          Select-Object -First 1
    if ($ip) { return $ip.IPAddress }
  }

  # 2) OTG / no-gateway fallback: any UP interface holding a private, non-APIPA IPv4.
  #    Rank Wi-Fi first (the van's phones are on Wi-Fi), then wired/USB-tether, then rest.
  $cands = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object {
    $_.IPAddress -match '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)' -and
    $_.IPAddress -notmatch '^169\.254\.' -and
    $_.AddressState -eq 'Preferred' -and
    ($upIdx -contains $_.InterfaceIndex)     # connected adapters only (skip a down Wi-Fi's stale IP)
  }
  $ranked = foreach ($c in $cands) {
    $alias = $c.InterfaceAlias
    # Never bind to a virtual/host-only switch (WSL, Hyper-V, Docker) -- phones aren't on it.
    $rank = if     ($alias -match 'vEthernet|Default Switch|Hyper-V|WSL|Docker|Loopback') { 9 }
            elseif ($alias -match 'Wi-?Fi|Wireless|WLAN')            { 0 }
            elseif ($alias -match 'USB|RNDIS|Tether|Ethernet|LAN')   { 1 }
            else   { 2 }
    [pscustomobject]@{ Ip = $c.IPAddress; Rank = $rank; Alias = $alias }
  }
  $ranked = $ranked | Where-Object { $_.Rank -lt 9 }
  $best = $ranked | Sort-Object Rank | Select-Object -First 1
  if ($best) { return $best.Ip }
  return $null
}

if (-not $LanIp) {
  $LanIp = Resolve-LanIp
  if (-not $LanIp) {
    Write-Host "No usable LAN IPv4 found - the laptop is not on any network." -ForegroundColor Yellow
    Write-Host "Connect to the router's Wi-Fi/OTG hotspot and re-run, or pass -LanIp <address>."
    exit 1
  }
}

if ($WaitForVm) {
  for ($i=0; $i -lt 30; $i++) {
    $u = ssh.exe -q -i $key -p 2222 @sshOpt ubuntu@127.0.0.1 "echo up" 2>$null
    if ($u -match 'up') { break }
    Start-Sleep -Seconds 15
  }
}

# Update Asterisk's external addresses to the current LAN IP + reload (matches commented or live line)
$remote = @'
cur=$(sudo asterisk -rx 'pjsip show transport transport-udp' 2>/dev/null | awk '/external_media_address/{print $3}')
if [ "$cur" = "__IP__" ]; then
  echo "external_media_address already __IP__ - skipping res_pjsip reload (phones stay registered)"
else
  sudo sed -i -E 's|^;?external_media_address=.*|external_media_address=__IP__|; s|^;?external_signaling_address=.*|external_signaling_address=__IP__|' /etc/asterisk/pjsip.conf
  sudo asterisk -rx 'module reload res_pjsip.so' >/dev/null 2>&1
  sleep 2
fi
sudo asterisk -rx 'pjsip show transport transport-udp' | grep external_media_address
'@ -replace '__IP__', $LanIp
$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($remote))
$out = ssh.exe -q -i $key -p 2222 @sshOpt ubuntu@127.0.0.1 "echo $b64 | base64 -d | bash" 2>$null

if ($out -match [Regex]::Escape($LanIp)) {
  Write-Host "UPES-ECS bound to this network." -ForegroundColor Green
} else {
  Write-Host "Set the LAN IP to $LanIp, but could not confirm the PJSIP reload (is the VM up?)." -ForegroundColor Yellow
}
Write-Host "  Phones register to :  ${LanIp} : 5060   (dial 111)"
Write-Host "  Asterisk advertises:  $($out -join ' ')"
Write-Host "  (Tell ERT Android answer points to use $LanIp as the SIP server on this network.)"
