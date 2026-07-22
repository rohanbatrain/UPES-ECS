<#
.SYNOPSIS
  Verify 100% voice-prompt coverage: every language CSV must translate EVERY catalog prompt.

.DESCRIPTION
  The dialplan serves prompts per caller from sounds/<lang>/ and falls back to English per
  file. "100% coverage" for a shipped language means it has NO holes - every prompt id in
  i18n/prompts.catalog.json has a non-empty translation in i18n/translations/<lang>.csv.

  This script is the durable gate for that invariant. It parses each CSV POSITIONALLY
  (id = column 0, translation = column 5) so it is immune to the duplicate-header quirk that
  breaks Import-Csv on en.csv (en,en) and id.csv (id,id). Run it after adding any prompt.

.PARAMETER Langs   Optional list of language codes to check (default: every *.csv except en).
.PARAMETER FailOnGap  Exit 1 if any checked language is below 100% (for CI / deploy gates).

.EXAMPLE  powershell -File i18n\Check-PromptCoverage.ps1
.EXAMPLE  powershell -File i18n\Check-PromptCoverage.ps1 -Langs hi,te,ml,ur,ne -FailOnGap
#>
[CmdletBinding()]
param(
  [string[]]$Langs,
  [switch]$FailOnGap
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName Microsoft.VisualBasic

$root = $PSScriptRoot
$catalog = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'prompts.catalog.json') | ConvertFrom-Json
$ids = @($catalog.prompts.id)

function Read-LangMap($csvPath) {
  # Positional CSV read: field[0]=id, field[5]=translation. Robust to duplicate headers
  # and to commas / quotes inside fields. Returns @{ id = translation }.
  $map = @{}
  $p = New-Object Microsoft.VisualBasic.FileIO.TextFieldParser($csvPath, [Text.Encoding]::UTF8)
  try {
    $p.TextFieldType = [Microsoft.VisualBasic.FileIO.FieldType]::Delimited
    $p.SetDelimiters(',')
    $p.HasFieldsEnclosedInQuotes = $true
    $first = $true
    while (-not $p.EndOfData) {
      $fields = $p.ReadFields()
      if ($first) { $first = $false; continue }          # skip header row
      if ($fields.Count -lt 6) { continue }
      $id = "$($fields[0])".Trim()
      if ($id) { $map[$id] = "$($fields[5])".Trim() }
    }
  } finally { $p.Close() }
  return $map
}

$files = Get-ChildItem (Join-Path $root 'translations') -Filter *.csv |
         Where-Object { $_.BaseName -ne 'en' }
if ($Langs) { $files = $files | Where-Object { $Langs -contains $_.BaseName } }

$gaps = 0; $checked = 0
$rows = foreach ($f in ($files | Sort-Object BaseName)) {
  $code = $f.BaseName; $checked++
  $map = Read-LangMap $f.FullName
  $missing = @($ids | Where-Object { -not $map.ContainsKey($_) -or [string]::IsNullOrWhiteSpace($map[$_]) })
  if ($missing.Count) { $gaps++ }
  [pscustomobject]@{ lang=$code; filled=($ids.Count-$missing.Count); of=$ids.Count; missing=($missing -join ', ') }
}

foreach ($r in $rows) {
  $tag = if ($r.filled -eq $r.of) { '[100%]' } else { '[GAP ]' }
  $line = "{0} {1,-4} {2,2}/{3}" -f $tag, $r.lang, $r.filled, $r.of
  if ($r.missing) { $line += "  missing: $($r.missing)" }
  Write-Host $line
}
Write-Host ""
Write-Host ("Catalog prompts: {0}   Languages checked: {1}   Complete: {2}   With gaps: {3}" -f `
            $ids.Count, $checked, ($checked-$gaps), $gaps)
if ($FailOnGap -and $gaps -gt 0) { Write-Host "FAIL: coverage gaps present." -ForegroundColor Red; exit 1 }
if ($gaps -eq 0) { Write-Host "OK: 100% prompt coverage for every checked language." -ForegroundColor Green }
