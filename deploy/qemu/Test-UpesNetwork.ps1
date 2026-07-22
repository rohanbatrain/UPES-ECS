<#
.SYNOPSIS
  Prove the UPES-ECS PBX is reachable on THIS network before you rely on it.
  One command that a non-networking person can run on the PBX laptop to confirm phones
  will register + dial + sync contacts. Prints READY / issues + the exact fix for each.
.DESCRIPTION
  Checks, in order: the VM is running; a LAN IP is detected; the stable hostname resolves
  to that IP (mDNS); SIP 5060 + RTP + CardDAV 5232 are listening/forwarded; the Windows
  firewall lets phones in; and (if reachable) Asterisk advertises the right media address.
  Read-only -- changes nothing. Use it after moving networks or wiring a new site.
.PARAMETER Base   QEMU runtime dir. Default %USERPROFILE%\qemu.
.EXAMPLE  powershell -File Test-UpesNetwork.ps1
#>
param([string]$Base = "$env:USERPROFILE\qemu", [string]$Name = 'upes-ecs.local')
$ErrorActionPreference = 'Continue'
$seed = "$Base\seed"
$rc = 0
function Ok  ($m){ Write-Host ("  OK    " + $m) -ForegroundColor Green }
function Warn($m){ Write-Host ("  WARN  " + $m) -ForegroundColor Yellow; if ($rc -lt 1){ $script:rc = 1 } }
function Bad ($m){ Write-Host ("  FAIL  " + $m) -ForegroundColor Red;   $script:rc = 2 }
function Fix ($m){ Write-Host ("        -> " + $m) -ForegroundColor DarkGray }

function Resolve-LanIp {
  $upIdx = @(Get-NetAdapter -EA SilentlyContinue | Where-Object { $_.Status -eq 'Up' } | Select-Object -ExpandProperty ifIndex)
  $r = Get-NetRoute -DestinationPrefix 0.0.0.0/0 -EA SilentlyContinue | Where-Object { $upIdx -contains $_.ifIndex } | Sort-Object RouteMetric | Select-Object -First 1
  if ($r) { $ip = Get-NetIPAddress -InterfaceIndex $r.ifIndex -AddressFamily IPv4 -EA SilentlyContinue | Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254\.)' } | Select-Object -First 1; if ($ip){ return $ip.IPAddress } }
  $c = Get-NetIPAddress -AddressFamily IPv4 -EA SilentlyContinue | Where-Object { $_.IPAddress -match '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)' -and $_.AddressState -eq 'Preferred' -and ($upIdx -contains $_.InterfaceIndex) } | Select-Object -First 1
  if ($c){ return $c.IPAddress }; return $null
}
function Test-Tcp($ip,$port,$ms=1500){
  try { $c=New-Object Net.Sockets.TcpClient; $a=$c.BeginConnect($ip,$port,$null,$null); if($a.AsyncWaitHandle.WaitOne($ms) -and $c.Connected){ $c.Close(); return $true }; $c.Close(); return $false } catch { return $false }
}

Write-Host "`nUPES-ECS network readiness`n==========================" -ForegroundColor Cyan

# 1. VM running
$vmUp = $false
if (Test-Path "$seed\vm.pid") { $p=(Get-Content "$seed\vm.pid" -EA SilentlyContinue); if ($p -and (Get-Process -Id $p -EA SilentlyContinue)) { $vmUp=$true } }
if ($vmUp) { Ok "PBX VM is running (PID $p)" } else { Bad "PBX VM is not running"; Fix "start it: $Base\start-vm.ps1" }

# 2. LAN IP
$ip = Resolve-LanIp
if ($ip) { Ok "Laptop LAN IP: $ip  (phones/switch see the PBX here)" }
else { Bad "No LAN IP - laptop is not on any network"; Fix "plug into the Juniper switch / join the Wi-Fi, then re-run" }

