<#
  UPES-ECS - HOST-SIDE generation of the REMAINING prompts (EAS announcements,
  roll-call, paging announcements, and system prompts) in the same Piper voice
  as the coach set, so the whole system speaks with ONE consistent voice.

  Same rationale as gen-coach-prompts.win.ps1: synthesize on the laptop (fast),
  the VM-side step downsamples to Asterisk 8 kHz.

  Text sources:
    - custom/upes-* and rollcall-*  : verbatim from scripts/gen-callout-prompts.sh
    - announce-{evacuate,all-clear,assemble} : same wording as the EAS set
    - announce-avoid-area, callout-notify, and the 6 system prompts
      (drill/voicemail/not-authorized/queue-*) : authored here in the EAS house
      style (SOP 28). Review and edit freely, then re-run.
#>
param(
  [string]$PiperExe = "$env:USERPROFILE\piper-win\piper\piper.exe",
  [string]$Model    = "C:\Users\Rohan\piper-model\en_US-lessac-high.onnx",
  [string]$OutDir   = "C:\Users\Rohan\piper-out2"
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path $PiperExe)) { throw "piper.exe not found at $PiperExe" }
if (-not (Test-Path $Model))    { throw "voice model not found at $Model" }
New-Item -ItemType Directory -Force -Path $OutDir, (Join-Path $OutDir 'custom'), (Join-Path $OutDir 'upesecs') | Out-Null
$piperDir = Split-Path $PiperExe -Parent

# g = custom  -> sounds/en/custom/       (EAS 'MESSAGES' set)
# g = upesecs -> sounds/en/upes-ecs/     (everything else)
$prompts = @(
  # ---- EAS announcement set (verbatim from gen-callout-prompts.sh) ----
  @{n='upes-evacuate'; g='custom'; t='Attention. This is the UPES Emergency Alert Service. Evacuate the building now. Leave immediately by the nearest safe exit. Do not use the lifts. Move to your assembly point and await further instructions.'},
  @{n='upes-shelter';  g='custom'; t='Attention. This is the UPES Emergency Alert Service. Shelter in place now. Move indoors, lock or block your door, stay away from windows, and remain quiet until you are told it is safe. Await further instructions.'},
  @{n='upes-allclear'; g='custom'; t='Attention. This is the UPES Emergency Alert Service. The emergency is now over. It is safe to resume normal activity. Thank you for your cooperation.'},
  @{n='upes-assemble'; g='custom'; t='Attention. This is the UPES Emergency Alert Service. Proceed to your designated assembly point now. Move calmly, help others where you can, and wait to be counted. Await further instructions.'},
  @{n='upes-rollcall'; g='custom'; t='Attention. This is the UPES Emergency Alert Service. This is a safety head count. If you are safe and able to respond, press one now.'},
  @{n='upes-test';     g='custom'; t='This is a test of the UPES Emergency Alert Service. This is only a test. No action is required, and no emergency response will be dispatched.'},
  # ---- roll-call control prompts (verbatim) ----
  @{n='rollcall-press1'; g='upesecs'; t='Press one if you are safe.'},
  @{n='rollcall-thanks'; g='upesecs'; t='Thank you. You are marked safe. You may now hang up.'},
  @{n='rollcall-noack';  g='upesecs'; t='No response was recorded. Please contact your warden as soon as you are able.'},
  # ---- all-campus paging announcements 720-723 (evacuate/all-clear/assemble reuse EAS wording) ----
  @{n='announce-evacuate';   g='upesecs'; t='Attention. This is the UPES Emergency Alert Service. Evacuate the building now. Leave immediately by the nearest safe exit. Do not use the lifts. Move to your assembly point and await further instructions.'},
  @{n='announce-avoid-area'; g='upesecs'; t='Attention. This is the UPES Emergency Alert Service. There is an incident on campus. Stay away from the affected area, do not approach, and follow the instructions of security staff. Await further instructions.'},
  @{n='announce-all-clear';  g='upesecs'; t='Attention. This is the UPES Emergency Alert Service. The emergency is now over. It is safe to resume normal activity. Thank you for your cooperation.'},
  @{n='announce-assemble';   g='upesecs'; t='Attention. This is the UPES Emergency Alert Service. Proceed to your designated assembly point now. Move calmly, help others where you can, and wait to be counted. Await further instructions.'},
  @{n='callout-notify';      g='upesecs'; t='Attention. This is a notification from the UPES Emergency Alert Service. Please listen carefully and follow the instructions that follow.'},
  # ---- system prompts (authored - review) ----
  @{n='drill-prompt';              g='upesecs'; t='This is a UPES emergency system drill. This is only a test. No real emergency is in progress, and no response will be dispatched. Thank you.'},
  @{n='emergency-voicemail-prompt';g='upesecs'; t='No responder is available to take your call right now. After the tone, please say your name, where you are, and what is happening. Stay safe. Help will call you back as soon as possible.'},
  @{n='not-authorized';            g='upesecs'; t='Sorry. You are not authorised to use this feature.'},
  @{n='queue-hold';                g='upesecs'; t='Please stay on the line. We are connecting you to a responder now.'},
  @{n='queue-paused';              g='upesecs'; t='You are now paused, and will not receive emergency calls. Dial star four six to resume.'},
  @{n='queue-resumed';             g='upesecs'; t='You are now available, and will receive emergency calls again.'}
)

Push-Location $piperDir
try {
  $i = 0
  foreach ($p in $prompts) {
    $i++
    $sub = if ($p.g -eq 'custom') { 'custom' } else { 'upesecs' }
    $out = Join-Path $OutDir "$sub\$($p.n).wav"
    Write-Host ("[{0,2}/{1}] {2}/{3}" -f $i, $prompts.Count, $p.g, $p.n)
    $p.t | & $PiperExe --model $Model --output_file $out
    if (-not (Test-Path $out)) { throw "piper produced no file for $($p.n)" }
  }
} finally { Pop-Location }
Write-Host ""
Write-Host "DONE: $($prompts.Count) prompts under $OutDir (22.05 kHz - VM step downsamples to 8 kHz)."
