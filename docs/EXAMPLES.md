# Examples and Tuning

This document provides specific examples of how to run various models and how to tune them for different use cases.

## Model Architecture Note

- **Dense models** (example: Qwen3.5-27B): All parameters activated per token. Slower but more accurate for coding. Consistent performance.
- **MoE (Mixture of Experts)** (examples: Qwen3.5-35B-A3B, Gemma-4-26B-A4B): Subset of parameters activated per token. Faster, larger models in same VRAM. Parts loaded dynamically for better memory usage. Better for general tasks and reasoning.

## Model Examples

All examples tested on **Ryzen 9 7950X3D + RX 7900 XTX (24GB VRAM)** with 64GB system RAM. Systems with differing amounts of VRAM should be adjusted, using different models, quantizations, values, etc.

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
        --top-p 0.95 --flash-attn on \
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
