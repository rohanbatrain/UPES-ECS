# Downloads

The git repository is intentionally lightweight — no Git LFS, no committed binaries, so it
clones fast. The ready-to-run artifacts live on
**[GitHub Releases](https://github.com/rohanbatrain/UPES-ECS/releases/latest)** — every file
is **under 2 GB**, so there's **no cloud mirror and no Git LFS**. Large deliverables are split
into GitHub-sized parts (reassembly below).

## Artifacts

| Asset | What it is | Build it yourself |
|---|---|---|
| `UPES-ECS-Setup-1.0.0-x64.exe` **+ `…-1.bin`…`-5.bin`** | Self-contained **offline installer** (QEMU + demo VM + app) — for a target PC with no internet. Download the `.exe` **and all 5 slices** into one folder, run the `.exe`. | `packaging/Build-FatInstaller.ps1` |
| `UPES-ECS-GUI.exe` | Native **GUI installer** (guided setup, 11 languages). | `packaging/Build-Installer.ps1` |
| `voice-prompts.zip` | Pre-generated **Piper TTS prompts**, all 44 languages (optional — regenerated at setup). | `scripts/gen-*-prompts.*` |
| `golden-vm.qcow2.zip.001` / `.002` / `.003` | Prebuilt **Asterisk PBX VM** image, split into volumes. Extract with `7z x golden-vm.qcow2.zip.001` (pulls the rest in). | `deploy/qemu/build-vm.ps1` |

## Which do I need?

!!! tip "Just trying it or developing?"
    You don't need any download. `git clone` + `Install-UpesEcs.ps1` builds everything from
    source (see the [Day-1 quickstart](quickstart.md)).

- **Deploying to an offline machine** → `UPES-ECS-Setup-1.0.0-x64.exe` + all its `.bin` slices.
- **Want the raw VM image** → the three `golden-vm.qcow2.zip.00N` volumes, reassembled as above.
- **Want prebuilt audio instead of regenerating** → `voice-prompts.zip`, unzipped into
  `deploy/asterisk/sounds/`.

## Default credentials (demo appliance)

The prebuilt appliance ships **ready to use** with public **demo** credentials — **no real
users, secrets, or PII**:

- **SIP demo accounts:** `500000001`–`500000003`, `40000001`, `4190`/`4191`, `4390`,
  `590000001` — password **`updemo123`**, server `upes-ecs.local`.
- **VM login:** `ubuntu` / `upesecs`. **Appliance SSH key:** a generic `upes-ecs-default` keypair.

!!! warning "Change these before any real use"
    They are public defaults for evaluation only. Add real users with `deploy\qemu\Add-UpesUser.ps1`,
    rotate the SSH key, and set a real `ubuntu` password. The image regenerates its SSH **host**
    keys on first boot, so no two appliances share a host identity.

## Integrity

Verify the SHA-256 checksums (`SHA256SUMS.txt`, listed on each release) before running:

```powershell
Get-FileHash .\UPES-ECS-Setup-1.0.0-x64.exe -Algorithm SHA256
```
