#!/bin/bash

# Ollama Intel Arc A770 Monitoring Script
# Monitors container memory, GPU usage, and model status

set -e

# Configuration
CONTAINER_NAME="ollama-arc-optimized"
OLLAMA_HOST="http://localhost:11434"
REFRESH_INTERVAL=5
LOG_FILE="logs/monitor.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Function to print colored output
print_header() {
    echo -e "${BOLD}${BLUE}$1${NC}"
}

print_status() {
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

# Function to get timestamp
timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Function to log with timestamp
log_message() {
    echo "$(timestamp) - $1" >> "$LOG_FILE"
}

# Function to check if container is running
check_container() {
    if docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        return 0
    else
        return 1
    fi
}

# Function to get container stats
get_container_stats() {
    if check_container; then
        docker stats --no-stream --format "table {{.MemUsage}}\t{{.CPUPerc}}\t{{.MemPerc}}" "$CONTAINER_NAME" | tail -n 1
    else
        echo "Container not running"
    fi
}

# Function to get container memory in bytes for calculations
get_container_memory_bytes() {
    if check_container; then
        docker stats --no-stream --format "{{.MemUsage}}" "$CONTAINER_NAME" | sed 's/[^0-9.]*\([0-9.]*\).*/\1/'
    else
        echo "0"
    fi
}

# Function to check Ollama API status
check_ollama_api() {
    if curl -s "$OLLAMA_HOST/api/version" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to get loaded models
get_loaded_models() {
    if check_ollama_api; then
        curl -s "$OLLAMA_HOST/api/ps" 2>/dev/null | jq -r '.models[]? | "\(.name) (\((.size_vram/1024/1024/1024*10|floor)/10)GB VRAM, \(.context_length) ctx)"' 2>/dev/null || echo "None"
    else
        echo "API not available"
    fi
}

# Function to get GPU utilization (if available)
get_gpu_usage() {
    if check_container; then
        # Try to get Intel GPU stats from inside container
        docker exec "$CONTAINER_NAME" timeout 3s intel_gpu_top -l 2>/dev/null | grep -E "Render/3D|VideoCodec|Blitter" | head -3 2>/dev/null || echo "GPU stats unavailable"
    else
        echo "Container not running"
    fi
}

# Function to check for memory warnings
check_memory_warnings() {
    local memory_usage=$(get_container_memory_bytes)
    local memory_gb=$(echo "$memory_usage" | awk '{printf "%.1f", $1}')

    if (( $(echo "$memory_gb > 18.0" | bc -l) )); then
        print_error "HIGH MEMORY USAGE: ${memory_gb}GB - Risk of OOM kill!"
        log_message "HIGH MEMORY WARNING: ${memory_gb}GB"
        return 1
    elif (( $(echo "$memory_gb > 15.0" | bc -l) )); then
        print_warning "Elevated memory usage: ${memory_gb}GB"
        log_message "ELEVATED MEMORY: ${memory_gb}GB"
        return 2
    else
        return 0
    fi
}

# Function to get recent logs for errors
check_recent_errors() {
    if check_container; then
        local errors=$(docker logs --tail 50 "$CONTAINER_NAME" 2>&1 | grep -i "error\|killed\|failed\|timeout" | tail -3)
        if [[ -n "$errors" ]]; then
            print_warning "Recent errors detected:"
            echo "$errors" | while read -r line; do
                echo "  $line"
            done
        fi
    fi
}

# Function to display system info
show_system_info() {
    print_header "=== System Information ==="

    # Host system memory
    local total_mem=$(free -h | awk '/^Mem:/ {print $2}')
    local used_mem=$(free -h | awk '/^Mem:/ {print $3}')
    local avail_mem=$(free -h | awk '/^Mem:/ {print $7}')
    print_info "Host Memory: $used_mem / $total_mem used ($avail_mem available)"

    # GPU info
    if lspci | grep -i "vga\|display" | grep -i intel >/dev/null 2>&1; then
        local gpu_info=$(lspci | grep -i "vga\|display" | grep -i intel | head -1 | cut -d: -f3)
        print_info "GPU:$gpu_info"
    fi

    echo
}

# Function to display container status
show_container_status() {
    print_header "=== Container Status ==="

    if check_container; then
        print_status "Container: Running"
        local stats=$(get_container_stats)
        print_info "Memory/CPU/Mem%: $stats"

        # Check for memory warnings
        check_memory_warnings

        # Container uptime
        local uptime=$(docker ps --format "{{.Status}}" --filter "name=$CONTAINER_NAME")
        print_info "Uptime: $uptime"
    else
        print_error "Container: Not running"
        print_info "Start with: docker-compose up -d"
        return 1
    fi

    echo
}

# Function to display Ollama status
show_ollama_status() {
    print_header "=== Ollama Service Status ==="

    if check_ollama_api; then
        local version=$(curl -s "$OLLAMA_HOST/api/version" | jq -r '.version' 2>/dev/null || echo "unknown")
        print_status "API: Responding (v$version)"

        # Show loaded models
        local models=$(get_loaded_models)
        if [[ "$models" != "None" ]]; then
            print_info "Loaded models:"
            echo "$models" | while read -r model; do
                echo "  • $model"
            done
        else
            print_info "No models currently loaded"
        fi
    else
        print_error "API: Not responding"
        print_info "Check container logs: docker logs $CONTAINER_NAME"
    fi

    echo
}

# Function to display GPU status
show_gpu_status() {
    print_header "=== GPU Status ==="

    if check_container; then
        print_info "Attempting to get GPU utilization..."
        local gpu_stats=$(get_gpu_usage)
        if [[ "$gpu_stats" != "GPU stats unavailable" ]]; then
            echo "$gpu_stats"
        else
            print_warning "GPU monitoring tools not available in container"
            print_info "This is normal if intel_gpu_top is not installed"
        fi
    else
        print_error "Cannot check GPU - container not running"
    fi

    echo
}

# Function for continuous monitoring
monitor_continuous() {
    print_header "Starting continuous monitoring (refresh every ${REFRESH_INTERVAL}s)"
    print_info "Press Ctrl+C to stop"
    echo

    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"

    while true; do
        clear
        echo "=== Ollama Intel Arc A770 Monitor - $(timestamp) ==="
        echo

        show_container_status
        show_ollama_status

        # Check for recent errors
        check_recent_errors

        # Log current status
        if check_container; then
            local memory_usage=$(get_container_memory_bytes)
            log_message "Memory: ${memory_usage}GB, Models: $(get_loaded_models | wc -l)"
        fi

        print_info "Next refresh in ${REFRESH_INTERVAL}s..."
        sleep "$REFRESH_INTERVAL"
    done
}

# Function to show help
show_help() {
    echo "Ollama Intel Arc A770 Monitoring Script"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -c, --continuous    Start continuous monitoring (default)"
    echo "  -o, --once          Run once and exit"
    echo "  -s, --status        Show detailed status"
    echo "  -m, --memory        Show memory usage only"
    echo "  -l, --logs          Show recent container logs"
    echo "  -e, --errors        Check for recent errors"
    echo "  -i, --interval SEC  Set refresh interval (default: ${REFRESH_INTERVAL}s)"
    echo
    echo "Examples:"
    echo "  $0                  # Start continuous monitoring"
    echo "  $0 -o               # Show status once"
    echo "  $0 -i 10            # Monitor with 10s refresh"
    echo "  $0 --memory         # Show memory usage only"
}

# Function for one-time status check
show_once() {
    show_system_info
    show_container_status
    show_ollama_status
    show_gpu_status
    check_recent_errors
}

# Function to show memory usage only
show_memory_only() {
    if check_container; then
        local stats=$(get_container_stats)
        echo "Container Memory Usage: $stats"
        check_memory_warnings

        if check_ollama_api; then
            local models=$(get_loaded_models)
            echo "Loaded Models: $models"
        fi
    else
        echo "Container not running"
    fi
}

# Function to show recent logs
show_logs() {
    if check_container; then
        print_header "Recent Container Logs (last 20 lines):"
        docker logs --tail 20 "$CONTAINER_NAME"
    else
        print_error "Container not running"
    fi
}

# Parse command line arguments
MODE="continuous"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--continuous)
            MODE="continuous"
            shift
            ;;
        -o|--once)
            MODE="once"
            shift
            ;;
        -s|--status)
            MODE="status"
            shift
            ;;
        -m|--memory)
            MODE="memory"
            shift
            ;;
        -l|--logs)
            MODE="logs"
            shift
            ;;
        -e|--errors)
            MODE="errors"
            shift
            ;;
        -i|--interval)
            REFRESH_INTERVAL="$2"
            shift 2
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
case $MODE in
    continuous)
        monitor_continuous
        ;;
    once|status)
        show_once
        ;;
    memory)
        show_memory_only
        ;;
    logs)
        show_logs
        ;;
    errors)
        check_recent_errors
        ;;
    *)
        show_help
        ;;
esac
