# Intel OneAPI + Ollama Setup Guide

This guide will help you properly configure Intel OneAPI environment for Ollama with Intel Arc GPU support.

## Overview

The issue you encountered requires sourcing Intel OneAPI environment variables before starting Ollama. This guide provides multiple approaches to ensure proper setup.

## Prerequisites

- Intel Arc GPU (A770 confirmed working)
- Ubuntu 24.04 or compatible Linux distribution
- Docker installed and configured
- Intel OneAPI toolkit installed (on host system)

## Quick Start

### Option 1: Enhanced Automated Setup (Recommended)

```bash
# Run the host-side OneAPI setup script
./scripts/host-oneapi-setup.sh

# Build the Docker image with enhanced OneAPI support
docker build -t ollama-ubuntu:24.04 .

# Run with the enhanced script (automatically handles OneAPI sourcing)
./scripts/run-ollama-enhanced.sh
```

### Option 2: Manual Host OneAPI Setup

```bash
# Source Intel OneAPI environment on host first
source /opt/intel/oneapi/setvars.sh --force

# Then start your existing Docker container
./run-ollama.sh
```

### Option 3: Direct Container Enhancement

```bash
# Use the enhanced startup script in container
docker exec -it ollama-arc /llm/scripts/enhanced-start-ollama.sh
```

## Detailed Setup Steps

### Step 1: Install Intel OneAPI on Host (if not already installed)

```bash
# Add Intel repository
wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | gpg --dearmor | sudo tee /usr/share/keyrings/oneapi-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | sudo tee /etc/apt/sources.list.d/oneAPI.list

# Update and install
sudo apt update
sudo apt install intel-oneapi-toolkit
```

### Step 2: Verify Host OneAPI Installation

```bash
# Check if OneAPI is properly installed
ls -la /opt/intel/oneapi/

# Test sourcing (should run without errors)
source /opt/intel/oneapi/setvars.sh --force

# Verify environment variables are set
env | grep -E "(ONEAPI|INTEL|SYCL)" | head -5
```

### Step 3: Verify GPU Setup

```bash
# Check GPU devices
ls -la /dev/dri/

# Check Intel GPU hardware
lspci | grep -i "vga\|3d\|display" | grep -i intel

# Test GPU tools (if available)
clinfo -l
intel_gpu_top --help
```

### Step 4: Build Enhanced Docker Image

The updated Dockerfile now includes:
- Enhanced OneAPI environment sourcing
- Multiple fallback methods for OneAPI setup
- Better error handling and logging
- Persistent environment variable export

```bash
# Build with enhanced OneAPI support
docker build -t ollama-ubuntu:24.04 .
```

### Step 5: Run with Enhanced Startup

```bash
# Option A: Use the automated script
./scripts/run-ollama-enhanced.sh

# Option B: Manual run with environment sourcing
source /opt/intel/oneapi/setvars.sh --force
docker run -d \
  --name ollama-arc \
  --device=/dev/dri/card1:/dev/dri/card1 \
  --device=/dev/dri/renderD129:/dev/dri/renderD129 \
  --env-file .env \
  -e OLLAMA_GPU_LAYERS=999 \
  -p 11434:11434 \
  -v ollama_data:/root/.ollama \
  ollama-ubuntu:24.04
```

## Troubleshooting

### Common Issues and Solutions

#### 1. OneAPI Environment Not Persisting

**Problem**: OneAPI variables are not available in the container

**Solution**: 
```bash
# Ensure host OneAPI is sourced first
source /opt/intel/oneapi/setvars.sh --force

# Or use the enhanced container initialization
docker exec -it ollama-arc /llm/scripts/enhanced-init-intel-gpu.sh
```

#### 2. GPU Device Not Accessible

**Problem**: `/dev/dri/renderD129` not found or no permissions

**Solution**:
```bash
# Check available GPU devices
ls -la /dev/dri/

# Add user to render group
sudo usermod -a -G render $USER

# Update Docker run command with correct device
# Replace renderD129 with your actual device
```

#### 3. SYCL Runtime Issues

**Problem**: SYCL enumeration fails or tools not available

**Solution**:
```bash
# Test SYCL tools in container
docker exec -it ollama-arc sycl-ls

# Check SYCL cache directory
docker exec -it ollama-arc ls -la /tmp/sycl_cache/

# Verify SYCL environment variables
docker exec -it ollama-arc env | grep SYCL
```

### Debugging Commands

