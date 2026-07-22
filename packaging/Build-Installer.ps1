<#
  Build-Installer.ps1 - packages the UPES-ECS deployment app into real Windows executables,
  then self-verifies the result is complete, robust, and airtight.

  Produces (in .\dist):
    stage\Deploy-UPES.exe   - the WinForms GUI compiled to a native exe (ps2exe)
    UPES-ECS-Setup.exe      - ONE self-extracting installer that bundles the whole payload
                              + Deploy-UPES.exe; double-click -> extracts -> launches the GUI.

  SECURITY: by default NO real secrets are packaged (pjsip_accounts.conf ships as a clean
  stub; credential CSVs are excluded). Pass -IncludeSecrets ONLY for a private same-org
  rebuild - it bakes your current SIP accounts into the installer.

  AFTER building, the script automatically:
    - verifies both exes are valid PE files (MZ header), non-empty, size-sane
    - scans the staged payload for secret-looking lines / credential files (clean build)
    - confirms app\ and secrets\ never made it into the payload
    - extracts the packaged payload and runs Install-UpesEcs.ps1 -DryRun end-to-end
      (proves the deploy logic is sound WITHOUT ever touching the live QEMU VM)
    - prints a PASS/FAIL summary and exits non-zero on any failure.

  Switches:
    -VerifyOnly            re-run ONLY the verification (+ dry-run) against an existing dist\
    -SkipGui              reuse the already-staged Deploy-UPES.exe (skip the ps2exe compile)
    -NoDryRun             skip the extracted-payload dry-run step (verification still runs)
    -IncludeSecrets       bake real SIP accounts in (private builds only)
    -Version 1.2.3        stamp the exe version
    -CertThumbprint <hex> Authenticode-sign Deploy-UPES.exe (before packaging) and
    -TimestampUrl <url>   UPES-ECS-Setup.exe (after packaging), then verify the signatures.

  Requires: ps2exe (auto-installed from PSGallery) + iexpress.exe (built into Windows).
  ASCII-only (Windows PowerShell 5.1). Every step is idempotent / re-runnable.
