#!/usr/bin/env bash
# Prove a live RTP audio session to a registered softphone: dial 111 and sample
# Asterisk's channel RTP stats mid-call. Rising Tx/Rx packet counts = real audio.
set -e
BD=/root/.baresip

# minimal config: register only; audio device irrelevant for this proof
cat > "$BD/config" <<EOF
module_path             /usr/lib/baresip/modules
module                  stun.so
module                  account.so
module                  contact.so
module                  menu.so
module                  ctrl_tcp.so
module                  g711.so
ctrl_tcp_listen         127.0.0.1:4444
sip_listen              0.0.0.0:5080
rtp_ports               11000-11100
EOF
cat > "$BD/accounts" <<EOF
<sip:1001@127.0.0.1;transport=udp>;auth_user=1001;auth_pass=change-me-1001;audio_codecs=PCMU,PCMA;regint=60
EOF

pkill -x baresip 2>/dev/null || true; sleep 1
baresip -f "$BD" >/tmp/baresip.log 2>&1 &
BSPID=$!
sleep 4
echo "== REGISTERED? =="; asterisk -rx "pjsip show contacts" | grep -iE "1001|Objects" | head

echo ""; echo "== dialing 111 =="
python3 - <<'PY'
import socket,json,time
def ns(d): b=d.encode(); return str(len(b)).encode()+b":"+b+b","
s=socket.create_connection(("127.0.0.1",4444),timeout=5)
s.sendall(ns(json.dumps({"command":"dial","params":"111","token":"t"})))
s.close()
PY

echo ""; echo "== RTP stats sampled during the call (watch Tx/Rx grow) =="
for i in 1 2 3 4; do
  sleep 3
  echo "--- sample $i (t=$((i*3))s) ---"
  asterisk -rx "pjsip show channelstats" 2>/dev/null | grep -iE "Bridgeid|1001|111|Tx:|Rx:" | head -6 || true
done

echo ""; echo "== hang up + CDR =="
python3 - <<'PY'
import socket,json,time
def ns(d): b=d.encode(); return str(len(b)).encode()+b":"+b+b","
s=socket.create_connection(("127.0.0.1",4444),timeout=5)
s.sendall(ns(json.dumps({"command":"hangup","params":"","token":"t"}))); s.close()
PY
sleep 2
tail -2 /var/log/asterisk/cdr-csv/Master.csv 2>/dev/null | sed 's/,,*/ | /g'
echo ""; echo "== recording size after continuous-record fix =="
ls -la /var/spool/asterisk/monitor/upes-ecs/*.wav 2>/dev/null | tail -1
kill $BSPID 2>/dev/null || true
echo "RTP-PROOF-DONE"
