#!/bin/bash

# Ollama Management Script for Intel Arc GPU
# Ubuntu 24.04 with IPEX-LLM Integration

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

# Load environment variables
if [ -f .env ]; then
    source .env
fi

# Default values
CONTAINER_NAME=${CONTAINER_NAME:-ollama-arc-optimized}
WEBUI_CONTAINER=${WEBUI_CONTAINER_NAME:-ollama-webui-enhanced}
IMAGE_NAME="ollama-ubuntu:24.04"

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

# Check if Docker is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi

    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not available"
        exit 1
    fi
}

# Check if container is running
is_running() {
    docker compose ps -q "$1" | grep -q . && docker compose ps "$1" | grep -q "Up"
}

# Show usage information
usage() {
    print_header "🚀 Ollama Management Script - Intel Arc GPU + IPEX-LLM"
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  start                Start all services"
    echo "  stop                 Stop all services"
    echo "  restart              Restart all services"
    echo "  build                Build/rebuild containers (Ubuntu 24.04 + IPEX)"
    echo "  logs [service]       Show logs (all or specific service)"
    echo "  status               Show service status"
    echo "  shell                Open shell in Ollama container"
    echo "  quick-start          Full setup: build, start, test GPU, pull model"
    echo ""
    echo "🎮 Arc GPU Commands:"
    echo "  gpu                  Show Arc GPU information and diagnostics"
    echo "  gpu-monitor          Start real-time GPU monitoring"
    echo "  gpu-test             Test Intel IPEX-LLM and Arc GPU setup"
    echo "  memory-monitor       Monitor GPU memory and VRAM usage"
    echo ""
    echo "Model Management:"
    echo "  models               List installed models"
    echo "  pull <model>         Download a model"
    echo "  remove <model>       Remove a model"
    echo "  run <model>          Run a model interactively"
    echo "  chat <model>         Start chat with a model"
    echo ""
    echo "Maintenance:"
    echo "  update               Update containers"
    echo "  backup               Backup data"
    echo "  restore <file>       Restore from backup"
    echo "  cleanup              Clean up unused resources"
    echo "  cleanup-models       Clean up model files"
    echo "  cleanup-logs         Clean up log files"
    echo "  reset                Reset all data (destructive!)"
    echo ""
    echo "Context Management:"
    echo "  export-context [name] Export current session context"
    echo "  import-context <file> Import session context"
    echo "  list-contexts        List available contexts"
    echo ""
    echo "Monitoring:"
    echo "  monitor              Monitor GPU and container stats"
    echo "  memory-monitor       Advanced GPU memory monitoring"
    echo "  test                 Test API connectivity"
    echo "  health               Check service health"
    echo ""
    echo "Examples:"
    echo "  $0 quick-start                 # Complete setup and test"
    echo "  $0 gpu-test                    # Test Arc GPU and IPEX-LLM setup"
    echo "  $0 pull qwen2.5:0.5b           # Pull a small model for testing"
    echo "  $0 chat qwen2.5:0.5b           # Chat with model on Arc GPU"
    echo "  $0 gpu-monitor                 # Monitor GPU during inference"
    echo "  $0 memory-monitor              # Track memory usage and VRAM"
    echo "  $0 logs ollama                 # View Ollama logs"
    echo "  $0 export-context my-session   # Export conversation context"
    echo "  $0 backup                      # Backup models and data"
    echo ""
    echo "🎯 Arc GPU Quick Start:"
    echo "  $0 quick-start                 # Recommended first command"
    echo "  $0 start && $0 gpu-test        # Alternative manual setup"
}

# Start services
start_services() {
    print_header "🚀 Starting Ollama Services"

    # Create data directories matching volume mounts
    mkdir -p data/models data/config data/webui

    print_status "Starting services..."
    docker compose up -d

    print_status "Waiting for services to be ready..."
    sleep 10

    if is_running "ollama-arc-optimized"; then
        print_success "Ollama server is running"
    else
        print_error "Ollama server failed to start"
        return 1
    fi

    if is_running "ollama-webui-enhanced"; then
        print_success "Web UI is running"
    else
        print_warning "Web UI is not running"
    fi

    print_success "Services started successfully!"
    echo "  • Ollama API: http://localhost:${OLLAMA_PORT:-11434}"
    echo "  • Web UI: http://localhost:${WEBUI_PORT:-3000}"
}

