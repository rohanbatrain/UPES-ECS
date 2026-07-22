# Runbook — Add a SIP user without drift

> **The bug this prevents:** a new account connects **once**, then the phone can't
> re-register — "the password magically changed." Root cause is **secret drift**, not a
> runtime process. Full analysis: [memory `sip-secret-drift-single-source`] and the
> CHANGELOG. This runbook is the standing procedure so it never recurs.

---

## The one rule

**There is exactly one source of truth for SIP secrets: `deploy/asterisk/pjsip_accounts.conf`.**
A secret is generated **once**, pinned there, and mirrored everywhere else. It is **never**
regenerated for an account that already exists.

## The one command

```powershell
powershell -File C:\Users\Rohan\UPES\deploy\qemu\Add-UpesUser.ps1 -SapId <sapid> -Name "<Full Name>"
```

- Staff/explicit context: add `-Role staff` (else inferred: 9-digit SAP → student/`ctx_student`, 8-digit → staff/`ctx_staff`).
- Match a phone already configured with a known password: add `-Secret <value>`.
- Repo-only, no live PBX (e.g. VM down): add `-NoVm`, then re-run without it when the VM is up.

`Add-UpesUser.ps1` does all of this atomically and **idempotently**:
1. If the extension already exists → reads back its **pinned** secret and reuses it. *Never regenerates.*
2. If new → generates one 14-hex secret and pins it.
3. Writes the **same** secret to: `pjsip_accounts.conf` → `secrets/TEAM-CREDENTIALS.md` → the **live VM** `/etc/asterisk/pjsip_accounts.conf`.
4. `pjsip reload`, then **verifies** the auth secret on the live PBX matches.
5. If the VM had drifted, it **heals** the VM back to the pinned secret.

**Re-running the exact command is always safe** — it re-asserts the same secret and changes nothing.

---

## Invariants — never violate these

| # | Rule | Why |
|---|---|---|
| 1 | Only `Add-UpesUser.ps1` creates/asserts users. | It is the only path that pins once and keeps all three stores in sync. |
| 2 | Never `openssl rand` a secret per-import, and never drive account creation off the `__SET_ON_IMPORT__` CSVs on this VM. | That mints a *fresh* password every run → the drift bug. Those CSVs are for a **separate FreePBX** target only. |
| 3 | Never hand-edit a password in just one place. | `pjsip_accounts.conf`, `TEAM-CREDENTIALS.md`, and the live VM must always agree. Re-run the tool instead. |
| 4 | Keep the Deploy/build data.iso copy list in sync with `setup-in-vm.sh`'s file loop — always incl. `pjsip_accounts.conf`. | A missing accounts file makes a `-Rebuild` wipe/abort accounts. |
| 5 | A live account's password is only changed deliberately (rotation), then push via the tool + redeliver to the owner. | Changing a working emergency account's secret silently locks a responder out. |

## For an AI/automation session (so you never drift)

1. **Do not** generate a secret inline, edit `pjsip_accounts.conf` by hand, or touch the CSVs.
2. Run the one command above. Read its output.
3. Confirm you see `VERIFY_OK <sapid> <secret>` and "LIVE PBX verified".
4. Report the credential + "register to \<LAN IP\>:5060". Nothing else.
5. If the user already exists, the tool says so and keeps the password — that is correct, not an error.

---

## Verify (independent of the tool)

```bash
ssh -i C:/Users/Rohan/qemu/ssh/upes_key -p 2222 ubuntu@localhost \
  'sudo asterisk -rx "pjsip show auth <sapid>" | grep -E "username|password"'
```
Must match the row in `secrets/TEAM-CREDENTIALS.md` and the block in `deploy/asterisk/pjsip_accounts.conf`.

## Recover a drifted / locked-out account

Just re-run the one command for that SAP ID. The tool detects the VM's password ≠ the pinned
source of truth and heals the VM back. The owner's existing phone config keeps working.

## Onboarding gate (before "active")

Register the handset to the LAN IP shown in the Console top bar (port 5060), then test:
`199` (drill) → a peer SAP ID → `111`. Confirm caller ID renders `Name - SAP ID`.
Deliver the secret once, securely; delete any throwaway `*.filled.*` file.
