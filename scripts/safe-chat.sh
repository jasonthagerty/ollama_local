#!/bin/bash

# Safe Chat Script for Ollama (Intel Arc A770 / SYCL)
# Provides a safe interactive chat interface with error handling and logging

set -e

# Configuration — source .env for container name if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$SCRIPT_DIR/../.env" ] && source "$SCRIPT_DIR/../.env"
CONTAINER_NAME="${CONTAINER_NAME:-ollama-arc-sycl}"
OLLAMA_HOST="http://localhost:11434"
LOG_FILE="logs/chat-$(date +%Y%m%d).log"
DEFAULT_MODEL="qwen3.5:9b"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Print functions
print_header() {
    echo -e "${BOLD}${BLUE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

# Logging function
log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" >> "$LOG_FILE"
}

# Check if container is running
check_container() {
    if docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        return 0
    else
        return 1
    fi
}

# Check API connectivity
check_api() {
    if curl -s -f "$OLLAMA_HOST/api/tags" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Get available models
get_models() {
    if check_api; then
        curl -s "$OLLAMA_HOST/api/tags" 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    models = data.get('models', [])
    for model in models:
        name = model.get('name', 'unknown')
        size = model.get('size', 0)
        size_gb = round(size / (1024**3), 1)
        modified = model.get('modified_at', '')[:10]
        print(f'{name} ({size_gb}GB, {modified})')
except Exception as e:
    print('Error parsing models')
" 2>/dev/null || echo "Error getting models"
    else
        echo "API not available"
    fi
}

# Validate model exists
validate_model() {
    local model="$1"
    if check_api; then
        curl -s "$OLLAMA_HOST/api/tags" | CHECK_MODEL="$model" python3 -c "
import json, sys, os
model_name = os.environ['CHECK_MODEL']
try:
    data = json.load(sys.stdin)
    models = data.get('models', [])
    model_names = [m.get('name', '') for m in models]
    if model_name in model_names:
        sys.exit(0)
    else:
        sys.exit(1)
except:
    sys.exit(1)
" 2>/dev/null
        return $?
    else
        return 1
    fi
}

# Safe prompt function with validation
safe_prompt() {
    local model="$1"
    local prompt="$2"
    local max_retries=3
    local retry=0

    while [ $retry -lt $max_retries ]; do
        local payload
        payload=$(printf '{"model":"%s","prompt":%s,"stream":false}' \
            "$model" "$(printf '%s' "$prompt" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')")
        if curl -s -X POST "$OLLAMA_HOST/api/generate" \
           -H "Content-Type: application/json" \
           -d "$payload" \
           2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if 'response' in data:
        print(data['response'])
        sys.exit(0)
    elif 'error' in data:
        print(f'Error: {data[\"error\"]}')
        sys.exit(1)
    else:
        print('Unexpected response format')
        sys.exit(1)
except Exception as e:
    print(f'Error: {e}')
    sys.exit(1)
"; then
            log_message "SUCCESS: Model=$model, Prompt=${prompt:0:50}..."
            return 0
        else
            retry=$((retry + 1))
            print_warning "Attempt $retry failed, retrying in 2 seconds..."
            sleep 2
        fi
    done

    print_error "Failed after $max_retries attempts"
    log_message "FAILED: Model=$model, Prompt=${prompt:0:50}..."
    return 1
}

# Interactive chat session
start_chat() {
    local model="$1"

    print_header "Starting Safe Chat Session"
    print_info "Model: $model"
    print_info "Type 'quit', 'exit', or 'bye' to end session"
    print_info "Type 'help' for available commands"
    print_info "Type 'models' to list available models"
    echo

    log_message "CHAT_START: Model=$model"

    while true; do
        echo -n -e "${CYAN}You:${NC} "
        read -r user_input

        # Handle empty input
        if [[ -z "$user_input" ]]; then
            continue
        fi

        # Handle special commands
        case "$user_input" in
            quit|exit|bye)
                print_success "Chat session ended"
                log_message "CHAT_END: User quit"
                break
                ;;
            help)
                echo "Available commands:"
                echo "  help     - Show this help"
                echo "  models   - List available models"
                echo "  switch   - Switch to different model"
                echo "  status   - Show system status"
                echo "  clear    - Clear screen"
                echo "  quit/exit/bye - End session"
                continue
                ;;
            models)
                print_info "Available models:"
                get_models | while read -r line; do
                    echo "  $line"
                done
                continue
                ;;
            switch)
                echo -n "Enter new model name: "
                read -r new_model
                if validate_model "$new_model"; then
                    model="$new_model"
                    print_success "Switched to model: $model"
                    log_message "MODEL_SWITCH: $model"
                else
                    print_error "Model '$new_model' not found"
                fi
                continue
                ;;
            status)
                if check_container && check_api; then
                    print_success "System status: All services running"
                else
                    print_error "System status: Services not responding"
                fi
                continue
                ;;
            clear)
                clear
                print_header "Safe Chat Session (Model: $model)"
                continue
                ;;
        esac

        # Process regular chat input
        echo -n -e "${GREEN}$model:${NC} "

        if safe_prompt "$model" "$user_input"; then
            echo
        else
            print_error "Failed to get response. Please try again."
            echo
        fi
    done
}

