#!/usr/bin/env bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# ── Dependency checks ─────────────────────────────────────────────────────────

check_dependencies() {
    if ! command -v nix &> /dev/null; then
        print_error "nix is not installed. Install it from https://nixos.org/download before continuing."
        exit 1
    fi
}

# Issue #7: ensure nix experimental features are enabled
check_nix_config() {
    local nix_conf="${HOME}/.config/nix/nix.conf"
    if grep -q "experimental-features" "$nix_conf" 2>/dev/null; then
        return 0
    fi
    print_warning "Nix experimental features (nix-command, flakes) are not enabled."
    print_info "Configuring ~/.config/nix/nix.conf..."
    mkdir -p "${HOME}/.config/nix"
    echo "experimental-features = nix-command flakes" >> "$nix_conf"
    print_success "Nix experimental features enabled. 'nix develop' will now work."
}

# ── Validation ────────────────────────────────────────────────────────────────

validate_project_name() {
    local name="$1"
    if [[ -z "$name" ]]; then
        print_error "Project name cannot be empty"
        return 1
    fi
    if [[ ! "$name" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
        print_error "Project name must start with a letter and contain only letters, numbers, underscores, and hyphens"
        return 1
    fi
    local python_name="${name//-/_}"
    if [[ ! "$python_name" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
        print_error "Project name contains invalid characters for Python package"
        return 1
    fi
    return 0
}

# ── Package renaming ──────────────────────────────────────────────────────────

rename_package_directory() {
    local old_name="$1"
    local new_name="$2"
    local python_name="${new_name//-/_}"
    if [[ -d "$old_name" ]]; then
        mv "$old_name" "$python_name"
        print_success "Renamed directory: $old_name -> $python_name"
    fi
}

replace_content() {
    local old_name="$1"
    local new_name="$2"
    local project_type="${3:-cli}"
    local python_name="${new_name//-/_}"

    print_info "Replacing content in files"

    local files_to_update=(
        "pyproject.toml"
        "noxfile.py"
        "CLAUDE.md"
        "Dockerfile"
        "package.json"
        "$python_name/__init__.py"
        "$python_name/cli.py"
        "$python_name/api.py"
        "$python_name/resources/__init__.py"
        "tests/test_cli.py"
        "tests/test_api.py"
        "tests/test_utils.py"
    )

    for file in "${files_to_update[@]}"; do
        if [[ -f "$file" ]]; then
            sed -i "s/$old_name/$python_name/g" "$file"
            if [[ "$file" == "pyproject.toml" ]]; then
                sed -i "s/name = \"$python_name\"/name = \"$new_name\"/" "$file"
                sed -i "s/prog_name=\"$python_name\"/prog_name=\"$new_name\"/" "$file"
            fi
            if [[ "$file" == *"cli.py" ]]; then
                sed -i "s/prog_name=\"$python_name\"/prog_name=\"$new_name\"/" "$file"
                sed -i "s/I am $python_name/I am $new_name/g" "$file"
            fi
            if [[ "$file" == *"api.py" ]]; then
                sed -i "s/title=\"$python_name\"/title=\"$new_name\"/" "$file"
            fi
            if [[ "$file" == "Dockerfile" ]]; then
                # The CLI entrypoint command uses hyphens (new_name), not underscores (python_name)
                sed -i "s/ENTRYPOINT \[\"$python_name\"\]/ENTRYPOINT [\"$new_name\"]/" "$file"
            fi
            if [[ "$file" == "CLAUDE.md" ]]; then
                local gh_user=""
                if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
                    gh_user=$(gh api user --jq .login 2>/dev/null || echo "")
                fi
                if [[ -n "$gh_user" ]]; then
                    sed -i "s|github\.com/grmhay/pythonproject|github.com/$gh_user/$new_name|g" "$file"
                else
                    sed -i "s|github\.com/grmhay/pythonproject|github.com/<your-username>/$new_name|g" "$file"
                fi
            fi
            print_success "Updated: $file"
        fi
    done

    # Remove files not needed for this project type
    case "$project_type" in
        cli)
            rm -f "$python_name/api.py" "tests/test_api.py"
            print_info "Removed API files (CLI-only project)"
            ;;
        api)
            rm -f "$python_name/cli.py" "tests/test_cli.py"
            print_info "Removed CLI files (API-only project)"
            ;;
        both)
            print_info "Keeping both CLI and API files"
            ;;
    esac
}

patch_for_type() {
    local python_name="$1"
    local new_name="$2"
    local project_type="$3"

    [[ "$project_type" == "cli" ]] && return 0

    print_info "Patching project files for type: $project_type"

    case "$project_type" in
        api)
            sed -i 's/dependencies = \["click"\]/dependencies = ["fastapi", "uvicorn[standard]"]/' pyproject.toml
            sed -i 's/test = \["mypy", "nox", "pytest", "ruff"\]/test = ["httpx", "mypy", "nox", "pytest", "ruff"]/' pyproject.toml
            sed -i "s/${python_name} = \"${python_name}\.cli:main\"/${python_name} = \"${python_name}.api:run\"/" pyproject.toml
            sed -i 's/Yet Another Python CLI Application/Yet Another Python API/' pyproject.toml
            sed -i 's/keywords = \["cli"\]/keywords = ["api"]/' pyproject.toml
            sed -i '/"Environment :: Console",/d' pyproject.toml
            sed -i 's/a CLI tool/an API/' "${python_name}/__init__.py"
            sed -i 's/pkgs\.python3Packages\.click/pkgs.python3Packages.fastapi\n            pkgs.python3Packages.uvicorn/' flake.nix
            sed -i 's/pkgs\.python3Packages\.pytest$/pkgs.python3Packages.pytest\n            pkgs.python3Packages.httpx/' flake.nix
            print_success "Patched for API: fastapi+uvicorn deps, api entrypoint."
            ;;
        both)
            sed -i 's/dependencies = \["click"\]/dependencies = ["click", "fastapi", "uvicorn[standard]"]/' pyproject.toml
            sed -i 's/test = \["mypy", "nox", "pytest", "ruff"\]/test = ["httpx", "mypy", "nox", "pytest", "ruff"]/' pyproject.toml
            sed -i "/${python_name} = \"${python_name}\.cli:main\"/a ${new_name}-api = \"${python_name}.api:run\"" pyproject.toml
            sed -i 's/Yet Another Python CLI Application/Yet Another Python Application/' pyproject.toml
            sed -i 's/keywords = \["cli"\]/keywords = ["cli", "api"]/' pyproject.toml
            sed -i 's/a CLI tool/a CLI tool and API/' "${python_name}/__init__.py"
            sed -i 's/pkgs\.python3Packages\.click/pkgs.python3Packages.click\n            pkgs.python3Packages.fastapi\n            pkgs.python3Packages.uvicorn/' flake.nix
            sed -i 's/pkgs\.python3Packages\.pytest$/pkgs.python3Packages.pytest\n            pkgs.python3Packages.httpx/' flake.nix
            print_success "Patched for CLI+API: click+fastapi+uvicorn deps, both entrypoints."
            ;;
    esac
}