# Stop services
stop_services() {
    print_header "🛑 Stopping Ollama Services"
    docker compose down
    print_success "Services stopped"
}

# Build services
build_services() {
    print_header "🔨 Building Ollama with Intel Arc GPU Support"
    print_status "Building Ubuntu 24.04 image with IPEX-LLM integration..."
    print_status "This may take several minutes..."
    docker compose build --no-cache
    print_success "Build completed successfully!"
    echo "  • Image: $IMAGE_NAME"
    echo "  • Base: Ubuntu 24.04"
    echo "  • Intel GPU: Enabled with IPEX libraries"
    echo "  • Arc GPU devices: /dev/dri/card1, /dev/dri/renderD129"
    echo "  • ML Environment: /opt/ml-env with PyTorch + IPEX"
}

# Restart services
restart_services() {
    print_header "🔄 Restarting Ollama Services"
    docker compose restart
    print_success "Services restarted"
}

# Build containers (already defined above, removing duplicate)

# Show logs
show_logs() {
    local service=${1:-}
    if [ -n "$service" ]; then
        print_header "📋 Logs for $service"
        docker compose logs -f "$service"
    else
        print_header "📋 All Service Logs"
        docker compose logs -f
    fi
}

# Show status
show_status() {
    print_header "📊 Service Status"
    docker compose ps

    echo ""
    print_status "Container Resource Usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" $CONTAINER_NAME $WEBUI_CONTAINER 2>/dev/null || true
}

# Quick start - complete setup and test
quick_start() {
    print_header "🚀 Quick Start - Complete Ollama Arc GPU Setup"

    print_status "Step 1/5: Building containers..."
    docker compose build --no-cache

    print_status "Step 2/5: Starting services..."
    start_services

    print_status "Step 3/5: Testing GPU setup..."
    sleep 5
    if is_running "ollama-arc-optimized"; then
        print_status "Running GPU diagnostics..."
        docker exec $CONTAINER_NAME /llm/bin/gpu-diagnostics-comprehensive | head -20
        echo ""
        print_status "Verifying IPEX_LLM_NUM_CTX: $(docker exec $CONTAINER_NAME printenv IPEX_LLM_NUM_CTX)"
    fi

    print_status "Step 4/5: Pulling test model..."
    if ! docker exec $CONTAINER_NAME ollama list | grep -q "qwen2.5:0.5b"; then
        docker exec $CONTAINER_NAME ollama pull qwen2.5:0.5b
    else
        print_success "qwen2.5:0.5b already available"
    fi

    print_status "Step 5/5: Testing model inference..."
    time docker exec $CONTAINER_NAME curl -s -X POST http://localhost:11434/api/generate \
        -d '{"model":"qwen2.5:0.5b","prompt":"Hello! Test GPU acceleration.","stream":false}' | \
        jq -r '.response' | head -2

    echo ""
    print_success "🎉 Quick start completed!"
    echo ""
    print_status "Next steps:"
    echo "  • Web UI: http://localhost:3000"
    echo "  • API: http://localhost:11434"
    echo "  • Test chat: $0 chat qwen2.5:0.5b"
    echo "  • GPU monitoring: $0 gpu-monitor"
    echo "  • Memory monitoring: $0 memory-monitor"
    echo "  • Full GPU test: $0 gpu-test"
}

# Build containers
build_containers() {
    print_header "🔨 Building Ollama Containers"
    print_status "Building containers with latest optimizations..."
    docker compose build --no-cache
    print_success "Containers built successfully"
}

# Update containers
update_containers() {
    print_header "🔄 Updating Ollama Containers"
    print_status "Pulling latest base images..."
    docker compose pull
    print_status "Rebuilding containers..."
    docker compose build --no-cache
    print_success "Containers updated successfully"
}

# Open shell in container
open_shell() {
    print_header "🐚 Opening Shell in Ollama Container"
    if is_running "ollama-arc-optimized"; then
        docker exec -it $CONTAINER_NAME /bin/bash
    else
        print_error "Ollama container is not running"
    fi
}

