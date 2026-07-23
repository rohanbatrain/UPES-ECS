<#
  UPES-ECS Deployment - friendly WinForms front end.

  The ONE thing a non-technical operator runs (via Deploy-UPES.cmd):
    1. pick a Region / language
    2. (optional) tick "Fetch latest before deploying" + paste a source URL/path
    3. click Deploy

  It just shells out to Install-UpesEcs.ps1 -Language <code> [-Source <url|path>] and
  streams the output into a live log. Needs no admin (the installer self-elevates only
  for the one-time prerequisite/firewall step).

  ASCII-only source (Windows PowerShell 5.1 requirement).
#>
[CmdletBinding()]
param(
  # Operator UI language override (two-letter code, e.g. en, hi, fr).
  # If omitted, the UI follows the Windows display language (CurrentUICulture),
  # falling back to English for any unknown culture or missing string.
  [string]$Language
)
$ErrorActionPreference = 'Stop'
# Resolve our own folder whether we run as a .ps1 (PSScriptRoot) or as a compiled
# .exe (ps2exe leaves PSScriptRoot/MyInvocation empty -> use the running module path).
$here =
  if ($PSScriptRoot) { $PSScriptRoot }
  elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
  else { Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) }
$install = Join-Path $here 'Install-UpesEcs.ps1'
$langs   = Join-Path $here 'i18n\languages.json'
$guiDir  = Join-Path $here 'i18n\gui'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# --- load languages (native (name)) with a safe English fallback ------------
function Get-Languages {
  $default = 'en'
  $list = @()
  try {
    if (Test-Path $langs) {
      $j = [IO.File]::ReadAllText($langs) | ConvertFrom-Json   # UTF-8 (Get-Content would mojibake natives)
      if ($j.default) { $default = "$($j.default)" }
      foreach ($e in $j.languages) {
        $native = if ($e.native) { "$($e.native)" } else { "$($e.name)" }
        $label  = if ("$($e.name)" -and "$($e.name)" -ne $native) { "$native ($($e.name))" } else { $native }
        $list += [pscustomobject]@{ Code = "$($e.code)"; Label = $label; Status = "$($e.status)" }
      }
    }
  } catch { }
  if ($list.Count -eq 0) { $list = @([pscustomobject]@{ Code = 'en'; Label = 'English'; Status = 'shipped' }) }
  return New-Object psobject -Property @{ Default = $default; List = @($list) }
}
$lang = Get-Languages

# --- operator UI language (strings + RTL) -----------------------------------
# The installer VOICE language is chosen in the combo box below; this block is
# the separate OPERATOR UI language (labels/buttons/messages of THIS window).
# Priority: -Language override -> Windows CurrentUICulture -> English fallback.

# English catalog is embedded inline (ASCII-only, PS 5.1 safe) so the UI always
# works even if the i18n\gui folder is missing. Non-ASCII translations live in
# UTF-8 JSON files under i18n\gui\<code>.json and are overlaid on top.
$T = @{
  title_window           = 'UPES-ECS Deployment'
  title_heading          = 'UPES-ECS - campus emergency PBX'
  subtitle               = 'Pick a language, then click Deploy. That is all.'
  lbl_region             = 'Region / language:'
  chk_fetch              = 'Fetch latest before deploying (advanced)'
  lbl_source             = 'Source (URL, .zip, or folder):'
  btn_deploy             = 'Deploy'
  status_ready           = 'Ready.'
  status_done            = 'Done.'
  status_deploying       = 'Deploying... (this can take several minutes on first run)'
  status_failed          = 'Failed (exit {0}).'
  status_could_not_start = 'Could not start.'
  sum_deployed           = '  UPES-ECS is deployed.'
  sum_phones             = '  Phones register to : {0}:5060   (UDP)'
  sum_emergency          = '  Emergency number   : dial 111'
  sum_console            = '  Operations Console : http://localhost:8080'
  msg_ok_body            = "UPES-ECS is up.`n`nPhones register to  {0}:5060`nEmergency number    dial 111`nConsole             http://localhost:8080"
  msg_ok_title           = 'Deployment complete'
  msg_fail_body          = "Deployment did not finish (exit code {0}).`n`nRead the log for the last error line, fix it, and click Deploy again."
  msg_fail_title         = 'Deployment failed'
  msg_noinstall_body     = "Install-UpesEcs.ps1 was not found next to this tool.`nExpected: {0}`n`nRun Deploy-UPES from inside the UPES-ECS folder."
  msg_noinstall_title    = 'Cannot deploy'
  msg_nosource_body      = 'Tick is on but no Source is set. Enter a URL, a .zip, or a folder - or untick to deploy the built-in copy.'
  msg_nosource_title     = 'Source needed'
  log_deploying          = "=> deploying language '{0}'"
  log_from_source        = " from source '{0}'"
  log_command            = '=> command: powershell {0}'
  log_error              = 'ERROR: {0}'
  lan_ip_placeholder     = '<this PC LAN IP>'
}