#>
[CmdletBinding()]
param(
  [switch]$IncludeSecrets,
  [string]$Version = '1.0.0',
  [switch]$VerifyOnly,
  [switch]$SkipGui,
  [switch]$NoDryRun,
  [string]$CertThumbprint,
  [string]$TimestampUrl = 'http://timestamp.digicert.com'
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Repo  = Split-Path -Parent $PSScriptRoot          # packaging\ -> repo root
$Out   = Join-Path $Repo 'dist'
$Stage = Join-Path $Out  'stage'                   # the payload tree (gets zipped)
$Pkg   = Join-Path $Out  '_pkg'                    # holds the 2 files IExpress bundles
$Gui   = Join-Path $Repo 'Deploy-UPES.ps1'
$GuiExe= Join-Path $Stage 'Deploy-UPES.exe'
$Setup = Join-Path $Out  'UPES-ECS-Setup.exe'
$Zip   = Join-Path $Pkg  'UPES-ECS-payload.zip'
$verQuad = ($Version.Split('.') + @('0','0','0','0'))[0..3] -join '.'

# size band for the self-extractor (MB). The payload is ~114 MB; keep a sane guard band.
$SetupMinMB = 60
$SetupMaxMB = 260
$GuiMaxMB   = 10                                    # the GUI exe is tiny (~0.05 MB)

$SecretRegex = '(password|secret)\s*=\s*[0-9a-f]{10,}'
$PayloadDirs = 'deploy','Console','i18n','api','scripts','config','provisioning'

function Say ($m){ Write-Host ("[build]  " + $m) -ForegroundColor Cyan }
function Warn($m){ Write-Host ("[warn]   " + $m) -ForegroundColor Yellow }
function Ok  ($m){ Write-Host ("[ok]     " + $m) -ForegroundColor Green }
function Bad ($m){ Write-Host ("[FAIL]   " + $m) -ForegroundColor Red }

# ===========================================================================
# helpers
# ===========================================================================
function Test-PeHeader([string]$path){
  # true if the file starts with the 'MZ' DOS/PE magic.
  if (-not (Test-Path $path)) { return $false }
  try {
    $fs = [IO.File]::OpenRead($path)
    try { $b = New-Object byte[] 2; [void]$fs.Read($b,0,2) } finally { $fs.Dispose() }
    return ($b[0] -eq 0x4D -and $b[1] -eq 0x5A)
  } catch { return $false }
}

function Get-SizeMB([string]$path){ [math]::Round((Get-Item $path).Length/1MB,2) }

function Sign-File([string]$path,[string]$what){
  if (-not $CertThumbprint) { return }
  Say ("code-signing {0}: {1}" -f $what, (Split-Path $path -Leaf))
  $cert = Get-ChildItem "Cert:\CurrentUser\My\$CertThumbprint","Cert:\LocalMachine\My\$CertThumbprint" -EA SilentlyContinue | Select-Object -First 1
  if (-not $cert) { throw "code-signing cert with thumbprint '$CertThumbprint' not found in CurrentUser\My or LocalMachine\My." }
  $r = Set-AuthenticodeSignature -FilePath $path -Certificate $cert -TimestampServer $TimestampUrl -HashAlgorithm SHA256
  if ($r.Status -ne 'Valid') { throw ("signing {0} failed: {1} - {2}" -f $what, $r.Status, $r.StatusMessage) }
  Ok ("signed + verified {0} (status={1})" -f $what, $r.Status)
}

# ===========================================================================
# VERIFY - the airtight self-check. Returns $true (pass) / $false (fail).
# ===========================================================================
function Invoke-Verify([bool]$secretsBaked){
  Write-Host ''
  Write-Host '============================================================' -ForegroundColor Cyan
  Write-Host ' VERIFY - proving the Windows build is airtight' -ForegroundColor Cyan
  Write-Host '============================================================' -ForegroundColor Cyan
  $fails = New-Object System.Collections.Generic.List[string]
  function Check([string]$name,[bool]$cond,[string]$detail){
    if ($cond) { Ok ("{0}  {1}" -f $name, $detail) }
    else { Bad ("{0}  {1}" -f $name, $detail); $fails.Add($name) }
  }

  # --- 1. staged tree exists -----------------------------------------------
  Check 'stage-tree-present'  (Test-Path $Stage) "staged payload at $Stage"
  Check 'gui-exe-present'     (Test-Path $GuiExe) "Deploy-UPES.exe present"
  Check 'setup-exe-present'   (Test-Path $Setup)  "UPES-ECS-Setup.exe present"
  if (-not (Test-Path $Stage) -or -not (Test-Path $GuiExe) -or -not (Test-Path $Setup)) {
    Bad 'cannot continue verification - core artifacts missing (build first).'
    return $false
  }

  # --- 2. PE headers + sizes -----------------------------------------------
  Check 'gui-exe-mz'      (Test-PeHeader $GuiExe) "Deploy-UPES.exe has MZ PE header"
  Check 'setup-exe-mz'    (Test-PeHeader $Setup)  "UPES-ECS-Setup.exe has MZ PE header"
  $guiMB   = Get-SizeMB $GuiExe
  $setupMB = Get-SizeMB $Setup
  Check 'gui-exe-nonzero' ((Get-Item $GuiExe).Length -gt 0 -and $guiMB -le $GuiMaxMB) ("Deploy-UPES.exe = $guiMB MB (>0, <= $GuiMaxMB)")
  Check 'setup-exe-band'  ($setupMB -ge $SetupMinMB -and $setupMB -le $SetupMaxMB) ("UPES-ECS-Setup.exe = $setupMB MB (band $SetupMinMB-$SetupMaxMB)")

  # --- 3. no app\ / secrets\ in the payload --------------------------------
  Check 'no-app-dir'      (-not (Test-Path (Join-Path $Stage 'app')))     "app\ absent from payload"
  Check 'no-secrets-dir'  (-not (Test-Path (Join-Path $Stage 'secrets'))) "secrets\ absent from payload"
  $straySecrets = @(Get-ChildItem $Stage -Recurse -Directory -Filter 'secrets' -EA SilentlyContinue)
  Check 'no-nested-secrets' ($straySecrets.Count -eq 0) "no nested 'secrets' directory anywhere in payload"

  # --- 4. no credential files ----------------------------------------------
  $credFiles = @(Get-ChildItem $Stage -Recurse -File -EA SilentlyContinue |
                 Where-Object { $_.Name -like '*.filled.csv' -or $_.Name -like '*users*.csv' -or $_.Name -eq 'TEAM-CREDENTIALS.md' })
  Check 'no-cred-files' ($credFiles.Count -eq 0) ("credential files stripped (found: " + ($(if($credFiles){($credFiles|ForEach-Object{$_.Name}) -join ', '}else{'none'})) + ")")

  # --- 5. accounts file is the clean stub (clean build only) ---------------
  $acct = Join-Path $Stage 'deploy\asterisk\pjsip_accounts.conf'
  if (-not $secretsBaked) {
    if (Test-Path $acct) {
      $acctTxt = [IO.File]::ReadAllText($acct)
      Check 'accounts-is-stub' ($acctTxt -match 'ships EMPTY of accounts') "pjsip_accounts.conf is the clean stub"
      Check 'accounts-no-secret' (-not ($acctTxt -match $SecretRegex)) "pjsip_accounts.conf has no secret-looking lines"
    } else {
      Check 'accounts-present' $false "pjsip_accounts.conf missing from payload"
    }

    # --- 6. whole-tree secret scan (text-ish files only) -------------------
    Say 'scanning staged tree for secret-looking lines...'
    $textExt = @('.conf','.cfg','.ini','.csv','.md','.txt','.json','.ps1','.psm1','.sh','.py','.yaml','.yml','.env','.xml','.js','.html','.htm','.cmd','.bat')
    $scan = @(Get-ChildItem $Stage -Recurse -File -EA SilentlyContinue |
              Where-Object { $textExt -contains $_.Extension.ToLower() -or $_.Extension -eq '' })
    $hits = @($scan | Select-String -Pattern $SecretRegex -EA SilentlyContinue)
    if ($hits.Count -gt 0) {
      foreach ($h in ($hits | Select-Object -First 8)) { Bad ("  secret-looking: {0}:{1}" -f $h.Path, $h.LineNumber) }
    }
    Check 'no-secret-lines' ($hits.Count -eq 0) ("scanned $($scan.Count) text files, $($hits.Count) secret-looking line(s)")
  } else {
    Warn 'IncludeSecrets build -> secret-scan assertions intentionally skipped (real accounts are expected).'
  }

  # --- 7. payload completeness (functional dirs are present) ---------------
  foreach ($d in $PayloadDirs) {
    if (Test-Path (Join-Path $Repo $d)) {
      Check ("payload-has-$d") (Test-Path (Join-Path $Stage $d)) "$d\ staged"
    }
  }
  Check 'payload-has-installer' (Test-Path (Join-Path $Stage 'Install-UpesEcs.ps1')) "Install-UpesEcs.ps1 staged"

  # --- summary --------------------------------------------------------------
  Write-Host ''
  if ($fails.Count -eq 0) {
    Write-Host '  VERIFY: PASS - all checks green.' -ForegroundColor Green
    return $true
  } else {
    Write-Host ("  VERIFY: FAIL - {0} check(s) failed: {1}" -f $fails.Count, ($fails -join ', ')) -ForegroundColor Red
    return $false
  }
}

# ===========================================================================
# DRY-RUN - extract the PACKAGED payload and run the real deploy path with
# -DryRun. Proves the end-to-end deploy logic exits 0 WITHOUT touching the VM.
# ===========================================================================
function Invoke-DryRun {
  Write-Host ''
  Write-Host '============================================================' -ForegroundColor Cyan
  Write-Host ' DRY-RUN - validating the packaged deploy path (no VM touched)' -ForegroundColor Cyan
  Write-Host '============================================================' -ForegroundColor Cyan
  if (-not (Test-Path $Zip)) { Bad "payload zip not found ($Zip) - cannot dry-run the packaged payload."; return $false }

  $ex = Join-Path $Out '_verify'
  if (Test-Path $ex) { Remove-Item $ex -Recurse -Force }
  New-Item -ItemType Directory -Force $ex | Out-Null
  Say "extracting packaged payload -> $ex"
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  [System.IO.Compression.ZipFile]::ExtractToDirectory($Zip, $ex)

  $inst = Join-Path $ex 'Install-UpesEcs.ps1'
  if (-not (Test-Path $inst)) { Bad "extracted payload has no Install-UpesEcs.ps1"; return $false }

  $ok = $true
  foreach ($lang in @('en','hi')) {
    Say "running: Install-UpesEcs.ps1 -DryRun -Language $lang   (extracted packaged copy)"
    $log = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $inst -DryRun -Language $lang 2>&1
    $code = $LASTEXITCODE
    $log | ForEach-Object { Write-Host ("    | " + $_) }
    if ($code -eq 0) { Ok ("dry-run (-Language $lang) exited 0") }
    else { Bad ("dry-run (-Language $lang) exited $code"); $ok = $false }
  }
  # cleanup the throwaway extraction
  Remove-Item $ex -Recurse -Force -EA SilentlyContinue
  Write-Host ''
  if ($ok) { Write-Host '  DRY-RUN: PASS - packaged deploy logic is sound (exit 0).' -ForegroundColor Green }
  else     { Write-Host '  DRY-RUN: FAIL - see output above.' -ForegroundColor Red }
  return $ok
}

# ===========================================================================
# VERIFY-ONLY short-circuit
# ===========================================================================
if ($VerifyOnly) {
  Say 'VerifyOnly - checking the existing dist\ (no rebuild).'
  $vp = Invoke-Verify -secretsBaked:$IncludeSecrets
  $dp = $true
  if (-not $NoDryRun) { $dp = Invoke-DryRun }
  if ($vp -and $dp) { Ok 'VerifyOnly complete: PASS.'; exit 0 } else { Bad 'VerifyOnly complete: FAIL.'; exit 1 }
}

# ===========================================================================
# 0. PREFLIGHT - tools, disk, payload dirs
# ===========================================================================
Say 'preflight...'
# ps2exe (only needed if we are actually compiling)
if (-not $SkipGui) {
  if (-not (Get-Module -ListAvailable ps2exe)) {
    Say 'installing ps2exe from PSGallery...'
    if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
      Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force | Out-Null
    }
    Install-Module ps2exe -Scope CurrentUser -Force -AllowClobber
  }
  Import-Module ps2exe -Force
  if (-not (Get-Command Invoke-ps2exe -EA SilentlyContinue)) { throw 'ps2exe imported but Invoke-ps2exe is unavailable.' }
  Ok 'ps2exe ready'
} else {
  if (-not (Test-Path $GuiExe)) { throw "-SkipGui set but $GuiExe does not exist yet - run a full build once first." }
  Ok "SkipGui - reusing existing Deploy-UPES.exe"
}
# iexpress
$iexpress = Join-Path $env:WINDIR 'System32\iexpress.exe'
if (-not (Test-Path $iexpress)) { throw "iexpress.exe not found ($iexpress) - cannot build the self-extractor." }
Ok 'iexpress present'
# disk space (need room for stage copy + zip + setup; require ~1 GB free)
try {
  $drv = (Get-Item $Repo).PSDrive
  $freeGB = [math]::Round($drv.Free/1GB,1)
  if ($freeGB -lt 1) { throw "only $freeGB GB free on $($drv.Name): - need at least 1 GB to build." }
  Ok ("disk: {0} GB free on {1}:" -f $freeGB, $drv.Name)
} catch { Warn ("disk-space check skipped: " + $_.Exception.Message) }
# payload dirs
$haveDirs = @()
foreach ($d in $PayloadDirs) { if (Test-Path (Join-Path $Repo $d)) { $haveDirs += $d } }
if ($haveDirs.Count -eq 0) { throw "no payload directories found under $Repo - are you in the repo root?" }
if (-not (Test-Path $Gui)) { throw "Deploy-UPES.ps1 not found at $Gui" }
if (-not (Test-Path (Join-Path $Repo 'Install-UpesEcs.ps1'))) { throw 'Install-UpesEcs.ps1 not found in repo root.' }
Ok ("payload dirs: " + ($haveDirs -join ', '))

