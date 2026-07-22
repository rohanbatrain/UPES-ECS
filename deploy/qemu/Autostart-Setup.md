# Setup Notes — Always-On Console Autostart

How to make the UPES-ECS **PBX VM + Operations Console** start automatically at every
logon and stay up on their own — so nobody ever launches `Serve.ps1` by hand.

**No admin required.** This uses the per-user **Startup folder** (not a service / Task
Scheduler, which need elevation).

---

## 1. Install (one time)

Run this **once**. Use the **full path** — the repo is at `C:\Users\Rohan\UPES`, so a
relative path fails if your prompt is somewhere else (e.g. `C:\Users\Rohan`):

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\Rohan\UPES\deploy\qemu\Register-Autostart.ps1
```

Or `cd` into the repo first, then use the relative path:

```powershell
cd C:\Users\Rohan\UPES
powershell -ExecutionPolicy Bypass -File deploy\qemu\Register-Autostart.ps1
```

**Expected output** (both lines must say *installed*, not *SKIP*):

```
installed UPES-ECS-VM.cmd -> C:\Users\Rohan\qemu\start-vm.ps1
installed UPES-ECS-Console.cmd -> C:\Users\Rohan\UPES\Console\Run-Console.ps1 -Port 8080 -RefreshSec 20
```

### If your folders differ

The script defaults to `-QemuDir C:\Users\Rohan\qemu` and
`-ConsoleDir C:\Users\Rohan\UPES\Console`. If either lives elsewhere, pass it:

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\Rohan\UPES\deploy\qemu\Register-Autostart.ps1 `
  -QemuDir C:\Users\Rohan\qemu -ConsoleDir C:\Users\Rohan\UPES\Console
```

A `SKIP …: … not found` line means that path is wrong — fix it and re-run.

---

## 2. What it installs

Two launchers in your Startup folder
(`%AppData%\Microsoft\Windows\Start Menu\Programs\Startup`):

| Launcher | Runs | When |
|---|---|---|
| `UPES-ECS-VM.cmd` | `qemu\start-vm.ps1` (boots the headless Asterisk VM) | at logon |
| `UPES-ECS-Console.cmd` | `Console\Run-Console.ps1` (**supervised** console) | ~25 s after logon (VM head-start) |

Both launch **hidden**. The console launcher runs the **supervisor** `Run-Console.ps1`,
not `Serve.ps1` directly — that is what makes it self-healing.

---

## 3. How "always on + auto-update" works

- **Self-heal** — `Run-Console.ps1` runs `Serve.ps1` and **restarts it automatically** if
  it ever exits (crash, error, or a network change that kills the HTTP listener), with a
  crash-loop backoff. A **global mutex** stops a second copy from double-binding port 8080.
  Restarts are logged to `Console\logs\console-supervisor.log`.
- **Auto-pickup of deploys** — `Serve.ps1` serves `app.js` / `app.css` / `index.html`
  **`no-cache`** and exposes a `/__build` stamp (newest asset mtime). The dashboard polls it
  every ~4 s and **reloads itself** when you change a file — no browser hard-refresh, no
  stale `app.js`. (`.wav` recordings still cache — they're immutable.)
- **Live data** — the wallboard reads the in-VM `/api/status` (live) and falls back to the
  `status.json` snapshot the supervisor refreshes; the in-VM `upes-api` is itself
  `systemd Restart=always`.

Net effect: reboot the laptop and everything comes back by itself; edit a Console file and
every open wallboard updates within seconds.

---

## 4. Verify

```powershell
# launchers present?
dir "$env:AppData\Microsoft\Windows\Start Menu\Programs\Startup\UPES-ECS-*.cmd"

# console reachable? (after ~25 s, or start it now: Console\Run-Console.ps1)
Invoke-WebRequest http://localhost:8080/__build -UseBasicParsing | Select-Object -Expand Content
#   -> {"build":"6386..."}   the dashboard reloads when this number changes
```

Then open **http://localhost:8080** in a browser. To test auto-reload: edit a label in
`Console\app.js`, save, and watch the open page refresh itself within a few seconds.

---

## 5. Update / uninstall

- **Re-run** `Register-Autostart.ps1` any time to refresh the launchers (e.g. after moving
  a folder). It overwrites in place.
- **Uninstall:**
  ```powershell
  powershell -ExecutionPolicy Bypass -File C:\Users\Rohan\UPES\deploy\qemu\Register-Autostart.ps1 -Remove
  ```

---

## 6. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `The argument '…Register-Autostart.ps1' … does not exist` | You ran it from the wrong folder. Use the **full path** (§1). |
| `SKIP …: … not found` | Wrong `-QemuDir` / `-ConsoleDir`. Pass the correct path (§1). |
| Console not on `:8080` after logon | Give it ~25 s (VM head-start). Check `Console\logs\console-supervisor.log`. Start manually to see errors: `powershell -File C:\Users\Rohan\UPES\Console\Run-Console.ps1`. |
| "another supervisor already holds the lock" | A copy is already running (the mutex is doing its job) — not an error. |
| Port 8080 already in use | Install/run with `-Port 8081` (edit the `Args` in `Register-Autostart.ps1`, or pass `-Port` to `Run-Console.ps1`). |
| Other LAN devices can't open the console | `Serve.ps1` binds localhost unless run **elevated**. The wallboard is meant to run **on the laptop**; expose to the LAN only if you intend to. |
| Edits don't show without a manual refresh | Confirm `/__build` returns JSON (§4). If you opened the file via `file://` instead of `http://localhost:8080`, the build check is a no-op by design. |

---

## 7. Assumptions & limits

- **Per-user logon.** Startup-folder launchers fire when *this user logs in* and the
  session stays logged in — the standard no-admin model for this deployment. If the laptop
  can run **elevated**, a boot-time Windows **service** (NSSM / `sc.exe`) would survive a
  logged-out console too; ask and it can be added.
- **VM side** already self-heals independently (`asterisk` and `upes-api` are
  `systemd Restart=always`); this covers the **Windows/Console** side.
- See also: [QEMU server runbook](README.md) · [Console README](../../Console/README.md) ·
  [Register-Autostart.ps1](Register-Autostart.ps1) · [Run-Console.ps1](../../Console/Run-Console.ps1).
