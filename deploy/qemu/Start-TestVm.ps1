# UPES-ECS - launch an ISOLATED, throwaway test VM that CANNOT touch your live VM.
#
# Safety model (why this will not corrupt your existing system):
#   * Copy-on-write overlay: the test disk is a thin qcow2 whose backing file is the
#     golden image opened READ-ONLY. All test writes land in the overlay; the golden /
#     live image is never modified. QEMU's image locking additionally refuses to build
#     an overlay while the live VM holds the golden image, so an accidental overlap is
#     blocked by QEMU itself, not just by convention.
#   * Alternate ports (2322/5062/5234/8090/10100-10119) so nothing clashes with the
#     live VM (2222/5060/5232/8088/10000-10019).
#   * Separate work dir (%USERPROFILE%\qemu-test) and PID file, and it does NOT start
#     the LAN responders (Set-UpesLanIp / Publish-UpesHostname) - so it stays host-local
#     and off the campus LAN / mDNS.
#   * Disk guard: refuses to run if the overlay would drop C: below -MinFreeGB.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File deploy\qemu\Start-TestVm.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File deploy\qemu\Start-TestVm.ps1 -Remove
#
# RECOMMENDED: shut the live VM down first (deploy\qemu\stop-vm.ps1 or kill the PID).
# The overlay build needs read access to the golden image; if the live VM has it locked,
# QEMU will error out clearly - that is the guard working, not a failure of this script.

param(
  [switch]$Remove,          # tear the test VM down and delete its overlay
  [int]$MinFreeGB = 6,      # abort if starting would leave C: below this
  [switch]$Force            # skip the "live VM is running" advisory prompt-equivalent abort
)
$ErrorActionPreference = 'Stop'

$base    = "$env:USERPROFILE\qemu"
$testDir = "$env:USERPROFILE\qemu-test"
$qemu    = "$base\qemu-system-x86_64.exe"
$qemuImg = "$base\qemu-img.exe"
$golden  = "$base\images\upes-ecs-server.qcow2"
$overlay = "$testDir\upes-ecs-test.qcow2"
$pidFile = "$testDir\test-vm.pid"
$serial  = "$testDir\serial.log"

function Stop-TestVm {
  if (Test-Path $pidFile) {
    $tp = Get-Content $pidFile -ErrorAction SilentlyContinue
    if ($tp -and (Get-Process -Id $tp -ErrorAction SilentlyContinue)) {
      Stop-Process -Id $tp -Force -ErrorAction SilentlyContinue
      Write-Output "Stopped test VM (PID $tp)."
    }
    Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
  }
}

if ($Remove) {
  Stop-TestVm
  if (Test-Path $overlay) { Remove-Item $overlay -Force -ErrorAction SilentlyContinue; Write-Output "Deleted overlay $overlay" }
  Write-Output "Test VM removed. Your live VM and golden image were never touched."
  return
}

# --- preflight ---
if (-not (Test-Path $qemu))    { throw "qemu-system-x86_64.exe not found at $qemu. Install/deploy the base VM first." }
if (-not (Test-Path $qemuImg)) { throw "qemu-img.exe not found at $qemuImg." }
if (-not (Test-Path $golden))  { throw "Golden image not found at $golden. Nothing to base a test VM on." }

# Already running?
if (Test-Path $pidFile) {
  $ex = Get-Content $pidFile -ErrorAction SilentlyContinue
  if ($ex -and (Get-Process -Id $ex -ErrorAction SilentlyContinue)) {
    Write-Output "Test VM already running (PID $ex). Use -Remove to stop it."; return
  }
}

# Advisory: warn if the live VM is up (overlay build may be blocked by image lock).
$liveUp = @(Get-Process qemu-system-x86_64 -ErrorAction SilentlyContinue).Count -gt 0
if ($liveUp -and -not $Force) {
  Write-Warning "A QEMU process is already running (likely your LIVE VM)."
  Write-Warning "For a clean, guaranteed-safe test, stop the live VM first, then re-run this."
  Write-Warning "If you understand the overlay is read-only-backed and want to proceed anyway, pass -Force."
  throw "Aborting so nothing overlaps your live VM. (Re-run with -Force to override.)"
}

# Disk guard.
$freeGB = [math]::Round((Get-PSDrive C).Free / 1GB, 1)
if ($freeGB -lt ($MinFreeGB + 1)) {
  throw "Only $freeGB GB free on C:. Need > $($MinFreeGB + 1) GB for a safe test overlay. Free space first."
}

New-Item -ItemType Directory -Force -Path $testDir | Out-Null

# Build a fresh thin COW overlay each run (read-only backing = golden image).
if (Test-Path $overlay) { Remove-Item $overlay -Force -ErrorAction SilentlyContinue }
Write-Output "Creating copy-on-write overlay (backing=golden, read-only)..."
& $qemuImg create -f qcow2 -b $golden -F qcow2 $overlay | Out-Null
if ($LASTEXITCODE -ne 0) { throw "qemu-img failed to create the overlay (is the golden image locked by the live VM?)." }

# Alternate, non-colliding forwards; test VM is host-local only (127.0.0.1) - off the LAN.
$rtp    = (10100..10119 | ForEach-Object { "hostfwd=udp:127.0.0.1:$_-:$($_-100)" }) -join ','
$netdev = "user,id=n0,hostfwd=tcp:127.0.0.1:2322-:22,hostfwd=udp:127.0.0.1:5062-:5060,hostfwd=tcp:127.0.0.1:5234-:5232,hostfwd=tcp:127.0.0.1:8090-:8088,$rtp"

$vmArgs = @(
  '-name','upes-ecs-TEST','-machine','q35','-accel','tcg','-cpu','max',
  '-smp','2','-m','2048','-L',$base,
  '-drive',"file=$overlay,if=virtio,format=qcow2",
  '-netdev',$netdev,
  '-device','virtio-net-pci,netdev=n0',
  '-display','none','-serial',"file:$serial"
)
$p = Start-Process $qemu -ArgumentList $vmArgs -WindowStyle Hidden -PassThru
$p.Id | Out-File $pidFile -Encoding ascii

Write-Output ""
Write-Output "ISOLATED TEST VM started (PID $($p.Id)). Your live VM/golden image are untouched."
Write-Output "  Overlay disk : $overlay  (thin; delete anytime with -Remove)"
Write-Output "  SSH          : ssh -p 2322 ubuntu@127.0.0.1"
Write-Output "  Console/WS   : http://127.0.0.1:8090"
Write-Output "  SIP (local)  : 127.0.0.1:5062   RTP 10100-10119 -> guest 10000-10019"
Write-Output "  Serial log   : $serial"
Write-Output ""
Write-Output "Tear down when done:  powershell -File deploy\qemu\Start-TestVm.ps1 -Remove"
