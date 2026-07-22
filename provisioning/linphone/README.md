# UPES-ECS · Standardized Linphone Provisioning

Onboard every phone with **zero manual misconfiguration**. Field testing showed that
*every* registration/audio failure came from a human picking a setting by hand — wrong
**Transport** (TLS instead of UDP), a **`+91`** country code prepended to SAP IDs, or an
**SRTP/codec** mismatch against a plain-RTP G.711 server. This folder removes all of that
by shipping the correct profile as a **controlled artifact** instead of a setup sheet.

Root cause and the fixes are documented in
[../../Journal/Field-Test-Issues-and-Mitigations.md](../../Journal/Field-Test-Issues-and-Mitigations.md)
(Issues 1, 2, 3, 5, 6). Battery/background survival is
[../../SOP/24-Mobile-App-Reliability-and-Battery.md](../../SOP/24-Mobile-App-Reliability-and-Battery.md).
The user-facing setup walkthrough is
[../../SOP/05-Student-SIP-Setup-Guide.md](../../SOP/05-Student-SIP-Setup-Guide.md).

Files here:

| File | What it is |
|---|---|
| `README.md` | This guide. |
| [`linphone-provisioning-template.xml`](linphone-provisioning-template.xml) | The standardized Linphone remote-provisioning profile (placeholders `__DOMAIN__` / `__SAPID__` / `__SECRET__`). |
| [`users.csv`](users.csv) | The confirmed roster to provision (secrets held as `__SET_ON_IMPORT__`). |
| [`make-profiles.md`](make-profiles.md) | Recipe: fill the template per user → serve over HTTP → point each phone at its URL/QR. |

Everything is **LAN-only** — no internet at runtime.

---

## 1. How Linphone remote provisioning works

Linphone can fetch its **entire configuration from a URL** instead of being typed in.
That config file is Linphone's native rc-file expressed as XML: each rc `[section]`
becomes a `<section name="...">` and each `key=value` becomes an
`<entry name="key">value</entry>`, wrapped in a `<config>` root that declares the
`http://www.linphone.org/xsds/lpconfig.xsd` schema. On fetch, Linphone **merges those
entries into its own config and restarts** — so the account, transport, codecs and
encryption are all applied identically, with nothing left to a user's choice.

The phone is pointed at the file in one of two ways:
- **Settings → Advanced → Remote provisioning** → paste the URL → restart, or
- **Scan a QR** of that same URL (Linphone Assistant → *Fetch remote configuration*).

Because the file is served from the laptop/PBX over plain HTTP on the LAN, there is **no
external dependency** — it works on the van network with no internet.

---

## 2. The standardized settings (the one correct profile)

These are hard values, not "unless IT tells you otherwise." They match the UPES-ECS PBX
exactly (UDP-only, plain RTP, G.711-only). The template bakes every one of them in.

| Setting | Correct value | Prevents (field-test issue) |
|---|---|---|
| **Domain / SIP proxy** | the **PBX LAN IP** for this network, e.g. `192.168.1.16` (`pbx.upes.lan` only where DNS exists) | unreachable / wrong host |
| **Transport** | **UDP** | Issue 1 — server is UDP-only; TLS/TCP hangs on "Operation in progress" |
| **Media encryption** | **None** | Issues 3 / 5 — server is plain RTP; SRTP/ZRTP → "connected, no audio" |
| **Audio codecs** | **G.711 only** — `PCMU` (u-law) + `PCMA` (A-law) | Issue 5 — server allows `ulaw`/`alaw` only |
| **International / country prefix (dial assistant)** | **OFF** — no `+91`, no escape-plus | Issue 2 — `+91` prepended to SAP IDs → "no such extension" |
| **Register expiry** | **~120 s** | Issue 6 — fast drop detection without REGISTER thrash |
| **Username / identity** | the user's **SAP ID** (e.g. `500120597`) | identity = extension |
| **Password** | the user's **one-time secret** (per-account, never shared) | traceability |
| **Background / battery** | app **Unrestricted**, auto-start on | Issue 6 / SOP 24 |

> **One-line domain form that pins the transport regardless of the UI:**
> `500120597@192.168.1.16;transport=udp`

Note: SAP IDs are **identifiers, not phone numbers** — the profile explicitly disables the
dial assistant so no app "helpfully" reformats them into E.164.

---

## 3. Three ways to provision (pick per situation)

### Option (i) — Remote-provisioning config file over HTTP  ·  *preferred for a fleet*

