# Intel Arc GPU Monitoring for Ollama

This document describes the GPU monitoring tools available in the Ollama Intel Arc setup.

## Overview

The custom Docker image now includes `intel_gpu_top` and additional GPU monitoring utilities specifically designed for Intel Arc GPUs. These tools help you monitor GPU utilization, memory usage, and performance while running AI models.

## Available GPU Monitoring Tools

### 1. `gpu-monitor` - Real-time GPU Monitoring
Interactive real-time monitoring with continuous updates.

```bash
# From host (using manage script)
./manage.sh gpu-monitor

# Direct container access
docker exec -it ollama-server-blackbox gpu-monitor
```

**Features:**
- Real-time GPU utilization
- Memory usage tracking
- Render engine activity
- Video engine usage
- Continuous updates every second

### 2. `gpu-stats` - Quick GPU Status
Get a quick snapshot of current GPU status and system information.

```bash
# From container shell
docker exec -it ollama-server-blackbox gpu-stats
```

**Output includes:**
- GPU device information
- Current utilization (5-second sample)
- System memory usage
- System load average

### 3. `gpu-health` - GPU Health Check
Comprehensive diagnostic tool to verify GPU setup and accessibility.

```bash
# From container shell
docker exec -it ollama-server-blackbox gpu-health
```

**Checks:**
- ✅ GPU devices presence in `/dev/dri`
- ✅ Intel GPU detection in PCI devices
- ✅ `intel_gpu_top` functionality
- ✅ Environment variables setup
- ❌ Reports any issues found

### 4. `intel_gpu_top` - Direct Intel GPU Top
Direct access to the Intel GPU monitoring utility.

```bash
# From container shell
docker exec -it ollama-server-blackbox intel_gpu_top

# With custom refresh rate (milliseconds)
docker exec -it ollama-server-blackbox intel_gpu_top -s 500
```

## Management Script Integration

The `manage.sh` script now includes GPU monitoring commands:

```bash
# Show comprehensive GPU information
./manage.sh gpu

# Start real-time monitoring
./manage.sh gpu-monitor

# Open container shell for manual monitoring
./manage.sh shell
```

## GPU Metrics Explained

### Key Metrics to Watch

1. **Render/3D Engine**: Shows GPU utilization for compute tasks (AI inference)
2. **Video Engine**: Video encoding/decoding activity
3. **Memory Usage**: GPU memory consumption
4. **Power Usage**: Current power draw (if available)
5. **Temperature**: GPU temperature (if available)

### Example Output
```
┌─────────────────────────────────────────────────────────────────────────┐
│ Intel GPU TOP - Intel(R) Arc(TM) A770 Graphics                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│    Render/3D      [████████████████████████████████████████] 95.2%     │
│    Copy           [█                                       ]  2.1%     │
│    Video          [                                        ]  0.0%     │
│    VideoEnhance   [                                        ]  0.0%     │
│                                                             12.8G/16G   │
└─────────────────────────────────────────────────────────────────────────┘
```

## Troubleshooting

### Common Issues

1. **"intel_gpu_top not accessible"**
   - Check if container has GPU device access: `ls -la /dev/dri/`
   - Verify Intel GPU is detected: `lspci | grep -i intel`
   - Ensure proper environment variables are set

2. **"No GPU devices found"**
   - Check host GPU devices: `ls -la /dev/dri/`
   - Verify Docker compose has device mapping: `/dev/dri:/dev/dri`
   - Check if Intel GPU drivers are installed on host

3. **"Permission denied"**
   - Ensure user is in `video` and `render` groups
   - Check device permissions in `/dev/dri/`

### Debug Commands

```bash
# Check GPU device permissions
docker exec ollama-server-blackbox ls -la /dev/dri/

# Verify Intel GPU detection
docker exec ollama-server-blackbox lspci | grep -i intel

# Check environment variables
docker exec ollama-server-blackbox env | grep -E "(ZES_|ONEAPI_|SYCL_)"

# Test basic GPU functionality
docker exec ollama-server-blackbox gpu-health
```

## Performance Monitoring During Inference

### Monitor Model Loading
```bash
# Terminal 1: Start monitoring
./manage.sh gpu-monitor

# Terminal 2: Load a model
./manage.sh pull deepseek-r1:14b
```

### Monitor During Chat/Inference
```bash
# Terminal 1: Start monitoring
docker exec -it ollama-server-blackbox gpu-monitor

# Terminal 2: Run inference
./manage.sh chat deepseek-r1:14b
```

## Environment Variables

Key environment variables for GPU monitoring:

```bash
# Enable system management interface
ZES_ENABLE_SYSMAN=1

# Enable PCI device ordering
ZE_ENABLE_PCI_ID_DEVICE_ORDER=1

# OneAPI device selector
ONEAPI_DEVICE_SELECTOR=level_zero:0

# Device type
DEVICE=Arc
```

## Building the Custom Image

The custom Docker image is built automatically when using:

```bash
./manage.sh build
```

Or manually:
```bash
docker compose build --no-cache
```

## Tips for Optimal Monitoring

1. **Use tmux/screen** for persistent monitoring sessions
2. **Monitor during model loading** to see peak memory usage
3. **Check temperature** during long inference sessions
4. **Compare utilization** between different model sizes
5. **Monitor memory fragmentation** after multiple model loads

## Integration with System Monitoring

Combine with system monitoring tools:

```bash
# Monitor GPU + system resources
docker exec -it ollama-server-blackbox bash -c "
  gpu-monitor &
  htop &
  wait
"
```

## Alerts and Automation

Example script for automated monitoring:

```bash
#!/bin/bash
# Monitor GPU usage and alert on high utilization
while true; do
    usage=$(docker exec ollama-server-blackbox intel_gpu_top -s 1000 -c 1 2>/dev/null | grep "Render/3D" | grep -o "[0-9.]*%" | head -1)
    if [[ ${usage%.*} -gt 90 ]]; then
        echo "HIGH GPU USAGE: $usage"
    fi
    sleep 10
done
```
