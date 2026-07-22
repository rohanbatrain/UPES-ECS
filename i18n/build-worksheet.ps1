<#
.SYNOPSIS
  Build / refresh a translation worksheet CSV for one language from the
  canonical UPES-ECS prompt catalog.

.DESCRIPTION
  Reads i18n/prompts.catalog.json and writes i18n/translations/<lang>.csv,
  one row per prompt, columns:

      id,category,file,max_seconds,en,<lang>,notes

  - "en"    is pre-filled with the exact English wording.
  - "<lang>" is the column the language expert fills in. It is left EMPTY
            for a new language, or (for the base language, e.g. en) pre-filled
            with the English text so the file works as a filled reference.
  - "notes" is pre-filled with per-prompt translation guidance derived from
            the prompt category and its wording (press-a-key digits, star
            codes, the service brand name, medical terms, length limits).

  IDEMPOTENT: if the target CSV already exists, any text the expert has
  already entered in the <lang> column is preserved (matched by prompt id).
  Re-running never overwrites the expert's work; it only fills in newly
  added prompts and refreshes the en / notes helper columns.

  Output is UTF-8 WITH BOM so Excel opens non-Latin scripts (Devanagari,
  etc.) correctly. This script file itself is kept ASCII-only on purpose.

.PARAMETER Lang
  Language code to build, e.g. hi. Matches a code in i18n/languages.json.

.PARAMETER Repo
  Optional path to the repository root. Defaults to the parent of the
  folder this script lives in (i18n\..).

.EXAMPLE
  .\build-worksheet.ps1 -Lang hi
.EXAMPLE
  .\build-worksheet.ps1 -Lang en
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z][A-Za-z0-9_-]*$')]
    [string]$Lang,

    [string]$Repo
)

$ErrorActionPreference = 'Stop'

# --- Resolve paths ---------------------------------------------------------
if ($Repo) {
    $i18nDir = Join-Path $Repo 'i18n'
} else {
    $i18nDir = $PSScriptRoot
}
$catalogPath = Join-Path $i18nDir 'prompts.catalog.json'
$outDir      = Join-Path $i18nDir 'translations'
$csvPath     = Join-Path $outDir ($Lang + '.csv')

