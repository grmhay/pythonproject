# Project Rules

## Environment
- Always work inside `nix develop`; never use pip or venv directly
- Run `nox` to validate; all five sessions must pass before committing

## Code conventions
- Every module in `zamazingo/` must have a corresponding test file in `tests/`
- Annotate every function — mypy strict is enforced via nox
- Write doctests in pure utility functions (they run automatically via pytest)
- Use `importlib.resources` to access files in `zamazingo/resources/`
- Use `importlib.metadata` for version retrieval; never hardcode version strings

## Feedback loops
Run before committing: `nox`
Or by session: `nox -s mypy`, `nox -s pytest`, `nox -s check`

## Out of scope (do not build)
- [list anything explicitly excluded from this project]

## Agent skills

### Issue tracker

Issues live in GitHub Issues (`github.com/grmhay/pythonproject`). See `docs/agents/issue-tracker.md`.

### Triage labels

Uses the default five-label vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context repo — one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.
