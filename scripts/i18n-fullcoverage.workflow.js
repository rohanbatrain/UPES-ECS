export const meta = {
  name: 'i18n-full-coverage',
  description: 'One agent per language: translate voice prompts + UI, download Piper voice, generate 42 WAVs. Full 44-language coverage (AI first-pass, staged, needs native review).',
  phases: [
    { title: 'Localize' },
  ],
}

// 38 languages that are still empty worksheets (en + 5 Indian langs already done).
const LANGS = [
  'ar','bg','ca','cs','cy','da','de','el','es','eu','fa','fi','fr','hu','id','is',
  'it','ka','kk','ku','lb','lv','nl','no','pl','pt','ro','ru','sk','sl','sq','sr',
  'sv','sw','tr','uk','vi','zh',
]

const REPO = 'c:\\Users\\Rohan\\UPES'

const SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['code','status','csv_filled','wav_count','ui_keys_translated','model_downloaded','errors'],
  properties: {
    code: { type: 'string' },
    status: { type: 'string', enum: ['complete','partial','failed'] },
    csv_filled: { type: 'integer', description: 'rows of the 42-prompt CSV filled with translation' },
    wav_count: { type: 'integer', description: 'WAV files produced in deploy/asterisk/sounds/lang/<code>' },
    ui_keys_translated: { type: 'integer', description: 'keys written to Console/ui-lang/<code>.json' },
    model_downloaded: { type: 'boolean' },
    errors: { type: 'array', items: { type: 'string' } },
    notes: { type: 'string' },
  },
}

function prompt(code) {
  return `You are localizing the UPES-ECS campus EMERGENCY communication system into ONE language: "${code}".
Repo root: ${REPO}. This is a real safety system (CPR, bleeding, fire, lockdown coaching). Your output is an
AI FIRST-PASS DRAFT that will be staged and MUST be reviewed by a native speaker before real go-live — accuracy
of every instruction and its ORDER is safety-critical. Do not add, drop, or reorder any step.

Do these SIX steps in order. Use the Read tool for files and the PowerShell/Bash tools for commands.

STEP 0 — Read your reference material:
  - ${REPO}\\i18n\\languages.json  -> find the object whose "code" == "${code}". Note its piper_voice, piper_url,
    piper_config_url, native name, and rtl flag.
  - ${REPO}\\i18n\\prompts.catalog.json  -> the 42 canonical prompts. For each prompt you need its "id", "en"
    text, and "notes" (per-prompt translation rules).
  - ${REPO}\\i18n\\translations\\hi-translations.json  -> the GOLD-STANDARD example of format & conventions.
    Mirror its style exactly.

STEP 1 — Translate the 42 voice prompts. Write ${REPO}\\i18n\\translations\\${code}-translations.json as a JSON
object { "<prompt id>": "<translation in ${code}>", ... } for ALL 42 ids, plus a leading "_note" key stating it
is an AI first-pass draft needing native review. Rules (follow the per-prompt "notes"):
  - Translate MEANING faithfully; calm, clear, unhurried emergency tone. Keep every step and its order.
  - DTMF / key prompts ("Press 1", "Press 2"...): keep the SAME key as English (never remap which number),
    spoken naturally in ${code} (e.g. Hindi wrote "एक दबाएँ" for "press 1"). Star codes like *23 -> keep the
    same digit sequence spoken naturally ("star two three"), as hi-translations.json does.
  - Keep the brand "UPES" recognizable. Keep phone/extension numbers unchanged.

STEP 2 — Merge into the worksheet CSV (deterministic, no hand-editing of CSV):
  powershell -ExecutionPolicy Bypass -File ${REPO}\\scripts\\apply-translations.win.ps1 -Lang ${code}
  It must print "filled 42/42 rows". If it reports MISSING ids, fix your ${code}-translations.json and re-run.

STEP 3 — Download the Piper voice model into C:\\Users\\Rohan\\piper-model (skip a file if it already exists and
  is > 1 MB). Use the piper_url and piper_config_url from languages.json. Save with the EXACT names
  <piper_voice>.onnx and <piper_voice>.onnx.json. Robust download, e.g.:
    curl -L -f --retry 3 -o "C:\\Users\\Rohan\\piper-model\\<piper_voice>.onnx" "<piper_url>"
    curl -L -f --retry 3 -o "C:\\Users\\Rohan\\piper-model\\<piper_voice>.onnx.json" "<piper_config_url>"
  Verify the .onnx is > 1 MB. If the download fails after retries, record it in errors and continue to STEP 5.

STEP 4 — Generate the 42 WAVs (only if the model downloaded):
  powershell -ExecutionPolicy Bypass -File ${REPO}\\scripts\\gen-lang-prompts.win.ps1 -Lang ${code}
  Then COUNT the WAVs produced:
    powershell -Command "(Get-ChildItem -Recurse -Filter *.wav '${REPO}\\deploy\\asterisk\\sounds\\lang\\${code}').Count"
  Expect 42. Piper is CPU-bound and other languages are generating at the same time, so it may take a few minutes.

STEP 5 — Translate the dashboard UI. Read ${REPO}\\Console\\ui-lang\\en.json (a flat JSON map, ~679 keys where
  key == English value). Write ${REPO}\\Console\\ui-lang\\${code}.json with the SAME keys byte-for-byte, and each
  VALUE translated into ${code}. Keep proper nouns (UPES, ERT), extension numbers, star/DTMF codes, and pure
  numbers unchanged. Output must be valid UTF-8 JSON with exactly the same set of keys as en.json.

STEP 6 — Report. Return the structured result: code="${code}", csv_filled (from step 2), wav_count (from step 4),
  ui_keys_translated (count of keys you wrote), model_downloaded, status ("complete" only if csv_filled==42 AND
  wav_count==42 AND ui_keys_translated matches en.json's key count), and any errors. Do NOT edit languages.json.`
}

phase('Localize')
log(`Localizing ${LANGS.length} languages, one agent each (full voice + UI + Piper audio).`)

const results = await parallel(
  LANGS.map((code) => () =>
    agent(prompt(code), {
      label: `lang:${code}`,
      phase: 'Localize',
      schema: SCHEMA,
    })
  )
)

const done = results.filter(Boolean)
const complete = done.filter((r) => r.status === 'complete')
const partial = done.filter((r) => r.status === 'partial')
const failed = done.filter((r) => r.status === 'failed')
const nullCount = results.length - done.length

log(`Done: ${complete.length} complete, ${partial.length} partial, ${failed.length} failed, ${nullCount} dropped.`)

return {
  requested: LANGS.length,
  complete: complete.map((r) => r.code).sort(),
  partial: partial.map((r) => ({ code: r.code, csv: r.csv_filled, wav: r.wav_count, ui: r.ui_keys_translated, errors: r.errors })),
  failed: failed.map((r) => ({ code: r.code, errors: r.errors })),
  dropped: nullCount,
  per_language: done,
}
