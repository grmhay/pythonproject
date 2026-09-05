# Development Rails Setup Guide (Python + Nix)

A step-by-step guide to wiring up the AIHero development rails in a new Python project, using the standard tooling from [grmhay/pythonproject](https://github.com/grmhay/pythonproject).

---

## Tech Stack

```
Environment:     Nix flake (nixpkgs-unstable + flake-utils)
Build system:    setuptools (via pyproject.toml)
Python:          3.11+ (pinned via Nix)
Type checker:    mypy
Testing:         pytest (with --doctest-modules)
Linting:         ruff (85+ rules)
Formatting:      ruff format + taplo (TOML)
Task runner:     nox
Pre-commit:      pre-commit framework (via Nix)
CLI framework:   click          (--type=cli, --type=both)
API framework:   FastAPI        (--type=api, --type=both)
Tracking:        GitHub issues
```

---

## Phase 1: Bootstrap the Project

### 1.1 Install global Claude skills (once per machine)

Before setting up any project, ensure your global Claude skills are installed:

```bash
git clone https://github.com/grmhay/claudesetup
cd claudesetup
bash install.sh
cd .. && rm -rf claudesetup
```

This installs the `/setup-dev-rails` and `/omarchy` skills into `~/.claude/skills/`. The clone is no longer needed once installed. Community skills are installed per-project by `create-python-project.sh`.

### 1.2 Clone the template and run the generator script

```bash
git clone https://github.com/grmhay/pythonproject
cd pythonproject
bash create-python-project.sh <your-project-name> [--type=cli|api|both]
```

`--type` controls what gets generated (default: `cli`):

| Flag | What you get |
|------|-------------|
| `--type=cli` | Click CLI entry point (`cli.py`) |
| `--type=api` | FastAPI app (`api.py`) + uvicorn runner; click removed |
| `--type=both` | Both `cli.py` and `api.py`; all deps included |

The script will:
- Rename all references from `zamazingo` to your package name
- Patch `pyproject.toml` and `flake.nix` for the chosen type (deps, entrypoints, classifiers)
- Add `pre-commit` to `flake.nix`, create `.pre-commit-config.yaml`
- Create `prd/` and `plans/` directories
- Append dev rails rules to `CLAUDE.md`
- Optionally re-initialise git (clean history, update remote, or keep as-is)

### 1.3 Enter the Nix dev shell

```bash
nix develop
```

This drops you into a shell with Python, mypy, nox, ruff, taplo, ipython, and the LSP tools pre-installed. All subsequent commands assume you are inside `nix develop`.

### 1.4 Verify the baseline passes

```bash
nox
```

All six sessions should pass on a fresh clone before you touch anything:

| Session   | What it checks                          |
|-----------|-----------------------------------------|
| `taplo`   | TOML formatting                         |
| `format`  | ruff formatting + import order          |
| `check`   | ruff lint (63 rule groups)              |
| `rails`   | the project still matches these rails   |
| `mypy`    | type correctness (strict)               |
| `pytest`  | unit tests + doctests                   |

---

## Phase 2: Feedback Loops (Pre-commit Hooks)

Pre-commit hooks are quality gates that run deterministically on every commit — AI doesn't get frustrated by slow commits the way humans do.

`create-python-project.sh` handles all the pre-commit wiring automatically: it adds `pre-commit` to `flake.nix` and creates `.pre-commit-config.yaml` (which runs the full `nox` suite on every commit). The only manual step is installing the hook inside the Nix dev shell:

```bash
nix develop
pre-commit install
```

**Verify it works before moving on.** Make a trivial commit and confirm nox fires.

> **Why `nox` not individual hooks?**
> The noxfile is the authoritative definition of what "passing" means. Running it directly avoids duplicating that definition in two places.

---

## Phase 3: Project Structure

The template uses a flat package layout (package at root, not under `src/`).

**`--type=cli` (default):**

```
my-project/
├── my_package/
│   ├── __init__.py          # exposes __version__ via importlib.metadata
│   ├── cli.py               # click entry point
│   ├── utils.py             # business logic (doctest-friendly)
│   └── resources/
│       ├── __init__.py
│       └── help.txt
├── tests/
│   ├── __init__.py
│   ├── test_cli.py          # uses click.testing.CliRunner
│   └── test_utils.py
...
```

**`--type=api`:**

```
my-project/
├── my_package/
│   ├── __init__.py
│   ├── api.py               # FastAPI app + uvicorn runner
│   ├── utils.py
│   └── resources/
├── tests/
│   ├── __init__.py
│   ├── test_api.py          # uses fastapi.testclient.TestClient
│   └── test_utils.py
...
```

**`--type=both`:** includes `cli.py`, `api.py`, `test_cli.py`, and `test_api.py`.

Common files regardless of type:

```
├── prd/                     # pre-created in template
├── plans/                   # pre-created in template
├── .claude/
│   └── skills/
│       └── do-work/         # pre-created in template
├── CLAUDE.md
├── flake.nix
├── flake.lock
├── noxfile.py
└── pyproject.toml
```

`prd/`, `plans/`, and `.claude/skills/do-work/` are pre-created in the template — no manual setup needed.

---

## Phase 4: CLAUDE.md — Persistent Steering

The template ships with a pre-populated `CLAUDE.md` containing the dev rails rules. `create-python-project.sh` substitutes the package name automatically — no manual edits needed to get a working file.

The only thing to customise after setup is the **Out of scope** section:

```markdown
## Out of scope (do not build)
- [list anything explicitly excluded from this project]
```

Do NOT run `claude init` — it generates bloated, quickly-stale output.

**Good candidates for CLAUDE.md:**
- Project-specific conventions (doctest style, resource access pattern)
- Nox session names Claude should use
- Anything specific to your domain

**Bad candidates:**
- File paths and function names (they rot)
- Things Claude can read from pyproject.toml or noxfile.py
- More than ~10 rules total

---

## Phase 5: Skills

Skills come from two places:

- **`/do-work`** — bundled in the pythonproject template at `.claude/skills/do-work/SKILL.md`; no install needed
- **Global and community skills** — managed via [claudesetup](https://github.com/grmhay/claudesetup); installed once per machine by running `bash install.sh`

**Machine-level** — installed globally into `~/.claude/skills/` by `claudesetup/install.sh`:

| Skill | Description |
|-------|-------------|
| `/setup-dev-rails` | Finish wiring up dev rails interactively in Claude Code |
| `/omarchy` | Customise the Omarchy Linux desktop |

**Project-level** — installed into `.claude/skills/` per project by `create-python-project.sh` via `npx skills@latest add mattpocock/skills`:

| Skill | Purpose |
|-------|---------|
| `/grill-with-docs` | Interrogate a feature idea to clarity |
| `/to-prd` | Write a PRD from a grilled idea |
| `/to-issues` | Generate GitHub issues from a PRD |
| `/tdd` | Red-green-refactor, one test at a time |
| `/diagnose` | Debug a hard problem systematically |
| `/improve-codebase-architecture` | Architectural review |
| `/zoom-out` | Step back and review overall direction |
| `/triage` | Label and prioritise open issues |
| `/grill-me` | Stress-test your own thinking |
| `/write-a-skill` | Create a new Claude skill |
| `/setup-matt-pocock-skills` | Configure issue tracker and docs location |

### Verify skills are available

After setup, open Claude Code in the project and run:

```
/skills
```

---

## Phase 6: PRD Workflow

Use this before starting any feature that spans more than one session.

### 6.1 Interrogate the idea

```
/grill-with-docs
```

Describe the feature. The skill asks probing questions to surface assumptions and constraints. Don't rush — the interrogation is the value.

### 6.2 Write the PRD

```
/to-prd
```

Turns the grilled idea into a structured PRD. Output: a `prd/feature-name.md` file.

### PRD structure to expect

```markdown
## Problem Statement
Why does this exist?

## Solution
What are we building?

## User Stories
1. As [role], I want [X] so that [Y]
2. ...

## Implementation Decisions
- New modules needed
- Technical choices (sync vs async, new click commands, new utils)
- New resource files (if any)
- Testing approach (unit tests, doctests, CLI runner tests)

## Out of Scope
- [explicit exclusions]
```

### 6.3 Optionally stress-test with `/grill-me`

Run `/grill-me` on your PRD before generating issues. It will expose remaining gaps.

---

## Phase 7: Planning

### 7.1 Generate issues from the PRD

```
/to-issues @prd/feature-name.md
```

This creates a dependency graph of GitHub issues. Optionally draft a `plans/feature-name.md` file by hand to capture tracer-bullet sequencing before execution.

### 7.2 Tracer bullet rule

Each phase must be a **vertical slice** — touching all layers end-to-end (model/util → CLI command → test):

```
Phase 1: Tracer bullet — minimal working end-to-end path (proves the stack works)
Phase 2: Core feature X (expands on phase 1)
Phase 3: Core feature Y
Phase 4: Polish and error handling
```

NOT:
```
Phase 1: All utility functions
Phase 2: All CLI commands
Phase 3: All tests  ← too late to discover integration issues
```

### 7.3 What plans should contain

**Include (durable decisions):**
- Click command names and options
- Module / function names
- New resource files
- Key technical choices

**Exclude (stale quickly):**
- Function signatures
- Exact file paths
- Pseudocode implementations

---

## Phase 8: GitHub Issues (Kanban)

For larger features, break the PRD into linked GitHub issues rather than executing phases sequentially.

### 8.1 Generate issues from PRD

```
/to-issues @prd/feature-name.md
```

This creates a dependency graph:

```
Issue 1: Tracer bullet            [unblocked — start here]
Issue 2: Feature A         blocked by #1
Issue 3: Feature B         blocked by #1
Issue 4: Polish            blocked by #2, #3
Issue 5: QA checklist      unblocked [human gate]
```

### 8.2 QA issues

Create a dedicated QA issue with a manual checklist:

```markdown
## QA Checklist
- [ ] `nox` passes (all six sessions)
- [ ] CLI happy path works end-to-end
- [ ] Error cases show correct messages
- [ ] Behaviour matches PRD user stories
- [ ] New commands appear in `--help`
```

---

## Phase 9: Execution Loop

### 9.1 Per-phase execution (HITL)

```bash
# 1. Clear context
/clear

# 2. Start the phase (always inside nix develop)
@prd/feature-name.md @plans/feature-name.md Do phase 1

# 3. Let it explore (expected; don't interrupt)
# 4. Review output manually
# 5. Give feedback in same context window
# 6. Commit when satisfied
git add -p && git commit -m "feat: phase 1 tracer bullet"

# 7. Clear before next phase
/clear
```

**Context meter discipline:**
- Clear at ~35-40% context usage
- Do not continue complex work past 50%

### 9.2 Red-green-refactor with pytest

```
Write one failing test → nox -s pytest (red)
Write minimum code to pass → nox -s pytest (green)
Refactor while tests stay green → nox (all sessions)
Repeat for next behaviour
```

Example: write the test first, watch it fail, then implement:

```python
# tests/test_utils.py
def test_my_new_function() -> None:
    result = my_new_function(x=5)
    assert result == 10
```

Then implement in `my_package/utils.py` with a doctest:

```python
def my_new_function(x: int) -> int:
    """Double the input.

    >>> my_new_function(5)
    10
    """
    return x * 2
```

Run `nox -s pytest` — both the unit test and the doctest will be picked up.

---

## Quick Reference: Nox Sessions

```bash
nox                    # run all sessions (the gate)
nox -s taplo           # check TOML formatting
nox -s format          # check ruff format + import order
nox -s format -- --fix # auto-fix formatting
nox -s check           # lint with ruff
nox -s rails           # check the project has not drifted off the rails
nox -s mypy            # type check
nox -s pytest          # unit tests + doctests
```

---

## Phase 2b: The gate in CI, and the deploy PR

The pre-commit hook is bypassable with `--no-verify`, and it does not exist at
all on a machine where nobody ran `pre-commit install`. So the gate also runs in
CI, in `.github/workflows/docker-publish.yml`:

| Job            | What it does                                                        |
|----------------|---------------------------------------------------------------------|
| `quality`      | `nix build '.#default' -L` — runs every nox session via `checkPhase`, with the tool versions pinned in `flake.lock` |
| `rails-check`  | runs the canonical checker from `pythonproject` — independent of this repo's own noxfile |
| `build-and-push` | builds and pushes the image; **needs both gates**                 |
| `deploy-pr`    | opens/updates the `deploy/<stack>` PR in the ops control plane      |

Two properties worth keeping:

- **The publish depends on the gate.** A gate that runs alongside the publish
  rather than before it cannot stop a bad image shipping. Two services in this
  fleet ran nox in CI while publishing from a job that did not depend on it.
- **`quality` uses the flake**, so CI and `nix develop` cannot drift apart. If a
  package's dynamic `setuptools-scm` version cannot resolve in the sandbox, use
  `nix develop --command nox` instead — the `rails` check accepts either.

Merging the deploy PR is the approval point; the reconciler rolls it out from
there. Nothing deploys straight from a green build.

### Why a `rails` session at all

`DEV_RAILS.md` has always described the rails correctly, and every project
generated from this template carries a copy. Four services drifted anyway —
prose is advisory, and nothing executed it. The `rails` session executes it:
the invariants live as data in `rails/rails-spec.toml` and are checked on every
commit and every build.

---

## Quick Reference: Daily Workflow

```
Start work?
  → nix develop

New feature?
  → /grill-with-docs   (interrogate to clarity)
  → /to-prd            (write the PRD)
  → /to-issues         (generate dependency graph)

Starting work on an issue?
  → /clear
  → @prd @plan "Do issue #N"
  → Review → commit → /clear

Writing logic?
  → /tdd               (red-green-refactor, one test at a time)
  → add doctests to pure utility functions

Hard bug?
  → /diagnose

Before committing?
  → nox (auto via pre-commit hook)

Architecture review?
  → /improve-codebase-architecture (run every few days)

Context getting high?
  → commit, /clear, start fresh

Build / run?
  → nix build
  → nix run                    # CLI (--type=cli or --type=both default script)
  → my-project-api             # API server (--type=api or --type=both, inside nix develop)
```

---

## Checklist: Is the Project Set Up?

**Once per machine:**
- [ ] `claudesetup` cloned and `bash install.sh` run — `/setup-dev-rails` and `/omarchy` installed globally

**Per project:**
- [ ] `create-python-project.sh` run; package renamed from `zamazingo`, dev rails wired up
- [ ] `nix develop` works and drops into dev shell
- [ ] `nox` passes all six sessions on the fresh template
- [ ] `pre-commit install` run inside `nix develop`
- [ ] Pre-commit fires on a test commit and blocks on failure
- [ ] `CLAUDE.md` "Out of scope" section updated for this project (via `/setup-dev-rails`)
- [ ] Community skills installed into `.claude/skills/` (via `/setup-dev-rails`)
- [ ] `/do-work` skill present (bundled in template)
- [ ] Verified `/skills` lists all skills
- [ ] GitHub issues enabled for the repo (for kanban workflow)
