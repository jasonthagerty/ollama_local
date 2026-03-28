# Ollama Local — Operations Guide

Intel Arc A770 · SYCL/Level Zero backend · Ollama v0.18.3

## Quick Reference

```bash
./manage.sh quick-start        # Build + start + pull all required models
./manage.sh build              # Build ollama-arc-sycl:3.3.4-fixed image
./manage.sh start              # Start container
./manage.sh stop               # Stop container
./manage.sh restart            # Stop + start
./manage.sh status             # Container + API status
./manage.sh health             # Full health check

./manage.sh hardware-test      # Verify SYCL/Level Zero GPU detection
./manage.sh hardware-info      # Show GPU + CPU info

./manage.sh models             # List installed models
./manage.sh pull <model>       # Download a model
./manage.sh pull-models        # Pull llama3.1:8b, phi3:mini, qwen3:8b + create qwen3:8b-nothink
./manage.sh create-models      # Create custom Modelfile variants (qwen3:8b-nothink)
./manage.sh chat <model>       # Interactive chat session
./manage.sh benchmark          # Token/sec benchmark (uses llama3.1:8b)

./manage.sh logs [service]     # Stream logs
./manage.sh shell              # bash into container
./manage.sh update             # Pull latest image + rebuild + restart
./manage.sh cleanup            # Remove stopped containers + unused images
./manage.sh backup             # Backup config (excludes model weights)
```

API endpoint: `http://localhost:11434`

---

## First-Time Setup

```bash
# 1. Build the image (adds missing libsycl-native-bfloat16.spv to upstream build)
./manage.sh build

# 2. Start the container
./manage.sh start

# 3. Pull required models and create qwen3:8b-nothink
./manage.sh pull-models
```

Or as a single command:
```bash
./manage.sh quick-start
```

---

## Service Management

```bash
./manage.sh start              # Start (creates ./data/ if missing)
./manage.sh stop               # Stop gracefully
./manage.sh restart            # Rolling restart
./manage.sh status             # Quick container + API status
./manage.sh health             # Detailed health: Docker, container, API, disk
./manage.sh logs               # Follow all logs
./manage.sh logs ollama-arc-sycl  # Follow Ollama container logs only
./manage.sh shell              # Interactive bash in container
```

---

## Hardware Operations

### Verify GPU Access

```bash
./manage.sh hardware-test
```

Checks:
1. `/dev/dri/` device nodes visible in container
2. `sycl-ls` output — should show `Intel(R) Arc(TM) A770 Graphics`
3. Quick inference test on available model

### Show Hardware Info

```bash
./manage.sh hardware-info
```

Shows CPU, memory, disk, host DRI devices, and SYCL device list from inside the container.

### Manual GPU Check

```bash
docker exec ollama-arc-sycl sycl-ls
```

Expected output includes:
```
[opencl:gpu:0] Intel(R) OpenCL HD Graphics, Intel(R) Arc(TM) A770 Graphics ...
[level_zero:gpu:0] Intel(R) Level-Zero, Intel(R) Arc(TM) A770 Graphics ...
```

---

## Model Management

### Required Models

| Model | VRAM | Used By |
|-------|------|---------|
| `llama3.1:8b` | ~4.7GB | benchmarks |
| `phi3:mini` | ~2.3GB | legacy |
| `qwen3:8b` | ~4.9GB | base for qwen3:8b-nothink |
| `qwen3:8b-nothink` | ~4.9GB | ha_boss, opn_boss, general use |

```bash
./manage.sh pull-models        # Pull all + create qwen3:8b-nothink in one step
./manage.sh create-models      # Re-run Modelfile creation only (if models already pulled)
```

### Custom Models (Modelfiles)

`models/Modelfile.qwen3-8b-nothink` — derives from `qwen3:8b` with `PARAMETER think false`.

```bash
./manage.sh create-models      # Registers qwen3:8b-nothink from the Modelfile
```

To override thinking per-prompt:
```
/think      # Enable chain-of-thought for this prompt
/no_think   # Disable chain-of-thought for this prompt
```

### Chat

```bash
./manage.sh chat qwen3:8b-nothink    # Fast, no thinking tokens
./manage.sh chat qwen3:8b            # Full reasoning mode
./manage.sh chat llama3.1:8b         # Clean, non-reasoning
```

