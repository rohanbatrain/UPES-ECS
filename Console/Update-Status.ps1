<#
.SYNOPSIS  Pull live status from the UPES-ECS VM and write status.json for the console.
.DESCRIPTION
  Queries Asterisk over SSH (service, ERT queue availability + members, registrations +
  who, active calls, storage, pending/recent missed emergencies, version) + the host's
  current LAN IP, computes an overall READY/DEGRADED/CRITICAL/OFFLINE state, and writes
  a rich status.json for the Console wallboard. Run on a schedule or via Serve.ps1.
#>
param(
  [string]$Base="$env:USERPROFILE\qemu",
  [string]$Out="$PSScriptRoot\status.json",
  [int]$MinAgents=1   # available ERT answer points required for READY (raise for production redundancy)
)
$ErrorActionPreference='Continue'
$key="$Base\ssh\upes_key"
$sshOpt=@('-o','StrictHostKeyChecking=no','-o','UserKnownHostsFile=NUL','-o','ConnectTimeout=10','-o','BatchMode=yes')

$serverIp=$null
$upIdx=@(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' } | Select-Object -ExpandProperty ifIndex)
$r=Get-NetRoute -DestinationPrefix 0.0.0.0/0 -ErrorAction SilentlyContinue | Where-Object { $upIdx -contains $_.ifIndex } | Sort-Object RouteMetric | Select-Object -First 1
if($r){ $serverIp=(Get-NetIPAddress -InterfaceIndex $r.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254\.)' } | Select-Object -First 1).IPAddress }

$remote=@'
echo "ASTERISK=$(systemctl is-active asterisk 2>/dev/null)"
echo "UPTIME=$(sudo asterisk -rx 'core show uptime' 2>/dev/null | head -1 | sed 's/System uptime: //')"
echo "QAVAIL=$(sudo asterisk -rx 'queue show ert_emergency_queue' 2>/dev/null | grep -c 'Not in use')"
echo "REG=$(sudo asterisk -rx 'pjsip show contacts' 2>/dev/null | grep -cE 'sip:[0-9]')"
echo "DISK=$(df -P / 2>/dev/null | tail -1 | awk '{print $5}' | tr -dc 0-9)"
echo "MISSED=$(wc -l < /var/lib/upes-ecs/alerts/missed-pending.log 2>/dev/null || echo 0)"
echo "VER=$(sudo asterisk -rx 'core show version' 2>/dev/null | head -1)"
echo "HOST=$(hostname)"
echo "ACTIVE=$(sudo asterisk -rx 'core show channels' 2>/dev/null | grep -oE '[0-9]+ active call' | grep -oE '^[0-9]+')"
sudo asterisk -rx 'pjsip show contacts' 2>/dev/null | grep -oE '[0-9]{8,9}/sip:[0-9]+@[0-9.]+' | sed -E 's#([0-9]+)/sip:[0-9]+@([0-9.]+)#REGUSER=\1|\2#'
sudo asterisk -rx 'queue show ert_emergency_queue' 2>/dev/null | python3 -c "import sys,re
for l in sys.stdin:
 l=re.sub(r'\x1b\[[0-9;]*m','',l)
 m=re.search(r'(PJSIP/\d+)',l); s=re.search(r'\((Not in use|Unavailable|In use|Paused|Invalid|Ringing|Busy)\)',l)
 if m and s: print('QMEMBER=%s|%s|%s'%(l.strip().split(' (')[0],m.group(1),s.group(1)))"
sudo tail -6 /var/lib/upes-ecs/incidents/missed-emergency.ndjson 2>/dev/null | python3 -c "import sys,json
for l in sys.stdin:
 l=l.strip()
 if not l: continue
 try:
  d=json.loads(l); print('MISSEDROW=%s|%s|%s|%s'%(d.get('incident_id',''),d.get('caller_extension',''),d.get('datetime',''),d.get('severity','')))
 except Exception: pass"
# --- call records (CDR): last 40 rows, csv-parsed on the VM into clean pipe rows ---
sudo cat /var/log/asterisk/cdr-csv/Master.csv 2>/dev/null | python3 -c "import sys,csv
try: rows=list(csv.reader(sys.stdin))
except Exception: rows=[]
for r in rows[-40:]:
 if len(r)<17: continue
 print('CDRROW=%s|%s|%s|%s|%s|%s|%s|%s'%(r[9],r[1],r[2],r[3],r[7],r[12],r[14],r[16]))"
# --- recordings: most-recent whole-call recordings (filename carries incident/caller/time) ---
sudo bash -c 'ls -1t /var/spool/asterisk/monitor/upes-ecs/*.wav 2>/dev/null | head -12' | while read f; do [ -n "$f" ] && echo "RECWAV=$(basename "$f")"; done
# --- presence: registration state of every defined endpoint (positions + clients) ---
sudo asterisk -rx "pjsip show endpoints" 2>/dev/null | python3 -c "import sys,re
for l in sys.stdin:
 l=re.sub(r'\x1b\[[0-9;]*m','',l)
 m=re.match(r'\s*Endpoint:\s+(\S+?)(?:/\S+)?\s+(Not in use|Unavailable|In use|Busy|Ringing|Unknown|Invalid)',l)
 if m: print('ENDP=%s|%s'%(m.group(1),m.group(2)))"
# --- analytics: aggregate the FULL CDR log into KPIs (answer-time, volume, drill pass-rate) ---
sudo cat /var/log/asterisk/cdr-csv/Master.csv 2>/dev/null | python3 -c "import sys,csv,json,datetime,collections
def kind(dst,app):
 d=(dst or '').strip(); a=(app or '').lower()
 if d=='111': return 'emergency'
 if d=='199' or 'drill' in a: return 'drill'
 if d=='198' or a=='echo': return 'echo'
 if d[:3]=='900' or 'confbridge' in a: return 'bridge'
 if (len(d)==3 and d[:1]=='7') or a=='page': return 'paging'
 return 'other'
def parse(t):
 try: return datetime.datetime.strptime(t,'%Y-%m-%d %H:%M:%S')
 except Exception: return None
try: rows=list(csv.reader(sys.stdin))
except Exception: rows=[]
tot=0; byk=collections.Counter(); hours=[0]*24; days=collections.Counter(); bysrc=collections.Counter()
em={'total':0,'answered':0,'ws':0.0,'wmax':0.0,'wn':0}; dr={'total':0,'answered':0}
for r in rows:
 if len(r)<17: continue
 src,dst,app,start,answer,dispo=r[1],r[2],r[7],r[9],r[10],r[14]
 tot+=1; k=kind(dst,app); byk[k]+=1
 st=parse(start)
 if st: hours[st.hour]+=1; days[st.strftime('%Y-%m-%d')]+=1
 if src: bysrc[src]+=1
 if k=='emergency':
  em['total']+=1
  if dispo=='ANSWERED':
   em['answered']+=1; an=parse(answer)
   if st and an:
    w=(an-st).total_seconds()
    if w>=0: em['ws']+=w; em['wn']+=1; em['wmax']=max(em['wmax'],w)
 if k=='drill':
  dr['total']+=1
  if dispo=='ANSWERED': dr['answered']+=1
out={'total':tot,'byKind':dict(byk),'hours':hours,'days':dict(sorted(days.items())[-14:]),
 'topCallers':bysrc.most_common(8),
 'emergency':{'total':em['total'],'answered':em['answered'],
  'answeredPct':(round(100*em['answered']/em['total']) if em['total'] else None),
  'avgWait':(round(em['ws']/em['wn'],1) if em['wn'] else None),
  'maxWait':(round(em['wmax']) if em['wn'] else None)},
 'drill':{'total':dr['total'],'answered':dr['answered'],
  'passPct':(round(100*dr['answered']/dr['total']) if dr['total'] else None)}}
print('ANALYTICS='+json.dumps(out))"
# --- live calls: active channel legs (for the realtime Department Map) ---
sudo asterisk -rx 'core show channels concise' 2>/dev/null | python3 -c "import sys,re
def secs(s):
 try:
  r=0
  for p in str(s).split(':'): r=r*60+int(p)
  return r
 except Exception: return 0
for l in sys.stdin:
 l=re.sub(r'\x1b\[[0-9;]*m','',l).strip()
 if '!' not in l: continue
 f=l.split('!')
 if len(f)<5: continue
 m=re.search(r'/(\d+)-',f[0]); ext=m.group(1) if m else ''
 cid=f[7] if len(f)>7 else ''; dialed=f[2] if len(f)>2 else ''; state=f[4] if len(f)>4 else ''
 app=f[5] if len(f)>5 else ''; bridge=f[-2] if len(f)>=14 else ''; dur=secs(f[11]) if len(f)>11 else 0
 print('LIVECALL=%s|%s|%s|%s|%s|%s|%s'%(ext,cid,dialed,state,app,bridge,dur))"
# --- shift log: recent on/off events (who staffed the emergency queue, when) ---
sudo tail -n 12 /var/lib/upes-ecs/shift/shift.log 2>/dev/null | sed 's/^/SHIFTROW=/'
'@
$b64=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($remote -replace "`r","")))
$raw=ssh.exe -q -i $key -p 2222 @sshOpt ubuntu@127.0.0.1 "echo $b64 | base64 -d | bash" 2>$null

