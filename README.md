# Ramalama Container Images

Custom container images for running llama.cpp with ROCm and Vulkan backends.

## Quick Start

### Build

```bash
# ROCm (AMD GPU)
podman build -f Containerfile.rocm -t localhost/rocm:latest .

# Vulkan (any GPU with Vulkan support)
podman build -f Containerfile.vulkan -t localhost/vulkan:latest .
```

### Use

```bash
# ROCm
ramalama serve --image localhost/rocm:latest \
    --threads 16 --ctx-size 131072 --port 8123 --temp 0.2 \
    huggingface://unsloth/Qwen3.5-27B-GGUF/Qwen3.5-27B-IQ4_NL.gguf

# Vulkan
ramalama serve --image localhost/vulkan:latest \
    --threads 16 --ctx-size 131072 --port 8123 --temp 0.2 \
    huggingface://unsloth/Qwen3.5-27B-GGUF/Qwen3.5-27B-IQ4_NL.gguf
```

## Alternative Names

```bash
podman build -f Containerfile.rocm -t localhost/rocm-llama:latest .
podman build -f Containerfile.vulkan -t localhost/vulkan-llama:latest .
```

## Build Options

### Custom GPU Targets (ROCm only)

```bash
podman build --build-arg GPU_TARGETS="gfx1100,gfx1102" -f Containerfile.rocm -t localhost/rocm:latest .
```

Default: `gfx1010,gfx1012,gfx1030,gfx1032,gfx1100,gfx1101,gfx1102,gfx1103,gfx1151,gfx1200,gfx1201`

### Custom llama.cpp Commit

```bash
podman build --build-arg LLAMA_CPP_COMMIT=<commit> -f Containerfile.rocm -t localhost/rocm:latest .
```

### Debug Build

```bash
podman build --build-arg RAMALAMA_IMAGE_BUILD_DEBUG_MODE=y -f Containerfile.rocm -t localhost/rocm:latest .
```

## GPU Device Passthrough

If needed, pass GPU devices to the container:

```bash
# ROCm
ramalama serve --image localhost/rocm:latest \
    --device /dev/kfd --device /dev/dri [model]

# Vulkan
ramalama serve --image localhost/vulkan:latest \
    --device /dev/dri [model]
```

## Verification

```bash
# Check built images
podman images | grep -E "rocm|vulkan"

# Verify binaries
podman run --rm localhost/rocm:latest ls /usr/bin/llama-server
podman run --rm localhost/vulkan:latest ls /usr/bin/llama-server
```

## Notes

- Containers use Fedora 44 as base
- llama.cpp is built from source with latest commit by default
- Multi-stage builds keep runtime images lean
- Follows Ramalama upstream best practices
- Uses `--mount=type=bind` for efficient layer usage
- Fails on CMake warnings for early issue detection
- ccache enabled for faster rebuilds