# Show GPU information
show_gpu_info() {
    print_header "🎮 GPU Information & Intel Arc A770 Status"

    print_status "Host GPU Devices:"
    ls -la /dev/dri/ 2>/dev/null || print_warning "No GPU devices found"

    echo ""
    print_status "PCI GPU Information:"
    lspci | grep -i "vga\|3d\|display" | grep -i intel || print_warning "No Intel GPU found in lspci"

    echo ""
    print_status "Intel Arc A770 Detection:"
    if lspci | grep -qi "56a0"; then
        print_success "✅ Intel Arc A770 detected (Device ID: 56a0)"
        lspci | grep "56a0" | sed 's/^/    /'
    else
        print_warning "Arc A770 specific device ID (56a0) not found"
    fi

    echo ""
    print_status "Container GPU Status:"
    if is_running "ollama-arc-optimized"; then
        print_status "Running Intel Arc GPU diagnostics..."
        if docker exec $CONTAINER_NAME /llm/bin/gpu-diagnostics-comprehensive 2>/dev/null; then
            print_success "Arc GPU diagnostics completed"
        else
            print_warning "GPU diagnostics failed - check container GPU access"
        fi

        echo ""
        print_status "Checking Arc GPU devices:"
        docker exec $CONTAINER_NAME ls -la /dev/dri/ 2>/dev/null || print_warning "Could not access GPU devices"

        echo ""
        print_status "Ollama GPU Detection:"
        if docker exec $CONTAINER_NAME pgrep ollama >/dev/null 2>&1; then
            print_status "Checking Ollama's GPU enumeration..."
            docker exec $CONTAINER_NAME timeout 5s ollama ps 2>/dev/null | head -3 || print_warning "Could not get Ollama GPU status"
        else
            print_warning "Ollama not running - GPU enumeration unavailable"
        fi
    else
        print_error "Ollama container is not running"
    fi

    echo ""
    print_status "Available GPU Monitoring Tools:"
    print_status "Available Arc GPU Tools and Commands:"
    if is_running "ollama-arc-optimized"; then
        echo "  🔍 gpu-diagnostics - Comprehensive Arc GPU diagnostics"
        echo "  🧪 gpu-test        - Test Intel IPEX-LLM and PyTorch integration"
        echo "  🎯 intel_gpu_top   - Real-time GPU monitoring (if available)"
        echo "  📊 vainfo          - Video acceleration info"
        echo ""
        echo "💡 Quick Commands:"
        echo "  $0 gpu                              # Show GPU information"
        echo "  $0 gpu-test                         # Test IPEX-LLM setup"
        echo "  $0 shell                            # Enter container for manual monitoring"
        echo "  docker exec $CONTAINER_NAME /llm/bin/gpu-diagnostics    # Full diagnostics"
        echo ""
        print_status "Intel Arc A770 Monitoring Tips:"
        echo "  • Use 'gpu-monitor' for real-time utilization during inference"
        echo "  • Monitor during model loading to see peak memory usage (15.1GB available)"
        echo "  • Arc A770 typically shows 95%+ Render/3D usage during AI inference"
        echo "  • Expected performance: ~1.5-3.0 tokens/second depending on model size"
    else
        print_warning "Container not running - start services to access GPU tools"
    fi
}

# List models
list_models() {
    print_header "📚 Installed Models"
    if is_running "ollama-arc-optimized"; then
        docker exec $CONTAINER_NAME ollama list
    else
        print_error "Ollama container is not running"
    fi
}

# Pull model
pull_model() {
    local model=$1
    if [ -z "$model" ]; then
        print_error "Please specify a model name"
        echo "Popular models: deepseek-r1:14b, deepseek-r1:8b, llama2, mistral, codellama, phi, tinyllama"
        return 1
    fi

    print_header "⬇️  Pulling Model: $model"
    if is_running "ollama-arc-optimized"; then
        docker exec -it $CONTAINER_NAME ollama pull "$model"
        print_success "Model $model pulled successfully"
    else
        print_error "Ollama container is not running"
    fi
}

# Remove model
remove_model() {
    local model=$1
    if [ -z "$model" ]; then
        print_error "Please specify a model name"
        return 1
    fi

    print_header "🗑️  Removing Model: $model"
    if is_running "ollama-arc-optimized"; then
        docker exec -it $CONTAINER_NAME ollama rm "$model"
        print_success "Model $model removed"
    else
        print_error "Ollama container is not running"
    fi
}

# Run model interactively
run_model() {
    local model=$1
    if [ -z "$model" ]; then
        print_error "Please specify a model name"
        return 1
    fi

    print_header "🤖 Running Model: $model"
    if is_running "ollama-arc-optimized"; then
        print_status "Starting interactive session with $model"
        print_status "Type 'exit' or press Ctrl+D to quit"
        docker exec -it $CONTAINER_NAME ollama run "$model"
    else
        print_error "Ollama container is not running"
    fi
}

