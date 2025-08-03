#!/bin/bash

# Context Export/Import Script for Ollama Management
# This script helps preserve project context between sessions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Default context directory
CONTEXT_DIR="${CONTEXT_DIR:-./context}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Function to print colored output
print_status() {
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

print_header() {
    echo -e "${CYAN}$1${NC}"
    echo "=================================================================="
}

# Show usage
usage() {
    print_header "📋 Context Export/Import Tool"
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  export [name]        Export current project context"
    echo "  import <file>        Import project context"
    echo "  list                 List available contexts"
    echo "  show <file>          Show context file content"
    echo "  clean                Clean old context files"
    echo ""
    echo "Examples:"
    echo "  $0 export my-session     # Export with custom name"
    echo "  $0 export               # Export with timestamp"
    echo "  $0 import context.json   # Import specific context"
    echo "  $0 list                 # Show available contexts"
}

# Export current context
export_context() {
    local context_name=${1:-"context_$TIMESTAMP"}
    local context_file="$CONTEXT_DIR/${context_name}.json"

    print_header "📤 Exporting Project Context"

    # Create context directory
    mkdir -p "$CONTEXT_DIR"

    print_status "Gathering project information..."

    # Create context JSON
    cat > "$context_file" << EOF
{
  "export_info": {
    "timestamp": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "user": "$(whoami)",
    "context_name": "$context_name",
    "project_path": "$SCRIPT_DIR"
  },
  "project_structure": {
    "files": $(find . -type f -name "*.sh" -o -name "*.yml" -o -name "*.yaml" -o -name "*.json" -o -name "*.md" -o -name "*.txt" -o -name ".env*" -o -name "Dockerfile*" | grep -v "./context/" | sort | jq -R . | jq -s .),
    "directories": $(find . -type d -not -path "./context*" -not -path "./.git*" -not -path "./data*" | sort | jq -R . | jq -s .)
  },
  "docker_info": {
    "compose_status": "$(docker compose ps --format json 2>/dev/null || echo '[]')",
    "images": "$(docker images --format json | grep -E "(ollama|webui)" || echo '{}')",
    "volumes": "$(docker volume ls --format json | grep -E "(ollama|webui)" || echo '{}')"
  },
  "environment": {
    "env_files": $(find . -name ".env*" -type f | xargs -I {} sh -c 'echo "{}:"; cat "{}" | grep -v "^#" | grep -v "^$"' 2>/dev/null | jq -R . | jq -s . || echo '[]'),
    "docker_compose_content": "$(cat docker-compose.yml 2>/dev/null | base64 -w 0 || echo '')",
    "dockerfile_content": "$(cat Dockerfile 2>/dev/null | base64 -w 0 || echo '')"
  },
  "ollama_state": {
    "running": $(docker compose ps ollama --format json 2>/dev/null | jq 'length > 0' || echo 'false'),
    "models": "$(docker exec $(docker compose ps -q ollama 2>/dev/null) ollama list 2>/dev/null || echo 'Container not running')",
    "gpu_status": "$(docker exec $(docker compose ps -q ollama 2>/dev/null) gpu-health 2>/dev/null || echo 'GPU check failed')"
  },
  "system_info": {
    "gpu_devices": "$(ls -la /dev/dri/ 2>/dev/null || echo 'No GPU devices')",
    "pci_gpu": "$(lspci | grep -i 'vga\\|3d\\|display' || echo 'No GPU found')",
    "docker_version": "$(docker --version 2>/dev/null || echo 'Docker not found')",
    "compose_version": "$(docker compose version 2>/dev/null || echo 'Compose not found')"
  },
  "recent_logs": {
    "manage_script_usage": "Last 10 commands would be tracked here",
    "container_logs": "$(docker compose logs --tail=50 2>/dev/null | tail -20 | base64 -w 0 || echo '')"
  }
}
EOF

    # Pretty format the JSON
    if command -v jq >/dev/null 2>&1; then
        jq . "$context_file" > "${context_file}.tmp" && mv "${context_file}.tmp" "$context_file"
    fi

    print_success "Context exported to: $context_file"

    # Show summary
    echo ""
    print_status "Context Summary:"
    echo "  • Export time: $(date)"
    echo "  • Project files: $(find . -type f -name "*.sh" -o -name "*.yml" -o -name "*.yaml" | wc -l)"
    echo "  • Docker status: $(docker compose ps --format table 2>/dev/null | wc -l) services"
    echo "  • File size: $(du -h "$context_file" | cut -f1)"
}

# Import context
import_context() {
    local context_file=$1

    if [[ -z "$context_file" ]]; then
        print_error "Please specify a context file to import"
        return 1
    fi

    if [[ ! -f "$context_file" ]]; then
        # Try looking in context directory
        if [[ -f "$CONTEXT_DIR/$context_file" ]]; then
            context_file="$CONTEXT_DIR/$context_file"
        else
            print_error "Context file not found: $context_file"
            return 1
        fi
    fi

    print_header "📥 Importing Project Context"
    print_status "Loading context from: $context_file"

    # Validate JSON
    if ! jq . "$context_file" >/dev/null 2>&1; then
        print_error "Invalid JSON format in context file"
        return 1
    fi

    # Show context info
    print_status "Context Information:"
    jq -r '.export_info | "  • Exported: \(.timestamp)\n  • From: \(.hostname)\n  • User: \(.user)\n  • Project: \(.context_name)"' "$context_file"

    echo ""
    print_status "Project Structure:"
    jq -r '.project_structure.files[] | "  • \(.)"' "$context_file" | head -10
    if [[ $(jq -r '.project_structure.files | length' "$context_file") -gt 10 ]]; then
        echo "  • ... and $(( $(jq -r '.project_structure.files | length' "$context_file") - 10 )) more files"
    fi

    echo ""
    print_status "Docker State:"
    jq -r '.docker_info.compose_status' "$context_file" | head -5

    echo ""
    print_status "Ollama State:"
    echo "  • Running: $(jq -r '.ollama_state.running' "$context_file")"
    echo "  • Models: $(jq -r '.ollama_state.models' "$context_file" | head -1)"

    echo ""
    print_warning "Context imported for reference. To restore files, use the show command and manually apply changes."
}

# List available contexts
list_contexts() {
    print_header "📋 Available Context Files"

    if [[ ! -d "$CONTEXT_DIR" ]]; then
        print_warning "No context directory found. Use 'export' to create contexts."
        return 0
    fi

    local contexts=($(find "$CONTEXT_DIR" -name "*.json" -type f | sort -r))

    if [[ ${#contexts[@]} -eq 0 ]]; then
        print_warning "No context files found in $CONTEXT_DIR"
        return 0
    fi

    echo "Context files (newest first):"
    for context in "${contexts[@]}"; do
        local basename=$(basename "$context")
        local size=$(du -h "$context" | cut -f1)
        local date=$(jq -r '.export_info.timestamp // "Unknown"' "$context" 2>/dev/null)
        local name=$(jq -r '.export_info.context_name // "Unknown"' "$context" 2>/dev/null)

        echo "  • $basename ($size) - $name - $date"
    done
}

# Show context file content
show_context() {
    local context_file=$1

    if [[ -z "$context_file" ]]; then
        print_error "Please specify a context file to show"
        return 1
    fi

    if [[ ! -f "$context_file" ]]; then
        if [[ -f "$CONTEXT_DIR/$context_file" ]]; then
            context_file="$CONTEXT_DIR/$context_file"
        else
            print_error "Context file not found: $context_file"
            return 1
        fi
    fi

    print_header "📄 Context File Content"

    if command -v jq >/dev/null 2>&1; then
        jq . "$context_file"
    else
        cat "$context_file"
    fi
}

# Clean old context files
clean_contexts() {
    print_header "🧹 Cleaning Old Context Files"

    if [[ ! -d "$CONTEXT_DIR" ]]; then
        print_warning "No context directory found"
        return 0
    fi

    local retention_days=${CONTEXT_RETENTION_DAYS:-30}

    print_status "Cleaning contexts older than $retention_days days..."

    local old_files=$(find "$CONTEXT_DIR" -name "*.json" -mtime +$retention_days)

    if [[ -z "$old_files" ]]; then
        print_success "No old context files to clean"
        return 0
    fi

    echo "Files to be deleted:"
    echo "$old_files"

    read -p "Delete these files? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "$old_files" | xargs rm -f
        print_success "Old context files cleaned"
    else
        print_status "Cleaning cancelled"
    fi
}

# Main command dispatcher
main() {
    case "${1:-}" in
        export)
            export_context "$2"
            ;;
        import)
            import_context "$2"
            ;;
        list)
            list_contexts
            ;;
        show)
            show_context "$2"
            ;;
        clean)
            clean_contexts
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            if [[ -n "${1:-}" ]]; then
                print_error "Unknown command: $1"
                echo ""
            fi
            usage
            exit 1
            ;;
    esac
}

# Check dependencies
if ! command -v jq >/dev/null 2>&1; then
    print_warning "jq is not installed. JSON formatting will be limited."
    print_status "Install with: sudo apt-get install jq"
fi

# Run main function
main "$@"
