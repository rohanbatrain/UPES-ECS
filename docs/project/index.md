# UPES-ECS Engineering Journal

This folder is the **real engineering log** for the UPES-ECS project — the LAN-only
campus emergency phone system built on Asterisk and deployed as a QEMU virtual
machine on a Windows "van laptop".

It is deliberately separate from the design docs. The [Blueprint](../Blueprint/),
[SOP](../SOP/), and [Docs](../Docs/) folders describe **what the system is and how it
should work**. This folder records **what actually broke on the way there and how we
fixed it** — the dead ends, the platform quirks, and the corrections we had to make
once real hardware, real config, and a real roster met the design.

## Contents

| File | What it is |
| --- | --- |
| [Roadblocks-and-Solutions.md](./Roadblocks-and-Solutions.md) | The main log. Every roadblock we hit, grouped by area, each with symptom / cause / fix / lesson. |
| [Doc-Fixes.md](./Doc-Fixes.md) | A short changelog of factual corrections made to the existing docs (wrong values, stale examples). |
| [Project-Status.md](./Project-Status.md) | Status of record — an honest accounting of what is done & validated, deferred, and still remaining. |
| [Feature-Roadmap.md](./Feature-Roadmap.md) | The next horizon — features beyond the current build, sequenced and mapped to real Asterisk capabilities. |
| [Feature-Demo-Evidence.md](./Feature-Demo-Evidence.md) | Live verification on the running QEMU PBX of designed features (backup/restore, fail2ban, pause/resume, paging, conference). |
| [Field-Test-Issues-and-Mitigations.md](./Field-Test-Issues-and-Mitigations.md) | Issues seen during the live Android field test and how each was mitigated. |
| [Production-Readiness.md](./Production-Readiness.md) | Production-readiness assessment — hardening, autostart, backups, and what remains before go-live. |

## Who this is for

- **Future maintainers** who hit the same wall and want the fix, not a re-investigation.
- **Reviewers / examiners** who want evidence the design was tested against reality, not just written down.
- **The next person** who moves the van laptop to a new network, rebuilds the VM, or
  re-provisions the roster — the gotchas that cost us hours are written down here so
  they cost you minutes.

Everything here reflects events that actually happened during build and test. No
invented incidents, no invented people. The only real roster lives in
[../Notes/Confirmed Details.md](../Notes/Confirmed%20Details.md).
