#!/usr/bin/env bash
#
# macos-mock-driver.sh -- runs INSIDE a Linux container with mock-Darwin stubs on
# PATH. This is SHELL-LOGIC VALIDATION VIA MOCK, **NOT a macOS runtime test**.
# Real macOS cannot boot in a normal Linux container, so we cannot exercise the
# real launchd / Homebrew / Asterisk. What we DO prove:
#   * install-macos.sh is `bash -n` clean and runs to completion under
#     `set -euo pipefail` (no unbound vars, no bad path joins);
#   * the arm64 (/opt/homebrew) vs Intel (/usr/local) brew-prefix branch both work;
#   * the launchd .plist files it generates are WELL-FORMED (parsed by plistlib);
#   * asterisk.conf / pjsip.conf / macos.env it writes are coherent;
#   * the ProgramArguments point at the resolved binaries under the chosen prefix.
#
# Repo is bind-mounted read-only at /repo; transcript -> /out.
set -uo pipefail

LANG_CODE="${1:-hi}"
OUT="${OUT:-/out/transcript-macos-mock.txt}"
mkdir -p "$(dirname "$OUT")"
exec > >(tee "$OUT") 2>&1

STUBS=/mockbin
export MOCK_LOG=/tmp/mock-calls.log
: > "$MOCK_LOG"

PASS=0; FAIL=0; declare -a RESULTS=()
check(){ local n="$1" rc="$2"; if [ "$rc" -eq 0 ]; then RESULTS+=("PASS  $n"); PASS=$((PASS+1)); else RESULTS+=("FAIL  $n"); FAIL=$((FAIL+1)); fi; }
hr(){ echo "-------------------------------------------------------------------"; }
sec(){ echo; echo "###################################################################"; echo "### $*"; echo "###################################################################"; }

sec "0. DISCLAIMER"
cat <<'EOF'
  This is SHELL-LOGIC VALIDATION VIA A MOCK-DARWIN HARNESS.
  It is NOT a macOS runtime test. brew/asterisk/launchctl/ipconfig/sw_vers are
  STUBS on PATH; the host kernel is Linux. Treat every PASS below as "the installer
  script's control flow / file generation is sound", NOT "Asterisk answered on a Mac".
  The only real, fast macOS validation is a 5-minute run on actual Mac hardware.
EOF
. /etc/os-release 2>/dev/null || true
echo "Container base : ${PRETTY_NAME:-unknown}  (kernel $(/bin/uname -s)/$(/bin/uname -m))"
echo "Stubs on PATH  : $(ls "$STUBS" | tr '\n' ' ')"

sec "1. Static checks: bash -n + python compile"
cp -a /repo /work
INS=/work/deploy/macos/install-macos.sh
bash -n "$INS"; check "install-macos.sh passes bash -n" $?
bash -n /work/deploy/macos/run-foreground.sh; check "run-foreground.sh passes bash -n" $?
python3 -m py_compile /work/deploy/macos/serve-console.py; check "serve-console.py compiles" $?
if command -v shellcheck >/dev/null 2>&1; then
  echo "--- shellcheck (informational) ---"; shellcheck -S warning "$INS" || true
fi

run_install() {  # <label> <brew-prefix> <uname-m> <home>
  local label="$1" prefix="$2" arch="$3" home="$4"
  sec "RUN [$label]: MOCK_BREW_PREFIX=$prefix  MOCK_UNAME_M=$arch"
  rm -rf "$home"; mkdir -p "$home"
  # Fresh brew prefix + a clean /opt/upes-ecs so this run stands alone.
  rm -rf "$prefix/etc/asterisk" /opt/upes-ecs
  : > "$MOCK_LOG"
  PATH="$STUBS:/usr/bin:/bin:/usr/sbin:/sbin" \
  HOME="$home" \
  MOCK_BREW_PREFIX="$prefix" MOCK_UNAME_M="$arch" MOCK_UNAME_S=Darwin \
  MOCK_LAN_IP=192.168.7.42 \
    bash "$INS" --language "$LANG_CODE" --lan-ip 192.168.7.42
  local rc=$?
  echo "INSTALLER-EXIT-CODE[$label]=$rc"
  check "[$label] install-macos.sh runs to completion (exit 0) under set -euo pipefail" "$rc"
  return 0
}

#--------------------------------------------------------------------------------
# ARM64 run (Apple-Silicon-style: brew prefix /opt/homebrew)
#--------------------------------------------------------------------------------
run_install "arm64" "/opt/homebrew" "arm64" "/root/home-arm64"
ARM_PREFIX=/opt/homebrew
ARM_HOME=/root/home-arm64

sec "2. [arm64] Generated launchd plists are WELL-FORMED"
LA="$ARM_HOME/Library/LaunchAgents"
echo "LaunchAgents dir: $LA"; ls -l "$LA" 2>/dev/null
for pl in com.upes-ecs.asterisk com.upes-ecs.api com.upes-ecs.console; do
  f="$LA/$pl.plist"
  if [ -f "$f" ]; then
    python3 - "$f" <<'PY'
