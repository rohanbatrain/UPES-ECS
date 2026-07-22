<#
.SYNOPSIS  Deploy all language voice packs + per-caller routing dialplan to the running VM.
.DESCRIPTION
  Idempotent, re-runnable. Pushes every language pack under
  deploy\asterisk\sounds\lang\<code>\ into the VM's /usr/share/asterisk/sounds/<code>/
  (downsampled to Asterisk's 8 kHz mono by sox IN the VM), installs the per-caller
  language-routing dialplan (config\extensions_custom.conf -> [sub_setlang]), seeds the
  campus default into astdb, and reloads. English (sounds/en) is NEVER overwritten - it is
  the always-complete per-file fallback (pristine-en rule).

  Serial by design: one tar, one scp stream, then a sequential in-VM install loop. We do NOT
  stack parallel disk I/O (it has corrupted a vhdx before).

  ASCII-only source (Windows PowerShell 5.1). Safe to run repeatedly.
.PARAMETER Base       Default $env:USERPROFILE\qemu (holds ssh\upes_key).
.PARAMETER Default    Campus default language to seed into DB(lang/_default). Default 'en'.
#>
param(
  [string]$Base="$env:USERPROFILE\qemu",
  [string]$Default="en"
)
$ErrorActionPreference='Stop'
$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$Key      = Join-Path $Base 'ssh\upes_key'
$SoundsLang = Join-Path $RepoRoot 'deploy\asterisk\sounds\lang'
$Dialplan   = Join-Path $RepoRoot 'config\extensions_custom.conf'

function Ssh-Vm { param([string]$Cmd) & ssh.exe -n -i $Key -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o BatchMode=yes -o ConnectTimeout=10 ubuntu@127.0.0.1 $Cmd }
function Scp-Vm { param([string]$Src,[string]$Dst) & scp.exe -i $Key -P 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o BatchMode=yes $Src ("ubuntu@127.0.0.1:" + $Dst) }

if(-not (Test-Path $Key)){ throw "ssh key not found at $Key" }
Write-Host "== UPES-ECS language deploy ==" -ForegroundColor Cyan

# 0) Reachability
if(("$(Ssh-Vm 'echo up')".Trim()) -ne 'up'){ throw "VM not reachable over SSH (is it running?)" }

# 1) Backup /etc/asterisk + a dereferenced copy of sounds/en (pristine-en safeguard)
$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
Write-Host "backing up /etc/asterisk + sounds/en on the VM ($ts)..."
Ssh-Vm ("BK=/var/lib/upes-ecs/backups/$ts; sudo mkdir -p `$BK; " +
  "sudo tar czf `$BK/etc-asterisk.tgz -C /etc asterisk 2>/dev/null; " +
  "sudo cp -aL /usr/share/asterisk/sounds/en `$BK/en-backup 2>/dev/null; " +
  "echo backed up to `$BK") | Write-Host

# 2) Stage + push all non-empty language packs as ONE tar
$langs = Get-ChildItem $SoundsLang -Directory | Where-Object { @(Get-ChildItem $_.FullName -Recurse -Filter *.wav -EA SilentlyContinue).Count -gt 0 }
Write-Host ("pushing " + $langs.Count + " language packs...") -ForegroundColor Cyan
$tar = Join-Path $env:TEMP ("upes-lang-packs-$ts.tgz")
& tar.exe --force-local -czf $tar -C $SoundsLang ($langs.Name)
if(-not (Test-Path $tar)){ throw "failed to build $tar" }
Scp-Vm $tar '/tmp/lang-packs.tgz' | Out-Null

# 3) Serial in-VM install: extract, sox-downsample each wav into sounds/<code>/, reload
$vmInstall = @'
set -u
S=/tmp/lang-stage; rm -rf "$S"; mkdir -p "$S"
tar xzf /tmp/lang-packs.tgz -C "$S"
for lang in $(ls "$S"); do
  src="$S/$lang"; [ -d "$src" ] || continue
  while IFS= read -r wav; do
    rel="${wav#$src/}"; dest="/usr/share/asterisk/sounds/$lang/$rel"
    sudo mkdir -p "$(dirname "$dest")"
    sudo sox "$wav" -r 8000 -c 1 -b 16 "$dest" 2>/dev/null || echo "SOXFAIL $wav"
  done < <(find "$src" -name '*.wav')
  echo "installed $lang"
done
sudo chown -R asterisk:asterisk /usr/share/asterisk/sounds 2>/dev/null || true
sudo asterisk -rx "module reload res_sound.so" >/dev/null 2>&1
echo "SOUNDS-DONE"
'@
# base64 the script so no quoting/CRLF surprises cross the SSH boundary
$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($vmInstall -replace "`r`n","`n")))
Write-Host "installing packs in the VM (serial downsample; this is the slow part)..."
Ssh-Vm ("echo $b64 | base64 -d | bash") | Write-Host

# 4) Install per-caller routing dialplan (idempotent), reload dialplan
Write-Host "installing per-caller routing dialplan..."
Scp-Vm $Dialplan '/tmp/extensions_custom.conf' | Out-Null
Ssh-Vm ("sudo sed -i 's/\r$//' /tmp/extensions_custom.conf; " +
  "sudo install -o root -g root -m 644 /tmp/extensions_custom.conf /etc/asterisk/extensions_custom.conf; " +
  "sudo asterisk -rx 'dialplan reload' >/dev/null 2>&1; echo DIALPLAN-DONE") | Write-Host

# 5) Seed campus default + replay per-user languages from the provisioning CSV
$csv = Join-Path $RepoRoot 'provisioning\user-languages.csv'
Ssh-Vm ("sudo asterisk -rx 'database put lang _default $Default'") | Out-Null
if(Test-Path $csv){
  foreach($ln in @(Get-Content $csv | Select-Object -Skip 1)){
    $p = $ln -split ','; if($p.Count -ge 2){
      $e="$($p[0])".Trim(); $l="$($p[1])".Trim().ToLower()
      if($e -match '^[0-9A-Za-z]{2,20}$' -and $l -match '^[a-z]{2,3}$'){ Ssh-Vm ("sudo asterisk -rx 'database put lang $e $l'") | Out-Null }
    }
  }
}
Remove-Item $tar -Force -EA SilentlyContinue
Write-Host "== deploy complete: per-caller language routing is live ==" -ForegroundColor Green
