<#
  UPES-ECS - HOST-SIDE multi-language prompt generation (Windows) .

  Generates the full 41-prompt audio pack for ONE language into
      deploy/asterisk/sounds/lang/<lang>/<file>
  mirroring the English layout in  deploy/asterisk/sounds/en/<file>.

  Same rationale as gen-coach-prompts.win.ps1 / gen-rest-prompts.win.ps1:
  synthesize on the laptop's native CPU (fast), 22.05 kHz mono WAV; the VM-side
  deploy step downsamples to Asterisk's 8 kHz with sox.

  Engine per language (from i18n/languages.json):
    - Piper neural TTS  when the language has a piper_voice model available.
    - eSpeak-NG (-v <espeak_lang>)  fallback, fully offline, no model download.

  Text source per language:
    - en   : the "en" field of i18n/prompts.catalog.json (base language).
    - other: i18n/translations/<lang>.csv , matched by the "id" column,
             read as UTF-8 so Devanagari (and other scripts) load correctly.

  This file is intentionally ASCII-only: PowerShell 5.1 mis-parses non-ASCII
  bytes in a no-BOM .ps1. All translated text is read from UTF-8 data files at
  run time and handed to the TTS engine as UTF-8, never embedded in the script.

  Usage (PowerShell 5.1):
    # Dry run - lists every prompt, its output file, engine and text length.
    # Works WITHOUT Piper/eSpeak installed (no TTS is invoked):
    powershell -ExecutionPolicy Bypass -File scripts\gen-lang-prompts.win.ps1 -Lang en -WhatIf

    # Real generation (English):
    powershell -ExecutionPolicy Bypass -File scripts\gen-lang-prompts.win.ps1 -Lang en

    # Real generation (Hindi) - download the Piper model + its .onnx.json first
    # (see i18n/TTS-VOICES.md):
    powershell -ExecutionPolicy Bypass -File scripts\gen-lang-prompts.win.ps1 -Lang hi `
        -Model C:\Users\Rohan\piper-model\hi_IN-pratham-medium.onnx
#>
param(
  [Parameter(Mandatory=$true)]
  [string]$Lang,

  [string]$PiperExe  = "$env:USERPROFILE\piper-win\piper\piper.exe",

  # Explicit Piper .onnx model. If omitted it is resolved from languages.json
  # (piper_voice) and looked up under -ModelDir.
  [string]$Model     = "",

  [string]$ModelDir  = "C:\Users\Rohan\piper-model",

  # eSpeak-NG executable (used only when no Piper model is available).
  [string]$EspeakExe = "espeak-ng.exe",

  # Default resolves to deploy/asterisk/sounds/lang/<lang> under the repo root.
  [string]$OutDir    = "",

  [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

# ---- locate repo root + data files (script lives in <repo>\scripts) ----------
$RepoRoot = Split-Path $PSScriptRoot -Parent
$CatalogPath   = Join-Path $RepoRoot 'i18n\prompts.catalog.json'
$LanguagesPath = Join-Path $RepoRoot 'i18n\languages.json'

if (-not (Test-Path $CatalogPath))   { throw "catalog not found at $CatalogPath" }
if (-not (Test-Path $LanguagesPath)) { throw "languages.json not found at $LanguagesPath" }

if ([string]::IsNullOrWhiteSpace($OutDir)) {
  $OutDir = Join-Path $RepoRoot ("deploy\asterisk\sounds\lang\{0}" -f $Lang)
}

# ---- read catalog + language definition (UTF-8) ------------------------------
$catalog   = Get-Content -Raw -Encoding UTF8 $CatalogPath   | ConvertFrom-Json
$languages = Get-Content -Raw -Encoding UTF8 $LanguagesPath | ConvertFrom-Json

$langDef = $languages.languages | Where-Object { $_.code -eq $Lang } | Select-Object -First 1
if (-not $langDef) { throw "language '$Lang' is not defined in $LanguagesPath" }

$piperVoice = "$($langDef.piper_voice)"   # "" when null (avoids PS 5.1 null trap)
$espeakLang = "$($langDef.espeak_lang)"
if ([string]::IsNullOrWhiteSpace($espeakLang)) { $espeakLang = $Lang }

# ---- decide the engine (configuration-driven, install-independent) -----------
# Piper is used when an explicit -Model is given OR the language has a
# piper_voice configured; otherwise fall back to eSpeak-NG.
$engine = 'espeak'
if (-not [string]::IsNullOrWhiteSpace($Model)) {
  $engine = 'piper'
} elseif (-not [string]::IsNullOrWhiteSpace($piperVoice)) {
  $engine = 'piper'
  $Model  = Join-Path $ModelDir ("{0}.onnx" -f $piperVoice)
}

# ---- build the text map for this language ------------------------------------
# $textFor[id] = the string to synthesize (may be empty -> skipped).
$textFor = @{}
if ($Lang -eq $catalog.base_language) {
  foreach ($p in $catalog.prompts) { $textFor[$p.id] = "$($p.en)" }
} else {
  $csvPath = Join-Path $RepoRoot ("i18n\translations\{0}.csv" -f $Lang)
  if (-not (Test-Path $csvPath)) {
    throw "translation CSV not found at $csvPath (needed for language '$Lang')"
  }
  # Read POSITIONALLY: id = column 0, translation = column 5 (id,category,file,max_seconds,en,<code>,notes).
  # This avoids the duplicate-header trap that breaks Import-Csv's $r.$Lang when the language code
  # collides with a base column name (e.g. 'id' Indonesian vs the prompt 'id' column, or 'en'), and
  # correctly handles quoted commas inside the translated text.
  Add-Type -AssemblyName Microsoft.VisualBasic
  $tp = New-Object Microsoft.VisualBasic.FileIO.TextFieldParser($csvPath, [Text.Encoding]::UTF8)
  try {
    $tp.TextFieldType = [Microsoft.VisualBasic.FileIO.FieldType]::Delimited
    $tp.SetDelimiters(',')
    $tp.HasFieldsEnclosedInQuotes = $true
    $first = $true
    while (-not $tp.EndOfData) {
      $fields = $tp.ReadFields()
      if ($first) { $first = $false; continue }          # skip header row
      if ($fields.Count -lt 6) { continue }
      $id = "$($fields[0])".Trim()
      if (-not [string]::IsNullOrWhiteSpace($id)) { $textFor[$id] = "$($fields[5])" }
    }
  } finally { $tp.Close() }
}

# ---- plan every prompt -------------------------------------------------------
$plan = @()
foreach ($p in $catalog.prompts) {
  $raw  = ''
  if ($textFor.ContainsKey($p.id)) { $raw = "$($textFor[$p.id])" }
  $text = $raw.Trim()
  $relFile = ($p.file -replace '/', '\')
  $outPath = Join-Path $OutDir $relFile
  $plan += [pscustomobject]@{
    Id      = $p.id
    File    = $p.file
    OutPath = $outPath
    Engine  = $engine
    Text    = $text
    Len     = $text.Length
    Skip    = [string]::IsNullOrWhiteSpace($text)
  }
}

$toDo    = @($plan | Where-Object { -not $_.Skip })
$skipped = @($plan | Where-Object {      $_.Skip })

# ---- WhatIf: list the plan, invoke no TTS ------------------------------------
if ($WhatIf) {
  Write-Host ("WhatIf  lang={0}  engine={1}  out={2}" -f $Lang, $engine, $OutDir)
  if ($engine -eq 'piper') {
    Write-Host ("        model={0}" -f $Model)
  } else {
    Write-Host ("        espeak voice=-v {0}" -f $espeakLang)
  }
  Write-Host ""
  Write-Host ("{0,-4} {1,-34} {2,-40} {3,-7} {4,5}  {5}" -f '#','id','file','engine','chars','status')
  $i = 0
  foreach ($e in $plan) {
    $i++
    $status = if ($e.Skip) { 'SKIP (empty)' } else { 'would generate' }
    Write-Host ("{0,-4} {1,-34} {2,-40} {3,-7} {4,5}  {5}" -f $i, $e.Id, $e.File, $e.Engine, $e.Len, $status)
  }
  Write-Host ""
  Write-Host ("Summary: {0} of {1} prompts would be generated with '{2}', {3} skipped (empty translation)." -f `
              $toDo.Count, $plan.Count, $engine, $skipped.Count)
  if ($skipped.Count -gt 0) {
    Write-Host ("Skipped ids: {0}" -f (($skipped | ForEach-Object { $_.Id }) -join ', '))
  }
  Write-Host "WhatIf: no audio was generated."
  return
}

