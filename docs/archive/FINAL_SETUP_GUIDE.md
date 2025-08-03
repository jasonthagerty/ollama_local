# Ollama Intel Arc GPU + Chat Context - Final Setup Guide

This comprehensive guide covers both GPU acceleration fixes and chat context storage for your Ollama Intel Arc A770 setup.

## 🚀 Quick Summary - What We Fixed

### GPU Acceleration Issue Resolution
The core problem was that Ollama was loading models into VRAM but falling back to CPU for inference. This was fixed by:

1. **Corrected Intel OneAPI environment sourcing**
2. **Fixed SYCL device selector for Intel Arc A770** 
3. **Enhanced container startup scripts**
4. **Proper environment variable persistence**

### Chat Context Storage Solutions
Multiple options provided for storing and managing conversation history:
- Built-in Ollama session management
- SQLite database with full conversation history
- File-based JSON storage
- Open WebUI integration (already running)

---

## 🔧 GPU Acceleration - Status & Testing

### Current Status
✅ **Fixed!** Your GPU acceleration has been optimized with these corrections:

```bash
# Key fixes applied:
ONEAPI_DEVICE_SELECTOR=level_zero:1  # Intel Arc A770 is device 1, not 0
Intel OneAPI environment properly sourced at startup
Enhanced error handling and fallback methods
Optimized Arc GPU environment variables
```

### Verify GPU Acceleration is Working

**Quick Test:**
```bash
# 1. Test GPU acceleration performance
./scripts/simple-chat.sh test-gpu

# 2. Monitor GPU usage during inference
./scripts/monitor-gpu.sh

# 3. Check container environment
docker exec ollama-arc-server env | grep -E "(INTEL|GPU|SYCL)"
```

**Expected Results for Working GPU Acceleration:**
- Token generation: **>20 tokens/sec**
- CPU usage during inference: **<50%**
- GPU memory usage visible in `intel_gpu_top`
- Fast response times

**If Still Having Issues:**
```bash
# Re-run the GPU acceleration fix
./scripts/fix-gpu-acceleration.sh

# Check Ollama logs for GPU detection
docker logs ollama-arc-server | grep -i "gpu\|intel\|arc"
```

---

## 💬 Chat Context Storage Solutions

### Option 1: Open WebUI (Recommended - Already Working!)

**Your Open WebUI is running at:** http://localhost:3000

**Features:**
- ✅ Automatic conversation history
- ✅ Multiple chat sessions
- ✅ Export/import capabilities
- ✅ User-friendly interface
- ✅ No additional setup required

**Access:** Simply use the web interface for persistent chat history.

### Option 2: Advanced Chat Context Manager

**Initialize the system:**
```bash
# Set up comprehensive chat context management
./scripts/chat-context-manager.sh init
```

**Create and use chat sessions:**
```bash
# Create new conversation session
SESSION_ID=$(./scripts/chat-context-manager.sh create-session "My Research Chat" "AI research discussion" "deepseek-r1:8b")

# Interactive chat with full context
./scripts/chat-context-manager.sh interactive $SESSION_ID

# Send single message with context
./scripts/chat-context-manager.sh chat $SESSION_ID "Explain quantum computing"

# List all sessions
./scripts/chat-context-manager.sh list-sessions

# Search conversations
./scripts/chat-context-manager.sh search "machine learning"

# Export session
./scripts/chat-context-manager.sh export-session $SESSION_ID md
```

### Option 3: Simple Chat with Basic Context

**For quick testing and simple conversations:**
```bash
# Interactive chat with context (no persistence)
./scripts/simple-chat.sh chat

# Monitor GPU usage while chatting
./scripts/simple-chat.sh monitor-chat

# Send single message
./scripts/simple-chat.sh send "Hello, how are you?"
```

### Option 4: Direct Ollama API with Context

**Manual conversation management:**
```bash
# Start conversation
curl -X POST http://localhost:11434/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-r1:8b",
    "messages": [
      {"role": "user", "content": "Hello, my name is John"}
    ]
  }'

# Continue conversation (include previous messages)
curl -X POST http://localhost:11434/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-r1:8b",
    "messages": [
      {"role": "user", "content": "Hello, my name is John"},
      {"role": "assistant", "content": "Hello John! Nice to meet you."},
      {"role": "user", "content": "What is my name?"}
    ]
  }'
```

---

## 📊 Performance Monitoring

### GPU Usage Monitoring
```bash
# Real-time GPU monitoring
./scripts/monitor-gpu.sh

# Container resource usage
docker stats ollama-arc-server

# Check Intel GPU tools
docker exec ollama-arc-server intel_gpu_top
docker exec ollama-arc-server sycl-ls
```

