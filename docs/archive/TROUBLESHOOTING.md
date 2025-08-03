# Troubleshooting Guide - Intel GPU Stack for Ollama

This guide helps resolve common issues when building and running the Intel GPU-optimized Ollama container.

## 🚨 Common Build Issues

### Repository Release File Errors

**Error**: `intel-graphics/ubuntu jammy Release' does not have a Release file`

**Cause**: Intel repositories are temporarily unavailable or the URL has changed.

**Solution**:
```bash
# The Dockerfile now includes fallbacks, but you can also:
1. Wait a few minutes and retry the build
2. Check if Intel repositories are accessible:
   curl -I https://repositories.intel.com/gpu/ubuntu/dists/jammy/Release
3. Use the fallback build approach (automatic in latest Dockerfile)
```

### Intel oneAPI Repository Issues

**Error**: `Failed to fetch https://apt.repos.intel.com/oneapi/...`

**Solutions**:
1. **Check internet connection**: Ensure you can reach Intel servers
   ```bash
   ping apt.repos.intel.com
   ```

2. **Retry the build**: Repositories may be temporarily down
   ```bash
   ./update-intel-stack.sh --force
   ```

3. **Use test build script**: Validates build with better error reporting
   ```bash
   ./test-build.sh
   ```

### Package Not Available Errors

**Error**: `Package 'intel-compute-runtime' has no installation candidate`

**This is normal!** The Dockerfile now handles this gracefully:
- Uses fallback packages from Ubuntu repositories
- Installs available Intel packages individually
- Continues build process even if some packages fail

**What happens**: Container builds successfully with standard GPU packages and any available Intel packages.

## 🔧 Build Solutions

### Complete Clean Build

If you're having persistent issues:

```bash
# Remove all Docker build cache
docker system prune -a -f

# Remove existing images
docker rmi ollama-ubuntu:24.04

# Clean rebuild
./update-intel-stack.sh --force
```

### Test Build Process

Use the test build script to diagnose issues:

```bash
# Run build test with detailed output
./test-build.sh

# Check build logs
cat build.log
```

### Offline/Limited Internet Build

For environments with limited internet access:

```bash
# Build with minimal requirements
docker build -t ollama-ubuntu:24.04 \
  --build-arg SKIP_INTEL_REPOS=true .
```

## 🚀 Runtime Issues

### Container Won't Start

**Check logs**:
```bash
docker-compose logs ollama
```

**Common solutions**:
```bash
# Restart services
docker-compose down
docker-compose up -d

# Check container status
docker ps -a
```

### Intel GPU Not Detected

**Check GPU devices**:
```bash
# On host system
ls -la /dev/dri/
lspci | grep -i intel

# In container
docker exec ollama-arc-server ls -la /dev/dri/
```

**Solutions**:
1. **Verify GPU mapping**: Ensure `/dev/dri` is properly mounted
2. **Check permissions**: GPU devices should be accessible
3. **Update host drivers**: Ensure Intel GPU drivers are installed on host

### Ollama API Not Responding

**Test API connectivity**:
```bash
# Check if Ollama is running
docker exec ollama-arc-server pgrep ollama

# Test API endpoint
curl http://localhost:11434/api/tags
```

**Solutions**:
```bash
# Restart Ollama service
docker exec ollama-arc-server pkill ollama
docker-compose restart ollama

# Check logs for errors
docker-compose logs -f ollama
```

## 🔍 Diagnostic Commands

### Quick Health Check

```bash
# Run all diagnostics
docker exec ollama-arc-server gpu-diagnostics

# Check Intel versions
docker exec ollama-arc-server intel-versions

# Test Python environment
docker exec ollama-arc-server /opt/ipex-llm-env/bin/python -c "import torch; print('PyTorch:', torch.__version__)"
```

### Detailed System Check

```bash
# System information
docker exec ollama-arc-server lscpu
docker exec ollama-arc-server free -h
docker exec ollama-arc-server df -h

# GPU information  
docker exec ollama-arc-server lspci | grep -i vga
docker exec ollama-arc-server ls -la /dev/dri/

# Network connectivity
docker exec ollama-arc-server ping -c 3 google.com
```

## 🛠️ Repository Fallback Information

The updated Dockerfile uses a robust fallback system:

### Primary Intel Repositories
- Intel oneAPI: `https://apt.repos.intel.com/oneapi`
- Intel GPU: `https://repositories.intel.com/gpu/ubuntu`

