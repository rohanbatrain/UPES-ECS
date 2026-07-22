# UPES-ECS - Regional / multi-language deployment

This is the **easy path** for standing up (or re-languaging) the campus emergency PBX.
If you are not a sysadmin, read only the first section.

---

## 1. The easy path (what you actually do)

1. Copy the whole `UPES` folder onto the PC (USB stick or download).
2. **Double-click `Deploy-UPES.cmd`.**
3. In the window that opens:
   - Pick your **Region / language** (e.g. `English` or `हिन्दी (Hindi)`).
   - Click the big green **Deploy** button.
4. Wait. The log fills in as it works (first run takes a few minutes - it downloads and
   builds the phone system). When it finishes you get a popup:

   ```
   Phones register to  <this PC's IP>:5060
   Emergency number    dial 111
   Console             http://localhost:8080
   ```

That's it. Phones on the same network register to that IP and dial **111** for emergencies.
Everything auto-starts again on every Windows logon - you never have to re-run this.

**To change the campus default language later:** just double-click `Deploy-UPES.cmd` again, pick
the new language, and Deploy. It does not rebuild the whole system - it installs the voice packs
and sets the default. **Individual callers can each have their own language** (next section).

---

## 2. What "language" actually changes (per-caller routing)

The system speaks in three places: the emergency line **111**, the panic-coach **102**, and the
drill line **199**. Each language ships a set of pre-recorded voice files (a "prompt pack").

**The campus can speak many languages at once - each caller hears their own.** On every call the
dialplan looks up the caller's language and plays that pack, falling back file-by-file to English
for anything not yet translated (so nothing ever breaks). Resolution order, all offline:

1. **The caller's personal preference** - `provisioning/user-languages.csv` (`ext,lang`), set per
   person (see §4b) or from the app.
2. **The campus default** - the language you pick in the GUI / `-Language` flag.
3. **English** - the built-in, always-complete fallback.

How the packs are stored:

- **English** is built in - always available, and is **never overwritten** (it is the safety net).
- **Other languages** each install into their **own** folder `sounds/<code>/` inside the VM, from
  a prompt pack at `deploy/asterisk/sounds/lang/<code>/`, down-sampled to phone quality (8 kHz)
  automatically. Every built pack is installed, not just the default.
- If you pick a **default** language whose pack isn't there yet, unmapped callers hear English and
  the tool tells you so.

Callers can also press **`*`** during the panic-coach to change language for that call.
The list of languages in the dropdown comes from `i18n/languages.json`.

---

## 3. Where the active region is recorded - `Console/region.json`

After every deploy, the tool writes **`Console/region.json`** - the single record of what
language is currently live. The Operations Console dashboard reads it. Example:

```json
{
  "schema": "upes-ecs.region/v1",
  "language": "hi",
  "languageName": "Hindi",
  "native": "हिन्दी",
  "prompts": "packed",
  "source": "local",
  "deployedAt": "2026-07-08T06:52:15Z"
}
```

- `prompts`: `"packed"` = the chosen language's voice files were installed;
  `"english-fallback"` = the pack was missing so English was kept.
- `source`: `"local"` = deployed from this folder; otherwise the URL/path it was fetched from.

---

## 4. Adding a new region / language

1. Add the language to `i18n/languages.json` (code, name, native name, voice) - this makes it
   appear in the dropdown. *(That file is owned by the i18n work, not this deploy tool.)*
2. Generate its prompt pack on the Windows host:

   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\gen-lang-prompts.win.ps1 -Lang <code>
   ```

   This writes the `.wav` files to `deploy/asterisk/sounds/lang/<code>/`, mirroring the
   English layout under `deploy/asterisk/sounds/en/` (`custom/…`, `upes-ecs/…`,
   `upes-ecs/coach/…`).
3. Double-click `Deploy-UPES.cmd`, pick the new language (as the default) and/or just Deploy -
   **every** built pack is installed into its own `sounds/<code>/`, so the language is available
   for per-caller routing even if it isn't the campus default. Done.

**Check coverage before shipping a language** - every one of the 42 catalog prompts must be
translated (no English-fallback holes):

```powershell
powershell -File i18n\Check-PromptCoverage.ps1                     # all languages
powershell -File i18n\Check-PromptCoverage.ps1 -Langs hi,te,ml,ur,ne -FailOnGap
```

All 43 non-English languages currently report `[100%] 42/42`. Non-English/Hindi translations are
AI drafts - have a native speaker review the safety-critical coach prompts before go-live.

> The prompt pack layout **must mirror `sounds/en/`** exactly (same relative file paths). Each
> file installs to `/usr/share/asterisk/sounds/<code>/<same-path>` inside the VM (its own language
> folder - **English is never touched**), which is exactly where the dialplan's
> `CHANNEL(language)=<code>` makes Asterisk look. A partial pack simply leaves the untranslated
> prompts in English, per file.

---

## 4b. Giving a specific person their own language

Per-user language lives in `provisioning/user-languages.csv` (`ext,lang`) - the single source of
truth. Set it when adding/asserting a user:

```powershell
powershell -File deploy\qemu\Add-UpesUser.ps1 -SapId 500120597 -Name "Rohan Batra" -Lang hi
```

This upserts the CSV, writes `lang` into `Console/directory.json`, and applies it to the live PBX
immediately (`database put lang <ext> <code>`), so that caller hears Hindi on their very next 111
call. Re-running `Install-UpesEcs.ps1` re-syncs the whole CSV into the PBX (`Sync-LangDb`). A caller
with no entry hears the campus default. The mobile app can set this too (writes the same store).

---

## 5. "Fetch latest before deploying" - release bundles (advanced)

The optional checkbox + **Source** field (or `Install-UpesEcs.ps1 -Source <…>`) deploys from a
**release bundle** instead of the local folder.

**Bundle format:** a `.zip` of the repo, containing at its root (or one folder down):

```
config/  scripts/  deploy/  api/  Console/  i18n/  Install-UpesEcs.ps1
```

`-Source` accepts any of:

| Source                                   | Behaviour                                                        |
|------------------------------------------|-----------------------------------------------------------------|
| `https://…/upes-ecs.zip`                 | downloaded, extracted to `<Base>\repo`, deployed from there      |
| `C:\path\to\upes-ecs.zip`                | extracted to `<Base>\repo`, deployed from there                  |
| `C:\path\to\a\repo\folder`               | used in place (already a repo copy)                              |
| *(unset - the default)*                  | deploys from the current folder, fully offline                   |

The extracted copy lives under `<Base>\repo` (default `%USERPROFILE%\qemu\repo`) so the Console
it serves stays put across reboots. The fetched source is recorded in `Console/region.json`.

---

## 6. Command line (for scripts / sysadmins)

The GUI is just a front end for the installer. Equivalent commands:

```powershell
# English (default), from this folder
powershell -ExecutionPolicy Bypass -File Install-UpesEcs.ps1

# Hindi prompts
powershell -ExecutionPolicy Bypass -File Install-UpesEcs.ps1 -Language hi

# Deploy a fetched release bundle in French
powershell -ExecutionPolicy Bypass -File Install-UpesEcs.ps1 -Language fr -Source https://example/upes-ecs.zip

# Dry run - validate the language + write region.json, touch nothing else
powershell -ExecutionPolicy Bypass -File Install-UpesEcs.ps1 -Language hi -DryRun
```

All existing installer switches still work (`-LanIp`, `-Base`, `-Rebuild`, `-LaunchTV`,
`-NoConsole`, `-Uninstall`). English remains the default; every prior behaviour is unchanged.
