# scripts/

Utility scripts for monitoring and interacting with the Ollama container.

## monitor.sh

Real-time monitoring dashboard for the Ollama container.

```bash
./scripts/monitor.sh              # Continuous refresh (5s interval)
./scripts/monitor.sh --once       # Single snapshot and exit
./scripts/monitor.sh --gpu        # GPU/SYCL status only
./scripts/monitor.sh --interval 10 # Custom refresh interval
```

**Options:**
- `-o, --once` — run once and exit
- `-s, --status` — detailed status
- `-m, --memory` — memory usage only
- `-l, --logs` — recent container logs
- `-e, --errors` — scan logs for errors
- `--gpu` — SYCL/GPU device status
- `-i, --interval SEC` — refresh interval (default: 5s)

Logs to `logs/monitor.log`.

## safe-chat.sh

Interactive chat with retry logic, model validation, and session logging.

```bash
./scripts/safe-chat.sh                      # Chat with default model
./scripts/safe-chat.sh qwen3:8b-nothink     # Specific model
./scripts/safe-chat.sh --list               # List available models
./scripts/safe-chat.sh --check              # Pre-flight checks only
./scripts/safe-chat.sh -m llama3.1:8b       # -m flag
```

**Options:**
- `-h, --help` — show help
- `-l, --list` — list models
- `-c, --check` — pre-flight checks only
- `-m, --model MODEL` — specify model
- `-v, --verbose` — verbose logging

**In-session commands:** `help`, `models`, `switch`, `status`, `clear`, `quit`

Logs to `logs/chat-YYYYMMDD.log`.

## Configuration

Both scripts source `../.env` automatically for `CONTAINER_NAME` and other settings. Default container name: `ollama-arc-sycl`.
