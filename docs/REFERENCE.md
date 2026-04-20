# Reference

This document contains advanced usage instructions and technical references for the Ramalama container images.

## Advanced Usage

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

## Technical Reference

### Ramalama CLI Arguments

- `--ctx-size 131072` - 128K context window
- `--temp 0.6` - Response temperature (0.0 = greedy, 0.8 = default)
- `--thinking 0` - Disable thinking mode (recommended for coding)
- `--ngl N` - GPU layers to offload (default: 999 = all; reduce if VRAM limited)

### Llama.cpp Runtime Arguments

Passed via `--runtime-args "..."`:

- `--batch-size 4096` - Logical batch size (default: 2048); higher = faster prompt processing, more VRAM
- `--ubatch-size 2048` - Physical batch size (default: 512); keep ≤ `--batch-size`
- `--parallel 1` - Single server slot; improves cache efficiency (especially for Gemma)
- `--flash-attn on` - Flash attention; faster inference, lower VRAM (default: auto)
- `--rope-freq-base 1000000` - RoPE frequency scaling; **required for 128K context**
- `--context-shift` - Context shifting for infinite/long text generation
- `-ctk q4_0 -ctv q4_0` - KV cache quantization (Q4_0); reduces VRAM usage
- `--mmap` - Memory-mapped files (enabled by default); faster load times

### Model Downloads

Use transport prefixes: `hf://`, `huggingface://`, `file://`, `oci://`.

**Troubleshooting `hf://` downloads:** If download fails, edit `~/.local/lib/python*/site-packages/ramalama/transports/huggingface.py` and replace `get_cli_download_args` with:

```python
def get_cli_download_args(self, directory_path, model):
    return ["download", self.repo_id, self.model_filename, "--local-dir", directory_path]
```
