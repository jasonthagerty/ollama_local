#!/bin/bash

# Intel GPU Version Checker Script (2025 Edition)
# Validates the installation of latest Intel GPU drivers and libraries

echo "🔍 Intel GPU Software Stack Version Checker (2025)"
echo "===================================================="
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get package version
get_package_version() {
    dpkg -l | grep "^ii.*$1" | awk '{print $3}' | head -1
}

# Function to compare version numbers
version_compare() {
    local ver1=$1
    local ver2=$2
    local op=$3

    if [ "$op" = "ge" ]; then
        dpkg --compare-versions "$ver1" ge "$ver2"
    elif [ "$op" = "gt" ]; then
        dpkg --compare-versions "$ver1" gt "$ver2"
    fi
}

# System Information
echo "📋 System Information:"
echo "  OS: $(lsb_release -d 2>/dev/null | cut -f2- || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "  Kernel: $(uname -r)"
echo "  Architecture: $(uname -m)"
echo "  Date: $(date)"
echo ""

# Intel GPU Hardware Detection
echo "🔌 Intel GPU Hardware:"
if lspci | grep -i "vga\|3d\|display" | grep -qi intel; then
    echo "✅ Intel GPU detected:"
    lspci | grep -i "vga\|3d\|display" | grep -i intel | sed 's/^/    /'

    # Specific Arc GPU detection (including 2025 models)
    if lspci | grep -qi "56a0\|56a1\|56a2"; then
        echo "  🎯 Intel Arc A-Series (A770/A750/A580) detected"
    elif lspci | grep -qi "56a3\|56a4"; then
        echo "  🎯 Intel Arc A-Series (A380/A310) detected"
    elif lspci | grep -qi "5690\|5691\|5692\|5693\|5694"; then
        echo "  🎯 Intel Arc B-Series Battlemage (B580/B570) detected"
    elif lspci | grep -qi "56b0\|56b1\|56b2\|56b3\|56b4"; then
        echo "  🎯 Intel Arc C-Series (2025) detected"
    elif lspci | grep -qi "7d40\|7d45\|7d60"; then
        echo "  🎯 Intel Xe2 Lunar Lake iGPU detected"
    elif lspci | grep -qi "8a50\|8a51\|8a52"; then
        echo "  🎯 Intel Xe3 (2025) detected"
    fi
else
    echo "❌ No Intel GPU found"
fi
echo ""

# DRI Devices
echo "💾 DRI Devices:"
if [ -d "/dev/dri" ]; then
    echo "  Available devices:"
    ls -la /dev/dri/ | sed 's/^/    /'

    # Check specific Arc GPU devices
    if [ -c "/dev/dri/card1" ] && [ -c "/dev/dri/renderD129" ]; then
        echo "  ✅ Arc GPU devices (card1, renderD129) available"
    elif [ -c "/dev/dri/card0" ] && [ -c "/dev/dri/renderD128" ]; then
        echo "  ⚠️  Integrated GPU devices (card0, renderD128) found"
    fi
else
    echo "  ❌ No DRI devices found"
fi
echo ""

# Intel oneAPI Version (2025)
echo "🧰 Intel oneAPI Toolkit (2025):"
if [ -d "/opt/intel/oneapi" ]; then
    ONEAPI_VERSION=$(ls /opt/intel/oneapi/compiler/ 2>/dev/null | grep -E '^[0-9]' | sort -V | tail -1)
    if [ -n "$ONEAPI_VERSION" ]; then
        echo "  ✅ Version: $ONEAPI_VERSION"

        # Check if it's 2025 version
        if echo "$ONEAPI_VERSION" | grep -q "^2025"; then
            echo "  🎯 Latest 2025 version detected"
        elif echo "$ONEAPI_VERSION" | grep -q "^2024"; then
            echo "  ⚠️  2024 version (2025.x recommended)"
        else
            echo "  ⚠️  Older version (2025.x recommended)"
        fi

        if [ -f "/opt/intel/oneapi/setvars.sh" ]; then
            echo "  ✅ Setup script available"
        fi

        # Check specific components
        DPCPP_VERSION=$(ls /opt/intel/oneapi/compiler/$ONEAPI_VERSION/bin/ 2>/dev/null | grep icpx | wc -l)
        if [ "$DPCPP_VERSION" -gt 0 ]; then
            echo "  ✅ DPC++ Compiler available"
        fi

        if [ -d "/opt/intel/oneapi/mkl/$ONEAPI_VERSION" ]; then
            echo "  ✅ Intel MKL available"
        fi
    else
        echo "  ⚠️  Installed but version unknown"
    fi
