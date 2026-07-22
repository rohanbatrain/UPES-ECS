# Security Policy

UPES-ECS is an emergency communication system. Security and data-handling
discipline are core requirements, not afterthoughts.

## Reporting a vulnerability

**Please do not open a public issue for security problems.**

Report privately via GitHub's **Security → Report a vulnerability** (private
advisories) on this repository, or email the maintainer. You can expect an
acknowledgement within **3 business days**.

Please include: affected component (Console, Asterisk dialplan, installer, API,
docs), reproduction steps, and impact.

## Supported versions

| Version | Supported |
|---------|-----------|
| `main`  | ✅ active  |
| tagged `1.x` | ✅ |
| < 1.0   | ❌ |

## Data-handling rules (hard requirements)

These are non-negotiable for this project and apply to code, docs, and any
contribution:

- **Never commit real personal data (PII).** Rosters, names, SAP IDs, phone
  extensions, and family links are provided as `*.example.*` templates only.
  The real files (`provisioning/*.csv`, `Console/directory.json`,
  `Notes/`) are git-ignored and stay on the operator's machine.
- **Never commit secrets.** SIP/PJSIP passwords, SSH keys, `.env`, and
  `secrets/` are git-ignored. The live `deploy/asterisk/pjsip_accounts.conf`
  contains real secrets and must never be committed — use
  `deploy/qemu/Add-UpesUser.ps1` (single source of truth).
- **Never commit captured emergency audio.** Recordings and voicemail stay on
  the server per the retention policy; only generated TTS voice prompts (Piper)
  are tracked, as source assets via Git LFS.
- If a secret is ever committed: **rotate/revoke it first**, then scrub history
  (`git filter-repo` / BFG) and force-push. History rewriting is cleanup, not
  remediation.

## Automated protections

This repository runs **gitleaks** secret scanning in CI and pre-commit. Enable
GitHub **Secret Scanning + Push Protection** on the hosted repository as well.
