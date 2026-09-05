"""Check a project against the canonical dev-rails invariants.

The rules live in ``rails-spec.toml`` next to this file, never in here, so the
two ways of invoking the checker -- ``nox -s rails`` locally and the
``rails-check`` reusable workflow in CI -- read the same definition and cannot
disagree about what the rails are.

Every invariant checked here corresponds to a way a real project drifted. See
the comments in the spec for which.

Usage::

    check-rails [PROJECT_DIR] [--spec PATH]
"""

from __future__ import annotations

import argparse
import sys
import tomllib
from pathlib import Path
from typing import TYPE_CHECKING, Any

import yaml

if TYPE_CHECKING:
    from collections.abc import Iterator

#: Marker for a failed check, and the process exit code when any check fails.
_FAILURE_EXIT = 1

#: ruff's catch-all: a project selecting it is a superset of any spec list.
_RUFF_ALL = "ALL"


class Report:
    """Accumulates check results and prints them as they are decided."""

    def __init__(self) -> None:
        """Start an empty report."""
        self.failures: list[str] = []
        self.warnings: list[str] = []
        self.passes: int = 0

    def ok(self, message: str) -> None:
        """Record a satisfied invariant."""
        self.passes += 1
        print(f"[PASS] {message}")

    def fail(self, message: str, fix: str) -> None:
        """Record a violated invariant, alongside how to fix it."""
        self.failures.append(message)
        print(f"[FAIL] {message}")
        print(f"       fix: {fix}")

    def warn(self, message: str, fix: str) -> None:
        """Record an advisory finding that does not fail the gate."""
        self.warnings.append(message)
        print(f"[WARN] {message}")
        print(f"       {fix}")

    def skip(self, message: str) -> None:
        """Record an invariant that does not apply to this project."""
        print(f"[SKIP] {message}")


def _load_toml(path: Path) -> dict[str, Any]:
    """Parse a TOML file, returning an empty mapping when it is absent."""
    if not path.is_file():
        return {}
    with path.open("rb") as handle:
        return tomllib.load(handle)


def _check_mypy(project: Path, spec: dict[str, Any], report: Report) -> None:
    """Verify mypy strict is on, as every rails project already claims."""
    if not spec.get("mypy", {}).get("strict", False):
        return
    pyproject = _load_toml(project / "pyproject.toml")
    mypy = pyproject.get("tool", {}).get("mypy")
    if mypy is None:
        report.fail(
            "pyproject.toml has no [tool.mypy] section",
            'add [tool.mypy] with strict = true -- "mypy strict is enforced" is '
            "claimed by CLAUDE.md and is otherwise untrue",
        )
    elif not mypy.get("strict", False):
        report.fail(
            "[tool.mypy] does not set strict = true",
            "add strict = true; measure the backlog first with `mypy --strict <paths>`",
        )
    else:
        report.ok("mypy strict is enabled")


def _check_ruff(project: Path, spec: dict[str, Any], report: Report) -> None:
    """Verify the ruff rule list has not silently narrowed."""
    required = spec.get("ruff", {}).get("select", [])
    if not required:
        return
    pyproject = _load_toml(project / "pyproject.toml")
    selected = pyproject.get("tool", {}).get("ruff", {}).get("lint", {}).get("select")
    if selected is None:
        report.fail(
            "pyproject.toml selects no ruff rules",
            "add [tool.ruff.lint] select with the canonical group list",
        )
        return
    if _RUFF_ALL in selected:
        report.ok(f"ruff selects {_RUFF_ALL} (superset of the canonical list)")
        return
    missing = [group for group in required if group not in selected]
    if missing:
        report.fail(
            f"ruff select is missing {len(missing)} canonical group(s): "
            f"{', '.join(missing)}",
            "restore the missing groups; size the backlog first with "
            "`nox -s check -- --stats`",
        )
    else:
        report.ok(f"ruff selects all {len(required)} canonical groups")


def _check_pre_commit(project: Path, report: Report) -> None:
    """Verify the commit hook runs the gate rather than a subset of it."""
    config = project / ".pre-commit-config.yaml"
    if not config.is_file():
        report.fail(
            ".pre-commit-config.yaml is missing",
            "add it with a local hook running nox, then `pre-commit install`",
        )
    elif "nox" not in config.read_text(encoding="utf-8"):
        report.fail(
            ".pre-commit-config.yaml does not run nox",
            "run nox itself rather than duplicating its sessions as hooks",
        )
    else:
        report.ok(".pre-commit-config.yaml runs nox")