import plistlib,sys
p=sys.argv[1]
with open(p,'rb') as fh: d=plistlib.load(fh)
assert d.get('Label'), "no Label"
assert isinstance(d.get('ProgramArguments'), list) and d['ProgramArguments'], "no ProgramArguments"
print("  OK  %-26s Label=%s  Prog[0]=%s" % (p, d['Label'], d['ProgramArguments'][0]))
PY
    check "[arm64] $pl.plist is valid plist XML (plistlib)" $?
  else
    echo "  MISSING $f"; check "[arm64] $pl.plist exists" 1
  fi
done
echo "--- asterisk plist ProgramArguments (should reference $ARM_PREFIX) ---"
sed -n '/ProgramArguments/,/\/array/p' "$LA/com.upes-ecs.asterisk.plist" 2>/dev/null
grep -q "$ARM_PREFIX" "$LA/com.upes-ecs.asterisk.plist" 2>/dev/null
check "[arm64] asterisk plist points at the arm64 brew prefix ($ARM_PREFIX)" $?

sec "3. [arm64] Config files written under the brew prefix"
AE="$ARM_PREFIX/etc/asterisk"
echo "asterisk.conf directories block:"; sed -n '1,20p' "$AE/asterisk.conf" 2>/dev/null
grep -q "astetcdir[[:space:]]*=>[[:space:]]*$AE" "$AE/asterisk.conf" 2>/dev/null
check "[arm64] asterisk.conf astetcdir points under $ARM_PREFIX" $?
grep -q '^live_dangerously = yes' "$AE/asterisk.conf" 2>/dev/null
check "[arm64] asterisk.conf enables live_dangerously (emergency dialplan needs it)" $?
echo "pjsip external addresses:"; grep -nE '^external_(media|signaling)_address=' "$AE/pjsip.conf" 2>/dev/null
grep -qE '^external_media_address=192\.168\.7\.42' "$AE/pjsip.conf" 2>/dev/null
check "[arm64] pjsip.conf external_media_address set to the (mock) LAN IP" $?
echo "111 emergency context present in deployed dialplan?"
grep -rq 'ctx_emergency_111' "$AE"/extensions*.conf 2>/dev/null
check "[arm64] emergency 111 dialplan (ctx_emergency_111) deployed to $AE" $?
echo "language pack present under prefix sounds?"
ls "$ARM_PREFIX/share/asterisk/sounds/$LANG_CODE" >/dev/null 2>&1
check "[arm64] language pack '$LANG_CODE' laid down under prefix sounds" $?

sec "4. [arm64] macos.env sanity"
echo "--- /opt/upes-ecs/macos.env ---"; cat /opt/upes-ecs/macos.env 2>/dev/null
grep -q "BREW_PREFIX=\"$ARM_PREFIX\"" /opt/upes-ecs/macos.env 2>/dev/null
check "[arm64] macos.env records the resolved brew prefix" $?

sec "5. [arm64] Secret scan of the deployed payload"
ACC="$AE/pjsip_accounts.conf"
S=$(grep -cE '^[[:space:]]*password=' "$ACC" 2>/dev/null || echo 0)
echo "  password= lines in deployed pjsip_accounts.conf: $S"
grep -nE '^[[:space:]]*password=' "$ACC" 2>/dev/null | head -3 | sed -E 's/(password=).{4}.*/\1****REDACTED****/'
echo "NOTE: install-macos.sh copies deploy/asterisk/pjsip_accounts.conf verbatim, which"
echo "      currently ships REAL SIP secrets (its inline comment calling it a 'clean stub'"
echo "      is inaccurate). Same single-source-of-truth posture as Linux -- must not be"
echo "      web-served. Flagged for the macOS agent in REPORT.md."

#--------------------------------------------------------------------------------
# INTEL run (x86_64-style: brew prefix /usr/local) -- prove the prefix branch
#--------------------------------------------------------------------------------
run_install "intel" "/usr/local" "x86_64" "/root/home-intel"
INT_PREFIX=/usr/local
INT_HOME=/root/home-intel
sec "6. [intel] Prefix branch lands under /usr/local"
LA2="$INT_HOME/Library/LaunchAgents"
grep -q "$INT_PREFIX" "$LA2/com.upes-ecs.asterisk.plist" 2>/dev/null
check "[intel] asterisk plist points at the Intel brew prefix ($INT_PREFIX)" $?
grep -q "astetcdir[[:space:]]*=>[[:space:]]*$INT_PREFIX/etc/asterisk" "$INT_PREFIX/etc/asterisk/asterisk.conf" 2>/dev/null
check "[intel] asterisk.conf astetcdir points under $INT_PREFIX" $?
python3 - "$LA2/com.upes-ecs.api.plist" <<'PY' && RC=0 || RC=1
import plistlib,sys
with open(sys.argv[1],'rb') as fh: plistlib.load(fh)
print("  intel api plist parses OK")
PY
check "[intel] api plist is valid plist XML" "$RC"

sec "7. Mock-call log (evidence the stubs were exercised)"
echo "unique mock commands invoked in the intel run:"
sort -u "$MOCK_LOG" | sed -E 's/^\[mock ([a-z_]+)\].*/\1/' | sort -u

sec "RESULT SUMMARY (shell-logic mock, NOT a macOS runtime test)"
for r in "${RESULTS[@]}"; do echo "  $r"; done
echo; echo "TOTAL: PASS=$PASS FAIL=$FAIL"
if [ "$FAIL" -eq 0 ]; then echo "OVERALL: PASS (mock logic)"; exit 0; else echo "OVERALL: FAIL"; exit 1; fi