#### Check Container Environment
```bash
# View all Intel-related environment variables
docker exec -it ollama-arc env | grep -E "(INTEL|ONEAPI|SYCL|ZE_)"

# Check GPU initialization logs
docker exec -it ollama-arc cat /tmp/intel-gpu-init.log

# Run full diagnostics
docker exec -it ollama-arc /llm/bin/gpu-diagnostics
```

#### Monitor Container Startup
```bash
# Watch container logs during startup
docker logs -f ollama-arc

# Check startup script logs
docker exec -it ollama-arc cat /tmp/ollama-startup.log
```

#### Test GPU Functionality
```bash
# Run Intel version checker
docker exec -it ollama-arc /llm/bin/intel-versions

# Test SYCL devices
docker exec -it ollama-arc timeout 10s sycl-ls

# Check OpenCL platforms
docker exec -it ollama-arc clinfo -l
```

## Scripts Overview

### Enhanced Scripts Added

1. **`scripts/host-oneapi-setup.sh`**
   - Verifies host OneAPI installation
   - Checks GPU configuration
   - Creates environment files
   - Generates enhanced run script

2. **`scripts/enhanced-init-intel-gpu.sh`**
   - Comprehensive Intel GPU initialization
   - Enhanced error handling and logging
   - Multiple fallback methods
   - Detailed verification steps

3. **`scripts/enhanced-start-ollama.sh`**
   - Enhanced Ollama startup with OneAPI sourcing
   - Pre-flight checks
   - Comprehensive environment verification
   - Detailed error reporting

4. **`scripts/run-ollama-enhanced.sh`** (auto-generated)
   - Host-side OneAPI sourcing
   - Enhanced Docker run with environment
   - Container status monitoring

## Environment Variables

### Critical OneAPI Variables
```bash
ONEAPI_DEVICE_SELECTOR=level_zero:0
SYCL_DEVICE_FILTER=level_zero:gpu
ZES_ENABLE_SYSMAN=1
ZE_ENABLE_PCI_ID_DEVICE_ORDER=1
```

### Intel Arc GPU Optimizations
```bash
DEVICE=Arc
INTEL_DEVICE_TARGET=arc
ZE_FLAT_DEVICE_HIERARCHY=COMPOSITE
NEO_DISABLE_MITIGATIONS=1
SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS=1
```

### Ollama-Specific Settings
```bash
OLLAMA_INTEL_GPU=true
OLLAMA_GPU_DEVICE=/dev/dri/renderD129
OLLAMA_GPU_LAYERS=999
DRI_PRIME=1
```

## Verification Steps

### After Successful Setup

1. **Check Ollama API**
   ```bash
   curl http://localhost:11434/api/tags
   ```

2. **Test Model Loading**
   ```bash
   curl http://localhost:11434/api/generate -d '{
     "model": "llama3.2:1b",
     "prompt": "Hello, world!",
     "stream": false
   }'
   ```

3. **Monitor GPU Usage**
   ```bash
   docker exec -it ollama-arc intel_gpu_top
   ```

## Performance Tips

### Optimal Settings for Arc A770

```bash
export OLLAMA_NUM_PARALLEL=2
export OLLAMA_MAX_LOADED_MODELS=1
export IPEX_LLM_NUM_CTX=16384
export IPEX_LLM_LOW_MEM=1
export SYCL_CACHE_PERSISTENT=1
```

### Memory Optimization
- Use `IPEX_LLM_LOW_MEM=1` for memory-constrained environments
- Set `OLLAMA_KEEP_ALIVE=5m` to free memory when idle
- Consider `OLLAMA_GPU_SPLIT` for multi-GPU setups

## Support and Resources

### Log Files to Check
- `/tmp/intel-gpu-init.log` - GPU initialization
- `/tmp/ollama-startup.log` - Ollama startup process
- `/tmp/oneapi_env_direct.txt` - OneAPI environment variables

### Useful Commands
```bash
# Container shell access
docker exec -it ollama-arc bash

# Real-time logs
docker logs -f ollama-arc

# GPU diagnostics
docker exec -it ollama-arc /llm/bin/gpu-diagnostics

# Environment verification
docker exec -it ollama-arc /llm/bin/intel-versions
```

### Getting Help

If you encounter issues:

1. Run the host setup script: `./scripts/host-oneapi-setup.sh`
2. Check the generated logs in `/tmp/`
3. Verify GPU devices and permissions
4. Ensure OneAPI is properly installed on the host
5. Try the enhanced startup scripts

The enhanced setup provides multiple fallback methods and comprehensive logging to help identify and resolve configuration issues.