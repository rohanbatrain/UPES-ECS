<#
.SYNOPSIS
  Phase-0 READ-ONLY load generator for the UPES-ECS Operations Console (Serve.ps1).

.DESCRIPTION
  Spins up N concurrent virtual "screens" (wallboards / dashboards) that poll the
  console exactly the way the real front-end does, then reports what the fan-in cache
  did under that load. It answers two questions:

    1. Does the fan-in cache work?  A high X-Upes-Cache HIT ratio at high -Clients means
       the backend (the SSH-tunnelled in-VM API) saw far fewer requests than the clients
       issued - i.e. 5 or 50 screens cost the VM about the same. The tool prints the
       "upstream fetches" figure (miss+stale) so you can see the amplification directly.

    2. Where is the concurrency ceiling?  Latency p50/p95/p99 and the error count show
       how the single-listener + runspace-pool server holds up as -Clients climbs.

  STRICTLY READ-ONLY. This tool ONLY issues HTTP GET requests to /api/live and
  /api/status. It NEVER POSTs and never touches /api/exec, /api/rebind, /api/adduser,
  /api/setlang, /api/deploy or any other privileged/mutating endpoint. It cannot change
  PBX state. It is safe to point at a live console, but it does put real read load on the
  VM if the cache is cold, so keep -Clients/-Seconds sane against production.

  Concurrency uses the same runspace-pool pattern as Console\Serve.ps1: a pool sized to
  -Clients, one [powershell] instance per virtual poller, BeginInvoke to launch, EndInvoke
  to reap, pool.Close() to shut down cleanly.

.PARAMETER Url
  Base URL of the console. Default http://localhost:8080. For a LAN box use e.g.
  http://192.168.1.50:8080.

.PARAMETER Clients
  Number of concurrent virtual screens (pollers). Default 10.

.PARAMETER Seconds
  How long each poller runs. Default 30.

.PARAMETER Endpoint
  Which poll profile each virtual screen runs:
    live   - only GET /api/live  every ~1.3s (fast KPI strip)
    status - only GET /api/status every ~4.5s (full wallboard schema)
    mixed  - a real board doing BOTH (live fast + status slow). Default.

.EXAMPLE
  .\Load-Test-Console.ps1
  10 mixed screens for 30s against localhost:8080.

.EXAMPLE
  .\Load-Test-Console.ps1 -Clients 25 -Seconds 60 -Endpoint mixed
  Prove fan-in with 25 screens for a minute. Watch the hit ratio stay high.

.EXAMPLE
  .\Load-Test-Console.ps1 -Clients 50 -Seconds 30 -Endpoint status -Url http://192.168.1.50:8080
  Push a LAN console with 50 status-only screens to find the ceiling.

.NOTES
  Windows PowerShell 5.1 safe (no ternary / ?. / ??). ASCII only.
#>
param(
  [string]$Url='http://localhost:8080',
  [int]$Clients=10,
  [int]$Seconds=30,
  [ValidateSet('live','status','mixed')][string]$Endpoint='mixed'
)

$ErrorActionPreference='Stop'
if($Clients -lt 1){ $Clients=1 }
if($Seconds -lt 1){ $Seconds=1 }
$base=$Url.TrimEnd('/')

# Process-wide HTTP tuning. In .NET Framework the default per-host connection limit is 2,
# which would serialize all our pollers onto 2 sockets and hide the real concurrency. Raise
# it well above -Clients. ServicePointManager is appdomain-wide, so setting it here also
# governs the runspace pollers. Expect100Continue off matches Serve.ps1.
[System.Net.ServicePointManager]::Expect100Continue=$false
$limit=[Math]::Max(64,$Clients*4)
[System.Net.ServicePointManager]::DefaultConnectionLimit=$limit
try{ Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue }catch{}

# Build the per-poller task list (endpoint path + cadence in ms) from -Endpoint.
if($Endpoint -eq 'live'){
  $tasks=@([pscustomobject]@{ path='/api/live';   interval=1300 })
} elseif($Endpoint -eq 'status'){
  $tasks=@([pscustomobject]@{ path='/api/status'; interval=4500 })
} else {
  $tasks=@(
    [pscustomobject]@{ path='/api/live';   interval=1300 },
    [pscustomobject]@{ path='/api/status'; interval=4500 }
  )
}

Write-Host "UPES-ECS Console load test (READ-ONLY, GET only)" -ForegroundColor Green
Write-Host ("  Target   : {0}" -f $base)
Write-Host ("  Clients  : {0} concurrent virtual screens" -f $Clients)
Write-Host ("  Duration : {0}s   Profile: {1}" -f $Seconds,$Endpoint)
$paths=@($tasks | ForEach-Object { "{0} ~{1}ms" -f $_.path,$_.interval }) -join ', '
Write-Host ("  Polling  : {0}" -f $paths)
Write-Host "  Running..." -ForegroundColor DarkGray

