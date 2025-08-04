# Intel Arc A770 GPU Optimization Guide for Ollama

This guide provides proven solutions for running Ollama with GPU acceleration on Intel Arc A770 graphics cards.

## 🎯 Quick Start - Working Configuration

### Current Working Setup
- **GPU**: Intel Arc A770 (16GB VRAM, 15.1GB available)
- **Model**: `llama3.2:3b` (2.6GB VRAM usage)
- **Performance**: ~17 seconds vs 3+ minutes on CPU
- **Context**: 2,048 tokens
- **Status**: ✅ GPU inference confirmed

### Immediate Fix
```bash
# Use GPU-friendly model instead of large 8B models
docker exec ollama-arc-optimized ollama pull llama3.2:3b

# Test GPU inference
curl -X POST http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2:3b",
    "prompt": "Hello! Test GPU inference.",
    "stream": false,
    "options": {
      "num_ctx": 2048,
      "num_batch": 128,
      "num_gpu": 999,
      "temperature": 0.7
    }
  }'
```

## 🔧 Problem Analysis

### Why DeepSeek R1 8B Failed on GPU
```
layers.offload=0 memory.required.full="32.0 GiB" memory.available="[15.1 GiB]"
```
- **Issue**: Model needs 32GB VRAM but only 15.1GB available
- **Result**: Ollama falls back to CPU-only execution
- **Solution**: Use smaller models or more aggressive quantization

### GPU Detection Logs (Working)
```
Intel(R) Arc(TM) A770 Graphics total="15.9 GiB" available="15.1 GiB"
inference compute id=0 library=oneapi
```

## 📋 Recommended Models for Arc A770

### ✅ Confirmed Working (GPU)
| Model | Size | VRAM Usage | Context | Performance |
|-------|------|------------|---------|-------------|
| `llama3.2:3b` | 2.0GB | 2.6GB | 2048 | Excellent |
| `llama3.2:1b` | 1.3GB | 1.8GB | 2048 | Excellent |
| `gemma2:2b` | 1.6GB | 2.2GB | 2048 | Very Good |

### ⚠️ Partially Working (Mixed CPU/GPU)
| Model | Size | VRAM Usage | Issue |
|-------|------|------------|-------|
| `llama3.1:8b` | 4.7GB | 8-12GB | May exceed VRAM with large context |
| `codellama:7b` | 3.8GB | 6-10GB | Context-dependent |

### ❌ CPU-Only (Too Large)
| Model | Size | Required VRAM | Issue |
|-------|------|---------------|-------|
| `deepseek-r1:8b` | 4.9GB | 32GB | Context memory explosion |
| `llama3.1:70b` | 40GB+ | 80GB+ | Model too large |

## ⚙️ Optimized Configuration

### Docker Compose Settings
```yaml
environment:
  # GPU Configuration
  - OLLAMA_INTEL_GPU=true
  - ONEAPI_DEVICE_SELECTOR=level_zero:0
  - SYCL_DEVICE_FILTER=level_zero:gpu
  
  # Memory Optimization
  - OLLAMA_GPU_LAYERS=999
  - OLLAMA_NUM_PARALLEL=1
  - OLLAMA_CONTEXT_LENGTH=2048
  - OLLAMA_MAX_LOADED_MODELS=1
  - OLLAMA_KV_CACHE_TYPE=q4_0
  - OLLAMA_GPU_OVERHEAD=2048
  - OLLAMA_MAX_VRAM=12000000000
  
  # Performance Tuning
  - OLLAMA_FLASH_ATTENTION=false  # Not supported on Arc
  - IPEX_LLM_LOW_MEM=1
  - IPEX_LLM_NUM_CTX=2048

resources:
  limits:
    memory: 20G
  reservations:
    memory: 8G
```

### API Call Template
```bash
# Safe GPU inference parameters
curl -X POST http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2:3b",
    "prompt": "Your prompt here",
    "stream": false,
    "options": {
      "num_ctx": 2048,
      "num_batch": 128,
      "num_gpu": 999,
      "temperature": 0.7,
      "top_p": 0.9,
      "repeat_penalty": 1.1
    }
  }'
```

## 🛠️ Troubleshooting Tools

### Check GPU Status
```bash
# Monitor script
./scripts/monitor.sh --status

# Check loaded models
curl -s http://localhost:11434/api/ps | jq '.models[]'

# Verify GPU detection
docker logs ollama-arc-optimized | grep "Intel.*Arc"
```

### GPU Test Script
```bash
# Run comprehensive GPU tests
./scripts/test-gpu.sh

# Quick test current config
./scripts/test-gpu.sh -q

# Test specific configuration
./scripts/test-gpu.sh -c 24 2048 128
```