else
    echo "  ❌ Not installed"
fi
echo ""

# Intel Compute Runtime (2025)
echo "⚡ Intel Compute Runtime (2025):"
COMPUTE_RUNTIME_VERSION=$(get_package_version "intel-compute-runtime")
if [ -n "$COMPUTE_RUNTIME_VERSION" ]; then
    echo "  ✅ Package version: $COMPUTE_RUNTIME_VERSION"

    # Check library version
    if [ -f "/usr/lib/x86_64-linux-gnu/intel-opencl/libigdrcl.so" ]; then
        LIB_VERSION=$(strings /usr/lib/x86_64-linux-gnu/intel-opencl/libigdrcl.so 2>/dev/null | grep "^[0-9][0-9]\." | head -1)
        if [ -n "$LIB_VERSION" ]; then
            echo "  ✅ Library version: $LIB_VERSION"

            # Check for 2025 versions (25.16+)
            if echo "$LIB_VERSION" | grep -q "^25\.1[6-9]\|^25\.[2-9][0-9]\|^2[6-9]\|^[3-9][0-9]"; then
                echo "  🎯 Latest 2025 version detected"
            elif echo "$LIB_VERSION" | grep -q "^25\.1[3-5]"; then
                echo "  ✅ Recent 2024 version (25.16+ recommended for 2025)"
            elif echo "$LIB_VERSION" | grep -q "^25\."; then
                echo "  ⚠️  Older 2024 version (25.16+ recommended)"
            else
                echo "  ⚠️  Legacy version (25.16+ recommended)"
            fi
        fi
    fi

    # Check for Intel Graphics Compiler
    IGC_VERSION=$(get_package_version "intel-graphics-compiler")
    if [ -n "$IGC_VERSION" ]; then
        echo "  ✅ Graphics Compiler: $IGC_VERSION"
    fi
else
    echo "  ❌ Not installed"
fi
echo ""

# Level Zero (2025)
echo "🔗 Level Zero (2025):"
LEVEL_ZERO_VERSION=$(get_package_version "libze1")
if [ -n "$LEVEL_ZERO_VERSION" ]; then
    echo "  ✅ libze1 version: $LEVEL_ZERO_VERSION"

    # Check if loader is available
    if [ -f "/usr/lib/x86_64-linux-gnu/libze_loader.so.1" ]; then
        echo "  ✅ Level Zero loader available"
    fi
else
    echo "  ❌ libze1 not installed"
fi

LEVEL_ZERO_GPU_VERSION=$(get_package_version "intel-level-zero-gpu")
if [ -n "$LEVEL_ZERO_GPU_VERSION" ]; then
    echo "  ✅ intel-level-zero-gpu version: $LEVEL_ZERO_GPU_VERSION"
else
    echo "  ❌ intel-level-zero-gpu not installed"
fi

LEVEL_ZERO_DEV_VERSION=$(get_package_version "level-zero-dev")
if [ -n "$LEVEL_ZERO_DEV_VERSION" ]; then
    echo "  ✅ level-zero-dev version: $LEVEL_ZERO_DEV_VERSION"
fi
echo ""

