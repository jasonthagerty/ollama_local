# Ollama Server with Intel Arc A770 GPU - Project Overview

This project provides a complete Docker-based setup for running Ollama with Intel Arc A770 GPU acceleration on the server "blackbox".

## 🚀 Quick Start

```bash
# 1. Run the automated setup
./setup.sh

# 2. Or start manually
./manage.sh start

# 3. Pull your first model
./manage.sh pull llama2

# 4. Start chatting
./manage.sh chat llama2
```

**Access Points:**
- Ollama API: http://localhost:11434
- Web UI: http://localhost:3000

## 📁 Project Structure

```
ollama-local/
├── docker-compose.yml      # Service definitions with Intel GPU support
├── Dockerfile             # Custom Ollama image with Intel GPU runtime
├── .env                   # Environment configuration
├── setup.sh              # Automated setup and verification script
├── manage.sh              # Management script for all operations
├── README.md              # Detailed documentation
├── OVERVIEW.md            # This file
├── .dockerignore          # Docker build optimization
└── data/                  # Persistent data (created automatically)
    ├── ollama/           # Model storage
    └── webui/            # Web UI data
```

## 🔧 Key Features

### Intel Arc A770 GPU Support
- Custom Docker image with Intel GPU runtime
- Level Zero and OpenCL drivers included
- Optimized for Intel Arc architecture
- GPU device passthrough configured

### Services
- **Ollama Server**: Main LLM inference engine
- **Web UI**: User-friendly chat interface
- **Health Checks**: Automatic service monitoring
- **Data Persistence**: Models and configs preserved

### Management Tools
- **setup.sh**: One-command setup with verification
- **manage.sh**: Complete management toolkit
- **Environment Variables**: Easy configuration via .env
- **Backup/Restore**: Data protection utilities

## 🎯 Common Commands

```bash
# Service Management
./manage.sh start           # Start all services
./manage.sh stop            # Stop all services
./manage.sh status          # Check service status
./manage.sh logs            # View logs

# Model Management
./manage.sh models          # List installed models
./manage.sh pull mistral    # Download Mistral model
./manage.sh chat mistral    # Chat with Mistral
./manage.sh remove mistral  # Remove model

# System Monitoring
./manage.sh gpu             # Show GPU information
./manage.sh monitor         # Live system monitoring
./manage.sh health          # Health check

# Maintenance
./manage.sh backup          # Create backup
./manage.sh update          # Update containers
./manage.sh cleanup         # Clean unused resources
```

## 🔍 GPU Configuration

The setup includes specific optimizations for Intel Arc A770:

### Environment Variables
- `SYCL_BE=PI_LEVEL_ZERO`: Use Level Zero backend
- `ONEAPI_DEVICE_SELECTOR=level_zero:gpu`: GPU selection
- `OLLAMA_GPU_OVERHEAD=0`: Minimize VRAM overhead
- `OLLAMA_FLASH_ATTENTION=1`: Enable flash attention

### Runtime Components
- Intel OpenCL ICD
- Level Zero GPU runtime
- Mesa GPU drivers
- Intel media drivers

### Device Access
- `/dev/dri/card0`: GPU card device
- `/dev/dri/renderD128`: GPU render device
- Video/render group membership

## 🧪 Verification Steps

The setup script verifies:
1. ✅ Docker and Docker Compose installation
2. ✅ User permissions (docker group)
3. ✅ Intel GPU device availability
4. ✅ GPU drivers functionality
5. ✅ Port availability (11434, 3000)
6. ✅ Container GPU access

## 📊 Performance Expectations

With Intel Arc A770 (16GB VRAM):
- **Small models** (7B): ~20-50 tokens/sec
- **Medium models** (13B): ~10-25 tokens/sec
- **Large models** (30B+): ~5-15 tokens/sec

*Performance varies by model architecture and context length*

## 🔧 Troubleshooting

### GPU Not Detected
```bash
# Check GPU devices
ls -la /dev/dri/

# Verify in container
./manage.sh shell
ls -la /dev/dri/
```

### Performance Issues
```bash
# Monitor GPU usage
intel_gpu_top

# Check container resources
./manage.sh monitor
```

### Service Problems
```bash
# Check service health
./manage.sh health

# View detailed logs
./manage.sh logs ollama
```

## 🚀 Popular Models to Try

```bash
# Lightweight and fast
./manage.sh pull phi
./manage.sh pull tinyllama

# Balanced performance
./manage.sh pull llama2
./manage.sh pull mistral

# Code-focused
./manage.sh pull codellama
./manage.sh pull deepseek-coder

# Specialized
./manage.sh pull vicuna
./manage.sh pull orca-mini
```

## 🔒 Security Notes

- Web UI uses configurable authentication
- Change `WEBUI_SECRET_KEY` in .env for production
- Consider reverse proxy with SSL for external access
- Firewall ports 11434 and 3000 as needed

## 📈 Resource Requirements

### Minimum
- Intel Arc A770 GPU
- 16GB System RAM
- 50GB free disk space
- Ubuntu 20.04+ or similar

### Recommended
- 32GB+ System RAM
- NVMe SSD storage
- Good cooling solution
- Dedicated GPU power supply

## 🔄 Updates

```bash
# Update containers
./manage.sh update

# Update models
./manage.sh pull <model-name>

# Update project files
git pull  # if using git
```

## 📞 Support Resources

- **Ollama Documentation**: https://github.com/ollama/ollama
- **Intel GPU Docs**: https://dgpu-docs.intel.com/
- **Docker Compose**: https://docs.docker.com/compose/

## 🎉 What's Next?

1. **Try different models** - Experiment with various model sizes
2. **Customize prompts** - Create system prompts for specific tasks
3. **API integration** - Build applications using the Ollama API
4. **Performance tuning** - Optimize for your specific workload
5. **Model creation** - Import and customize your own models

Happy chatting with your local AI server! 🤖