<#
.SYNOPSIS
  The ONE safe way to add (or re-assert) a UPES-ECS SIP user. Idempotent: the secret is
  generated exactly ONCE and pinned in the single source of truth
  (deploy/asterisk/pjsip_accounts.conf). Re-running NEVER regenerates the password.

.DESCRIPTION
  Fixes the "new account connects once, then the password changes" class of bug for good.
  The historical cause was secret drift: the account's password was never pinned, so a
  later re-provision / import / rebuild minted a fresh random secret and the phone could
  no longer re-register. This tool removes that failure mode by design:

    1. Source of truth  = deploy/asterisk/pjsip_accounts.conf (real, pinned secrets).
    2. If the extension already exists, its EXISTING secret is read back and reused --
       the password is NEVER regenerated (that is what makes re-runs safe).
    3. The SAME secret is written to: the source-of-truth conf, secrets/TEAM-CREDENTIALS.md,
       and the live VM's /etc/asterisk/pjsip_accounts.conf -- then PJSIP is reloaded and
       the account is verified. All three can never drift again.
    4. A drifted VM (password != source of truth) is HEALED back to the pinned secret,
       so the phone's configured password always works.

.PARAMETER SapId   The SAP ID / employee ID = the extension = the SIP username. Digits only.
.PARAMETER Name    Display name (drives caller ID), e.g. "Student Example Five".
.PARAMETER Role    student | staff. Optional; inferred from SAP length (9=student, 8=staff).
.PARAMETER Secret  Pin an explicit secret (e.g. to match a phone already configured).
                   Ignored if the user already exists (existing secret is authoritative).
.PARAMETER Lang    Preferred spoken language for this caller's emergency/coach prompts:
                   a code from i18n\languages.json (e.g. hi, te, ml, ur, ne, en). Optional;
                   unset = the caller hears the campus default. Upserts the source of truth
                   (provisioning\user-languages.csv), directory.json, and the live astdb
                   (DB(lang/<ext>)) so the dialplan routes this caller immediately.
.PARAMETER Base    QEMU runtime dir holding ssh\upes_key. Default C:\Users\Rohan\qemu.
.PARAMETER NoVm    Only update the repo source of truth + credentials; skip the live VM push.

.EXAMPLE  powershell -File Add-UpesUser.ps1 -SapId 500000005 -Name "Student Example Five"
.EXAMPLE  powershell -File Add-UpesUser.ps1 -SapId 40009999  -Name "New Staff" -Role staff
.EXAMPLE  powershell -File Add-UpesUser.ps1 -SapId 500000005 -Name "Student Example Five" -Lang hi  # route this caller to Hindi prompts
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$SapId,
  [Parameter(Mandatory)][string]$Name,
  [ValidateSet('student','staff')][string]$Role,
  [string]$Secret,
  [string]$Lang,
  [string]$Base = "$env:USERPROFILE\qemu",
  [switch]$App,
  [switch]$NoVm
)
$ErrorActionPreference = 'Stop'
function Info($m){ Write-Host "    $m" }
function Ok($m){ Write-Host "    $m" -ForegroundColor Green }
function Warn($m){ Write-Host "  ! $m" -ForegroundColor Yellow }

# --- resolve paths ---------------------------------------------------------
$repo  = (Resolve-Path "$PSScriptRoot\..\..").Path
$conf  = Join-Path $repo 'deploy\asterisk\pjsip_accounts.conf'
$creds = Join-Path $repo 'secrets\TEAM-CREDENTIALS.md'
$key   = Join-Path $Base 'ssh\upes_key'
if (-not (Test-Path $conf))  { throw "source of truth not found: $conf" }
$utf8  = New-Object System.Text.UTF8Encoding($false)   # no BOM, LF preserved

# --- validate + infer context ---------------------------------------------
if ($SapId -notmatch '^\d{3,}$') { throw "SapId must be digits only (got '$SapId')." }
if (-not $Role) { $Role = if ($SapId.Length -eq 8) { 'staff' } else { 'student' } }
$ctx = if ($Role -eq 'staff') { 'ctx_staff' } else { 'ctx_student' }
$Name = $Name.Trim()

# --- optional language preference ------------------------------------------
if ($Lang) {
  $Lang = $Lang.Trim().ToLower()
  if ($Lang -notmatch '^[a-z]{2,3}$') { throw "Lang must be a 2-3 letter code from i18n\languages.json (got '$Lang')." }
  $langsJson = Join-Path $repo 'i18n\languages.json'
  if (Test-Path $langsJson) {
    try {
      $lj = [IO.File]::ReadAllText($langsJson) | ConvertFrom-Json
      if (-not ($lj.languages | Where-Object { $_.code -eq $Lang })) {
        Warn "language '$Lang' is not in i18n\languages.json - proceeding, but if no pack exists this caller falls back to the campus default/English."
      }
    } catch {}
  }
}

