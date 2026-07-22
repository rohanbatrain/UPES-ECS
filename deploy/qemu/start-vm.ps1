# UPES-ECS - start the QEMU server VM (headless, persistent, LAN-facing). No admin.
# Van-laptop mode: SIP 5060 + RTP 10000-10019 are exposed on ALL host interfaces
# (so phones on the LAN reach this laptop's IP); SSH stays host-local (127.0.0.1).
$ErrorActionPreference = 'Stop'
$base = "$env:USERPROFILE\qemu"
$qemu = "$base\qemu-system-x86_64.exe"
$img  = "$base\images"
$seed = "$base\seed"

if (Test-Path "$seed\vm.pid") {
  $old = Get-Content "$seed\vm.pid" -ErrorAction SilentlyContinue
  if ($old -and (Get-Process -Id $old -ErrorAction SilentlyContinue)) {
    Write-Output "UPES-ECS VM already running (PID $old)"; return
  }
}

# LAN-facing port forwards: SSH host-local; SIP+RTP + CardDAV + app-WS on 0.0.0.0 (all NICs).
# 5232/tcp = CardDAV directory; 8088/tcp = Asterisk WebSocket for the UPES Safe mobile app
# (SIP-over-WS + WebRTC signalling) so phones reach it at upes-ecs.local:8088 / <lan-ip>:8088.
$rtp = (10000..10019 | ForEach-Object { "hostfwd=udp:0.0.0.0:$_-:$_" }) -join ','
$netdev = "user,id=n0,hostfwd=tcp:127.0.0.1:2222-:22,hostfwd=udp:0.0.0.0:5060-:5060,hostfwd=tcp:0.0.0.0:5232-:5232,hostfwd=tcp:0.0.0.0:8088-:8088,$rtp"

$vmArgs = @(
  '-name','upes-ecs-pbx-01','-machine','q35','-accel','tcg','-cpu','max',
  '-smp','4','-m','2048','-L',$base,
  '-drive',"file=$img\upes-ecs-server.qcow2,if=virtio,format=qcow2",
  '-netdev',$netdev,
  '-device','virtio-net-pci,netdev=n0',
  '-display','none','-serial',"file:$seed\serial.log"
)
$p = Start-Process $qemu -ArgumentList $vmArgs -WindowStyle Hidden -PassThru
$p.Id | Out-File "$seed\vm.pid" -Encoding ascii

# DYNAMIC ACROSS ROUTERS: bind Asterisk to whatever network we're on now.
# Runs detached, waits for the VM, updates the advertised LAN IP + reloads PJSIP.
if (Test-Path "$base\Set-UpesLanIp.ps1") {
  Start-Process powershell -WindowStyle Hidden -ArgumentList `
    '-NoProfile','-ExecutionPolicy','Bypass','-File',"$base\Set-UpesLanIp.ps1",'-WaitForVm' | Out-Null
}

# STABLE HOSTNAME: publish upes-ecs.local over mDNS -> current LAN IP, so phones set the
# SIP server ONCE and follow this laptop across every network switch (no re-pointing by
# hand). Long-running responder; recomputes the IP live, so a mid-session move needs nothing.
if (Test-Path "$base\Publish-UpesHostname.ps1") {
  Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like '*Publish-UpesHostname.ps1*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }  # avoid duplicates on re-run
  Start-Process powershell -WindowStyle Hidden -ArgumentList `
    '-NoProfile','-ExecutionPolicy','Bypass','-File',"$base\Publish-UpesHostname.ps1" | Out-Null
}

Write-Output "UPES-ECS VM started (PID $($p.Id)). Auto-binding to the current network..."
$ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Wi-Fi' -ErrorAction SilentlyContinue).IPAddress
Write-Output "  Phones on the LAN register to:  upes-ecs.local:5060  (or ${ip}:5060)   (dial 111)"
Write-Output "  Stable hostname (mDNS):  upes-ecs.local -> follows this laptop's IP automatically"
Write-Output "  Admin/SSH:  ssh -p 2222 ubuntu@localhost"
Write-Output "  Moved networks while running? Nothing to do -- the hostname re-points itself (or re-run Set-UpesLanIp.ps1)."
