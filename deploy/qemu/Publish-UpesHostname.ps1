<#
.SYNOPSIS
  Publish a STABLE hostname (default upes-ecs.local) for the UPES-ECS PBX over mDNS,
  so phones set the SIP server ONCE and never touch it again across network switches.
.DESCRIPTION
  The pain this fixes: QEMU forwards SIP/RTP on the laptop's LAN IP, and that IP changes
  every time you move to a new router / OTG hotspot. Set-UpesLanIp.ps1 already rebinds
  Asterisk's *advertised* address (server side) -- but every phone still had the raw IP
  typed into its Linphone profile, so someone had to re-point every handset by hand.

  This responder closes that gap with zero per-network config and zero internet:
  it answers multicast-DNS (RFC 6762) A-record queries for "upes-ecs.local" with the
  laptop's CURRENT LAN IP -- the SAME IP Set-UpesLanIp.ps1 computes, so the name and the
  advertised media address always agree. Phones provisioned with server = upes-ecs.local
  re-resolve on their next REGISTER (reg_expires=120s) and follow the laptop automatically.

  Why mDNS and not DNS: on an arbitrary router or a phone-hotspot you do NOT control DHCP,
  so you cannot hand out a DNS server. mDNS is link-local multicast -- it needs nothing on
  the network and works fully offline. This is the only mechanism that is genuinely
  set-once for the field/van case.

  Self-contained: pure PowerShell, no admin (UDP 5353 is unprivileged), no external deps.
  Coexists with Windows' own mDNS responder via SO_REUSEADDR. start-vm.ps1 launches it
  hidden on boot; it recomputes the IP live, so a mid-session network switch needs nothing.

  LOCKSTEP (added): the same live IP-change detection now also fires the SERVER-side rebind
  (Set-UpesLanIp.ps1) so Asterisk's external_media_address follows the network too. Before
  this, a mid-session switch updated the name but not the media address, so calls connected
  yet "press 1" (DTMF) died and dropped ~32s. Now the name AND the media address move
  together with zero manual steps. See Invoke-AsteriskRebind below.

  Fixed SIP devices that cannot resolve .local (some gate phones / speakers) stay on a raw
  IP or a controlled-router DNS entry -- see deploy\qemu\HOSTNAME-mDNS.md.
.PARAMETER Name       The mDNS name to publish. Default upes-ecs.local.
.PARAMETER LanIp      Pin a specific IP instead of auto-detecting (rare; testing).
.PARAMETER Base       Install/runtime dir (for the log). Default %USERPROFILE%\qemu.
.PARAMETER Once       Send one gratuitous announcement and exit (used for a manual nudge).
.EXAMPLE  powershell -File Publish-UpesHostname.ps1
.EXAMPLE  powershell -File Publish-UpesHostname.ps1 -Name pbx.local
#>
param(
  [string]$Name  = 'upes-ecs.local',
  [string]$LanIp,
  [string]$Base  = "$env:USERPROFILE\qemu",
  [switch]$Once
)
$ErrorActionPreference = 'Continue'
$log = "$Base\seed\mdns.log"
function Log($m) {
  $line = "{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m
  try { Add-Content -Path $log -Value $line -Encoding ascii -ErrorAction SilentlyContinue } catch {}
}

# --------------------------------------------------------------------------- #
# LAN IP resolver -- IDENTICAL logic to Set-UpesLanIp.ps1's Resolve-LanIp so the
# mDNS answer always matches the address Asterisk advertises. OTG / no-gateway safe.
# --------------------------------------------------------------------------- #
function Resolve-LanIp {
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
  # 2) OTG / no-gateway fallback: any UP interface with a private, non-APIPA IPv4.
  $cands = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object {
    $_.IPAddress -match '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)' -and
    $_.IPAddress -notmatch '^169\.254\.' -and
    $_.AddressState -eq 'Preferred' -and
    ($upIdx -contains $_.InterfaceIndex)
  }
  $ranked = foreach ($c in $cands) {
    $alias = $c.InterfaceAlias
    $rank = if     ($alias -match 'vEthernet|Default Switch|Hyper-V|WSL|Docker|Loopback') { 9 }
            elseif ($alias -match 'Wi-?Fi|Wireless|WLAN')            { 0 }
            elseif ($alias -match 'USB|RNDIS|Tether|Ethernet|LAN')   { 1 }
            else   { 2 }
    [pscustomobject]@{ Ip = $c.IPAddress; Rank = $rank }
  }
  $best = ($ranked | Where-Object { $_.Rank -lt 9 } | Sort-Object Rank | Select-Object -First 1)
  if ($best) { return $best.Ip }
  return $null
}

