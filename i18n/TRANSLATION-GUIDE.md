# UPES-ECS Translation Guide

**For the language expert translating the campus emergency voice prompts.**

Thank you for helping. This short guide tells you everything you need to
translate the prompts safely and consistently. You do **not** need any
technical knowledge — you only edit one column in a spreadsheet.

---

## 1. What you are translating, and why it matters

UPES-ECS is the **campus emergency phone system**. When something goes wrong
on campus — a fire, a medical emergency, a lockdown, an evacuation — the
system plays these recorded messages down the phone to students and staff.

These are **life-safety messages**. Someone frightened, injured, or in danger
will hear your words and act on them. That makes your job different from
normal translation:

- **Accuracy is safety.** These are step-by-step first-aid and evacuation
  instructions. A dropped step, a reordered step, or a "smoother" paraphrase
  can get someone hurt. Translate the **meaning exactly** — do not add
  information, do not remove information, do not change the order.
- **Calm saves lives.** The voice must sound like a **calm, clear, unhurried
  authority** — a trained responder who has everything under control. Never
  alarming, never panicked, never dramatic. Reassuring, plain, and steady.

---

## 2. Tone and register

| Do | Don't |
|----|-------|
| Calm, steady, in control | Panicked, urgent-sounding, dramatic |
| Plain, everyday words everyone understands | Rare literary or bureaucratic words |
| Neutral, respectful register | Rude, commanding, or over-formal |
| Short, direct sentences | Long, winding sentences |
| Warm but professional | Cold, robotic, or emotional |

**Register:** Use a **respectful, neutral register that every listener
understands** — students, staff, visitors, of every background. For Hindi,
prefer everyday spoken Hindi (a respectful "आप" form) over heavy Sanskritised
or heavily Urdu-ised vocabulary. Aim for words a first-year student and a
senior staff member would both understand instantly.

---

## 3. Script

- **Hindi:** write in **Devanagari** (हिन्दी). Do not romanise.
- Use standard, correct spelling and punctuation for the language.
- The file is saved so that your script displays correctly in Excel — see
  Section 9 if the characters look wrong.

---

## 4. Length — keep it tight

Each row has a **`max_seconds`** column: the target spoken length of that
prompt. **In an emergency, long messages cost time and delay action.**

- Keep your translation to **roughly the same spoken length or shorter** than
  `max_seconds`. Read it aloud at a calm pace and check.
- If your language naturally needs more words than English, **tighten the
  wording** — drop filler, not meaning. Never drop an actual instruction to
  save time; shorten the phrasing instead.
- The very short prompts (4–8 seconds) must stay short and punchy.

---

## 5. Press-a-key prompts — KEEP THE DIGIT

Some prompts ask the caller to press a key on the phone, e.g.
*"Press 1 if you are safe."* or *"Press 2 for severe bleeding."*

The **number is a physical phone key**. The system is listening for that exact
key. **You must keep the same digit.** Translate the word *"press"* and the
meaning around it, but **never change or translate the number itself into a
different number**, and never drop it.

- English: **Press 1** if you are safe.
- Hindi: यदि आप सुरक्षित हैं, तो **एक दबाएँ**.  ✅ (still key **1**)
- Hindi: यदि आप सुरक्षित हैं, तो **दो दबाएँ**.  ❌ (wrong — changed the key!)

The `notes` column tells you exactly which key(s) a prompt uses. In prompts
with a whole menu (e.g. the first-aid menu), every "Press N ..." pairing must
keep its **original number**. Keep them in the **same order** as the English.

---

## 6. Numbers, codes, and the service name

- **"UPES Emergency Alert Service"** — this is the name of the service and
  must stay **recognisable**. Render it so a listener recognises it as the
  official service. For Hindi, transliterate it in Devanagari:
  **यूपीईएस इमरजेंसी अलर्ट सर्विस** (keep "यूपीईएस" for the UPES brand). Do
  **not** invent a new translated name — consistency matters across all
  prompts.
- **Star / feature codes** (e.g. *"dial star two three"* = **\*23**,
  *"star four six"* = **\*46**) — these are dialling codes. **Keep the exact
  digits.** Say "star" the way your users would speak it, then the digits, in
  the same order. Example (Hindi): "स्टार दो तीन दबाएँ" for \*23.