if (-not (Test-Path -LiteralPath $catalogPath)) {
    throw "Catalog not found: $catalogPath"
}
if (-not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

# --- Load catalog ----------------------------------------------------------
$catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
$baseLang = [string]$catalog.base_language
if (-not $baseLang) { $baseLang = 'en' }
$prompts = @($catalog.prompts)
if ($prompts.Count -eq 0) {
    throw "Catalog contains no prompts: $catalogPath"
}

# --- Preserve any translations already entered (idempotency) ---------------
# Only real translation languages carry expert work worth preserving. The
# base-language reference file is always regenerated deterministically.
$preserve = @{}
if ($Lang -ne $baseLang -and (Test-Path -LiteralPath $csvPath)) {
    try {
        $existing = Import-Csv -LiteralPath $csvPath
        foreach ($row in $existing) {
            $names = $row.PSObject.Properties.Name
            if (($names -contains 'id') -and ($names -contains $Lang)) {
                $preserve[[string]$row.id] = [string]$row.$Lang
            }
        }
        Write-Verbose ("Preserving {0} existing row(s) from {1}" -f $preserve.Count, $csvPath)
    } catch {
        Write-Warning "Could not read existing CSV for preservation ($csvPath): $($_.Exception.Message)"
    }
}

# --- Helpers ---------------------------------------------------------------
function ConvertTo-CsvField {
    param([string]$Value)
    if ($null -eq $Value) { $Value = '' }
    # Always quote; escape embedded double quotes by doubling them.
    '"' + ($Value -replace '"', '""') + '"'
}

$WordToDigit = @{
    'zero' = '0'; 'one' = '1'; 'two' = '2'; 'three' = '3'; 'four' = '4';
    'five' = '5'; 'six' = '6'; 'seven' = '7'; 'eight' = '8'; 'nine' = '9'
}

function Get-PromptNotes {
    param($Prompt)

    $parts = New-Object System.Collections.Generic.List[string]
    $en = [string]$Prompt.en

    switch ([string]$Prompt.category) {
        'coach'    { $parts.Add('First-aid / crisis coaching: keep every step AND its order exactly. Do not add, drop, or reorder instructions - accuracy is safety-critical. Tone: calm, clear, unhurried.') }
        'flow'     { $parts.Add('Emergency call-flow line: calm, reassuring authority. Keep it short.') }
        'eas'      { $parts.Add('Mass emergency alert announcement: authoritative and clear, never panicked.') }
        'rollcall' { $parts.Add('Head-count / roll-call prompt: short and unambiguous.') }
        'paging'   { $parts.Add('Campus-wide paging announcement: authoritative and clear (same wording family as the alerts).') }
        'shift'    { $parts.Add('Responder shift-status prompt: neutral and clear.') }
        'system'   { $parts.Add('System status prompt: neutral, clear, brief.') }
        default    { $parts.Add('Emergency prompt: calm, clear, neutral.') }
    }

    # Press-a-key digits (numeric "press 1" and spelled "press one").
    $digits = New-Object System.Collections.Generic.List[string]
    $matches = [regex]::Matches($en, '(?i)press\s+([0-9]|zero|one|two|three|four|five|six|seven|eight|nine)')
    foreach ($m in $matches) {
        $tok = $m.Groups[1].Value.ToLower()
        if ($tok -match '^[0-9]$') { $d = $tok } else { $d = $WordToDigit[$tok] }
        if ($d -and -not $digits.Contains($d)) { $digits.Add($d) }
    }
    if ($digits.Count -gt 0) {
        $parts.Add('PRESS-A-KEY prompt. Keep the phone key(s) EXACTLY: ' + ($digits -join ', ') + '. The caller physically presses that key on the phone, so translate the word "press" but NEVER change or translate the number itself.')
    }

    # Star / feature codes (e.g. star two three -> *23).
    if ($en -match '(?i)\bstar\b') {
        $parts.Add('Contains a star / feature code (e.g. *23, *46): keep the digits exactly. Render "star" plus the digits the way your users dial them - see the guide.')
    }

    # Service brand name.
    if ($en -match 'UPES Emergency Alert Service') {
        $parts.Add('Keep "UPES Emergency Alert Service" as the recognisable service name - see the guide for how to render the brand + acronym.')
    }

    # Medical device term.
    if ($en -match '(?i)defibrillator') {
        $parts.Add('"defibrillator" (AED): use the locally understood term for the automatic shock device.')
    }

    # Length reminder for tight prompts.
    $maxS = 0; [void][int]::TryParse([string]$Prompt.max_seconds, [ref]$maxS)
    if ($maxS -gt 0 -and $maxS -le 8) {
        $parts.Add(('Very short prompt: keep spoken length under about {0}s.' -f $maxS))
    }

    return ($parts -join ' ')
}

# --- Build rows ------------------------------------------------------------
$headerCols = @('id', 'category', 'file', 'max_seconds', 'en', $Lang, 'notes')
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add((($headerCols | ForEach-Object { ConvertTo-CsvField $_ }) -join ','))

$count = 0
foreach ($p in $prompts) {
    $id = [string]$p.id
    $en = [string]$p.en

    if ($preserve.ContainsKey($id)) {
        $tr = $preserve[$id]
    } elseif ($Lang -eq $baseLang) {
        $tr = $en          # filled reference for the base language
    } else {
        $tr = ''           # empty for the expert to fill
    }

    $notes = Get-PromptNotes -Prompt $p

    $fields = @(
        $id,
        [string]$p.category,
        [string]$p.file,
        [string]$p.max_seconds,
        $en,
        $tr,
        $notes
    )
    $lines.Add((($fields | ForEach-Object { ConvertTo-CsvField $_ }) -join ','))
    $count++
}

# --- Write UTF-8 WITH BOM (Excel-friendly for non-Latin scripts) -----------
$content = ($lines -join "`r`n") + "`r`n"
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($csvPath, $content, $utf8Bom)

$preserved = $preserve.Count
Write-Host ("Wrote {0} ({1} prompt rows + header)." -f $csvPath, $count)
if ($preserved -gt 0) {
    Write-Host ("Preserved {0} existing '{1}' translation cell(s)." -f $preserved, $Lang)
}