# ---- real generation: validate tooling ---------------------------------------
if ($engine -eq 'piper') {
  if (-not (Test-Path $PiperExe)) { throw "piper.exe not found at $PiperExe" }
  if (-not (Test-Path $Model))    { throw "Piper model not found at $Model (see i18n/TTS-VOICES.md for the download)" }
  $piperDir = Split-Path $PiperExe -Parent   # so espeak-ng-data (phonemizer) is found next to the exe
} else {
  $espeakCmd = Get-Command $EspeakExe -ErrorAction SilentlyContinue
  if (-not $espeakCmd) { throw "espeak-ng not found ('$EspeakExe'); install eSpeak-NG or pass -EspeakExe" }
}

# Ensure translated (non-ASCII) text reaches the native TTS process as UTF-8.
$prevOutputEncoding = $OutputEncoding
$OutputEncoding = New-Object System.Text.UTF8Encoding($false)

$generated = 0
$tmpTxt = $null
if ($engine -eq 'piper') { Push-Location $piperDir }
try {
  $i = 0
  foreach ($e in $toDo) {
    $i++
    New-Item -ItemType Directory -Force -Path (Split-Path $e.OutPath -Parent) | Out-Null
    Write-Host ("[{0,2}/{1}] {2} -> {3}" -f $i, $toDo.Count, $e.Id, $e.File)

    if ($engine -eq 'piper') {
      $e.Text | & $PiperExe --model $Model --output_file $e.OutPath
    } else {
      # Pass text via a UTF-8 temp file (-f) to avoid command-line arg mangling.
      $tmpTxt = [System.IO.Path]::GetTempFileName()
      [System.IO.File]::WriteAllText($tmpTxt, $e.Text, (New-Object System.Text.UTF8Encoding($false)))
      & $EspeakExe -v $espeakLang -f $tmpTxt -w $e.OutPath | Out-Null
      Remove-Item $tmpTxt -Force -ErrorAction SilentlyContinue
      $tmpTxt = $null
    }

    if (-not (Test-Path $e.OutPath)) { throw "TTS produced no file for $($e.Id)" }
    $generated++
  }
} finally {
  if ($engine -eq 'piper') { Pop-Location }
  if ($tmpTxt -and (Test-Path $tmpTxt)) { Remove-Item $tmpTxt -Force -ErrorAction SilentlyContinue }
  $OutputEncoding = $prevOutputEncoding
}

Write-Host ""
Write-Host ("DONE lang={0}: {1} generated, {2} skipped (empty translation), engine={3}." -f `
            $Lang, $generated, $skipped.Count, $engine)
Write-Host ("Output: {0}  (22.05 kHz mono - the VM deploy step downsamples to 8 kHz)." -f $OutDir)
if ($skipped.Count -gt 0) {
  Write-Host ("Skipped ids: {0}" -f (($skipped | ForEach-Object { $_.Id }) -join ', '))
}