Fill [`linphone-provisioning-template.xml`](linphone-provisioning-template.xml) per user,
serve this folder over HTTP, and point each phone at its URL — via **Settings → Advanced →
Remote provisioning** or a **QR of that URL**. All the standardized settings above come
from the file; there is nothing to type, so nothing to typo. Full recipe:
[make-profiles.md](make-profiles.md).

Best for: bulk rollout, re-imaging, dedicated ERT/control-room devices (rebuild identically).

### Option (ii) — Manual entry using the exact table  ·  *fallback for one phone*

If provisioning isn't available, enter these by hand in Linphone
(**Assistant → Use SIP Account**) — and copy the table **exactly**, including the hard
fields most people get wrong:

| Field | Enter |
|---|---|
| Username | your **SAP ID**, e.g. `500120597` |
| Password | your one-time UPES-ECS secret |
| Domain / SIP proxy | the PBX IP, e.g. `192.168.1.16` |
| **Transport** | **UDP** (Account → Transport) |
| **Media encryption** | **None** |
| **Audio codecs** | enable **PCMU** + **PCMA**; disable the rest |
| **International prefix / dial assistant** | **OFF** |
| Register expiry | 120 |
| Display name | your name, e.g. `Rohan Batra` |

This mirrors [SOP 05 Step 3](../../SOP/05-Student-SIP-Setup-Guide.md) — the Transport line
there is **UDP**, not optional.

### Option (iii) — The "Register a client" generator in the Console  ·  *fast at a desk*

[../../Console/index.html](../../Console/index.html) → **Register a Client** generates, on
the spot: a strong crypto-random secret, the CSV import line for the PBX, and the exact
Linphone settings string to hand to the user (SIP server, username, password, Transport=UDP,
display name) — nothing leaves the page. Use it to mint one account + its credentials, then
either hand the settings over for **Option (ii)** or feed the secret into **Option (i)** to
build that user's profile.

---

## 4. Onboarding self-test (the gate to "Active")

A phone is **not "done"** until it passes this gate, **in order**. No green + no echo =
the device is not provisioned, regardless of what the user says. This mirrors
[SOP 05 Step 4](../../SOP/05-Student-SIP-Setup-Guide.md) and Field-Test §A.2.

```text
0. ping <PBX IP>          -> L3 reachable        (e.g. ping 192.168.1.16)  [prove the LAN first]
1. app shows Registered   -> green / Connected    => transport + credentials OK
2. dial 198  (echo)       -> hear your own voice   => mic + speaker + media path OK
3. dial 199  (drill)      -> drill prompt          => dialplan reachable, NO real dispatch
4. dial 111               -> reaches ERT           => emergency path + two-way audio
5. call another SAP ID    -> reaches that peer      => student-to-student calling OK
```

Only when **all** of 1–5 pass is the phone marked **Active**. Some Android brands need the
[SOP 24](../../SOP/24-Mobile-App-Reliability-and-Battery.md) battery/background steps
applied **before** step 1 will *stay* green — apply those, then re-verify.

- **198** = echo test · **199** = drill (safe, no real dispatch) · **111** = emergency ·
  a **SAP ID** = a normal internal call. See the
  [Numbering Plan](../../SOP/01-Numbering-Plan.md).

---

## 5. Who is provisioned

[`users.csv`](users.csv) holds the **confirmed** roster only (from
[../../Notes/Confirmed Details.md](../../Notes/Confirmed%20Details.md)) — four students in
`ctx_student`: `500120597` Rohan Batra, `500000002` Student Example Two, `500000003` Student Example Three
Shaktawat, `500000004` Student Example Four. Staff, ERT positions and fixed devices are created
from the CSVs one level up ([../pilot-users.csv](../pilot-users.csv),
[../responder-positions.csv](../responder-positions.csv),
[../fixed-devices.csv](../fixed-devices.csv)); this folder only builds the **phone-side**
Linphone profiles.

---

## 6. Secrets discipline

- The committed template and `users.csv` carry **only placeholders**
  (`__DOMAIN__`/`__SAPID__`/`__SECRET__`, `__SET_ON_IMPORT__`). **No real secret is ever
  committed.**
- Filled per-user profiles (`*.filled.xml`) are generated at provisioning time, served, and
  then **deleted** — the same `*.filled` pattern as [../README.md](../README.md#generating-secrets).
- Each secret is **per-account and delivered once, securely**; a served `.filled.xml` (and any
  QR of its URL) is secret-bearing — keep both off git and off shared drives.
