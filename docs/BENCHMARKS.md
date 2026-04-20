# Benchmarks

This document contains performance benchmarks and comparisons for the Ramalama container images.

## Performance Comparison: Desktop vs Steam Deck

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

## Backend Performance Comparison

Benchmarks performed on Qwen3.5-27B-IQ4_NL with Ryzen 9 7950X3D + RX 7900 XTX.

| Backend | pp512 (tokens/s) | tg128 (tokens/s) |
|---------|------------------|------------------|
| Vulkan | 874–882 | 42 |
| ROCm | 1042–1045 | 34–35 |

- **ROCm**: +18–20% faster prompt processing (input)
- **Vulkan**: +20–24% faster token generation (output)

**Choose ROCm** for large inputs or faster initial analysis. **Choose Vulkan** for faster streaming output.