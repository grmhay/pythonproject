# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

This project uses Nix and nox for development. All commands assume you're in a Nix development shell (`nix develop`).

### Testing and Quality Assurance
- `nox` - Run all test sessions (format check, lint, type check, tests)
- `nox --list` - Show all available nox sessions
- `nox -s pytest` - Run only the test suite
- `nox -s mypy` - Run type checking only
- `nox -s check` - Run linting only
- `nox -s format` - Check code formatting
- `nox -s format -- --fix` - Auto-fix formatting issues
- `nox -s taplo` - Check TOML file formatting
- `nox -s taplo -- --fix` - Auto-fix TOML formatting

### Building and Running
- `nix build` - Build the package
- `nix run` - Run the CLI application
- `nix run . -- --name=example --count=3` - Run with specific arguments

### Development Environment
- `nix develop` - Enter development shell with all dependencies

## Architecture Overview

This is a Python CLI application template project called "zamazingo" that demonstrates a well-structured Python package with modern tooling.

### Project Structure
- `zamazingo/` - Main package directory
  - `cli.py` - Click-based CLI interface with greeting functionality
  - `utils.py` - Utility functions (includes safe_divide with doctests)
  - `resources/` - Package resources and resource loading utilities
    - `help.txt` - Static help text file loaded at runtime
- `tests/` - Test suite using pytest
- `create-python-project.sh` - Template generator script for creating new projects

### Key Design Patterns
- **Resource Management**: Uses `importlib.resources` for accessing package data files
- **CLI Framework**: Built with Click for command-line interface
- **Version Management**: Dynamic version retrieval using `importlib.metadata`
- **Testing**: Comprehensive test coverage with pytest and Click's CliRunner
- **Code Quality**: Extensive linting with ruff, type checking with mypy

### Configuration Files
- `pyproject.toml` - Modern Python project configuration with extensive ruff rules
- `noxfile.py` - Test automation with multiple sessions
- `flake.nix` - Nix development environment and package definition

### Development Workflow
1. Enter Nix shell for reproducible environment
2. Use nox sessions for testing and quality checks
3. The project template can generate new CLI projects using the shell script

This is primarily a template project designed to be copied and modified for new Python CLI applications.