- **Plain numbers** spoken in text (e.g. "about twice every second", "five
  firm blows") — translate normally into your language's natural way of saying
  the number. These are descriptions, **not** phone keys, so you may write
  them as words. Only the **press-a-key digits** and **star codes** must stay
  as-is.
- **Emergency / phone numbers** and brand words: keep the digits exactly.

---

## 7. Do NOT add or drop information

This is the most important rule. These prompts are **procedural first-aid and
evacuation instructions**.

- Keep **every** instruction and **every** step.
- Keep them in the **same order**.
- Do **not** add advice, warnings, or politeness that isn't in the English —
  even if it seems helpful.
- Do **not** simplify away a detail (e.g. "a few centimetres above the wound,
  between the wound and the heart" must keep both parts).
- If a sentence is genuinely ambiguous, translate it faithfully and add a short
  question in the `notes`/comment to the coordinator — do not guess.

---

## 8. How to fill in the worksheet

You will receive a file named like **`hi.csv`** (for Hindi). Open it in Excel
or any spreadsheet program. Each row is one prompt. The columns are:

| Column | What it is | Do you edit it? |
|--------|-----------|-----------------|
| `id` | Internal name of the prompt | No |
| `category` | What kind of prompt it is | No |
| `file` | The audio file it becomes | No |
| `max_seconds` | Target spoken length (see §4) | No |
| `en` | The exact English wording | No — this is your source |
| **`hi`** (your language code) | **Your translation goes here** | **YES — this is the only column you fill** |
| `notes` | Per-prompt guidance from us (digits, brand, etc.) | No — read it, don't edit |

**Your job:** for each row, read `en` and the `notes`, then type your
translation into the **`hi`** column (or your language's column). Leave every
other column exactly as it is. When you are done, **save the file** (keep it as
`.csv`, UTF-8) and send it back.

- Do not rename the file, add columns, delete rows, or reorder rows.
- If you cannot translate a row yet, leave its cell blank and come back to it —
  blank cells are fine and will be kept if the file is regenerated.

---

## 9. If the characters look wrong in Excel

The file is saved as **UTF-8 with a BOM**, which Excel needs to show Devanagari
correctly. If you open it and see garbled characters:

- Use **File ▸ Open** in Excel and pick the file (rather than double-clicking),
  or use **Data ▸ From Text/CSV** and choose **65001: Unicode (UTF-8)** as the
  encoding.
- When saving, choose **CSV UTF-8 (Comma delimited)** as the file type.
- Google Sheets and LibreOffice Calc open the file correctly by default.

---

## 10. QA checklist (before you send the file back)

Read each translated prompt **aloud, calmly**, and check:

- [ ] Does it sound **calm, clear, and unhurried** — never alarming?
- [ ] Is **every** step from the English present, in the **same order**?
- [ ] Did I **add nothing** and **drop nothing**?
- [ ] For press-a-key prompts, is the **digit unchanged** (1 stays 1)?
- [ ] For star codes, are the **digits unchanged** (\*23 stays \*23)?
- [ ] Is **"UPES Emergency Alert Service"** rendered the **same way** everywhere?
- [ ] Is it **short enough** (around `max_seconds` or less when read aloud)?
- [ ] Is the wording **understandable to everyone** (no rare words)?
- [ ] Did I fill **only** the language column and leave the rest untouched?
- [ ] Does the script display **correctly** (no garbled characters)?

---

## 11. Worked example (Hindi)

Below are two prompts translated as a model. They show the tone, the script,
and how to keep digits and the brand name.

> **EXAMPLE — to be verified by a native expert.** These are illustrative and
> must be checked and, if needed, corrected by the reviewing native speaker
> before use.

### Example A — a press-a-key prompt

- **id:** `upes-ecs/rollcall-press1`
- **English (`en`):** `Press one if you are safe.`
- **Note:** press-a-key prompt — key **1** must stay **1**; very short (≤ 4s).
- **Model Hindi (`hi`):** `यदि आप सुरक्षित हैं, तो एक दबाएँ।`

Why: keeps the phone key **1** ("एक"), stays short and calm, uses the everyday
respectful "आप" form.

### Example B — the test announcement

- **id:** `custom/upes-test`
- **English (`en`):** `This is a test of the UPES Emergency Alert Service. This is only a test. No action is required, and no emergency response will be dispatched.`
- **Note:** keep the service name "UPES Emergency Alert Service" recognisable;
  authoritative and clear; ≤ 11s.
- **Model Hindi (`hi`):** `यह यूपीईएस इमरजेंसी अलर्ट सर्विस का एक परीक्षण है। यह केवल एक परीक्षण है। किसी कार्रवाई की आवश्यकता नहीं है, और कोई आपातकालीन प्रतिक्रिया नहीं भेजी जाएगी।`

Why: the brand **यूपीईएस इमरजेंसी अलर्ट सर्विस** stays recognisable; every part
of the message (it's a test / only a test / no action / no response dispatched)
is kept, in order; the tone is plain and reassuring.

---

**Questions?** If anything is unclear or a prompt seems ambiguous, ask the
coordinator rather than guessing — with life-safety messages, it is always
better to check. Thank you again for your careful work.
