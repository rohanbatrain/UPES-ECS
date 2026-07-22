<#
.SYNOPSIS  Serve the UPES-ECS Operations Console on the laptop.
.DESCRIPTION
  Minimal static web server (no admin) on http://localhost:<Port>. Also refreshes
  status.json every -RefreshSec seconds so the dashboard stays live. Open the printed
  URL in a browser on the laptop.
  For LAN access (phones/other PCs), run elevated once so it can bind all interfaces,
  or view the console on the laptop itself.

  CONCURRENCY: each request is handled in a runspace pool (not one-at-a-time), so a
  slow upstream /api/* call can no longer block static assets or the other screens'
  polls. This is what made "everything" feel delayed. REVERSIBLE: the previous
  single-threaded build is saved alongside as Serve.ps1.bak-preconcurrency.
.PARAMETER Port        Default 8080
.PARAMETER RefreshSec  How often to regenerate status.json (0 = don't). Default 30.
#>
param([int]$Port=8080,[int]$RefreshSec=20,[string]$Base="$env:USERPROFILE\qemu")
$ErrorActionPreference='Stop'
$root=$PSScriptRoot

# Always TRY all-interfaces (LAN) first. This succeeds when elevated OR when a urlacl for
# http://+:<Port>/ exists (see the one-time netsh command in README). If HTTP.sys refuses
# (not admin, no urlacl), fall back to localhost so the laptop-only console still works.
$admin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
$prefix="http://+:$Port/"
$listener=New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)
try{ $listener.Start() } catch { Write-Host "LAN bind ($prefix) refused: $($_.Exception.Message)" -ForegroundColor Yellow; Write-Host "  Falling back to localhost. For LAN access run elevated once, or add a urlacl (see README)." -ForegroundColor Yellow; $prefix="http://localhost:$Port/"; $listener=New-Object System.Net.HttpListener; $listener.Prefixes.Add($prefix); $listener.Start() }

$ctypes=@{'.html'='text/html';'.js'='text/javascript';'.css'='text/css';'.json'='application/json';'.md'='text/plain';'.png'='image/png';'.svg'='image/svg+xml';'.wav'='audio/wav';'.gsm'='audio/x-gsm'}
Write-Host "UPES-ECS Console -> $($prefix.Replace('+','localhost'))" -ForegroundColor Green
if(-not $admin){ Write-Host "  (localhost only; run elevated for LAN access)" -ForegroundColor Yellow }
Write-Host "  Ctrl+C to stop."

# --- Live API proxy: /api/* -> the in-VM FastAPI, reached via the SSH tunnel on 18090.
#     Fast (real HTTP, no per-request SSH login). status.json + refresher stay as fallback.
[System.Net.ServicePointManager]::Expect100Continue=$false
$ApiBase='http://127.0.0.1:18090'

# Shared, thread-safe cache of the host's current LAN IP. Computing it runs three WMI/CIM
# queries (Get-NetAdapter/Route/IPAddress) that cost 100s of ms each; the IP changes maybe
# once a session, so we cache it (~45s TTL) instead of paying that on EVERY /api/status.
# Synchronized so the runspace-pool request handlers can share one cache safely.
$Shared=[hashtable]::Synchronized(@{ ip=$null; ipTs=[DateTime]::MinValue })
# --- SCALE-CACHE (REVERSIBLE): shared, thread-safe caches so MANY concurrent screens (TVs +
#     dashboards) share ONE upstream fetch (api fan-in) and ONE disk read per file (static).
#     Created on the MAIN thread and reached inside the runspace handler via $Shared - NO
#     handler-signature / AddArgument change (arg-order bugs would be catastrophic here). ---
$Shared.apiCache=[hashtable]::Synchronized(@{})
$Shared.staticCache=[hashtable]::Synchronized(@{})
# Per-key lock objects for single-flight refresh (only ONE upstream fetch per key in flight).
$Shared.apiLocks=[hashtable]::Synchronized(@{ 'api/status'=(New-Object object); 'api/live'=(New-Object object) })
# --- end SCALE-CACHE ---
function Get-ServerIpRaw {
  try{ $up=@(Get-NetAdapter -EA SilentlyContinue | Where-Object { $_.Status -eq 'Up' } | Select-Object -ExpandProperty ifIndex)
    $r=Get-NetRoute -DestinationPrefix 0.0.0.0/0 -EA SilentlyContinue | Where-Object { $up -contains $_.ifIndex } | Sort-Object RouteMetric | Select-Object -First 1
    if($r){ return @(Get-NetIPAddress -InterfaceIndex $r.ifIndex -AddressFamily IPv4 -EA SilentlyContinue | Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254\.)' })[0].IPAddress } }catch{}
  return $null
}
# Seed the cache once on the MAIN thread (NetTCPIP module reliably available here) so the
# very first request already has an IP even if a runspace can't autoload the module.
try{ $Shared.ip=Get-ServerIpRaw; $Shared.ipTs=Get-Date }catch{}

# persistent SSH tunnel: localhost:18090 -> VM:8090 (the FastAPI). One slow SSH login, then
# every /api/* call reuses it (fast). Auto-reconnects if it drops.
$tunnelJob={ param($k) while($true){
  ssh.exe -i $k -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o BatchMode=yes -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes -N -L 18090:127.0.0.1:8090 ubuntu@127.0.0.1 2>$null
  Start-Sleep -Seconds 3 } }
Start-Job -ScriptBlock $tunnelJob -ArgumentList "$Base\ssh\upes_key" | Out-Null
Write-Host "  API tunnel opening (localhost:18090 -> VM:8090)..." -ForegroundColor DarkGray

# background status refresher
if($RefreshSec -gt 0){
  $sb={ param($b,$o,$r,$s) $i=0; while($true){ try{ & "$o" -Base $b | Out-Null }catch{};
    if($i % 4 -eq 0){ try{ & "$r" -Base $b | Out-Null }catch{} }  # sync recordings every 4th cycle
    $i++; Start-Sleep -Seconds $s } }
  Start-Job -ScriptBlock $sb -ArgumentList $Base,"$root\Update-Status.ps1","$root\Pull-Recordings.ps1",$RefreshSec | Out-Null
}

# --------------------------------------------------------------------------------------
# Per-request handler. Runs in a runspace-pool thread so a slow upstream never blocks the
# accept loop or the other in-flight requests. Self-contained: takes all state as args and
# defines its own Get-ServerIp (runspaces do NOT inherit main-thread functions).
# --------------------------------------------------------------------------------------
$handler={
  param($ctx,$root,$ApiBase,$Base,$ctypes,$Shared)
  function Get-ServerIp {
    # fresh cache hit -> no WMI at all
    if($Shared.ip -and ((Get-Date)-$Shared.ipTs).TotalSeconds -lt 45){ return $Shared.ip }
    try{ $up=@(Get-NetAdapter -EA SilentlyContinue | Where-Object { $_.Status -eq 'Up' } | Select-Object -ExpandProperty ifIndex)
      $r=Get-NetRoute -DestinationPrefix 0.0.0.0/0 -EA SilentlyContinue | Where-Object { $up -contains $_.ifIndex } | Sort-Object RouteMetric | Select-Object -First 1
      if($r){ $ip=@(Get-NetIPAddress -InterfaceIndex $r.ifIndex -AddressFamily IPv4 -EA SilentlyContinue | Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254\.)' })[0].IPAddress
        if($ip){ $Shared.ip=$ip; $Shared.ipTs=Get-Date }
        return $ip } }catch{}
    return $Shared.ip   # on failure, fall back to the last-known (main-thread-seeded) IP
  }
  # After a LIVE IVR-language switch (api/ivrlang) rewrite region.json so the dashboard chip +
  # Region view follow immediately. Native/name come from Console\languages.json (deploy-written)
  # so we never embed non-ASCII here (PS 5.1 source stays ASCII). source='live-toggle' marks it
  # a runtime switch rather than a Deploy-UPES deployment. Defined in-handler: runspaces do NOT
  # inherit main-thread functions.
  function Update-RegionJson($code){
    try{
      $code = ("$code").ToLower()
      $name = $code; $native = $code
      $lp = Join-Path $root 'languages.json'
      if(Test-Path $lp){
        $j = [IO.File]::ReadAllText($lp) | ConvertFrom-Json
        $e = $j.languages | Where-Object { "$($_.code)" -eq $code } | Select-Object -First 1
        if($e){ $name = "$($e.name)"; $native = if($e.native){ "$($e.native)" } else { $name } }
      }
      if($code -eq 'en'){ $name = 'English'; $native = 'English' }
      $obj = [ordered]@{
        schema='upes-ecs.region/v1'; language=$code; languageName=$name; native=$native
        prompts='packed'; source='live-toggle'
        deployedAt=(Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
      }
      [IO.File]::WriteAllText((Join-Path $root 'region.json'), ($obj | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
    }catch{}
  }
  # --- admin helpers (in-handler: runspaces do NOT inherit main-thread functions) ----------
  # Read a POST body to a UTF-8 string.
  $ReadBody = {
    param($c)
    $len=[int]$c.Request.ContentLength64; if($len -le 0){ return '' }
    $buf=New-Object byte[] $len; $off=0
    while($off -lt $len){ $n=$c.Request.InputStream.Read($buf,$off,$len-$off); if($n -le 0){break}; $off+=$n }
    return [Text.Encoding]::UTF8.GetString($buf,0,$off)
  }
  # Run one command on the VM over SSH (BatchMode, no host-key prompt). Returns combined stdout.
  $SshVm = {
    param($b,$cmd)
    $key = Join-Path $b 'ssh\upes_key'
    # -n: read stdin from NUL. Without it ssh.exe blocks on stdin when spawned from a
    # windowless PowerShell (runspace handler), hanging the request.
    # NOTE: Windows OpenSSH does NOT support ControlMaster multiplexing ("getsockname failed:
    # Not a socket"), so each admin command pays a fresh login. That is slow on the single-vCPU
    # TCG VM under tunnel/refresher contention but it is CORRECT; the fast path is api/exec over
    # the tunnel (see the VM-side upes_lang action).
    $o = & ssh.exe -n -i $key -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o BatchMode=yes -o ConnectTimeout=10 ubuntu@127.0.0.1 $cmd 2>$null
    return (@($o) -join "`n")
  }
  # Call a whitelisted VM /exec action over the FAST tunnel (no fresh SSH login). Returns the
  # parsed object, or $null if the tunnel/VM is down (caller can fall back to $SshVm).
  $VmExec = {
    param($apiBase,$action,$argsObj)
    $body = @{ action=$action; args=$argsObj } | ConvertTo-Json -Compress
    try{ $resp=Invoke-WebRequest -Uri ($apiBase+'/exec') -Method POST -Body $body -ContentType 'application/json' -UseBasicParsing -TimeoutSec 12; return ($resp.Content | ConvertFrom-Json) }catch{ return $null }
  }
  # Write a JSON string as the response.
  $WriteJson = {
    param($c,$s)
    $jb=[Text.Encoding]::UTF8.GetBytes("$s")
    $c.Response.ContentType='application/json'
    $c.Response.Headers.Add('Cache-Control','no-cache, no-store, must-revalidate')
    $c.Response.OutputStream.Write($jb,0,$jb.Length)
  }
  # Start a host-side PowerShell script DETACHED, tracked by a running/done flag + captured log
  # (same pattern as api/rebind). Returns immediately so a slow deploy never blocks the listener.
  $StartDetached = {
    param($b,$scriptPath,$argLine,$tag)
    $log  = Join-Path $b ($tag + '-last.log')
    $flag = Join-Path $b ($tag + '-last.flag')
    if((Test-Path $flag) -and (("$(Get-Content $flag -Raw -EA SilentlyContinue)").Trim() -eq 'running')){
      return @{ ok=$true; running=$true; output=('A ' + $tag + ' job is already in progress...') }
    }
    if(-not (Test-Path $scriptPath)){ return @{ ok=$false; running=$false; output=($scriptPath + ' not found') } }
    $inner = "try { & `"$scriptPath`" $argLine *>&1 | Out-File -FilePath `"$log`" -Encoding utf8 } finally { Set-Content -Path `"$flag`" -Value 'done' -Encoding ascii }"
    Set-Content -Path $flag -Value 'running' -Encoding ascii
    Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-Command',$inner | Out-Null
    return @{ ok=$true; running=$true; output=($tag + ' started.') }
  }
  # GET status of a detached job (running/done + captured log).
  $JobStatus = {
    param($b,$tag)
    $log  = Join-Path $b ($tag + '-last.log')
    $flag = Join-Path $b ($tag + '-last.flag')
    $running = (Test-Path $flag) -and (("$(Get-Content $flag -Raw -EA SilentlyContinue)").Trim() -eq 'running')
    $logtext = if(Test-Path $log){ "$(Get-Content $log -Raw -EA SilentlyContinue)" } else { '' }
    return @{ ok=$true; running=$running; output=($logtext.Trim()) }
  }
  # Known language codes (from Console\languages.json). Used to validate lang inputs.
  $KnownLangs = {
    param($r)
    $codes=@('en')
    try{ $lp=Join-Path $r 'languages.json'; if(Test-Path $lp){ $j=[IO.File]::ReadAllText($lp)|ConvertFrom-Json; $codes=@($j.languages | ForEach-Object { "$($_.code)".ToLower() }) } }catch{}
    return $codes
  }
  try{
    $path=$ctx.Request.Url.LocalPath.TrimStart('/'); if(-not $path){ $path='index.html' }
    if($path -eq '__build'){
      # Build stamp = newest mtime of the Console's own front-end assets. The dashboard
      # polls this and reloads itself when it changes, so deploying an edit (app.js/css/
      # index.html) is picked up automatically - no manual browser hard-refresh.
      $assets=@('app.js','app.css','index.html','tv.js','tv.css','tv-safety.html','tv-ops.html','directory.json') | ForEach-Object { Join-Path $root $_ }
      $tok=($assets | Where-Object { Test-Path $_ } | ForEach-Object { (Get-Item $_).LastWriteTimeUtc.Ticks } | Measure-Object -Maximum).Maximum
      $jb=[Text.Encoding]::UTF8.GetBytes("{""build"":""$tok""}")
      $ctx.Response.ContentType='application/json'
      $ctx.Response.Headers.Add('Cache-Control','no-cache, no-store, must-revalidate')
      $ctx.Response.OutputStream.Write($jb,0,$jb.Length)
    } elseif($path -eq 'api/rebind'){
      # --- HOST-SIDE rebind. Only the host knows its current LAN IP, so this can't be a VM
      #     /exec action. The PJSIP reload is slow (~60-90s) on the TCG-emulated PBX, so we
      #     run it DETACHED (never block this listener / freeze the wallboard):
      #       POST -> start Set-UpesLanIp.ps1 in the background, return immediately.
      #       GET  -> report running/done + the script's captured output + the current LAN IP.
      #     The dashboard's serverIp updates within 4s regardless (the host knows its new IP
      #     instantly via /api/status); the reload just makes media follow. No internet needed.
      $script = Join-Path $Base 'Set-UpesLanIp.ps1'
      $log    = Join-Path $Base 'rebind-last.log'
      $flag   = Join-Path $Base 'rebind-last.flag'
      # "$(...)" interpolation coerces a null read (empty/locked file) to '' - [string]$null stays $null in PS 5.1.
      $running = (Test-Path $flag) -and (("$(Get-Content $flag -Raw -EA SilentlyContinue)").Trim() -eq 'running')
      if($ctx.Request.HttpMethod -eq 'POST'){
        if($running){
          $out = @{ ok=$true; running=$true; serverIp=(Get-ServerIp); output='A rebind is already in progress...' } | ConvertTo-Json -Compress
        } elseif(-not (Test-Path $script)){
          $out = @{ ok=$false; running=$false; output=("Set-UpesLanIp.ps1 not found at " + $script) } | ConvertTo-Json -Compress
        } else {
          # Wrapper captures ALL streams to the log, then flips the flag to 'done' no matter what.
          $inner = "try { & `"$script`" -Base `"$Base`" *>&1 | Out-File -FilePath `"$log`" -Encoding utf8 } finally { Set-Content -Path `"$flag`" -Value 'done' -Encoding ascii }"
          Set-Content -Path $flag -Value 'running' -Encoding ascii
          Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-Command',$inner | Out-Null
          $out = @{ ok=$true; running=$true; serverIp=(Get-ServerIp); output='Rebind started - detecting the current LAN IP and reloading Asterisk (~60-90s on the emulated PBX). The new IP appears on the dashboard automatically.' } | ConvertTo-Json -Compress
        }
      } else {
        # "$(...)" coerces a $null read (missing / freshly-created empty / locked log) to '' so .Trim() is safe.
        $logtext = if(Test-Path $log){ "$(Get-Content $log -Raw -EA SilentlyContinue)" } else { '' }
        $out = [ordered]@{ ok=$true; running=$running; serverIp=(Get-ServerIp); output=($logtext.Trim()) } | ConvertTo-Json -Compress
      }
      $jb=[Text.Encoding]::UTF8.GetBytes($out)
      $ctx.Response.ContentType='application/json'
      $ctx.Response.Headers.Add('Cache-Control','no-cache, no-store, must-revalidate')
      $ctx.Response.OutputStream.Write($jb,0,$jb.Length)
    } elseif($path -eq 'api/ivrlang'){
      # --- HOST-SIDE live IVR voice-language switch. Runs Set-UpesIvrLanguage.ps1 (SSHes into
      #     the VM, swaps the active prompt set, reloads res_sound). Fast (~2-4s) so we run it
      #     INLINE (unlike the slow rebind). GET -> current language ; POST {"language":"en|hi"}
      #     -> switch, then refresh region.json so the dashboard follows immediately. The script
      #     is launched as a child powershell (with -Json) so its exit code never touches this
      #     handler; we pass its single JSON line straight through.
      $ivrScript = Join-Path (Split-Path $root -Parent) 'deploy\qemu\Set-UpesIvrLanguage.ps1'
      $runIvr = {
        param($extra)
        if(-not (Test-Path $ivrScript)){ return '{"ok":false,"language":"unknown","output":"Set-UpesIvrLanguage.ps1 not found"}' }
        $a = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$ivrScript,'-Json','-Base',$Base) + $extra
        $raw = & powershell @a 2>$null
        $line = $raw | Where-Object { "$_" -match '^\s*\{' } | Select-Object -Last 1
        if(-not $line){ return '{"ok":false,"language":"unknown","output":"no response from the switch script (is the VM up?)"}' }
        return "$line"
      }
      if($ctx.Request.HttpMethod -eq 'POST'){
        $len=[int]$ctx.Request.ContentLength64; $body=''
        if($len -gt 0){
          $buf=New-Object byte[] $len; $off=0
          while($off -lt $len){ $n=$ctx.Request.InputStream.Read($buf,$off,$len-$off); if($n -le 0){break}; $off+=$n }
          $body=[Text.Encoding]::UTF8.GetString($buf,0,$off)
        }
        $lang=''
        try{ $lang=("$(($body | ConvertFrom-Json).language)").Trim().ToLower() }catch{}
        if($lang -ne 'en' -and $lang -ne 'hi'){
          $out='{"ok":false,"language":"unknown","output":"language must be en or hi"}'
        } else {
          $out = & $runIvr @('-Language',$lang)
          try{ if((($out | ConvertFrom-Json).ok)){ Update-RegionJson $lang }; }catch{}
        }
      } else {
        $out = & $runIvr @('-Status')
      }
      $jb=[Text.Encoding]::UTF8.GetBytes("$out")
      $ctx.Response.ContentType='application/json'
      $ctx.Response.Headers.Add('Cache-Control','no-cache, no-store, must-revalidate')
      $ctx.Response.OutputStream.Write($jb,0,$jb.Length)
    } elseif($path -eq 'api/users'){
      # --- HOST-SIDE user roster. Merges directory.json (name/kind) with each user's language
      #     (directory.json 'lang' field, else provisioning\user-languages.csv). GET only.
      $dir = Join-Path $root 'directory.json'
      $langCsv = Join-Path (Split-Path $root -Parent) 'provisioning\user-languages.csv'
      $langMap=@{}
      if(Test-Path $langCsv){ foreach($ln in @(Get-Content $langCsv -EA SilentlyContinue | Select-Object -Skip 1)){ $p=$ln -split ','; if($p.Count -ge 2){ $langMap["$($p[0])".Trim()]="$($p[1])".Trim() } } }
      $arr=@()
      if(Test-Path $dir){
        try{ $j=[IO.File]::ReadAllText($dir) | ConvertFrom-Json
          foreach($k in $j.PSObject.Properties.Name){
            $u=$j.$k
            $lg = if($u.PSObject.Properties.Name -contains 'lang' -and $u.lang){ "$($u.lang)" } elseif($langMap.ContainsKey($k)){ $langMap[$k] } else { '' }
            $arr += [ordered]@{ ext=$k; name="$($u.name)"; kind="$($u.kind)"; lang=$lg }
          } }catch{}
      }
      $out = @{ ok=$true; users=$arr } | ConvertTo-Json -Depth 5
      & $WriteJson $ctx $out
    } elseif($path -eq 'api/setlang'){
      # --- HOST-SIDE per-user language. POST {ext,lang}. Sets the caller's language everywhere the
      #     per-caller dialplan routing (sub_setlang) reads it: live astdb DB(lang/<ext>), the
      #     provisioning CSV (survives VM rebuild), and directory.json (so the roster shows it).
      #     Fast (one SSH) so it runs INLINE. Strict input validation (SSH command injection guard).
      $body = & $ReadBody $ctx
      $ext=''; $lang=''
      try{ $o=$body|ConvertFrom-Json; $ext="$($o.ext)".Trim(); $lang="$($o.lang)".Trim().ToLower() }catch{}
      $known = & $KnownLangs $root
      if($ext -notmatch '^[0-9A-Za-z]{2,20}$' -or $lang -notmatch '^[a-z]{2,3}$' -or -not ($known -contains $lang)){
        $out='{"ok":false,"output":"invalid ext or unknown language"}'
      } else {
        # FAST path: set live astdb via the VM API over the tunnel; fall back to SSH if down.
        $ve = & $VmExec $ApiBase 'setlang' @{ ext=$ext; lang=$lang }
        if($null -eq $ve){ $r = & $SshVm $Base ("sudo asterisk -rx 'database put lang $ext $lang'") } else { $r = "$($ve.output)" }
        # upsert provisioning\user-languages.csv
        try{
          $ulc = $langCsv2 = Join-Path (Split-Path $root -Parent) 'provisioning\user-languages.csv'
          $lines=@('ext,lang'); if(Test-Path $ulc){ $lines=@(Get-Content $ulc -EA SilentlyContinue) }
          if($lines.Count -lt 1 -or $lines[0] -notmatch '^ext,lang'){ $lines=@('ext,lang')+$lines }
          $found=$false; for($i=1;$i -lt $lines.Count;$i++){ if("$($lines[$i])" -match ("^"+[regex]::Escape($ext)+",")){ $lines[$i]="$ext,$lang"; $found=$true } }
          if(-not $found){ $lines += "$ext,$lang" }
          Set-Content -Path $ulc -Value ($lines | Where-Object { "$_".Trim() -ne '' }) -Encoding ascii
        }catch{}
        # add/update lang field in directory.json (preserve the rest)
        try{
          $dj = Join-Path $root 'directory.json'
          if(Test-Path $dj){ $d=[IO.File]::ReadAllText($dj)|ConvertFrom-Json
            if($d.PSObject.Properties.Name -contains $ext){
              if($d.$ext.PSObject.Properties.Name -contains 'lang'){ $d.$ext.lang=$lang } else { $d.$ext | Add-Member -NotePropertyName lang -NotePropertyValue $lang -Force }
              [IO.File]::WriteAllText($dj, ($d | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding($false)))
            } }
        }catch{}
        $out = @{ ok=$true; ext=$ext; lang=$lang; output="language set for $ext -> $lang" } | ConvertTo-Json -Compress
      }
      & $WriteJson $ctx $out
    } elseif($path -eq 'api/deflang'){
      # --- HOST-SIDE campus DEFAULT language (any of the 43 packs). GET -> current default;
      #     POST {lang} -> set astdb DB(lang/_default) + region.json. This is what an un-mapped
      #     caller hears. Instant (per-caller routing reads astdb per call; no res_sound reload).
      if($ctx.Request.HttpMethod -eq 'POST'){
        $body = & $ReadBody $ctx; $lang=''
        try{ $lang="$(($body|ConvertFrom-Json).lang)".Trim().ToLower() }catch{}
        $known = & $KnownLangs $root
        if($lang -notmatch '^[a-z]{2,3}$' -or -not ($known -contains $lang)){
          $out='{"ok":false,"output":"unknown language"}'
        } else {
          $ve = & $VmExec $ApiBase 'deflang' @{ lang=$lang }
          if($null -eq $ve){ & $SshVm $Base ("sudo asterisk -rx 'database put lang _default $lang'") | Out-Null }
          Update-RegionJson $lang
          $out = @{ ok=$true; default=$lang; output="campus default -> $lang" } | ConvertTo-Json -Compress
        }
      } else {
        $ve = & $VmExec $ApiBase 'deflang' @{}
        if($null -ne $ve -and $ve.default){ $val="$($ve.default)" }
        else { $cur = (& $SshVm $Base "sudo asterisk -rx 'database get lang _default'"); $val='en'; if($cur -match 'Value:\s*([a-z]{2,3})'){ $val=$matches[1] } }
        $out = @{ ok=$true; default=$val } | ConvertTo-Json -Compress
      }
      & $WriteJson $ctx $out
    } elseif($path -eq 'api/adduser'){
      # --- HOST-SIDE add/heal a SIP user via the one safe path: deploy\qemu\Add-UpesUser.ps1
      #     (pins the secret, SSHes to the VM, pjsip reload, refreshes CardDAV). Can take ~10-20s,
      #     so DETACHED (flag+log). POST {sapId,name,lang,kind}; GET -> job status.
      if($ctx.Request.HttpMethod -eq 'POST'){
        $body = & $ReadBody $ctx; $sap='';$name='';$lang='';$kind=''
        try{ $o=$body|ConvertFrom-Json; $sap="$($o.sapId)".Trim(); $name="$($o.name)".Trim(); $lang="$($o.lang)".Trim().ToLower(); $kind="$($o.kind)".Trim() }catch{}
        $known = & $KnownLangs $root
        if($sap -notmatch '^[0-9A-Za-z]{2,20}$' -or $name -notmatch "^[\w .,'\-]{1,60}$"){
          $out = '{"ok":false,"output":"invalid SAP id or name"}'
        } else {
          $add = Join-Path (Split-Path $root -Parent) 'deploy\qemu\Add-UpesUser.ps1'
          $al = "-SapId '$sap' -Name '$($name -replace "'","''")' -Base '$Base'"
          if($lang -match '^[a-z]{2,3}$' -and ($known -contains $lang)){ $al += " -Lang $lang" }
          $out = (& $StartDetached $Base $add $al 'adduser') | ConvertTo-Json -Compress
        }
      } else { $out = (& $JobStatus $Base 'adduser') | ConvertTo-Json -Compress }
      & $WriteJson $ctx $out
    } elseif($path -eq 'api/vm'){
      # --- HOST-SIDE VM lifecycle. POST {action:start|stop|status}. start/stop shell the qemu
      #     helpers; status pings the VM over SSH. Fast enough to run inline.
      $body = & $ReadBody $ctx; $action='status'
      try{ $action="$(($body|ConvertFrom-Json).action)".Trim().ToLower() }catch{}
      $qd = Join-Path (Split-Path $root -Parent) 'deploy\qemu'
      if($action -eq 'start'){
        $s=Join-Path $qd 'start-vm.ps1'
        $out = (& $StartDetached $Base $s "-Base '$Base'" 'vmstart') | ConvertTo-Json -Compress
      } elseif($action -eq 'stop'){
        $s=Join-Path $qd 'stop-vm.ps1'
        $out = (& $StartDetached $Base $s "-Base '$Base'" 'vmstop') | ConvertTo-Json -Compress
      } else {
        # FAST: hit the VM API /health over the tunnel; fall back to an SSH ping if unreachable.
        $up=$false
        try{ $hr=Invoke-WebRequest -Uri ($ApiBase+'/health') -UseBasicParsing -TimeoutSec 6; if($hr.StatusCode -eq 200){ $up=$true } }catch{}
        if(-not $up){ $up = ((& $SshVm $Base 'echo up').Trim() -eq 'up') }
        # PS 5.1: 'if' works as an assignment RHS but NOT inside grouping parens as a hashtable value
        # (throws "'if' is not recognized" at runtime -> handler 500 -> dashboard shows the 'error' chip).
        $vmUpMsg = if($up){ 'VM reachable' } else { 'VM not reachable' }
        $out = @{ ok=$true; up=$up; output=$vmUpMsg } | ConvertTo-Json -Compress
      }
      & $WriteJson $ctx $out
    } elseif($path -eq 'api/genprompt'){
      # --- HOST-SIDE voice-prompt generation for ONE language pack (Piper/eSpeak on the host CPU).
      #     Slow (minutes) -> DETACHED. POST {lang}; GET -> job status. Writes into
      #     deploy\asterisk\sounds\lang\<lang>\ ; deploy to the VM afterwards with api/deploy.
      if($ctx.Request.HttpMethod -eq 'POST'){
        $body = & $ReadBody $ctx; $lang=''
        try{ $lang="$(($body|ConvertFrom-Json).lang)".Trim().ToLower() }catch{}
        $known = & $KnownLangs $root
        if($lang -notmatch '^[a-z]{2,3}$' -or -not ($known -contains $lang)){
          $out='{"ok":false,"output":"unknown language"}'
        } else {
          $gen = Join-Path (Split-Path $root -Parent) 'scripts\gen-lang-prompts.win.ps1'
          $out = (& $StartDetached $Base $gen "-Lang $lang" 'genprompt') | ConvertTo-Json -Compress
        }
      } else { $out = (& $JobStatus $Base 'genprompt') | ConvertTo-Json -Compress }
      & $WriteJson $ctx $out
    } elseif($path -eq 'api/deploy'){
      # --- HOST-SIDE redeploy of all language sound packs + dialplan to the VM (idempotent).
      #     Very slow -> DETACHED. POST -> start ; GET -> job status.
      if($ctx.Request.HttpMethod -eq 'POST'){
        $dep = Join-Path (Split-Path $root -Parent) 'deploy\qemu\Deploy-LangPacks.ps1'
        $out = (& $StartDetached $Base $dep "-Base '$Base'" 'deploy') | ConvertTo-Json -Compress
      } else { $out = (& $JobStatus $Base 'deploy') | ConvertTo-Json -Compress }
      & $WriteJson $ctx $out
    } elseif($path -like 'api/*'){
      # --- proxy to the in-VM FastAPI (GET /api/status, POST /api/exec, etc.) ---
      $target = $ApiBase + '/' + $path.Substring(4)
      # --- SCALE-CACHE (REVERSIBLE): fan-in api cache ---
      # N wallboards/dashboards share ONE upstream fetch. ONLY GET api/status (TTL 2000ms) and
      # api/live (TTL 1000ms) are cached; POSTs and every other endpoint (exec/rebind/ivrlang/
      # users/...) bypass the cache and behave exactly as before. Cache key = the path; value =
      # @{ body=<final response string>; ts=<DateTime> }. For api/status the stored body is AFTER
      # the serverIp injection (staleness up to the TTL is fine - Get-ServerIp is itself cached
      # ~45s). X-Upes-Cache header: hit=served from fresh cache, miss=fetched now, stale=last-good.
      $cacheKey=$null; $cacheTtl=0
      if($ctx.Request.HttpMethod -eq 'GET'){
        if($path -eq 'api/status'){ $cacheKey='api/status'; $cacheTtl=2000 }
        elseif($path -eq 'api/live'){ $cacheKey='api/live'; $cacheTtl=400 }
      }
      # --- IMMEDIATE-UPDATE (REVERSIBLE): ?fresh=1 forces a LIVE read - skip the cache HIT + single-
      #     flight coalesce so the client that just hung a call up gets the TRUE current count NOW,
      #     not a cached one. The result is still STORED (and serve-stale kept), so it only bypasses
      #     READING a stale value. Used by the dashboard right after the hangup action returns. ---
      $forceFresh=$false
      try{ if("$($ctx.Request.QueryString['fresh'])" -eq '1'){ $forceFresh=$true } }catch{}
      $servedFromCache=$false
      if($cacheKey -and (-not $forceFresh)){
        $hitEntry=$Shared.apiCache[$cacheKey]
        if($hitEntry -and ($null -ne $hitEntry.body) -and (((Get-Date)-$hitEntry.ts).TotalMilliseconds -lt $cacheTtl)){
          $jb=[Text.Encoding]::UTF8.GetBytes("$($hitEntry.body)")
          $ctx.Response.ContentType='application/json'
          $ctx.Response.Headers.Add('X-Upes-Cache','hit')
          # G3 freshness guardrail: how old (host clock) the served body is, so the client can
          # gate the live call count on PROVABLE freshness instead of trusting a 200 (see below).
          $hitAge=[int]((Get-Date)-$hitEntry.ts).TotalMilliseconds; $ctx.Response.Headers.Add('X-Upes-Age-Ms',"$hitAge")
          $ctx.Response.OutputStream.Write($jb,0,$jb.Length)
          $servedFromCache=$true
        }
      }
      if(-not $servedFromCache){
      # --- SCALE-CACHE single-flight (REVERSIBLE): coalesce concurrent refreshes so only ONE
      #     upstream fetch per key is in flight at a time. On the slow emulated VM a /live fetch
      #     takes ~0.3-0.5s; without this, EVERY client that polls during that window also misses
      #     and piles onto the VM (stampede) AND ties up runspace-pool slots -> tail latency spikes
      #     to many seconds. Here: the first caller to find the cache expired grabs the key lock and
      #     refreshes; everyone else during that window is served the last-good value instantly (no
      #     VM hit, no pool blocking). Cacheable GETs only - POST/other endpoints never lock. ---
      $gotLock=$false; $lk=$null
      if($cacheKey){ $lk=$Shared.apiLocks[$cacheKey]; if($lk){ [System.Threading.Monitor]::TryEnter($lk,0,[ref]$gotLock) } }
      if($cacheKey -and (-not $forceFresh) -and (-not $gotLock)){
        # another thread is already refreshing this key -> serve last-good instantly (coalesced hit)
        $coEntry=$Shared.apiCache[$cacheKey]
        if($coEntry -and ($null -ne $coEntry.body)){
          $cb=[Text.Encoding]::UTF8.GetBytes("$($coEntry.body)")
          $ctx.Response.ContentType='application/json'
          $ctx.Response.Headers.Add('X-Upes-Cache','hit')
          $coAge=[int]((Get-Date)-$coEntry.ts).TotalMilliseconds; $ctx.Response.Headers.Add('X-Upes-Age-Ms',"$coAge")
          try{ $ctx.Response.OutputStream.Write($cb,0,$cb.Length) }catch{}
        } else {
          # cold start (no cached body yet) under contention: wait for the leader, then serve its result
          [System.Threading.Monitor]::Enter($lk,[ref]$gotLock)
          $coEntry=$Shared.apiCache[$cacheKey]
          if($coEntry -and ($null -ne $coEntry.body) -and (((Get-Date)-$coEntry.ts).TotalMilliseconds -lt $cacheTtl)){
            $cb=[Text.Encoding]::UTF8.GetBytes("$($coEntry.body)")
            $ctx.Response.ContentType='application/json'
            $ctx.Response.Headers.Add('X-Upes-Cache','hit')
            $coAge2=[int]((Get-Date)-$coEntry.ts).TotalMilliseconds; $ctx.Response.Headers.Add('X-Upes-Age-Ms',"$coAge2")
            try{ $ctx.Response.OutputStream.Write($cb,0,$cb.Length) }catch{}
            [System.Threading.Monitor]::Exit($lk); $gotLock=$false
          }
          # else: still nothing fresh -> fall through holding the lock and fetch (below)
        }
      }
      if((-not $cacheKey) -or $gotLock -or $forceFresh){
      try{
        if($ctx.Request.HttpMethod -eq 'POST'){
          $len=[int]$ctx.Request.ContentLength64; $body=''
          if($len -gt 0){
            $buf=New-Object byte[] $len; $off=0
            while($off -lt $len){ $n=$ctx.Request.InputStream.Read($buf,$off,$len-$off); if($n -le 0){break}; $off+=$n }
            $body=[Text.Encoding]::UTF8.GetString($buf,0,$off)
          }
          $resp=Invoke-WebRequest -Uri $target -Method POST -Body $body -ContentType 'application/json' -UseBasicParsing -TimeoutSec 25
          $out=$resp.Content
          # IMMEDIATE-UPDATE: a POST to /api/* is a mutation (e.g. /exec hangup). Expire the cached
          # live+status entries so EVERY board's next poll recomputes fresh - not just the operator
          # who acted. Keeps the body for serve-stale; only the timestamp is aged out.
          try{ foreach($ik in @('api/live','api/status')){ $ie=$Shared.apiCache[$ik]; if($ie){ $ie['ts']=[DateTime]::MinValue } } }catch{}
        } else {
          $resp=Invoke-WebRequest -Uri $target -UseBasicParsing -TimeoutSec 12
          $out=$resp.Content
          if($path -eq 'api/status'){   # inject the host's current LAN IP (the API in the VM can't know it)
            try{ $o=$out|ConvertFrom-Json; $o|Add-Member -NotePropertyName serverIp -NotePropertyValue (Get-ServerIp) -Force; $out=($o|ConvertTo-Json -Depth 12 -Compress) }catch{}
          }
        }
        # SCALE-CACHE: store the FINAL body (after any serverIp injection) so the next N clients
        # within the TTL share it, and so serve-stale has a last-good copy on an upstream failure.
        if($cacheKey){ $Shared.apiCache[$cacheKey]=@{ body="$out"; ts=(Get-Date) } }
        $jb=[Text.Encoding]::UTF8.GetBytes($out)
        $ctx.Response.ContentType='application/json'
        if($cacheKey){ $ctx.Response.Headers.Add('X-Upes-Cache','miss'); $ctx.Response.Headers.Add('X-Upes-Age-Ms','0') }  # fresh fetch from the VM this instant
        $ctx.Response.OutputStream.Write($jb,0,$jb.Length)
      }catch{
        # SCALE-CACHE serve-stale: for a cacheable GET (api/status/api/live) with a last-good body,
        # return it as HTTP 200 + X-Upes-Cache:stale so wallboards never blank during a VM hiccup
        # and clients don't pile up on the 12s timeout. Only 502 when there is NO cached body.
        $staleEntry=$null; if($cacheKey){ $staleEntry=$Shared.apiCache[$cacheKey] }
        if($cacheKey -and $staleEntry -and ($null -ne $staleEntry.body)){
          $sb=[Text.Encoding]::UTF8.GetBytes("$($staleEntry.body)")
          $ctx.Response.ContentType='application/json'
          $ctx.Response.Headers.Add('X-Upes-Cache','stale')
          # Unbounded during an outage - this is exactly what tells the client to STOP trusting the count.
          $staleAge=[int]((Get-Date)-$staleEntry.ts).TotalMilliseconds; $ctx.Response.Headers.Add('X-Upes-Age-Ms',"$staleAge")
          try{ $ctx.Response.OutputStream.Write($sb,0,$sb.Length) }catch{}
        } else {
          $ctx.Response.StatusCode=502
          $eb=[Text.Encoding]::UTF8.GetBytes('{"ok":false,"output":"API unreachable - is the tunnel + VM API up?"}')
          try{ $ctx.Response.OutputStream.Write($eb,0,$eb.Length) }catch{}
        }
      }finally{
        if($gotLock -and $lk){ [System.Threading.Monitor]::Exit($lk); $gotLock=$false }
      }
      }
      }
      # --- end SCALE-CACHE ---
    } else {
      # --- static file serving (+ whitelisted repo docs for the doc viewer) ---
      $file=Join-Path $root $path
      if((-not (Test-Path $file)) -and ($path -match '\.md$') -and ($path -match '^(SOP|Blueprint|AI-101|Journal|config|deploy|provisioning|Notes)/')){
        $cand=Join-Path (Split-Path $root -Parent) $path
        if(Test-Path $cand){ $file=$cand }
      }
      $ext=[IO.Path]::GetExtension($file).ToLower()
      # Only serve known-safe web types - never *.ps1 (would leak the ssh key path / internals).
      if((Test-Path $file) -and $ctypes.ContainsKey($ext) -and -not (Split-Path $file -Leaf).StartsWith('.')){
        $ctx.Response.ContentType = $ctypes[$ext]
        # Code/markup/data must never be stale - the wallboard auto-reloads on deploy, and a
        # cached app.js would defeat that. Recordings (.wav) are immutable, so let them cache.
        if(@('.html','.js','.css','.json','.md') -contains $ext){ $ctx.Response.Headers.Add('Cache-Control','no-cache, no-store, must-revalidate') }
        # --- SCALE-CACHE (REVERSIBLE): static in-memory cache + gzip ---
        # Serve file bytes from a shared in-memory cache keyed by the resolved path, refreshed when
        # the file's mtime changes (so the /__build auto-reload keeps working - deployed edits are
        # picked up). For text types (.html/.js/.css/.json/.md) we also keep a gzip copy, compressed
        # ONCE per file version, and send it when the client advertises Accept-Encoding: gzip.
        # Binary types (png/svg/wav/gsm) are cached raw and never gzipped.
        $isText = (@('.html','.js','.css','.json','.md') -contains $ext)
        $mtime = (Get-Item $file).LastWriteTimeUtc.Ticks
        $entry = $Shared.staticCache[$file]
        if(-not ($entry -and ($entry.mtime -eq $mtime))){
          $raw=[IO.File]::ReadAllBytes($file)
          $gz=$null
          if($isText){
            try{
              $ms=New-Object System.IO.MemoryStream
              $gzs=New-Object System.IO.Compression.GzipStream($ms,[System.IO.Compression.CompressionMode]::Compress)
              $gzs.Write($raw,0,$raw.Length); $gzs.Close()
              $gz=$ms.ToArray(); $ms.Dispose()
            }catch{ $gz=$null }
          }
          $entry=@{ raw=$raw; gz=$gz; mtime=$mtime }
          $Shared.staticCache[$file]=$entry
        }
        $ae=''; try{ $ae="$($ctx.Request.Headers['Accept-Encoding'])" }catch{}
        if($isText -and $entry.gz -and ($ae -match 'gzip')){
          $ctx.Response.Headers.Add('Content-Encoding','gzip')
          $ctx.Response.OutputStream.Write($entry.gz,0,$entry.gz.Length)
        } else {
          $ctx.Response.OutputStream.Write($entry.raw,0,$entry.raw.Length)
        }
        # --- end SCALE-CACHE ---
      } else { $ctx.Response.StatusCode=404 }
    }
  } catch { try{ $ctx.Response.StatusCode=500 }catch{} }
  try{ $ctx.Response.OutputStream.Close() }catch{}
}

# Runspace pool: up to 24 concurrent request handlers. The accept loop below only accepts a
# connection and dispatches it, so it returns to GetContext() immediately - no request can
# hold the server hostage. Completed handler instances are reaped each iteration. Raised from
# 12 to 24 for headroom when many screens fetch static assets at once (app.js/css); with the
# single-flight api cache almost every request now returns from memory in microseconds, so the
# pool is rarely held long anyway.
$pool=[runspacefactory]::CreateRunspacePool(1,24)
$pool.Open()
$inflight=New-Object System.Collections.ArrayList

try{
  while($listener.IsListening){
    $ctx=$listener.GetContext()
    $psi=[powershell]::Create()
    $psi.RunspacePool=$pool
    [void]$psi.AddScript($handler)
    [void]$psi.AddArgument($ctx)
    [void]$psi.AddArgument($root)
    [void]$psi.AddArgument($ApiBase)
    [void]$psi.AddArgument($Base)
    [void]$psi.AddArgument($ctypes)
    [void]$psi.AddArgument($Shared)
    $h=$psi.BeginInvoke()
    [void]$inflight.Add([pscustomobject]@{ P=$psi; H=$h })
    # reap finished handlers so runspaces/[powershell] instances don't accumulate
    for($i=$inflight.Count-1; $i -ge 0; $i--){
      if($inflight[$i].H.IsCompleted){
        try{ $inflight[$i].P.EndInvoke($inflight[$i].H) }catch{}
        try{ $inflight[$i].P.Dispose() }catch{}
        $inflight.RemoveAt($i)
      }
    }
  }
} finally {
  try{ $pool.Close() }catch{}
}