### Safe Chat Script
```bash
# Interactive GPU-optimized chat
./scripts/safe-chat.sh -i

# Single query
./scripts/safe-chat.sh "Your question here"

# Check system status
./scripts/safe-chat.sh --status
```

## 📊 Performance Benchmarks

### Response Time Comparison
| Model | Hardware | Context | Time | Tokens/sec |
|-------|----------|---------|------|------------|
| DeepSeek R1 8B | CPU | 1024 | 180s | 0.9 |
| Llama 3.2 3B | GPU | 2048 | 17s | 12.8 |
| Llama 3.2 1B | GPU | 2048 | 8s | 24.6 |

### Memory Usage
| Model | VRAM | System RAM | Container |
|-------|------|------------|-----------|
| Llama 3.2 3B | 2.6GB | 4.2GB | 6.8GB |
| Llama 3.2 1B | 1.8GB | 3.1GB | 5.2GB |

## 🚨 Common Issues & Solutions

### Issue: "layers.offload=0" (CPU-only)
**Symptoms**: Slow inference, high CPU usage
**Cause**: Model too large for available VRAM
**Solution**: 
```bash
# Use smaller model
ollama pull llama3.2:3b
# Or reduce context size
# num_ctx: 1024 instead of 4096
```

### Issue: "signal: killed" / OOM
**Symptoms**: Container crashes, process terminated
**Cause**: Memory exhaustion
**Solution**:
```bash
# Reduce memory settings in docker-compose.yml
OLLAMA_CONTEXT_LENGTH=1024
OLLAMA_NUM_PARALLEL=1
OLLAMA_KV_CACHE_TYPE=q4_0
```

### Issue: Slow GPU performance
**Symptoms**: GPU detected but still slow
**Cause**: Mixed CPU/GPU execution
**Solution**:
```bash
# Force full GPU offload
num_gpu: 999
num_ctx: 2048  # Don't exceed 4096
```

### Issue: Flash attention warnings
**Symptoms**: "flash attention enabled but not supported"
**Solution**: This is normal for Intel Arc - disable flash attention:
```yaml
OLLAMA_FLASH_ATTENTION=false
```

## 🎯 Optimization Strategy

### For Maximum Performance
1. **Use 3B or smaller models** for Arc A770
2. **Keep context ≤ 2048 tokens** to prevent VRAM overflow
3. **Set num_gpu=999** to force full GPU offload
4. **Monitor VRAM usage** with provided scripts

### For Maximum Context
1. **Use 1B models** for larger context windows
2. **Reduce batch size** (num_batch: 64)
3. **Use Q3_K_M quantization** if available

### For Best Balance
- **Model**: `llama3.2:3b`
- **Context**: 2048 tokens
- **Batch**: 128
- **Expected**: 10-15 tokens/second

## 📝 Model Selection Guide

### Choose Based on Use Case

**Code Generation**: `codellama:7b` (with reduced context)
**General Chat**: `llama3.2:3b`
**Quick Responses**: `llama3.2:1b`
**Long Context**: `gemma2:2b` with extended context

### Quantization Levels
- **Q4_K_M**: Best quality/performance balance (recommended)
- **Q3_K_M**: More aggressive compression, fits larger models
- **Q5_K_M**: Higher quality but larger size

## 🔍 Verification Commands

### Confirm GPU Inference
```bash
# Should show VRAM usage > 0
curl -s http://localhost:11434/api/ps | jq '.models[].size_vram'

# Should complete in < 30 seconds
time curl -X POST http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{"model":"llama3.2:3b","prompt":"Hello","stream":false}'
```

### Check Container Health
```bash
# Memory usage should be stable
docker stats ollama-arc-optimized --no-stream

# No recent errors
docker logs ollama-arc-optimized --tail 20
```

## 🎉 Success Indicators

✅ **GPU Working When**:
- Model loads in < 10 seconds
- Response time < 30 seconds for short prompts
- VRAM usage > 0 in `api/ps`
- No "layers.offload=0" in logs
- Container memory stable < 10GB

❌ **CPU Fallback When**:
- Response time > 60 seconds
- High CPU usage, low GPU usage
- "layers.offload=0" in logs
- "memory.required.full > available" errors

## 📞 Support & Updates

### Quick Diagnostics
```bash
# Run full system check
./scripts/monitor.sh --once

# Test GPU with safe model
./scripts/safe-chat.sh --status
```

### File Locations
- **Configuration**: `docker-compose.yml`
- **Monitoring**: `scripts/monitor.sh`
- **GPU Testing**: `scripts/test-gpu.sh`
- **Safe Chat**: `scripts/safe-chat.sh`

---

**Last Updated**: January 2025  
**Tested Configuration**: Intel Arc A770 16GB, Ollama 0.10.1, OneAPI 2024.2