# --------------------------------------------------------------------------------------
# One virtual screen. Self-contained (runspaces do NOT inherit main-thread functions or
# variables): takes everything as arguments, owns its own HttpClient, returns a small
# summary object (total, errors, per-request latencies, X-Upes-Cache tallies).
# --------------------------------------------------------------------------------------
$poller={
  param($clientId,$baseUrl,$deadlineSec,$tasks,$seed)
  try{ Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue }catch{}
  $tasks=@($tasks)

  $client=New-Object System.Net.Http.HttpClient
  $client.Timeout=[TimeSpan]::FromSeconds(20)

  $latencies=New-Object 'System.Collections.Generic.List[double]'
  $cache=@{}
  $total=0
  $errors=0

  $rand=New-Object System.Random ([int]$seed)
  # Stagger each task's first fire across its interval so pollers do not all hit at t=0.
  $next=@()
  for($i=0;$i -lt $tasks.Count;$i++){ $next += ($rand.NextDouble()*[double]$tasks[$i].interval) }

  $sw=[System.Diagnostics.Stopwatch]::StartNew()
  $deadlineMs=[double]$deadlineSec*1000.0

  while($sw.Elapsed.TotalMilliseconds -lt $deadlineMs){
    $now=$sw.Elapsed.TotalMilliseconds
    $fired=$false
    for($i=0;$i -lt $tasks.Count;$i++){
      if($now -ge $next[$i]){
        $fired=$true
        $uri=$baseUrl + $tasks[$i].path
        $total++
        $rt=[System.Diagnostics.Stopwatch]::StartNew()
        try{
          $resp=$client.GetAsync($uri).GetAwaiter().GetResult()
          $rt.Stop()
          $latencies.Add($rt.Elapsed.TotalMilliseconds)
          if($resp.IsSuccessStatusCode){
            $tag='none'
            $vals=$null
            if($resp.Headers.TryGetValues('X-Upes-Cache',[ref]$vals)){
              $first=@($vals)[0]
              if($first){ $tag=("$first").ToLower() }
            }
            if($cache.ContainsKey($tag)){ $cache[$tag]++ } else { $cache[$tag]=1 }
          } else {
            $errors++
            if($cache.ContainsKey('error')){ $cache['error']++ } else { $cache['error']=1 }
          }
          $resp.Dispose()
        }catch{
          $rt.Stop()
          $errors++
          if($cache.ContainsKey('error')){ $cache['error']++ } else { $cache['error']=1 }
        }
        # schedule this task's next fire with +/-10% jitter (realistic, avoids lockstep)
        $jit=1.0 + (($rand.NextDouble()-0.5)*0.2)
        $next[$i]=$sw.Elapsed.TotalMilliseconds + ([double]$tasks[$i].interval*$jit)
      }
    }
    if(-not $fired){
      # idle until the soonest task is due (capped 5..200ms so we stay responsive to the deadline)
      $soonest=[double]::MaxValue
      for($i=0;$i -lt $next.Count;$i++){ if($next[$i] -lt $soonest){ $soonest=$next[$i] } }
      $wait=$soonest - $sw.Elapsed.TotalMilliseconds
      if($wait -lt 5){ $wait=5 }
      if($wait -gt 200){ $wait=200 }
      Start-Sleep -Milliseconds ([int]$wait)
    }
  }

  try{ $client.Dispose() }catch{}
  return [pscustomobject]@{
    total     = $total
    errors    = $errors
    latencies = $latencies.ToArray()
    cache     = $cache
  }
}

# --- runspace pool: one poller per client, all concurrent (same pattern as Serve.ps1) ---
$pool=[runspacefactory]::CreateRunspacePool(1,$Clients)
$pool.Open()
$jobs=New-Object System.Collections.ArrayList
$wall=[System.Diagnostics.Stopwatch]::StartNew()

try{
  for($c=1;$c -le $Clients;$c++){
    $psi=[powershell]::Create()
    $psi.RunspacePool=$pool
    [void]$psi.AddScript($poller)
    [void]$psi.AddArgument($c)
    [void]$psi.AddArgument($base)
    [void]$psi.AddArgument($Seconds)
    [void]$psi.AddArgument($tasks)
    [void]$psi.AddArgument(($c*7919)+1)   # per-poller RNG seed
    $h=$psi.BeginInvoke()
    [void]$jobs.Add([pscustomobject]@{ P=$psi; H=$h })
  }

  # EndInvoke blocks until each poller finishes (~ -Seconds), so no polling loop needed.
  $results=New-Object System.Collections.ArrayList
  foreach($j in $jobs){
    try{
      $out=$j.P.EndInvoke($j.H)
      foreach($o in $out){ [void]$results.Add($o) }
    }catch{}
    try{ $j.P.Dispose() }catch{}
  }
} finally {
  try{ $pool.Close() }catch{}
  try{ $pool.Dispose() }catch{}
}
$wall.Stop()

