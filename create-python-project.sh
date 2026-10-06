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
    # Same rule as copier.yml's validator: a distribution name whose import
    # name is the hyphens-to-underscores form.
    if [[ ! "$name" =~ ^[a-z][a-z0-9-]*[a-z0-9]$ ]]; then
        print_error "Project name must be lowercase letters, digits and hyphens, starting with a letter"
        return 1
    fi
    return 0
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

    # Never create anything remote without a human answering: with no
    # terminal, a timed-out or swallowed prompt would otherwise read as "yes".
    if [[ ! -t 0 ]]; then
        print_info "No terminal — skipping Docker Hub secrets setup. Run it by hand later."
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

setup_github_remote() {
    local project_name="$1"

    if ! command -v gh &>/dev/null; then
        print_warning "gh CLI not found — skipping GitHub remote setup."
        print_info "Install gh from https://cli.github.com then run:"
        print_info "  gh repo create $project_name --public"
        print_info "  git remote add origin <url>"
        print_info "  git push -u origin main"
        return 0
    fi

    if ! gh auth status &>/dev/null 2>&1; then
        print_warning "gh CLI not authenticated — run 'gh auth login' then set up the remote manually."
        return 0
    fi

    # Never create anything remote without a human answering: with no
    # terminal, a timed-out or swallowed prompt would otherwise read as "yes".
    if [[ ! -t 0 ]]; then
        print_info "No terminal — skipping GitHub repo creation. Run it by hand later."
        return 0
    fi

    echo ""
    local visibility=""
    read -t 15 -p "Create GitHub repo '$project_name'? [Y/n] " create_repo || true
    create_repo="${create_repo:-Y}"
    if [[ "$create_repo" =~ ^[Nn]$ ]]; then
        print_info "Skipping GitHub remote setup."
        print_info "To set up later: gh repo create $project_name --public && git remote add origin <url> && git push -u origin main"
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

# ── Main ──────────────────────────────────────────────────────────────────────

usage() {
    echo "Usage: $0 <project-name> [--type=cli|api|both|library] [--template=SRC] [--vcs-ref=REF] [--defaults]"
    echo ""
    echo "Generates a new Python project from the pythonproject Copier template in"
    echo "./<project-name>, then initialises git, pins the flake and offers to create"
    echo "the GitHub repo. Later template changes are pulled with 'copier update'."
    echo ""
    echo "Options:"
    echo "  --type=cli              CLI project using Click              [default]"
    echo "  --type=api              FastAPI project"
    echo "  --type=both             CLI + FastAPI in one project"
    echo "  --type=library          Library: no entry points, no container"
    echo "  --template=SRC          Template source        [default: gh:grmhay/pythonproject]"
    echo "  --vcs-ref=REF           Template tag or branch [default: latest tag]"
    echo "  --defaults              Accept defaults for the remaining template questions"
    echo ""
    echo "Examples:"
    echo "  $0 my-awesome-cli"
    echo "  $0 my-awesome-api --type=api"
    echo "  $0 homelab-fleet-common --type=library"
}

main() {
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi

    local project_name="$1"
    local project_type="cli"
    local template="gh:grmhay/pythonproject"
    local vcs_ref=""
    local defaults=0

    for arg in "${@:2}"; do
        case "$arg" in
            --type=*)     project_type="${arg#--type=}" ;;
            --template=*) template="${arg#--template=}" ;;
            --vcs-ref=*)  vcs_ref="${arg#--vcs-ref=}" ;;
            --defaults)   defaults=1 ;;
            *)
                print_error "Unknown argument: $arg"
                exit 1
                ;;
        esac
    done

    case "$project_type" in
        cli|api|both|library) ;;
        *) print_error "Unknown --type value '$project_type'. Use: cli, api, both, library"; exit 1 ;;
    esac

    check_dependencies
    check_nix_config

    if ! validate_project_name "$project_name"; then
        exit 1
    fi

    if [[ -e "$project_name" ]]; then
        print_error "'$project_name' already exists here. Pick another name or directory."
        exit 1
    fi

    print_info "Generating $project_name (type: $project_type) from $template"
    local copier_args=(copy --trust --data "project_name=$project_name" --data "type=$project_type")
    [[ -n "$vcs_ref" ]] && copier_args+=(--vcs-ref "$vcs_ref")
    [[ "$defaults" == 1 ]] && copier_args+=(--defaults)
    nix run nixpkgs#copier -- "${copier_args[@]}" "$template" "$project_name"

    cd "$project_name"
    git init -q -b main
    git add -A

    # The template ships flake.lock without the pythonproject input; locking
    # adds it, pinning the rails checker this project is held to.
    print_info "Pinning flake inputs..."
    nix flake lock
    install_skills

    git add -A
    git commit -q -m "Initial commit: $project_name from the pythonproject template"
    print_success "Git repository initialised"

    setup_github_remote "$project_name"
    [[ "$project_type" != "library" ]] && setup_docker_secrets "$project_name"

    print_success "Project '$project_name' generated."
    echo ""
    print_info "Next steps:"
    print_info "  1. cd $project_name"
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