Write-Host "`n==> Add/assert UPES-ECS user $SapId ($Name) [$Role/$ctx]" -ForegroundColor Cyan

# --- read source of truth; find an existing PINNED secret (idempotency core) -----
$lines = [System.IO.File]::ReadAllText($conf) -split "`r?`n"
$existingSecret = $null
$hdr = "[$SapId](auth-tpl)"
for ($i = 0; $i -lt $lines.Count; $i++) {
  if ($lines[$i].Trim() -eq $hdr) {
    for ($j = $i + 1; $j -lt [Math]::Min($i + 6, $lines.Count); $j++) {
      if ($lines[$j] -match '^\s*password\s*=\s*(.+?)\s*$') { $existingSecret = $Matches[1]; break }
    }
    break
  }
}

if ($existingSecret) {
  $Secret = $existingSecret
  $isNew = $false
  Ok "user exists -> reusing PINNED secret (password will NOT change)."
} else {
  $isNew = $true
  if (-not $Secret) {
    # student-style: 7 random bytes -> 14 hex chars. Generated exactly once, then pinned.
    $bytes = New-Object byte[] 7
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $Secret = -join ($bytes | ForEach-Object { $_.ToString('x2') })
  }
  Info "new user -> generated secret pinned as source of truth."
}
Info "secret: $Secret"

# --- canonical account block (exact existing format) -----------------------
# UPES Safe app users register over WebSocket/WebRTC, so their endpoint uses the
# (endpoint-webrtc-tpl) template + transport-ws (defined in pjsip.conf). Everything
# else -- auth, aor, secret, dialing number = SAP -- is identical to a UDP phone, so
# a person is EITHER a UDP-softphone user OR an app user (never both on one SAP).
$endpointTpl = if ($App) { 'endpoint-webrtc-tpl' } else { 'endpoint-tpl' }
$endpointLines = @(
  "[$SapId]($endpointTpl)"
  "context=$ctx"
  "auth=$SapId"
  "aors=$SapId"
  "callerid=$Name <$SapId>"
)
if ($App) { $endpointLines += "transport=transport-ws" }
$block = ($endpointLines + @(
  "[$SapId](auth-tpl)"
  "username=$SapId"
  "password=$Secret"
  "[$SapId](aor-tpl)"
)) -join "`n"
if ($App) { Info "app user -> WebRTC/WS endpoint (registers over ws://<pbx-ip>:8088/ws)." }

# --- 1) source of truth: append block if the user is new -------------------
if ($isNew) {
  $raw = [System.IO.File]::ReadAllText($conf)
  if ($raw -notmatch [Regex]::Escape("[$SapId](endpoint-tpl)")) {
    if ($raw -notmatch "`n$") { $raw += "`n" }
    $raw += "`n$block`n"
    [System.IO.File]::WriteAllText($conf, $raw, $utf8)
    Ok "pjsip_accounts.conf  <- appended $SapId"
  }
} else {
  Info "pjsip_accounts.conf  : already present (unchanged)"
}

# --- 2) TEAM-CREDENTIALS.md: insert the People-table row if missing --------
if (Test-Path $creds) {
  $cl = [System.IO.File]::ReadAllText($creds) -split "`r?`n"
  if (-not ($cl | Where-Object { $_ -match "\|\s*``$SapId``\s*\|" })) {
    $roleLabel = if ($Role -eq 'staff') { 'Staff' } else { 'Student' }
    $row = "| $Name | $roleLabel | ``$SapId`` | ``$Secret`` | $ctx |"
    $sec2 = ($cl | Select-String -Pattern '^\s*##\s*2\.' | Select-Object -First 1).LineNumber
    if ($sec2) {
      $ins = $sec2 - 1                                  # 0-based index of the "## 2." line
      while ($ins -gt 0 -and $cl[$ins-1].Trim() -eq '') { $ins-- }   # walk back over blanks
      $out = @(); $out += $cl[0..($ins-1)]; $out += $row; $out += $cl[$ins..($cl.Count-1)]
      [System.IO.File]::WriteAllText($creds, ($out -join "`n"), $utf8)
      Ok "TEAM-CREDENTIALS.md  <- added row for $SapId"
    } else { Warn "could not locate People table in TEAM-CREDENTIALS.md; add the row by hand." }
  } else { Info "TEAM-CREDENTIALS.md  : row already present" }
}

