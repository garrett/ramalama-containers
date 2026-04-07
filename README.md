# Custom Ramalama Container Images

Custom container images for Ramalama with the latest llama.cpp for Vulkan and ROCm GPU backends.

### Why Use This?

Run LLMs locally instead of in the cloud:

- **Data privacy & sovereignty**: Your code, documents, and prompts stay on your machine
- **Open & trustworthy**: Inspect what you're running instead of trusting a black box
- **Control**: Choose model versions. No unexpected behavior changes
- **Cost**: No API fees or per-token charges
- **Offline**: Works without internet access

Use for coding assistants, research, or any task requiring privacy, control, and reliability.

### Backend Choice

- **Vulkan**: Open standard, faster builds and runtime. Smaller downloads and image size. Works on AMD, NVIDIA, Intel. Recommended option in most cases.
- **ROCm**: AMD only. Longer build times. Can match Vulkan with some models, and may exceed Vulkan in some cases, but generally slower.

## Quick Start

### Vulkan

**For:** Any GPU with Vulkan support (AMD, NVIDIA, Intel). Open standard, faster builds, faster runtime in most cases.

Auto-detects primary GPU (dGPU on systems with both iGPU and dGPU).

```bash
podman build -f Containerfile.vulkan -t localhost/vulkan:latest .

ramalama serve --image localhost/vulkan:latest granite4:micro-h
```

### ROCm

**For:** AMD GPUs only. Can match or exceed Vulkan with some models, but generally slower and with longer build times.

```bash
podman build -f Containerfile.rocm -t localhost/rocm:latest .

ramalama serve --image localhost/rocm:latest granite4:micro-h
```

**Multi-GPU:** If you have an integrated GPU on your CPU and also a dedicated GPU card, you may need to set `HIP_VISIBLE_DEVICES` environment variable (`--env "HIP_VISIBLE_DEVICES=0"`).


## Examples

All examples tested on **Ryzen 9 7950X3D + RX 7900 XTX (24GB VRAM)** with 64GB system RAM. Systems with differing amounts of VRAM should be adjusted, using different models, quantizations, values, etc.

**Model architecture note:**
- **Dense models** (example: Qwen3.5-27B): All parameters activated per token. Slower but more accurate for coding. Consistent performance.
- **MoE (Mixture of Experts)** (examples: Qwen3.5-35B-A3B, Gemma-4-26B-A4B): Subset of parameters activated per token. Faster, larger models in same VRAM. Parts loaded dynamically for better memory usage. Better for general tasks and reasoning.

### Qwen3.5-27B (Dense) - Coding

Lower temperature and thinking disabled for precise coding.

```bash
ramalama serve --image localhost/vulkan:latest \
    --port 8123 --temp 0.6 --thinking 0 --ctx-size 131072 \
    --runtime-args "\
        --batch-size 4096 --ubatch-size 2048 --parallel 1 \
        --top-p 0.95 --top-k 20 --flash-attn on \
        --context-shift --rope-freq-base 1000000 \
        -ctk q4_0 -ctv q4_0" \
    hf://unsloth/Qwen3.5-27B-GGUF/Qwen3.5-27B-UD-Q4_K_XL.gguf
```

### Qwen3.5-35B-A3B (MoE) - General/Reasoning

Higher temperature for complex reasoning. Use 27B dense for faster inference if VRAM limited.

```bash
ramalama serve --image localhost/vulkan:latest \
    --port 8123 --temp 1.0 --ctx-size 131072 \
    --runtime-args "\
        --batch-size 4096 --ubatch-size 2048 --parallel 1 \
        --top-p 0.95 --top-k 20 --flash-attn on \
        --context-shift --rope-freq-base 1000000 \
        -ctk q4_0 -ctv q4_0" \
    hf://unsloth/Qwen3.5-35B-A3B-GGUF/Qwen3.5-35B-A3B-UD-IQ4_NL.gguf
```

### Gemma-4-26B-A4B (MoE) - General & Coding

All-purpose model with strong coding. Same parameters for general and coding per Google's recommendations.

```bash
ramalama serve --image localhost/vulkan:latest \
    --port 8123 --temp 1.0 --ctx-size 131072 \
    --runtime-args "\
        --batch-size 4096 --ubatch-size 2048 --parallel 1 \
        --top-p 0.95 --top-k 64 --flash-attn on \
        --context-shift -ctk q4_0 -ctv q4_0" \
    hf://unsloth/gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q4_K_M.gguf
```

**For coding:** Consider `--temp 0.7-0.8` for more deterministic code output (optional, not officially recommended).

**VRAM Tuning:**
- **16GB**: `--batch-size 2048`, `-ctk q8_0 -ctv q8_0` (or use smaller models)
- **24GB**: `--batch-size 4096 --ubatch-size 2048`, `-ctk q4_0 -ctv q4_0`
- **32GB+**: `--batch-size 8192` for faster prompt processing

