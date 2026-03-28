#!/bin/bash

# Ollama Management Script for Intel Arc A770 (IPEX-LLM / Level Zero / SYCL)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load environment variables
if [ -f .env ]; then
    source .env
fi

CONTAINER_NAME=${CONTAINER_NAME:-ollama-arc-sycl}
COMPOSE_FILE="docker-compose.yml"

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

# Check if Docker and Docker Compose are available
check_dependencies() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi

    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose V2 is not available"
        exit 1
    fi
}

# Check if container is running
is_running() {
    local container_name=$1
    docker ps --format "table {{.Names}}" | grep -q "^${container_name}$"
}

# Get container status
get_status() {
    local container_name=$1
    docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "not_found"
}

# Build containers
build_containers() {
    print_header "Building Containers"

    print_status "Building Ollama SYCL container..."
    docker compose -f "$COMPOSE_FILE" build --no-cache

    print_success "Containers built successfully"
}

# Start services
start_services() {
    print_header "Starting Ollama Services"

    check_dependencies

    # Create data directory for WebUI
    mkdir -p data/webui

    # Auto-generate WEBUI_SECRET_KEY if still set to placeholder
    if [ -f .env ] && grep -q 'change-me' .env; then
        local new_key
        new_key=$(openssl rand -hex 32)
        sed -i "s/WEBUI_SECRET_KEY=.*/WEBUI_SECRET_KEY=${new_key}/" .env
        print_success "Generated new WEBUI_SECRET_KEY"
    fi

    print_status "Starting services with Docker Compose..."
    docker compose -f "$COMPOSE_FILE" up -d

    print_status "Waiting for services to be ready..."
    sleep 10

    # Wait for Ollama to be ready
    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if curl -s -f http://localhost:11434/api/tags > /dev/null 2>&1; then
            print_success "Ollama API is ready"
            break
        fi

        print_status "Waiting for Ollama API... (attempt $attempt/$max_attempts)"
        sleep 5
        attempt=$((attempt + 1))
    done

    if [ $attempt -gt $max_attempts ]; then
        print_error "Ollama API failed to start within expected time"
        return 1
    fi

    print_success "All services started successfully"
    #print_status "Web UI available at: http://localhost:3000"
    print_status "API available at: http://localhost:11434"
}

# Stop services
stop_services() {
    print_header "Stopping Ollama Services"

    docker compose -f "$COMPOSE_FILE" down

    print_success "Services stopped"
}

# Restart services
restart_services() {
    print_header "Restarting Ollama Services"

    stop_services
    sleep 2
    start_services
}

# Show service status
show_status() {
    print_header "Service Status"

    local ollama_status=$(get_status "$CONTAINER_NAME")
    # local webui_status=$(get_status "$WEBUI_CONTAINER")

    echo "Ollama Container: $ollama_status"
    # echo "WebUI Container: $webui_status"
    echo ""

    if is_running "$CONTAINER_NAME"; then
        print_status "Ollama API Status:"
        if curl -s -f http://localhost:11434/api/tags > /dev/null 2>&1; then
            echo "  API: ✅ Responsive"
        else
            echo "  API: ❌ Not responding"
        fi
    fi

    if is_running "$WEBUI_CONTAINER"; then
        print_status "WebUI Status:"
        if curl -s -f http://localhost:3000/health > /dev/null 2>&1; then
            echo "  WebUI: ✅ Responsive"
        else
            echo "  WebUI: ❌ Not responding"
        fi
    fi
}

# Hardware test
hardware_test() {
    print_header "SYCL / Level Zero Hardware Test - Intel Arc A770"

    if ! is_running "$CONTAINER_NAME"; then
        print_error "Ollama container is not running. Start services first."
        return 1
    fi

    print_status "Checking DRI device nodes..."
    docker exec "$CONTAINER_NAME" bash -c "ls -la /dev/dri/ 2>/dev/null || echo 'No /dev/dri devices found'"

    print_status "Checking Level Zero / SYCL GPU detection..."
    docker exec "$CONTAINER_NAME" bash -c "
if command -v sycl-ls > /dev/null 2>&1; then
    sycl-ls 2>/dev/null
else
    echo 'sycl-ls not available — checking Ollama GPU detection via API...'
fi"

    print_status "Testing model inference on GPU..."
    local test_model="qwen3:8b"
    if ! docker exec "$CONTAINER_NAME" ollama list 2>/dev/null | grep -q "qwen3:8b"; then
        test_model="$(docker exec "$CONTAINER_NAME" ollama list 2>/dev/null | awk 'NR>1 {print $1; exit}')"
    fi

    if [ -n "$test_model" ]; then
        docker exec "$CONTAINER_NAME" ollama run "$test_model" "Say hello in one word" 2>/dev/null \
            && print_success "Inference test passed with $test_model" \
            || print_warning "Inference test failed — check logs with: ./manage.sh logs"
    else
        print_warning "No models installed. Run: ./manage.sh pull-models"
    fi

    print_success "Intel Arc A770 hardware test completed"
}

