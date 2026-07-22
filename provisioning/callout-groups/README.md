# Call-out Groups

Group lists consumed by [`scripts/mass_callout.sh`](../../scripts/mass_callout.sh) to
run a **mass notification** or a **roll-call** (press 1 = safe) across a set of
extensions. Each group is a plain CSV: **one extension per line**.

## Format

```text
# comment lines start with '#' and are ignored; blank lines too
4400
4401
4402
```

- One numeric extension per line (positions or SAP-ID/employee-ID extensions).
- `#` comments and blank lines are ignored.
- Windows CRLF is tolerated (the script strips `\r`).

## Files

One `*.example.csv` per responder department — **position** extensions from the
[Numbering Plan](../../SOP/01-Numbering-Plan.md) (dispatch front-door + answer seats).
Placeholders only, no people. Copy to a real name before staffing.

| File | Purpose |
|---|---|
| `medical.example.csv` | **EXAMPLE** — medical positions (4200–4299) |
| `security.example.csv` | **EXAMPLE** — security positions (4300–4399, incl. 4301 Lead) |
| `wardens.example.csv` | **EXAMPLE** — warden positions (4400–4499) |
| `operations.example.csv` | **EXAMPLE** — operations positions (4500–4599) |
| `it-network.example.csv` | **EXAMPLE** — IT / network positions (4600–4699) |

## Making a real group

1. Copy the example to a real name, e.g. `wardens.csv`, `ert-all.csv`, `hostel-a.csv`.
2. List the actual extensions (positions from `../responder-positions.csv`, or the
   real user extensions who should be reached).
3. **PII / privacy:** a group is just extensions — keep it that way. Do **not** add
   names or SAP IDs as data columns, and treat any file that maps to real people as
   restricted (see [Backup & Restore §5](../../SOP/11-Backup-Restore-Procedure.md)).
   Do not commit rosters that identify individuals.

## Running

```bash
# Notify only (play a message, hang up):
/opt/upes-ecs/mass_callout.sh provisioning/callout-groups/wardens.csv callout-drill notify

# Roll-call (play message + collect "press 1 = safe"):
/opt/upes-ecs/mass_callout.sh provisioning/callout-groups/wardens.csv rollcall-msg rollcall

# Then summarize (runid is printed by mass_callout.sh):
/opt/upes-ecs/rollcall_report.sh <runid>
```

Only ONE call-out runs at a time (the engine takes a lock). See
[FEATURES.md → Mass call-out / roll-call](../../config/FEATURES.md) for the dial
codes, dependencies (sound files), and the `ctx_callout` dialplan target.
