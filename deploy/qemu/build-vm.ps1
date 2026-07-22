# UPES-ECS - reproducible QEMU server build on Windows (no admin required).
# Downloads portable QEMU + Ubuntu cloud image, builds the cloud-init ISOs from the
# repo's real config/scripts, and boots a headless, self-configuring server VM.
#
#   powershell -ExecutionPolicy Bypass -File build-vm.ps1
#
# After ~a few minutes (TCG), the VM installs Asterisk + applies the UPES-ECS dialplan.
# Then: ssh -i <base>\ssh\upes_key -p 2222 ubuntu@localhost
$ErrorActionPreference='Stop'
$base   = "$env:USERPROFILE\qemu"
$repo   = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent   # ..\..\ = repo root
$img    = "$base\images"; $seed = "$base\seed"
New-Item -ItemType Directory -Force $base,$img,"$seed\cidata","$seed\data" | Out-Null

# 1. Portable QEMU (extract official installer with 7-Zip - no admin)
if (-not (Test-Path "$base\qemu-system-x86_64.exe")) {
  $idx = curl.exe -s https://qemu.weilnetz.de/w64/
  $latest = ([regex]::Matches($idx,'qemu-w64-setup-\d+\.exe') | ForEach-Object {$_.Value} | Sort-Object -Unique | Select-Object -Last 1)
  curl.exe -L -s -o "$env:TEMP\qemu-setup.exe" "https://qemu.weilnetz.de/w64/$latest"
  & "C:\Program Files\7-Zip\7z.exe" x "$env:TEMP\qemu-setup.exe" "-o$base" -y | Out-Null
}

# 2. Ubuntu 22.04 cloud image -> 20G working disk
if (-not (Test-Path "$img\jammy-base.img")) {
  curl.exe -L -s -o "$img\jammy-base.img" "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
}
Copy-Item "$img\jammy-base.img" "$img\upes-ecs-server.qcow2" -Force
& "$base\qemu-img.exe" resize "$img\upes-ecs-server.qcow2" 20G

# 3. SSH key (put the .pub into seed\user-data before running, or reuse this repo's)
if (-not (Test-Path "$base\ssh\upes_key")) {
  New-Item -ItemType Directory -Force "$base\ssh" | Out-Null
  ssh-keygen.exe -t ed25519 -N '""' -f "$base\ssh\upes_key" -q
  Write-Warning "New SSH key generated - paste $base\ssh\upes_key.pub into seed\user-data (ssh_authorized_keys) and rerun."
}

# 4. cloud-init seed: user-data + meta-data (from repo) ; data: config + scripts
Copy-Item "$PSScriptRoot\seed\user-data","$PSScriptRoot\seed\meta-data" "$seed\cidata" -Force
Copy-Item "$PSScriptRoot\seed\setup-in-vm.sh" "$seed\data" -Force
New-Item -ItemType Directory -Force "$seed\data\asterisk","$seed\data\scripts" | Out-Null
Copy-Item "$repo\config\extensions_custom.conf","$repo\config\extensions_features.conf","$repo\config\extensions_features_wiring.conf","$repo\config\extensions_aihelpline.conf" "$seed\data\asterisk\" -Force
Copy-Item "$repo\deploy\asterisk\extensions.conf","$repo\deploy\asterisk\pjsip.conf","$repo\deploy\asterisk\pjsip_accounts.conf","$repo\deploy\asterisk\queues.conf","$repo\deploy\asterisk\voicemail.conf","$repo\deploy\asterisk\rtp.conf","$repo\deploy\asterisk\confbridge.conf","$repo\deploy\asterisk\fail2ban-asterisk.conf" "$seed\data\asterisk\" -Force
Copy-Item "$repo\scripts\*.sh" "$seed\data\scripts\" -Force
# number->language map for the *55 self-service "set my language" feature code
Copy-Item "$repo\i18n\dtmf-languages.csv" "$seed\data\" -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force "$seed\data\api" | Out-Null
Copy-Item "$repo\api\upes_api.py","$repo\api\upes-api.service" "$seed\data\api\" -Force
# host-side runtime scripts must live in $base so Register-Autostart + Set-UpesLanIp work
Copy-Item "$PSScriptRoot\start-vm.ps1","$PSScriptRoot\stop-vm.ps1","$PSScriptRoot\Set-UpesLanIp.ps1" $base -Force -ErrorAction SilentlyContinue

# 5. Build ISOs with Windows IMAPI (no extra tools)
$isoType=@"
public class ISOFile { public unsafe static void Create(string Path, object Stream, int BlockSize, int TotalBlocks) {
  int bytes=0; byte[] buf=new byte[BlockSize]; var ptr=(System.IntPtr)(&bytes);
  var o=System.IO.File.OpenWrite(Path); var i=Stream as System.Runtime.InteropServices.ComTypes.IStream;
  if(o!=null){ while(TotalBlocks-->0){ i.Read(buf,BlockSize,ptr); o.Write(buf,0,bytes);} o.Flush(); o.Close(); } } }
"@
if(-not ('ISOFile' -as [type])){ Add-Type -CompilerParameters (New-Object System.CodeDom.Compiler.CompilerParameters -Property @{CompilerOptions='/unsafe'}) -TypeDefinition $isoType }
function Build-Iso($src,$iso,$label){ $f=New-Object -ComObject IMAPI2FS.MsftFileSystemImage; $f.FileSystemsToCreate=3; $f.VolumeName=$label; $f.Root.AddTree($src,$false); $r=$f.CreateResultImage(); if(Test-Path $iso){Remove-Item $iso -Force}; [ISOFile]::Create($iso,$r.ImageStream,$r.BlockSize,$r.TotalBlocks) }
Build-Iso "$seed\cidata" "$seed\seed.iso" "CIDATA"
Build-Iso "$seed\data" "$seed\data.iso" "UPESDATA"

# 6. First boot WITH the cloud-init ISOs (self-configures). Steady-state boot uses start-vm.ps1.
$vmArgs=@('-name','upes-ecs-pbx-01','-machine','q35','-accel','tcg','-cpu','max','-smp','4','-m','2048','-L',$base,
 '-drive',"file=$img\upes-ecs-server.qcow2,if=virtio,format=qcow2",
 '-drive',"file=$seed\seed.iso,media=cdrom",'-drive',"file=$seed\data.iso,media=cdrom",
 '-netdev','user,id=n0,hostfwd=tcp::2222-:22,hostfwd=udp::5060-:5060',
 '-device','virtio-net-pci,netdev=n0','-display','none','-serial',"file:$seed\serial.log")
$p=Start-Process "$base\qemu-system-x86_64.exe" -ArgumentList $vmArgs -WindowStyle Hidden -PassThru
$p.Id | Out-File "$seed\vm.pid" -Encoding ascii
Write-Output "First boot started (PID $($p.Id)). Wait ~5-10 min for cloud-init, then: ssh -i $base\ssh\upes_key -p 2222 ubuntu@localhost"