# --- 2b) directory / roster files: keep the phonebook + rosters in sync -----
#   These carry NO real secret (placeholder only) - the source of truth is pjsip_accounts.conf.
$notes = Join-Path $repo 'Notes\Confirmed Details.md'
if (Test-Path $notes) {
  $nt = [System.IO.File]::ReadAllText($notes)
  if ($nt -notmatch "(?m)^\s*$([Regex]::Escape($SapId))\b") {
    if ($nt -notmatch "`n$") { $nt += "`n" }
    $nt += "$SapId - $Name`n"
    [System.IO.File]::WriteAllText($notes, $nt, $utf8)
    Ok "Confirmed Details.md  <- added $SapId"
  } else { Info "Confirmed Details.md  : already present" }
}
$mc = if ($Role -eq 'staff') { 3 } else { 2 }
$rosters = @(
  @{ path = Join-Path $repo 'provisioning\pilot-users.csv';       row = "$SapId,$Name,__SET_ON_IMPORT__,pjsip,$ctx,`"$Name - $SapId`",no,$mc" }
  @{ path = Join-Path $repo 'provisioning\linphone\users.csv';    row = "$SapId,$Name,$ctx,__SET_ON_IMPORT__" }
)
foreach ($f in $rosters) {
  if (Test-Path $f.path) {
    $ct = [System.IO.File]::ReadAllText($f.path)
    if ($ct -notmatch "(?m)^$([Regex]::Escape($SapId)),") {
      if ($ct -notmatch "`n$") { $ct += "`n" }
      [System.IO.File]::WriteAllText($f.path, ($ct + $f.row + "`n"), $utf8)
      Ok ("{0}  <- added row" -f (Split-Path $f.path -Leaf))
    } else { Info ("{0}  : already present" -f (Split-Path $f.path -Leaf)) }
  }
}
# per-user language preference: single source of truth for voice routing
# (survives Install-UpesEcs directory regeneration; synced into astdb below).
if ($Lang) {
  $langCsv = Join-Path $repo 'provisioning\user-languages.csv'
  if (-not (Test-Path $langCsv)) { [System.IO.File]::WriteAllText($langCsv, "ext,lang`n", $utf8) }
  $rows = @(Import-Csv -Path $langCsv | Where-Object { "$($_.ext)".Trim() -match '^\d{3,}$' })
  $found = $false
  foreach ($r in $rows) { if ("$($r.ext)".Trim() -eq $SapId) { $r.lang = $Lang; $found = $true } }
  if (-not $found) { $rows += [pscustomobject]@{ ext = $SapId; lang = $Lang } }
  $csvOut = "ext,lang`n" + (($rows | ForEach-Object { "{0},{1}" -f "$($_.ext)".Trim(), "$($_.lang)".Trim() }) -join "`n") + "`n"
  [System.IO.File]::WriteAllText($langCsv, $csvOut, $utf8)
  Ok "user-languages.csv  <- $SapId = $Lang"
}

# keep the LED-TV wallboard name directory (Console/directory.json) in sync
$dirJson = Join-Path $repo 'Console\directory.json'
if (Test-Path $dirJson) {
  $obj = $null
  try { $obj = Get-Content $dirJson -Raw | ConvertFrom-Json } catch {}
  if ($null -eq $obj) { $obj = [pscustomobject]@{} }
  $entry = [ordered]@{ name = $Name; kind = $Role }
  if ($Lang) { $entry.lang = $Lang }
  $obj | Add-Member -NotePropertyName $SapId -NotePropertyValue ([pscustomobject]$entry) -Force
  [System.IO.File]::WriteAllText($dirJson, ($obj | ConvertTo-Json -Depth 5), $utf8)
  Ok ("directory.json  <- $SapId = $Name" + $(if ($Lang) { " [$Lang]" } else { "" }))
}

# VM callout/roll-call group membership (role-based). students are in the roster groups; both are in all/700.
$groups = if ($Role -eq 'staff') { 'all 700' } else { 'roster all 700 701 702 hostels academic' }

# --- 3) live VM: append-if-missing / HEAL-if-drifted, reload, verify -------
if ($NoVm) { Warn "-NoVm: skipped live VM push. Run without -NoVm to apply to the running PBX."; return }
if (-not (Test-Path $key)) { Warn "SSH key not found ($key); repo updated but VM not pushed."; return }

$sshOpt = @('-o','StrictHostKeyChecking=no','-o','UserKnownHostsFile=NUL','-o','ConnectTimeout=12','-o','BatchMode=yes')
$remote = @'
set -e
CONF=/etc/asterisk/pjsip_accounts.conf
EXT="__EXT__"
SECRET="__SECRET__"
GRPS="__GROUPS__"                 # NOT 'GROUPS' - that is a bash special var (user's GID array)
sudo cp -a "$CONF" "${CONF}.bak-adduser"
present=$(grep -c "^\[${EXT}\](endpoint-tpl)" "$CONF" || true)
cur=$(sudo asterisk -rx "pjsip show auth ${EXT}" 2>/dev/null | awk "/password/{print \$3}")
if [ "$present" = "0" ]; then
  cat <<BLOCK | sudo tee -a "$CONF" >/dev/null

