# Project Rules

## Environment
- Always work inside `nix develop`; never use pip or venv directly
- Run `nox` to validate; all six sessions must pass before committing

## Code conventions
- Every module in `rails/` must have a corresponding test file in `tests/`
- Annotate every function — mypy strict is enforced via nox
- Write doctests in pure utility functions (they run automatically via pytest)
- Use `importlib.metadata` for version retrieval; never hardcode version strings

## Feedback loops
Run before committing: `nox`
Or by session: `nox -s mypy`, `nox -s pytest`, `nox -s check`

## Template
- `template/` is rendered by Copier; files ending `.jinja` are templated, others are copied verbatim
- Never put `${{ }}` GitHub Actions expressions in a `.jinja` file; workflows stay plain YAML
- Any change under `template/` must keep `nox` green: the tests render every project type and run the rails checker on it
- Adding a file the project should own after generation? List it in `_skip_if_exists` in `copier.yml`

## Out of scope (do not build)
- [list anything explicitly excluded from this project]

## Agent skills

### Issue tracker

Issues live in GitHub Issues (`github.com/grmhay/pythonproject`). See `docs/agents/issue-tracker.md`.

### Triage labels

Uses the default five-label vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context repo — one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.