# OpenCL (2025)
echo "🎮 OpenCL (2025):"
OPENCL_VERSION=$(get_package_version "intel-opencl-icd")
if [ -n "$OPENCL_VERSION" ]; then
    echo "  ✅ intel-opencl-icd version: $OPENCL_VERSION"
else
    echo "  ❌ intel-opencl-icd not installed"
fi

# Check OpenCL platforms
if command_exists clinfo; then
    echo "  📊 OpenCL Platforms:"
    OPENCL_OUTPUT=$(clinfo 2>/dev/null | grep -E "(Platform Name|Device Name|Driver Version)" | head -10)
    if [ -n "$OPENCL_OUTPUT" ]; then
        echo "$OPENCL_OUTPUT" | sed 's/^/      /'
    else
        echo "      Failed to query platforms"
    fi
else
    echo "  ⚠️  clinfo not available"
fi
echo ""

# Intel Media Stack (2025)
echo "🎬 Intel Media Stack (2025):"
MEDIA_DRIVER_VERSION=$(get_package_version "intel-media-driver")
if [ -n "$MEDIA_DRIVER_VERSION" ]; then
    echo "  ✅ intel-media-driver version: $MEDIA_DRIVER_VERSION"
else
    echo "  ❌ intel-media-driver not installed"
fi

MEDIA_VA_VERSION=$(get_package_version "intel-media-va-driver-non-free")
if [ -n "$MEDIA_VA_VERSION" ]; then
    echo "  ✅ intel-media-va-driver-non-free version: $MEDIA_VA_VERSION"
else
    echo "  ❌ intel-media-va-driver-non-free not installed"
fi

# Check VPL (Video Processing Library)
VPL_VERSION=$(get_package_version "libvpl2")
if [ -n "$VPL_VERSION" ]; then
    echo "  ✅ Intel VPL version: $VPL_VERSION"
fi

ONEVPL_VERSION=$(get_package_version "onevpl-intel-gpu")
if [ -n "$ONEVPL_VERSION" ]; then
    echo "  ✅ OneVPL Intel GPU version: $ONEVPL_VERSION"
fi
echo ""

# Intel GPU Tools (2025)
echo "🔧 Intel GPU Tools (2025):"
if command_exists intel_gpu_top; then
    echo "  ✅ intel_gpu_top available"
else
    echo "  ❌ intel_gpu_top not available"
fi

if command_exists vainfo; then
    echo "  ✅ vainfo available"
    echo "  📊 VA-API info:"
    timeout 3s vainfo 2>/dev/null | head -5 | sed 's/^/      /' || echo "      Failed to query VA-API"
else
    echo "  ❌ vainfo not available"
fi

if command_exists vulkaninfo; then
    echo "  ✅ vulkaninfo available"
    echo "  📊 Vulkan info:"
    timeout 3s vulkaninfo --summary 2>/dev/null | grep -E "(deviceName|driverVersion)" | head -3 | sed 's/^/      /' || echo "      Failed to query Vulkan"
else
    echo "  ❌ vulkaninfo not available"
fi
echo ""