# Show hardware information
hardware_info() {
    print_header "Hardware Information - Intel Arc A770 Setup"

    print_status "System Information:"
    echo "CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
    echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
    echo "Storage: $(df -h . | tail -1 | awk '{print $4}') available"

    print_status "GPU Information (host):"
    lspci | grep -E "(VGA|3D|Display)" | grep -i intel || echo "No Intel GPU found in lspci"

    print_status "DRI Devices (host):"
    ls -la /dev/dri/ 2>/dev/null || echo "No /dev/dri devices"

    if is_running "$CONTAINER_NAME"; then
        print_status "Ollama GPU Detection:"
        curl -s http://localhost:11434/api/tags > /dev/null 2>&1 \
            && echo "  API: ✅ Responsive" \
            || echo "  API: ❌ Not responding"

        docker exec "$CONTAINER_NAME" bash -c "
echo 'Container DRI devices:'
ls /dev/dri/ 2>/dev/null || echo '  none'
echo 'SYCL devices:'
sycl-ls 2>/dev/null || echo '  sycl-ls not available'
" 2>/dev/null || echo "Container GPU information not available"
    fi
}

# List models
list_models() {
    print_header "Installed Models"

    if ! is_running "$CONTAINER_NAME"; then
        print_error "Ollama container is not running"
        return 1
    fi

    docker exec "$CONTAINER_NAME" ollama list
}

# Pull model
pull_model() {
    local model_name="$1"

    if [ -z "$model_name" ]; then
        print_error "Model name required"
        echo "Usage: $0 pull <model_name>"
        return 1
    fi

    print_header "Pulling Model: $model_name"

    if ! is_running "$CONTAINER_NAME"; then
        print_error "Ollama container is not running"
        return 1
    fi

    docker exec "$CONTAINER_NAME" ollama pull "$model_name"
    print_success "Model $model_name pulled successfully"
}

# Remove model
remove_model() {
    local model_name="$1"

    if [ -z "$model_name" ]; then
        print_error "Model name required"
        echo "Usage: $0 remove <model_name>"
        return 1
    fi

    print_header "Removing Model: $model_name"

    if ! is_running "$CONTAINER_NAME"; then
        print_error "Ollama container is not running"
        return 1
    fi

    docker exec "$CONTAINER_NAME" ollama rm "$model_name"
    print_success "Model $model_name removed successfully"
}

# Interactive chat
chat() {
    local model_name="$1"

    if [ -z "$model_name" ]; then
        print_error "Model name required"
        echo "Usage: $0 chat <model_name>"
        return 1
    fi

    print_header "Interactive Chat with $model_name"
    print_status "Type 'exit' or press Ctrl+C to quit"

    if ! is_running "$CONTAINER_NAME"; then
        print_error "Ollama container is not running"
        return 1
    fi

    docker exec -it "$CONTAINER_NAME" ollama run "$model_name"
}

# View logs
view_logs() {
    local service="$1"

    print_header "Service Logs"

    if [ -n "$service" ]; then
        docker compose -f "$COMPOSE_FILE" logs -f "$service"
    else
        docker compose -f "$COMPOSE_FILE" logs -f
    fi
}

