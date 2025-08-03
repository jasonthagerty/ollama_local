FROM ubuntu:24.04

# Set environment variables for Intel GPU and Arc GPU targeting
ENV DEBIAN_FRONTEND=noninteractive \
    INTEL_GPU=1 \
    OLLAMA_INTEL_GPU=true \
    ZES_ENABLE_SYSMAN=1 \
    ZE_ENABLE_PCI_ID_DEVICE_ORDER=1 \
    ONEAPI_DEVICE_SELECTOR=level_zero:0 \
    DEVICE=Arc \
    SYCL_CACHE_PERSISTENT=1 \
    DRI_PRIME=1 \
    OLLAMA_GPU_DEVICE=/dev/dri/renderD129 \
    NEO_DISABLE_MITIGATIONS=1 \
    SYCL_DEVICE_FILTER=level_zero:gpu \
    ZE_FLAT_DEVICE_HIERARCHY=COMPOSITE \
    INTEL_DEVICE_TARGET=arc \
    ZE_ENABLE_VALIDATION_LAYER=0 \
    ZE_ENABLE_PARAMETER_VALIDATION=0 \
    INTEL_COMPUTE_RUNTIME_OCL_DEBUG=0 \
    INTEL_COMPUTE_RUNTIME_L0_DEBUG=0 \
    INTEL_COMPUTE_RUNTIME_ENABLE_KERNEL_DEBUG=0 \
    NEO_ENABLE_INDIRECT_ACCESS_DETECTION=0 \
    SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS=1 \
    SYCL_PI_LEVEL_ZERO_DEVICE_SCOPE_EVENTS=1 \
    SYCL_PI_LEVEL_ZERO_USE_COPY_ENGINE=1 \
    CL_CONFIG_CPU_FORCE_PRIVATE_MEM_SIZE=16MB \
    CL_CONFIG_USE_VECTORIZER=true \
    SYCL_CACHE_DIR=/tmp/sycl_cache \
    IPEX_LLM_LOW_MEM=1 \
    IPEX_LLM_NUM_CTX=16384 \
    OLLAMA_GPU_LAYERS=999 \
    OLLAMA_NUM_PARALLEL=2 \
    OLLAMA_MAX_LOADED_MODELS=1 \
    OLLAMA_KEEP_ALIVE=5m \
    PATH="/opt/intel/oneapi/compiler/latest/linux/bin:/usr/local/bin:$PATH" \
    LD_LIBRARY_PATH="/opt/intel/oneapi/umf/0.11/lib:/opt/intel/oneapi/compiler/latest/linux/lib:/opt/intel/oneapi/compiler/latest/linux/lib/x64"

