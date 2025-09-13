# Python CLI Project Template

This is a template for creating modern Python CLI applications with comprehensive tooling and best practices.

## Using This Template

To create a new project from this template:

1. Clone or download this repository
2. Run the configuration script with your desired project name:

```sh
./create-python-project.sh my-project-name
```

**Important**: The `create-python-project.sh` script is a one-time use script that configures the template for your new project. After running it:
- The script renames the `zamazingo` package directory to your project name
- Updates all references throughout the codebase
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
