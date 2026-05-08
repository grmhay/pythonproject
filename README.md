# Python CLI Project Template

This is a template for creating modern Python CLI applications with comprehensive tooling and best practices.

## Using This Template

To create a new project from this template:

1. Clone or download this repository
2. Run the configuration script with your desired project name and type:

```sh
# CLI project (default)
./create-python-project.sh my-project-name

# FastAPI project
./create-python-project.sh my-project-name --type=api

# CLI + FastAPI in one project
./create-python-project.sh my-project-name --type=both
```

| `--type` | Entry point | Dependencies |
|----------|-------------|--------------|
| `cli` (default) | `cli.py` via Click | `click` |
| `api` | `api.py` via FastAPI + uvicorn | `fastapi`, `uvicorn[standard]`, `httpx` (test) |
| `both` | `cli.py` + `api.py` | all of the above |

**Important**: The `create-python-project.sh` script is a one-time use script that configures the template for your new project. After running it:
- The script renames the `zamazingo` package directory to your project name
- Updates all references throughout the codebase
- Patches `pyproject.toml` and `flake.nix` for the chosen project type
- Updates the README with project-specific content
- Commits the changes to git
- **Removes itself** - the script deletes itself after successful configuration

The script validates project names to ensure they work as Python packages and handles the conversion of hyphens to underscores where needed for Python imports.

## Develop

Enter the Nix shell with:

```sh
nix develop
```

Then run the tests with:

```sh
nox
```

To see the available sessions, run:

```sh
nox --list
```

To format the codebase:

```sh
nox -s format -- --fix
```

## Build

To check and build the package, run:

```sh
nix build
```

## Run

To run the package, use:

```sh
nix run
```

... and with arguments:

```sh
nix run . -- --name=there --count=3
```

## Verifying a project setup

After bootstrapping a project, you can verify it is fully configured by running:

```sh
bash check-python-project-setup.sh /path/to/your/project
```

This checks package renaming, nix config, pre-commit hooks, prd/plans directories, CLAUDE.md, all Matt Pocock skills, and machine-level Claude skills.

## Developing this project
Because running the create-python-project.sh script ultimately deletes the script, you have to clone the repo locally, edit the script if that is what you are working on, commit and push the change then test it.

If it all goes to cr*p then you can just sudo \rm -r pythonproject and clone it again.
