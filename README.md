# Ramalama Container Images

Custom container images for running llama.cpp with ROCm and Vulkan backends.

## Quick Start

### Build

```bash
# Vulkan (any GPU with Vulkan support)
podman build -f Containerfile.vulkan -t localhost/vulkan:latest .

# ROCm (AMD GPU only)
podman build -f Containerfile.rocm -t localhost/rocm:latest .
```

**Note:** Vulkan builds typically complete faster than ROCm builds. ROCm requires more dependencies and compiles for multiple GPU architectures. Runtime performance varies by workload—use the Benchmarking section below to compare on your hardware.

### Run

```bash
# Vulkan (any GPU with Vulkan support)
ramalama serve --image localhost/vulkan:latest \
    huggingface://unsloth/Qwen3.5-27B-GGUF/Qwen3.5-27B-IQ4_NL.gguf

# ROCm (AMD GPU only)
ramalama serve --image localhost/rocm:latest \
    huggingface://unsloth/Qwen3.5-27B-GGUF/Qwen3.5-27B-IQ4_NL.gguf
```

## Multi-GPU Support

### Vulkan (iGPU + dGPU)

Vulkan auto-detects and uses the primary GPU (dGPU on systems with both iGPU and dGPU).

### ROCm (AMD GPU only)

For ROCm with multiple AMD GPUs, use `HIP_VISIBLE_DEVICES` to select which GPU to use:

```bash
# Select GPU 0
ramalama serve --image localhost/rocm:latest \
    --env "HIP_VISIBLE_DEVICES=0" \
    huggingface://unsloth/Qwen3.5-27B-GGUF/Qwen3.5-27B-IQ4_NL.gguf

# Select GPU 1
ramalama serve --image localhost/rocm:latest \
    --env "HIP_VISIBLE_DEVICES=1" \
    huggingface://unsloth/Qwen3.5-27B-GGUF/Qwen3.5-27B-IQ4_NL.gguf
```

## Coding Agents

For coding agents, use lower temperature for more deterministic output:

```bash
ramalama serve --image localhost/vulkan:latest \
    --port 8124 --temp 0.2 --thinking 0 \
    huggingface://unsloth/Qwen3.5-27B-GGUF/Qwen3.5-27B-IQ4_NL.gguf

ramalama serve --image localhost/rocm:latest \
    --env "HIP_VISIBLE_DEVICES=0" \
    --port 8124 --temp 0.2 --thinking 0 \
    huggingface://unsloth/Qwen3.5-27B-GGUF/Qwen3.5-27B-IQ4_NL.gguf
```

**Tips:**
- `--temp 0.2` provides deterministic output for coding; `--temp 0.8` (default) is better for conversation
- Add `--thinking 0` to disable reasoning output for cleaner, parseable results (useful for automated agents)
- For complex tasks, keeping thinking enabled may produce higher-quality code

## Advanced


### Custom llama.cpp Version

```bash
podman build --build-arg LLAMA_CPP_COMMIT=<commit> -f Containerfile.rocm -t localhost/rocm:latest .
```

## Benchmarking

Compare performance between ROCm and Vulkan backends:

```bash
# Benchmark Vulkan
ramalama bench --image localhost/vulkan:latest \
    huggingface://unsloth/Qwen3.5-27B-GGUF/Qwen3.5-27B-IQ4_NL.gguf

# Benchmark ROCm
ramalama bench --image localhost/rocm:latest \
    huggingface://unsloth/Qwen3.5-27B-GGUF/Qwen3.5-27B-IQ4_NL.gguf
```

**Performance Results (Qwen3.5-27B-IQ4_NL on Ryzen 9 7950X3D + RX 7900 XTX):**

| Backend | pp512 (tokens/s) | tg128 (tokens/s) |
|---------|------------------|------------------|
| Vulkan | 874–882 | 42 |
| ROCm | 1042–1045 | 34–35 |

**What this means:**
- **pp512 (prompt processing)**: ROCm processes your *input* 18–20% faster. When pasting code files or long prompts, ROCm starts responding sooner and can analyze your code more quickly.
- **tg128 (token generation)**: Vulkan generates *output* 20–24% faster. During conversations or code generation, Vulkan streams text more quickly.

**Which to choose:**
- Use **ROCm** for coding tasks where you paste large code files or want faster analysis
- Use **Vulkan** for conversations or when you prefer faster streaming output
- For multi-GPU ROCm systems, use `HIP_VISIBLE_DEVICES` to select which GPU to use

The benchmark reports tokens per second, time to first token, and other performance metrics.
