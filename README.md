# ollama-local

Containerized local LLM inference via [Ollama](https://ollama.com/) with Intel Arc A770 GPU acceleration (Level Zero / SYCL backend).

## Stack

- **Ollama API** — port 11434, SYCL-accelerated inference on Arc A770 16GB
- **Image** — local build extending [eleiton/ollama-intel-arc](https://github.com/eleiton/ollama-intel-arc) (`ollama-arc-sycl:3.3.4`, Ollama v0.18.3)

## Quick Start

```bash
# First time
./manage.sh build          # build ollama-arc-sycl:3.3.4-fixed
./manage.sh start
./manage.sh pull-models    # pulls llama3.1:8b, phi3:mini, qwen3:8b + creates qwen3:8b-nothink

# Or all in one
./manage.sh quick-start
```

## Common Commands

```bash
./manage.sh start              # Start container
./manage.sh stop               # Stop container
./manage.sh status             # Container + API status
./manage.sh health             # Full health check
./manage.sh logs               # Stream logs
./manage.sh shell              # bash into container

./manage.sh pull <model>       # Download a model
./manage.sh pull-models        # Pull required models + create custom variants
./manage.sh create-models      # Create Modelfile variants (qwen3:8b-nothink)
./manage.sh models             # List installed models
./manage.sh chat <model>       # Interactive chat
./manage.sh benchmark          # Token/sec test (uses llama3.1:8b)

./manage.sh hardware-test      # Verify SYCL/Level Zero GPU detection
./manage.sh hardware-info      # Show GPU + CPU info
```

## Models

| Model | VRAM | Notes |
|-------|------|-------|
| `qwen3:8b-nothink` | ~4.9GB | Recommended — thinking disabled, ~16 tok/s |
| `qwen3:8b` | ~4.9GB | Reasoning mode — ~8 tok/s visible |
| `llama3.1:8b` | ~4.7GB | Clean, non-reasoning, good for benchmarks |
| `phi3:mini` | ~2.3GB | Lightweight |

`qwen3:8b-nothink` is created automatically by `./manage.sh pull-models` from `models/Modelfile.qwen3-8b-nothink`. Per-prompt override: append `/think` or `/no_think`.

## Configuration

Copy `.env.template` to `.env` and adjust as needed. Key settings:

```bash
MODELS_PATH=/gow/ai/ollama        # model weight storage (NVMe)
GPU_CARD_DEVICE=/dev/dri/card1    # Arc A770
GPU_RENDER_DEVICE=/dev/dri/renderD129
OLLAMA_CONTEXT_LENGTH=32768
OLLAMA_MAX_LOADED_MODELS=3
```

See [OPERATIONS.md](OPERATIONS.md) for full reference.

## Architecture

The base image (`ollama-arc-sycl:3.3.4`) must be built locally from [eleiton/ollama-intel-arc](https://github.com/eleiton/ollama-intel-arc). `Dockerfile.sycl-fix` extends it to add `libsycl-native-bfloat16.spv`, which is required for inference but missing from the upstream build.

```
Dockerfile.sycl-fix
  FROM intel/oneapi-basekit:2025.2.2  ← copies missing SPV file
  FROM ollama-arc-sycl:3.3.4          ← eleiton build (Ollama v0.18.3 + SYCL ggml)
  → ollama-arc-sycl:3.3.4-fixed
```

## Downstream Projects

- **ha_boss** — Home Assistant automation agent (`http://localhost:11434`, model: `qwen3:8b-nothink`)
- **opn_boss** — OPNsense firewall analysis agent (`http://localhost:11434`, model: `qwen3:8b-nothink`)
