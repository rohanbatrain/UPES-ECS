# UPES-ECS Demo — try everything in 5 minutes

A **turnkey demo**: one command seeds ready-made accounts with known passwords and writes
softphone profiles, so right after installing you can dial `111`, watch the response-team
queue, hear the offline coach, switch languages, and see the live console and wallboards.

> ⚠️ **Demo credentials are public and intentionally simple.** Use this only on a local,
> isolated network for evaluation. **Never** deploy these accounts or this password to
> production — add real users with `deploy\qemu\Add-UpesUser.ps1` (it pins a unique secret
> per account). The demo uses fresh extensions that don't touch your real roster.

---

## 1. Seed the demo

After the system is up (`Install-UpesEcs.ps1`), run once from the repo root:

```powershell
powershell -File demo\Seed-Demo.ps1
```

It provisions the accounts below, sets their languages, links a parent/child for the family
feature, and writes importable Linphone profiles to `demo\linphone-profiles\`. Re-running is
safe (idempotent). You can also install straight into demo mode:

```powershell
.\Install-UpesEcs.ps1 -Demo
```

---

## 2. Demo accounts

Every demo account uses the password **`updemo123`**. SIP server **`upes-ecs.local`** (or the
LAN IP the installer shows), transport **UDP**, username = the extension.

| Extension | Name | Role | Language | Try it for… |
|---|---|---|---|---|
| `500000001` | Demo Student One | student | English | Placing the `111` emergency call |
| `500000002` | Demo Student Two | student | Hindi | Per-caller language (prompts in Hindi) |
| `500000003` | Demo Student Three | student | Telugu | Per-caller language (prompts in Telugu) |
| `40000001` | Demo Staff One | staff | English | A staff caller |
| `4190` | Demo ERT Desk 1 | responder | — | **Answering** `111` (go on shift with `*22`) |
| `4191` | Demo ERT Desk 2 | responder | — | Transfer / second answer point |
| `4390` | Demo Gate Phone | device | — | A gate / entry phone |
| `590000001` | Demo Parent One | parent | — | Family link to Demo Student One |

---

## 3. Register two softphones

You need at least two SIP phones to place and answer a call. Easiest is **Linphone** (free;
Android / iOS / desktop).

**Fastest — import a profile:** serve the generated profiles over the LAN and point Linphone
(Settings → Remote provisioning) at, e.g., `http://<LAN-IP>:8080/500000001.filled.xml`.
(Copy `demo\linphone-profiles\*.filled.xml` next to the Console web root, or run
`python -m http.server` in that folder.)

**Or enter it by hand:**

- **Username:** `500000001` (phone A) and `4190` (phone B)
- **Password:** `updemo123`
- **SIP server / domain:** `upes-ecs.local` (or the LAN IP), transport **UDP**

Both should show **Registered**. On one laptop, run Linphone desktop for one account and
Linphone on your phone (same Wi-Fi) for the other.

---

## 4. The 5-minute tour — dial this, see that

| Dial (from) | What happens |
|---|---|
| **`*22`** from `4190` | Go **on shift** so `4190` starts receiving `111` calls (`*23` = off shift). Do this first. |
| **`111`** from `500000001` | The campus emergency hotline → response-team queue → **`4190`** rings. Answer it — a live emergency call, recorded from the first second. |
| **`111`** from `500000002` | Same flow, but every prompt is spoken in **Hindi** — per-caller language routing. |
| **`102`** from any phone | The **offline panic-coach**: an automatic first-aid guide (press 1–9 for topics). No human or internet needed. |
| **`199`** from any phone | **Drill mode** — safe to test without triggering a real response. |
| **`4191`** while on a `111` call | **Transfer / add** a second responder (three-way dispatch). |
| **`700`-series** from `4190` | **Paging / announcement** (a device like `4390` is a target). |

Open the operations surfaces in a browser:

- **Operations Console:** `http://localhost:8080` — live queue, calls, roster, status.
- **Safety wallboard:** `http://localhost:8080/tv-safety.html` — the giant **DIAL 111** board.
- **Ops wallboard:** `http://localhost:8080/tv-ops.html` — queue, KPIs, analytics.

The board turns **READY** once a responder is on shift (`4190` + `*22`) and there are no open
follow-ups. If it shows DEGRADED/CRITICAL from a backlog, clear it on the VM with
`sudo -u asterisk followup.sh`.

---

## 5. Remove the demo

```powershell
powershell -File demo\Seed-Demo.ps1 -Remove   # prints how to remove the demo extensions
```

Then add your real users with `deploy\qemu\Add-UpesUser.ps1` and you're in production mode.