### Granite 4 Micro (Code/Chat, Mamba)

```bash
ramalama serve --image localhost/vulkan:latest \
    --port 8123 --temp 0.7 --thinking 0 \
    granite4:micro-h
```

### Olmo-3-7B-Think (Reasoning)

Fast, efficient reasoning model with **open training** (not just open weights).

```bash
ramalama serve --image localhost/vulkan:latest \
    --port 8123 --temp 0.6 \
    --runtime-args "\
        --batch-size 4096 --ubatch-size 2048 --parallel 1 \
        --top-p 0.95 --top-k 40 \
        --context-shift --flash-attn on \
        -ctk q4_0 -ctv q4_0" \
    hf://allenai/Olmo-3-7B-Think-GGUF/Olmo-3-7B-Think-IQ4_NL.gguf
```

### Model Recommendations

All of the models below are at least open weights (where the models themselves are under a FOSS license) and can run locally.

**When being more open (training, not just model) matters:**
- **Olmo-3-7B-Think** - Chain of Thought reasoning, open training methodology (3.9 GB)

**For coding agents:**
- **Qwen3.5-27B-UD-Q4_K_XL** - Best overall for coding (16.4 GB)
- **Qwen3-Coder-30B-A3B** - Specialized MoE for code (16.5 GB)

**For general tasks:**
- **Qwen3.5-35B-A3B** - Larger MoE for complex tasks (16.6 GB)
- **Gemma-4-26B-A4B** - Versatile MoE all-purpose model (15.7 GB)

**For quick and simple tasks:**
- **Granite 4 Micro-H** - Ultra-fast (1.8 GB)

### Performance Comparison: Desktop vs Steam Deck

Tested with **Granite 4 Micro-H (Mamba)** using `ramalama bench --image localhost/vulkan:latest granite4:micro-h` on Ryzen 9 7950X3D + RX 7900 XTX (Desktop) and AMD Vangogh (Steam Deck).

**Benchmark metrics:**
- **pp512 (prompt processing)**: Tokens per second when processing 512-token prompt (input speed)
- **tg128 (token generation)**: Tokens per second when generating 128 tokens (output speed)

**Note:** Benchmarks use containers built from this repo unless noted. Desktop ROCm results use upstream default container; Deck ROCm was not tested with this repo's build.


| System | Hardware | Type | Input (pp512) | Output (tg128) | Status |
|--------|----------|------|---------------|----------------|--------|
| **Desktop** | 7950X3D + 7900 XTX | Vulkan GPU | 5,270.3 t/s | 177.3 t/s | ✅ Excellent |
| **Desktop** | 7950X3D + 7900 XTX | ROCm GPU | 4,173.0 t/s | 116.9 t/s | ✅ Good |
| **Desktop** | 7950X3D | CPU | 334.2 t/s | 28.9 t/s | ⚠️ Slow |
| **Steam Deck** | AMD Vangogh | Vulkan GPU | 247.6 t/s | 24.7 t/s | ✅ Best for Deck |
| **Steam Deck** | AMD Vangogh | CPU | 38.9 t/s | 10.2 t/s | ⚠️ Slow |
| **Steam Deck** | AMD Vangogh | ROCm GPU | — | — | ❌ Hangs |

**Desktop:** Vulkan outperforms ROCm by ~1.3x on input. CPU-only is ~16x slower than GPU.

**Steam Deck:** Vulkan GPU is the only viable option (ROCm hangs). CPU-only is ~6x slower than Vulkan GPU.

**Verdict:** Use **Vulkan GPU** everywhere. On Steam Deck, ROCm is unstable.

## Tuning

### Coding

- `--thinking 0` recommended for coding (avoids loops, faster iteration; let linting/tools catch edge cases)
- `--temp 0.6` works well for Qwen coding tasks; experiment to find optimal value per model
- `--temp 0.8` (default) for conversations

### Recommended Sampling Parameters by Model

