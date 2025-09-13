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

# Function to initialize git repository
init_git() {
    local project_name="$1"
    
    if command -v git &> /dev/null; then
        if [[ -d ".git" ]]; then
            print_info "Git repository already exists, adding changes"
            git add .
            git commit -m "Renamed template to $project_name"
        else
            git init
            git add .
            git commit -m "Initial commit: $project_name project from template"
        fi
        print_success "Git repository updated"
    else
        print_warning "Git not found, skipping repository initialization"
    fi
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
        echo "It will rename the package directory and update all references to use"
        echo "the new project name."
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