### Performance Benchmarks
```bash
# Run comprehensive GPU test
./scripts/simple-chat.sh test-gpu

# Check system diagnostics
./scripts/diagnose-gpu-acceleration.sh

# Test setup validation
./scripts/test-setup.sh
```

---

## 🗂️ File Organization

Your chat context data is organized in:

```
Projects/ollama-local/data/
├── contexts/           # JSON session files
├── conversations.db    # SQLite database
├── backups/           # Database backups
├── exports/           # Exported conversations
├── sessions/          # Session metadata
└── templates/         # Chat templates
```

### Backup & Export

**Backup conversations:**
```bash
# Backup database
./scripts/chat-context-manager.sh backup-database

# Export specific session
./scripts/chat-context-manager.sh export-session $SESSION_ID json
./scripts/chat-context-manager.sh export-session $SESSION_ID md
```

---

## 🔍 Troubleshooting

### GPU Acceleration Issues

**Symptoms:** High CPU usage, slow tokens, no GPU utilization

**Solutions:**
```bash
# 1. Re-run GPU acceleration fix
./scripts/fix-gpu-acceleration.sh

# 2. Check SYCL device detection
docker exec ollama-arc-server bash -c "source /opt/intel/oneapi/setvars.sh --force && sycl-ls"

# 3. Verify environment variables
docker exec ollama-arc-server env | grep -E "(ONEAPI_DEVICE_SELECTOR|SYCL_DEVICE_FILTER)"

# 4. Check Ollama startup logs
docker logs ollama-arc-server | tail -50
```

### Chat Context Issues

**Database Problems:**
```bash
# Reinitialize database
./scripts/chat-context-manager.sh init

# Check database status
./scripts/chat-context-manager.sh status
```

**Connection Issues:**
```bash
# Test Ollama connection
./scripts/simple-chat.sh test-connection

# Check container status
docker ps | grep ollama
```

---

## 🎯 Quick Start Commands

### For GPU-Accelerated Chat:
```bash
# Start interactive chat with GPU monitoring
./scripts/simple-chat.sh monitor-chat

# Or use Open WebUI (recommended)
# Open browser to: http://localhost:3000
```

### For Persistent Conversation History:
```bash
# Create session and start chatting
SESSION_ID=$(./scripts/chat-context-manager.sh create-session "Today's Chat")
./scripts/chat-context-manager.sh interactive $SESSION_ID
```

### For Quick Testing:
```bash
# Test GPU performance
./scripts/simple-chat.sh test-gpu

# Send single message
./scripts/simple-chat.sh send "Explain AI in 50 words"
```

---

## 📈 Expected Performance

With properly configured Intel Arc A770 GPU acceleration:

| Metric | Expected Value | Indicates |
|--------|---------------|-----------|
| Token Generation | >20 tokens/sec | Good GPU acceleration |
| CPU Usage | <50% during inference | GPU is handling workload |
| Response Time | <5s for short prompts | Efficient processing |
| Model Loading | <30s for 8B models | Fast GPU memory allocation |

---

## 🔗 Key Files & Scripts

| Script | Purpose |
|--------|---------|
| `scripts/fix-gpu-acceleration.sh` | Fix GPU acceleration issues |
| `scripts/chat-context-manager.sh` | Full-featured chat management |
| `scripts/simple-chat.sh` | Simple chat and testing |
| `scripts/monitor-gpu.sh` | Real-time GPU monitoring |
| `scripts/diagnose-gpu-acceleration.sh` | Comprehensive diagnostics |

---

## 🌟 Recommended Workflow

1. **Daily Use:** Open WebUI at http://localhost:3000 for casual chatting
2. **Development/API:** Use `chat-context-manager.sh` for programmatic access
3. **Testing:** Use `simple-chat.sh` for quick tests and performance checks
4. **Monitoring:** Run `monitor-gpu.sh` to verify GPU utilization

Your setup now provides enterprise-grade chat context management with high-performance GPU acceleration! 🚀

---

## 📞 Quick Help

**Get help for any script:**
```bash
./scripts/chat-context-manager.sh help
./scripts/simple-chat.sh help
./scripts/fix-gpu-acceleration.sh  # (self-documenting)
```

**Check system status:**
```bash
./scripts/chat-context-manager.sh status
./scripts/test-setup.sh
```

**Access logs:**
```bash
docker logs -f ollama-arc-server
docker logs -f ollama-webui
```

Everything is now optimized for your Intel Arc A770 with comprehensive chat context storage! 🎉