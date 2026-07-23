# Try the demo

A **turnkey demo**: one command seeds ready-made accounts with known passwords and writes
softphone profiles, so right after installing you can dial `111`, watch the response-team
queue, hear the offline coach, switch languages, and see the live console and wallboards.

## See it first

<div style="position:relative;padding-bottom:56.25%;height:0;overflow:hidden;border-radius:12px;margin:1.25rem 0;box-shadow:0 12px 32px -12px rgba(10,40,30,.35);">
  <video controls preload="metadata" playsinline
    poster="https://rohanbatrain.github.io/UPES-ECS/docs/assets/demo-poster.jpg"
    style="position:absolute;top:0;left:0;width:100%;height:100%;border:0;background:#000"
    title="UPES-ECS demo video (1:10–2:18 highlight)">
    <source src="https://github.com/rohanbatrain/UPES-ECS/releases/download/v1.0.0/upes-ecs-demo.mp4" type="video/mp4">
  </video>
</div>

!!! warning "Demo credentials are public"
    The demo password is intentionally simple and the accounts use fresh extensions that
    don't touch your real roster. Use this **only on a local, isolated network** for
    evaluation — never in production. Add real users with `deploy\qemu\Add-UpesUser.ps1`.

## 1. Seed it

After the system is up (`Install-UpesEcs.ps1`), from the repo root:

```powershell
powershell -File demo\Seed-Demo.ps1
```

…or install straight into demo mode:

```powershell
.\Install-UpesEcs.ps1 -Demo
```

This provisions the accounts, sets languages, links a parent/child, and writes Linphone
profiles to `demo\linphone-profiles\`. It's idempotent — safe to re-run.

## 2. Demo accounts

Every account uses the password **`updemo123`**, SIP server **`upes-ecs.local`** (or the LAN
IP the installer shows), transport **UDP**, username = the extension.

| Extension | Name | Role | Language |
|---|---|---|---|
| `500000001` | Demo Student One | student | English |
| `500000002` | Demo Student Two | student | Hindi |
| `500000003` | Demo Student Three | student | Telugu |
| `40000001` | Demo Staff One | staff | English |
| `4190` | Demo ERT Desk 1 | responder | — |
| `4191` | Demo ERT Desk 2 | responder | — |
| `4390` | Demo Gate Phone | device | — |
| `590000001` | Demo Parent One | parent | — |

## 3. Register two softphones

Install **Linphone** (free; Android / iOS / desktop) and add two accounts — e.g. `500000001`
(the caller) and `4190` (the responder). Username = extension, password = `updemo123`,
server = `upes-ecs.local`, transport UDP. Or import a profile from `demo\linphone-profiles\`
via **Settings → Remote provisioning**.

## 4. The 5-minute tour — dial this, see that

| Dial (from) | What happens |
|---|---|
| **`*22`** from `4190` | Go **on shift** so `4190` receives `111` calls (`*23` = off shift). Do this first. |
| **`111`** from `500000001` | Emergency hotline → response-team queue → `4190` rings. Answer it. |
| **`111`** from `500000002` | Same flow, prompts spoken in **Hindi** (per-caller language). |
| **`102`** from any phone | The **offline panic-coach** (first-aid menu, no human/internet). |
| **`199`** from any phone | **Drill mode** — safe to test. |
| **`4191`** mid-call | **Transfer / add** a second responder. |

Then open:

- **Operations Console** — `http://localhost:8080`
- **Safety wallboard** — `http://localhost:8080/tv-safety.html`
- **Ops wallboard** — `http://localhost:8080/tv-ops.html`

The board turns **READY** once `4190` is on shift and there are no open follow-ups.

## 5. Remove it

```powershell
powershell -File demo\Seed-Demo.ps1 -Remove
```

See also the full walkthrough in [`demo/README.md`](https://github.com/rohanbatrain/UPES-ECS/blob/main/demo/README.md).
