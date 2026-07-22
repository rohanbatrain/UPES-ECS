# Downloads

The git repository is intentionally lightweight — no Git LFS, no committed binaries, so it
clones fast. The large, ready-to-run artifacts are distributed **out of band**:

- **[GitHub Releases](https://github.com/rohanbatrain/UPES-ECS/releases/latest)** — files up
  to 2 GB (installers, prompt packs).
- **Cloud mirror** — anything larger (golden VM image, full offline bundle). *(Link added on
  the [release page](https://github.com/rohanbatrain/UPES-ECS/releases/latest) and in
  [DOWNLOADS.md](https://github.com/rohanbatrain/UPES-ECS/blob/main/DOWNLOADS.md).)*

## Artifacts

| Asset | What it is | Build it yourself |
|---|---|---|
| `UPES-ECS-Setup.exe` | Self-contained **offline installer** (QEMU + golden VM + app) — for a target PC with no internet. | `packaging/Build-FatInstaller.ps1` |
| `UPES-ECS-GUI.exe` | Native **GUI installer**. | `packaging/Build-Installer.ps1` |
| `voice-prompts.zip` | Pre-generated **Piper TTS prompts**, all 44 languages (optional — regenerated at setup). | `scripts/gen-*-prompts.*` |
| `golden-vm.qcow2.zip` | Prebuilt **Asterisk PBX VM** image. | `deploy/qemu/build-vm.ps1` |

## Which do I need?

!!! tip "Just trying it or developing?"
    You don't need any download. `git clone` + `Install-UpesEcs.ps1` builds everything from
    source (see the [Day-1 quickstart](quickstart.md)).

- **Deploying to an offline machine** → `UPES-ECS-Setup.exe`.
- **Want prebuilt audio instead of regenerating** → `voice-prompts.zip`, unzipped into
  `deploy/asterisk/sounds/`.

## Integrity

Verify the SHA-256 checksum (listed on each release) before running:

```powershell
Get-FileHash .\UPES-ECS-Setup.exe -Algorithm SHA256
```