update_readme() {
    local project_name="$1"
    local project_type="${2:-cli}"
    local readme_file="README.md"

    local type_desc
    case "$project_type" in
        cli)  type_desc="A Python CLI application." ;;
        api)  type_desc="A Python API application." ;;
        both) type_desc="A Python application with CLI and API." ;;
    esac

    if [[ -f "$readme_file" ]]; then
        cat > "$readme_file" << EOF
# $project_name

$type_desc

## Develop

Enter the Nix shell with:

\`\`\`sh
nix develop
\`\`\`

Then run the tests with:

\`\`\`sh
nox
\`\`\`

To see the available sessions, run:

\`\`\`sh
nox --list
\`\`\`

To format the codebase:

\`\`\`sh
nox -s format -- --fix
\`\`\`

## Build

To check and build the package, run:

\`\`\`sh
nix build
\`\`\`

## Run
EOF

        case "$project_type" in
            cli)
                cat >> "$readme_file" << EOF

To run the CLI, use:

\`\`\`sh
nix run
\`\`\`

... and with arguments:

\`\`\`sh
nix run . -- --name=there --count=3
\`\`\`
EOF
                ;;
            api)
                cat >> "$readme_file" << EOF

To start the API server:

\`\`\`sh
nix run
\`\`\`

The API will be available at <http://localhost:8000>.
Docs at <http://localhost:8000/docs>.
EOF
                ;;
            both)
                cat >> "$readme_file" << EOF

Inside \`nix develop\`, run the CLI:

\`\`\`sh
$project_name --name=there --count=3
\`\`\`

Start the API server:

\`\`\`sh
${project_name}-api
\`\`\`

The API will be available at <http://localhost:8000>.
Docs at <http://localhost:8000/docs>.
EOF
                ;;
        esac

        cat >> "$readme_file" << 'EOF'

## Sandbox Loop

The Sandbox Loop runs Claude Code against GitHub Issues labelled `ready-for-agent`, implements them inside an isolated Docker container, and opens a pull request per issue.

### First-time setup

Copy `.sandcastle/.env.example` to `.sandcastle/.env` and fill in your credentials:

```sh
cp .sandcastle/.env.example .sandcastle/.env
```

Build the sandbox Docker image (only needed once, or after editing `.sandcastle/Dockerfile`):

```sh
npx sandcastle docker build-image
```

### Running the loop

1. Apply the `ready-for-agent` label to any fully-specified issue
2. Run the loop:
   ```sh
   npm run sandcastle
   ```
3. The agent opens a PR per issue and moves the label from `ready-for-agent` to `ready-for-human`
4. Review and merge the PR

### Prerequisites

- Docker running locally
- `gh` CLI authenticated (`gh auth login`)
- `ANTHROPIC_API_KEY` and `GITHUB_TOKEN` set in `.sandcastle/.env`
EOF

        print_success "Updated README.md"
    fi
}

# ── Dev rails setup ───────────────────────────────────────────────────────────

setup_dev_rails() {
    print_info "Setting up dev rails..."

    # Add pre-commit to flake.nix dev shell
    if grep -q "pre-commit" flake.nix; then
        print_warning "pre-commit already present in flake.nix — skipping."
    else
        if grep -q "ipython" flake.nix; then
            sed -i 's/ipython/ipython\n            pre-commit/' flake.nix
            print_success "Added pre-commit to flake.nix."
        else
            print_warning "Could not auto-patch flake.nix — add 'pre-commit' to devShell packages manually."
        fi
    fi

    # Create .pre-commit-config.yaml
    if [[ -f .pre-commit-config.yaml ]]; then
        print_warning ".pre-commit-config.yaml already exists — skipping."
    else
        cat > .pre-commit-config.yaml << 'EOF'
repos:
  - repo: local
    hooks:
      - id: nox
        name: nox
        entry: nox
        language: system
        pass_filenames: false
        always_run: true
EOF
        print_success "Created .pre-commit-config.yaml."
    fi

    # Create prd/ and plans/ directories
    mkdir -p prd plans
    touch prd/.gitkeep plans/.gitkeep
    print_success "Created prd/ and plans/ directories."

    # Append dev rails section to CLAUDE.md
    local DEV_RAILS_MARKER="## Dev rails"
    if grep -q "${DEV_RAILS_MARKER}" CLAUDE.md 2>/dev/null; then
        print_warning "Dev rails section already present in CLAUDE.md — skipping."
    else
        cat >> CLAUDE.md << 'EOF'

## Dev rails

### Environment
- Always work inside `nix develop`; never use pip or venv directly
- Run `nox` to validate all five sessions: taplo → format → check → mypy → pytest

### Code conventions
- Every module must have a corresponding test file in `tests/`
- Annotate every function — mypy strict is enforced
- Write doctests in pure utility functions (they run via `--doctest-modules`)
- Use `importlib.resources` to access files in the package `resources/` directory
- Use `importlib.metadata` for version retrieval; never hardcode version strings

### Feedback loops
Run before committing: `nox`
Run a single session: `nox -s mypy`, `nox -s pytest`, `nox -s check`
Auto-fix formatting: `nox -s format -- --fix`

### Planning artefacts
- PRD files live in `prd/`
- Implementation plans live in `plans/`

### Daily workflow
New feature?   → /grill-with-docs → /to-prd → /to-issues
Start issue?   → /clear → @prd @plan "Do issue #N"
Write logic?   → /tdd (red-green-refactor, one test at a time)
Hard bug?      → /diagnose
Validate?      → nox
Architecture?  → /improve-codebase-architecture (run every few days)
EOF
        print_success "Dev rails section appended to CLAUDE.md."
    fi
}

# ── Docker Hub secrets ───────────────────────────────────────────────────────

setup_docker_secrets() {
    local project_name="$1"

    if ! command -v gh &>/dev/null; then
        print_warning "gh CLI not found — skipping Docker Hub secrets setup."
        return 0
    fi

    if ! gh auth status &>/dev/null 2>&1; then
        print_warning "gh CLI not authenticated — skipping Docker Hub secrets setup."
        return 0
    fi

    local gh_user
    gh_user=$(gh api user --jq .login 2>/dev/null || echo "")
    if [[ -z "$gh_user" ]]; then
        print_warning "Could not determine GitHub username — skipping Docker Hub secrets setup."
        return 0
    fi

    if ! gh repo view "$gh_user/$project_name" &>/dev/null 2>&1; then
        print_warning "Repo $gh_user/$project_name not found on GitHub — skipping Docker Hub secrets setup."
        return 0
    fi

    echo ""
    local setup_secrets=""
    read -t 15 -p "Set Docker Hub secrets on $gh_user/$project_name? [Y/n] " setup_secrets || true
    setup_secrets="${setup_secrets:-Y}"
    if [[ "$setup_secrets" =~ ^[Nn]$ ]]; then
        print_info "Skipping. Set them later with:"
        print_info "  gh secret set DOCKERHUB_USERNAME --repo $gh_user/$project_name"
        print_info "  gh secret set DOCKERHUB_TOKEN    --repo $gh_user/$project_name"
        return 0
    fi

    local username="${DOCKERHUB_USERNAME:-}"
    if [[ -z "$username" ]]; then
        read -p "Docker Hub username: " username
    else
        print_info "Using DOCKERHUB_USERNAME from environment"
    fi

    local token="${DOCKERHUB_TOKEN:-}"
    if [[ -z "$token" ]]; then
        read -s -p "Docker Hub access token: " token
        echo ""
    else
        print_info "Using DOCKERHUB_TOKEN from environment"
    fi

    if [[ -z "$username" ]] || [[ -z "$token" ]]; then
        print_warning "Username or token was empty — skipping Docker Hub secrets setup."
        return 0
    fi

    gh secret set DOCKERHUB_USERNAME --repo "$gh_user/$project_name" --body "$username" \
        && print_success "Set DOCKERHUB_USERNAME on $gh_user/$project_name"
    gh secret set DOCKERHUB_TOKEN --repo "$gh_user/$project_name" --body "$token" \
        && print_success "Set DOCKERHUB_TOKEN on $gh_user/$project_name"
}

# ── Skills setup ─────────────────────────────────────────────────────────────

install_skills() {
    print_info "Installing Matt Pocock skills into .claude/skills/..."

    if ! command -v npx &>/dev/null; then
        print_warning "npx not found — skipping skills install. Install Node.js then run:"
        print_warning "  npx skills@latest add mattpocock/skills"
        return 0
    fi

    npx skills@latest add mattpocock/skills --yes \
        && print_success "Matt Pocock skills installed into .claude/skills/" \
        || print_warning "Skills install failed — run 'npx skills@latest add mattpocock/skills' manually"
}

# ── Git setup ─────────────────────────────────────────────────────────────────

validate_git_url() {
    local url="$1"
    if [[ "$url" =~ ^https://github\.com/[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+\.git$ ]] || \
       [[ "$url" =~ ^git@github\.com:[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+\.git$ ]] || \
       [[ "$url" =~ ^https://gitlab\.com/[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+\.git$ ]] || \
       [[ "$url" =~ ^git@gitlab\.com:[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+\.git$ ]] || \
       [[ "$url" =~ ^https://[a-zA-Z0-9.-]+/[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+\.git$ ]]; then
        return 0
    else
        return 1
    fi
}

display_git_options() {
    echo ""
    print_info "Git repository configuration options:"
    echo ""
    print_info "1) Keep existing git history and update remote URL"
    print_info "2) Start fresh (remove git history and initialize new repository)"
    print_info "3) Keep existing git history and remote (no changes)"
    print_info "4) Skip git configuration entirely"
    echo ""
}

get_git_choice() {
    while true; do
        if read -t 10 -p "Choose an option [1-4] (default: 2 in 10s): " choice; then
            choice="${choice:-2}"
        else
            echo "" >&2
            choice="2"
        fi
        case $choice in
            [1-4]) echo "$choice"; break;;
            *) print_warning "Please enter a number between 1 and 4";;
        esac
    done
}

get_remote_url() {
    local project_name="$1"
    echo ""
    print_info "Enter the URL for your new git repository."
    print_info "Examples:"
    print_info "  https://github.com/username/$project_name.git"
    print_info "  git@github.com:username/$project_name.git"
    echo ""
    while true; do
        read -p "Remote URL: " remote_url
        if [[ -z "$remote_url" ]]; then
            print_warning "URL cannot be empty. Please enter a valid git repository URL."
            continue
        fi
        if validate_git_url "$remote_url"; then
            echo "$remote_url"
            break
        else
            print_warning "Invalid URL format. Please enter a valid git repository URL."
            print_info "Supported formats: GitHub, GitLab HTTPS/SSH URLs"
        fi
    done
}

# Issue #8: offer to create GitHub repo after fresh init
setup_github_remote() {
    local project_name="$1"

    if ! command -v gh &>/dev/null; then
        print_warning "gh CLI not found — skipping GitHub remote setup."
        print_info "Install gh from https://cli.github.com then run:"
        print_info "  gh repo create $project_name --public"
        print_info "  git remote add origin <url>"
        print_info "  git push -u origin master"
        return 0
    fi

    if ! gh auth status &>/dev/null 2>&1; then
        print_warning "gh CLI not authenticated — run 'gh auth login' then set up the remote manually."
        return 0
    fi

    echo ""
    local visibility=""
    read -t 15 -p "Create GitHub repo '$project_name'? [Y/n] " create_repo || true
    create_repo="${create_repo:-Y}"
    if [[ "$create_repo" =~ ^[Nn]$ ]]; then
        print_info "Skipping GitHub remote setup."
        print_info "To set up later: gh repo create $project_name --public && git remote add origin <url> && git push -u origin master"
        return 0
    fi

    read -t 10 -p "Visibility — public or private? [public/private] (default: private): " visibility || true
    visibility="${visibility:-private}"
    if [[ "$visibility" != "public" ]]; then
        visibility="private"
    fi

    print_info "Creating GitHub repo '$project_name' ($visibility)..."
    gh repo create "$project_name" "--${visibility}" --source=. --remote=origin --push
    print_success "GitHub repo created and pushed: https://github.com/$(gh api user --jq .login)/$project_name"
}

init_git() {
    local project_name="$1"
    local git_mode="${2:-}"  # Issue #3: optional non-interactive mode

    if ! command -v git &> /dev/null; then
        print_warning "Git not found, skipping repository initialization"
        return 0
    fi

    # No existing repo — just init fresh
    if [[ ! -d ".git" ]]; then
        print_info "No git repository found, initializing new repository"
        git init
        git add .
        git commit -m "Initial commit: $project_name project from template"
        print_success "New git repository initialized"
        setup_github_remote "$project_name"
        return 0
    fi

    # Non-interactive mode (Issue #3)
    if [[ -n "$git_mode" ]]; then
        case "$git_mode" in
            fresh)
                print_info "Git mode: fresh"
                rm -rf .git
                git init
                git add .
                git commit -m "Initial commit: $project_name project from template"
                print_success "Fresh git repository initialized"
                setup_github_remote "$project_name"
                ;;
            keep-remote)
                print_info "Git mode: keep-remote"
                git add .
                git commit -m "Configured template for project: $project_name"
                print_success "Git repository updated (remote unchanged)"
                ;;
            keep)
                print_info "Git mode: keep"
                git add .
                git commit -m "Configured template for project: $project_name"
                print_success "Git repository updated (remote unchanged)"
                ;;
            skip)
                print_info "Git mode: skip — skipping git configuration"
                ;;
            *)
                print_error "Unknown --git-mode value '$git_mode'. Use: fresh, keep-remote, keep, skip"
                exit 1
                ;;
        esac
        print_success "Git configuration completed"
        return 0
    fi

    # Interactive mode
    local current_remote=$(git remote get-url origin 2>/dev/null || echo "")
    if [[ -n "$current_remote" ]]; then
        print_info "Current git remote origin: $current_remote"
    else
        print_info "No git remote origin configured"
    fi
    display_git_options
    local choice=$(get_git_choice)
    case $choice in
        1)
            local new_remote=$(get_remote_url "$project_name")
            if [[ -n "$current_remote" ]]; then
                git remote set-url origin "$new_remote"
                print_success "Updated git remote origin to: $new_remote"
            else
                git remote add origin "$new_remote"
                print_success "Added git remote origin: $new_remote"
            fi
            git add .
            git commit -m "Configured template for project: $project_name"
            print_info "To push: git push -u origin master"
            ;;
        2)
            print_info "Removing existing git history..."
            rm -rf .git
            git init
            git add .
            git commit -m "Initial commit: $project_name project from template"
            print_success "Fresh git repository initialized"
            setup_github_remote "$project_name"
            ;;
        3)
            git add .
            git commit -m "Configured template for project: $project_name"
            print_success "Git repository updated (remote unchanged)"
            ;;
        4)
            print_info "Skipping git configuration"
            return 0
            ;;
    esac
    print_success "Git configuration completed"
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: $0 <project-name> [--type=cli|api|both] [--git-mode=fresh|keep-remote|keep|skip]"
        echo ""
        echo "Bootstraps a new Python project from the pythonproject template."
        echo "Renames the package, wires up dev rails, and configures git."
        echo ""
        echo "Options:"
        echo "  --type=cli              CLI project using Click              [default]"
        echo "  --type=api              FastAPI project"
        echo "  --type=both             CLI + FastAPI in one project"
        echo "  --git-mode=fresh        Start fresh (remove history, new repo)"
        echo "  --git-mode=keep-remote  Keep history, commit changes, keep remote"
        echo "  --git-mode=keep         Alias for keep-remote"
        echo "  --git-mode=skip         Skip all git configuration"
        echo ""
        echo "Examples:"
        echo "  $0 my-awesome-cli"
        echo "  $0 my-awesome-api --type=api"
        echo "  $0 my-awesome-app --type=both"
        echo "  $0 my-awesome-cli --git-mode=keep-remote"
        exit 1
    fi

    local project_name="$1"
    local project_type="cli"
    local git_mode=""

    # Parse flags
    for arg in "${@:2}"; do
        case "$arg" in
            --type=*)
                project_type="${arg#--type=}"
                ;;
            --git-mode=*)
                git_mode="${arg#--git-mode=}"
                ;;
            *)
                print_error "Unknown argument: $arg"
                exit 1
                ;;
        esac
    done

    case "$project_type" in
        cli|api|both) ;;
        *) print_error "Unknown --type value '$project_type'. Use: cli, api, both"; exit 1 ;;
    esac

    check_dependencies
    check_nix_config

    if ! validate_project_name "$project_name"; then
        exit 1
    fi

    if [[ ! -d "zamazingo" ]]; then
        print_error "zamazingo directory not found. Are you running this from a cloned template?"
        exit 1
    fi

    local python_name="${project_name//-/_}"

    print_info "Configuring template for project: $project_name (type: $project_type)"

    rename_package_directory "zamazingo" "$project_name"
    replace_content "zamazingo" "$project_name" "$project_type"
    patch_for_type "$python_name" "$project_name" "$project_type"
    update_readme "$project_name" "$project_type"
    setup_dev_rails
    install_skills

    init_git "$project_name" "$git_mode"
    setup_docker_secrets "$project_name"

    print_info "Removing setup script"
    rm -f "create-python-project.sh"

    # Rename the project directory if it is still called 'pythonproject'
    local current_dir
    current_dir="$(basename "$PWD")"
    if [[ "$current_dir" == "pythonproject" ]]; then
        local parent_dir
        parent_dir="$(dirname "$PWD")"
        cd "$parent_dir"
        mv "pythonproject" "$project_name"
        print_success "Renamed project directory: pythonproject → $project_name"
        cd "$project_name"
    fi

    print_success "Project '$project_name' configured successfully!"
    echo ""
    print_info "Next steps (run inside 'nix develop'):"
    print_info "  1. cd ../$project_name          # if not already there"
    print_info "  2. nix develop                  # also runs npm install --silent"
    print_info "  3. nox                          # verify baseline passes"
    print_info "  4. pre-commit install           # wire up the git hook"
    print_info "  5. /setup-dev-rails             # in Claude Code — runs /setup-matt-pocock-skills, customises CLAUDE.md"
    print_info "  6. cp .sandcastle/.env.example .sandcastle/.env  # fill in ANTHROPIC_API_KEY + GITHUB_TOKEN"
    print_info "  7. npx sandcastle docker build-image             # build sandbox image (once)"
    echo ""
    print_info "Machine-level Claude skills: https://github.com/grmhay/claudesetup"
}

main "$@"
