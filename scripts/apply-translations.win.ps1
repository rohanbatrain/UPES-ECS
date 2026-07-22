<#
  UPES-ECS - deterministic merge of a per-language translation JSON into the
  worksheet CSV column, so no agent ever hand-escapes CSV.

  Reads:
    i18n/translations/<Lang>-translations.json  ->  { "<prompt id>": "<translated text>", ... }
                                                     ("_note" keys are ignored)
    i18n/translations/<Lang>.csv                 ->  worksheet built by build-worksheet.ps1
                                                     (columns: id,category,file,max_seconds,en,<Lang>,notes)

  Writes (in place, UTF-8 WITH BOM so Excel + Import-Csv read non-Latin scripts):
    i18n/translations/<Lang>.csv  with the <Lang> column filled from the JSON,
    matched by the "id" column. en / notes / other columns are preserved exactly.

  This file is ASCII-only on purpose (PS 5.1 mis-parses non-ASCII no-BOM .ps1);
  all translated text lives in the UTF-8 JSON, never in the script.

  Usage:
    powershell -ExecutionPolicy Bypass -File scripts\apply-translations.win.ps1 -Lang de
#>
param(
  [Parameter(Mandatory=$true)][string]$Lang
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path $PSScriptRoot -Parent
$csvPath  = Join-Path $RepoRoot ("i18n\translations\{0}.csv" -f $Lang)
$jsonPath = Join-Path $RepoRoot ("i18n\translations\{0}-translations.json" -f $Lang)

if (-not (Test-Path $csvPath))  { throw "worksheet CSV not found: $csvPath (run build-worksheet.ps1 -Lang $Lang first)" }
if (-not (Test-Path $jsonPath)) { throw "translations JSON not found: $jsonPath" }

# ---- load the translation map (UTF-8) ----------------------------------------
$map = Get-Content -Raw -Encoding UTF8 $jsonPath | ConvertFrom-Json

# ConvertFrom-Json gives a PSCustomObject; index by property name.
function Get-Tr([string]$id) {
  $p = $map.PSObject.Properties[$id]
  if ($p) { return "$($p.Value)" }
  return $null
}

# ---- fill the <Lang> column, preserving every other field --------------------
$rows = Import-Csv -Encoding UTF8 -Path $csvPath
if (-not ($rows | Get-Member -Name $Lang -MemberType NoteProperty)) {
  throw "CSV $csvPath has no '$Lang' column - is this the right worksheet?"
}

$filled = 0; $missing = @()
foreach ($r in $rows) {
  $id = "$($r.id)"
  if ([string]::IsNullOrWhiteSpace($id)) { continue }
  $tr = Get-Tr $id
  if ($null -ne $tr -and -not [string]::IsNullOrWhiteSpace($tr)) {
    $r.$Lang = $tr
    $filled++
  } elseif ([string]::IsNullOrWhiteSpace("$($r.$Lang)")) {
    $missing += $id
  }
}

# ---- write back UTF-8 WITH BOM (ConvertTo-Csv preserves column order) ---------
$csvText = ($rows | ConvertTo-Csv -NoTypeInformation) -join "`r`n"
$utf8bom = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($csvPath, $csvText + "`r`n", $utf8bom)

Write-Host ("apply-translations lang={0}: filled {1}/{2} rows." -f $Lang, $filled, $rows.Count)
if ($missing.Count -gt 0) {
  Write-Host ("  MISSING translations for ids: {0}" -f ($missing -join ', '))
  exit 2
}
