---
name: do-work
description: Use this skill to implement a feature or fix a bug with discipline
---

## Steps

### 1. Understand
Read the task description and any referenced PRD or plan files.

### 2. Plan
If no plan exists, outline the approach in 3-5 bullet points before writing any code.

### 3. Implement
- **Logic / services**: Use red-green-refactor (one failing test → minimum code to pass → refactor → repeat)
- **CLI commands**: Implement directly; test via `click.testing.CliRunner`
- **Type annotations**: Add to every function; run `nox -s mypy` to verify

### 4. Validate
Run `nox`. Iterate until all five sessions pass.

### 5. Commit
Write a meaningful commit message describing the why, not the what.
