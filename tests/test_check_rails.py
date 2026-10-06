"""Tests for the dev-rails checker, run against freshly rendered templates.

Rendering every project type and checking it is what proves the template and
the rails agree: a template change that knocks generated projects off the
rails fails here, before any service pulls it in with `copier update`.
"""

from pathlib import Path

import copier
import pytest

from rails.check_rails import main

#: The repository root, which is the Copier template source.
TEMPLATE = Path(__file__).resolve().parent.parent

#: Every project type copier.yml offers.
PROJECT_TYPES = ["cli", "api", "both", "library"]


def _render(destination: Path, project_type: str) -> Path:
    """Render the template for *project_type* into *destination*."""
    copier.run_copy(
        str(TEMPLATE),
        str(destination),
        data={"project_name": f"demo-{project_type}", "type": project_type},
        defaults=True,
        unsafe=True,
        quiet=True,
    )
    return destination


@pytest.mark.parametrize("project_type", PROJECT_TYPES)
def test_rendered_project_is_on_the_rails(tmp_path: Path, project_type: str) -> None:
    """A freshly generated project of every type passes the checker."""
    project = _render(tmp_path / project_type, project_type)

    assert main([str(project)]) == 0


def test_dropping_mypy_strict_fails(tmp_path: Path) -> None:
    """The checker rejects a generated project that turned strict mypy off."""
    project = _render(tmp_path / "cli", "cli")
    pyproject = project / "pyproject.toml"
    pyproject.write_text(
        pyproject.read_text().replace("strict = true", "strict = false"),
    )

    assert main([str(project)]) == 1


def test_missing_spec_fails(tmp_path: Path) -> None:
    """A spec path that does not exist is an error, not a pass."""
    assert main([str(tmp_path), "--spec", str(tmp_path / "nope.toml")]) == 1
