#!/bin/bash

set -eux -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

DEFAULT_LLAMA_CPP_BRANCH="master"

LLAMA_CPP_REPO="${LLAMA_CPP_REPO:-https://github.com/ggml-org/llama.cpp}"
LLAMA_CPP_REF="${LLAMA_CPP_PULL_REF:-$DEFAULT_LLAMA_CPP_BRANCH}"

BACKEND="${1-}"
ACTION="${2-}"
SKIP_DEPS="${SKIP_DEPS:-}"

if [ -z "$BACKEND" ]; then
    echo "Usage: $0 <rocm|mesa> [runtime]"
    exit 1
fi

. /etc/os-release

dnf_install_rocm() {
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
    fi
}



dnf_install_mesa() {
    dnf install -y --exclude "selinux-policy,container-selinux" \
        gcc-c++ \
        cmake \
        git \
        make \
        ccache \
        vulkan-loader-devel \
        vulkan-headers \
        vulkan-tools \
        spirv-tools \
        spirv-headers-devel \
        glslc \
        glslang
}

dnf_install_rocm_runtime() {
    dnf install -y --setopt=install_weak_deps=false --exclude "selinux-policy,container-selinux" \
        hipblas \
        rocblas \
        rocm-hip \
        rocm-runtime \
        rocsolver \
        libgomp
}

dnf_install_mesa_runtime() {
    dnf install -y --setopt=install_weak_deps=false --exclude "selinux-policy,container-selinux" \
        vulkan-loader \
        vulkan-tools \
        mesa-vulkan-drivers \
        libgomp
}

clone_llama_cpp() {
    git_clone_specific_commit "$LLAMA_CPP_REPO" "$LLAMA_CPP_REF"
}

cmake_steps() {
    local backend="${1}"
    local install_prefix="/tmp/install"
    
    # Set SOURCE_DATE_EPOCH for reproducible builds
    SOURCE_DATE_EPOCH=$(git log -1 --pretty=%ct)
    export SOURCE_DATE_EPOCH
    
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
    
    case "$backend" in
        rocm)
            if [ "$ID" = "fedora" ]; then
                cmake_flags+=("-DCMAKE_HIP_COMPILER_ROCM_ROOT=/usr")
            fi
            cmake_flags+=(
                "-DGGML_HIP=ON"
                "-DGPU_TARGETS=${GPU_TARGETS:-gfx1010,gfx1012,gfx1030,gfx1032,gfx1100,gfx1101,gfx1102,gfx1103,gfx1151,gfx1200,gfx1201}"
            )
            ;;
        mesa)
            cmake_flags+=("-DGGML_VULKAN=1")
            ;;
        *)
            echo "Unknown backend: $backend"
            exit 1
            ;;
    esac
    
    cmake -B build "${cmake_flags[@]}" 2>&1 | cmake_check_warnings
    local build_config=Release
    if [[ "${RAMALAMA_IMAGE_BUILD_DEBUG_MODE:-}" == y ]]; then
        build_config=Debug
    fi
    cmake --build build --config "$build_config" -j"$(nproc)" 2>&1 | cmake_check_warnings
    cmake --install build 2>&1 | cmake_check_warnings
}

clone_and_build_llama_cpp() {
    clone_llama_cpp
    cmake_steps "$BACKEND"
}



cleanup() {
    available dnf && dnf -y clean all
    ldconfig # needed for libraries
}

dnf_install_runtime_deps() {
    local backend="${1}"
    case "$backend" in
        rocm)
            dnf_install_rocm_runtime
            ;;
        mesa)
            dnf_install_mesa_runtime
            ;;
    esac
    cleanup
}

main() {
    if [ "$ACTION" = "runtime" ]; then
        dnf_install_runtime_deps "$BACKEND"
        exit 0
    fi
    
    if [ -z "$SKIP_DEPS" ]; then
        case "$BACKEND" in
            rocm)
                dnf_install_rocm
                ;;
            mesa)
                dnf_install_mesa
                ;;
            *)
                echo "Unknown backend: $BACKEND"
                exit 1
                ;;
        esac
    fi
    
    if [[ "${RAMALAMA_IMAGE_BUILD_DEBUG_MODE:-}" == y ]]; then
        dnf install -y gdb strace
    fi
    
    clone_and_build_llama_cpp
    cleanup
    
    if [ "${RAMALAMA_IMAGE_BUILD_DEBUG_MODE:-}" != "y" ]; then
        cd ..
        rm -rf llama.cpp
    fi
}

main
