# UPES-ECS Ownership & RACI

Closes Risk **R12** (bus factor). Defines who owns what so UPES-ECS doesn't depend on
one person, and every task has a clear owner and backup.

**R** Responsible (does it) · **A** Accountable (owns the outcome, one per row) ·
**C** Consulted · **I** Informed

---

## 1. Named owners (fill in people)

| Role | Primary | Backup |
|---|---|---|
| UPES-ECS System Admin (IT) | ________ | ________ |
| ERT Lead / Incident Commander | ________ | ________ |
| Control Room Duty Owner | ________ | ________ |
| University Approver (admin) | ________ | ________ |
| Network/Wi-Fi owner (IT) | ________ | ________ |
| Van deployment owner | ________ | ________ |

> **Every primary must have a trained backup.** No single person is a point of failure —
> that's the whole point of this document.

---

## 2. RACI matrix

| Task | IT Admin | ERT Lead | Control Room | University | Network |
|---|:--:|:--:|:--:|:--:|:--:|
| PBX / FreePBX build + config | **A/R** | C | I | I | C |
| Custom dialplan + scripts | **A/R** | C | I | | I |
| SIP account provisioning | **A/R** | C | I | I | |
| ERT roster / queue membership | C | **A/R** | R | I | |
| Daily readiness check | R | C | **A/R** | | I |
| Health monitoring | **A/R** | C | R | I | C |
| Backups (config) | **A/R** | I | I | | |
| Restore test | **A/R** | C | I | I | |
| Recording access / release | C | **A/R** | C | C | |
| Retention / deletion approval | R | C | I | **A** | |
| Paging approval (700s) | I | **A/R** | R | I | |
| Incident closure | I | **A/R** | R | | |
| Drill scheduling + review | R | **A/R** | R | C | I |
| Van readiness + deployment | R | **A** | C | I | C |
| Wi-Fi / client isolation / VLAN | C | I | I | I | **A/R** |
| Security hardening | **A/R** | C | I | I | C |
| Abuse / prank handling | R | **A** | R | C | |
| Go-live approval | R | R | I | **A** | C |
| Compliance / DPDP policy | C | C | I | **A/R** | |

---

## 3. Recurring responsibilities

| Cadence | Task | Owner (A) |
|---|---|---|
| Every shift | Daily readiness check | Control Room |
| Daily | Config backup (auto) + health cron | IT Admin |
| Daily | Review missed-emergency queue | ERT Lead |
| Weekly | Drill health report | ERT Lead |
| Monthly | Basic drill · directory/device review · van deploy drill | ERT Lead / IT |
| Monthly (pilot) | Restore test | IT Admin |
| Quarterly | Full-scenario drill · restore test · role review | ERT Lead / IT |

---

## 4. Knowledge continuity (anti bus-factor)

- **Runbooks current:** build guide, dialplan design, backup/restore, van deployment — all in this repo, kept updated.
- **Two people** can do every critical task (primary + backup trained).
- **Credentials** in a shared secrets store the backup can reach (not one person's head/laptop).
- **Config in git** (`upes-ecs-config`) — anyone with access can see history and restore.
- **Onboarding note:** a new admin should be able to stand up the system from the [Master Plan](07-Master-Implementation-Plan.md) + [FreePBX Build Guide](08-FreePBX-Build-Guide.md) + this repo alone.

---

## 5. Escalation path (who to call when it breaks)

```text
System issue      → IT Admin (→ backup) → Network owner if Wi-Fi/LAN
Emergency ops     → Control Room → ERT Lead → University authority
Van/field issue   → Van owner → ERT Lead
Policy/compliance → University Approver
Go-live / rollback decision → University Approver + ERT Lead + IT Admin (all three)
```

---

## 6. Decisions still needing an owner + date

From the [Risk Register](21-Risk-Register-and-Gaps.md) — assign each an accountable person and a due date:

- **R10 DPDP / recording compliance** → University Approver
- **R9 security hardening sign-off** → IT Admin
- **R13 cost / BOM** → IT Admin + University
- Van power sizing + repeater plan → Van owner + Network
