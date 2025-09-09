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

# Function to copy and rename files
copy_and_rename() {
    local template_dir="$1"
    local target_dir="$2"
    local old_name="$3"
    local new_name="$4"
    local python_name="${new_name//-/_}"
    
    print_info "Copying template files to $target_dir"
    
    # Copy all files except .git directory
    cp -r "$template_dir"/* "$target_dir/" 2>/dev/null || true
    cp -r "$template_dir"/.[!.]* "$target_dir/" 2>/dev/null || true
    
    # Remove .git directory if it exists
    if [[ -d "$target_dir/.git" ]]; then
        rm -rf "$target_dir/.git"
    fi
    
    # Rename the main package directory
    if [[ -d "$target_dir/$old_name" ]]; then
        mv "$target_dir/$old_name" "$target_dir/$python_name"
        print_success "Renamed directory: $old_name -> $python_name"
    fi
}

# Function to replace content in files
replace_content() {
    local target_dir="$1"
    local old_name="$2"
    local new_name="$3"
    local python_name="${new_name//-/_}"
    
    print_info "Replacing content in files"
    
    # Files to update
    local files_to_update=(
        "$target_dir/pyproject.toml"
        "$target_dir/noxfile.py"
        "$target_dir/$python_name/__init__.py"
        "$target_dir/$python_name/cli.py"
        "$target_dir/$python_name/resources/__init__.py"
        "$target_dir/tests/test_cli.py"
        "$target_dir/tests/test_utils.py"
    )
    
    for file in "${files_to_update[@]}"; do
        if [[ -f "$file" ]]; then
            # Replace package name references
            sed -i "s/$old_name/$python_name/g" "$file"
            
            # In pyproject.toml, also update the project name (which can have hyphens)
            if [[ "$file" == *"pyproject.toml" ]]; then
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
    local target_dir="$1"
    local project_name="$2"
    
    cd "$target_dir"
    
    if command -v git &> /dev/null; then
        git init
        git add .
        git commit -m "Initial commit: $project_name project from template"
        print_success "Initialized git repository"
    else
        print_warning "Git not found, skipping repository initialization"
    fi
}

# Function to update README
update_readme() {
    local target_dir="$1"
    local project_name="$2"
    
    local readme_file="$target_dir/README.md"
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
    local template_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local project_name="$1"
    local target_dir="$2"
    
    # Show usage if no arguments provided
    if [[ $# -eq 0 ]]; then
        echo "Usage: $0 <project-name> [target-directory]"
        echo ""
        echo "Creates a new Python project from the zamazingo template"
        echo ""
        echo "Arguments:"
        echo "  project-name      Name of the new project (required)"
        echo "  target-directory  Directory to create the project in (optional, defaults to ./project-name)"
        echo ""
        echo "Examples:"
        echo "  $0 my-awesome-cli"
        echo "  $0 data-processor /path/to/projects/"
        exit 1
    fi
    
    # Validate project name
    if ! validate_project_name "$project_name"; then
        exit 1
    fi
    
    # Set default target directory if not provided
    if [[ -z "$target_dir" ]]; then
        target_dir="./$project_name"
    fi
    
    # Convert target_dir to absolute path
    target_dir="$(realpath "$target_dir" 2>/dev/null || echo "$target_dir")"
    
    # Check if target directory already exists
    if [[ -d "$target_dir" ]]; then
        print_error "Target directory '$target_dir' already exists"
        exit 1
    fi
    
    print_info "Creating new Python project: $project_name"
    print_info "Template directory: $template_dir"
    print_info "Target directory: $target_dir"
    
    # Create target directory
    mkdir -p "$target_dir"
    
    # Copy and rename files
    copy_and_rename "$template_dir" "$target_dir" "zamazingo" "$project_name"
    
    # Replace content in files
    replace_content "$target_dir" "zamazingo" "$project_name"
    
    # Update README
    update_readme "$target_dir" "$project_name"
    
    # Initialize git repository
    init_git "$target_dir" "$project_name"
    
    print_success "Project '$project_name' created successfully!"
    print_info "To get started:"
    print_info "  cd $target_dir"
    print_info "  nix develop"
    print_info "  nox"
    
    # Clean up template directory
    print_info "Cleaning up template directory"
    cd /
    rm -rf "$template_dir/zamazingo"
    print_success "Removed zamazingo directory"
}

# Run main function with all arguments
main "$@"