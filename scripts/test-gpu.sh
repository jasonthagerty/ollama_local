#!/bin/bash

# GPU Test Script for Ollama Intel Arc A770
# Tests different GPU layer configurations to find optimal settings

set -e

# Configuration
OLLAMA_HOST="http://localhost:11434"
MODEL="deepseek-r1:8b"
TEST_PROMPT="Hello! Please respond with exactly 10 words."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

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

# Function to check if Ollama is running
check_ollama() {
    if ! curl -s "$OLLAMA_HOST/api/version" >/dev/null 2>&1; then
        print_error "Ollama server is not running at $OLLAMA_HOST"
        exit 1
    fi
}

# Function to unload all models
unload_models() {
    print_info "Unloading all models..."
    local models=$(curl -s "$OLLAMA_HOST/api/ps" | jq -r '.models[]?.name' 2>/dev/null || echo "")
    if [[ -n "$models" ]]; then
        echo "$models" | while read -r model; do
            if [[ -n "$model" ]]; then
                curl -s -X DELETE "$OLLAMA_HOST/api/generate" \
                    -H "Content-Type: application/json" \
                    -d "{\"model\": \"$model\", \"keep_alive\": 0}" >/dev/null
            fi
        done
        sleep 3
    fi
}

# Function to test GPU layers
test_gpu_layers() {
    local layers=$1
    local context_size=$2
    local batch_size=$3

    print_header "Testing with $layers GPU layers, context $context_size, batch $batch_size"

    # Unload models first
    unload_models

    # Test the configuration
    local start_time=$(date +%s.%N)

    local response=$(curl -s -X POST "$OLLAMA_HOST/api/generate" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$MODEL\",
            \"prompt\": \"$TEST_PROMPT\",
            \"stream\": false,
            \"options\": {
                \"num_ctx\": $context_size,
                \"num_batch\": $batch_size,
                \"num_gpu\": $layers,
                \"temperature\": 0.1,
                \"top_p\": 0.9
            }
        }")

    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l)

    if echo "$response" | jq -e '.response' >/dev/null 2>&1; then
        local tokens=$(echo "$response" | jq -r '.eval_count // 0')
        local prompt_tokens=$(echo "$response" | jq -r '.prompt_eval_count // 0')
        local total_duration=$(echo "$response" | jq -r '.total_duration // 0')
        local eval_duration=$(echo "$response" | jq -r '.eval_duration // 0')

        # Calculate tokens per second
        local tokens_per_sec="0"
        if [[ "$eval_duration" != "0" && "$eval_duration" != "null" ]]; then
            tokens_per_sec=$(echo "scale=2; $tokens * 1000000000 / $eval_duration" | bc -l)
        fi

        print_success "SUCCESS - Duration: ${duration}s"
        print_info "  Generated tokens: $tokens"
        print_info "  Prompt tokens: $prompt_tokens"
        print_info "  Tokens/sec: $tokens_per_sec"

        # Check if running on GPU by looking at speed
        if (( $(echo "$tokens_per_sec > 10" | bc -l) )); then
            print_success "  Likely running on GPU (good speed)"
        else
            print_warning "  Likely running on CPU (slow speed)"
        fi

        # Check memory usage
        check_memory_usage

        return 0
    else
        print_error "FAILED - Error response"
        echo "$response" | jq -r '.error // .' 2>/dev/null || echo "$response"
        return 1
    fi
}

# Function to check memory usage
check_memory_usage() {
    local container_stats=$(docker stats --no-stream --format "{{.MemUsage}}" ollama-arc-optimized 2>/dev/null || echo "N/A")
    print_info "  Container memory: $container_stats"

    # Get GPU memory from loaded models
    local gpu_usage=$(curl -s "$OLLAMA_HOST/api/ps" | jq -r '.models[]? | "  GPU VRAM: \((.size_vram/1024/1024/1024*10|floor)/10)GB"' 2>/dev/null || echo "  GPU VRAM: N/A")
    if [[ "$gpu_usage" != "  GPU VRAM: N/A" ]]; then
        echo "$gpu_usage"
    fi
}

# Function to check for errors in logs
check_logs_for_errors() {
    print_info "Checking recent logs for GPU-related messages..."
    local recent_logs=$(docker logs --tail 20 ollama-arc-optimized 2>&1)

    # Look for GPU/CPU indicators
    if echo "$recent_logs" | grep -q "layers.offload=0"; then
        print_error "Found: layers.offload=0 (CPU-only execution)"
    elif echo "$recent_logs" | grep -q "layers.offload=[1-9]"; then
        local offloaded=$(echo "$recent_logs" | grep "layers.offload=" | tail -1 | sed 's/.*layers.offload=\([0-9]*\).*/\1/')
        print_success "Found: layers.offload=$offloaded (GPU execution)"
    fi

    if echo "$recent_logs" | grep -q "CPU.*buffer"; then
        print_warning "Found CPU buffer allocation (may indicate CPU execution)"
    fi

    if echo "$recent_logs" | grep -q "killed\|error\|failed"; then
        print_error "Found error/killed messages in logs"
    fi
}