# --------------------------------------------------------------------------------------
# Aggregate + report.
# --------------------------------------------------------------------------------------
$allLat=New-Object 'System.Collections.Generic.List[double]'
$totalReq=0
$totalErr=0
$cacheAgg=@{}
foreach($r in $results){
  $totalReq += [int]$r.total
  $totalErr += [int]$r.errors
  foreach($l in $r.latencies){ [void]$allLat.Add([double]$l) }
  foreach($k in $r.cache.Keys){
    if($cacheAgg.ContainsKey($k)){ $cacheAgg[$k] += [int]$r.cache[$k] } else { $cacheAgg[$k]=[int]$r.cache[$k] }
  }
}

function Get-Pctl($sorted,$p){
  $n=$sorted.Length
  if($n -eq 0){ return 0.0 }
  $idx=[int][Math]::Ceiling(($p/100.0)*$n)-1
  if($idx -lt 0){ $idx=0 }
  if($idx -ge $n){ $idx=$n-1 }
  return $sorted[$idx]
}

$sorted=$allLat.ToArray()
[Array]::Sort($sorted)
$elapsed=$wall.Elapsed.TotalSeconds
$rps=0.0
if($elapsed -gt 0){ $rps=$totalReq/$elapsed }

$p50=Get-Pctl $sorted 50
$p95=Get-Pctl $sorted 95
$p99=Get-Pctl $sorted 99
$maxMs=0.0
if($sorted.Length -gt 0){ $maxMs=$sorted[$sorted.Length-1] }

$hit=0;   if($cacheAgg.ContainsKey('hit')){ $hit=$cacheAgg['hit'] }
$miss=0;  if($cacheAgg.ContainsKey('miss')){ $miss=$cacheAgg['miss'] }
$stale=0; if($cacheAgg.ContainsKey('stale')){ $stale=$cacheAgg['stale'] }
$cacheable=$hit+$miss+$stale
$hitRatio=0.0
if($cacheable -gt 0){ $hitRatio=($hit/[double]$cacheable)*100.0 }
$upstream=$miss+$stale   # requests the cache could not answer -> the backend actually fetched

Write-Host ""
Write-Host "==== RESULTS ==============================================" -ForegroundColor Cyan
Write-Host ("  Target            : {0}" -f $base)
Write-Host ("  Clients / profile : {0} / {1}" -f $Clients,$Endpoint)
Write-Host ("  Duration (wall)   : {0:N1} s" -f $elapsed)
Write-Host ("  Requests total    : {0}" -f $totalReq)
Write-Host ("  Throughput        : {0:N1} req/s" -f $rps)
Write-Host ("  Errors            : {0}" -f $totalErr)
Write-Host "  ---- latency (ms) ----"
Write-Host ("  p50 / p95 / p99   : {0:N1} / {1:N1} / {2:N1}" -f $p50,$p95,$p99)
Write-Host ("  max               : {0:N1}" -f $maxMs)
Write-Host "  ---- X-Upes-Cache ----"
$order=@('hit','miss','stale','none','error')
foreach($k in $order){
  if($cacheAgg.ContainsKey($k)){
    Write-Host ("  {0,-6}: {1}" -f $k,$cacheAgg[$k])
  }
}
# any header value we did not anticipate
foreach($k in $cacheAgg.Keys){
  if($order -notcontains $k){ Write-Host ("  {0,-6}: {1}" -f $k,$cacheAgg[$k]) }
}
Write-Host ("  hit ratio         : {0:N1}%   (hit / (hit+miss+stale))" -f $hitRatio)
Write-Host "  ---- fan-in -----------"
Write-Host ("  Clients issued    : {0} GET requests" -f $totalReq)
Write-Host ("  Backend fetched   : ~{0} (miss+stale) - the rest were served from cache" -f $upstream)
if($upstream -gt 0){
  $amp=$totalReq/[double]$upstream
  Write-Host ("  Amplification     : {0:N1}x  (a high number = fan-in working)" -f $amp)
} elseif($cacheable -gt 0) {
  Write-Host "  Amplification     : all cacheable requests were served from cache (perfect fan-in)"
} else {
  Write-Host "  Amplification     : no X-Upes-Cache headers seen (is the cache deployed? is the target the console?)"
}
Write-Host "===========================================================" -ForegroundColor Cyan
