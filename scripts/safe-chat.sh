#!/bin/bash

# Safe Chat Script for Ollama with Intel Arc A770
# This script ensures memory-safe API calls to prevent OOM kills

set -e

# Configuration
OLLAMA_HOST="http://localhost:11434"
MODEL="deepseek-r1:8b"
MAX_CONTEXT=2048
BATCH_SIZE=128
TEMPERATURE=0.7
TOP_P=0.9

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[CHAT]${NC} $1"
}

# Function to check if Ollama is running
check_ollama() {
    if ! curl -s "$OLLAMA_HOST/api/version" >/dev/null 2>&1; then
        print_error "Ollama server is not running at $OLLAMA_HOST"
        print_status "Please start the container: docker-compose up -d"
        exit 1
    fi
}

# Function to check model status
check_model() {
    local models=$(curl -s "$OLLAMA_HOST/api/tags" | jq -r '.models[]?.name' 2>/dev/null || echo "")
    if [[ ! "$models" =~ "$MODEL" ]]; then
        print_error "Model $MODEL not found"
        print_status "Available models:"
        curl -s "$OLLAMA_HOST/api/tags" | jq -r '.models[]?.name' 2>/dev/null || echo "None"
        exit 1
    fi
}

# Function to monitor memory usage
monitor_memory() {
    local container_name="ollama-arc-optimized"
    if docker ps --format "table {{.Names}}" | grep -q "$container_name"; then
        local memory_usage=$(docker stats --no-stream --format "table {{.MemUsage}}" "$container_name" | tail -n 1)
        echo -e "${BLUE}[MEMORY]${NC} Container usage: $memory_usage"
    fi
}

# Function to make safe API call
safe_chat() {
    local prompt="$1"
    local stream="${2:-false}"

    if [[ -z "$prompt" ]]; then
        print_error "No prompt provided"
        return 1
    fi

    print_status "Sending prompt with safe parameters..."
    print_status "Context: $MAX_CONTEXT tokens, Batch: $BATCH_SIZE, Temp: $TEMPERATURE"

    local json_payload=$(jq -n \
        --arg model "$MODEL" \
        --arg prompt "$prompt" \
        --argjson stream "$stream" \
        --argjson num_ctx "$MAX_CONTEXT" \
        --argjson num_batch "$BATCH_SIZE" \
        --argjson temperature "$TEMPERATURE" \
        --argjson top_p "$TOP_P" \
        --argjson num_gpu 999 \
        --argjson repeat_penalty 1.1 \
        '{
            model: $model,
            prompt: $prompt,
            stream: $stream,
            options: {
                num_ctx: $num_ctx,
                num_batch: $num_batch,
                temperature: $temperature,
                top_p: $top_p,
                num_gpu: $num_gpu,
                repeat_penalty: $repeat_penalty
            }
        }')

    local response=$(curl -s -X POST "$OLLAMA_HOST/api/generate" \
        -H "Content-Type: application/json" \
        -d "$json_payload")

    if [[ $? -eq 0 ]] && echo "$response" | jq -e '.response' >/dev/null 2>&1; then
        print_header "Response:"
        echo "$response" | jq -r '.response'
        echo
        print_status "Tokens - Total: $(echo "$response" | jq -r '.eval_count // "N/A"'), Context: $(echo "$response" | jq -r '.prompt_eval_count // "N/A"')"
        print_status "Duration: $(echo "$response" | jq -r '.total_duration // 0' | awk '{printf "%.2f", $1/1000000000}')s"
    else
        print_error "API call failed or returned error"
        echo "$response" | jq -r '.error // .' 2>/dev/null || echo "$response"
        return 1
    fi
}

