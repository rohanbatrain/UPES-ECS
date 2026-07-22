<#
  UPES-ECS - HOST-SIDE prompt generation (Windows) using Piper neural TTS.

  Why host-side: the QEMU VM runs under software emulation (no hardware
  virtualization), so Piper inference there is ~437x real-time - unusable.
  We synthesize on the laptop's native CPU (fast), then the deploy step copies
  the WAVs into the VM and downsamples them to Asterisk's 8 kHz with sox.

  Output here is 22.05 kHz mono 16-bit WAV (Piper native). The VM-side step
  resamples to 8 kHz. Texts are kept identical to scripts/gen-coach-prompts.sh
  (that script remains the offline/pico2wave fallback generator).

  Usage (PowerShell):
    powershell -ExecutionPolicy Bypass -File scripts\gen-coach-prompts.win.ps1
#>
param(
  [string]$PiperExe = "$env:USERPROFILE\piper-win\piper\piper.exe",
  [string]$Model    = "C:\Users\Rohan\piper-model\en_US-lessac-high.onnx",
  [string]$OutDir   = "C:\Users\Rohan\piper-out"
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $PiperExe)) { throw "piper.exe not found at $PiperExe" }
if (-not (Test-Path $Model))    { throw "voice model not found at $Model" }

New-Item -ItemType Directory -Force -Path $OutDir, (Join-Path $OutDir 'coach') | Out-Null
$piperDir = Split-Path $PiperExe -Parent   # so espeak-ng-data is found next to the exe

# name | group (coach|root) | text  - MUST match gen-coach-prompts.sh
$prompts = @(
  @{n='intro';         g='coach'; t='You have reached the campus emergency guidance line. No responder is free at this moment, and help has been alerted to call you back. Stay calm. Take a slow breath. I will guide you through what to do. If you are able, also call your national emergency number now.'},
  @{n='intro-test';    g='coach'; t='This is the campus emergency guidance line, in test mode. No real incident is being logged. I will guide you through what to do in an emergency.'},
  @{n='menu';          g='coach'; t='Choose the situation. Press 1 if someone is not breathing or has no pulse. Press 2 for severe bleeding. Press 3 for choking. Press 4 for fire or smoke. Press 5 for a threat, attacker, or lockdown. Press 6 if someone is unconscious but breathing. Press 7 if you are trapped. Press 9 to try a responder again. Press 8 to leave a message. Press 0 to hear these choices again.'},
  @{n='cpr';           g='coach'; t='Put the person on their back on a firm surface and kneel beside them. Place the heel of one hand in the centre of the chest, and your other hand on top. Push down hard and fast, about twice every second, letting the chest rise fully each time. Keep going without stopping. If someone is nearby, send them for the nearest defibrillator, and turn it on to follow its spoken instructions. Do not stop until help arrives or the person wakes.'},
  @{n='bleeding';      g='coach'; t='Press firmly and directly on the wound with a cloth or your hand. Do not remove the cloth. If blood soaks through, add more on top and keep pressing hard. If it is an arm or a leg and the bleeding will not stop, tie a strong band tightly a few centimetres above the wound, between the wound and the heart, and note the time. Keep the person warm and still.'},
  @{n='choking';       g='coach'; t='Ask if they can speak or cough. If they cannot breathe, stand behind them and give five firm blows between the shoulder blades with the heel of your hand. If that does not work, wrap your arms around their waist and give five quick inward and upward thrusts just above the navel. Keep repeating the back blows and the thrusts until the object comes out or help arrives.'},
  @{n='fire';          g='coach'; t='Get everyone out now, and do not stop for belongings. Stay low under the smoke, where the air is clearer. Before opening any door, feel it with the back of your hand. If it is hot, find another way out. Do not use the lifts. Once you are outside, stay outside, and move to the assembly point. Do not go back in.'},
  @{n='lockdown';      g='coach'; t='If you can leave the area safely, move away from the danger quietly and quickly. If you cannot, get into a room, lock or block the door, and stay low, away from windows and doors. Turn off the lights and set your phone to silent. Stay quiet and out of sight. Do not open the door until security or the police tell you it is safe.'},
  @{n='recovery';      g='coach'; t='If the person is breathing but not awake, gently roll them onto their side. Tilt their head back a little to keep the airway open, and lift their chin. Stay with them and keep watching that they are still breathing. If they stop breathing, begin chest compressions in the centre of the chest.'},
  @{n='trapped';       g='coach'; t='Stay as calm and still as you can, to save air and energy. Cover your nose and mouth with cloth against dust. Tap steadily on a pipe, a wall, or any hard surface, so rescuers can hear you. Shout only as a last resort, to avoid breathing in dust. Do not light any flame. Move as little as possible and wait to be found.'},
  @{n='tryagain';      g='coach'; t='I am trying to reach a responder now. Please stay on the line and hold.'},
  @{n='noresponder';   g='coach'; t='No responder is free yet. I will stay with you. Returning to the guidance.'},
  @{n='invalid';       g='coach'; t='Sorry, I did not understand that.'},
  @{n='nochoice';      g='coach'; t='I did not hear a choice.'},
  @{n='leavemsg';      g='coach'; t='I will now let you leave a message for the response team. After the tone, say where you are and what is happening.'},
  @{n='pick-language'; g='coach'; t='To change the language, press 1 for English, or 2 for Hindi.'},
  @{n='fastpath-intro';g='coach'; t='First aid guidance. A responder is still being alerted and will join if they can. Stay with me.'},
  @{n='emergency-preanswer'; g='root'; t='You have reached the campus emergency line. Your call is being recorded, and help is being reached now. Stay on the line. If someone needs first aid right now, press 1 at any time, and I will guide you.'},
  @{n='hold-firstaid';       g='root'; t='Still connecting you to a responder. If you need first aid now, press 1 for step by step guidance.'},
  @{n='responder-alert';     g='root'; t='Emergency alert. There is an active call on the campus emergency line and no responder has answered. Please make yourself available now. Press 1 to join the emergency queue.'},
  @{n='shift-on';            g='root'; t='You are now on shift. You will receive campus emergency calls until you go off shift by dialling star two three.'},
  @{n='shift-off';           g='root'; t='You are now off shift. You will no longer receive campus emergency calls.'}
)

Push-Location $piperDir
try {
  $i = 0
  foreach ($p in $prompts) {
    $i++
    $out = if ($p.g -eq 'coach') { Join-Path $OutDir "coach\$($p.n).wav" } else { Join-Path $OutDir "$($p.n).wav" }
    Write-Host ("[{0,2}/{1}] {2}/{3}" -f $i, $prompts.Count, $p.g, $p.n)
    $p.t | & $PiperExe --model $Model --output_file $out
    if (-not (Test-Path $out)) { throw "piper produced no file for $($p.n)" }
  }
} finally { Pop-Location }

Write-Host ""
Write-Host "DONE: $($prompts.Count) prompts written under $OutDir  (22.05 kHz - VM step will downsample to 8 kHz)."
