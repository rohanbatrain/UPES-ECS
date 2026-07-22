<#
.SYNOPSIS
  Audit UPES-ECS voice-prompt coverage: every language must have every catalog prompt, as
  translated TEXT (i18n\translations\<code>.csv) AND as staged AUDIO (deploy\asterisk\sounds\...).

.DESCRIPTION
  The emergency panic-coach plays the SAME set of prompts in every language (intro -> menu ->
  first-aid topics). A language that is missing a prompt plays that step as SILENCE (never a
  dropped call -- Asterisk's Background/Playback continue on a missing file -- but a degraded
  flow). This script is the single source of truth for "is every language complete?".

  It checks, against i18n\prompts.catalog.json (the canonical N prompts):
    1. TEXT  - each i18n\translations\<code>.csv has a non-empty translation for every prompt id.
    2. AUDIO - the committed English base (deploy\asterisk\sounds\en\) and each staged pack
               (deploy\asterisk\sounds\lang\<code>\) has a WAV for every prompt file.
    3. (optional, -Vm) the RUNNING VM has every prompt under /usr/share/asterisk/sounds/<code>/.

  Packs with ZERO wavs (e.g. zh -- voice pack pending) are reported as "text-only / english-
  fallback", NOT as gaps, because the dialplan falls back to English per file for them.

  ASCII-only (Windows PowerShell 5.1). Exit code 0 = complete, 1 = gaps found.

