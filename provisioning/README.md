# UPES-ECS Provisioning Templates

> ## ⚠ Adding a user on the QEMU/Asterisk deployment? Use one command.
> ```powershell
> powershell -File ..\deploy\qemu\Add-UpesUser.ps1 -SapId <sapid> -Name "<Full Name>"
> ```
> `Add-UpesUser.ps1` is the **only safe way** to add a user on this deployment. It generates
> the secret **once**, pins it in the single source of truth
> (`deploy/asterisk/pjsip_accounts.conf`), mirrors it to `secrets/TEAM-CREDENTIALS.md` and the
> **live VM**, reloads PJSIP, and verifies. **Re-running it never changes an existing password.**
>
> 📖 Full procedure + invariants: **[../deploy/qemu/ADD-USER-RUNBOOK.md](../deploy/qemu/ADD-USER-RUNBOOK.md)**
>
> **Do NOT** hand-generate secrets with `openssl rand` per import, or drive account creation
> from the `__SET_ON_IMPORT__` CSVs below, on this deployment. That regenerates a *fresh*
> secret every run — the account connects once, then the phone can't re-register with its old
> password ("password magically changed"). The CSVs below are for a **separate FreePBX** target
> only, where the source of truth is FreePBX's own DB — not this Asterisk VM.

---

CSV templates for bulk-creating SIP accounts via **FreePBX → Admin → Bulk Handler →
Extensions → Import**. One row per account. Fill, validate, back up, import, test.

> **Match your FreePBX's headers first.** FreePBX Bulk Handler formats vary by version.
> Best practice: in Bulk Handler, **Export** one existing extension to CSV, then align
> these templates to those exact column names before importing. The columns here are
> the essential fields every version needs; add/rename to match your export.

---

## Files

| File | For | Extension = |
|---|---|---|
| `pilot-users.csv` | Confirmed human users (real roster from [../Notes/Confirmed Details.md](../Notes/Confirmed%20Details.md)) | SAP ID / employee ID |
| `responder-positions.csv` | **Generic responder positions** (ERT, Medical, Security, Warden, Ops, IT) staffed by shift | 4100–4699 |
| `fixed-devices.csv` | True location-bound devices (gate phones, IP speakers) | 4300–4799 |

> **Real data only.** `pilot-users.csv` holds the confirmed people;
> `responder-positions.csv` and `fixed-devices.csv` hold the extensions defined in the
> [Numbering Plan](../SOP/01-Numbering-Plan.md). No fabricated names or SAP IDs.

### Roles are POSITIONS, not people — see [SOP 30](../SOP/30-ERT-Roles-and-Shifts.md)
**Every responder role** (ERT, Medical, Security, Warden, Ops, IT) is a **generic
position staffed by shift** — not a named person. The confirmed people in
`pilot-users.csv` are **staff/student accounts** (normal calling) **and** trained
officers who occupy a position on their shift. So:
- **Do not** put a person's SAP ID into a responder context.
- **ERT positions** (`4110/4111/…`) are the **111-queue members**. Other responder
  positions (Medical `4200`, Security `4300`, …) are **dispatch targets** in `ctx_responder`
  — they receive handoffs and coordinate, but do **not** answer the 111 queue.
- `pilot-users.csv` context default: 9-digit SAP IDs (`500120597`) → `ctx_student`;
  8-digit IDs (`40000001`) → `ctx_staff`. Confirm each person's category (not their role).

---

## Column guide

| Column | Meaning | Example |
|---|---|---|
| `extension` | The number. Human = **SAP ID**; fixed = 4xxx | `500120597` / `4300` |
| `name` | Display name → drives caller ID | `Rohan Batra` / `Security-Control-4300` |
| `secret` | SIP password — **≥12 random chars, unique**. Ship as `__SET_ON_IMPORT__` and inject the generated secret at import; never commit real secrets to git | `__SET_ON_IMPORT__` |
| `tech` | Channel tech | `pjsip` |
| `context` | Role/permission context (see [Role Matrix](../SOP/04-SIP-Account-Role-Matrix.md)) | `ctx_student` |
| `outbound_cid` | Caller ID shown | `"Rohan Batra - 500120597"` |
| `voicemail` | VM enabled? | `no` (students) / `no` (fixed) |
| `location` | Fixed devices only — physical location | `Security Control Room` |
| `max_contacts` | Devices per account | `2` student / `3` ERT/staff / `1` fixed |

> If your FreePBX maps permissions via **Class of Service** instead of raw context,
> put the COS name in a `cos`/`class` column instead of `context`.

---

## Rules (from the decisions)

- **Human extension = SAP ID.** Never invent random student numbers.
- **Fixed devices = 4000–4999**, named `Location-Role-Extension`, owned by a dept/role.
- **Unique, strong secret per account** — never a shared/trivial password (banned: `student123`, `sapid123`, `password`, `100100`).
- **Caller ID must be readable/traceable** — `Name - SAP ID` for people, location/role for devices. No blank/`Unknown`.
- Start with a **controlled pilot (10–25 users)** — don't import the whole university on day one.
- SAP IDs are **never reused**; disabled accounts keep their history.

---

## Generating secrets

Don't hand-type passwords. Generate them, e.g. on the server:

```bash
# one strong secret
openssl rand -base64 15

# fill the secret column of a file just before import (writes a NEW file; keep it out of git)
awk -F, 'BEGIN{OFS=","} NR==1{print;next} { "openssl rand -base64 15" | getline s; $3=s; print }' \
    pilot-users.csv > pilot-users.filled.csv
```

The committed CSVs carry `__SET_ON_IMPORT__` in the secret column — **never real
secrets in git.** Generate into a throwaway `*.filled.csv`, import it, then delete it.
Deliver secrets **once, securely** (portal / helpdesk / sealed sheet). Keep the filled
file access-restricted; see [Backup & Restore §5](../SOP/11-Backup-Restore-Procedure.md).

---

## Import steps

```text
1. Bulk Handler → Extensions → Export one sample → copy its headers.
2. Align the template columns to those headers.
3. Take a config backup (pre-change rule).
4. Bulk Handler → Import → upload CSV → review the preview.
5. Import → Apply Config.
6. Test: register 2 accounts, dial 199, dial 111, dial SAP-ID → SAP-ID.
7. Verify caller ID renders "Name - SAP ID".
```

Both CSVs contain **real, confirmed entries** — no placeholder people. Add rows only
for confirmed users/devices. The only placeholder is the `secret` column
(`__SET_ON_IMPORT__`), filled at import time and never committed.