def _check_nox_sessions(project: Path, spec: dict[str, Any], report: Report) -> None:
    """Every session the gate is defined as must exist."""
    required: list[str] = spec.get("nox", {}).get("sessions", [])
    if not required:
        return
    noxfile = project / "noxfile.py"
    if not noxfile.is_file():
        report.fail("noxfile.py is missing", "the gate is defined by the noxfile")
        return
    source = noxfile.read_text(encoding="utf-8")
    missing = [
        name
        for name in required
        if f'name="{name}"' not in source and f"def {name}(" not in source
    ]
    if missing:
        report.fail(
            f"noxfile.py defines no {', '.join(missing)} session(s)",
            "restore the missing sessions",
        )
    else:
        report.ok(f"noxfile.py defines all {len(required)} gate sessions")


def _workflows(project: Path) -> Iterator[tuple[Path, dict[str, Any]]]:
    """Yield each parseable workflow under .github/workflows."""
    directory = project / ".github" / "workflows"
    if not directory.is_dir():
        return
    for path in sorted(directory.glob("*.y*ml")):
        try:
            loaded = yaml.safe_load(path.read_text(encoding="utf-8"))
        except yaml.YAMLError:
            continue
        if isinstance(loaded, dict):
            yield path, loaded


def _job_runs_gate(job: dict[str, Any]) -> bool:
    """Report whether a job runs the nox gate, by either accepted variant."""
    for step in job.get("steps") or []:
        if not isinstance(step, dict):
            continue
        run = str(step.get("run", ""))
        # `nix build` runs nox via the package checkPhase; `nix develop` runs it
        # directly. Both are in use across the fleet -- a package whose dynamic
        # version cannot resolve in the sandbox must use the latter.
        if "nix build" in run or "nox" in run:
            return True
    return False


def _job_publishes(job: dict[str, Any]) -> bool:
    """Report whether a job pushes an image."""
    for step in job.get("steps") or []:
        if isinstance(step, dict) and "build-push-action" in str(step.get("uses", "")):
            return True
    return False


def _needs_closure(jobs: dict[str, Any], start: str) -> set[str]:
    """Return every job reachable from ``start`` through `needs` edges."""
    seen: set[str] = set()
    pending = [start]
    while pending:
        current = pending.pop()
        needs = jobs.get(current, {}).get("needs") or []
        if isinstance(needs, str):
            needs = [needs]
        for name in needs:
            if name not in seen:
                seen.add(name)
                pending.append(name)
    return seen


def _collect_ci_jobs(
    project: Path,
) -> tuple[set[str], set[str], dict[str, Any]]:
    """Return the gate jobs, the publishing jobs, and every job by name.

    Jobs are collected across all workflows, because the gate and the publish
    can live in different files -- and when they do, `needs` cannot span them,
    which is exactly the gap worth reporting.
    """
    gate_jobs: set[str] = set()
    publish_jobs: set[str] = set()
    all_jobs: dict[str, Any] = {}
    for _path, workflow in _workflows(project):
        for name, job in (workflow.get("jobs") or {}).items():
            if not isinstance(job, dict):
                continue
            all_jobs[name] = job
            if _job_runs_gate(job):
                gate_jobs.add(name)
            if _job_publishes(job):
                publish_jobs.add(name)
    return gate_jobs, publish_jobs, all_jobs


def _check_ci(project: Path, spec: dict[str, Any], report: Report) -> None:
    """CI must run the gate, and publishing must be blocked behind it."""
    ci_spec = spec.get("ci", {})
    if not ci_spec.get("require_gate", False):
        return

    gate_jobs, publish_jobs, all_jobs = _collect_ci_jobs(project)

    if not gate_jobs:
        report.fail(
            "no CI workflow runs the nox gate",
            "add a quality job running `nix build '.#default' -L` (or "
            "`nix develop --command nox`) -- without it the pre-commit hook is "
            "the only enforcement, and --no-verify skips that",
        )
        return
    report.ok(f"CI runs the nox gate ({', '.join(sorted(gate_jobs))})")

    if not ci_spec.get("require_publish_needs_gate", False):
        return
    if not publish_jobs:
        report.skip("no publishing job to gate")
        return
    ungated = [
        name
        for name in publish_jobs
        if not (_needs_closure(all_jobs, name) & gate_jobs)
    ]
    if ungated:
        report.fail(
            f"publish job(s) {', '.join(ungated)} do not depend on the gate",
            "add `needs: <gate job>` -- a gate that cannot block a publish is "
            "decoration",
        )
    else:
        report.ok("publishing is blocked behind the gate")