Or use the safe-chat script (retry logic, model validation, logging):
```bash
./scripts/safe-chat.sh                          # Default model
./scripts/safe-chat.sh qwen3:8b-nothink         # Specific model
./scripts/safe-chat.sh --list                   # List available models
./scripts/safe-chat.sh --check                  # Pre-flight checks only
```

### Benchmark

Uses `llama3.1:8b` (non-reasoning model for clean tok/s measurement):

```bash
./manage.sh benchmark
```

**Do not benchmark with `qwen3:8b`** — thinking tokens inflate elapsed time and skew results.

---

## Monitoring

```bash
./manage.sh logs -f                    # Follow all container logs
./scripts/monitor.sh                   # Continuous dashboard (5s refresh)
./scripts/monitor.sh --once            # Single snapshot
./scripts/monitor.sh --gpu             # GPU/SYCL status only
```

```bash
# Container resource usage
docker stats ollama-arc-sycl --no-stream

# Check SYCL kernel cache
ls -lh ~/.cache/opencl/  # host SYCL cache location
```

---

## Maintenance

### Update Image

```bash
./manage.sh update             # Pulls latest upstream + rebuilds sycl-fix layer + restarts
```

Or manually:
```bash
docker pull ollama-arc-sycl:3.3.4   # Pull new upstream if eleiton releases one
./manage.sh build                    # Rebuild fixed image
./manage.sh restart
```

### Cleanup

```bash
./manage.sh cleanup            # Remove project containers + prune unused images
```

### Backup

```bash
./manage.sh backup             # Backs up docker-compose.yml + .env (not model weights)
```

Model weights are stored at `MODELS_PATH=/gow/ai/ollama` and excluded from backup — re-pull with `./manage.sh pull-models`.

---

## Troubleshooting

### Container won't start

```bash
./manage.sh logs               # Check startup errors
docker inspect ollama-arc-sycl # Check device passthrough
ls -la /dev/dri/               # Verify host GPU devices exist
```

### API not responding after start

Normal if SYCL kernels are compiling on first model load — can take 2-5 minutes. Check logs:
```bash
./manage.sh logs | grep -i sycl
```

`SYCL_CACHE_PERSISTENT=1` caches compiled kernels so subsequent starts are fast.

### GPU not detected (CPU fallback)

```bash
docker exec ollama-arc-sycl sycl-ls   # Should list Arc A770
```

If empty:
- Verify `/dev/dri/card1` and `/dev/dri/renderD129` exist on host
- Check user is in `render` and `video` groups on host
- Try `./manage.sh build` to rebuild the fixed image

### Inference is very slow

Check if a reasoning model is running in thinking mode:
```bash
./manage.sh logs | grep "thinking"
```

Use `qwen3:8b-nothink` instead of `qwen3:8b` for normal tasks. Append `/no_think` to prompts as a per-request override.

### libsycl-native-bfloat16.spv error in logs

This is handled by `Dockerfile.sycl-fix` and `GGML_SYCL_F16=1`. If you see it after a fresh build:
```bash
./manage.sh build   # Rebuild to re-copy the SPV file from oneAPI basekit
```

---

## Configuration Reference

All settings in `.env`:

| Variable | Default | Description |
|----------|---------|-------------|
| `CONTAINER_NAME` | `ollama-arc-sycl` | Container name |
| `GPU_CARD_DEVICE` | `/dev/dri/card1` | Arc A770 card device |
| `GPU_RENDER_DEVICE` | `/dev/dri/renderD129` | Arc A770 render device |
| `MODELS_PATH` | `./data/models` | Model weight storage path |
| `OLLAMA_PORT` | `11434` | API port |
| `OLLAMA_CONTEXT_LENGTH` | `32768` | Context window (qwen3 supports 128k) |
| `OLLAMA_NUM_PARALLEL` | `2` | Concurrent request slots |
| `OLLAMA_MAX_LOADED_MODELS` | `3` | Models kept warm in VRAM |
| `OLLAMA_KV_CACHE_TYPE` | `q8_0` | KV cache quantization |
| `OLLAMA_KEEP_ALIVE` | `5m` | Unload idle models after |
| `OLLAMA_FLASH_ATTENTION` | `false` | Not supported by SYCL backend |
| `ONEAPI_DEVICE_SELECTOR` | `level_zero:0` | Pin to Arc A770 (GPU 0) |
| `SYCL_CACHE_PERSISTENT` | `1` | Cache compiled SYCL kernels |
| `GGML_SYCL_F16` | `1` | Force F16 (BF16 SPV workaround) |