# Health check
health_check() {
    print_header "Comprehensive Health Check"

    # Check Docker
    print_status "Checking Docker..."
    if docker info > /dev/null 2>&1; then
        echo "  Docker: ✅ Running"
    else
        echo "  Docker: ❌ Not available"
        return 1
    fi

    # Check containers
    print_status "Checking containers..."
    local ollama_status=$(get_status "$CONTAINER_NAME")

    if [ "$ollama_status" = "running" ]; then
        echo "  Ollama: ✅ Running"
    else
        echo "  Ollama: ❌ $ollama_status"
    fi

    # Check API endpoints
    if is_running "$CONTAINER_NAME"; then
        print_status "Checking API endpoints..."
        if curl -s -f http://localhost:11434/api/tags > /dev/null 2>&1; then
            echo "  Ollama API: ✅ Responsive"
        else
            echo "  Ollama API: ❌ Not responding"
        fi
    fi

    if is_running "$WEBUI_CONTAINER"; then
        if curl -s -f http://localhost:3000 > /dev/null 2>&1; then
            echo "  WebUI: ✅ Responsive"
        else
            echo "  WebUI: ❌ Not responding"
        fi
    fi

    # Check disk space
    print_status "Checking disk space..."
    local available=$(df . | tail -1 | awk '{print $4}')
    if [ "$available" -gt 1000000 ]; then  # 1GB in KB
        echo "  Disk space: ✅ Sufficient"
    else
        echo "  Disk space: ⚠️  Low ($(df -h . | tail -1 | awk '{print $4}') available)"
    fi

    print_success "Health check completed"
}

# Cleanup unused resources
cleanup() {
    print_header "Cleaning Up Resources"

    print_status "Stopping and removing project containers, networks..."
    docker compose -f "$COMPOSE_FILE" down --remove-orphans

    print_status "Removing unused Docker images..."
    docker image prune -f

    print_success "Cleanup completed"
}

# Update containers
update() {
    print_header "Updating Containers"

    print_status "Pulling latest images..."
    docker compose -f "$COMPOSE_FILE" pull

    print_status "Rebuilding containers..."
    build_containers

    print_status "Restarting services..."
    restart_services

    print_success "Update completed"
}

# Backup data
backup() {
    local backup_dir="backup_$(date +%Y%m%d_%H%M%S)"

    print_header "Creating Backup"

    mkdir -p "$backup_dir"

    print_status "Backing up WebUI data..."
    if [ -d "data/webui" ]; then
        cp -r data/webui "$backup_dir/"
    fi
    # Model weights are excluded — re-pull with: ./manage.sh pull-models

    print_status "Backing up configuration..."
    cp docker-compose.yml "$backup_dir/"
    cp .env "$backup_dir/" 2>/dev/null || true

    print_success "Backup created in $backup_dir"
}

# Shell access
shell() {
    if ! is_running "$CONTAINER_NAME"; then
        print_error "Ollama container is not running"
        return 1
    fi

    print_status "Opening shell in Ollama container..."
    docker exec -it "$CONTAINER_NAME" /bin/bash
}

# Pull the models needed by ha_boss and opn_boss
pull_models() {
    print_header "Pulling Required Models"

    if ! is_running "$CONTAINER_NAME"; then
        print_error "Ollama container is not running. Start services first."
        return 1
    fi

    print_status "Pulling llama3.1:8b (for ha_boss)..."
    docker exec "$CONTAINER_NAME" ollama pull llama3.1:8b

    print_status "Pulling phi3:mini (for opn_boss)..."
    docker exec "$CONTAINER_NAME" ollama pull phi3:mini

    # NOTE: qwen3.5:9b hangs on SYCL inference (multimodal ops not supported)
    print_status "Pulling qwen3:8b (text-only, confirmed working on SYCL)..."
    docker exec "$CONTAINER_NAME" ollama pull qwen3:8b

    print_success "Required models pulled."

    create_models

    print_success "All models ready. Run './manage.sh models' to verify."
}

# Create custom models from Modelfiles in models/
create_models() {
    print_header "Creating Custom Models from Modelfiles"

    if ! is_running "$CONTAINER_NAME"; then
        print_error "Ollama container is not running. Start services first."
        return 1
    fi

    # models/Modelfile.qwen3-8b-nothink → qwen3:8b-nothink
    # Requires qwen3:8b to already be pulled.
    if docker exec "$CONTAINER_NAME" ollama list | grep -q "^qwen3:8b "; then
        print_status "Creating qwen3:8b-nothink (thinking disabled by default)..."
        docker cp models/Modelfile.qwen3-8b-nothink "$CONTAINER_NAME":/tmp/Modelfile.qwen3-8b-nothink
        docker exec "$CONTAINER_NAME" ollama create qwen3:8b-nothink -f /tmp/Modelfile.qwen3-8b-nothink
        print_success "qwen3:8b-nothink created — use this for non-reasoning tasks"
    else
        print_warning "qwen3:8b not found — skipping qwen3:8b-nothink (run pull-models first)"
    fi
}