# Chat with model
chat_model() {
    local model=$1
    if [ -z "$model" ]; then
        print_error "Please specify a model name"
        return 1
    fi

    print_header "💬 Chat with Model: $model"
    if is_running "ollama-arc-optimized"; then
        print_status "Starting chat with $model"
        print_status "Type your message and press Enter. Type 'quit' to exit."
        docker exec -it $CONTAINER_NAME ollama run "$model"
    else
        print_error "Ollama container is not running"
    fi
}

# Update containers
update_containers() {
    print_header "⬆️  Updating Containers"
    docker compose pull
    docker compose up -d
    print_success "Containers updated"
}

# Backup data
backup_data() {
    print_header "💾 Creating Backup"

    local backup_dir="${BACKUP_PATH:-./backups}"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$backup_dir/ollama_backup_$timestamp.tar.gz"

    mkdir -p "$backup_dir"

    print_status "Creating backup: $backup_file"

    # Create backup of volumes
    docker run --rm \
        -v ollama-local_ollama-data:/source/ollama:ro \
        -v ollama-local_open-webui-data:/source/webui:ro \
        -v "$backup_dir:/backup" \
        alpine tar czf "/backup/ollama_backup_$timestamp.tar.gz" -C /source .

    print_success "Backup created: $backup_file"

    # Clean old backups
    if [ -n "${BACKUP_RETENTION_DAYS}" ]; then
        print_status "Cleaning backups older than ${BACKUP_RETENTION_DAYS} days"
        find "$backup_dir" -name "ollama_backup_*.tar.gz" -mtime +${BACKUP_RETENTION_DAYS} -delete
    fi
}

# Restore from backup
restore_data() {
    local backup_file=$1
    if [ -z "$backup_file" ] || [ ! -f "$backup_file" ]; then
        print_error "Please specify a valid backup file"
        return 1
    fi

    print_header "📥 Restoring from Backup"
    print_warning "This will overwrite existing data!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Restore cancelled"
        return 0
    fi

    print_status "Stopping services..."
    docker compose down

    print_status "Restoring data from $backup_file"
    docker run --rm \
        -v ollama-local_ollama-data:/target/ollama \
        -v ollama-local_open-webui-data:/target/webui \
        -v "$(dirname "$backup_file"):/backup" \
        alpine tar xzf "/backup/$(basename "$backup_file")" -C /target

    print_status "Starting services..."
    docker compose up -d

    print_success "Data restored successfully"
}

# Cleanup unused resources
cleanup() {
    print_header "🧹 Cleaning Up"

    echo "Select cleanup options:"
    echo "1) Basic cleanup (unused containers, networks, images)"
    echo "2) Deep cleanup (+ build cache, stopped containers)"
    echo "3) Full cleanup (+ volumes, everything)"
    echo "4) Model cleanup (remove unused models)"
    echo "5) Log cleanup (clear container logs)"
    echo "6) All of the above"
    echo "0) Cancel"

    read -p "Choose option (0-6): " choice

    case $choice in
        0)
            print_status "Cleanup cancelled"
            return 0
            ;;
        1|2|3|6)
            print_status "Removing unused Docker containers..."
            docker container prune -f

            print_status "Removing unused Docker networks..."
            docker network prune -f

            print_status "Removing unused Docker images..."
            docker image prune -f

            if [[ $choice == "2" || $choice == "3" || $choice == "6" ]]; then
                print_status "Removing build cache..."
                docker builder prune -f

                print_status "Removing all stopped containers..."
                docker container prune -f
            fi

            if [[ $choice == "3" || $choice == "6" ]]; then
                print_warning "This will remove unused volumes (may include data!)"
                read -p "Continue? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    print_status "Removing unused volumes..."
                    docker volume prune -f
                fi
            fi
            ;;
    esac

    if [[ $choice == "4" || $choice == "6" ]]; then
        if is_running "ollama-arc-optimized"; then
            print_status "Checking for unused models..."
            # List models and let user select which to remove
            echo "Current models:"
            docker exec $CONTAINER_NAME ollama list
            echo ""
            read -p "Enter model name to remove (or 'skip' to skip): " model_name
            if [[ $model_name != "skip" && -n $model_name ]]; then
                docker exec $CONTAINER_NAME ollama rm "$model_name" || print_warning "Could not remove model $model_name"
            fi
        else
            print_warning "Ollama container not running, skipping model cleanup"
        fi
    fi

    if [[ $choice == "5" || $choice == "6" ]]; then
        print_status "Clearing container logs..."
        # Clear logs for our containers
        if docker ps -q --filter "name=$CONTAINER_NAME" | grep -q .; then
            docker logs $CONTAINER_NAME 2>/dev/null | wc -l | xargs -I {} echo "Ollama logs: {} lines"
            sudo truncate -s 0 $(docker inspect --format='{{.LogPath}}' $CONTAINER_NAME) 2>/dev/null || print_warning "Could not clear Ollama logs"
        fi

        if docker ps -q --filter "name=$WEBUI_CONTAINER" | grep -q .; then
            docker logs $WEBUI_CONTAINER 2>/dev/null | wc -l | xargs -I {} echo "WebUI logs: {} lines"
            sudo truncate -s 0 $(docker inspect --format='{{.LogPath}}' $WEBUI_CONTAINER) 2>/dev/null || print_warning "Could not clear WebUI logs"
        fi
    fi

    # Show disk space saved
    print_status "Cleanup summary:"
    df -h | grep -E "(Filesystem|/var/lib/docker|/$)" || df -h /

    print_success "Cleanup completed"
}

