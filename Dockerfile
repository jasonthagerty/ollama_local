# Multi-stage Dockerfile for Intel Arc GPU optimized Ollama
# Supports environment variables from .env via docker-compose build args

# Build arguments from docker-compose/.env
ARG UBUNTU_VERSION=24.04
ARG PYTHON_VERSION=3.12
ARG ONEAPI_VERSION=2025.2
ARG IPEX_VERSION=2.7.0
ARG INTEL_GPU=1
ARG INTEL_DEVICE_TARGET=arc
ARG DEVICE=Arc

FROM ubuntu:${UBUNTU_VERSION}

# Re-declare ARGs after FROM to use them in this stage
ARG UBUNTU_VERSION
ARG PYTHON_VERSION
ARG ONEAPI_VERSION
ARG IPEX_VERSION
ARG INTEL_GPU
ARG INTEL_DEVICE_TARGET
ARG DEVICE

# Set environment variables for Intel GPU and Arc GPU targeting
ENV DEBIAN_FRONTEND=noninteractive \
    INTEL_GPU=${INTEL_GPU} \
    OLLAMA_INTEL_GPU=true \
    ZES_ENABLE_SYSMAN=1 \
    ZE_ENABLE_PCI_ID_DEVICE_ORDER=1 \
    ONEAPI_DEVICE_SELECTOR=level_zero:0 \
    DEVICE=${DEVICE} \
    SYCL_CACHE_PERSISTENT=1 \
    DRI_PRIME=1 \
    OLLAMA_GPU_DEVICE=/dev/dri/renderD129 \
    NEO_DISABLE_MITIGATIONS=1 \
    SYCL_DEVICE_FILTER=level_zero:gpu \
    ZE_FLAT_DEVICE_HIERARCHY=COMPOSITE \
    INTEL_DEVICE_TARGET=${INTEL_DEVICE_TARGET} \
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
    python3 \
    python3-pip \
    python3-venv \
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
    # Install build dependencies (remove these later)
    apt-get install -y --no-install-recommends \
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
    # Try to install Intel GPU tools (optional)
    for pkg in intel-gpu-tools clinfo; do \
    apt-get install -y --no-install-recommends $pkg 2>/dev/null || echo "Package $pkg not available in standard repos"; \
    done && \
    \
    # Clean apt cache
    rm -rf /var/lib/apt/lists/* && \
    \
    # Add Intel oneAPI repository
    (wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB 2>/dev/null | \
    gpg --dearmor --output /usr/share/keyrings/oneapi-archive-keyring.gpg 2>/dev/null && \
    echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" > /etc/apt/sources.list.d/oneAPI.list && \
    echo "Intel oneAPI repository added") || \
    echo "Intel oneAPI repository not available, continuing without it" && \
    \
    # Add Intel GPU repository
    (wget -qO- https://repositories.intel.com/gpu/intel-graphics.key 2>/dev/null | \
    gpg --dearmor --output /usr/share/keyrings/intel-graphics.gpg 2>/dev/null && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu jammy client" > /etc/apt/sources.list.d/intel-gpu.list && \
    echo "Intel GPU repository added") || \
    echo "Intel GPU repository not available, continuing with available packages" && \
    \
    # Update package lists with Intel repositories
    apt-get update 2>/dev/null || echo "Some repositories failed to update, continuing with available packages" && \
    \
    # Install Intel packages
    INTEL_PACKAGES="intel-opencl-icd intel-level-zero-gpu level-zero intel-media-driver intel-media-va-driver-non-free intel-compute-runtime intel-graphics-compiler libze1 intel-gmmlib libmfx1 libvpl2 onevpl-intel-gpu libvpl-tools" && \
    for pkg in $INTEL_PACKAGES; do \
    echo "Trying to install $pkg..." && \
    (apt-get install -y --no-install-recommends $pkg 2>/dev/null && echo "✓ Installed $pkg") || echo "✗ $pkg not available"; \
    done && \
    \
    # Install Intel oneAPI packages
    ONEAPI_PACKAGES="intel-oneapi-toolkit intel-oneapi-compiler-dpcpp-cpp intel-oneapi-mkl intel-oneapi-runtime-dpcpp-cpp intel-oneapi-runtime-mkl intel-oneapi-runtime-opencl intel-oneapi-compiler-dpcpp-cpp-${ONEAPI_VERSION} intel-oneapi-mkl-${ONEAPI_VERSION}" && \
    for pkg in $ONEAPI_PACKAGES; do \
    echo "Trying to install $pkg..." && \
    (apt-get install -y --no-install-recommends $pkg 2>/dev/null && echo "✓ Installed $pkg") || echo "✗ $pkg not available"; \
    done && \
    \
    # Create Python virtual environment for IPEX-LLM
    python3 -m venv /opt/ipex-llm-env && \
    /opt/ipex-llm-env/bin/pip install --no-cache-dir --upgrade pip setuptools wheel && \
    \
    # Install PyTorch CPU version first
    /opt/ipex-llm-env/bin/pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu && \
    \
    # Install Intel Extension for PyTorch (IPEX)
    (/opt/ipex-llm-env/bin/pip install --no-cache-dir intel-extension-for-pytorch && echo "✓ IPEX installed") || \
    (/opt/ipex-llm-env/bin/pip install --no-cache-dir intel-extension-for-pytorch==${IPEX_VERSION}.* && echo "✓ IPEX ${IPEX_VERSION} installed") || \
    echo "✗ IPEX not available, continuing without it" && \
    \
    # Install essential ML packages
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
    # Install Intel ML optimization packages
    INTEL_ML_PACKAGES="optimum-intel neural-compressor intel-extension-for-transformers scikit-learn-intelex" && \
    for pkg in $INTEL_ML_PACKAGES; do \
    echo "Trying to install $pkg..." && \
    (/opt/ipex-llm-env/bin/pip install --no-cache-dir $pkg && echo "✓ Installed $pkg") || echo "✗ $pkg not available"; \
    done && \
    \
    # Install GPU monitoring tools (optional)
    /opt/ipex-llm-env/bin/pip install --no-cache-dir gpustat py3nvml 2>/dev/null || echo "GPU monitoring tools not available" && \
    \
    # Create necessary directories
    mkdir -p /llm/ollama /llm/scripts /llm/bin /root/.ollama /tmp/sycl_cache /llm/data/contexts /llm/data/backups /llm/data/exports && \
    chmod 777 /tmp/sycl_cache && \
    \
    # Install Ollama
    curl -fsSL https://ollama.com/install.sh | sh && \
    cp /usr/local/bin/ollama /llm/ollama/ && \
    chmod +x /llm/ollama/ollama && \
    \
    # Create SYCL device listing script
    cat > /usr/local/bin/sycl-ls << 'SYCL_EOF'
#!/bin/bash
export LD_LIBRARY_PATH="/opt/intel/oneapi/umf/0.11/lib:/opt/intel/oneapi/compiler/${ONEAPI_VERSION}/lib:/opt/intel/oneapi/umf/0.11/lib:/opt/intel/oneapi/compiler/latest/linux/lib:/opt/intel/oneapi/compiler/latest/linux/lib/x64"
if [ -f "/opt/intel/oneapi/compiler/latest/linux/bin/sycl-ls" ]; then
/opt/intel/oneapi/compiler/latest/linux/bin/sycl-ls "$@"
elif [ -f "/opt/intel/oneapi/compiler/${ONEAPI_VERSION}/linux/bin/sycl-ls" ]; then
/opt/intel/oneapi/compiler/${ONEAPI_VERSION}/linux/bin/sycl-ls "$@"
else
echo "SYCL device listing tool not found"
echo "Available OneAPI components:"
ls -la /opt/intel/oneapi/ 2>/dev/null || echo "OneAPI not installed"
fi
SYCL_EOF

RUN chmod +x /usr/local/bin/sycl-ls && \
    # Create Intel GPU information script
    cat > /usr/local/bin/gpu-info << 'GPU_EOF'
#!/bin/bash
echo "=== Intel GPU Information ==="
echo "DRI devices:"
ls -la /dev/dri/ 2>/dev/null || echo "No DRI devices found"
echo ""
echo "VA-API info:"
vainfo 2>/dev/null || echo "VA-API not available"
echo ""
echo "OpenCL devices:"
clinfo -l 2>/dev/null || echo "OpenCL not available"
echo ""
echo "SYCL devices:"
sycl-ls 2>/dev/null || echo "SYCL not available"
echo ""
echo "GPU utilization:"
timeout 3s intel_gpu_top -l 2>/dev/null | head -5 || echo "intel_gpu_top not available"
GPU_EOF

RUN chmod +x /usr/local/bin/gpu-info && \
    # Create comprehensive GPU test script
    cat > /usr/local/bin/test-gpu << 'TEST_EOF'
#!/bin/bash
echo "🧪 Intel Arc GPU Test Suite"
echo "=========================="
echo "Environment: $DEVICE (Target: $INTEL_DEVICE_TARGET)"
echo ""

# Test 1: Device availability
echo "1. Testing GPU device access..."
if [ -c "$OLLAMA_GPU_DEVICE" ]; then
echo "✓ GPU device $OLLAMA_GPU_DEVICE is accessible"
else
echo "✗ GPU device $OLLAMA_GPU_DEVICE not found"
fi

# Test 2: SYCL runtime
echo ""
echo "2. Testing SYCL runtime..."
if sycl-ls 2>/dev/null | grep -i "level.*zero\|intel.*arc" >/dev/null; then
echo "✓ SYCL Level Zero runtime working"
sycl-ls 2>/dev/null | grep -i "level.*zero\|intel.*arc"
else
echo "✗ SYCL Level Zero runtime not working"
fi

# Test 3: OpenCL
echo ""
echo "3. Testing OpenCL..."
if clinfo -l 2>/dev/null | grep -i intel >/dev/null; then
echo "✓ Intel OpenCL runtime working"
else
echo "✗ Intel OpenCL runtime not working"
fi

# Test 4: Python IPEX environment
echo ""
echo "4. Testing Python IPEX environment..."
if /opt/ipex-llm-env/bin/python -c "import intel_extension_for_pytorch as ipex; print(f'✓ IPEX version: {ipex.__version__}')" 2>/dev/null; then
echo "✓ Intel Extension for PyTorch working"
else
echo "✗ Intel Extension for PyTorch not working"
fi

# Test 5: GPU memory info
echo ""
echo "5. GPU memory information..."
if command -v intel_gpu_top >/dev/null; then
timeout 2s intel_gpu_top -l 2>/dev/null | grep -E "GPU|Memory" | head -3 || echo "GPU memory info not available"
else
echo "intel_gpu_top not available"
fi

echo ""
echo "Test completed!"
TEST_EOF

RUN chmod +x /usr/local/bin/test-gpu && \
    # Remove build dependencies to reduce image size
    apt-get remove -y \
    build-essential \
    cmake \
    git \
    wget \
    python3-dev \
    libegl1-mesa-dev \
    libgl1-mesa-dev \
    libgles2-mesa-dev \
    mesa-common-dev && \
    # Final cleanup
    apt-get autoremove -y && \
    apt-get autoclean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    # Set up oneAPI environment
    echo "source /opt/intel/oneapi/setvars.sh --force" >> /etc/bash.bashrc

# Create a startup script that sources oneAPI environment
RUN cat > /usr/local/bin/ollama-startup << 'STARTUP_EOF'
#!/bin/bash
set -e

# Source Intel oneAPI environment
if [ -f "/opt/intel/oneapi/setvars.sh" ]; then
source /opt/intel/oneapi/setvars.sh --force >/dev/null 2>&1
fi

# Set up environment paths
export PATH="/opt/intel/oneapi/compiler/latest/linux/bin:/llm/bin:/llm/ollama:/opt/ipex-llm-env/bin:$PATH"
export LD_LIBRARY_PATH="/opt/intel/oneapi/umf/0.11/lib:/opt/intel/oneapi/compiler/latest/linux/lib:/opt/intel/oneapi/compiler/latest/linux/lib/x64:$LD_LIBRARY_PATH"

# Verify GPU access
echo "🚀 Starting Ollama with Intel Arc GPU optimization..."
echo "GPU Device: $OLLAMA_GPU_DEVICE"
echo "Intel Device Target: $INTEL_DEVICE_TARGET"
echo "OneAPI Device Selector: $ONEAPI_DEVICE_SELECTOR"

# Check GPU device accessibility
if [ ! -c "$OLLAMA_GPU_DEVICE" ]; then
echo "⚠️  Warning: GPU device $OLLAMA_GPU_DEVICE not accessible"
fi

# Start Ollama
exec /usr/local/bin/ollama "$@"
STARTUP_EOF

RUN chmod +x /usr/local/bin/ollama-startup

# Set the working directory
WORKDIR /llm

# Expose Ollama port
EXPOSE 11434

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:11434/api/tags || exit 1

# Use the startup script as entrypoint
ENTRYPOINT ["/usr/local/bin/ollama-startup"]
CMD ["serve"]

# Labels for metadata
LABEL org.opencontainers.image.title="Ollama Intel Arc GPU Optimized"
LABEL org.opencontainers.image.description="Ollama with Intel Arc GPU acceleration using IPEX-LLM"
LABEL org.opencontainers.image.version="1.0"
LABEL org.opencontainers.image.vendor="Custom Build"
LABEL intel.gpu.target="${INTEL_DEVICE_TARGET}"
LABEL intel.device="${DEVICE}"
LABEL ipex.version="${IPEX_VERSION}"
LABEL ubuntu.version="${UBUNTU_VERSION}"