# Quick start
quick_start() {
    print_header "Quick Start - Ollama + Intel Arc A770 Setup"

    print_status "Step 1: Starting services..."
    start_services

    print_status "Step 2: Pulling required models..."
    pull_models

    print_success "Quick start completed!"
    # print_status "Access the Web UI at: http://localhost:3000"
    print_status "API available at: http://localhost:11434"
}

# Benchmark
benchmark() {
    print_header "Performance Benchmark"

    if ! is_running "$CONTAINER_NAME"; then
        print_error "Ollama container is not running"
        return 1
    fi

    # Use a non-reasoning model for clean benchmark results.
    # qwen3:8b generates thinking tokens which skew tok/s — use llama3.1:8b instead.
    local test_model="llama3.1:8b"
    local test_prompt="Write a short story about artificial intelligence in exactly 100 words."

    print_status "Running benchmark with model: $test_model"
    print_status "Test prompt: $test_prompt"

    # Ensure model is available
    if ! docker exec "$CONTAINER_NAME" ollama list | grep -q "$test_model"; then
        print_status "Pulling test model..."
        pull_model "$test_model"
    fi

    print_status "Starting benchmark..."
    local start_time=$(date +%s)

    local tmpfile
    tmpfile=$(mktemp /tmp/benchmark_XXXXXX.txt)
    docker exec "$CONTAINER_NAME" ollama run "$test_model" "$test_prompt" > "$tmpfile"

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    print_success "Benchmark completed in ${duration} seconds"

    local word_count=$(wc -w < "$tmpfile")
    local tokens_per_second=$(echo "scale=2; $word_count / $duration" | bc -l 2>/dev/null || echo "N/A")
    print_status "Approximate tokens per second: $tokens_per_second"
    rm -f "$tmpfile"
}

# Show help
show_help() {
    echo "Ollama Management Script - Intel Arc A770 (SYCL)"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  quick-start         Complete setup and test"
    echo "  build              Build containers"
    echo "  start              Start all services"
    echo "  stop               Stop all services"
    echo "  restart            Restart all services"
    echo "  status             Show service status"
    echo "  health             Comprehensive health check"
    echo ""
    echo "Hardware Commands:"
    echo "  hardware-test      Test SYCL/Level Zero GPU acceleration"
    echo "  hardware-info      Show hardware information"
    echo "  benchmark          Run performance benchmark"
    echo ""
    echo "Model Commands:"
    echo "  models             List installed models"
    echo "  pull <model>       Download a model"
    echo "  pull-models        Pull llama3.1:8b, phi3:mini, and qwen3:8b"
    echo "  create-models      Create custom models from Modelfiles (e.g. qwen3:8b-nothink)"
    echo "  remove <model>     Remove a model"
    echo "  chat <model>       Interactive chat with model"
    echo ""
    echo "Maintenance Commands:"
    echo "  logs [service]     View service logs"
    echo "  update             Update containers"
    echo "  cleanup            Remove unused resources"
    echo "  backup             Backup data and configuration"
    echo "  shell              Access container shell"
    echo ""
    echo "Examples:"
    echo "  $0 quick-start"
    echo "  $0 pull llama2:7b"
    echo "  $0 chat qwen3:8b"
    echo "  $0 hardware-test"
}

# Main command handler
case "${1:-}" in
    "quick-start")
        quick_start
        ;;
    "build")
        build_containers
        ;;
    "start")
        start_services
        ;;
    "stop")
        stop_services
        ;;
    "restart")
        restart_services
        ;;
    "status")
        show_status
        ;;
    "health")
        health_check
        ;;
    "hardware-test")
        hardware_test
        ;;
    "hardware-info")
        hardware_info
        ;;
    "benchmark")
        benchmark
        ;;
    "models")
        list_models
        ;;
    "pull")
        pull_model "$2"
        ;;
    "pull-models")
        pull_models
        ;;
    "create-models")
        create_models
        ;;
    "remove")
        remove_model "$2"
        ;;
    "chat")
        chat "$2"
        ;;
    "logs")
        view_logs "$2"
        ;;
    "update")
        update
        ;;
    "cleanup")
        cleanup
        ;;
    "backup")
        backup
        ;;
    "shell")
        shell
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    "")
        print_error "No command specified"
        echo ""
        show_help
        exit 1
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