__BLOCK__
BLOCK
  echo "VM: appended ${EXT}"
elif [ "$cur" != "$SECRET" ]; then
  # HEAL drift: strip every section for this ext, then re-append the pinned block
  sudo awk -v ext="$EXT" '
    /^\[/ { skip = ($0 ~ "^\\[" ext "\\]\\(") ? 1 : 0 }
    skip==0 { print }
  ' "$CONF" > /tmp/pj.$$ && sudo cp /tmp/pj.$$ "$CONF" && rm -f /tmp/pj.$$
  cat <<BLOCK | sudo tee -a "$CONF" >/dev/null

__BLOCK__
BLOCK
  echo "VM: HEALED drifted secret for ${EXT}"
else
  echo "VM: already correct for ${EXT}"
fi
sudo asterisk -rx "pjsip reload" >/dev/null; sleep 2
got=$(sudo asterisk -rx "pjsip show auth ${EXT}" 2>/dev/null | awk "/password/{print \$3}")
if [ "$got" = "$SECRET" ]; then echo "VERIFY_OK ${EXT} ${got}"; else echo "VERIFY_FAIL ${EXT} got=[${got}] want=[${SECRET}]"; fi
# callout / roll-call group membership (idempotent): add EXT to each group file if absent
for g in $GRPS; do
  f=/opt/upes-ecs/groups/$g.csv
  [ -f "$f" ] || continue
  if ! grep -qxF "$EXT" "$f"; then printf '%s\n' "$EXT" | sudo tee -a "$f" >/dev/null; echo "GROUP +$g"; fi
done
'@
$remote = $remote.Replace('__EXT__', $SapId).Replace('__SECRET__', $Secret).Replace('__GROUPS__', $groups).Replace('__BLOCK__', $block)
$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($remote -replace "`r","")))
$out = & ssh.exe -q -i $key -p 2222 @sshOpt ubuntu@127.0.0.1 "echo $b64 | base64 -d | bash" 2>$null

$out | ForEach-Object { Info $_ }
if (($out -join ' ') -match "VERIFY_OK $SapId $([Regex]::Escape($Secret))") {
  Ok "LIVE PBX verified: $SapId authenticates with the pinned secret."
} else {
  Warn "Could not confirm the account on the live PBX (is the VM up? ssh -i $key -p 2222 ubuntu@localhost)."
}

# push the language preference into astdb so the dialplan routes this caller at once
if ($Lang) {
  & ssh.exe -q -i $key -p 2222 @sshOpt ubuntu@127.0.0.1 "sudo asterisk -rx `"database put lang $SapId $Lang`"" 2>$null | Out-Null
  Ok "LIVE PBX: astdb lang/$SapId = '$Lang' (this caller now hears $Lang prompts, English per-file fallback)."
}

# --- 4) refresh the CardDAV phonebook on the PBX ---------------------------
# Push the updated directory.json into the VM and regenerate the shared address book so
# the new person shows up on every phone within seconds. (Staff appear; students are
# excluded from the shared book by design -- they still register + dial as normal.)
if (Test-Path $dirJson) {
  $dirRaw = [System.IO.File]::ReadAllText($dirJson) -replace "`r",""
  $db64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($dirRaw))
  $cd = "echo $db64 | base64 -d | sudo tee /opt/upes-ecs/family/directory.json >/dev/null; " +
        "sudo systemctl start upes-carddav-sync.service 2>/dev/null && echo CARDDAV_SYNCED || echo CARDDAV_SKIP"
  $cout = & ssh.exe -q -i $key -p 2222 @sshOpt ubuntu@127.0.0.1 $cd 2>$null
  if (($cout -join ' ') -match 'CARDDAV_SYNCED') { Ok "CardDAV directory refreshed on the PBX." }
  elseif (($cout -join ' ') -match 'CARDDAV_SKIP') { Info "directory.json pushed; CardDAV not installed on this VM (skipped)." }
}

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host " User ready: $Name" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  SIP username / extension :  $SapId"
Write-Host "  SIP password             :  $Secret"
Write-Host "  Context                  :  $ctx"
Write-Host "  Register phone to        :  upes-ecs.local : 5060  (stable hostname; or the laptop LAN IP)"
Write-Host "  Re-running this command is SAFE -- it will never change the password.`n"