# Pre-flight checks
preflight_checks() {
    print_header "Running Pre-flight Checks"

    # Check if container is running
    if check_container; then
        print_success "Container is running"
    else
        print_error "Container '$CONTAINER_NAME' is not running"
        print_info "Start with: ./manage.sh start"
        return 1
    fi

    # Check API connectivity
    if check_api; then
        print_success "API is responding"
    else
        print_error "Ollama API is not responding"
        print_info "Check container logs: docker logs $CONTAINER_NAME"
        return 1
    fi

    # Check for available models
    local model_count=$(curl -s "$OLLAMA_HOST/api/tags" 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(len(data.get('models', [])))
except:
    print(0)
" 2>/dev/null || echo "0")

    if [ "$model_count" -gt 0 ]; then
        print_success "Found $model_count available models"
    else
        print_warning "No models found"
        print_info "Download a model with: ./manage.sh pull $DEFAULT_MODEL"
        return 1
    fi

    return 0
}

# Show help
show_help() {
    echo "Safe Chat Script for Ollama (Intel Arc A770 / SYCL)"
    echo
    echo "Usage: $0 [OPTIONS] [MODEL]"
    echo
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -l, --list          List available models"
    echo "  -c, --check         Run pre-flight checks only"
    echo "  -m, --model MODEL   Specify model to use"
    echo "  -v, --verbose       Enable verbose logging"
    echo
    echo "Examples:"
    echo "  $0                          # Start chat with default model"
    echo "  $0 llama2:7b               # Start chat with specific model"
    echo "  $0 --list                  # List available models"
    echo "  $0 --check                 # Check system status"
    echo "  $0 -m qwen2.5:0.5b         # Start with specified model"
    echo
    echo "During chat session:"
    echo "  Type 'help' for chat commands"
    echo "  Type 'quit' to exit"
    echo "  Type 'models' to list models"
    echo "  Type 'switch' to change model"
}

# Main function
main() {
    local model="$DEFAULT_MODEL"
    local action="chat"
    local verbose=false

    # Create log directory
    mkdir -p "$(dirname "$LOG_FILE")"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -l|--list)
                action="list"
                shift
                ;;
            -c|--check)
                action="check"
                shift
                ;;
            -m|--model)
                model="$2"
                shift 2
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                model="$1"
                shift
                ;;
        esac
    done

    # Enable verbose logging if requested
    if [ "$verbose" = true ]; then
        set -x
    fi

    case $action in
        list)
            print_header "Available Models"
            get_models | while read -r line; do
                echo "  $line"
            done
            ;;
        check)
            preflight_checks
            ;;
        chat)
            # Run pre-flight checks
            if ! preflight_checks; then
                exit 1
            fi
            echo

            # Validate specified model
            if ! validate_model "$model"; then
                print_warning "Model '$model' not found"
                print_info "Available models:"
                get_models | while read -r line; do
                    echo "  $line"
                done
                echo
                echo -n "Enter model name to use: "
                read -r model
                if ! validate_model "$model"; then
                    print_error "Model '$model' not found"
                    exit 1
                fi
            fi

            # Start chat session
            start_chat "$model"
            ;;
    esac
}

# Run main function with all arguments
main "$@"
