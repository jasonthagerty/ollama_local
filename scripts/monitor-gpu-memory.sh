#!/bin/bash

# GPU Memory Monitor for Intel Arc GPUs with Ollama
# This script monitors GPU memory usage and Ollama process health

set -euo pipefail

# Configuration
CONTAINER_NAME="ollama-arc-optimized"
LOG_FILE="./logs/gpu-memory-monitor.log"
CHECK_INTERVAL=30
MEMORY_THRESHOLD=90
VRAM_THRESHOLD=85

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ensure logs directory exists
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_colored() {
    local color=$1
    shift
    echo -e "${color}$(date '+%Y-%m-%d %H:%M:%S') - $*${NC}" | tee -a "$LOG_FILE"
}

check_container_running() {
    if ! docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        log_colored "$RED" "ERROR: Container $CONTAINER_NAME is not running"
        return 1
    fi
    return 0
}

get_container_memory() {
    docker stats --no-stream --format "table {{.MemUsage}}" "$CONTAINER_NAME" | tail -n +2 | awk '{
        split($1, mem, "/");
        used = 0; total = 0;
        # Convert to MB for easier comparison
        if (match(mem[1], /([0-9.]+)([GMK])/)) {
            used = substr(mem[1], RSTART, RLENGTH-1);
            unit = substr(mem[1], RSTART+RLENGTH-1, 1);
            if (unit == "G") used *= 1024;
            else if (unit == "K") used /= 1024;
        }
        if (match(mem[2], /([0-9.]+)([GMK])/)) {
            total = substr(mem[2], RSTART, RLENGTH-1);
            unit = substr(mem[2], RSTART+RLENGTH-1, 1);
            if (unit == "G") total *= 1024;
            else if (unit == "K") total /= 1024;
        }
        if (total > 0) {
            printf "%.0f %.0f %.1f", used, total, (used/total)*100;
        } else {
            printf "0 0 0.0";
        }
    }'
}

get_gpu_info() {
    # Try to get GPU information from inside the container
    docker exec "$CONTAINER_NAME" bash -c '
        if command -v intel_gpu_top >/dev/null 2>&1; then
            timeout 3s intel_gpu_top -l 2>/dev/null | head -10 || echo "GPU monitoring not available"
        elif [ -d /dev/dri ]; then
            echo "GPU devices available:"
            ls -la /dev/dri/
        else
            echo "No GPU devices found"
        fi
    ' 2>/dev/null || echo "Cannot access GPU info"
}

check_ollama_health() {
    local api_response
    api_response=$(curl -s --max-time 5 "http://localhost:11434/api/tags" 2>/dev/null || echo "")

    if [[ -n "$api_response" ]] && echo "$api_response" | grep -q "models"; then
        return 0
    else
        return 1
    fi
}

get_loaded_models() {
    curl -s --max-time 5 "http://localhost:11434/api/ps" 2>/dev/null | \
    python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    models = data.get('models', [])
    if models:
        for model in models:
            name = model.get('name', 'unknown')
            size = model.get('size_vram', model.get('size', 0))
            size_gb = size / (1024**3) if size > 0 else 0
            print(f'  - {name}: {size_gb:.1f}GB VRAM')
    else:
        print('  - No models currently loaded')
except:
    print('  - Unable to parse model info')
" || echo "  - API not responding"
}

check_vram_warnings() {
    # Check recent logs for VRAM warnings
    local recent_warnings
    recent_warnings=$(docker logs --since=5m "$CONTAINER_NAME" 2>&1 | grep -i "vram.*timeout\|gpu.*recover" | wc -l)
    echo "$recent_warnings"
}

