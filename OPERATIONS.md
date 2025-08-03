# Ollama Local - Operations Guide

Complete operations manual for managing your Intel Arc GPU optimized Ollama deployment.

## 📋 Table of Contents

- [Quick Reference](#-quick-reference)
- [Installation & Setup](#-installation--setup)
- [Service Management](#-service-management)
- [GPU Operations](#-gpu-operations)
- [Model Management](#-model-management)
- [Monitoring & Diagnostics](#-monitoring--diagnostics)
- [Maintenance & Updates](#-maintenance--updates)
- [Performance Tuning](#-performance-tuning)
- [Backup & Recovery](#-backup--recovery)
- [Troubleshooting](#-troubleshooting)
- [Advanced Configuration](#-advanced-configuration)

---

## 🚀 Quick Reference

### Essential Commands
```bash
# Complete setup from scratch
./manage.sh quick-start

# Service management
./manage.sh start           # Start all services
./manage.sh stop            # Stop all services
./manage.sh restart         # Restart services
./manage.sh status          # Show service status

# GPU operations
./manage.sh gpu-test        # Test GPU acceleration
./manage.sh gpu-monitor     # Monitor GPU usage
./manage.sh gpu             # Show GPU info

# Model management
./manage.sh models          # List models
./manage.sh pull <model>    # Download model
./manage.sh chat <model>    # Interactive chat

# Health & diagnostics
./manage.sh health          # Full health check
./manage.sh logs [service]  # View logs
```

### Access Points
- **Web UI**: http://localhost:3000
- **API**: http://localhost:11434
- **Health Check**: http://localhost:11434/api/tags

---

## 🛠️ Installation & Setup

### Prerequisites Verification

Before installation, verify your system meets requirements:

```bash
# Check Docker installation
docker --version
docker compose version

# Verify Intel Arc GPU
lspci | grep -i intel
ls -la /dev/dri/

# Check system resources
free -h
df -h
```

**Required Output:**
- Docker 24.0+ with Compose V2
- Intel Arc GPU visible in lspci
- `/dev/dri/card1` and `/dev/dri/renderD129` devices
- 16GB+ RAM, 50GB+ free storage

### Initial Setup Methods

#### Method 1: Quick Start (Recommended)
```bash
# Clone repository
git clone <repository-url>
cd ollama-local

# Complete automated setup
chmod +x manage.sh
./manage.sh quick-start
```

**Expected output:**
```
🚀 Quick Start - Complete Ollama Arc GPU Setup
==================================================================
[INFO] Step 1/5: Building containers...
[INFO] Step 2/5: Starting services...
[INFO] Step 3/5: Testing GPU setup...
[INFO] Step 4/5: Pulling test model...
[INFO] Step 5/5: Testing model inference...
[SUCCESS] 🎉 Quick start completed!
```

#### Method 2: Manual Setup
```bash
# Build containers
./manage.sh build

# Start services
./manage.sh start

# Wait for services to be ready
sleep 30

# Test GPU functionality
./manage.sh gpu-test

# Pull your first model
./manage.sh pull qwen2.5:0.5b
```

### Post-Installation Verification

```bash
# Check service health
./manage.sh health

# Verify GPU acceleration
./manage.sh gpu-test

# Test model inference
./manage.sh chat qwen2.5:0.5b
```

---

## ⚙️ Service Management

### Container Lifecycle

#### Starting Services
```bash
# Start all services
./manage.sh start

# Start specific service
docker compose up -d ollama-arc-optimized
docker compose up -d ollama-webui-enhanced
```

#### Stopping Services
```bash
# Stop all services
./manage.sh stop

# Stop specific service
docker compose stop ollama-arc-optimized
docker compose stop ollama-webui-enhanced

# Stop and remove containers
docker compose down
```

#### Restarting Services
```bash
# Restart all services
./manage.sh restart

# Restart specific service
docker compose restart ollama-arc-optimized
```

### Service Status Monitoring

#### Check Service Status
```bash
# Comprehensive status
./manage.sh status

# Docker compose status
docker compose ps

# Container health
docker compose ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

**Expected healthy output:**
```
NAME                    STATUS                    PORTS
ollama-arc-optimized    Up X minutes (healthy)    0.0.0.0:11434->11434/tcp
ollama-webui-enhanced   Up X minutes (healthy)    0.0.0.0:3000->8080/tcp
```

#### Resource Usage
```bash
# Resource monitoring
./manage.sh monitor

# Real-time stats
docker stats ollama-arc-optimized ollama-webui-enhanced

# Memory usage
docker exec ollama-arc-optimized free -h
```

### Service Dependencies

**Startup Order:**
1. ollama-arc-optimized (primary service)
2. ollama-webui-enhanced (depends on Ollama)

**Health Check Sequence:**
1. Container startup (10-15 seconds)
2. GPU initialization (5-10 seconds)
3. API availability (1-2 seconds)
4. Model loading (variable)

---

## 🎮 GPU Operations

### GPU Status & Diagnostics

#### Basic GPU Information
```bash
# Quick GPU info
./manage.sh gpu

# Comprehensive diagnostics
./manage.sh gpu-test

# GPU device verification
docker exec ollama-arc-optimized ls -la /dev/dri/
```

#### Detailed GPU Diagnostics
```bash
# Full GPU diagnostics
docker exec ollama-arc-optimized /llm/bin/gpu-diagnostics-comprehensive

# Intel GPU stack information
docker exec ollama-arc-optimized env | grep -E "(INTEL|SYCL|OLLAMA_GPU)"

# OpenCL platform info
docker exec ollama-arc-optimized clinfo
```

### GPU Performance Monitoring

#### Real-time GPU Monitoring
```bash
# Start GPU monitor
./manage.sh gpu-monitor

# Intel GPU top (if available)
docker exec ollama-arc-optimized intel_gpu_top

# Custom monitoring loop
while true; do
  echo "=== $(date) ==="
  docker exec ollama-arc-optimized nvidia-smi || echo "Intel GPU monitoring"
  sleep 5
done
```

#### Performance Metrics
```bash
# Check IPEX_LLM configuration
docker exec ollama-arc-optimized printenv | grep IPEX_LLM

# SYCL cache status
docker exec ollama-arc-optimized ls -la /tmp/sycl_cache/

# GPU memory usage
docker exec ollama-arc-optimized cat /sys/class/drm/card1/device/mem_info_vram_used
```

### GPU Optimization Verification

#### Context Window Configuration
```bash
# Verify 16K context setting
echo "IPEX_LLM_NUM_CTX: $(docker exec ollama-arc-optimized printenv IPEX_LLM_NUM_CTX)"

# Test large context
docker exec ollama-arc-optimized curl -s -X POST http://localhost:11434/api/generate \
  -d '{"model":"qwen2.5:0.5b","prompt":"Long context test...","options":{"num_ctx":16384}}'
```

#### Performance Settings Verification
```bash
# Check optimization flags
docker exec ollama-arc-optimized env | grep -E "(NEO_DISABLE|SYCL_CACHE|OLLAMA_GPU_LAYERS)"

# Expected output:
# NEO_DISABLE_MITIGATIONS=1
# SYCL_CACHE_PERSISTENT=1
# OLLAMA_GPU_LAYERS=999
```

---

## 📚 Model Management

### Model Discovery & Installation

#### Browsing Available Models
```bash
# Popular models
./manage.sh models

# Search for models (manual)
docker exec ollama-arc-optimized ollama list
```

**Recommended Models by Size:**
- **Lightweight (< 1GB)**: qwen2.5:0.5b, tinyllama
- **Medium (1-5GB)**: llama2:7b, mistral:7b, qwen2.5:7b
- **Large (5-15GB)**: deepseek-r1:8b, llama2:13b, codellama:13b

#### Installing Models
```bash
# Install lightweight model (fast)
./manage.sh pull qwen2.5:0.5b

# Install medium model
./manage.sh pull llama2:7b

# Install coding model
./manage.sh pull codellama:7b

# Monitor download progress
docker exec ollama-arc-optimized ollama ps
```

#### Verifying Model Installation
```bash
# List installed models
./manage.sh models

# Test model functionality
./manage.sh chat qwen2.5:0.5b

# API test
curl -X POST http://localhost:11434/api/generate \
  -d '{"model":"qwen2.5:0.5b","prompt":"Hello!","stream":false}'
```

### Model Configuration & Tuning

#### Custom Model Parameters
```bash
# Create custom Modelfile
cat > Modelfile << EOF
FROM llama2:7b
PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER num_ctx 16384
SYSTEM You are a helpful assistant specialized in technical topics.
EOF

# Build custom model
docker exec ollama-arc-optimized ollama create my-assistant -f Modelfile
```

#### Model Performance Tuning
```bash
# Test different context sizes
for ctx in 4096 8192 16384; do
  echo "Testing context size: $ctx"
  time docker exec ollama-arc-optimized curl -s -X POST http://localhost:11434/api/generate \
    -d "{\"model\":\"qwen2.5:0.5b\",\"prompt\":\"Test\",\"options\":{\"num_ctx\":$ctx}}"
done

# Benchmark inference speed
./manage.sh benchmark qwen2.5:0.5b
```

### Model Lifecycle Management

#### Model Updates
```bash
# Update existing model
./manage.sh pull llama2:7b --force

# Check for updates
docker exec ollama-arc-optimized ollama list | grep "days ago"
```

#### Model Removal
```bash
# Remove specific model
./manage.sh remove old-model

# Clean up unused models
./manage.sh cleanup-models

# Force removal
docker exec ollama-arc-optimized ollama rm model-name
```

#### Model Storage Management
```bash
# Check storage usage
./manage.sh storage

# Analyze model sizes
docker exec ollama-arc-optimized du -sh /root/.ollama/models/*

# Clean cache
docker exec ollama-arc-optimized rm -rf /tmp/ollama-cache/*
```

---

## 📊 Monitoring & Diagnostics

### Health Monitoring

#### Comprehensive Health Check
```bash
# Full system health
./manage.sh health

# Expected output:
# ✅ Services Status
# ✅ Container Health  
# ✅ GPU Access
# ✅ API Health
# ✅ Web UI Health
```

#### Service-Specific Health
```bash
# Ollama service health
curl -f http://localhost:11434/api/tags

# Web UI health
curl -f http://localhost:3000/health

# Container health
docker inspect ollama-arc-optimized --format='{{.State.Health.Status}}'
```

### Log Management

#### Viewing Logs
```bash
# All services logs
./manage.sh logs

# Specific service logs
./manage.sh logs ollama
./manage.sh logs webui

# Real-time log following
docker compose logs -f ollama-arc-optimized

# Filtered logs
docker compose logs ollama-arc-optimized | grep -i gpu
```

#### Log Analysis
```bash
# Check for errors
docker compose logs ollama-arc-optimized | grep -i error

# GPU initialization logs
docker compose logs ollama-arc-optimized | grep -i "gpu\|intel\|sycl"

# Performance logs
docker compose logs ollama-arc-optimized | grep -i "inference\|token"
```

### Performance Monitoring

#### Resource Usage Tracking
```bash
# Container resource usage
docker stats --no-stream ollama-arc-optimized

# System resource usage
docker exec ollama-arc-optimized top -n 1

# Memory usage breakdown
docker exec ollama-arc-optimized cat /proc/meminfo | head -10
```

#### API Performance Monitoring
```bash
# Response time testing
time curl -X POST http://localhost:11434/api/generate \
  -d '{"model":"qwen2.5:0.5b","prompt":"Performance test","stream":false}'

# Concurrent request testing
for i in {1..5}; do
  curl -X POST http://localhost:11434/api/generate \
    -d '{"model":"qwen2.5:0.5b","prompt":"Test $i","stream":false}' &
done
wait
```

#### GPU Performance Analysis
```bash
# SYCL cache hit rate
ls -la /tmp/sycl_cache/ | wc -l

# GPU memory usage
cat /sys/class/drm/card1/device/mem_info_vram_total
cat /sys/class/drm/card1/device/mem_info_vram_used

# Context window utilization
grep "num_ctx" /var/log/ollama.log
```

---

## 🔧 Maintenance & Updates

### Container Updates

#### Updating Base Images
```bash
# Update containers
./manage.sh update

# Manual update process
docker compose pull
docker compose build --no-cache
docker compose up -d
```

#### Rolling Updates
```bash
# Zero-downtime update
docker compose build ollama-arc-optimized
docker compose up -d --no-deps ollama-arc-optimized
```

### System Maintenance

#### Cleanup Operations
```bash
# Clean unused resources
./manage.sh cleanup

# Clean Docker system
docker system prune -a

# Clean specific components
./manage.sh cleanup-models
./manage.sh cleanup-logs
```

#### Cache Management
```bash
# Clear SYCL cache
docker exec ollama-arc-optimized rm -rf /tmp/sycl_cache/*

# Clear Ollama cache
docker exec ollama-arc-optimized rm -rf /tmp/ollama-*

# Rebuild caches
docker compose restart ollama-arc-optimized
```

### Configuration Updates

#### Environment Variable Updates
```bash
# Edit configuration
nano .env

# Apply changes
docker compose down
docker compose up -d

# Verify changes
docker exec ollama-arc-optimized printenv | grep IPEX_LLM
```

#### Service Configuration Updates
```bash
# Edit docker-compose.yml
nano docker-compose.yml

# Validate configuration
docker compose config

# Apply changes
docker compose up -d
```

---

## ⚡ Performance Tuning

### GPU Performance Optimization

#### Context Window Tuning
```bash
# Test different context sizes
for size in 4096 8192 16384 32768; do
  echo "Testing context size: $size"
  # Update IPEX_LLM_NUM_CTX=$size in .env
  docker compose restart ollama-arc-optimized
  # Run performance test
  time ./manage.sh chat qwen2.5:0.5b "Summarize quantum computing"
done
```

#### Memory Optimization
```bash
# Enable low memory mode
echo "IPEX_LLM_LOW_MEM=1" >> .env

# Adjust GPU layers
echo "OLLAMA_GPU_LAYERS=50" >> .env  # Reduce if memory constrained

# Restart to apply
docker compose restart ollama-arc-optimized
```

#### Parallel Processing Tuning
```bash
# Adjust parallel requests
echo "OLLAMA_NUM_PARALLEL=4" >> .env

# Adjust max loaded models
echo "OLLAMA_MAX_LOADED_MODELS=2" >> .env

# Test concurrent performance
for i in {1..4}; do
  ./manage.sh chat qwen2.5:0.5b "Test $i" &
done
wait
```

### System Performance Optimization

#### Resource Allocation
```bash
# Increase container memory
# In docker-compose.yml:
deploy:
  resources:
    limits:
      memory: 64G
    reservations:
      memory: 32G
```

#### Intel GPU Optimizations
```bash
# Verify performance settings
docker exec ollama-arc-optimized env | grep -E "(NEO_DISABLE|SYCL_PI)"

# Expected optimizations:
# NEO_DISABLE_MITIGATIONS=1
# SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS=1
# SYCL_PI_LEVEL_ZERO_DEVICE_SCOPE_EVENTS=1
```

### Benchmarking

#### Performance Benchmarking
```bash
# Create benchmark script
cat > benchmark.sh << 'EOF'
#!/bin/bash
MODEL=${1:-qwen2.5:0.5b}
PROMPT="Explain quantum computing in detail with examples and applications."

echo "Benchmarking model: $MODEL"
echo "=========================================="

# Warm-up run
curl -s -X POST http://localhost:11434/api/generate \
  -d "{\"model\":\"$MODEL\",\"prompt\":\"Hello\"}" > /dev/null

# Benchmark runs
for i in {1..5}; do
  echo "Run $i:"
  time curl -s -X POST http://localhost:11434/api/generate \
    -d "{\"model\":\"$MODEL\",\"prompt\":\"$PROMPT\",\"stream\":false}" | \
    jq -r '.response' | wc -w
  echo ""
done
EOF

chmod +x benchmark.sh
./benchmark.sh qwen2.5:0.5b
```

---

## 💾 Backup & Recovery

### Data Backup

#### Model Backup
```bash
# Backup all models
./manage.sh backup

# Manual model backup
tar -czf models-backup-$(date +%Y%m%d).tar.gz data/models/

# Backup specific model
docker exec ollama-arc-optimized ollama export qwen2.5:0.5b > qwen25-backup.gguf
```

#### Configuration Backup
```bash
# Backup configuration files
tar -czf config-backup-$(date +%Y%m%d).tar.gz \
  docker-compose.yml .env manage.sh

# Backup volumes
docker run --rm -v ollama-local_ollama_models:/data \
  -v $(pwd):/backup alpine tar czf /backup/models-backup.tar.gz /data
```

#### Complete System Backup
```bash
# Export containers
docker save ollama-local-ollama-arc-optimized:latest | gzip > ollama-image-backup.tar.gz

# Backup all data
tar -czf ollama-complete-backup-$(date +%Y%m%d).tar.gz \
  data/ docker-compose.yml .env manage.sh Dockerfile
```

### Data Recovery

#### Model Recovery
```bash
# Restore models from backup
tar -xzf models-backup-YYYYMMDD.tar.gz

# Import specific model
docker exec ollama-arc-optimized ollama import qwen25-backup.gguf qwen2.5:0.5b
```

#### Configuration Recovery
```bash
# Restore configuration
tar -xzf config-backup-YYYYMMDD.tar.gz

# Rebuild with restored config
docker compose down
docker compose build --no-cache
docker compose up -d
```

#### Disaster Recovery
```bash
# Complete system restore
# 1. Restore image
docker load < ollama-image-backup.tar.gz

# 2. Restore data
tar -xzf ollama-complete-backup-YYYYMMDD.tar.gz

# 3. Restart services
docker compose up -d

# 4. Verify restoration
./manage.sh health
```

---

## 🔍 Troubleshooting

### Common Issues & Solutions

#### GPU Not Detected
```bash
# Check GPU devices
ls -la /dev/dri/
lspci | grep -i intel

# Verify container GPU access
docker exec ollama-arc-optimized ls -la /dev/dri/

# Check Intel drivers
docker exec ollama-arc-optimized clinfo

# Solutions:
# 1. Install Intel GPU drivers on host
# 2. Add user to video/render groups
# 3. Restart Docker daemon
```

#### Container Startup Issues
```bash
# Check container logs
docker compose logs ollama-arc-optimized

# Common issues:
# - Port already in use: Change OLLAMA_PORT in .env
# - GPU access denied: Fix device permissions
# - Memory allocation: Reduce memory limits

# Debug container
docker run -it --entrypoint /bin/bash ollama-local-ollama-arc-optimized
```

#### Model Loading Failures
```bash
# Check available space
df -h data/models/

# Check model integrity
docker exec ollama-arc-optimized ollama list

# Re-download corrupted model
./manage.sh remove problematic-model
./manage.sh pull problematic-model
```

#### Performance Issues
```bash
# Check GPU utilization
./manage.sh gpu-monitor

# Check memory usage
docker stats ollama-arc-optimized

# Common solutions:
# 1. Reduce OLLAMA_GPU_LAYERS
# 2. Enable IPEX_LLM_LOW_MEM
# 3. Reduce context window size
# 4. Use smaller models
```

### Diagnostic Commands

#### System Diagnostics
```bash
# Complete system check
./manage.sh health

# GPU diagnostics
./manage.sh gpu-test

# Network connectivity
curl -f http://localhost:11434/api/tags
curl -f http://localhost:3000/health

# Resource availability
free -h
df -h
docker system df
```

#### Log Analysis
```bash
# Error detection
docker compose logs ollama-arc-optimized | grep -i error | tail -20

# GPU issues
docker compose logs ollama-arc-optimized | grep -i "gpu\|intel\|sycl" | tail -20

# Performance issues
docker compose logs ollama-arc-optimized | grep -i "slow\|timeout\|memory" | tail -20
```

### Emergency Recovery

#### Service Recovery
```bash
# Force restart all services
docker compose down --timeout 0
docker compose up -d --force-recreate

# Reset to known good state
git checkout HEAD -- docker-compose.yml .env
docker compose down
docker compose build --no-cache
docker compose up -d
```

#### Data Recovery
```bash
# Restore from last backup
./manage.sh restore latest-backup.tar.gz

# Reset to clean state (DESTRUCTIVE)
docker compose down -v
docker system prune -a
./manage.sh quick-start
```

---

## 🔬 Advanced Configuration

### Custom Model Development

#### Creating Custom Models
```bash
# Create Modelfile
cat > CustomModel << EOF
FROM llama2:7b
PARAMETER temperature 0.8
PARAMETER top_p 0.9
PARAMETER num_ctx 16384
SYSTEM You are an expert AI assistant specializing in technical documentation.
EOF

# Build custom model
docker exec ollama-arc-optimized ollama create tech-assistant -f CustomModel

# Test custom model
./manage.sh chat tech-assistant
```

#### Model Fine-tuning Preparation
```bash
# Export model for fine-tuning
docker exec ollama-arc-optimized ollama export llama2:7b > base-model.gguf

# Prepare training data
mkdir -p training-data/
echo "Your training data here" > training-data/dataset.jsonl
```

### Integration Development

#### API Integration
```python
# Python integration example
import requests
import json

class OllamaClient:
    def __init__(self, base_url="http://localhost:11434"):
        self.base_url = base_url
    
    def generate(self, model, prompt, stream=False):
        response = requests.post(
            f"{self.base_url}/api/generate",
            json={"model": model, "prompt": prompt, "stream": stream}
        )
        return response.json()
    
    def chat(self, model, messages):
        response = requests.post(
            f"{self.base_url}/api/chat",
            json={"model": model, "messages": messages}
        )
        return response.json()

# Usage
client = OllamaClient()
response = client.generate("qwen2.5:0.5b", "Hello!")
print(response['response'])
```

#### Webhook Integration
```bash
# Set up webhook for model completion
cat > webhook-handler.py << 'EOF'
from flask import Flask, request
import requests

app = Flask(__name__)

@app.route('/webhook', methods=['POST'])
def handle_webhook():
    data = request.json
    # Process completion webhook
    print(f"Model: {data['model']}, Response: {data['response']}")
    return "OK"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

python webhook-handler.py
```

### Multi-Instance Setup

#### Load Balancing
```yaml
# docker-compose-cluster.yml
version: '3.8'
services:
  ollama-1:
    extends:
      file: docker-compose.yml
      service: ollama-arc-optimized
    ports:
      - "11434:11434"
  
  ollama-2:
    extends:
      file: docker-compose.yml
      service: ollama-arc-optimized
    ports:
      - "11435:11434"
  
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
```

#### High Availability Setup
```bash
# Create HA configuration
cat > nginx.conf << 'EOF'
upstream ollama {
    server ollama-1:11434;
    server ollama-2:11434;
}

server {
    listen 80;
    location / {
        proxy_pass http://ollama;
        proxy_set_header Host $host;
    }
}
EOF

# Deploy HA setup
docker compose -f docker-compose-cluster.yml up -d
```

### Security Hardening

#### Container Security
```yaml
# Enhanced security configuration
security_opt:
  - no-new-privileges:true
  - seccomp:unconfined
read_only: true
tmpfs:
  - /tmp
  - /var/tmp
user: "1000:1000"
```

#### Network Security
```yaml
# Restricted network access
networks:
  ollama-internal:
    driver: bridge
    internal: true
  ollama-external:
    driver: bridge
```

#### Access Control
```bash
# Enable Web UI authentication
echo "WEBUI_AUTH=true" >> .env
echo "WEBUI_SECRET_KEY=$(openssl rand -hex 32)" >> .env

# Restart to apply
docker compose restart ollama-webui-enhanced
```

---

## 📞 Support & Resources

### Getting Help

#### Debug Information Collection
```bash
# Collect system information
./manage.sh health > debug-info.txt
docker compose logs > debug-logs.txt
docker version >> debug-info.txt
uname -a >> debug-info.txt

# Include in support request
tar -czf debug-package-$(date +%Y%m%d).tar.gz debug-info.txt debug-logs.txt
```

#### Performance Profiling
```bash
# CPU profiling
docker exec ollama-arc-optimized top -b -n 1 > cpu-profile.txt

# Memory profiling
docker exec ollama-arc-optimized cat /proc/meminfo > memory-profile.txt

# GPU profiling
./manage.sh gpu-monitor > gpu-profile.txt
```

### Best Practices

#### Production Deployment
1. **Resource Planning**: Allocate 2x model size in GPU memory
2. **Monitoring**: Set up automated health checks
3. **Backup Strategy**: Daily model backups, weekly full backups
4. **Security**: Enable authentication, use HTTPS
5. **Performance**: Monitor response times and resource usage

#### Development Workflow
1. **Testing**: Use small models for development
2. **Staging**: Test with production-size models
3. **Deployment**: Use automated deployment scripts
4. **Monitoring**: Implement comprehensive logging

---

**Operations Guide Complete** ✅  
**Last Updated**: July 30, 2025  
**Version**: 2.0  
**Status**: Production Ready