Official sampling parameters from model providers. See the [Examples](#examples) section above for full `ramalama serve` commands.

| Model | Use Case | temp | top_p | top_k | thinking |
|-------|----------|------|-------|-------|----------|
| **Qwen 3.5** | Coding | 0.6 | 0.95 | 20 | 0 |
| **Qwen 3.5** | General/Reasoning | 1.0 | 0.95 | 20 | auto |
| **Gemma 4** | All | 1.0 | 0.95 | 64 | auto |

**How to use:**
- `--temp VALUE` - ramalama argument (example: `--temp 0.6`)
- `--runtime-args "--top-p VALUE --top-k VALUE"` - pass to llama.cpp
- `--thinking 0` - disable for coding; `auto` (default) for general use

**Model notes:**
- See Model architecture note and individual examples above for details

*Note: Support for sampling parameters varies by inference framework. Llama.cpp defaults: top_k=40, top_p=0.95, temp=0.8.*

#### Zed Integration

Set via UI: **LLM provider** → "Add Provider" -> "OpenAI API" with a URL of `http://localhost:8123` (or 0.0.0.0, or an IPv4 address to a machine the model is running on, if it's on another computer). Works with Qwen, Gemma, Granite 4, and other models served through ramalama.

Alternatively, add to `settings.json`. Use the same model name and `max_tokens` as your `ramalama serve` command for consistent token estimates (helps you gauge when you'll run out of context):
```json
"language_models": {
  "openai_compatible": {
    "local": {
      "api_url": "http://localhost:8123",
      "available_models": [
        {
          "name": "Qwen3.5-27B",
          "max_tokens": 131072,
          "max_output_tokens": 8192,
          "capabilities": {
            "tools": true,
            "images": false,
            "parallel_tool_calls": true,
            "chat_completions": true
          }
        }
      ]
    }
  }
}
```

### Performance

Run `ramalama bench --image <backend>:latest <model>` with either `vulkan` or `rocm`.

| Backend | pp512 (tokens/s) | tg128 (tokens/s) |
|---------|------------------|------------------|
| Vulkan | 874–882 | 42 |
| ROCm | 1042–1045 | 34–35 |

*Benchmarked on Qwen3.5-27B-IQ4_NL with Ryzen 9 7950X3D + RX 7900 XTX.*

- **ROCm**: +18–20% faster prompt processing (input)
- **Vulkan**: +20–24% faster token generation (output)

**Choose ROCm** for large inputs or faster initial analysis. **Choose Vulkan** for faster streaming output.

## Glossary

- **Quantization (quant)**: Reduced model precision to save memory. `Q4_K_M` = 4-bit, medium quality.
- **Dense**: All parameters activated per token.
- **MoE (Mixture of Experts)**: Subset of parameters activated per token.
- **Inference**: Running a model to generate outputs from inputs (text, prompts, etc.).
- **VRAM**: GPU memory. More VRAM allows larger models/faster inference. CPU fallback possible without GPU.
- **Context size**: Tokens the model can remember. 131072 = 128K tokens (~100K words).
- **Token**: Basic text unit (~0.75 words).

## Advanced

### Version Control

Containers build llama.cpp from `master` by default. Use `LLAMA_CPP_REF` for reproducible builds:

```bash
# Production (specific commit)
podman build --build-arg LLAMA_CPP_REF=bc05a6803e48f17e0f2c7a99fce9b50d03882de7 \
    -f Containerfile.rocm -t localhost/rocm:20250607 .

# Debug build
podman build --env RAMALAMA_IMAGE_BUILD_DEBUG_MODE=y \
    -f Containerfile.rocm -t localhost/rocm:debug .
```

`LLAMA_CPP_REF` accepts branches, commit hashes, tags, or remote refs. `RAMALAMA_IMAGE_BUILD_DEBUG_MODE=y` enables debug symbols, installs gdb/strace, preserves source.

### Reference

#### Ramalama CLI Arguments

- `--ctx-size 131072` - 128K context window
- `--temp 0.6` - Response temperature (0.0 = greedy, 0.8 = default)
- `--thinking 0` - Disable thinking mode (recommended for coding)
- `--ngl N` - GPU layers to offload (default: 999 = all; reduce if VRAM limited)

#### Llama.cpp Runtime Arguments

Passed via `--runtime-args "..."`:

- `--batch-size 4096` - Logical batch size (default: 2048); higher = faster prompt processing, more VRAM
- `--ubatch-size 2048` - Physical batch size (default: 512); keep ≤ `--batch-size`
- `--parallel 1` - Single server slot; improves cache efficiency (especially for Gemma)
- `--flash-attn on` - Flash attention; faster inference, lower VRAM (default: auto)
- `--rope-freq-base 1000000` - RoPE frequency scaling; **required for 128K context**
- `--context-shift` - Context shifting for infinite/long text generation
- `-ctk q4_0 -ctv q4_0` - KV cache quantization (Q4_0); reduces VRAM usage
- `--mmap` - Memory-mapped files (enabled by default); faster load times

#### Model Downloads

Use transport prefixes: `hf://`, `huggingface://`, `file://`, `oci://`.

**Troubleshooting hf:// downloads:** If download fails, edit `~/.local/lib/python*/site-packages/ramalama/transports/huggingface.py` and replace `get_cli_download_args` with:

```python
def get_cli_download_args(self, directory_path, model):
    return ["download", self.repo_id, self.model_filename, "--local-dir", directory_path]
```