# --------------------------------------------------------------------------- #
# Keep Asterisk's advertised media address in lockstep with the published name.
# The name (phone side) already follows the IP live via this responder. The server
# side -- external_media_address in Asterisk's SDP -- was only rebound at VM boot, so a
# mid-session network switch left it STALE: phones followed the name to the new IP
# (signalling ok, call connects) while Asterisk still advertised the OLD IP, so inbound
# RTP + RFC4733 DTMF went nowhere -> "press 1" dead AND the call dropped ~32s.
# Set-UpesLanIp.ps1 is the single source of truth for the rebind and is IDEMPOTENT (it
# no-ops when already correct, else reloads PJSIP), so calling it on every IP change --
# including the first lock-in, which reconciles a responder that (re)started AFTER a move
# -- is safe. Launched detached so the mDNS serve loop never blocks.
# --------------------------------------------------------------------------- #
function Invoke-AsteriskRebind([string]$ip) {
  $rebind = "$Base\Set-UpesLanIp.ps1"
  if (-not (Test-Path $rebind)) { $rebind = "$PSScriptRoot\Set-UpesLanIp.ps1" }
  if (-not (Test-Path $rebind)) { Log "rebind SKIPPED: Set-UpesLanIp.ps1 not found (looked in $Base and $PSScriptRoot)"; return }
  try {
    Start-Process powershell -WindowStyle Hidden -ArgumentList `
      '-NoProfile','-ExecutionPolicy','Bypass','-File',$rebind,'-LanIp',$ip | Out-Null
    Log "rebind Asterisk media address -> $ip  (Set-UpesLanIp.ps1, detached; idempotent)"
  } catch { Log "rebind launch FAILED: $_" }
}

# --------------------------------------------------------------------------- #
# Minimal mDNS wire helpers
# --------------------------------------------------------------------------- #
# Encode a dotted name ("upes-ecs.local") into length-prefixed DNS labels + root 0.
function ConvertTo-DnsName([string]$n) {
  $bytes = New-Object System.Collections.Generic.List[byte]
  foreach ($label in $n.Trim('.').Split('.')) {
    $lb = [Text.Encoding]::ASCII.GetBytes($label)
    $bytes.Add([byte]$lb.Length)
    $bytes.AddRange($lb)
  }
  $bytes.Add([byte]0)
  return ,$bytes.ToArray()
}

# Read a DNS name from a buffer at $off. Returns @{ Name; Next }. Bails (Name=$null)
# on a compression pointer -- questions must not use them for our simple matcher.
function Read-DnsName([byte[]]$buf, [int]$off) {
  $parts = @(); $i = $off
  while ($i -lt $buf.Length) {
    $len = $buf[$i]
    if ($len -eq 0) { $i++; break }
    if (($len -band 0xC0) -eq 0xC0) { return @{ Name = $null; Next = $i + 2 } }  # pointer -> skip
    $i++
    if ($i + $len -gt $buf.Length) { return @{ Name = $null; Next = $buf.Length } }
    $parts += [Text.Encoding]::ASCII.GetString($buf, $i, $len)
    $i += $len
  }
  return @{ Name = ($parts -join '.'); Next = $i }
}

# Build an mDNS response/announcement carrying one A record (name -> ip).
function New-ARecordPacket([string]$name, [string]$ip, [int]$ttl = 120) {
  $out = New-Object System.Collections.Generic.List[byte]
  # Header: ID=0, flags=0x8400 (QR=1, AA=1), QD=0, AN=1, NS=0, AR=0
  $out.AddRange([byte[]](0,0, 0x84,0x00, 0,0, 0,1, 0,0, 0,0))
  $out.AddRange((ConvertTo-DnsName $name))               # NAME
  $out.AddRange([byte[]](0,1))                            # TYPE  A
  $out.AddRange([byte[]](0x80,1))                         # CLASS IN + cache-flush (0x8000)
  $t0 = [byte](($ttl -shr 24) -band 0xFF); $t1 = [byte](($ttl -shr 16) -band 0xFF)
  $t2 = [byte](($ttl -shr 8)  -band 0xFF); $t3 = [byte]($ttl -band 0xFF)
  $out.AddRange([byte[]]($t0,$t1,$t2,$t3))                # TTL (4 bytes)
  $out.AddRange([byte[]](0,4))                            # RDLENGTH = 4
  foreach ($o in $ip.Split('.')) { $out.Add([byte][int]$o) }   # RDATA = A
  return ,$out.ToArray()
}

$mcastAddr = [Net.IPAddress]::Parse('224.0.0.251')
$mcastEp   = New-Object Net.IPEndPoint($mcastAddr, 5353)
$targetLc  = $Name.Trim('.').ToLowerInvariant()

# --------------------------------------------------------------------------- #
# One-shot mode: fire a single announcement with the current IP, then exit.
# --------------------------------------------------------------------------- #
if ($Once) {
  $ip = if ($LanIp) { $LanIp } else { Resolve-LanIp }
  if (-not $ip) { Log "Once: no LAN IP, nothing announced"; exit 1 }
  try {
    $s = New-Object Net.Sockets.UdpClient
    $s.Client.SetSocketOption([Net.Sockets.SocketOptionLevel]::Socket, [Net.Sockets.SocketOptionName]::ReuseAddress, $true)
    $pkt = New-ARecordPacket $Name $ip
    [void]$s.Send($pkt, $pkt.Length, $mcastEp)
    $s.Close()
    Log "Once: announced $Name -> $ip"
  } catch { Log "Once: announce failed: $_" }
  exit 0
}

# --------------------------------------------------------------------------- #
# Responder loop: answer A queries for our name + re-announce on IP change.
# --------------------------------------------------------------------------- #
Log "starting mDNS responder for $Name (base=$Base)"
$sock = $null
try {
  $sock = New-Object Net.Sockets.Socket([Net.Sockets.AddressFamily]::InterNetwork, [Net.Sockets.SocketType]::Dgram, [Net.Sockets.ProtocolType]::Udp)
  $sock.SetSocketOption([Net.Sockets.SocketOptionLevel]::Socket, [Net.Sockets.SocketOptionName]::ReuseAddress, $true)
  $sock.Bind((New-Object Net.IPEndPoint([Net.IPAddress]::Any, 5353)))
  $sock.SetSocketOption([Net.Sockets.SocketOptionLevel]::IP, [Net.Sockets.SocketOptionName]::AddMembership,
    (New-Object Net.Sockets.MulticastOption($mcastAddr, [Net.IPAddress]::Any)))
  $sock.ReceiveTimeout = 1000
} catch {
  Log "FATAL bind 5353 failed: $_"
  exit 1
}

$buf       = New-Object byte[] 4096
$lastIp    = $null
$lastAnnc  = [DateTime]::MinValue
$reboundIp = $null                 # last IP we rebound Asterisk to (fire rebind once per IP)
$announceEverySec = 60

while ($true) {
  # Keep the record fresh: recompute IP; announce on change or on the heartbeat interval.
  $curIp = if ($LanIp) { $LanIp } else { Resolve-LanIp }
  $now   = Get-Date
  if ($curIp -and ($curIp -ne $lastIp -or ($now - $lastAnnc).TotalSeconds -ge $announceEverySec)) {
    try {
      $pkt = New-ARecordPacket $Name $curIp
      [void]$sock.SendTo($pkt, $mcastEp)
      if ($curIp -ne $lastIp) { Log "announce $Name -> $curIp (was $lastIp)" }
      $lastIp = $curIp; $lastAnnc = $now
    } catch { Log "announce failed: $_" }
  }

  # Server side: rebind Asterisk's media address whenever the LAN IP first appears or
  # changes, so the SDP address tracks the network exactly like the mDNS name does. Fires
  # once per distinct IP (not the null transients Resolve-LanIp returns mid-switch, which
  # are skipped above), independent of the announce throttle. See Invoke-AsteriskRebind.
  if ($curIp -and $curIp -ne $reboundIp) {
    Invoke-AsteriskRebind $curIp
    $reboundIp = $curIp
  }

  # Answer inbound queries.
  $remote = [Net.EndPoint](New-Object Net.IPEndPoint([Net.IPAddress]::Any, 0))
  try {
    $n = $sock.ReceiveFrom($buf, [ref]$remote)
  } catch [Net.Sockets.SocketException] {
    continue   # 1s receive timeout -> loop back to the announce check
  } catch {
    Log "recv error: $_"; Start-Sleep -Milliseconds 200; continue
  }
  if ($n -lt 12) { continue }

  # Parse header: only act on queries (QR=0) with questions.
  $flags = ($buf[2] -shl 8) -bor $buf[3]
  if (($flags -band 0x8000) -ne 0) { continue }          # a response, not a query
  $qd = ($buf[4] -shl 8) -bor $buf[5]
  if ($qd -lt 1) { continue }

  $off = 12; $match = $false
  for ($q = 0; $q -lt $qd -and $off -lt $n; $q++) {
    $rn = Read-DnsName $buf $off
    $off = $rn.Next
    if ($off + 4 -gt $n) { break }
    $qtype = ($buf[$off] -shl 8) -bor $buf[$off + 1]
    $off += 4                                            # skip QTYPE + QCLASS
    if ($rn.Name -and ($rn.Name.ToLowerInvariant() -eq $targetLc) -and ($qtype -eq 1 -or $qtype -eq 255)) {
      $match = $true
    }
  }
  if (-not $match) { continue }

  $ip = if ($LanIp) { $LanIp } else { Resolve-LanIp }
  if (-not $ip) { continue }
  try {
    $pkt = New-ARecordPacket $Name $ip
    [void]$sock.SendTo($pkt, $mcastEp)                    # multicast the answer (RFC 6762)
    $lastIp = $ip; $lastAnnc = Get-Date
  } catch { Log "reply failed: $_" }
}
