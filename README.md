# pythonproject

The [Copier](https://copier.readthedocs.io) template for grmhay Python
projects, and the source of the canonical dev-rails checker they are held to.

## Generate a project

```sh
git clone https://github.com/grmhay/pythonproject /tmp/pythonproject
bash /tmp/pythonproject/create-python-project.sh my-project --type=cli|api|both|library
```

The script renders `./my-project` from `gh:grmhay/pythonproject` (latest tag),
initialises git on `main`, pins the rails checker in `flake.lock`, installs the
community skills, and offers to create the GitHub repo. Plain Copier works too:

```sh
nix run nixpkgs#copier -- copy --trust gh:grmhay/pythonproject my-project
```

| `type` | Entry points | Container + deploy PR |
|--------|--------------|-----------------------|
| `cli` | Click CLI, MCP server | yes |
| `api` | FastAPI + uvicorn, MCP server | yes |
| `both` | CLI, API, MCP server | yes |
| `library` | none | no; CI runs the gate and rails check only |

## Keep a project up to date

Inside a generated project:

```sh
nix run nixpkgs#copier -- update --trust
```

Template changes are merged three-way into the files the template manages
(noxfile, flake, CI, sandbox loop, pre-commit, `DEV_RAILS.md`). Files listed in
`_skip_if_exists` in `copier.yml` belong to the project and are never touched.
Project-specific nox sessions go in `noxfile_local.py`.

To adopt the template in a project that predates it, run `copier copy` over the
existing checkout with answers matching the project, then review the diff hunk
by hunk before committing `.copier-answers.yml`.

## Layout

| Path | What it is |
|------|-----------|
| `copier.yml` | Template questions and the managed / project-owned split |
| `template/` | What gets rendered into a project |
| `rails/` | The dev-rails checker (`check-rails`) and its spec; exposed as the flake's `check-rails` package |
| `.github/workflows/rails-check.yml` | Reusable workflow generated projects call to run the checker independently of their own noxfile |
| `create-python-project.sh` | Generator wrapper around `copier copy` |

## Develop

```sh
nix develop
nox
```

The test suite renders every project type and runs the rails checker on it.
CI additionally builds each rendered type with its own flake, overriding the
`pythonproject` input with the branch under test.

Release by tagging `vX.Y.Z`; `copier copy` and `copier update` default to the
latest tag.

## Verify a generated project

```sh
bash check-python-project-setup.sh   # inside the project
```
