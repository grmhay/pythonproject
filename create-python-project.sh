#!/run/current-system/sw/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to validate project name
validate_project_name() {
    local name="$1"
    
    # Check if name is empty
    if [[ -z "$name" ]]; then
        print_error "Project name cannot be empty"
        return 1
    fi
    
    # Check if name contains only valid characters (letters, numbers, underscores, hyphens)
    if [[ ! "$name" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
        print_error "Project name must start with a letter and contain only letters, numbers, underscores, and hyphens"
        return 1
    fi
    
    # Check if name is a valid Python package name (no hyphens for Python imports)
    local python_name="${name//-/_}"
    if [[ ! "$python_name" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
        print_error "Project name contains invalid characters for Python package"
        return 1
    fi
    
    return 0
}

# Function to rename the package directory
rename_package_directory() {
    local old_name="$1"
    local new_name="$2"
    local python_name="${new_name//-/_}"
    
    # Rename the main package directory
    if [[ -d "$old_name" ]]; then
        mv "$old_name" "$python_name"
        print_success "Renamed directory: $old_name -> $python_name"
    fi
}

# Function to replace content in files
replace_content() {
    local old_name="$1"
    local new_name="$2"
    local python_name="${new_name//-/_}"
    
    print_info "Replacing content in files"
    
    # Files to update
    local files_to_update=(
        "pyproject.toml"
        "noxfile.py"
        "$python_name/__init__.py"
        "$python_name/cli.py"
        "$python_name/resources/__init__.py"
        "tests/test_cli.py"
        "tests/test_utils.py"
    )
    
    for file in "${files_to_update[@]}"; do
        if [[ -f "$file" ]]; then
            # Replace package name references
            sed -i "s/$old_name/$python_name/g" "$file"
            
            # In pyproject.toml, also update the project name (which can have hyphens)
            if [[ "$file" == "pyproject.toml" ]]; then
                sed -i "s/name = \"$python_name\"/name = \"$new_name\"/" "$file"
                sed -i "s/prog_name=\"$python_name\"/prog_name=\"$new_name\"/" "$file"
            fi
            
            # In cli.py, update the prog_name to use the actual project name
            if [[ "$file" == *"cli.py" ]]; then
                sed -i "s/prog_name=\"$python_name\"/prog_name=\"$new_name\"/" "$file"
                sed -i "s/I am $python_name/I am $new_name/g" "$file"
            fi
            
            print_success "Updated: $file"
        fi
    done
}

# Function to validate git remote URL
validate_git_url() {
    local url="$1"
    
    # Basic validation for common git URL formats
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

# Function to display git configuration options
display_git_options() {
    echo ""
    print_info "Git repository configuration options:"
    echo ""
    print_info "1) Keep existing git history and update remote URL"
    print_info "   - Preserves all existing commits and history"
    print_info "   - Changes the remote origin URL to a new repository"
    print_info "   - Commits the template configuration changes"
    print_info "   - Prompts you to enter a new git remote URL"
    echo ""
    print_info "2) Start fresh (remove git history and initialize new repository)"
    print_info "   - Deletes the .git directory (removes all history)"
    print_info "   - Initializes a brand new git repository"
    print_info "   - Makes an initial commit with the configured template"
    print_info "   - No remote is configured (you'd add one manually later)"
    echo ""
    print_info "3) Keep existing git history and remote (no changes)"
    print_info "   - Preserves existing commits, history, and remote URL"
    print_info "   - Only commits the template configuration changes"
    print_info "   - No changes to git remote configuration"
    echo ""
    print_info "4) Skip git configuration entirely"
    print_info "   - Makes no git-related changes at all"
    print_info "   - Leaves the repository exactly as it was"
    print_info "   - Useful if you want to handle git setup manually later"
    echo ""
}

# Function to get user choice for git configuration
get_git_choice() {
    while true; do
        read -p "Choose an option [1-4]: " choice
        case $choice in
            [1-4]) echo "$choice"; break;;
            *) print_warning "Please enter a number between 1 and 4";;
        esac
    done
}

# Function to get new remote URL from user
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

# Function to initialize git repository with remote configuration
init_git() {
    local project_name="$1"
    
    if ! command -v git &> /dev/null; then
        print_warning "Git not found, skipping repository initialization"
        return 0
    fi
    
    # Check if we're in a git repository
    if [[ ! -d ".git" ]]; then
        print_info "No git repository found, initializing new repository"
        git init
        git add .
        git commit -m "Initial commit: $project_name project from template"
        print_success "New git repository initialized"
        return 0
    fi
    
    # We have an existing git repository, get user preference
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
            # Update remote URL
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
            
            print_info "To push to your new repository, run:"
            print_info "  git push -u origin main"
            ;;
        2)
            # Start fresh - remove git history
            print_info "Removing existing git history..."
            rm -rf .git
            
            git init
            git add .
            git commit -m "Initial commit: $project_name project from template"
            
            print_success "Fresh git repository initialized"
            print_info "To add a remote and push, run:"
            print_info "  git remote add origin <your-repo-url>"
            print_info "  git push -u origin main"
            ;;
        3)
            # Keep everything as-is
            git add .
            git commit -m "Configured template for project: $project_name"
            print_success "Git repository updated (remote unchanged)"
            ;;
        4)
            # Skip git configuration
            print_info "Skipping git configuration"
            return 0
            ;;
    esac
    
    print_success "Git configuration completed"
}

