# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Does

Containerized local LLM inference via [Ollama](https://ollama.com/) with Intel Arc A770 GPU acceleration. The stack is a single service:

- **Ollama API** (port 11434) — LLM inference using a local SYCL build (`ollama-arc-sycl:3.3.4-fixed`)

### Why This Exists

Two downstream projects depend on this:
- **ha_boss** (`/home/jason/Projects/ha_boss`) — uses `qwen3:8b-nothink`, calls `POST /api/generate` at `http://localhost:11434`
- **opn_boss** (`/home/jason/Projects/opn_boss`) — uses `qwen3:8b-nothink`, calls `POST /api/generate` at `http://localhost:11434`

## Common Commands

All lifecycle operations go through `manage.sh`:

```bash
./manage.sh start              # Start all services (creates data/ dirs if missing)
./manage.sh stop               # Stop all services
./manage.sh status             # Show container + API status
./manage.sh health             # Full health check
./manage.sh logs [service]     # Stream logs (omit service for all)
./manage.sh shell              # bash into the Ollama container

./manage.sh pull <model>       # Download a model
./manage.sh pull-models        # Pull llama3.1:8b, phi3:mini, qwen3:8b + create qwen3:8b-nothink
./manage.sh create-models      # Create custom models from Modelfiles (standalone)
./manage.sh models             # List installed models
./manage.sh chat <model>       # Interactive chat
./manage.sh benchmark          # Token/sec test with llama3.1:8b

./manage.sh hardware-test      # Verify Intel Arc GPU device access via SYCL
./manage.sh hardware-info      # Show GPU/CPU info
```

First-time setup:
```bash
./manage.sh build          # build ollama-arc-sycl:3.3.4-fixed from Dockerfile.sycl-fix
./manage.sh start
./manage.sh pull-models
```

## Architecture

### Image Strategy

The base image is built by [eleiton/ollama-intel-arc](https://github.com/eleiton/ollama-intel-arc) (`ollama-arc-sycl:3.3.4`, Ollama v0.18.3) using Intel oneAPI 2025.2.2 and the ggml SYCL backend. This provides GPU acceleration via **Level Zero / SYCL** on Intel Arc GPUs.

`Dockerfile.sycl-fix` extends that image to add `libsycl-native-bfloat16.spv`, which is required for inference but missing from the upstream build. `GGML_SYCL_F16=1` is set as an env var to force F16 (instead of BF16) as an additional fallback.

**Note**: IPEX-LLM (`intelanalytics/ipex-llm-inference-cpp-xpu`) was the previous base image but was archived January 28, 2026. It is no longer used. OpenVINO is a separate Intel framework that Ollama does not use — any historical `OV_*` references in this repo are stale.

### Container Strategy

```
docker-compose.yml
└── ollama-arc-sycl   ← build: Dockerfile.sycl-fix, image: ollama-arc-sycl:3.3.4-fixed
```

The service name and container name are both `ollama-arc-sycl` (overridable via `CONTAINER_NAME` in `.env`).

### Volume Layout

| Host Path | Container Path | Purpose |
|-----------|----------------|---------|
| `${MODELS_PATH:-./data/models}` | `/root/.ollama` | Model weights |

`MODELS_PATH=/gow/ai/ollama` in `.env` — points to NVMe storage for low-latency model reads.

### Configuration

All tunables live in `.env`. Key groups:
- **GPU device paths**: `GPU_CARD_DEVICE=/dev/dri/card1`, `GPU_RENDER_DEVICE=/dev/dri/renderD129` (Arc A770)
- **Level Zero / SYCL settings**: `ZES_ENABLE_SYSMAN=1`, `ONEAPI_DEVICE_SELECTOR=level_zero:0`, `SYCL_CACHE_PERSISTENT=1`
- **SYCL workarounds**: `GGML_SYCL_F16=1` (force F16, avoids missing BF16 SPV), `OLLAMA_FLASH_ATTENTION=false` (SYCL backend doesn't support it)
- **Ollama performance**: `OLLAMA_CONTEXT_LENGTH=32768`, `OLLAMA_NUM_PARALLEL=2`, `OLLAMA_KV_CACHE_TYPE=q8_0`, `OLLAMA_MAX_LOADED_MODELS=3`

### Startup Sequence

The container runs `ollama serve` directly. GPU is exposed via device passthrough (`/dev/dri/card1` and `/dev/dri/renderD129`). The container runs as root; `shm_size: 16g` is required for Level Zero access.

On first use of a model, SYCL kernels are compiled and cached (controlled by `SYCL_CACHE_PERSISTENT=1`). This causes an apparent hang of several minutes — it's normal.

## Models

| Model | VRAM | Purpose | Notes |
|-------|------|---------|-------|
| `llama3.1:8b` | ~4.7GB | benchmarks | ~16 tok/s, clean output |
| `phi3:mini` | ~2.3GB | legacy opn_boss | being phased out |
| `qwen3:8b` | ~4.9GB | reasoning tasks | generates thinking tokens; ~8 tok/s visible |
| `qwen3:8b-nothink` | ~4.9GB | ha_boss, opn_boss, general | thinking disabled; ~16 tok/s |

`qwen3:8b-nothink` is a custom model created from `models/Modelfile.qwen3-8b-nothink` via `./manage.sh create-models`. It sets `PARAMETER think false` — per-prompt override with `/think` or `/no_think` still works.

**qwen3.5:9b is not compatible** with the current SYCL backend (multimodal ops unsupported — tracked in jasonthagerty/ollama_local#19).

## GPU Notes

The Arc A770 has 16GB VRAM. Three 8b-class models fit simultaneously:
- `llama3.1:8b` (~4.7GB) + `qwen3:8b-nothink` (~4.9GB) + `phi3:mini` (~2.3GB) = ~11.9GB

`OLLAMA_MAX_LOADED_MODELS=3` keeps all three warm.