# Python Environment and IPEX (2025)
echo "🐍 Python Environment (2025):"
if [ -f "/opt/ipex-llm-env/bin/python" ]; then
    PYTHON_VERSION=$(/opt/ipex-llm-env/bin/python --version 2>&1)
    echo "  ✅ Python: $PYTHON_VERSION"

    # Check PyTorch
    TORCH_VERSION=$(/opt/ipex-llm-env/bin/python -c "import torch; print(torch.__version__)" 2>/dev/null)
    if [ -n "$TORCH_VERSION" ]; then
        echo "  ✅ PyTorch: $TORCH_VERSION"

        # Check if it's a 2025-compatible version (2.5+)
        if echo "$TORCH_VERSION" | grep -q "^2\.[5-9]\|^[3-9]\."; then
            echo "  🎯 2025-compatible PyTorch version"
        else
            echo "  ⚠️  Older PyTorch version (2.5+ recommended for 2025)"
        fi
    else
        echo "  ❌ PyTorch not available"
    fi

    # Check Intel Extension for PyTorch
    IPEX_VERSION=$(/opt/ipex-llm-env/bin/python -c "import intel_extension_for_pytorch as ipex; print(ipex.__version__)" 2>/dev/null)
    if [ -n "$IPEX_VERSION" ]; then
        echo "  ✅ Intel Extension for PyTorch: $IPEX_VERSION"

        # Check for 2025 versions
        if echo "$IPEX_VERSION" | grep -q "^2\.[5-9]"; then
            echo "  🎯 2025-compatible IPEX version"
        else
            echo "  ⚠️  Older IPEX version (2.5+ recommended)"
        fi
    else
        echo "  ❌ Intel Extension for PyTorch not available"
    fi

    # Check Intel Extension for Transformers
    IPEX_TRANS_VERSION=$(/opt/ipex-llm-env/bin/python -c "import intel_extension_for_transformers; print('Available')" 2>/dev/null)
    if [ -n "$IPEX_TRANS_VERSION" ]; then
        echo "  ✅ Intel Extension for Transformers: Available"
    else
        echo "  ❌ Intel Extension for Transformers not available"
    fi

    # Check Neural Compressor
    NC_VERSION=$(/opt/ipex-llm-env/bin/python -c "import neural_compressor; print('Available')" 2>/dev/null)
    if [ -n "$NC_VERSION" ]; then
        echo "  ✅ Neural Compressor: Available"
    fi

    # Check Intel TensorFlow
    ITF_VERSION=$(/opt/ipex-llm-env/bin/python -c "import intel_tensorflow; print('Available')" 2>/dev/null)
    if [ -n "$ITF_VERSION" ]; then
        echo "  ✅ Intel TensorFlow: Available"
    fi
else
    echo "  ❌ Intel-optimized Python environment not found"
fi
echo ""

# Environment Variables (2025)
echo "🌍 Environment Variables (2025):"
echo "  OLLAMA_INTEL_GPU: ${OLLAMA_INTEL_GPU:-not set}"
echo "  DRI_PRIME: ${DRI_PRIME:-not set}"
echo "  ONEAPI_DEVICE_SELECTOR: ${ONEAPI_DEVICE_SELECTOR:-not set}"
echo "  ZES_ENABLE_SYSMAN: ${ZES_ENABLE_SYSMAN:-not set}"
echo "  SYCL_CACHE_PERSISTENT: ${SYCL_CACHE_PERSISTENT:-not set}"
echo "  NEO_DISABLE_MITIGATIONS: ${NEO_DISABLE_MITIGATIONS:-not set}"
echo "  IPEX_LLM_NUM_CTX: ${IPEX_LLM_NUM_CTX:-not set}"
echo "  IPEX_LLM_LOW_MEM: ${IPEX_LLM_LOW_MEM:-not set}"
echo "  SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS: ${SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS:-not set}"
echo ""

# Performance Optimizations Status (2025)
echo "🚀 Performance Optimizations (2025):"
if [ "${NEO_DISABLE_MITIGATIONS:-0}" = "1" ]; then
    echo "  ✅ Security mitigations disabled (20% performance boost)"
else
    echo "  ⚠️  Security mitigations enabled (consider NEO_DISABLE_MITIGATIONS=1)"
fi

if [ "${SYCL_CACHE_PERSISTENT:-0}" = "1" ]; then
    echo "  ✅ SYCL persistent cache enabled"
else
    echo "  ⚠️  SYCL persistent cache not enabled"
fi

if [ "${IPEX_LLM_LOW_MEM:-0}" = "1" ]; then
    echo "  ✅ IPEX low memory mode enabled"
fi

