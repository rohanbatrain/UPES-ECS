<#
.SYNOPSIS
  One-command deploy of the UPES-ECS emergency PBX as a QEMU server VM on a Windows
  "van laptop" - LAN-facing, self-configuring, autostarting. No admin required
  (except the optional one-time firewall rule for external phones).

.DESCRIPTION
  Automates everything:
    1. Installs portable QEMU (extracts the official build with 7-Zip)   [no admin]
    2. Downloads the Ubuntu 22.04 cloud image + builds a persistent disk
    3. Builds cloud-init ISOs from this repo's real config/ + scripts/,
       injecting the laptop's LAN IP so Asterisk advertises it to phones
    4. Boots the VM headless, LAN-facing (SIP 5060 + RTP range on all NICs)
    5. Waits for cloud-init to install Asterisk + apply the emergency dialplan
    6. Registers Windows autostart (Startup launcher + logon task)
    7. Adds the SIP/RTP firewall rule (if elevated) or prints the command
    8. Verifies Asterisk + optionally places a live test call to 111

.PARAMETER LanIp
  The laptop's LAN IP phones will register to. Default: auto-detected default-route IPv4.
.PARAMETER Base
  Install/runtime directory. Default C:\Users\Rohan\qemu
.PARAMETER Memory / Cpus / DiskGB / Accel
  VM sizing + accelerator ('tcg' works everywhere; 'whpx' needs the Hypervisor Platform feature).
.PARAMETER RtpStart / RtpCount
  RTP media port range (forwarded). Default 10000, 20 ports.
.PARAMETER AddFirewallRule
  Attempt the inbound firewall rule; self-elevates (UAC) if not already admin.
.PARAMETER Rebuild
  Recreate the VM disk from the base image (wipes VM state).
.PARAMETER SkipCallTest
  Skip the automated softphone call-to-111 validation.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File Deploy-UpesEcsVm.ps1
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File Deploy-UpesEcsVm.ps1 -LanIp 192.168.1.16 -AddFirewallRule
#>
[CmdletBinding()]
param(
  [string]$LanIp,
  [string]$Base    = "$env:USERPROFILE\qemu",
  [int]$Memory     = 2048,
  [int]$Cpus       = 2,
  [int]$DiskGB     = 20,
  [ValidateSet('tcg','whpx')][string]$Accel = 'tcg',
  [int]$RtpStart   = 10000,
  [int]$RtpCount   = 20,
  [switch]$AddFirewallRule,
  [switch]$Rebuild,
  [switch]$SkipCallTest
)
$ErrorActionPreference = 'Stop'
function Step($m){ Write-Host "`n==> $m" -ForegroundColor Cyan }
function Info($m){ Write-Host "    $m" }
function Warn($m){ Write-Host "    ! $m" -ForegroundColor Yellow }
function Test-Admin { ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator) }

$repo   = (Resolve-Path "$PSScriptRoot\..\..").Path
$img    = "$Base\images"
$seed   = "$Base\seed"
$disk   = "$img\upes-ecs-server.qcow2"
$key    = "$Base\ssh\upes_key"
$qemu   = "$Base\qemu-system-x86_64.exe"
$qimg   = "$Base\qemu-img.exe"
$sshOpt = @('-o','StrictHostKeyChecking=no','-o','UserKnownHostsFile=NUL','-o','ConnectTimeout=12','-o','BatchMode=yes')
$rtpEnd = $RtpStart + $RtpCount - 1

# ---- 0. LAN IP -------------------------------------------------------------
if (-not $LanIp) {
  $r = Get-NetRoute -DestinationPrefix 0.0.0.0/0 | Sort-Object RouteMetric | Select-Object -First 1
  $LanIp = (Get-NetIPAddress -InterfaceIndex $r.ifIndex -AddressFamily IPv4).IPAddress
}
Step "UPES-ECS QEMU deploy - LAN IP $LanIp, repo $repo"
New-Item -ItemType Directory -Force $Base,$img,$seed,"$seed\cidata","$seed\data","$Base\ssh" | Out-Null

