#!/bin/bash
#
# build_llama.sh - Build llama.cpp for ROCm and Vulkan
#
# Usage: ./build_llama.sh <backend> [runtime]
#   backend: rocm | vulkan
#   runtime: if present, only install runtime dependencies
#

set -eux -o pipefail

# Source helper library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# Configuration
DEFAULT_LLAMA_CPP_COMMIT="9c600bc"


LLAMA_CPP_REPO="${LLAMA_CPP_REPO:-https://github.com/ggml-org/llama.cpp}"
LLAMA_CPP_COMMIT="${LLAMA_CPP_PULL_REF:-$DEFAULT_LLAMA_CPP_COMMIT}"

# Parse arguments
BACKEND="${1-}"
ACTION="${2-}"
SKIP_DEPS="${SKIP_DEPS:-}"

if [ -z "$BACKEND" ]; then
    echo "Usage: $0 <rocm|vulkan> [runtime]"
    exit 1
fi

# Source OS info
. /etc/os-release

# Install build dependencies for ROCm
install_rocm_build_deps() {
    if [ "$ID" = "fedora" ]; then
        dnf update -y
        dnf install -y \
            rocm-core-devel \
            hipblas-devel \
            rocblas-devel \
            rocm-hip-devel \
            gcc-c++ \
            cmake \
            git \
            make \
            ccache
    else
        echo "ROCm build currently supports Fedora"
        exit 1
    fi
    dnf -y clean all
}

# Install build dependencies for Vulkan
install_vulkan_build_deps() {
    dnf install -y \
        gcc-c++ \
        cmake \
        git \
        make \
        ccache \
        vulkan-loader-devel \
        vulkan-headers \
        vulkan-tools \
        spirv-tools \
        glslc \
        glslang
    dnf -y clean all
}

# Install runtime dependencies for ROCm
install_rocm_runtime_deps() {
    dnf install -y --setopt=install_weak_deps=false \
        hipblas \
        rocblas \
        rocm-hip \
        rocm-runtime \
        rocsolver \
        libgomp
    dnf -y clean all
}

# Install runtime dependencies for Vulkan
install_vulkan_runtime_deps() {
    dnf install -y --setopt=install_weak_deps=false \
        vulkan-loader \
        vulkan-tools \
        libgomp
    dnf -y clean all
}

# Clone llama.cpp at specific commit
clone_llama_cpp() {
    git_clone_specific_commit "$LLAMA_CPP_REPO" "$LLAMA_CPP_COMMIT"
}

# Configure and build llama.cpp
build_llama_cpp() {
    local backend="${1}"
    local install_prefix="/tmp/install"
    
    # Set SOURCE_DATE_EPOCH for reproducible builds
    SOURCE_DATE_EPOCH=$(git log -1 --pretty=%ct)
    export SOURCE_DATE_EPOCH
    
    # Common CMake flags
    local cmake_flags=(
        "-DCMAKE_INSTALL_PREFIX=$install_prefix"
        "-DGGML_CCACHE=ON"
        "-DGGML_RPC=ON"
        "-DLLAMA_BUILD_TESTS=OFF"
        "-DLLAMA_BUILD_EXAMPLES=OFF"
        "-DGGML_BUILD_TESTS=OFF"
        "-DGGML_BUILD_EXAMPLES=OFF"
        "-DGGML_NATIVE=OFF"
        "-DGGML_BACKEND_DL=ON"
        "-DGGML_CPU_ALL_VARIANTS=ON"
        "-DGGML_CMAKE_BUILD_TYPE=Release"
    )
    
    # Backend-specific flags
    case "$backend" in
        rocm)
            if [ "$ID" = "fedora" ]; then
                cmake_flags+=("-DCMAKE_HIP_COMPILER_ROCM_ROOT=/usr")
            fi
            # GPU targets for ROCm (covers most common AMD GPUs)
            cmake_flags+=(
                "-DGGML_HIP=ON"
                "-DGPU_TARGETS=${GPU_TARGETS:-gfx1010,gfx1012,gfx1030,gfx1032,gfx1100,gfx1101,gfx1102,gfx1103,gfx1151,gfx1200,gfx1201}"
            )
            ;;
        vulkan)
            cmake_flags+=("-DGGML_VULKAN=ON")
            ;;
        *)
            echo "Unknown backend: $backend"
            exit 1
            ;;
    esac
    
    # Run CMake with warning checking
    cmake -B build "${cmake_flags[@]}" 2>&1 | cmake_check_warnings
    cmake --build build --config Release -j"$(nproc)" 2>&1 | cmake_check_warnings
    cmake --install build 2>&1 | cmake_check_warnings
}

# Cleanup build artifacts
cleanup() {
    available dnf && dnf -y clean all
    ldconfig
}

# Runtime installation from builder
install_from_builder() {
    local backend="${1}"
    local install_prefix="/tmp/install"
    
    # Copy binaries and libraries to system paths
    cp -a "$install_prefix/bin/" /usr/
    if [ -d "$install_prefix/lib64" ]; then
        cp -a "$install_prefix/lib64/*.so*" /usr/lib64/
    fi
    if [ -d "$install_prefix/lib" ]; then
        cp -a "$install_prefix/lib/*.so*" /usr/lib/
    fi
    
    # Install runtime dependencies
    case "$backend" in
        rocm)
            install_rocm_runtime_deps
            ;;
        vulkan)
            install_vulkan_runtime_deps
            ;;
    esac
    
    cleanup
}

# Main function
main() {
    # If runtime mode, only install runtime deps and exit
    if [ "$ACTION" = "runtime" ]; then
        install_from_builder "$BACKEND"
        exit 0
    fi
    
    # Install build dependencies (unless SKIP_DEPS is set)
    if [ -z "$SKIP_DEPS" ]; then
        case "$BACKEND" in
            rocm)
                install_rocm_build_deps
                ;;
            vulkan)
                install_vulkan_build_deps
                ;;
            *)
                echo "Unknown backend: $BACKEND"
                exit 1
                ;;
        esac
    fi
    
    # Clone and build
    clone_llama_cpp
    build_llama_cpp "$BACKEND"
    cleanup
    
    # Remove source if not in debug mode
    if [ "${RAMALAMA_IMAGE_BUILD_DEBUG_MODE:-}" != "y" ]; then
        cd ..
        rm -rf llama.cpp
    fi
}

main