$m=@{}; $reg=@(); $qm=@(); $missed=@(); $cdr=@(); $rec=@(); $pres=@(); $analytics=$null; $shiftlog=@(); $live=@()
foreach($line in ($raw -split "`n")){
  $line=$line.Trim()
  if($line -match '^REGUSER=(.+)\|(.+)$'){ $reg += ,([ordered]@{ext=$Matches[1];ip=$Matches[2]}) }
  elseif($line -match '^QMEMBER=(.+)\|(.+)\|(.+)$'){ $qm += ,([ordered]@{name=$Matches[1];iface=$Matches[2];state=$Matches[3]}) }
  elseif($line -match '^MISSEDROW=(.*)\|(.*)\|(.*)\|(.*)$'){ $missed += ,([ordered]@{incident_id=$Matches[1];caller=$Matches[2];time=$Matches[3];severity=$Matches[4]}) }
  elseif($line -match '^CDRROW=(.*)$'){
    $p = $Matches[1] -split '\|'
    if($p.Count -ge 8){ $cdr += ,([ordered]@{time=$p[0];src=$p[1];dst=$p[2];context=$p[3];app=$p[4];dur=([int]($p[5] -replace '\D',''));disposition=$p[6];uniqueid=$p[7]}) }
  }
  elseif($line -match '^RECWAV=(.+)$'){
    $fn=$Matches[1]; $inc='';$cal='';$tm=''
    if($fn -match '^(.*?)_([0-9]+)_([0-9]{8}-[0-9]{6})\.wav$'){ $inc=$Matches[1];$cal=$Matches[2];$tm=$Matches[3] }
    $rec += ,([ordered]@{file=$fn;incident=$inc;caller=$cal;time=$tm})
  }
  elseif($line -match '^ENDP=(.+)\|(.+)$'){ $pres += ,([ordered]@{ext=$Matches[1];state=$Matches[2]}) }
  elseif($line -match '^LIVECALL=(.*)$'){
    $p = $Matches[1] -split '\|'
    if($p.Count -ge 7){ $live += ,([ordered]@{ext=$p[0];cid=$p[1];dialed=$p[2];state=$p[3];app=$p[4];bridge=$p[5];seconds=([int]($p[6] -replace '\D',''))}) }
  }
  elseif($line -match '^ANALYTICS=(.+)$'){ try{ $analytics = $Matches[1] | ConvertFrom-Json }catch{} }
  elseif($line -match '^SHIFTROW=(.*)\|(.*)\|(.*)$'){ $shiftlog += ,([ordered]@{time=$Matches[1];ext=$Matches[2];action=$Matches[3]}) }
  elseif($line -match '^([A-Z]+)=(.*)$'){ $m[$Matches[1]]=$Matches[2] }
}