# Clean up old model files and temporary data
cleanup_models() {
    print_header "🧹 Model Cleanup"

    if ! is_running "ollama-arc-optimized"; then
        print_error "Ollama container is not running"
        return 1
    fi

    print_status "Analyzing model storage..."
    docker exec $CONTAINER_NAME du -sh /root/.ollama/models/* 2>/dev/null || print_warning "No models found"

    echo ""
    echo "Model cleanup options:"
    echo "1) Remove specific model"
    echo "2) Remove all models"
    echo "3) Show model details"
    echo "0) Cancel"

    read -p "Choose option (0-3): " choice

    case $choice in
        1)
            echo "Available models:"
            docker exec $CONTAINER_NAME ollama list
            read -p "Enter model name to remove: " model_name
            if [[ -n $model_name ]]; then
                remove_model "$model_name"
            fi
            ;;
        2)
            print_warning "This will remove ALL models!"
            read -p "Are you sure? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                print_status "Removing all models..."
                docker exec $CONTAINER_NAME find /root/.ollama/models -type f -delete 2>/dev/null || true
                print_success "All models removed"
            fi
            ;;
        3)
            docker exec $CONTAINER_NAME ollama list
            echo ""
            docker exec $CONTAINER_NAME du -sh /root/.ollama/models/* 2>/dev/null || echo "No model files found"
            ;;
        0)
            print_status "Model cleanup cancelled"
            ;;
    esac
}

# Clean up logs and temporary files
cleanup_logs() {
    print_header "🧹 Log Cleanup"

    print_status "Current log sizes:"
    if docker ps -q --filter "name=$CONTAINER_NAME" | grep -q .; then
        log_size=$(docker logs $CONTAINER_NAME 2>&1 | wc -c)
        echo "Ollama container: $(($log_size / 1024))KB"
    fi

    if docker ps -q --filter "name=$WEBUI_CONTAINER" | grep -q .; then
        log_size=$(docker logs $WEBUI_CONTAINER 2>&1 | wc -c)
        echo "WebUI container: $(($log_size / 1024))KB"
    fi

    echo ""
    echo "Log cleanup options:"
    echo "1) Clear container logs"
    echo "2) Rotate logs (keep last 100 lines)"
    echo "3) Clear Docker system logs"
    echo "4) Clear all logs"
    echo "0) Cancel"

    read -p "Choose option (0-4): " choice

    case $choice in
        1|4)
            print_status "Clearing container logs..."
            for container in $CONTAINER_NAME $WEBUI_CONTAINER; do
                if docker ps -q --filter "name=$container" | grep -q .; then
                    log_path=$(docker inspect --format='{{.LogPath}}' $container 2>/dev/null)
                    if [[ -n $log_path ]]; then
                        sudo truncate -s 0 "$log_path" 2>/dev/null || print_warning "Could not clear logs for $container"
                    fi
                fi
            done
            ;;
        2)
            print_status "Rotating container logs..."
            for container in $CONTAINER_NAME $WEBUI_CONTAINER; do
                if docker ps -q --filter "name=$container" | grep -q .; then
                    docker logs --tail 100 $container > "/tmp/${container}_backup.log" 2>&1
                    log_path=$(docker inspect --format='{{.LogPath}}' $container 2>/dev/null)
                    if [[ -n $log_path ]]; then
                        sudo truncate -s 0 "$log_path" 2>/dev/null || print_warning "Could not rotate logs for $container"
                    fi
                fi
            done
            ;;
        3|4)
            print_status "Clearing Docker system logs..."
            sudo journalctl --vacuum-time=1d 2>/dev/null || print_warning "Could not clear system logs"
            ;;
        0)
            print_status "Log cleanup cancelled"
            ;;
    esac

    if [[ $choice != "0" ]]; then
        print_success "Log cleanup completed"
    fi
}

# Export context for session continuity
export_context() {
        print_header "📤 Exporting Session Context"

        local context_name=${1:-"session_$(date +%Y%m%d_%H%M%S)"}
        local context_dir="./context"
        local context_file="$context_dir/${context_name}.json"

        mkdir -p "$context_dir"

        print_status "Gathering project context..."

        # Use the dedicated context export script
        if [[ -f "./export-context.sh" ]]; then
            ./export-context.sh export "$context_name"
        else
            print_warning "Context export script not found, creating basic context..."

            cat > "$context_file" << EOF
{
  "export_info": {
    "timestamp": "$(date -Iseconds)",
    "context_name": "$context_name",
    "project_path": "$SCRIPT_DIR"
  },
  "services_status": "$(docker compose ps --format json 2>/dev/null || echo '[]')",
  "models": "$(docker exec $CONTAINER_NAME ollama list 2>/dev/null || echo 'Container not running')",
  "gpu_status": "$(docker exec $CONTAINER_NAME gpu-health 2>/dev/null || echo 'GPU check failed')"
}
EOF
            print_success "Basic context exported to: $context_file"
        fi
}

# Import context for session continuity
import_context() {
    local context_file=$1

    if [[ -z "$context_file" ]]; then
        print_error "Please specify a context file to import"
        return 1
    fi

    print_header "📥 Importing Session Context"

    # Use the dedicated context import script
    if [[ -f "./export-context.sh" ]]; then
        ./export-context.sh import "$context_file"
    else
        print_warning "Context export script not found, showing basic import..."
        if [[ -f "$context_file" ]]; then
            cat "$context_file"
        else
            print_error "Context file not found: $context_file"
        fi
    fi
}

# List available contexts
list_contexts() {
    print_header "📋 Available Contexts"

    # Use the dedicated context script
    if [[ -f "./export-context.sh" ]]; then
        ./export-context.sh list
    else
        print_warning "Context export script not found"
        local context_dir="./context"
        if [[ -d "$context_dir" ]]; then
            ls -la "$context_dir"/*.json 2>/dev/null || print_warning "No context files found"
        else
            print_warning "No context directory found"
        fi
    fi
}

# Reset all data (destructive)
reset_data() {
    print_header "🔥 Resetting All Data"
    print_error "WARNING: This will delete ALL data including models and configurations!"
    read -p "Type 'RESET' to confirm: " confirm

    if [ "$confirm" != "RESET" ]; then
        print_status "Reset cancelled"
        return 0
    fi

    print_status "Stopping services..."
    docker compose down -v

    print_status "Removing data directories..."
    rm -rf data/

    print_status "Removing Docker volumes..."
    docker volume rm -f ollama-local_ollama-data ollama-local_open-webui-data 2>/dev/null || true

    print_success "All data has been reset"
}

# Monitor system
monitor_system() {
    print_header "📊 System Monitor"
    print_status "Press Ctrl+C to stop monitoring"

    while true; do
        clear
        echo -e "${CYAN}Ollama System Monitor - $(date)${NC}"
        echo "=================================================================="

        # Container stats
        echo -e "\n${BLUE}Container Stats:${NC}"
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" $CONTAINER_NAME $WEBUI_CONTAINER 2>/dev/null || echo "Containers not running"

        # GPU stats
        echo -e "\n${BLUE}GPU Stats:${NC}"
        if command -v intel_gpu_top &> /dev/null; then
            timeout 2s intel_gpu_top -s 1000 -c 1 2>/dev/null | head -10 || echo "GPU monitoring unavailable"
        else
            echo "intel_gpu_top not available"
        fi

        # Memory and VRAM warnings
        echo -e "\n${BLUE}Memory & VRAM Status:${NC}"
        local vram_warnings=$(docker logs --since=1m $CONTAINER_NAME 2>&1 | grep -i "vram.*timeout\|gpu.*recover" | wc -l)
        if [ "$vram_warnings" -gt 0 ]; then
            echo -e "${RED}⚠️  VRAM warnings in last minute: $vram_warnings${NC}"
        else
            echo -e "${GREEN}✅ No recent VRAM warnings${NC}"
        fi

        # System load
        echo -e "\n${BLUE}System Load:${NC}"
        uptime

        sleep 5
    done
}

# Advanced memory monitoring
memory_monitor() {
    print_header "🧠 Advanced GPU Memory Monitor"

    if [ ! -f "./scripts/monitor-gpu-memory.sh" ]; then
        print_error "Memory monitoring script not found"
        print_status "Creating memory monitoring script..."
        return 1
    fi

    print_status "Starting advanced memory monitoring..."
    print_status "This will track GPU memory, VRAM warnings, and container health"
    print_status "Press Ctrl+C to stop"
    echo ""

    # Make sure script is executable
    chmod +x ./scripts/monitor-gpu-memory.sh

    # Run the memory monitor
    ./scripts/monitor-gpu-memory.sh --container "$CONTAINER_NAME"
}

# Test API connectivity
test_api() {
    print_header "🧪 Testing API Connectivity"

    local api_url="http://localhost:${OLLAMA_PORT:-11434}"

    print_status "Testing Ollama API at $api_url"

    if curl -s -f "$api_url/api/tags" >/dev/null; then
        print_success "Ollama API is responding"

        print_status "Available models:"
        curl -s "$api_url/api/tags" | python3 -m json.tool 2>/dev/null || echo "Could not parse response"
    else
        print_error "Ollama API is not responding"
    fi

    print_status "Testing Web UI at http://localhost:${WEBUI_PORT:-3000}"
    if curl -s -f "http://localhost:${WEBUI_PORT:-3000}/health" >/dev/null; then
        print_success "Web UI is responding"
    else
        print_warning "Web UI is not responding"
    fi
}

# Check service health
check_health() {
    print_header "🏥 Health Check"

    print_status "Docker Compose Services:"
    docker compose ps

    print_status "Container Health:"
    if is_running "ollama-arc-optimized"; then
        print_success "Ollama container is running"
    else
        print_error "Ollama container is not running"
    fi

    if is_running "ollama-webui-enhanced"; then
        print_success "Web UI container is running"
    else
        print_warning "Web UI container is not running"
    fi

    print_status "GPU Access:"
    if is_running "ollama-arc-optimized"; then
        if docker exec $CONTAINER_NAME ls /dev/dri/ >/dev/null 2>&1; then
            print_success "GPU devices accessible in container"
        else
            print_error "GPU devices not accessible in container"
        fi
    fi

    print_status "API Health:"
    test_api
}

# Main command dispatcher
main() {
    check_docker

    case "${1:-}" in
        quick-start)
            quick_start
            ;;
        start)
            start_services
            ;;
        stop)
            stop_services
            ;;
        restart)
            restart_services
            ;;
        build)
            build_containers
            ;;
        update)
            update_containers
            ;;
        logs)
            show_logs "$2"
            ;;
        status)
            show_status
            ;;
        shell)
            open_shell
            ;;
        gpu)
            show_gpu_info
            ;;
        gpu-test)
            if is_running "ollama-arc-optimized"; then
                print_header "🧪 Testing Intel IPEX-LLM and Arc GPU Setup"
                print_status "Running comprehensive GPU and ML library tests..."
                echo ""

                print_status "Testing Arc GPU devices and permissions..."
                docker exec $CONTAINER_NAME /llm/bin/gpu-diagnostics-comprehensive

                echo ""
                print_status "Testing Intel Extension for PyTorch..."
                docker exec $CONTAINER_NAME /opt/ipex-llm-env/bin/python -c "
import sys
print('🐍 Python ML Environment Test')
print('=' * 40)
try:
    import torch
    print(f'✅ PyTorch: {torch.__version__}')
except ImportError as e:
    print(f'❌ PyTorch: {e}')

try:
    import intel_extension_for_pytorch as ipex
    print(f'✅ Intel Extension for PyTorch: {ipex.__version__}')
except ImportError as e:
    print(f'❌ Intel Extension for PyTorch: {e}')

try:
    import transformers
    print(f'✅ Transformers: {transformers.__version__}')
except ImportError as e:
    print(f'❌ Transformers: {e}')

print('\\n🎯 Arc GPU Environment:')
import os
print(f'  DRI_PRIME: {os.getenv(\"DRI_PRIME\", \"not set\")}')
print(f'  OLLAMA_GPU_DEVICE: {os.getenv(\"OLLAMA_GPU_DEVICE\", \"not set\")}')
print(f'  OLLAMA_INTEL_GPU: {os.getenv(\"OLLAMA_INTEL_GPU\", \"not set\")}')
print(f'  IPEX_LLM_NUM_CTX: {os.getenv(\"IPEX_LLM_NUM_CTX\", \"not set\")}')
print(f'  IPEX_LLM_LOW_MEM: {os.getenv(\"IPEX_LLM_LOW_MEM\", \"not set\")}')
print(f'  SYCL_DEVICE_FILTER: {os.getenv(\"SYCL_DEVICE_FILTER\", \"not set\")}')
"

                echo ""
                print_status "Testing Ollama context window configuration..."
                echo "IPEX_LLM_NUM_CTX value: $(docker exec $CONTAINER_NAME printenv IPEX_LLM_NUM_CTX)"

                echo ""
                print_status "Testing Ollama API and model performance..."
                if docker exec $CONTAINER_NAME curl -s http://localhost:11434/api/tags | grep -q "models"; then
                    print_success "Ollama API is responsive"
                    echo ""
                    print_status "Testing model inference with GPU optimization..."
                    time docker exec $CONTAINER_NAME curl -s -X POST http://localhost:11434/api/generate \
                        -d '{"model":"qwen2.5:0.5b","prompt":"Test GPU: What is 2+2?","stream":false}' | \
                        jq -r '.response' | head -1
                else
                    print_warning "No models available for GPU testing"
                fi

                print_success "GPU and IPEX-LLM test completed!"
            else
                print_error "Ollama container is not running"
                print_status "Start the container first: $0 start"
            fi
            ;;
        models)
            list_models
            ;;
        pull)
            pull_model "$2"
            ;;
        remove|rm)
            remove_model "$2"
            ;;
        run)
            run_model "$2"
            ;;
        chat)
            chat_model "$2"
            ;;
        update)
            update_containers
            ;;
        backup)
            backup_data
            ;;
        restore)
            restore_data "$2"
            ;;
        cleanup)
            cleanup
            ;;
        cleanup-models)
            cleanup_models
            ;;
        cleanup-logs)
            cleanup_logs
            ;;
        export-context)
            export_context "$2"
            ;;
        import-context)
            import_context "$2"
            ;;
        list-contexts)
            list_contexts
            ;;
        gpu-monitor)
            if is_running "ollama-arc-optimized"; then
                print_header "🎮 Real-time Intel Arc GPU Monitoring"
                print_status "Starting GPU monitor (Press Ctrl+C to stop)"
                echo ""
                print_status "Available monitoring options:"
                echo "  • intel_gpu_top - Real-time GPU utilization"
                echo "  • GPU device status and memory usage"
                echo "  • Arc A770: 15.9 GiB total VRAM"
                echo ""

                # Check if intel_gpu_top is available in container
                if docker exec $CONTAINER_NAME command -v intel_gpu_top >/dev/null 2>&1; then
                    print_status "Starting intel_gpu_top monitoring..."
                    if [ -t 0 ] && [ -t 1 ]; then
                        docker exec -it $CONTAINER_NAME intel_gpu_top
                    else
                        print_warning "TTY not available, showing GPU status instead"
                        docker exec $CONTAINER_NAME intel_gpu_top -l
                    fi
                else
                    print_warning "intel_gpu_top not available, showing alternative GPU info"
                    docker exec $CONTAINER_NAME /llm/bin/gpu-diagnostics
                fi
            else
                print_error "Ollama container is not running"
                print_status "Start the container first: $0 start"
            fi
            ;;
        reset)
            reset_data
            ;;
        monitor)
            monitor_system
            ;;
        memory-monitor)
            memory_monitor
            ;;
        test)
            test_api
            ;;
        health)
            check_health
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            if [ -n "${1:-}" ]; then
                print_error "Unknown command: $1"
                echo ""
            fi
            usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
