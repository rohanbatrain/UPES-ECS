# Doc Fixes

Factual corrections made to the existing documentation during the doc-integrity pass.
Scope was deliberately conservative: only outright factual errors were changed — no
rewrites, no restructuring, no design changes, no edits to the QEMU runtime, the Console,
or any `.ps1` scripts.

## Corrections

| File | What was wrong | What we changed |
| --- | --- | --- |
| [../Docs/Feature-14.md](../Docs/Feature-14.md) | Used the fabricated SAP ID `500123456` in 9 places, several of them attributed to **Rohan Batra**, whose real SAP ID is `500120597` (per [../Notes/Confirmed Details.md](../Notes/Confirmed%20Details.md)). | Replaced every `500123456` with `500120597`. Affected the worked example (SAP ID / SIP extension / username / display name), the provisioning-flow example, the caller-ID example, and the directory-mapping example. |

## Checks that came back clean

- **`MixMonitor(...,b)` stale usage:** No live config uses the buggy `,b` flag. The only
  remaining mentions are in [../Blueprint/07-Deployment-Runbook.md](../Blueprint/07-Deployment-Runbook.md)
  and [../deploy/README.md](../deploy/README.md), where they correctly **document the bug
  as found and fixed**. The active dialplan
  ([../config/extensions_custom.conf](../config/extensions_custom.conf)) and
  [../SOP/09-Dialplan-Design.md](../SOP/09-Dialplan-Design.md) both use plain
  `MixMonitor(${MIXMONITOR_FILENAME})` (whole-call). No change needed.
- **Emergency / drill numbers:** _(superseded)_ At the time of this pass, `100` (emergency)
  and `199` (drill) were consistent across config, SOPs, and Blueprint. The system has since
  **migrated to `111` as the sole emergency number** (`100` has since been **deprecated and
  fully removed** — it no longer routes), and added `102` as the offline panic-coach route.
  Docs are being updated to reflect `111`-primary; the old "100 everywhere, no errors"
  certification no longer holds.
- **Numbering plan:** ERT `4101` / `4110-4113` / `4120`, responders `4200/4300/4400/4500/4600`,
  fixed devices `4700s`, RTP range `10000-10019`, SIP UDP `5060`, and the context names
  (`ctx_student`, `ctx_staff`, `ctx_ert`, `ctx_ert_lead`, `ctx_responder`,
  `ctx_control_room`, `ctx_fixed_device`, `ctx_admin`) all match the known-correct facts.
  No errors found.
- **Roster / secrets:** The provisioning CSVs
  ([../provisioning/](../provisioning/)) use only the confirmed roster and ship secrets as
  `__SET_ON_IMPORT__`. No fabricated identities remain. No change needed.

## Note

One other invented value exists: `500987654` (labelled generically as "ERT Member") in the
directory-mapping example of [../Docs/Feature-14.md](../Docs/Feature-14.md). It is **not**
attributed to any real named person and there is no confirmed ERT-member SAP ID to
substitute, so it was left untouched in keeping with the conservative scope. Flagging it
here for visibility.
