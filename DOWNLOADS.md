# Downloads

The git repository stays lightweight (no Git LFS, no committed binaries). The large,
ready-to-run artifacts are distributed **out of band**:

- **[GitHub Releases](https://github.com/rohanbatrain/UPES-ECS/releases/latest)** — for
  files up to 2 GB (installers, prompt packs).
- **Cloud mirror** — for anything larger (the golden VM image, full offline bundle). The
  current mirror link is listed on the
  [latest release](https://github.com/rohanbatrain/UPES-ECS/releases/latest).
  <!-- CLOUD_FOLDER_START --><!-- CLOUD_FOLDER_END -->
  <!-- Paste the cloud folder URL between the markers above as a bullet, e.g.:
       - Cloud folder: https://drive.google.com/... -->

  Meanwhile, everything can be **built from source** — no downloads required (`git clone`
  + `Install-UpesEcs.ps1`).

## Artifacts

| Asset | What it is | Size | Build it yourself |
|---|---|---|---|
| `UPES-ECS-Setup-1.0.0-x64.exe` **+ all `…-N.bin` slices** | Self-contained **offline installer** — bundles QEMU, the demo-provisioned Asterisk VM, and the app. Runs on a fresh Windows PC with no internet. Download the `.exe` **and every** `UPES-ECS-Setup-1.0.0-x64-*.bin` into one folder, then run the `.exe`. | ~7.4 GB (6 files) | [`packaging/Build-FatInstaller.ps1`](packaging/Build-FatInstaller.ps1) |
| `UPES-ECS-GUI.exe` | Native **GUI installer** (guided setup, 11 languages). | small | [`packaging/Build-Installer.ps1`](packaging/Build-Installer.ps1) |
| `voice-prompts.zip` | Pre-generated **Piper TTS prompts**, all 44 languages. Optional — `Install-UpesEcs.ps1` regenerates them at setup. | ~815 MB | [`scripts/gen-*-prompts.*`](scripts/) |
| `golden-vm.qcow2.zip.001` / `.002` / `.003` | Prebuilt **Asterisk PBX VM** image (boot-ready), split into GitHub-sized volumes. | ~5.3 GB (3 parts) | [`deploy/qemu/build-vm.ps1`](deploy/qemu/build-vm.ps1) |

All assets live on the [latest release](https://github.com/rohanbatrain/UPES-ECS/releases/latest) (each file < 2 GB); no cloud mirror or Git LFS needed.

### Reassembling the split files

- **Offline installer** — no reassembly: put `UPES-ECS-Setup-1.0.0-x64.exe` and **all** its
  `…-1.bin … -5.bin` slices in the same folder and run the `.exe` (Inno joins the slices itself).
- **Golden VM image** — download all three volumes into one folder, then extract with 7-Zip
  pointed at the **first** part (it pulls in `.002`/`.003` automatically):

  ```powershell
  & "C:\Program Files\7-Zip\7z.exe" x golden-vm.qcow2.zip.001
  # -> upes-ecs-server.qcow2  (boot-ready)
  ```

## Which do I need?

- **Just trying it / developing?** You don't need any of these — `git clone` + `Install-UpesEcs.ps1`
  builds everything from source (see the [Quickstart](https://rohanbatrain.github.io/UPES-ECS/docs/getting-started/quickstart/)).
- **Deploying to an offline machine?** Grab `UPES-ECS-Setup-1.0.0-x64.exe` + all its `.bin` slices.
- **Want the raw VM image?** Grab the three `golden-vm.qcow2.zip.00N` volumes and reassemble (above).
- **Want prebuilt voice audio instead of regenerating?** Grab `voice-prompts.zip` and unzip
  into `deploy/asterisk/sounds/`.

## Default credentials (demo appliance)

The prebuilt appliance (`UPES-ECS-Setup.exe` / `golden-vm.qcow2.zip`) ships **ready to use out
of the box** with well-known **default** credentials — the same public demo roster documented in
[Try the demo](https://rohanbatrain.github.io/UPES-ECS/docs/getting-started/demo.md). It carries
**no real users, secrets, or PII**.

| What | Default | Notes |
|---|---|---|
| SIP demo accounts | ext `500000001`–`500000003`, `40000001`, `4190`/`4191`, `4390`, `590000001` | password **`updemo123`**, server `upes-ecs.local` |
| VM console login | user `ubuntu` / password `upesecs` | local console / SSH |
| Appliance SSH key | bundled `qemu\ssh\upes_key` (generic `upes-ecs-default` keypair) | used by the installer to configure the VM |

> ⚠️ **These are public defaults for evaluation only — change them before any real use.**
> Add real users with `deploy\qemu\Add-UpesUser.ps1` (never hand-edit accounts), rotate the SSH
> key, and set a real `ubuntu` password. The image regenerates its SSH **host** keys on first
> boot, so no two appliances share a host identity.

## Integrity

Each release lists SHA-256 checksums (`SHA256SUMS.txt`) alongside its assets. Verify before running:

```powershell
Get-FileHash .\UPES-ECS-Setup-1.0.0-x64.exe -Algorithm SHA256
```