function Resolve-UiCulture {
  param([string]$Override)
  $code = ''
  if ($Override) { $code = "$Override".Trim().ToLower() }
  if (-not $code) {
    try { $code = ([System.Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName).ToLower() } catch { $code = 'en' }
  }
  # normalise things like 'en-US' / 'pt_BR' down to the leading language subtag
  if ($code -match '^([a-z]{2,3})') { $code = $Matches[1] } else { $code = 'en' }
  if (-not $code) { $code = 'en' }
  return $code
}

# Overlay a per-culture JSON file (UTF-8) on top of the English defaults.
function Merge-GuiStrings {
  param([hashtable]$Base, [string]$Code)
  if (-not $Code -or $Code -eq 'en') { return }
  $path = Join-Path $guiDir ($Code + '.json')
  if (-not (Test-Path $path)) { return }
  try {
    $j = [IO.File]::ReadAllText($path) | ConvertFrom-Json   # UTF-8 (Get-Content would mojibake)
    foreach ($p in $j.PSObject.Properties) {
      if ($p.Name -like '_*') { continue }                  # skip _comment etc.
      $val = "$($p.Value)"
      if ($val.Trim()) { $Base[$p.Name] = $val }            # ignore blank -> keep English
    }
  } catch { }                                               # any parse error -> stay English
}

# Also let i18n\gui\en.json override the inline English defaults (optional).
$uiCode = Resolve-UiCulture -Override $Language
# load English file overrides first (if present), then the selected culture
$enFile = Join-Path $guiDir 'en.json'
if (Test-Path $enFile) {
  try {
    $je = [IO.File]::ReadAllText($enFile) | ConvertFrom-Json
    foreach ($p in $je.PSObject.Properties) {
      if ($p.Name -like '_*') { continue }
      $val = "$($p.Value)"
      if ($val.Trim()) { $T[$p.Name] = $val }
    }
  } catch { }
}
Merge-GuiStrings -Base $T -Code $uiCode

# right-to-left cultures -> mirror the whole form (LTR unaffected)
$rtlCodes = @('ar','he','fa','ku','ur')
$uiRtl = ($rtlCodes -contains $uiCode)

# --- form -------------------------------------------------------------------
$form            = New-Object System.Windows.Forms.Form
$form.Text       = $T['title_window']
$form.Size       = New-Object System.Drawing.Size(720, 560)
$form.MinimumSize= New-Object System.Drawing.Size(640, 480)
$form.StartPosition = 'CenterScreen'
$form.Font       = New-Object System.Drawing.Font('Segoe UI', 9)
if ($uiRtl) { $form.RightToLeft = 'Yes'; $form.RightToLeftLayout = $true }

$title           = New-Object System.Windows.Forms.Label
$title.Text      = $T['title_heading']
$title.Font      = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
$title.Location  = New-Object System.Drawing.Point(16, 12)
$title.AutoSize  = $true
$form.Controls.Add($title)

$subtitle        = New-Object System.Windows.Forms.Label
$subtitle.Text   = $T['subtitle']
$subtitle.Location= New-Object System.Drawing.Point(18, 44)
$subtitle.AutoSize= $true
$subtitle.ForeColor = [System.Drawing.Color]::DimGray
$form.Controls.Add($subtitle)

# region / language
$lblLang         = New-Object System.Windows.Forms.Label
$lblLang.Text    = $T['lbl_region']
$lblLang.Location= New-Object System.Drawing.Point(18, 82)
$lblLang.AutoSize= $true
$form.Controls.Add($lblLang)

$cboLang         = New-Object System.Windows.Forms.ComboBox
$cboLang.Location= New-Object System.Drawing.Point(150, 78)
$cboLang.Size    = New-Object System.Drawing.Size(300, 26)
$cboLang.DropDownStyle = 'DropDownList'
$cboLang.Anchor  = 'Top,Left,Right'
foreach ($l in $lang.List) { [void]$cboLang.Items.Add($l.Label) }
# preselect the default language
$idx = 0
for ($i = 0; $i -lt $lang.List.Count; $i++) { if ($lang.List[$i].Code -eq $lang.Default) { $idx = $i; break } }
if ($cboLang.Items.Count -gt 0) { $cboLang.SelectedIndex = $idx }
$form.Controls.Add($cboLang)

# optional: fetch latest
$chkFetch        = New-Object System.Windows.Forms.CheckBox
$chkFetch.Text   = $T['chk_fetch']
$chkFetch.Location = New-Object System.Drawing.Point(20, 116)
$chkFetch.AutoSize = $true
$form.Controls.Add($chkFetch)

$lblSrc          = New-Object System.Windows.Forms.Label
$lblSrc.Text     = $T['lbl_source']
$lblSrc.Location  = New-Object System.Drawing.Point(18, 146)
$lblSrc.AutoSize  = $true
$lblSrc.Enabled   = $false
$form.Controls.Add($lblSrc)

$txtSrc          = New-Object System.Windows.Forms.TextBox
$txtSrc.Location  = New-Object System.Drawing.Point(200, 142)
$txtSrc.Size      = New-Object System.Drawing.Size(400, 26)
$txtSrc.Anchor    = 'Top,Left,Right'
$txtSrc.Enabled   = $false
$form.Controls.Add($txtSrc)

$chkFetch.Add_CheckedChanged({ $lblSrc.Enabled = $chkFetch.Checked; $txtSrc.Enabled = $chkFetch.Checked })

# deploy button
$btn             = New-Object System.Windows.Forms.Button
$btn.Text        = $T['btn_deploy']
$btn.Location    = New-Object System.Drawing.Point(20, 180)
$btn.Size        = New-Object System.Drawing.Size(160, 42)
$btn.Font        = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
$btn.BackColor   = [System.Drawing.Color]::FromArgb(0, 120, 60)
$btn.ForeColor   = [System.Drawing.Color]::White
$btn.FlatStyle   = 'Flat'
$form.Controls.Add($btn)

$status          = New-Object System.Windows.Forms.Label
$status.Text     = $T['status_ready']
$status.Location = New-Object System.Drawing.Point(196, 192)
$status.AutoSize = $true
$form.Controls.Add($status)

# live log
$log             = New-Object System.Windows.Forms.TextBox
$log.Location    = New-Object System.Drawing.Point(20, 236)
$log.Size        = New-Object System.Drawing.Size(660, 250)
$log.Multiline   = $true
$log.ReadOnly    = $true
$log.ScrollBars  = 'Vertical'
$log.Anchor      = 'Top,Bottom,Left,Right'
$log.BackColor   = [System.Drawing.Color]::FromArgb(24, 24, 24)
$log.ForeColor   = [System.Drawing.Color]::Gainsboro
$log.Font        = New-Object System.Drawing.Font('Consolas', 9)
$form.Controls.Add($log)

# --- deploy plumbing --------------------------------------------------------
$script:proc = $null
$queue = [System.Collections.Queue]::Synchronized((New-Object System.Collections.Queue))

function Add-Log([string]$line) { if ($null -ne $line) { $queue.Enqueue($line) } }

# UI-thread drain timer: pull queued output lines + detect process exit.
$timer          = New-Object System.Windows.Forms.Timer
$timer.Interval = 150
$timer.Add_Tick({
  while ($queue.Count -gt 0) {
    $line = $queue.Dequeue()
    $log.AppendText([string]$line + "`r`n")
  }
  if ($script:proc -and $script:proc.HasExited) {
    $timer.Stop()
    while ($queue.Count -gt 0) { $log.AppendText([string]$queue.Dequeue() + "`r`n") }
    $code = $script:proc.ExitCode
    if ($code -eq 0) {
      $ip = Get-LanIp
      $status.Text = $T['status_done']
      $log.AppendText("`r`n============================================================`r`n")
      $log.AppendText($T['sum_deployed'] + "`r`n")
      $log.AppendText(($T['sum_phones'] -f $ip) + "`r`n")
      $log.AppendText($T['sum_emergency'] + "`r`n")
      $log.AppendText($T['sum_console'] + "`r`n")
      $log.AppendText("============================================================`r`n")
      [System.Windows.Forms.MessageBox]::Show(
        ($T['msg_ok_body'] -f $ip),
        $T['msg_ok_title'], 'OK', 'Information') | Out-Null
    } else {
      $status.Text = ($T['status_failed'] -f $code)
      [System.Windows.Forms.MessageBox]::Show(
        ($T['msg_fail_body'] -f $code),
        $T['msg_fail_title'], 'OK', 'Error') | Out-Null
    }
    $btn.Enabled = $true; $cboLang.Enabled = $true; $chkFetch.Enabled = $true
    $txtSrc.Enabled = $chkFetch.Checked; $script:proc = $null
  }
})

function Get-LanIp {
  try {
    $r  = Get-NetRoute -DestinationPrefix 0.0.0.0/0 | Sort-Object RouteMetric | Select-Object -First 1
    $ip = (Get-NetIPAddress -InterfaceIndex $r.ifIndex -AddressFamily IPv4 |
           Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254\.)' } | Select-Object -First 1).IPAddress
    if ($ip) { return $ip }
  } catch { }
  return $T['lan_ip_placeholder']
}

$btn.Add_Click({
  if (-not (Test-Path $install)) {
    [System.Windows.Forms.MessageBox]::Show(
      ($T['msg_noinstall_body'] -f $install),
      $T['msg_noinstall_title'], 'OK', 'Error') | Out-Null
    return
  }
  if ($cboLang.SelectedIndex -lt 0) { return }
  $code = $lang.List[$cboLang.SelectedIndex].Code
  $src  = $txtSrc.Text.Trim()
  if ($chkFetch.Checked -and -not $src) {
    [System.Windows.Forms.MessageBox]::Show($T['msg_nosource_body'], $T['msg_nosource_title'], 'OK', 'Warning') | Out-Null
    return
  }

  # build the installer argument list
  $instArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File', $install, '-Language', $code)
  if ($chkFetch.Checked -and $src) { $instArgs += @('-Source', $src) }

  $log.Clear()
  $fromSrc = ''
  if ($chkFetch.Checked -and $src) { $fromSrc = ($T['log_from_source'] -f $src) }
  Add-Log (($T['log_deploying'] -f $code) + $fromSrc)
  Add-Log ($T['log_command'] -f ($instArgs -join ' '))
  Add-Log ''
  $status.Text = $T['status_deploying']
  $btn.Enabled = $false; $cboLang.Enabled = $false; $chkFetch.Enabled = $false; $txtSrc.Enabled = $false

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe')
  $psi.Arguments = ($instArgs | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.CreateNoWindow = $true
  $psi.WorkingDirectory = $here

  $script:proc = New-Object System.Diagnostics.Process
  $script:proc.StartInfo = $psi
  $script:proc.EnableRaisingEvents = $true
  # stream stdout/stderr into the synchronized queue (handlers run on worker threads)
  Register-ObjectEvent -InputObject $script:proc -EventName OutputDataReceived -MessageData $queue -Action {
    if ($EventArgs.Data -ne $null) { $Event.MessageData.Enqueue($EventArgs.Data) }
  } | Out-Null
  Register-ObjectEvent -InputObject $script:proc -EventName ErrorDataReceived -MessageData $queue -Action {
    if ($EventArgs.Data -ne $null) { $Event.MessageData.Enqueue($EventArgs.Data) }
  } | Out-Null

  try {
    [void]$script:proc.Start()
    $script:proc.BeginOutputReadLine()
    $script:proc.BeginErrorReadLine()
    $timer.Start()
  } catch {
    $status.Text = $T['status_could_not_start']
    Add-Log ($T['log_error'] -f $_.Exception.Message)
    $btn.Enabled = $true; $cboLang.Enabled = $true; $chkFetch.Enabled = $true; $txtSrc.Enabled = $chkFetch.Checked
    $script:proc = $null
  }
})

$form.Add_FormClosing({
  try { if ($script:proc -and -not $script:proc.HasExited) { $script:proc.Kill() } } catch { }
})

[void]$form.ShowDialog()