# ---- 1. QEMU (portable, no admin) -----------------------------------------
Step "1/8 QEMU"
if (-not (Test-Path $qemu)) {
  $sevenZip = @("C:\Program Files\7-Zip\7z.exe","C:\Program Files (x86)\7-Zip\7z.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
  if (-not $sevenZip) { throw "7-Zip not found (needed to extract QEMU). Install 7-Zip or place qemu-system-x86_64.exe in $Base." }
  $idx = curl.exe -s https://qemu.weilnetz.de/w64/
  $latest = ([regex]::Matches($idx,'qemu-w64-setup-\d+\.exe') | ForEach-Object {$_.Value} | Sort-Object -Unique | Select-Object -Last 1)
  Info "downloading $latest ..."
  curl.exe -L -s -o "$env:TEMP\qemu-setup.exe" "https://qemu.weilnetz.de/w64/$latest"
  Info "extracting ..."
  & $sevenZip x "$env:TEMP\qemu-setup.exe" "-o$Base" -y | Out-Null
}
Info ((& $qemu --version | Select-Object -First 1))

# ---- 2. Ubuntu image + disk -----------------------------------------------
Step "2/8 Ubuntu cloud image + disk"
if (-not (Test-Path "$img\jammy-base.img")) {
  Info "downloading Ubuntu 22.04 cloud image ..."
  curl.exe -L -s -o "$img\jammy-base.img" "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
}
if ($Rebuild -or -not (Test-Path $disk)) {
  Copy-Item "$img\jammy-base.img" $disk -Force
  & $qimg resize $disk "${DiskGB}G" | Out-Null
  Info "working disk ready (${DiskGB}G)"
} else { Info "existing disk kept (use -Rebuild to recreate)" }

# ---- 3. SSH key ------------------------------------------------------------
Step "3/8 SSH key"
if (-not (Test-Path $key)) { ssh-keygen.exe -t ed25519 -N '""' -f $key -q }
icacls $key /inheritance:r /grant:r "$($env:USERNAME):F" | Out-Null
$pub = (Get-Content "$key.pub")
Info "key ready"

# ---- 4. cloud-init seed + data ISOs (LAN IP injected) ---------------------
Step "4/8 cloud-init ISOs"
@"
#cloud-config
hostname: upes-ecs-pbx-01
ssh_pwauth: true
password: upesecs
chpasswd: { expire: false }
ssh_authorized_keys:
  - $pub
package_update: true
packages: [asterisk, asterisk-core-sounds-en-gsm, baresip, sox]
runcmd:
  - mkdir -p /mnt/upesdata
  - mount LABEL=UPESDATA /mnt/upesdata || mount /dev/sr1 /mnt/upesdata || mount /dev/sr0 /mnt/upesdata
  - cp /mnt/upesdata/setup-in-vm.sh /tmp/s.sh
  - sed -i 's/\r`$//' /tmp/s.sh
  - bash /tmp/s.sh > /var/log/upes-setup.log 2>&1
  - touch /var/lib/cloud/upes-setup-done
"@ | Set-Content "$seed\cidata\user-data" -Encoding ascii
"instance-id: upes-ecs-01`nlocal-hostname: upes-ecs-pbx-01" | Set-Content "$seed\cidata\meta-data" -Encoding ascii

# payload: setup script + config (with LAN IP) + scripts
Copy-Item "$PSScriptRoot\seed\setup-in-vm.sh" "$seed\data\" -Force
New-Item -ItemType Directory -Force "$seed\data\asterisk","$seed\data\scripts" | Out-Null
# NOTE: this set MUST match the files setup-in-vm.sh copies (its for-loop), or a -Rebuild
# aborts / drops accounts. pjsip_accounts.conf is the account source of truth -- never omit it.
Copy-Item "$repo\config\extensions_custom.conf","$repo\config\extensions_features.conf","$repo\config\extensions_features_wiring.conf","$repo\config\extensions_aihelpline.conf" "$seed\data\asterisk\" -Force
Copy-Item "$repo\deploy\asterisk\extensions.conf","$repo\deploy\asterisk\pjsip.conf","$repo\deploy\asterisk\pjsip_accounts.conf","$repo\deploy\asterisk\queues.conf","$repo\deploy\asterisk\voicemail.conf","$repo\deploy\asterisk\confbridge.conf","$repo\deploy\asterisk\fail2ban-asterisk.conf" "$seed\data\asterisk\" -Force
Copy-Item "$repo\scripts\*.sh" "$seed\data\scripts\" -Force
# api tree (status API + CardDAV directory server) + directory source for the phonebook
New-Item -ItemType Directory -Force "$seed\data\api","$seed\data\Console" | Out-Null
Copy-Item "$repo\api\*" "$seed\data\api\" -Recurse -Force -Exclude '__pycache__'
Copy-Item "$repo\Console\directory.json" "$seed\data\Console\" -Force
# per-user voice-language map (ext,lang): runtime source of truth for the API + astdb boot seed
New-Item -ItemType Directory -Force "$seed\data\provisioning" | Out-Null
if (Test-Path "$repo\provisioning\user-languages.csv") { Copy-Item "$repo\provisioning\user-languages.csv" "$seed\data\provisioning\" -Force }
# inject LAN IP: uncomment + set external addresses; write rtp.conf
$pj = Get-Content "$seed\data\asterisk\pjsip.conf" -Raw
$pj = $pj -replace ';external_media_address=.*', "external_media_address=$LanIp"
$pj = $pj -replace ';external_signaling_address=.*', "external_signaling_address=$LanIp"
Set-Content "$seed\data\asterisk\pjsip.conf" -Value $pj -Encoding ascii
"[general]`nrtpstart=$RtpStart`nrtpend=$rtpEnd" | Set-Content "$seed\data\asterisk\rtp.conf" -Encoding ascii

# IMAPI ISO writer
$isoType=@"
public class ISOFile { public unsafe static void Create(string Path, object Stream, int BlockSize, int TotalBlocks) {
  int bytes=0; byte[] buf=new byte[BlockSize]; var ptr=(System.IntPtr)(&bytes);
  var o=System.IO.File.OpenWrite(Path); var i=Stream as System.Runtime.InteropServices.ComTypes.IStream;
  if(o!=null){ while(TotalBlocks-->0){ i.Read(buf,BlockSize,ptr); o.Write(buf,0,bytes);} o.Flush(); o.Close(); } } }
"@
if(-not ('ISOFile' -as [type])){ Add-Type -CompilerParameters (New-Object System.CodeDom.Compiler.CompilerParameters -Property @{CompilerOptions='/unsafe'}) -TypeDefinition $isoType }
function Build-Iso($src,$iso,$label){ $f=New-Object -ComObject IMAPI2FS.MsftFileSystemImage; $f.FileSystemsToCreate=3; $f.VolumeName=$label; $f.Root.AddTree($src,$false); $rr=$f.CreateResultImage(); if(Test-Path $iso){Remove-Item $iso -Force}; [ISOFile]::Create($iso,$rr.ImageStream,$rr.BlockSize,$rr.TotalBlocks) }
Build-Iso "$seed\cidata" "$seed\seed.iso" "CIDATA"
Build-Iso "$seed\data"   "$seed\data.iso" "UPESDATA"
Info "ISOs built (LAN IP $LanIp injected)"

# ---- 5. First boot (LAN-facing + ISOs) ------------------------------------
Step "5/8 boot VM (accel=$Accel, LAN-facing)"
# stop any prior instance
if (Test-Path "$seed\vm.pid") { $o=(Get-Content "$seed\vm.pid").Trim(); if($o){ Stop-Process -Id $o -Force -ErrorAction SilentlyContinue }; Remove-Item "$seed\vm.pid" -Force }
$rtpFwd = ($RtpStart..$rtpEnd | ForEach-Object { "hostfwd=udp:0.0.0.0:$_-:$_" }) -join ','
# 5232/tcp = CardDAV directory, exposed on the LAN like SIP so phones reach upes-ecs.local:5232.
$netdev = "user,id=n0,hostfwd=tcp:127.0.0.1:2222-:22,hostfwd=udp:0.0.0.0:5060-:5060,hostfwd=tcp:0.0.0.0:5232-:5232,$rtpFwd"
$accelArg = if ($Accel -eq 'whpx') { 'whpx,kernel-irqchip=off' } else { 'tcg' }
$vmArgs = @('-name','upes-ecs-pbx-01','-machine','q35','-accel',$accelArg,'-cpu','max','-smp',"$Cpus",'-m',"$Memory",'-L',$Base,
  '-drive',"file=$disk,if=virtio,format=qcow2",
  '-drive',"file=$seed\seed.iso,media=cdrom",'-drive',"file=$seed\data.iso,media=cdrom",
  '-netdev',$netdev,'-device','virtio-net-pci,netdev=n0','-display','none','-serial',"file:$seed\serial.log")
Remove-Item "$seed\serial.log" -ErrorAction SilentlyContinue
$p = Start-Process $qemu -ArgumentList $vmArgs -WindowStyle Hidden -PassThru
$p.Id | Out-File "$seed\vm.pid" -Encoding ascii
Info "QEMU PID $($p.Id)"

# ---- 6. Wait for cloud-init + setup ---------------------------------------
Step "6/8 wait for Asterisk install + config (cloud-init; slow on TCG)"
function VMssh($c){ ssh.exe -q -i $key -p 2222 @sshOpt ubuntu@127.0.0.1 $c 2>$null }
$done=$false
for($i=1;$i -le 20;$i++){
  Start-Sleep -Seconds 30
  $su = VMssh "test -f /var/lib/cloud/upes-setup-done && echo DONE || echo PENDING"
  Info ("[{0}] setup={1}" -f $i, ($su -join ''))
  if(($su -join '') -match 'DONE'){ $done=$true; break }
}
if(-not $done){ Warn "setup did not confirm in time; check: ssh -i $key -p 2222 ubuntu@localhost 'sudo cat /var/log/upes-setup.log'" }

# ---- 7. Lifecycle scripts + autostart + firewall --------------------------
Step "7/8 lifecycle scripts + autostart + firewall"
# place start/stop scripts in the runtime dir, with the chosen RTP range
Copy-Item "$PSScriptRoot\start-vm.ps1","$PSScriptRoot\stop-vm.ps1","$PSScriptRoot\Set-UpesLanIp.ps1","$PSScriptRoot\Publish-UpesHostname.ps1","$PSScriptRoot\Test-UpesNetwork.ps1","$PSScriptRoot\Rebind-Network.cmd" $Base -Force
((Get-Content "$Base\start-vm.ps1" -Raw) -replace '10000\.\.10019', "$RtpStart..$rtpEnd") | Set-Content "$Base\start-vm.ps1" -Encoding ascii
$startup = [Environment]::GetFolderPath('Startup')
Set-Content "$startup\upes-ecs-vm.cmd" -Encoding ascii -Value "@echo off`r`npowershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Base\start-vm.ps1`""
# Belt-and-suspenders logon task IN ADDITION to the Startup-folder launcher above.
# A locked-down / non-elevated Task Scheduler can deny /Create; that must NOT abort the
# deploy (the Startup launcher already provides autostart). Run through cmd.exe so its
# ">nul 2>nul" swallows schtasks' native stderr entirely -- otherwise PS 5.1 with
# $ErrorActionPreference='Stop' raises a terminating NativeCommandError on any stderr line.
$taskTr = "powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Base\start-vm.ps1`""
cmd.exe /c "schtasks /Create /TN ""UPES-ECS VM"" /TR ""$taskTr"" /SC ONLOGON /F >nul 2>nul"
if ($LASTEXITCODE -eq 0) { Info "autostart registered (Startup launcher + logon task)" }
else { Warn "logon task not created (Task Scheduler locked/needs admin) - Startup-folder launcher still handles autostart" }

$fwCmd = "New-NetFirewallRule -DisplayName 'UPES-ECS SIP-RTP' -Direction Inbound -Protocol UDP -LocalPort 5060,$RtpStart-$rtpEnd -Action Allow -Profile Any; New-NetFirewallRule -DisplayName 'UPES-ECS CardDAV' -Direction Inbound -Protocol TCP -LocalPort 5232 -Action Allow -Profile Any"
if (Test-Admin) {
  try { Invoke-Expression $fwCmd | Out-Null; Info "firewall rule added" } catch { Warn "firewall rule failed: $($_.Exception.Message)" }
} elseif ($AddFirewallRule) {
  Info "self-elevating for firewall rule (UAC prompt)..."
  Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile","-Command",$fwCmd -Wait
} else {
  Warn "firewall rule NOT added (needs admin). Run this once, elevated, so LAN phones can connect:"
  Write-Host "    $fwCmd" -ForegroundColor White
}

# ---- 8. Verify + optional call test ---------------------------------------
Step "8/8 verify"
$ver = VMssh "systemctl is-active asterisk; sudo asterisk -rx 'dialplan show ctx_emergency_111' | grep -c EMERGENCY_111_CALL; sudo asterisk -rx 'pjsip show transport transport-udp' | grep external_media"
Info ("asterisk/emergency/transport: " + ($ver -join ' | '))

if (-not $SkipCallTest) {
  Info "placing a softphone call to 111 (LAN IP path)..."
  $t = @"
BD=`$HOME/.baresip; mkdir -p "`$BD"
printf 'module_path /usr/lib/baresip/modules\nmodule account.so\nmodule menu.so\nmodule ctrl_tcp.so\nmodule g711.so\nctrl_tcp_listen 127.0.0.1:4444\nsip_listen 0.0.0.0:5081\nrtp_ports 12000-12100\n' > "`$BD/config"
printf '<sip:1001@$LanIp;transport=udp>;auth_user=1001;auth_pass=change-me-1001;audio_codecs=PCMU,PCMA;regint=60\n' > "`$BD/accounts"
pkill -x baresip 2>/dev/null; sleep 1; baresip -f "`$BD" >/tmp/ct.log 2>&1 &
sleep 7; echo REG:; sudo asterisk -rx 'pjsip show contacts' | grep -c 1001
python3 -c 'import socket,json
def ns(d):
 b=d.encode();return str(len(b)).encode()+b":"+b+b","
s=socket.create_connection(("127.0.0.1",4444),timeout=5);s.sendall(ns(json.dumps({"command":"dial","params":"111"})));s.close()'
sleep 8; echo RTP:; sudo asterisk -rx 'pjsip show channelstats' | grep -c ulaw; pkill -x baresip 2>/dev/null
"@
  $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($t -replace "`r","")))
  $res = ssh.exe -q -i $key -p 2222 @sshOpt ubuntu@127.0.0.1 "echo $b64 | base64 -d | bash" 2>$null
  Info ("call test: " + ($res -join ' '))
}

# ---- Summary ---------------------------------------------------------------
Write-Host "`n============================================================" -ForegroundColor Green
Write-Host " UPES-ECS QEMU server is UP." -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  Phones on the LAN register to :  $LanIp : 5060   (SAP-ID / positions)"
Write-Host "  Emergency number             :  111   (drill: 199)"
Write-Host "  RTP media range              :  $RtpStart-$rtpEnd/udp"
Write-Host "  Admin / SSH                  :  ssh -i $key -p 2222 ubuntu@localhost"
Write-Host "  Lifecycle                    :  $Base\start-vm.ps1  |  $Base\stop-vm.ps1"
Write-Host "  Autostart                    :  on Windows logon (Startup + task)"
if (-not (Test-Admin)) { Write-Host "  TODO (once, elevated)        :  add the firewall rule above for external phones" -ForegroundColor Yellow }
Write-Host "  Register the ERT answer-point Androids as 4101/4110/4111, then run SOP 17 pilot tests.`n"