.PARAMETER Vm    Also SSH the running VM and verify on-box coverage per installed language.
.PARAMETER Base  Runtime dir holding ssh\upes_key (for -Vm). Default %USERPROFILE%\qemu.
.EXAMPLE  powershell -ExecutionPolicy Bypass -File scripts\verify-prompt-coverage.ps1
.EXAMPLE  powershell -ExecutionPolicy Bypass -File scripts\verify-prompt-coverage.ps1 -Vm
#>
[CmdletBinding()]
param(
  [switch]$Vm,
  [string]$Base = "$env:USERPROFILE\qemu"
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent

$catPath = Join-Path $repo 'i18n\prompts.catalog.json'
if (-not (Test-Path $catPath)) { Write-Host "[FAIL] catalog not found: $catPath" -ForegroundColor Red; exit 1 }
$cat   = [IO.File]::ReadAllText($catPath) | ConvertFrom-Json
$ids   = @($cat.prompts | ForEach-Object { "$($_.id)" })
$files = @($cat.prompts | ForEach-Object { "$($_.file)" })
$N     = $ids.Count
Write-Host ("UPES-ECS prompt-coverage audit -- catalog = {0} prompts" -f $N) -ForegroundColor Cyan

# ---- language list from languages.json (authoritative) -----------------------
$langPath = Join-Path $repo 'i18n\languages.json'
$langs = @((([IO.File]::ReadAllText($langPath) | ConvertFrom-Json).languages) | ForEach-Object { "$($_.code)" })

# ---- helper: read a translations CSV positionally (id=col0, text=col5) --------
Add-Type -AssemblyName Microsoft.VisualBasic
function Get-CsvIds($csvPath) {
  $have = @{}
  if (-not (Test-Path $csvPath)) { return $have }
  $tp = New-Object Microsoft.VisualBasic.FileIO.TextFieldParser($csvPath, [Text.Encoding]::UTF8)
  try {
    $tp.TextFieldType = [Microsoft.VisualBasic.FileIO.FieldType]::Delimited
    $tp.SetDelimiters(','); $tp.HasFieldsEnclosedInQuotes = $true
    $first = $true
    while (-not $tp.EndOfData) {
      $f = $tp.ReadFields()
      if ($first) { $first = $false; continue }
      if ($f.Count -lt 6) { continue }
      $id = "$($f[0])".Trim(); $tx = "$($f[5])".Trim()
      if ($id -and $tx) { $have[$id] = $true }
    }
  } finally { $tp.Close() }
  return $have
}

$rows = @()
$totalGaps = 0

foreach ($code in ($langs | Sort-Object)) {
  # TEXT coverage
  if ($code -eq 'en') {
    $textCount = $N   # English text is the catalog itself
  } else {
    $have = Get-CsvIds (Join-Path $repo ("i18n\translations\{0}.csv" -f $code))
    $textCount = @($ids | Where-Object { $have.ContainsKey($_) }).Count
  }
  # AUDIO coverage (committed staging)
  $audioDir = if ($code -eq 'en') { Join-Path $repo 'deploy\asterisk\sounds\en' }
              else { Join-Path $repo ("deploy\asterisk\sounds\lang\{0}" -f $code) }
  $audioCount = 0
  if (Test-Path $audioDir) {
    foreach ($rel in $files) { if (Test-Path (Join-Path $audioDir ($rel -replace '/','\'))) { $audioCount++ } }
  }
  $audioState = if ($audioCount -eq $N) { 'complete' }
                elseif ($audioCount -eq 0) { 'english-fallback' }   # pending voice pack (e.g. zh)
                else { 'PARTIAL' }
  $gap = 0
  if ($textCount -ne $N) { $gap += ($N - $textCount) }
  if ($audioState -eq 'PARTIAL') { $gap += ($N - $audioCount) }
  $totalGaps += $gap
  $rows += [PSCustomObject]@{ Lang=$code; Text=("{0}/{1}" -f $textCount,$N); Audio=("{0}/{1}" -f $audioCount,$N); AudioState=$audioState; Gap=$gap }
}

$rows | Format-Table -AutoSize

$badText  = @($rows | Where-Object { $_.Text -ne ("{0}/{0}" -f $N) -and $_.Text -ne ("$N/$N") })
$partial  = @($rows | Where-Object { $_.AudioState -eq 'PARTIAL' })
$fallback = @($rows | Where-Object { $_.AudioState -eq 'english-fallback' })

if ($fallback.Count -gt 0) {
  Write-Host ("NOTE: english-fallback (text ready, voice pack pending): {0}" -f (($fallback.Lang) -join ', ')) -ForegroundColor Yellow
}
if ($badText.Count -gt 0) {
  Write-Host ("TEXT GAPS in: {0}" -f (($badText.Lang) -join ', ')) -ForegroundColor Red
}
if ($partial.Count -gt 0) {
  Write-Host ("PARTIAL AUDIO (a real gap -- rebuild the pack): {0}" -f (($partial.Lang) -join ', ')) -ForegroundColor Red
}

# ---- optional: verify the RUNNING VM ----------------------------------------
if ($Vm) {
  Write-Host "`n== on-VM coverage ==" -ForegroundColor Cyan
  $key = Join-Path $Base 'ssh\upes_key'
  $sshOpt = @('-o','StrictHostKeyChecking=no','-o','UserKnownHostsFile=NUL','-o','ConnectTimeout=10','-o','BatchMode=yes')
  if (-not (Test-Path $key)) { Write-Host "[!] SSH key not found ($key) - skipping VM check" -ForegroundColor Yellow }
  else {
    $relList = ($files -join "`n")
    $sh = @"
DEST_BASE=/usr/share/asterisk/sounds
for L in en $(($langs | Where-Object { $_ -ne 'en' }) -join ' '); do
  D="`$DEST_BASE/`$L"
  [ -d "`$D" ] || { echo "`$L absent(fallback-to-en)"; continue; }
  miss=0
  while IFS= read -r rel; do [ -f "`$D/`$rel" ] || miss=`$((miss+1)); done <<'REL'
$relList
REL
  echo "`$L missing=`$miss"
done
"@
    $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($sh -replace "`r","")))
    $res = ssh.exe -q -i $key -p 2222 @sshOpt ubuntu@127.0.0.1 "echo $b64 | base64 -d | bash" 2>$null
    if ($res) { $res | ForEach-Object { Write-Host ("    " + $_) } } else { Write-Host "    [!] VM not reachable" -ForegroundColor Yellow }
  }
}

Write-Host ""
if ($badText.Count -eq 0 -and $partial.Count -eq 0) {
  Write-Host ("[ok] coverage complete: {0} languages, {1} prompts each (english-fallback: {2})" -f $langs.Count, $N, $fallback.Count) -ForegroundColor Green
  exit 0
} else {
  Write-Host ("[FAIL] coverage gaps: {0} text-incomplete, {1} partial-audio language(s)" -f $badText.Count, $partial.Count) -ForegroundColor Red
  exit 1
}