# Install all dependencies, build software, and cleanup in a single layer to minimize image size
RUN set -ex && \
    # Update package lists
    apt-get update && \
    \
    # Install runtime dependencies (keep these)
    apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    gnupg \
    software-properties-common \
    apt-transport-https \
    lsb-release \
    vainfo \
    mesa-utils \
    mesa-va-drivers \
    mesa-vulkan-drivers \
    va-driver-all \
    ocl-icd-libopencl1 \
    libegl-mesa0 \
    libegl1 \
    libgbm1 \
    libgl1-mesa-dri \
    libglapi-mesa \
    libglx-mesa0 \
    libvulkan1 \
    vulkan-tools \
    libva-dev \
    sqlite3 \
    jq \
    bc \
    openssl \
    # Python runtime
    python3 \
    python3-pip \
    python3-venv \
    # System utilities
    pciutils \
    htop \
    vim \
    nano \
    tmux \
    net-tools \
    procps \
    lshw \
    hwinfo && \
    \
    # Install build dependencies (will remove later)
    apt-get install -y --no-install-recommends \
    # Build tools
    build-essential \
    cmake \
    git \
    wget \
    python3-dev \
    # Development libraries
    libegl1-mesa-dev \
    libgl1-mesa-dev \
    libgles2-mesa-dev \
    mesa-common-dev && \
    \
    # Try to install Intel GPU packages from standard repositories
    for pkg in intel-gpu-tools clinfo; do \
    apt-get install -y --no-install-recommends $pkg 2>/dev/null || echo "Package $pkg not available in standard repos"; \
    done && \
    \
    # Clean initial package cache
    rm -rf /var/lib/apt/lists/* && \
    \
    # Add Intel repositories (graceful failure)
    (wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB 2>/dev/null | \
    gpg --dearmor --output /usr/share/keyrings/oneapi-archive-keyring.gpg 2>/dev/null && \
    echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" > /etc/apt/sources.list.d/oneAPI.list && \
    echo "Intel oneAPI repository added") || \
    echo "Intel oneAPI repository not available, continuing without it" && \
    \
    (wget -qO- https://repositories.intel.com/gpu/intel-graphics.key 2>/dev/null | \
    gpg --dearmor --output /usr/share/keyrings/intel-graphics.gpg 2>/dev/null && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu jammy client" > /etc/apt/sources.list.d/intel-gpu.list && \
    echo "Intel GPU repository added") || \
    echo "Intel GPU repository not available, continuing with available packages" && \
    \
    # Update repositories for Intel packages
    apt-get update 2>/dev/null || echo "Some repositories failed to update, continuing with available packages" && \
    \
    # Install Intel GPU packages (runtime only)
    INTEL_PACKAGES="intel-opencl-icd intel-level-zero-gpu level-zero intel-media-driver intel-media-va-driver-non-free intel-compute-runtime intel-graphics-compiler libze1 intel-gmmlib libmfx1 libvpl2 onevpl-intel-gpu libvpl-tools" && \
    for pkg in $INTEL_PACKAGES; do \
    echo "Trying to install $pkg..." && \
    (apt-get install -y --no-install-recommends $pkg 2>/dev/null && echo "✓ Installed $pkg") || echo "✗ $pkg not available"; \
    done && \
    \
    # Install Intel oneAPI toolkit with SYCL tools (includes runtime + tools)
    ONEAPI_PACKAGES="intel-oneapi-toolkit intel-oneapi-compiler-dpcpp-cpp intel-oneapi-mkl intel-oneapi-runtime-dpcpp-cpp intel-oneapi-runtime-mkl intel-oneapi-runtime-opencl intel-oneapi-compiler-dpcpp-cpp-2025.2 intel-oneapi-mkl-2025.2" && \
    for pkg in $ONEAPI_PACKAGES; do \
    echo "Trying to install $pkg..." && \
    (apt-get install -y --no-install-recommends $pkg 2>/dev/null && echo "✓ Installed $pkg") || echo "✗ $pkg not available"; \
    done && \
    \
    # Create Intel-optimized Python virtual environment
    python3 -m venv /opt/ipex-llm-env && \
    /opt/ipex-llm-env/bin/pip install --no-cache-dir --upgrade pip setuptools wheel && \
    \
    # Install PyTorch and ML packages
    /opt/ipex-llm-env/bin/pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu && \
    \
    # Install Intel Extension for PyTorch
    (/opt/ipex-llm-env/bin/pip install --no-cache-dir intel-extension-for-pytorch && echo "✓ IPEX installed") || \
    (/opt/ipex-llm-env/bin/pip install --no-cache-dir intel-extension-for-pytorch==2.1.* && echo "✓ IPEX 2.1 installed") || \
    echo "✗ IPEX not available, continuing without it" && \
    \
    # Install core ML libraries
    /opt/ipex-llm-env/bin/pip install --no-cache-dir \
    transformers \
    accelerate \
    datasets \
    tokenizers \
    sentencepiece \
    protobuf \
    numpy \
    psutil && \
    \
    # Install Intel ML optimizations (optional)
    INTEL_ML_PACKAGES="optimum-intel neural-compressor intel-extension-for-transformers scikit-learn-intelex" && \
    for pkg in $INTEL_ML_PACKAGES; do \
    echo "Trying to install $pkg..." && \
    (/opt/ipex-llm-env/bin/pip install --no-cache-dir $pkg && echo "✓ Installed $pkg") || echo "✗ $pkg not available"; \
    done && \
    \
    # Install GPU monitoring tools
    /opt/ipex-llm-env/bin/pip install --no-cache-dir gpustat py3nvml 2>/dev/null || echo "GPU monitoring tools not available" && \
    \
    # Create directory structure
    mkdir -p /llm/ollama /llm/scripts /llm/bin /root/.ollama /tmp/sycl_cache /llm/data/contexts /llm/data/backups /llm/data/exports && \
    chmod 777 /tmp/sycl_cache && \
    \
    # Download and install Ollama
    curl -fsSL https://ollama.com/install.sh | sh && \
    cp /usr/local/bin/ollama /llm/ollama/ && \
    chmod +x /llm/ollama/ollama && \
    \
    # Create sycl-ls wrapper with correct library paths
    cat > /usr/local/bin/sycl-ls << 'SYCL_EOF' && \
    #!/bin/bash
    export LD_LIBRARY_PATH="/opt/intel/oneapi/umf/0.11/lib:/opt/intel/oneapi/compiler/2025.2/lib:${LD_LIBRARY_PATH:-}"
exec /opt/intel/oneapi/compiler/2025.2/bin/sycl-ls "$@"
SYCL_EOF
RUN chmod +x /usr/local/bin/sycl-ls && \
    \
    # CLEANUP PHASE - Remove build dependencies and caches
    echo "Starting cleanup to reduce image size..." && \
    \
    # Remove build tools and development packages (but keep oneAPI tools)
    apt-get remove -y --purge \
    build-essential \
    cmake \
    git \
    wget \
    python3-dev \
    libegl1-mesa-dev \
    libgl1-mesa-dev \
    libgles2-mesa-dev \
    mesa-common-dev && \
    \
    # Remove orphaned packages
    apt-get autoremove -y --purge && \
    \
    # Clean package cache and temporary files
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* \
    /var/cache/apt/archives/* \
    /tmp/* \
    /var/tmp/* \
    /root/.cache \
    /root/.wget-hsts && \
    \
    # Clean pip cache
    /opt/ipex-llm-env/bin/pip cache purge 2>/dev/null || true && \
    \
    # Remove unnecessary documentation and man pages
    rm -rf /usr/share/doc/* \
    /usr/share/man/* \
    /usr/share/info/* \
    /usr/share/locale/* \
    /var/log/* && \
    \
    # Remove any remaining package files
    find /var/lib/dpkg/info -name "*.list" -delete 2>/dev/null || true && \
    \
    # Clean oneAPI installation if present (keep tools but remove docs/examples)
    if [ -d "/opt/intel/oneapi" ]; then \
    find /opt/intel/oneapi -name "*doc*" -type d -exec rm -rf {} + 2>/dev/null || true; \
    find /opt/intel/oneapi -name "*example*" -type d -exec rm -rf {} + 2>/dev/null || true; \
    find /opt/intel/oneapi -name "*sample*" -type d -exec rm -rf {} + 2>/dev/null || true; \
    fi && \
    \
    echo "Cleanup completed"

# Create comprehensive Intel GPU initialization script
RUN cat > /llm/scripts/init-intel-gpu-optimized.sh << 'EOF'
#!/bin/bash
echo "🎯 Advanced Intel Arc GPU Initialization for Ollama..."

# Exit on any error for better debugging
set -e

# Create log file for comprehensive logging
LOG_FILE="/tmp/intel-gpu-init.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

echo "$(date): Starting advanced Intel GPU initialization" >> "$LOG_FILE"

# Step 1: Activate Intel-optimized ML environment
echo "📦 Activating Python environment..."
if [ -f /opt/ipex-llm-env/bin/activate ]; then
source /opt/ipex-llm-env/bin/activate
echo "✅ Python environment activated"
echo "  Python: $(python --version 2>/dev/null || echo 'not accessible')"
else
echo "⚠️  Python environment not found"
fi

# Step 2: Force source Intel OneAPI environment with enhanced handling
echo "🔧 Loading Intel OneAPI environment..."

if [ -f /opt/intel/oneapi/setvars.sh ]; then
echo "✅ Found setvars.sh, applying comprehensive OneAPI initialization..."

# Create comprehensive OneAPI initialization script
cat > /tmp/oneapi_comprehensive_init.sh << 'ONEAPI_INIT'
#!/bin/bash
# Comprehensive OneAPI initialization

# Source OneAPI environment with all components
source /opt/intel/oneapi/setvars.sh --force 2>&1

# Export critical environment variables explicitly
export ONEAPI_ROOT=/opt/intel/oneapi
export INTEL_GPU=1
export OLLAMA_INTEL_GPU=true

# Intel Arc A770 specific settings (device 1, not 0)
export ONEAPI_DEVICE_SELECTOR=level_zero:0
export SYCL_DEVICE_FILTER=level_zero:gpu
export DEVICE=Arc
export INTEL_DEVICE_TARGET=arc

# Level Zero optimizations for Arc GPU
export ZES_ENABLE_SYSMAN=1
export ZE_ENABLE_PCI_ID_DEVICE_ORDER=1
export ZE_FLAT_DEVICE_HIERARCHY=COMPOSITE
export ZE_ENABLE_VALIDATION_LAYER=0
export ZE_ENABLE_PARAMETER_VALIDATION=0

# SYCL performance optimizations
export SYCL_CACHE_PERSISTENT=1
export SYCL_CACHE_DIR=/tmp/sycl_cache
export SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS=1
export SYCL_PI_LEVEL_ZERO_DEVICE_SCOPE_EVENTS=1
export SYCL_PI_LEVEL_ZERO_USE_COPY_ENGINE=1

# Intel Compute Runtime optimizations
export INTEL_COMPUTE_RUNTIME_OCL_DEBUG=0
export INTEL_COMPUTE_RUNTIME_L0_DEBUG=0
export INTEL_COMPUTE_RUNTIME_ENABLE_KERNEL_DEBUG=0
export NEO_DISABLE_MITIGATIONS=1
export NEO_ENABLE_INDIRECT_ACCESS_DETECTION=0

# GPU device configuration
export DRI_PRIME=1
export OLLAMA_GPU_DEVICE=/dev/dri/renderD129

# Ollama GPU settings
export OLLAMA_GPU_LAYERS=999
export OLLAMA_NUM_PARALLEL=2
export OLLAMA_MAX_LOADED_MODELS=1
export OLLAMA_KEEP_ALIVE=5m

# IPEX-LLM optimizations
export IPEX_LLM_LOW_MEM=1
export IPEX_LLM_NUM_CTX=16384

# OpenCL optimizations
export CL_CONFIG_CPU_FORCE_PRIVATE_MEM_SIZE=16MB
export CL_CONFIG_USE_VECTORIZER=true

# Export all Intel-related variables to a file for persistence
env | grep -E "(ONEAPI|INTEL|SYCL|ZE_|ZES_|LEVEL_ZERO|DRI|DEVICE|NEO|OLLAMA|IPEX|CL_)" > /tmp/intel_gpu_env_persistent.sh

echo "✅ Comprehensive Intel Arc A770 environment configured"
ONEAPI_INIT

chmod +x /tmp/oneapi_comprehensive_init.sh

# Execute comprehensive initialization
if /tmp/oneapi_comprehensive_init.sh; then
echo "✅ OneAPI comprehensive initialization completed successfully"

# Source the persistent environment variables
if [ -f /tmp/intel_gpu_env_persistent.sh ]; then
while IFS='=' read -r key value; do
export "$key"="$value"
done < /tmp/intel_gpu_env_persistent.sh
echo "✅ Persistent environment variables loaded"
fi
else
echo "⚠️  OneAPI initialization had issues, applying manual fallback..."

# Manual fallback configuration
export ONEAPI_DEVICE_SELECTOR=level_zero:0
export SYCL_DEVICE_FILTER=level_zero:gpu
export DEVICE=Arc
export INTEL_DEVICE_TARGET=arc
export ZES_ENABLE_SYSMAN=1
export INTEL_GPU=1
export OLLAMA_INTEL_GPU=true
fi

# Manual path setup as additional fallback
if [ -d "/opt/intel/oneapi/compiler/latest/linux/bin" ]; then
export PATH="/opt/intel/oneapi/compiler/latest/linux/bin:$PATH"
echo "✅ OneAPI compiler added to PATH"
fi

if [ -d "/opt/intel/oneapi/compiler/latest/linux/lib" ]; then
export LD_LIBRARY_PATH="/opt/intel/oneapi/umf/0.11/lib:/opt/intel/oneapi/compiler/latest/linux/lib:/opt/intel/oneapi/compiler/latest/linux/lib/x64:${LD_LIBRARY_PATH:-}"
echo "✅ OneAPI libraries added to LD_LIBRARY_PATH"
fi

else
echo "❌ OneAPI not found, using system Intel packages only"

# Basic fallback environment for system Intel packages
export INTEL_GPU=1
export OLLAMA_INTEL_GPU=true
export ONEAPI_DEVICE_SELECTOR=level_zero:0
export SYCL_DEVICE_FILTER=level_zero:gpu
export DEVICE=Arc
export INTEL_DEVICE_TARGET=arc
fi

# Step 3: Ensure SYCL cache directory is properly configured
echo "💾 Configuring SYCL cache..."
mkdir -p /tmp/sycl_cache
chmod 777 /tmp/sycl_cache
export SYCL_CACHE_DIR=/tmp/sycl_cache
echo "✅ SYCL cache configured at /tmp/sycl_cache"

# Step 4: Verify hardware and environment
echo "🔍 Verifying Intel Arc GPU configuration..."

# Check GPU devices
if [ -d "/dev/dri" ]; then
echo "GPU devices found:"
ls -la /dev/dri/ | sed 's/^/  /'

if [ -c "/dev/dri/renderD129" ]; then
echo "✅ Target GPU device /dev/dri/renderD129 accessible"
else
echo "⚠️  Target GPU device /dev/dri/renderD129 not found"
echo "Available devices:"
ls -la /dev/dri/ | grep renderD | sed 's/^/  /'
fi
else
echo "❌ No DRI devices found"
fi

# Test SYCL device enumeration
echo "🔬 Testing SYCL device enumeration..."
if command -v sycl-ls >/dev/null 2>&1; then
echo "✅ sycl-ls available"
if timeout 10s sycl-ls 2>/dev/null; then
echo "✅ SYCL device enumeration successful"
else
echo "⚠️  SYCL enumeration failed or timed out"
fi
else
echo "❌ sycl-ls not available"
fi

# Test OpenCL
if command -v clinfo >/dev/null 2>&1; then
echo "✅ clinfo available"
echo "OpenCL platforms:"
timeout 5s clinfo -l 2>/dev/null | head -3 | sed 's/^/  /' || echo "  OpenCL enumeration failed"
else
echo "❌ clinfo not available"
fi

# Step 5: Export final environment for other processes
echo "📤 Exporting comprehensive environment..."

# Create comprehensive environment export
cat > /tmp/ollama_complete_env.sh << 'ENV_EXPORT'
# Comprehensive Intel Arc A770 GPU Environment
export INTEL_GPU=1
export OLLAMA_INTEL_GPU=true
export ONEAPI_DEVICE_SELECTOR=level_zero:0
export SYCL_DEVICE_FILTER=level_zero:gpu
export DEVICE=Arc
export INTEL_DEVICE_TARGET=arc
export ZES_ENABLE_SYSMAN=1
export ZE_ENABLE_PCI_ID_DEVICE_ORDER=1
export ZE_FLAT_DEVICE_HIERARCHY=COMPOSITE
export ZE_ENABLE_VALIDATION_LAYER=0
export ZE_ENABLE_PARAMETER_VALIDATION=0
export SYCL_CACHE_PERSISTENT=1
export SYCL_CACHE_DIR=/tmp/sycl_cache
export SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS=1
export SYCL_PI_LEVEL_ZERO_DEVICE_SCOPE_EVENTS=1
export SYCL_PI_LEVEL_ZERO_USE_COPY_ENGINE=1
export INTEL_COMPUTE_RUNTIME_OCL_DEBUG=0
export INTEL_COMPUTE_RUNTIME_L0_DEBUG=0
export INTEL_COMPUTE_RUNTIME_ENABLE_KERNEL_DEBUG=0
export NEO_DISABLE_MITIGATIONS=1
export NEO_ENABLE_INDIRECT_ACCESS_DETECTION=0
export DRI_PRIME=1
export OLLAMA_GPU_DEVICE=/dev/dri/renderD129
export OLLAMA_GPU_LAYERS=999
export OLLAMA_NUM_PARALLEL=2
export OLLAMA_MAX_LOADED_MODELS=1
export OLLAMA_KEEP_ALIVE=5m
export IPEX_LLM_LOW_MEM=1
export IPEX_LLM_NUM_CTX=16384
export CL_CONFIG_CPU_FORCE_PRIVATE_MEM_SIZE=16MB
export CL_CONFIG_USE_VECTORIZER=true
ENV_EXPORT

chmod +x /tmp/ollama_complete_env.sh
echo "✅ Complete environment exported to /tmp/ollama_complete_env.sh"

# Final verification
echo "🎯 Intel Arc A770 GPU initialization completed!"
echo "Key settings:"
echo "  • ONEAPI_DEVICE_SELECTOR: $ONEAPI_DEVICE_SELECTOR"
echo "  • SYCL_DEVICE_FILTER: $SYCL_DEVICE_FILTER"
echo "  • INTEL_DEVICE_TARGET: $INTEL_DEVICE_TARGET"
echo "  • OLLAMA_INTEL_GPU: $OLLAMA_INTEL_GPU"
echo "  • SYCL_CACHE_DIR: $SYCL_CACHE_DIR"

echo "$(date): Intel GPU initialization completed successfully" >> "$LOG_FILE"
EOF

# Create optimized Ollama startup script
RUN cat > /llm/scripts/start-ollama-optimized.sh << 'EOF'
#!/bin/bash
echo "🚀 Starting Ollama with Optimized Intel Arc GPU Support"

# Exit on error for better debugging
set -e

# Create startup log
LOG_FILE="/tmp/ollama-startup.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

echo "$(date): Starting optimized Ollama startup" >> "$LOG_FILE"

# Step 1: Force comprehensive Intel GPU initialization
echo "🔧 Initializing Intel Arc GPU environment..."
if [ -f "/llm/scripts/init-intel-gpu-optimized.sh" ]; then
source /llm/scripts/init-intel-gpu-optimized.sh
else
echo "⚠️  GPU initialization script not found, using basic setup..."
# Basic fallback
export INTEL_GPU=1
export OLLAMA_INTEL_GPU=true
export ONEAPI_DEVICE_SELECTOR=level_zero:0
export SYCL_DEVICE_FILTER=level_zero:gpu
export DEVICE=Arc
fi

# Step 2: Source persistent environment if available
if [ -f "/tmp/ollama_complete_env.sh" ]; then
echo "📋 Loading persistent GPU environment..."
source /tmp/ollama_complete_env.sh
echo "✅ GPU environment loaded"
fi

# Step 3: Force OneAPI environment sourcing
if [ -f "/opt/intel/oneapi/setvars.sh" ]; then
echo "🔧 Force sourcing Intel OneAPI environment..."
source /opt/intel/oneapi/setvars.sh --force >/dev/null 2>&1 || echo "⚠️  OneAPI sourcing had issues"
echo "✅ OneAPI environment processed"
fi

# Step 4: Configure Ollama environment
echo "⚙️  Configuring Ollama environment..."

# Core Ollama configuration
export OLLAMA_HOST=${OLLAMA_HOST:-0.0.0.0:11434}
export OLLAMA_ORIGINS=${OLLAMA_ORIGINS:-*}
export OLLAMA_MODELS=${OLLAMA_MODELS:-/root/.ollama/models}

# Ensure models directory exists
mkdir -p "$OLLAMA_MODELS"

# Intel GPU specific Ollama settings
export OLLAMA_INTEL_GPU=true
export OLLAMA_GPU_LAYERS=${OLLAMA_GPU_LAYERS:-999}
export OLLAMA_NUM_PARALLEL=${OLLAMA_NUM_PARALLEL:-2}
export OLLAMA_MAX_LOADED_MODELS=${OLLAMA_MAX_LOADED_MODELS:-1}
export OLLAMA_KEEP_ALIVE=${OLLAMA_KEEP_ALIVE:-5m}

echo "✅ Ollama environment configured"

# Step 5: Pre-flight verification
echo "🔍 Pre-flight verification..."

# Check critical environment variables
CRITICAL_VARS=("OLLAMA_INTEL_GPU" "ONEAPI_DEVICE_SELECTOR" "SYCL_DEVICE_FILTER" "DEVICE")
for var in "${CRITICAL_VARS[@]}"; do
value="${!var}"
if [ -n "$value" ]; then
echo "  ✅ $var = $value"
else
echo "  ❌ $var not set"
fi
done

# Check GPU device
if [ -c "/dev/dri/renderD129" ]; then
echo "  ✅ GPU device accessible: /dev/dri/renderD129"
else
echo "  ⚠️  GPU device not found: /dev/dri/renderD129"
fi

# Check SYCL cache
if [ -d "/tmp/sycl_cache" ]; then
echo "  ✅ SYCL cache directory ready"
else
echo "  ⚠️  SYCL cache directory missing"
fi

# Step 6: Start Ollama
echo "🚀 Starting Ollama server..."

cd /llm/ollama

echo "Ollama configuration:"
echo "  • Host: $OLLAMA_HOST"
echo "  • Models: $OLLAMA_MODELS"
echo "  • Intel GPU: $OLLAMA_INTEL_GPU"
echo "  • GPU Layers: $OLLAMA_GPU_LAYERS"
echo "  • Device Selector: $ONEAPI_DEVICE_SELECTOR"

# Start Ollama with error handling
if ! ./ollama serve; then
echo "❌ Ollama failed to start"
echo "Diagnostics:"
echo "  • GPU devices: $(ls /dev/dri/ 2>/dev/null | tr '\n' ' ' || echo 'none')"
echo "  • OneAPI: $(ls /opt/intel/oneapi/ 2>/dev/null | head -1 || echo 'not found')"
echo "  • Environment: $(env | grep -c INTEL || echo '0') Intel variables set"
exit 1
fi

echo "$(date): Ollama startup completed" >> "$LOG_FILE"
EOF

# Create comprehensive diagnostics script
RUN cat > /llm/bin/gpu-diagnostics-comprehensive << 'EOF'
#!/bin/bash
echo "🔍 Comprehensive Intel Arc GPU Diagnostics"
echo "=========================================="

echo "1. System Information:"
echo "  OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "  Kernel: $(uname -r)"
echo ""

echo "2. GPU Devices:"
if [ -d "/dev/dri" ]; then
ls -la /dev/dri/
echo "  ✅ DRI devices found"
else
echo "  ❌ No DRI devices"
fi
echo ""

echo "3. Intel OneAPI:"
if [ -d "/opt/intel/oneapi" ]; then
echo "  ✅ OneAPI installed"
echo "  Components: $(ls /opt/intel/oneapi/ | grep -v setvars | tr '\n' ' ')"
if [ -f "/opt/intel/oneapi/setvars.sh" ]; then
echo "  ✅ setvars.sh available"
fi
else
echo "  ❌ OneAPI not found"
fi
echo ""

echo "4. Environment Variables:"
env | grep -E "(ONEAPI|INTEL|SYCL|ZE_|OLLAMA.*GPU)" | while read var; do
echo "  $var"
done
echo ""

echo "5. SYCL Devices:"
if command -v sycl-ls >/dev/null 2>&1; then
echo "  ✅ sycl-ls available"
if source /opt/intel/oneapi/setvars.sh --force >/dev/null 2>&1; then
sycl-ls 2>/dev/null | head -5 || echo "  ⚠️  SYCL enumeration failed"
fi
else
echo "  ❌ sycl-ls not available"
fi
echo ""

echo "6. OpenCL:"
if command -v clinfo >/dev/null 2>&1; then
echo "  ✅ clinfo available"
timeout 5s clinfo -l 2>/dev/null | head -3 || echo "  ⚠️  OpenCL enumeration failed"
else
echo "  ❌ clinfo not available"
fi
echo ""

echo "7. Ollama Status:"
if pgrep ollama >/dev/null; then
echo "  ✅ Ollama running"
if timeout 3s curl -s http://localhost:11434/api/tags >/dev/null; then
echo "  ✅ API responding"
else
echo "  ⚠️  API not responding"
fi
else
echo "  ❌ Ollama not running"
fi
echo ""

echo "8. Memory Usage:"
free -h | head -2
echo ""

echo "9. Recent Logs:"
if [ -f "/tmp/intel-gpu-init.log" ]; then
echo "  GPU Init Log (last 5 lines):"
tail -5 /tmp/intel-gpu-init.log | sed 's/^/    /'
fi
if [ -f "/tmp/ollama-startup.log" ]; then
echo "  Ollama Startup Log (last 5 lines):"
tail -5 /tmp/ollama-startup.log | sed 's/^/    /'
fi
EOF

# Create chat context manager initialization script
RUN cat > /llm/scripts/init-chat-context.sh << 'EOF'
#!/bin/bash
echo "💬 Initializing Chat Context Management..."

# Create data directories
mkdir -p /llm/data/contexts /llm/data/backups /llm/data/exports /llm/data/sessions /llm/data/templates

# Initialize SQLite database
DB_FILE="/llm/data/conversations.db"

if [ ! -f "$DB_FILE" ]; then
echo "📊 Creating conversation database..."

sqlite3 "$DB_FILE" << 'SQL_EOF'
-- Conversations table
CREATE TABLE IF NOT EXISTS conversations (
id INTEGER PRIMARY KEY AUTOINCREMENT,
session_id TEXT NOT NULL,
message_id INTEGER NOT NULL,
role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
content TEXT NOT NULL,
model TEXT,
timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
metadata TEXT,
token_count INTEGER,
processing_time REAL
);

-- Sessions table
CREATE TABLE IF NOT EXISTS sessions (
session_id TEXT PRIMARY KEY,
name TEXT,
description TEXT,
model TEXT,
system_prompt TEXT,
created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
message_count INTEGER DEFAULT 0,
total_tokens INTEGER DEFAULT 0,
settings TEXT
);

-- Templates table
CREATE TABLE IF NOT EXISTS templates (
id INTEGER PRIMARY KEY AUTOINCREMENT,
name TEXT UNIQUE NOT NULL,
description TEXT,
system_prompt TEXT,
initial_messages TEXT,
model TEXT,
settings TEXT,
created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_conversations_session ON conversations(session_id);
CREATE INDEX IF NOT EXISTS idx_conversations_timestamp ON conversations(timestamp);
CREATE INDEX IF NOT EXISTS idx_sessions_updated ON sessions(updated_at);

-- Insert default template
INSERT OR IGNORE INTO templates (name, description, system_prompt, model)
VALUES ('default', 'Default conversation template', 'You are a helpful AI assistant.', 'deepseek-r1:8b');
SQL_EOF

echo "✅ Database initialized at $DB_FILE"
else
echo "✅ Database already exists"
fi

# Set permissions
chmod 666 "$DB_FILE" 2>/dev/null || true
chmod -R 777 /llm/data/ 2>/dev/null || true

echo "✅ Chat context management initialized"
EOF

# Create comprehensive container entrypoint
RUN cat > /usr/local/bin/ollama-entrypoint.sh << 'EOF'
#!/bin/bash
echo "🐳 Ollama Container Entrypoint - Intel Arc GPU Optimized"

# Exit on error
set -e

# Create comprehensive startup log
STARTUP_LOG="/tmp/container-startup.log"
exec 1> >(tee -a "$STARTUP_LOG")
exec 2> >(tee -a "$STARTUP_LOG" >&2)

echo "$(date): Container startup initiated" >> "$STARTUP_LOG"

# Step 1: Initialize Intel GPU environment
echo "🔧 Initializing Intel GPU environment..."
if [ -f "/llm/scripts/init-intel-gpu-optimized.sh" ]; then
source /llm/scripts/init-intel-gpu-optimized.sh
echo "✅ Intel GPU environment initialized"
else
echo "⚠️  GPU initialization script not found"
fi

# Step 2: Initialize chat context system
echo "💬 Initializing chat context system..."
if [ -f "/llm/scripts/init-chat-context.sh" ]; then
source /llm/scripts/init-chat-context.sh
echo "✅ Chat context system initialized"
else
echo "⚠️  Chat context initialization script not found"
fi

# Step 3: Verify critical components
echo "🔍 Verifying critical components..."

# Check GPU access
if [ -c "/dev/dri/renderD129" ]; then
echo "✅ GPU device accessible"
else
echo "⚠️  GPU device not accessible - check Docker device mounts"
fi

# Check OneAPI
if [ -d "/opt/intel/oneapi" ]; then
echo "✅ Intel OneAPI available"
else
echo "⚠️  Intel OneAPI not found"
fi

# Check Ollama binary
if [ -f "/llm/ollama/ollama" ]; then
echo "✅ Ollama binary ready"
else
echo "❌ Ollama binary not found"
exit 1
fi

# Step 4: Execute the passed command or default startup
echo "🚀 Starting container services..."

if [ $# -eq 0 ]; then
# Default: start Ollama with optimizations
echo "Starting Ollama with Intel Arc GPU optimizations..."
exec /llm/scripts/start-ollama-optimized.sh
else
# Execute passed command
echo "Executing custom command: $*"
exec "$@"
fi

echo "$(date): Container startup completed" >> "$STARTUP_LOG"
EOF

# Make all scripts executable
RUN chmod +x /llm/scripts/init-intel-gpu-optimized.sh \
    /llm/scripts/start-ollama-optimized.sh \
    /llm/scripts/init-chat-context.sh \
    /llm/bin/gpu-diagnostics-comprehensive \
    /usr/local/bin/ollama-entrypoint.sh

# Scripts are built into the image - no need to copy from host

# Add scripts to PATH
ENV PATH="/llm/bin:/llm/scripts:/llm/ollama:/opt/ipex-llm-env/bin:/opt/intel/oneapi/compiler/latest/linux/bin:$PATH"

# Set working directory
WORKDIR /llm

# Create version info file
RUN echo "Ollama Intel Arc GPU Optimized Container" > /llm/VERSION && \
    echo "Built: $(date)" >> /llm/VERSION && \
    echo "Features:" >> /llm/VERSION && \
    echo "  - Intel Arc A770 GPU optimization" >> /llm/VERSION && \
    echo "  - Integrated OneAPI environment" >> /llm/VERSION && \
    echo "  - Chat context management" >> /llm/VERSION && \
    echo "  - Comprehensive diagnostics" >> /llm/VERSION && \
    echo "  - Performance monitoring" >> /llm/VERSION

# Health check with enhanced validation
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD /llm/bin/gpu-diagnostics-comprehensive >/dev/null 2>&1 && \
    curl -f http://localhost:11434/api/tags >/dev/null 2>&1 || exit 1

# Expose Ollama port
EXPOSE 11434

# Use optimized entrypoint
ENTRYPOINT ["/usr/local/bin/ollama-entrypoint.sh"]

# Default command
CMD []
