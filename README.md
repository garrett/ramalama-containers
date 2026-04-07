# Ramalama Container Images

Custom container images for running llama.cpp with Vulkan and ROCm backends.

**Note:** Vulkan builds faster than ROCm. ROCm requires more dependencies and compiles for multiple GPU architectures. Runtime performance varies by workload—see Benchmarking.

## Backends

### Vulkan (Stable)

**Best for:** Conversations, faster token generation, coding, any GPU with Vulkan support

Auto-detects primary GPU (dGPU on systems with both iGPU and dGPU).

```bash
podman build -f Containerfile.vulkan -t localhost/vulkan:latest .
ramalama serve --image localhost/vulkan:latest \
    huggingface://unsloth/Qwen3.5-27B-GGUF/Qwen3.5-27B-IQ4_NL.gguf
```

### ROCm (Stable)

**Best for:** Faster prompt processing, large inputs, coding, AMD GPU only

```bash
podman build -f Containerfile.rocm -t localhost/rocm:latest .
ramalama serve --image localhost/rocm:latest \
    huggingface://unsloth/Qwen3.5-27B-GGUF/Qwen3.5-27B-IQ4_NL.gguf
```

Multi-GPU: use `HIP_VISIBLE_DEVICES` to select GPU:
```bash
ramalama serve --image localhost/rocm:latest \
    --env "HIP_VISIBLE_DEVICES=0" \
    huggingface://unsloth/Qwen3.5-27B-GGUF/Qwen3.5-27B-IQ4_NL.gguf
```

## Coding Agents

```bash
ramalama serve --image localhost/vulkan:latest \
    --port 8124 --temp 0.2 --thinking 0 \
    huggingface://unsloth/Qwen3.5-27B-GGUF/Qwen3.5-27B-IQ4_NL.gguf
```

**Tips:**
- `--thinking 0` recommended for coding (avoids loops, faster iteration; let linting/tools catch edge cases)
- Temperature varies by model—Qwen works well at 0.6 for coding, experiment to find optimal value
- `--temp 0.8` (default) for conversation

## Real-World Examples

### Qwen3.5-27B with Flash Attention and 128K Context
```bash
ramalama serve \
    --image localhost/vulkan:latest \
    --port 8123 --temp 0.6 --thinking 0 --ctx-size 131072 \
    --runtime-args " \
    --batch-size 4096 --ubatch-size 2048 \
    --parallel 1 --context-shift \
    --flash-attn on --rope-freq-base 1000000 \
    -ctk q4_0 -ctv q4_0" \
    hf://unsloth/Qwen3.5-27B-GGUF/Qwen3.5-27B-UD-Q4_K_XL.gguf
```

### Qwen3.5-35B-A3B

```bash
ramalama serve \
    --image localhost/vulkan:latest \
    --port 8123 --temp 0.6 --thinking 0 --ctx-size 131072 \
    --runtime-args " \
    --batch-size 4096 --ubatch-size 2048 \
    --parallel 1 --context-shift \
    --flash-attn on --rope-freq-base 1000000 \
    -ctk q4_0 -ctv q4_0" \
    hf://unsloth/Qwen3.5-35B-A3B-GGUF/Qwen3.5-35B-A3B-UD-IQ4_NL.gguf
```

### Gemma-4-26B-A4B

```bash
ramalama serve \
    --image localhost/vulkan:latest \
    --port 8123 --temp 0.6 --thinking 0 --ctx-size 131072 \
    --runtime-args " \
    --parallel 1 --context-shift --flash-attn on \
    -ctk q4_0 -ctv q4_0" \
    huggingface://unsloth/gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q4_K_M.gguf
```

### Hardware Notes

These examples are tested on **Ryzen 9 7950X3D + RX 7900 XTX (24GB VRAM)** with 64GB system RAM.

#### Tuning for Different VRAM Sizes

- **16GB VRAM**: Reduce `--batch-size` to 2048, use `-ctk q8_0 -ctv q8_0` or consider smaller models
- **24GB VRAM** (current examples): `--batch-size 4096 --ubatch-size 2048` with `-ctk q4_0 -ctv q4_0` works well for 27B-35B models
- **32GB+ VRAM**: Can increase `--batch-size` to 8192 for faster prompt processing

