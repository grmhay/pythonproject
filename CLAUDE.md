# Project Rules

## Environment
- Always work inside `nix develop`; never use pip or venv directly
- Run `nox` to validate; all five sessions must pass before committing

## Code conventions
- Every module in `vm_service/` must have a corresponding test file in `tests/`
- Annotate every function — mypy strict is enforced via nox
- Write doctests in pure utility functions (they run automatically via pytest)
- Use `importlib.resources` to access files in `vm_service/resources/`
- Use `importlib.metadata` for version retrieval; never hardcode version strings

## Feedback loops
Run before committing: `nox`
Or by session: `nox -s mypy`, `nox -s pytest`, `nox -s check`

## Project conventions
- vm-service manages the lifecycle of Proxmox-based virtual machines
- VM IDs are always integers and globally unique
- Use the Proxmox API exclusively — never the Proxmox CLI

## Out of scope (do not build)
- Nothing explicitly excluded

## Agent skills

### Issue tracker

Issues live in GitHub Issues (`github.com/grmhay/vm-service`). See `docs/agents/issue-tracker.md`.

### Triage labels

Uses the default five-label vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context repo — one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Dev rails

### Environment
- Always work inside `nix develop`; never use pip or venv directly
- Run `nox` to validate all five sessions: taplo → format → check → mypy → pytest

### Code conventions
- Every module must have a corresponding test file in `tests/`
- Annotate every function — mypy strict is enforced
- Write doctests in pure utility functions (they run via `--doctest-modules`)
- Use `importlib.resources` to access files in the package `resources/` directory
- Use `importlib.metadata` for version retrieval; never hardcode version strings

### Feedback loops
Run before committing: `nox`
Run a single session: `nox -s mypy`, `nox -s pytest`, `nox -s check`
Auto-fix formatting: `nox -s format -- --fix`

### Planning artefacts
- PRD files live in `prd/`
- Implementation plans live in `plans/`

### Daily workflow
New feature?   → /grill-with-docs → /to-prd → /to-issues
Start issue?   → /clear → @prd @plan "Do issue #N"
Write logic?   → /tdd (red-green-refactor, one test at a time)
Hard bug?      → /diagnose
Validate?      → nox
Architecture?  → /improve-codebase-architecture (run every few days)