# Function for interactive chat
interactive_chat() {
    print_header "Starting interactive chat with $MODEL"
    print_warning "Memory-optimized mode: $MAX_CONTEXT token context limit"
    print_status "Type 'quit', 'exit', or press Ctrl+C to stop"
    echo

    while true; do
        echo -n -e "${GREEN}You:${NC} "
        read -r user_input

        if [[ "$user_input" =~ ^(quit|exit)$ ]]; then
            print_status "Goodbye!"
            break
        fi

        if [[ -z "$user_input" ]]; then
            continue
        fi

        echo
        monitor_memory
        safe_chat "$user_input"
        echo
    done
}

# Function to show help
show_help() {
    echo "Safe Chat Script for Ollama (Intel Arc A770 optimized)"
    echo
    echo "Usage:"
    echo "  $0 [OPTIONS] [PROMPT]"
    echo
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -i, --interactive   Start interactive chat mode"
    echo "  -m, --model MODEL   Use specific model (default: $MODEL)"
    echo "  -c, --context SIZE  Set context size (default: $MAX_CONTEXT, max: 4096)"
    echo "  -t, --temp TEMP     Set temperature (default: $TEMPERATURE)"
    echo "  -s, --stream        Enable streaming response"
    echo "  --status           Show server and model status"
    echo "  --monitor          Show memory usage"
    echo
    echo "Examples:"
    echo "  $0 \"Hello, how are you?\""
    echo "  $0 -i"
    echo "  $0 --status"
    echo "  $0 -c 1024 -t 0.5 \"Write a poem\""
}

# Function to show status
show_status() {
    print_header "Ollama Server Status"

    # Check server
    if curl -s "$OLLAMA_HOST/api/version" >/dev/null 2>&1; then
        local version=$(curl -s "$OLLAMA_HOST/api/version" | jq -r '.version')
        print_status "Server: Running (version $version)"
    else
        print_error "Server: Not running"
        return 1
    fi

    # Check models
    print_status "Available models:"
    curl -s "$OLLAMA_HOST/api/tags" | jq -r '.models[] | "  • \(.name) (\(.parameter_size // "unknown") params, \((.size/1024/1024/1024 | floor))GB)"' 2>/dev/null || echo "  None"

    # Check running models
    print_status "Currently loaded models:"
    local running=$(curl -s "$OLLAMA_HOST/api/ps" | jq -r '.models[]?.name' 2>/dev/null)
    if [[ -n "$running" ]]; then
        echo "$running" | while read -r model; do
            local info=$(curl -s "$OLLAMA_HOST/api/ps" | jq -r ".models[] | select(.name == \"$model\") | \"  • \(.name) (VRAM: \((.size_vram/1024/1024/1024 | floor))GB, Context: \(.context_length))\"")
            echo "$info"
        done
    else
        echo "  None"
    fi

    # Show memory usage
    monitor_memory
}

# Parse command line arguments
INTERACTIVE=false
STREAM=false
PROMPT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -i|--interactive)
            INTERACTIVE=true
            shift
            ;;
        -m|--model)
            MODEL="$2"
            shift 2
            ;;
        -c|--context)
            MAX_CONTEXT="$2"
            if [[ $MAX_CONTEXT -gt 4096 ]]; then
                print_warning "Context size $MAX_CONTEXT is too high for Arc A770, limiting to 4096"
                MAX_CONTEXT=4096
            fi
            shift 2
            ;;
        -t|--temp)
            TEMPERATURE="$2"
            shift 2
            ;;
        -s|--stream)
            STREAM=true
            shift
            ;;
        --status)
            show_status
            exit 0
            ;;
        --monitor)
            monitor_memory
            exit 0
            ;;
        -*)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            PROMPT="$1"
            shift
            ;;
    esac
done

# Main execution
print_header "Safe Ollama Chat (Arc A770 Optimized)"

# Check prerequisites
check_ollama
check_model

if [[ "$INTERACTIVE" == "true" ]]; then
    interactive_chat
elif [[ -n "$PROMPT" ]]; then
    safe_chat "$PROMPT" "$STREAM"
else
    show_help
fi
