#!/bin/bash

# SYCL-LS Wrapper Script
# This script ensures the correct library paths are set for sycl-ls to work properly

# Set the required library paths
export LD_LIBRARY_PATH="/opt/intel/oneapi/umf/0.11/lib:/opt/intel/oneapi/compiler/2025.2/lib:${LD_LIBRARY_PATH:-}"

# Execute sycl-ls with all passed arguments
exec /opt/intel/oneapi/compiler/2025.2/bin/sycl-ls "$@"