### Fallback Strategy
1. **Try Intel repositories**: Latest packages if available
2. **Use Ubuntu packages**: Standard GPU libraries
3. **Individual package fallbacks**: Install what's available
4. **Continue on failures**: Build completes even with missing packages

### What Still Works Without Intel Repos
- ✅ Basic GPU functionality via Mesa drivers
- ✅ OpenCL support via ocl-icd-libopencl1
- ✅ Vulkan support via mesa-vulkan-drivers
- ✅ Ollama with CPU inference
- ✅ Python ML environment with PyTorch

### What Requires Intel Repos
- 🔶 Latest Intel Compute Runtime (25.16+)
- 🔶 Intel Extension for PyTorch optimizations
- 🔶 oneAPI 2025.2 toolkit
- 🔶 Advanced Arc GPU features

## 📝 Environment Variables Troubleshooting

### Check Critical Variables

```bash
# Intel GPU detection
docker exec ollama-arc-server env | grep -E "(INTEL|ZE_|SYCL|OLLAMA)"

# Expected values:
# OLLAMA_INTEL_GPU=true
# ZES_ENABLE_SYSMAN=1
# NEO_DISABLE_MITIGATIONS=1
# SYCL_CACHE_PERSISTENT=1
```

### Reset Environment

```bash
# Restart container with fresh environment
docker-compose down
docker-compose up -d
```

## 🏥 Performance Issues

### Low GPU Utilization

**Check mitigations**:
```bash
docker exec ollama-arc-server env | grep NEO_DISABLE_MITIGATIONS
# Should return: NEO_DISABLE_MITIGATIONS=1
```

**Monitor GPU usage**:
```bash
# If available
docker exec ollama-arc-server intel_gpu_top

# Alternative monitoring
docker stats ollama-arc-server
```

### Memory Issues

**Check memory limits**:
```bash
# Current memory usage
docker exec ollama-arc-server free -h

# Container limits (should be 32GB)
docker inspect ollama-arc-server | grep -i memory
```

**Solutions**:
- Increase memory limits in docker-compose.yml
- Enable IPEX low memory mode (should be automatic)
- Use smaller models

## 🆘 Getting Help

### Collect Debug Information

When reporting issues, include:

```bash
# System information
uname -a
docker --version
docker-compose --version

# Build logs
cat build.log

# Container logs
docker-compose logs ollama > ollama.log

# GPU diagnostics
docker exec ollama-arc-server gpu-diagnostics > gpu-diag.log

# Intel versions
docker exec ollama-arc-server intel-versions > intel-versions.log
```

### Common Log Patterns

**Build Success Indicators**:
- ✅ "Container built successfully"
- ✅ "Intel GPU stack validation passed"
- ✅ "PyTorch available"

**Expected Warnings** (Normal):
- ⚠️ "Package XYZ not available, skipping"
- ⚠️ "Intel graphics repository setup failed, continuing"
- ⚠️ "Some Intel repositories were unavailable"

**Critical Errors**:
- ❌ "Docker build failed"
- ❌ "Container is not responding"
- ❌ "Failed to start services"

## 🔄 Reset and Recovery

### Complete System Reset

```bash
# Stop all services
docker-compose down

# Remove containers and images
docker rm -f ollama-arc-server ollama-webui
docker rmi ollama-ubuntu:24.04

# Clean Docker system
docker system prune -a -f

# Rebuild from scratch
./update-intel-stack.sh --force
```

### Backup and Restore

**Backup models and data**:
```bash
# Backup models
cp -r data/models/ backup_models/

# Backup configuration
cp -r data/config/ backup_config/
```

**Restore after rebuild**:
```bash
# Restore models
cp -r backup_models/* data/models/

# Restore configuration  
cp -r backup_config/* data/config/
```

## 📞 Support Resources

- **Intel GPU Documentation**: https://dgpu-docs.intel.com/
- **Docker Documentation**: https://docs.docker.com/
- **Ollama Documentation**: https://ollama.com/docs
- **Intel oneAPI**: https://www.intel.com/content/www/us/en/developer/tools/oneapi/

## 🎯 Success Indicators

Your system is working correctly when:

- ✅ Container builds without critical errors
- ✅ `docker exec ollama-arc-server intel-versions` shows detected components
- ✅ `docker exec ollama-arc-server gpu-diagnostics` reports no critical issues
- ✅ Ollama API responds at http://localhost:11434/api/tags
- ✅ Models load and generate responses
- ✅ Web UI accessible at http://localhost:3000 (if enabled)

Remember: Even without all Intel packages, the system provides excellent performance with standard GPU drivers and PyTorch optimizations!