# ===========================================================================
# 1. clean output (idempotent)
# ===========================================================================
foreach ($d in @($Stage,$Pkg)) { if (Test-Path $d) { Remove-Item $d -Recurse -Force } }
New-Item -ItemType Directory -Force -Path $Stage,$Pkg | Out-Null

# ===========================================================================
# 2. compile the GUI -> Deploy-UPES.exe
# ===========================================================================
if (-not $SkipGui) {
  Say 'compiling Deploy-UPES.ps1 -> Deploy-UPES.exe'
  Invoke-ps2exe -inputFile $Gui -outputFile $GuiExe `
    -noConsole -title 'UPES-ECS Deployment' -description 'UPES-ECS campus emergency PBX - deployment' `
    -company 'UPES-ECS' -product 'UPES-ECS' -version $verQuad -copyright 'UPES-ECS' | Out-Null
  if (-not (Test-Path $GuiExe)) { throw 'ps2exe did not produce Deploy-UPES.exe' }
  if (-not (Test-PeHeader $GuiExe)) { throw 'ps2exe produced a file without an MZ header - compile is corrupt.' }
  Ok 'Deploy-UPES.exe compiled (valid PE)'
}

# ===========================================================================
# 3. stage the payload (preserve layout)
# ===========================================================================
foreach ($d in $haveDirs) {
  $srcD = Join-Path $Repo $d
  Say "staging $d\"
  # /E all subdirs, exclude filled + user credential CSVs + junk dirs; quiet output
  robocopy $srcD (Join-Path $Stage $d) /E /XF *.filled.csv *users*.csv /XD node_modules .git __pycache__ secrets `
    /NFL /NDL /NJH /NJS /NP /R:1 /W:1 | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "robocopy failed for $d (exit $LASTEXITCODE)" }
}
$rootFiles = 'Install-UpesEcs.ps1','Deploy-UPES.ps1','Deploy-UPES.cmd','README.md',
             'CHANGELOG.md','setup.sh'
foreach ($f in $rootFiles) {
  $srcF = Join-Path $Repo $f
  if (Test-Path $srcF) { Copy-Item $srcF (Join-Path $Stage $f) -Force }
}

# ===========================================================================
# 4. strip secrets (default)
# ===========================================================================
if (-not $IncludeSecrets) {
  Say 'sanitizing: removing real secrets from the package'
  $acct = Join-Path $Stage 'deploy\asterisk\pjsip_accounts.conf'
  if (Test-Path $acct) {
    $stub = @(
      '; UPES-ECS PJSIP accounts - SOURCE OF TRUTH'
      '; This PACKAGED copy ships EMPTY of accounts (no SIP secrets in the installer).'
      '; Add users AFTER install, one command each (pins the secret once, syncs everything):'
      ';   powershell -File deploy\qemu\Add-UpesUser.ps1 -SapId <id> -Name "<full name>"'
      ''
    ) -join "`r`n"
    [IO.File]::WriteAllText($acct, $stub, (New-Object Text.UTF8Encoding($false)))
  }
  # nuke any lingering credential material anywhere in the staged tree (matches the verifier)
  Get-ChildItem $Stage -Recurse -File -EA SilentlyContinue |
    Where-Object { $_.Name -like '*.filled.csv' -or $_.Name -like '*users*.csv' -or $_.Name -eq 'TEAM-CREDENTIALS.md' } |
    Remove-Item -Force -EA SilentlyContinue
} else {
  Warn '-IncludeSecrets set - real SIP accounts WILL be baked into the installer (private use only)'
}

# ===========================================================================
# 4b. sign the GUI exe BEFORE it goes into the zip (optional)
# ===========================================================================
Sign-File $GuiExe 'Deploy-UPES.exe'

# ===========================================================================
# 5. zip the payload
# ===========================================================================
Say 'zipping payload...'
if (Test-Path $Zip) { Remove-Item $Zip -Force }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($Stage, $Zip)   # faster than Compress-Archive for many files
Say ("payload.zip = {0} MB" -f (Get-SizeMB $Zip))

# ===========================================================================
# 6. bootstrap the Setup.exe runs after extraction
# ===========================================================================
$boot = @'
$ErrorActionPreference = 'Stop'
$src  = Split-Path -Parent $MyInvocation.MyCommand.Path
$dest = Join-Path $env:LOCALAPPDATA 'Programs\UPES-ECS'
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
# overwrite-safe extract
Get-ChildItem $dest -Force -EA SilentlyContinue | Remove-Item -Recurse -Force -EA SilentlyContinue
[System.IO.Compression.ZipFile]::ExtractToDirectory((Join-Path $src 'UPES-ECS-payload.zip'), $dest)
# desktop shortcut
try {
  $ws  = New-Object -ComObject WScript.Shell
  $lnk = $ws.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'UPES-ECS Deploy.lnk'))
  $lnk.TargetPath = (Join-Path $dest 'Deploy-UPES.exe'); $lnk.WorkingDirectory = $dest; $lnk.Save()
} catch {}
Start-Process (Join-Path $dest 'Deploy-UPES.exe')
'@
$bootPath = Join-Path $Pkg 'bootstrap.ps1'
[IO.File]::WriteAllText($bootPath, $boot, (New-Object Text.UTF8Encoding($false)))

# ===========================================================================
# 7. IExpress -> single self-extracting Setup.exe
# ===========================================================================
if (Test-Path $Setup) { Remove-Item $Setup -Force }
$sed = Join-Path $Pkg 'UPES-ECS.sed'
$launch = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File bootstrap.ps1'
$sedTxt = @"
[Version]
Class=IEXPRESS
SEDVersion=3
[Options]
PackagePurpose=InstallApp
ShowInstallProgramWindow=0
HideExtractAnimation=1
UseLongFileName=1
InsideCompressed=0
CAB_FixedSize=0
CAB_ResvCodeSigning=0
RebootMode=N
InstallPrompt=%InstallPrompt%
DisplayLicense=%DisplayLicense%
FinishMessage=%FinishMessage%
TargetName=%TargetName%
FriendlyName=%FriendlyName%
AppLaunched=%AppLaunched%
PostInstallCmd=%PostInstallCmd%
AdminQuietInstCmd=%AdminQuietInstCmd%
UserQuietInstCmd=%UserQuietInstCmd%
SourceFiles=SourceFiles
[Strings]
InstallPrompt=
DisplayLicense=
FinishMessage=
TargetName=$Setup
FriendlyName=UPES-ECS Setup
AppLaunched=$launch
PostInstallCmd=<None>
AdminQuietInstCmd=
UserQuietInstCmd=
FILE0="bootstrap.ps1"
FILE1="UPES-ECS-payload.zip"
[SourceFiles]
SourceFiles0=$Pkg
[SourceFiles0]
%FILE0%=
%FILE1%=
"@
[IO.File]::WriteAllText($sed, $sedTxt, (New-Object Text.ASCIIEncoding))
Say 'running IExpress...'
& $iexpress /N /Q $sed | Out-Null
if (-not (Test-Path $Setup)) { throw 'IExpress did not produce UPES-ECS-Setup.exe' }

# ===========================================================================
# 7b. sign the Setup.exe AFTER packaging (optional) + SmartScreen note
# ===========================================================================
if ($CertThumbprint) {
  Sign-File $Setup 'UPES-ECS-Setup.exe'
} else {
  Warn 'not code-signed -> SmartScreen may warn on first run ("More info -> Run anyway").'
  Warn 'for a signed build pass -CertThumbprint <hex> [-TimestampUrl <url>].'
}

# ===========================================================================
# 8. build report
# ===========================================================================
Write-Host ''
Say 'BUILD DONE.'
Write-Host ("  {0}  ({1} MB)  - native GUI exe" -f $GuiExe, (Get-SizeMB $GuiExe))
Write-Host ("  {0}  ({1} MB)  - single self-extracting installer" -f $Setup, (Get-SizeMB $Setup))
Write-Host ("  secrets in package : {0}" -f $(if($IncludeSecrets){'YES (private build)'}else{'NO (clean)'}))
Write-Host ("  code-signed        : {0}" -f $(if($CertThumbprint){'YES'}else{'NO (SmartScreen note above)'}))

# ===========================================================================
# 9. AUTO SELF-VERIFY + DRY-RUN (fail loudly)
# ===========================================================================
$verifyPass = Invoke-Verify -secretsBaked:$IncludeSecrets
$dryPass = $true
if (-not $NoDryRun) { $dryPass = Invoke-DryRun } else { Warn 'NoDryRun - skipped the extracted-payload dry-run.' }

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
if ($verifyPass -and $dryPass) {
  Write-Host ' RESULT: PASS - the Windows build is complete and airtight.' -ForegroundColor Green
  Write-Host '============================================================' -ForegroundColor Cyan
  exit 0
} else {
  Write-Host ' RESULT: FAIL - see the failed checks above.' -ForegroundColor Red
  Write-Host '============================================================' -ForegroundColor Cyan
  exit 1
}