# Function to update README
update_readme() {
    local project_name="$1"
    
    local readme_file="README.md"
    if [[ -f "$readme_file" ]]; then
        # Create a new README with project-specific content
        cat > "$readme_file" << EOF
# $project_name

A Python CLI application created from the zamazingo template.

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

To run the package, use:

\`\`\`sh
nix run
\`\`\`

... and with arguments:

\`\`\`sh
nix run . -- --name=there --count=3
\`\`\`
EOF
        print_success "Updated README.md"
    fi
}

# Main function
main() {
    local project_name="$1"
    
    # Show usage if no arguments provided
    if [[ $# -eq 0 ]]; then
        echo "Usage: $0 <project-name>"
        echo ""
        echo "Configures the current zamazingo template for a new project"
        echo ""
        echo "This script should be run from a cloned zamazingo template directory."
        echo "It will rename the package directory, update all references to use"
        echo "the new project name, and configure git repository settings."
        echo ""
        echo "Git Configuration:"
        echo "  - If a git repository exists, you'll be prompted to configure the remote"
        echo "  - Options include updating the remote URL, starting fresh, or keeping as-is"
        echo "  - URL validation ensures proper git repository format"
        echo ""
        echo "Arguments:"
        echo "  project-name      Name of the new project (required)"
        echo ""
        echo "Examples:"
        echo "  $0 my-awesome-cli"
        echo "  $0 data-processor"
        exit 1
    fi
    
    # Validate project name
    if ! validate_project_name "$project_name"; then
        exit 1
    fi
    
    # Check if we're in a zamazingo template directory
    if [[ ! -d "zamazingo" ]]; then
        print_error "zamazingo directory not found. Are you running this from a cloned template?"
        exit 1
    fi
    
    print_info "Configuring template for project: $project_name"
    
    # Rename the package directory
    rename_package_directory "zamazingo" "$project_name"
    
    # Replace content in files
    replace_content "zamazingo" "$project_name"
    
    # Update README
    update_readme "$project_name"
    
    # Initialize/update git repository
    init_git "$project_name"
    
    # Remove the setup script since it's no longer needed
    print_info "Removing setup script"
    rm -f "create-python-project.sh"
    
    print_success "Project '$project_name' configured successfully!"
    print_info "To get started:"
    print_info "  nix develop"
    print_info "  nox"
}

# Run main function with all arguments
main "$@"