def _check_flake(project: Path, spec: dict[str, Any], report: Report) -> None:
    """Verify a dynamic version has setuptools-scm in the flake build-system."""
    if not spec.get("flake", {}).get(
        "require_setuptools_scm_when_dynamic_version", False
    ):
        return
    pyproject = _load_toml(project / "pyproject.toml")
    dynamic = pyproject.get("project", {}).get("dynamic") or []
    if "version" not in dynamic:
        report.skip("version is static; setuptools-scm not required")
        return
    flake = project / "flake.nix"
    if not flake.is_file():
        report.skip("no flake.nix")
        return
    if "setuptools-scm" in flake.read_text(encoding="utf-8"):
        report.ok("flake.nix provides setuptools-scm for the dynamic version")
    else:
        report.fail(
            'pyproject declares dynamic = ["version"] but flake.nix has no '
            "setuptools-scm",
            "add setuptools-scm to the flake build-system and set "
            "SETUPTOOLS_SCM_PRETEND_VERSION -- otherwise `nix build` fails "
            "before it reaches checkPhase",
        )


def _package_dir(project: Path) -> Path | None:
    """Locate the project's package directory from pyproject's project name."""
    pyproject = _load_toml(project / "pyproject.toml")
    name = pyproject.get("project", {}).get("name")
    if not name:
        return None
    candidate = project / str(name).replace("-", "_")
    return candidate if candidate.is_dir() else None


def _module_referenced(module: Path, package: Path, corpus: str) -> bool:
    """Report whether any test refers to this module, by dotted path or name."""
    dotted = ".".join(
        (package.name, *module.relative_to(package).with_suffix("").parts)
    )
    return dotted in corpus or f"import {module.stem}" in corpus


def _check_tests(project: Path, spec: dict[str, Any], report: Report) -> None:
    """Every module should have a test file, as CLAUDE.md claims."""
    tests_spec = spec.get("tests", {})
    if not tests_spec.get("require_test_per_module", False):
        return
    package = _package_dir(project)
    if package is None:
        report.skip("could not locate the package directory")
        return
    ignore = set(tests_spec.get("ignore_modules", []))
    tests_dir = project / "tests"
    if not tests_dir.is_dir():
        report.fail("no tests/ directory", "add one")
        return
    existing = {path.name for path in tests_dir.rglob("test_*.py")}
    # A module counts as covered if a conventionally-named test file exists OR
    # any test refers to it. Matching on filename alone punishes reasonable
    # names -- tests/test_records_api.py does cover api/records.py -- and
    # proves nothing about coverage either way.
    corpus = "\n".join(
        path.read_text(encoding="utf-8", errors="ignore")
        for path in tests_dir.rglob("*.py")
    )
    missing = [
        module.relative_to(project).as_posix()
        for module in sorted(package.rglob("*.py"))
        if module.stem not in ignore
        and f"test_{module.stem}.py" not in existing
        and not _module_referenced(module, package, corpus)
    ]
    if missing:
        report.warn(
            f"{len(missing)} module(s) have no obvious test coverage: "
            f"{', '.join(missing)}",
            "advisory only -- a module exercised indirectly (through a "
            "TestClient, say) cannot be detected from the source, so this "
            "never fails the gate",
        )
    else:
        report.ok("every module has apparent test coverage")


def _parse_args(argv: list[str] | None) -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "project",
        nargs="?",
        default=".",
        help="project directory to check (default: the current directory)",
    )
    parser.add_argument(
        "--spec",
        default=None,
        help="path to rails-spec.toml (default: alongside this script)",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Check a project and return the process exit code."""
    args = _parse_args(argv)
    project = Path(args.project).resolve()
    spec_path = (
        Path(args.spec) if args.spec else Path(__file__).with_name("rails-spec.toml")
    )
    spec = _load_toml(spec_path)
    if not spec:
        print(f"error: no rails spec at {spec_path}", file=sys.stderr)
        return _FAILURE_EXIT

    print(f"Checking dev rails in: {project}")
    print("─" * 60)
    report = Report()
    _check_mypy(project, spec, report)
    _check_ruff(project, spec, report)
    _check_pre_commit(project, report)
    _check_nox_sessions(project, spec, report)
    _check_ci(project, spec, report)
    _check_flake(project, spec, report)
    _check_tests(project, spec, report)
    print("─" * 60)

    warned = f", {len(report.warnings)} advisory" if report.warnings else ""
    if report.failures:
        print(f"{report.passes} passed, {len(report.failures)} failed{warned}")
        return _FAILURE_EXIT
    print(f"{report.passes} passed{warned} — on the rails")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