> **Note:** For detailed argument documentation, see the [Reference](#reference) section below.

## Version Control

By default, containers build from `master` branch.

**Development (latest features):**
```bash
podman build -f Containerfile.rocm -t localhost/rocm:latest .
```

**Production (reproducible builds):**
```bash
podman build --build-arg LLAMA_CPP_REF=bc05a6803e48f17e0f2c7a99fce9b50d03882de7 \
    -f Containerfile.rocm \
    -t localhost/rocm:20250607 .
```

`LLAMA_CPP_REF` accepts branches, commit hashes, tags, or remote refs.

**Debug builds (for troubleshooting):**
```bash
podman build --env RAMALAMA_IMAGE_BUILD_DEBUG_MODE=y \
    -f Containerfile.rocm \
    -t localhost/rocm:debug .
```

Setting `RAMALAMA_IMAGE_BUILD_DEBUG_MODE=y` builds llama.cpp with debug symbols (Debug config), installs debug tools (gdb, strace), and preserves source files in the container for troubleshooting.

## Benchmarking

```bash
ramalama bench --image localhost/vulkan:latest \
    huggingface://unsloth/Qwen3.5-27B-GGUF/Qwen3.5-27B-IQ4_NL.gguf
ramalama bench --image localhost/rocm:latest \
    huggingface://unsloth/Qwen3.5-27B-GGUF/Qwen3.5-27B-IQ4_NL.gguf
```

### Performance Results (Qwen3.5-27B-IQ4_NL, Ryzen 9 7950X3D + RX 7900 XTX)

| Backend | pp512 (tokens/s) | tg128 (tokens/s) |
|---------|------------------|------------------|
| Vulkan | 874–882 | 42 |
| ROCm | 1042–1045 | 34–35 |

### What This Means

- **pp512 (prompt processing)**: ROCm processes *input* 18–20% faster. Better for pasting code files or long prompts.
- **tg128 (token generation)**: Vulkan generates *output* 20–24% faster. Better for conversations and code streaming.

### Which to Choose

- Use **ROCm** for large code files or faster initial analysis
- Use **Vulkan** for faster streaming output during generation
- Both work well for coding—choose based on workflow preference
- For multi-GPU ROCm, use `HIP_VISIBLE_DEVICES` to select GPU

## Reference

### Native Ramalama CLI Arguments

- `--ctx-size 131072` - 128K context window
- `--temp 0.6` - Response temperature (0.0 = greedy, 0.8 = default, higher = more creative)
- `--thinking 0` - Disable thinking mode (recommended for coding tasks)
- `--ngl N` - GPU layers to offload (default: 999 = all layers; reduce if VRAM limited)

### Llama.cpp Runtime Arguments

These are passed via `--runtime-args "..."`:

**Performance Tuning:**
- `--batch-size 4096` - Logical batch size (default: 2048); higher = faster prompt processing, more VRAM
- `--ubatch-size 2048` - Physical batch size (default: 512); keep ≤ `--batch-size`
- `-np 1` / `--parallel 1` - Single server slot; improves cache efficiency, especially for Gemma

**Context and Attention:**
- `--flash-attn on` - Flash attention; faster inference with lower VRAM usage (default: auto)
- `--rope-freq-base 1000000` - RoPE frequency scaling; **required for 128K context** (default: from model)
- `--context-shift` - Context shifting for infinite/long text generation (default: disabled)

**Memory Optimization:**
- `-ctk q4_0 -ctv q4_0` - KV cache quantization (Q4_0); reduces VRAM usage (omit for full precision)
- `--mmap` - Memory-mapped files (enabled by default); faster load times, good for systems with plenty of RAM

### Model Downloads

Use transport prefixes: `hf://`, `huggingface://`, `file://`, `oci://`.

**Troubleshooting:** If a `hf://` model download doesn't work, it might be because the upstream ramalama code has a placeholder for downloading. Fix it by editing `~/.local/lib/python*/site-packages/ramalama/transports/huggingface.py` and replacing the `get_cli_download_args` method with this:

```python
def get_cli_download_args(self, directory_path, model):
    return ["download", self.repo_id, self.model_filename, "--local-dir", directory_path]
```
This tells ramalama to use the `hf` command with the right `--local-dir` option when downloading.
