# Agent instructions for issue #{{ISSUE_NUMBER}}

## Setup — read these first

Before doing anything else, read:

1. `CLAUDE.md` — project conventions, feedback loops, and constraints
2. `CONTEXT.md` — domain glossary; use only the terms defined here
3. Any ADRs in `docs/adr/` that touch the area you are about to change

## Fetch the issue

!`gh issue view {{ISSUE_NUMBER}} --comments`

## Implement

Implement what the issue describes. Follow every constraint in `CLAUDE.md` exactly:

- Annotate every function (mypy strict is enforced)
- Every new module in the package directory must have a corresponding test file in `tests/`
- Write doctests in pure utility functions
- Use `importlib.resources` for files in the package `resources/` directory
- Use `importlib.metadata` for version retrieval — never hardcode version strings
- Do not add comments that describe what code does; only add a comment when the WHY is non-obvious

## Validate

Run `nox` and iterate until all sessions pass:

```
nox
```

Do not commit until `nox` passes cleanly.

## Finish

1. Commit your changes with a message that explains the why, not the what.

2. Update the issue labels:
   ```
   gh issue edit {{ISSUE_NUMBER}} --remove-label ready-for-agent --add-label ready-for-human
   ```

3. Open a pull request:
   ```
   gh pr create \
     --title "<short title from the issue>" \
     --body "$(cat <<'EOF'
   ## Summary

   <1-3 bullet points>

   Closes #{{ISSUE_NUMBER}}

   🤖 Generated with [Claude Code](https://claude.com/claude-code)
   EOF
   )"
   ```