# 3. mDNS hostname -> LAN IP
$mdnsProc = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -EA SilentlyContinue | Where-Object { $_.CommandLine -like '*Publish-UpesHostname.ps1*' }
if ($mdnsProc) { Ok "Hostname responder running (publishing $Name)" } else { Warn "Hostname responder not running"; Fix "it starts with the VM; launch $Base\Publish-UpesHostname.ps1 or restart the VM" }
try {
  $res = (Resolve-DnsName -Name $Name -Type A -EA Stop | Select-Object -First 1).IPAddress
  if ($res -eq $ip) { Ok "$Name resolves to $res  (phones can use the name)" }
  elseif ($res) { Warn "$Name resolves to $res but LAN IP is $ip (stale)"; Fix "restart: $Base\Publish-UpesHostname.ps1 -Once" }
} catch { Warn "$Name did not resolve via mDNS from this laptop"; Fix "check $seed\mdns.log; ensure the responder is running" }

# 4. SIP 5060/udp listening (QEMU forward on all interfaces)
if (Get-NetUDPEndpoint -LocalPort 5060 -EA SilentlyContinue) { Ok "SIP 5060/udp is listening (phones can register)" }
else { if($vmUp){ Bad "SIP 5060/udp not listening" ; Fix "restart the VM: $Base\start-vm.ps1" } else { Warn "SIP 5060/udp not listening (VM down)" } }

# 5. RTP media range (spot-check the first port)
if (Get-NetUDPEndpoint -LocalPort 10000 -EA SilentlyContinue) { Ok "RTP media ports are listening (two-way audio path open)" }
else { if($vmUp){ Warn "RTP port 10000/udp not listening"; Fix "restart the VM: $Base\start-vm.ps1" } }

# 6. CardDAV 5232/tcp reachable (server up + forwarded + firewall)
if ($ip -and (Test-Tcp $ip 5232)) { Ok "CardDAV 5232/tcp reachable on $ip (phonebook syncs)" }
elseif (Test-Tcp '127.0.0.1' 5232) { Warn "CardDAV up locally but not on the LAN IP"; Fix "firewall likely blocks it - see the fix below" }
else { if($vmUp){ Warn "CardDAV 5232/tcp not reachable"; Fix "install it in the VM (api/carddav/install-carddav.sh) or check the firewall" } }

# 7. Windows firewall lets phones in
$fw = @(Get-NetFirewallRule -EA SilentlyContinue | Where-Object { $_.DisplayName -like 'UPES-ECS*' -and $_.Enabled -eq 'True' })
if ($fw.Count -ge 1) { Ok "Firewall rule(s) present: $((($fw | Select-Object -Expand DisplayName) -join ', '))" }
else {
  Warn "No UPES-ECS inbound firewall rule found (phones on the LAN may be blocked)"
  Fix "run ONCE, elevated (admin PowerShell):"
  Fix "New-NetFirewallRule -DisplayName 'UPES-ECS SIP-RTP' -Direction Inbound -Protocol UDP -LocalPort 5060,10000-10019 -Action Allow -Profile Any"
  Fix "New-NetFirewallRule -DisplayName 'UPES-ECS CardDAV' -Direction Inbound -Protocol TCP -LocalPort 5232 -Action Allow -Profile Any"
}

# 8. Asterisk advertises the right media address (if the VM is up)
if ($vmUp) {
  $key = "$Base\ssh\upes_key"
  if (Test-Path $key) {
    $opt = @('-o','StrictHostKeyChecking=no','-o','UserKnownHostsFile=NUL','-o','ConnectTimeout=8','-o','BatchMode=yes')
    $adv = ssh.exe -q -i $key -p 2222 @opt ubuntu@127.0.0.1 "sudo asterisk -rx 'pjsip show transport transport-udp' 2>/dev/null | awk '/external_media_address/{print \$3}'" 2>$null
    if ($adv) {
      if ($adv.Trim() -eq $ip) { Ok "Asterisk advertises $adv (matches LAN IP)" }
      else { Warn "Asterisk advertises $adv but LAN IP is $ip"; Fix "rebind: $Base\Set-UpesLanIp.ps1" }
    }
  }
}

Write-Host "`n--------------------------------------------------" -ForegroundColor DarkGray
switch ($rc) {
  0 { Write-Host "READY: phones can register (upes-ecs.local:5060), call 111, and sync contacts." -ForegroundColor Green }
  1 { Write-Host "MOSTLY READY: core calling works; fix the WARNs above for full function." -ForegroundColor Yellow }
  2 { Write-Host "NOT READY: fix the FAIL item(s) above, then re-run." -ForegroundColor Red }
}
Write-Host "Tell phones to use SIP server:  $Name : 5060   (or $ip : 5060)`n"
exit $rc