if [ -d "/tmp/sycl_cache" ]; then
    CACHE_SIZE=$(du -sh /tmp/sycl_cache 2>/dev/null | cut -f1 || echo "unknown")
    echo "  ✅ SYCL cache directory exists (size: $CACHE_SIZE)"
fi
echo ""

# Ollama Integration (2025)
echo "🦙 Ollama Integration (2025):"
if command_exists
 ollama; then
    OLLAMA_VERSION=$(ollama --version 2>/dev/null | head -1 || echo "unknown")
    echo "  ✅ Ollama available: $OLLAMA_VERSION"

    if pgrep ollama >/dev/null; then
        echo "  ✅ Ollama service running"

        # Test API connectivity
        if timeout 3s curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
            echo "  ✅ Ollama API responding"
        else
            echo "  ⚠️  Ollama API not responding"
        fi
    else
        echo "  ⚠️  Ollama service not running"
    fi
else
    echo "  ❌ Ollama not available"
fi
echo ""

# Overall Status Assessment (2025)
echo "📊 Overall Status Assessment (2025):"
MISSING_COMPONENTS=0
WARNINGS=0

# Check critical components
if [ -z "$(get_package_version 'intel-compute-runtime')" ]; then
    echo "  ❌ Missing: Intel Compute Runtime"
    MISSING_COMPONENTS=$((MISSING_COMPONENTS + 1))
fi

if [ -z "$(get_package_version 'libze1')" ]; then
    echo "  ❌ Missing: Level Zero"
    MISSING_COMPONENTS=$((MISSING_COMPONENTS + 1))
fi

if [ -z "$(get_package_version 'intel-opencl-icd')" ]; then
    echo "  ❌ Missing: Intel OpenCL"
    MISSING_COMPONENTS=$((MISSING_COMPONENTS + 1))
fi

if [ ! -d "/opt/intel/oneapi" ]; then
    echo "  ❌ Missing: Intel oneAPI"
    MISSING_COMPONENTS=$((MISSING_COMPONENTS + 1))
fi

# Check for 2025 versions
ONEAPI_VERSION=$(ls /opt/intel/oneapi/compiler/ 2>/dev/null | grep -E '^[0-9]' | sort -V | tail -1)
if [ -n "$ONEAPI_VERSION" ] && ! echo "$ONEAPI_VERSION" | grep -q "^2025"; then
    echo "  ⚠️  oneAPI version not 2025.x (current: $ONEAPI_VERSION)"
    WARNINGS=$((WARNINGS + 1))
fi

if [ "${NEO_DISABLE_MITIGATIONS:-0}" != "1" ]; then
    echo "  ⚠️  Performance mitigations not disabled (missing 20% boost)"
    WARNINGS=$((WARNINGS + 1))
fi

# Final assessment
if [ $MISSING_COMPONENTS -eq 0 ]; then
    if [ $WARNINGS -eq 0 ]; then
        echo "  ✅ All components installed with 2025 optimizations"
        echo "  🎯 Ready for high-performance Intel Arc GPU acceleration"
    else
        echo "  ✅ All critical components installed"
        echo "  ⚠️  $WARNINGS optimization(s) could be improved"
        echo "  🔧 Consider updating configuration for better performance"
    fi
else
    echo "  ⚠️  $MISSING_COMPONENTS critical component(s) missing"
    if [ $WARNINGS -gt 0 ]; then
        echo "  ⚠️  $WARNINGS additional optimization(s) needed"
    fi
    echo "  🔧 Rebuild container to install missing components"
fi

echo ""
echo "🏁 Intel GPU Stack Validation Complete (2025 Edition)"
echo "====================================================="
echo ""
echo "💡 Recommendations:"
echo "  • Use Intel oneAPI 2025.2+ for best performance"
echo "  • Enable NEO_DISABLE_MITIGATIONS=1 for 20% speed boost"
echo "  • Use Compute Runtime 25.16+ for latest features"
echo "  • Configure SYCL_CACHE_PERSISTENT=1 for faster startup"
echo ""
