# Family links — UPES Safe app

Lets a **parent/guardian** see their **child's** live safety status in the app during a
campus emergency: safe / needs-help, on-campus, last location, and a one-tap call.

## Model

`families.csv` is the **source of truth** (repo copy here) — one row per parent→child link:

```csv
parent_sap,child_sap
40009001,500120597
40009001,500000002   # same parent, second child = second row
```

The live copy at `/opt/upes-ecs/family/families.csv` is read by `safety_api.py` on every
`/family` request (no restart needed). Keep the two in sync with the script — never
hand-edit the live copy.

## Add a link

Both the parent and the child must already be real SIP accounts. Create the parent first
(a normal account — it can be `-App` too so the parent uses the app to call):

```powershell
# 1. parent account (once)
powershell -File deploy\qemu\Add-UpesUser.ps1 -SapId 40009001 -Name "Rajesh Batra" -Role staff -App
# 2. link parent -> child (idempotent; re-running is a no-op)
powershell -File provisioning\family\Add-UpesFamily.ps1 -ParentSap 40009001 -ChildSap 500120597
```

`Add-UpesFamily.ps1` appends the row to the repo `families.csv` **and** pushes it to the
live VM over SSH (skip the push with `-NoVm`).

## Campus geofence

`campus.json` (`{lat, lon, radiusM}`) decides on-campus vs off-campus for a child's
reported position. Set it to your campus centre + a radius that covers the grounds. It's
seeded into `/opt/upes-ecs/family/` on install; edit + re-push if the campus moves.

## Files
- `families.csv` — parent→child links (source of truth).
- `campus.json` — geofence centre + radius.
- `Add-UpesFamily.ps1` — idempotent link tool (repo + live VM).
- `README.md` — this file.
