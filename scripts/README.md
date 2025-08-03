# Enhanced Scripts for Intel OneAPI + Ollama

This directory contains enhanced scripts to ensure proper Intel OneAPI environment sourcing for Ollama with Intel Arc GPU support.

## Scripts Overview

### 🔧 Setup Scripts

#### `host-oneapi-setup.sh`
**Purpose**: Comprehensive host-side Intel OneAPI setup and verification
- Checks Intel OneAPI installation on host
- Verifies GPU configuration and permissions
- Creates environment files for Docker
- Generates enhanced run script
- Provides troubleshooting guidance

**Usage**:
```bash
./scripts/host-oneapi-setup.sh
```

**What it does**:
- Verifies `/opt/intel/oneapi/` installation
- Sources OneAPI environment on host
- Checks GPU devices and permissions
- Creates `.env` file with Intel GPU variables
- Generates `run-ollama-enhanced.sh` script

---

### 🚀 Container Scripts

#### `enhanced-init-intel-gpu.sh`
**Purpose**: Comprehensive Intel GPU initialization inside container
- Enhanced OneAPI environment sourcing with multiple fallback methods
- Comprehensive environment variable setup
- Hardware verification and diagnostics
- Detailed logging and error handling

**Features**:
- Multiple OneAPI sourcing attempts
- SYCL cache setup and configuration
- Hardware detection and verification
- Environment persistence for other processes
- Comprehensive logging to `/tmp/intel-gpu-init.log`

#### `enhanced-start-ollama.sh`
**Purpose**: Enhanced Ollama startup with Intel OneAPI integration
- Forces OneAPI environment sourcing at startup
- Comprehensive pre-flight checks
- Enhanced error handling and diagnostics
- Performance optimization settings

**Features**:
- Multi-method OneAPI environment loading
- Python environment activation
- Comprehensive environment verification
- GPU access testing
- Detailed startup logging to `/tmp/ollama-startup.log`

---

### 🧪 Testing and Diagnostics

#### `test-setup.sh`
**Purpose**: Comprehensive test suite for verifying setup
- Tests host OneAPI installation
- Verifies Docker container configuration
- Checks Intel tools availability
- Tests Ollama API functionality
- Analyzes log files for errors

**Usage**:
```bash
./scripts/test-setup.sh
```

**Test Categories**:
- Host system tests (OneAPI, Docker, GPU)
- Container environment tests
- Intel tools availability
- SYCL device enumeration
- Ollama API functionality
- Performance monitoring
- Log analysis

---

## Quick Start Guide

### 1. Initial Setup
```bash
# Run comprehensive host setup
./scripts/host-oneapi-setup.sh

# Build Docker image with enhanced OneAPI support
docker build -t ollama-ubuntu:24.04 .
```

### 2. Start Ollama
```bash
# Option A: Use auto-generated enhanced script
./scripts/run-ollama-enhanced.sh

# Option B: Manual startup with OneAPI sourcing
source /opt/intel/oneapi/setvars.sh --force
./run-ollama.sh
```

### 3. Verify Setup
```bash
# Run comprehensive tests
./scripts/test-setup.sh

# Quick API test
curl http://localhost:11434/api/tags
```

## Troubleshooting Workflow

### If OneAPI Environment Issues:
1. Run `./scripts/host-oneapi-setup.sh`
2. Check OneAPI installation: `ls -la /opt/intel/oneapi/`
3. Test manual sourcing: `source /opt/intel/oneapi/setvars.sh --force`
4. Use enhanced container init: `docker exec -it ollama-arc /llm/scripts/enhanced-init-intel-gpu.sh`

### If GPU Access Issues:
1. Check devices: `ls -la /dev/dri/`
2. Check permissions: `groups` (should include 'render')
3. Add to render group: `sudo usermod -a -G render $USER`
4. Run container diagnostics: `docker exec -it ollama-arc /llm/bin/gpu-diagnostics`

### If Container Issues:
1. Check container status: `docker ps`
2. View logs: `docker logs ollama-arc`
3. Run test suite: `./scripts/test-setup.sh`
4. Check initialization logs: `docker exec ollama-arc cat /tmp/intel-gpu-init.log`

## Environment Files

### `.env` (Auto-generated)
Contains Intel GPU environment variables for Docker container:
- `INTEL_GPU=1`
- `OLLAMA_INTEL_GPU=true`
- `ZES_ENABLE_SYSMAN=1`
- `ONEAPI_DEVICE_SELECTOR=level_zero:0`
- `DEVICE=Arc`
- And more...

### Log Files (Container)
- `/tmp/intel-gpu-init.log` - GPU initialization details
- `/tmp/ollama-startup.log` - Ollama startup process
- `/tmp/oneapi_env_direct.txt` - OneAPI environment variables
- `/tmp/ollama_full_env.txt` - Complete environment dump

## Advanced Usage

### Manual OneAPI Sourcing
```bash
# On host before Docker run
source /opt/intel/oneapi/setvars.sh --force

# Inside container during runtime
docker exec ollama-arc bash -c "source /opt/intel/oneapi/setvars.sh --force && /llm/scripts/start-ollama.sh"
```

### Debug Mode
```bash
# Enable verbose logging
export OLLAMA_DEBUG=true
export OLLAMA_VERBOSE=true

# Run with debug output
docker run -e OLLAMA_DEBUG=true -e OLLAMA_VERBOSE=true ...
```

### Performance Monitoring
```bash
# GPU utilization
docker exec -it ollama-arc intel_gpu_top

# System resources
docker stats ollama-arc

# SYCL device info
docker exec ollama-arc sycl-ls
```

## Integration with Existing Scripts

These enhanced scripts work alongside your existing setup:

- `manage.sh` - Can call enhanced scripts for better OneAPI handling
- `run-ollama.sh` - Enhanced version auto-generated by host setup
- `gpu-config.sh` - Works with enhanced initialization
- `verify-gpu.sh` - Complemented by enhanced diagnostics

## Support

If you encounter issues:

1. **Run the test suite**: `./scripts/test-setup.sh`
2. **Check setup guide**: `ONEAPI_SETUP_GUIDE.md`
3. **Review logs**: Container logs in `/tmp/` directory
4. **Verify prerequisites**: OneAPI installed, GPU accessible, Docker running

The enhanced scripts provide comprehensive logging and multiple fallback methods to handle various Intel OneAPI configuration scenarios.