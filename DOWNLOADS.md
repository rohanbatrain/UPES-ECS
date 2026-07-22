# Downloads

The git repository stays lightweight (no Git LFS, no committed binaries). The large,
ready-to-run artifacts are distributed **out of band**:

- **[GitHub Releases](https://github.com/rohanbatrain/UPES-ECS/releases/latest)** — for
  files up to 2 GB (installers, prompt packs).
- **Cloud mirror** — for anything larger (the golden VM image, full offline bundle):
  <!-- CLOUD_FOLDER_START -->
  _link coming soon — will be added here._
  <!-- CLOUD_FOLDER_END -->

## Artifacts

| Asset | What it is | Size | Where | Build it yourself |
|---|---|---|---|---|
| `UPES-ECS-Setup.exe` | Self-contained **offline installer** — bundles QEMU, the golden Asterisk VM, and the app. Runs on a fresh Windows PC with no internet. | large | Release / cloud | [`packaging/Build-FatInstaller.ps1`](packaging/Build-FatInstaller.ps1) |
| `UPES-ECS-GUI.exe` | Native **GUI installer** (guided setup). | small | Release | [`packaging/Build-Installer.ps1`](packaging/Build-Installer.ps1) |
| `voice-prompts.zip` | Pre-generated **Piper TTS prompts**, all 44 languages. Optional — `Install-UpesEcs.ps1` regenerates them at setup. | ~1 GB | Release / cloud | [`scripts/gen-*-prompts.*`](scripts/) |
| `golden-vm.qcow2.zip` | Prebuilt **Asterisk PBX VM** image (boot-ready). | multi-GB | Cloud | [`deploy/qemu/build-vm.ps1`](deploy/qemu/build-vm.ps1) |

## Which do I need?

- **Just trying it / developing?** You don't need any of these — `git clone` + `Install-UpesEcs.ps1`
  builds everything from source (see the [Quickstart](https://rohanbatrain.github.io/UPES-ECS/docs/getting-started/quickstart/)).
- **Deploying to an offline machine?** Grab `UPES-ECS-Setup.exe` (the offline installer).
- **Want prebuilt voice audio instead of regenerating?** Grab `voice-prompts.zip` and unzip
  into `deploy/asterisk/sounds/`.

## Integrity

Each release lists SHA-256 checksums alongside its assets. Verify before running:

```powershell
Get-FileHash .\UPES-ECS-Setup.exe -Algorithm SHA256
```
