#!/usr/bin/env bash
# Register a real softphone (baresip) to the WSL Asterisk and place a live call to 111.
# Proof of audio: the softphone sends a 440 Hz tone (ausine); Asterisk's MixMonitor on
# the 111 call records it — a non-empty recording proves real RTP audio reached 111.
set -e
BD=/root/.baresip
MODP=/usr/lib/baresip/modules
mkdir -p "$BD"

cat > "$BD/config" <<EOF
module_path             $MODP
module                  stun.so
module                  account.so
module                  contact.so
module                  menu.so
module                  ctrl_tcp.so
module                  g711.so
module                  ausine.so
module                  aufile.so
audio_source            aufile,/tmp/tone.wav
audio_player            aufile,/tmp/baresip-rx.wav
ctrl_tcp_listen         127.0.0.1:4444
sip_listen              0.0.0.0:5080
rtp_ports               11000-11100
EOF

cat > "$BD/accounts" <<EOF
<sip:1001@127.0.0.1;transport=udp>;auth_user=1001;auth_pass=change-me-1001;audio_codecs=PCMU,PCMA;regint=60
EOF

rm -f /var/spool/asterisk/monitor/upes-ecs/*.wav /tmp/baresip-rx.wav 2>/dev/null || true

# Generate a real 8 kHz tone for the softphone to SEND (matches PCMU 8kHz, no resample).
sox -n -r 8000 -c 1 /tmp/tone.wav synth 15 sine 440 2>/dev/null && echo "tone.wav generated" || echo "sox tone gen FAILED"

echo "== starting softphone (baresip) =="
baresip -f "$BD" >/tmp/baresip.log 2>&1 &
BSPID=$!
sleep 5
echo "-- REGISTRATION --"
grep -iE "register|unregister|200 ok|account" /tmp/baresip.log | tail -6
asterisk -rx "pjsip show endpoint 1001" | grep -iE "Contact:|Aor|Avail|Unavail" | head -4

echo ""; echo "== DIAL 111 (12s call) =="
python3 - <<'PY'
import socket, json, time
def ns(d):
    b=d.encode(); return str(len(b)).encode()+b":"+b+b","
s=socket.create_connection(("127.0.0.1",4444),timeout=5)
s.sendall(ns(json.dumps({"command":"dial","params":"111","token":"t1"})))
time.sleep(12)
s.sendall(ns(json.dumps({"command":"hangup","params":"","token":"t2"})))
time.sleep(1); s.close(); print("dial + hangup sent")
PY

sleep 2
echo ""; echo "-- CALL LOG (softphone side) --"
grep -iE "call|established|answered|audio|codec|rtp" /tmp/baresip.log | tail -12
echo ""; echo "-- ASTERISK recording of the 111 call (proof of audio) --"
ls -la /var/spool/asterisk/monitor/upes-ecs/*.wav 2>/dev/null
echo ""; echo "-- recording duration/content --"
for f in /var/spool/asterisk/monitor/upes-ecs/*.wav; do [ -f "$f" ] && soxi "$f" 2>/dev/null | grep -iE "Duration|Sample" ; done 2>/dev/null || echo "(soxi not installed; size shown above)"
echo ""; echo "-- softphone received audio (Asterisk prompt) --"
ls -la /tmp/baresip-rx.wav 2>/dev/null

kill $BSPID 2>/dev/null || true
echo "CALL-TEST-DONE"