monitor_loop() {
    log_colored "$BLUE" "Starting GPU memory monitoring (PID: $$)"
    log "Container: $CONTAINER_NAME"
    log "Check interval: ${CHECK_INTERVAL}s"
    log "Memory threshold: ${MEMORY_THRESHOLD}%"
    log "VRAM threshold: ${VRAM_THRESHOLD}%"
    echo ""

    local iteration=0

    while true; do
        iteration=$((iteration + 1))

        # Check if container is running
        if ! check_container_running; then
            sleep "$CHECK_INTERVAL"
            continue
        fi

        # Get memory stats
        local memory_stats
        memory_stats=$(get_container_memory)
        read -r mem_used_mb mem_total_mb mem_percent <<< "$memory_stats"

        # Check Ollama API health
        local api_status="❌"
        if check_ollama_health; then
            api_status="✅"
        fi

        # Check for recent VRAM warnings
        local vram_warnings
        vram_warnings=$(check_vram_warnings)

        # Determine status color based on thresholds
        local status_color="$GREEN"
        local status="HEALTHY"

        if [[ -n "$mem_percent" ]] && (( $(echo "$mem_percent > $MEMORY_THRESHOLD" | bc -l 2>/dev/null || echo 0) )); then
            status_color="$RED"
            status="HIGH_MEMORY"
        elif [[ -n "$mem_percent" ]] && (($(echo "$mem_percent > $VRAM_THRESHOLD" | bc -l 2>/dev/null || echo 0))) || [[ "$vram_warnings" -gt 0 ]]; then
            status_color="$YELLOW"
            status="WARNING"
        fi

        # Log status every 10 iterations or if there's an issue
        if [[ $((iteration % 10)) -eq 1 ]] || [[ "$status" != "HEALTHY" ]]; then
            log_colored "$status_color" "[$status] Memory: ${mem_used_mb}MB/${mem_total_mb}MB (${mem_percent}%) | API: $api_status | VRAM Warnings: $vram_warnings"

            if [[ $((iteration % 10)) -eq 1 ]]; then
                log "Loaded models:"
                get_loaded_models | while read -r line; do
                    log "$line"
                done
                echo ""
            fi
        fi

        # Take action if memory is too high
        if [[ "$status" == "HIGH_MEMORY" ]]; then
            log_colored "$RED" "HIGH MEMORY USAGE DETECTED - Consider unloading models"

            # Optionally auto-restart if memory is critically high
            if [[ -n "$mem_percent" ]] && (( $(echo "$mem_percent > 95" | bc -l 2>/dev/null || echo 0) )); then
                log_colored "$RED" "CRITICAL MEMORY USAGE - Recommending container restart"
            fi
        fi

        # Alert on VRAM warnings
        if [[ "$vram_warnings" -gt 2 ]]; then
            log_colored "$YELLOW" "Multiple VRAM timeout warnings detected ($vram_warnings in last 5 minutes)"
        fi

        sleep "$CHECK_INTERVAL"
    done
}

show_help() {
    cat << EOF
GPU Memory Monitor for Ollama Intel Arc Setup

Usage: $0 [OPTIONS]

Options:
    -h, --help              Show this help message
    -i, --interval SECONDS  Set check interval (default: $CHECK_INTERVAL)
    -m, --memory-threshold  Memory usage threshold % (default: $MEMORY_THRESHOLD)
    -v, --vram-threshold    VRAM threshold % (default: $VRAM_THRESHOLD)
    -l, --log-file FILE     Log file path (default: $LOG_FILE)
    -c, --container NAME    Container name (default: $CONTAINER_NAME)
    --once                  Run once and exit
    --status                Show current status and exit

Examples:
    $0                      Start monitoring with default settings
    $0 --interval 60        Check every 60 seconds
    $0 --once               Check once and show status
    $0 --status             Show current system status

The monitor will:
  - Track container memory usage
  - Monitor Ollama API health
  - Watch for GPU VRAM timeout warnings
  - Log activities to $LOG_FILE
  - Alert when thresholds are exceeded

EOF
}

show_current_status() {
    echo -e "${BLUE}=== Current Ollama GPU Status ===${NC}"

    # Container status
    if check_container_running; then
        echo -e "${GREEN}✅ Container: Running${NC}"

        # Memory stats
        local memory_stats
        memory_stats=$(get_container_memory)
        read -r mem_used_mb mem_total_mb mem_percent <<< "$memory_stats"
        echo "📊 Memory: ${mem_used_mb}MB / ${mem_total_mb}MB (${mem_percent}%)"

        # API health
        if check_ollama_health; then
            echo -e "${GREEN}✅ API: Responding${NC}"
        else
            echo -e "${RED}❌ API: Not responding${NC}"
        fi

        # Loaded models
        echo "🤖 Loaded models:"
        get_loaded_models

        # Recent warnings
        local vram_warnings
        vram_warnings=$(check_vram_warnings)
        if [[ "$vram_warnings" -gt 0 ]]; then
            echo -e "${YELLOW}⚠️  VRAM warnings in last 5 minutes: $vram_warnings${NC}"
        else
            echo -e "${GREEN}✅ No recent VRAM warnings${NC}"
        fi

    else
        echo -e "${RED}❌ Container: Not running${NC}"
    fi

    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -i|--interval)
            CHECK_INTERVAL="$2"
            shift 2
            ;;
        -m|--memory-threshold)
            MEMORY_THRESHOLD="$2"
            shift 2
            ;;
        -v|--vram-threshold)
            VRAM_THRESHOLD="$2"
            shift 2
            ;;
        -l|--log-file)
            LOG_FILE="$2"
            shift 2
            ;;
        -c|--container)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        --once)
            show_current_status
            exit 0
            ;;
        --status)
            show_current_status
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate dependencies
if ! command -v docker >/dev/null 2>&1; then
    echo "Error: docker command not found"
    exit 1
fi

if ! command -v bc >/dev/null 2>&1; then
    echo "Warning: bc not found, some calculations may not work"
fi

# Start monitoring
monitor_loop