$reachable = [bool]$m['ASTERISK']
$asterisk  = if($m['ASTERISK']){$m['ASTERISK']}else{'unreachable'}
$qavail    = if($m.ContainsKey('QAVAIL')){[int]$m['QAVAIL']}else{$null}
$regN      = if($m['REG']){[int]$m['REG']}else{0}
$disk      = if($m['DISK']){[int]$m['DISK']}else{$null}
$missedP   = if($m['MISSED']){[int]$m['MISSED']}else{0}
$active    = if($m['ACTIVE']){[int]$m['ACTIVE']}else{0}

$state='OFFLINE'
$thinCover=$false
if($reachable -and $asterisk -eq 'active'){
  if(($null -ne $qavail -and $qavail -lt $MinAgents) -or ($null -ne $disk -and $disk -ge 90)){ $state='CRITICAL' }
  elseif(($null -ne $disk -and $disk -ge 75) -or $missedP -gt 0){ $state='DEGRADED' }
  else { $state='READY' }
  # READY but only one answer point available = no backup - flag as thin cover (still ready to answer)
  if($state -eq 'READY' -and $null -ne $qavail -and $qavail -lt ($MinAgents + 1)){ $thinCover=$true }
}

$obj=[ordered]@{
  updated        = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
  state          = $state
  serverIp       = $serverIp
  hostname       = if($m['HOST']){$m['HOST']}else{'upes-ecs-pbx-01'}
  asterisk       = $asterisk
  version        = $m['VER']
  uptime         = $m['UPTIME']
  queueAvailable = $qavail
  minAgents      = $MinAgents
  thinCover      = $thinCover
  registrations  = $regN
  diskPct        = $disk
  missedPending  = $missedP
  activeCalls    = $active
  liveCalls      = $live
  queueMembers   = $qm
  registeredUsers= $reg
  missedRecent   = $missed
  cdr            = $cdr
  recordings     = $rec
  presence       = $pres
  analytics      = $analytics
  shiftLog       = $shiftlog
}
$json = $obj | ConvertTo-Json -Depth 8
[IO.File]::WriteAllText($Out, $json, (New-Object Text.UTF8Encoding($false)))  # no BOM - clean fetch().json()
Write-Host "status.json -> $state  (ip $serverIp, $regN reg, $($qm.Count) members, $active active, $($live.Count) live legs, disk $disk%, $($cdr.Count) cdr, $($rec.Count) rec, $($pres.Count) endpoints)"
