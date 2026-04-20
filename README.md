# Custom Ramalama container images

Custom container images for Ramalama with the latest llama.cpp for Vulkan and ROCm GPU backends. Intended to be upstreamed as much as possible.

### Why use this?

Use when you need to run an LLM but don't want to use a cloud provider. Running locally gives you:

- **Data privacy**: Keep your code and documents on your machine
- **Open models**: Many have open weights, some with open training data
- **Control**: Choose and maintain your model without unexpected changes
- **No fees**: No API costs or per-token charges
- **Offline**: Works without internet access

## Quick Start

### Vulkan

**For:** Any GPU with Vulkan support (AMD, NVIDIA, Intel).

Open standard with faster builds and runtime in most cases.

Auto-detects primary GPU (dGPU on systems with both iGPU and dGPU).

```bash
podman build -f Containerfile.vulkan -t localhost/vulkan:latest .

ramalama serve --image localhost/vulkan:latest granite4:micro-h
```

### ROCm

**For:** AMD GPUs only.

```bash
podman build -f Containerfile.rocm -t localhost/rocm:latest .

ramalama serve --image localhost/rocm:latest granite4:micro-h
```

**Multi-GPU:** If you have an integrated GPU on your CPU and also a dedicated GPU card, you may need to set `HIP_VISIBLE_DEVICES` environment variable (`--env "HIP_VISIBLE_DEVICES=0"`).

## Extended docs

- [Examples and tuning](docs/EXAMPLES.md) - Model-specific examples, architecture notes, and tuning guides.
- [Reference](docs/REFERENCE.md) - Advanced usage, CLI arguments, and technical details.
- [Benchmarks](docs/BENCHMARKS.md) - Performance comparisons across different hardware and backends.

## Glossary

- **Quantization (quant)**: Reduced model precision to save memory. `Q4_K_M` = 4-bit, medium quality.
- **Dense**: All parameters activated per token.
- **MoE (Mixture of Experts)**: Subset of parameters activated per token.
- **Inference**: Generating outputs from inputs using a model.
- **VRAM**: GPU memory. More VRAM supports larger models and faster inference. Falls back to CPU if needed.
- **Context size**: Tokens the model can process. 131072 = 128K tokens (~100K words).
- **Token**: Basic text unit (~0.75 words).