# Function to show current system status
show_status() {
    print_header "Current System Status"

    # Container status
    if docker ps --format "{{.Names}}" | grep -q "ollama-arc-optimized"; then
        print_success "Container: Running"
    else
        print_error "Container: Not running"
        return 1
    fi

    # API status
    if check_ollama; then
        print_success "Ollama API: Responding"
    else
        print_error "Ollama API: Not responding"
        return 1
    fi

    # Currently loaded models
    local loaded=$(curl -s "$OLLAMA_HOST/api/ps" | jq -r '.models[]?.name' 2>/dev/null)
    if [[ -n "$loaded" ]]; then
        print_info "Loaded models: $loaded"
        check_memory_usage
    else
        print_info "No models currently loaded"
    fi

    echo
}

# Function to run comprehensive tests
run_tests() {
    print_header "GPU Layer Optimization Tests for Intel Arc A770"
    echo

    show_status
    check_logs_for_errors
    echo

    # Test configurations from most conservative to most aggressive
    local configs=(
        "8 1024 64"     # Very conservative
        "16 1024 128"   # Conservative
        "24 2048 128"   # Moderate
        "28 2048 256"   # Aggressive
        "32 4096 256"   # Very aggressive
        "999 2048 128"  # Auto (let Ollama decide)
    )

    print_header "Testing different GPU layer configurations..."
    echo

    local best_config=""
    local best_speed=0

    for config in "${configs[@]}"; do
        read -r layers context batch <<< "$config"

        echo "----------------------------------------"
        if test_gpu_layers "$layers" "$context" "$batch"; then
            # Extract speed from last test
            local speed=$(curl -s "$OLLAMA_HOST/api/ps" | jq -r '.models[]? | .name' 2>/dev/null)
            if [[ -n "$speed" ]]; then
                # Simple heuristic: if model loads successfully, it's good
                best_config="$config"
                print_info "Configuration saved as viable option"
            fi
        fi
        echo
        sleep 2
    done

    echo "========================================"
    if [[ -n "$best_config" ]]; then
        read -r best_layers best_context best_batch <<< "$best_config"
        print_success "RECOMMENDED CONFIGURATION:"
        print_info "  GPU Layers: $best_layers"
        print_info "  Context Size: $best_context"
        print_info "  Batch Size: $best_batch"
        echo
        print_info "To apply this configuration, update your docker-compose.yml:"
        echo "  OLLAMA_GPU_LAYERS=$best_layers"
        echo "  OLLAMA_CONTEXT_LENGTH=$best_context"
    else
        print_error "No viable GPU configuration found"
        print_warning "The model may be too large for your GPU VRAM"
        print_info "Consider using a smaller model or Q3_K_M quantization"
    fi
}

# Function to show help
show_help() {
    echo "GPU Test Script for Ollama Intel Arc A770"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -t, --test          Run comprehensive GPU layer tests (default)"
    echo "  -s, --status        Show current system status only"
    echo "  -c, --custom LAYERS CONTEXT BATCH"
    echo "                      Test specific configuration"
    echo "  -l, --logs          Check logs for GPU/CPU indicators"
    echo "  -q, --quick         Run quick test with current settings"
    echo
    echo "Examples:"
    echo "  $0                  # Run full test suite"
    echo "  $0 -s               # Show status only"
    echo "  $0 -c 24 2048 128   # Test specific config"
    echo "  $0 -q               # Quick test"
}

# Function for quick test
quick_test() {
    print_header "Quick GPU Test"
    show_status

    print_info "Testing current configuration..."
    test_gpu_layers "999" "2048" "128"

    check_logs_for_errors
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -s|--status)
        show_status
        exit 0
        ;;
    -c|--custom)
        if [[ $# -lt 4 ]]; then
            print_error "Custom test requires 3 parameters: layers context batch"
            exit 1
        fi
        check_ollama
        test_gpu_layers "$2" "$3" "$4"
        exit 0
        ;;
    -l|--logs)
        check_logs_for_errors
        exit 0
        ;;
    -q|--quick)
        check_ollama
        quick_test
        exit 0
        ;;
    -t|--test|"")
        check_ollama
        run_tests
        exit 0
        ;;
    *)
        print_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac
