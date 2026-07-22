# Contributing to UPES-ECS

Thanks for your interest in improving UPES-ECS. This is an emergency
communication system, so correctness, safety, and data hygiene come first.

## Ground rules

- **Read the [Security Policy](SECURITY.md) before your first change.** The data
  hygiene rules (no PII, no secrets, no captured audio) are hard requirements.
- Be respectful — see the [Code of Conduct](CODE_OF_CONDUCT.md).
- Discuss substantial changes in an issue before opening a large PR.

## Development setup

The stack is polyglot: PowerShell (Windows host tooling), Python (`api/`,
console proxies), shell (`deploy/`, `scripts/`), Asterisk config (`config/`,
`deploy/asterisk/`), and MkDocs (`docs/`).

```bash
# Docs site
pip install -r docs/requirements.txt
mkdocs serve            # live preview at http://127.0.0.1:8000

# Quality gates (run before pushing)
pip install pre-commit
pre-commit install
pre-commit run --all-files
```

PowerShell scripts are linted with **PSScriptAnalyzer**; Python with **Ruff**;
shell with **ShellCheck**. CI runs all three on every PR.

## Conventions

- **Directories**: lowercase-kebab-case (`deploy/asterisk`).
- **PowerShell scripts**: `Verb-Noun.ps1` PascalCase, CRLF line endings (this is
  the one deliberate exception to the lowercase/LF rule — enforced by
  `.gitattributes` and `.editorconfig`).
- **Shell / config / Python**: LF line endings.
- **Docs**: kebab-case filenames; place pages under the right section
  (`getting-started`, `architecture`, `features`, `guides`, `operations`,
  `networking`, `reference`, `project`) and add them to `mkdocs.yml` `nav`.
- **Commits**: imperative mood, explain the *why*. Keep the
  [changelog](CHANGELOG.md) updated (Keep a Changelog format).

## Pull requests

1. Branch from `main`.
2. Keep PRs focused and reasonably small.
3. Ensure `pre-commit run --all-files` passes and no secrets/PII are staged.
4. Update docs and the changelog where relevant.
5. Fill in the PR template checklist.

## Adding data

Never add real rosters or credentials. If a new data-driven feature needs input
files, ship a sanitized `*.example.*` template and git-ignore the real file.
