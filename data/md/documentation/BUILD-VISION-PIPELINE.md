# Building and Deploying GPU-Accelerated Vision Pipeline

This guide documents how to reproduce the complete GPU-accelerated vision model infrastructure for Protocol-7.

## Prerequisites

- Docker with GPU support (NVIDIA Container Toolkit)
- NVIDIA GPU with CUDA support (tested on RTX 3060)
- ~20GB disk space for models and builds
- ~4GB RAM minimum

## Step 1: Apply IQK Symbol Fix to ik_llama.cpp

The ik_llama.cpp fork must be patched to fix the IQK symbol linking issue.

```bash
cd /data/source/ik_llama.cpp

# Apply the fix patch
git apply /data/projects/protocol-7/data/patches/iqk-symbol-extern-c-fix.patch

# Verify the patch was applied
git diff --name-only
# Should show: ggml/src/iqk/iqk_flash_attn.cpp
```

## Step 2: Build GPU-Accelerated Vision Binary via Docker

The Dockerfile automatically configures:
- **Hysteria tunnel proxy** for stable package downloads (eliminates hash mismatches on mobile networks)
- **CMake CUDA20 support** via Kitware repository (required for upstream optimizations)
- **CUDA architecture 86** (RTX 3060 compute capability - adjust for your GPU)
- **NCCL2 runtime library** for collective communications
- **Upstream optimizations**: fused norm kernels (5-15% inference speedup), CUDA device improvements

```bash
cd /data/source/ik_llama.cpp

# Build the Docker image with CUDA and optimized vision support
docker build -f Dockerfile.cuda-build -t ik-llama-vision-cuda:latest .

# Extract binaries from the built image
docker create --name extract-vision ik-llama-vision-cuda:latest
docker cp extract-vision:/usr/local/bin/llama-mtmd-cli ./llama-mtmd-cli-cuda
docker cp extract-vision:/usr/local/lib/libggml.so ./libggml.so
docker cp extract-vision:/usr/local/lib/libllama.so ./libllama.so
docker cp extract-vision:/usr/local/lib/libmtmd.so ./libmtmd.so
docker rm extract-vision

# Make binary executable
chmod +x ./llama-mtmd-cli-cuda
```

**Note**: The build now targets `llama-mtmd-cli` (multimodal vision binary) exclusively. For different GPU architectures, update `CMAKE_CUDA_ARCHITECTURES` in Dockerfile:
- RTX 3060: `86` (Ampere)
- RTX 3080/3090: `86` (Ampere)
- RTX 4070/4080/4090: `89` (Ada)
- A100: `80` (Ampere)
- H100: `90` (Hopper)

## Step 3: Acquire Vision Models

Download Qwen2.5-VL model (tested and working):

```bash
mkdir -p /mnt/ext-xfs-data/models-lmstudio/Qwen

# Download from Hugging Face or LM Studio
# Files needed:
# - Qwen2.5-VL-7B-Instruct-Q4_K_M.gguf (4.4GB)
# - mmproj-F16.gguf (1.3GB)

# Verify files
ls -lh /mnt/ext-xfs-data/models-lmstudio/Qwen/
# Should show both files listed above
```

## Step 4: Verify Vision Binary Works

Test the vision model directly:

```bash
cd /data/source/ik_llama.cpp

export LD_LIBRARY_PATH=/data/source/ik_llama.cpp:$LD_LIBRARY_PATH

./llama-mtmd-cli-cuda \
  -m /mnt/ext-xfs-data/models-lmstudio/Qwen/Qwen2.5-VL-7B-Instruct-Q4_K_M.gguf \
  --mmproj /mnt/ext-xfs-data/models-lmstudio/Qwen/mmproj-F16.gguf \
  --image /data/projects/protocol-7/data/gfx/backgrounds/4VVIXSXYEI35M6IUUYW274KXEYCSRZTWZE5ZQH7RHRLYNTPXHBNHTB3V.jpg \
  -n 30 -c 2048 -e --prompt "Describe this:" 2>&1 | tail -20

# Should output an image description within 15-20 seconds
```

## Step 5: Start Protocol-7 Vision Pipeline

Start the v7 zenka system:

```bash
p7 v7.list zenki

# Should show online:
# - cube (message router)
# - p7-log (logging)
# - image-quality (vision analysis)
# - image-batch (batch processing)
# - llama-server-vision (HTTP endpoint)
```

## Step 6: Test Complete-Analysis Vision Processing

Test the new auto-resume vision analysis command:

```bash
# Single image with auto-completion
p7 lm-vision.complete-analysis /data/projects/protocol-7/data/gfx/test-image.jpg "describe this in detail"

# Should return complete analysis (may take multiple passes)
# - First pass: Initial analysis, will resume if truncated
# - Subsequent passes: Continuation of analysis
# - Final: Complete response with proper ending

# Check logs for multi-pass processing:
tail -f /var/log/protocol-7/lm-vision.log | grep -E "check_completion|check-completion-chain"
```

**Expected output:** Complete image description ending with proper punctuation, no truncation.

## Step 7: Test Batch Vision Processing (Legacy)

For batch processing of multiple images:

```bash
p7 image-batch.process "/data/projects/protocol-7/batches/test_vision_batch.yaml"

# Should return a batch_id and start processing
# Check status:
p7 image-batch.status "batch-<id>"
```

## Verification Checklist

- [ ] IQK symbol patch applied to ik_llama.cpp
- [ ] Docker build completed successfully
- [ ] Binaries extracted and deployed
- [ ] Vision model files present in /mnt/ext-xfs-data/models-lmstudio/Qwen/
- [ ] Direct binary test produces image descriptions
- [ ] v7 zenka system online
- [ ] **NEW:** `lm-vision.complete-analysis` returns complete multi-line descriptions
- [ ] **NEW:** Multi-pass resumption works for truncated responses (check logs)
- [ ] **NEW:** No GPU out-of-memory errors on consecutive calls
- [ ] **NEW:** Single-pass completion for typical requests
- [ ] image-quality processes requests (legacy direct command)
- [ ] image-batch processes job queues
- [ ] Batch processing returns results

## Troubleshooting

### "undefined symbol: iqk_flash_attn_noalibi"
- Ensure patch was applied: `git diff ggml/src/iqk/iqk_flash_attn.cpp`
- Should show `+extern "C" IQK_API` on line 332

### Binary won't start
- Check library path: `export LD_LIBRARY_PATH=/data/source/ik_llama.cpp:$LD_LIBRARY_PATH`
- Verify binary exists: `ls -lh llama-mtmd-cli-cuda`
- Check CUDA compatibility: `nvidia-smi`

### Vision model not found
- Verify paths: `ls -lh /mnt/ext-xfs-data/models-lmstudio/Qwen/`
- Should have both .gguf and mmproj files
- Update search paths if using different location

### Batch processing not starting
- Verify image-quality is online: `p7 v7.list zenki | grep image-quality`
- Check image path exists in batch YAML
- Monitor logs: `tail -f /var/log/protocol-7/llama-server-vision.log`

## Performance Expectations

### Complete-Analysis Command (New - Jan 2026)

Measured with Qwen3-VL-4B on RTX 3060 (with complete-analysis wrapper):
- **Single-pass (typical)**: ~5-8 seconds for complete analysis
- **Two-pass (truncated responses)**: ~10-16 seconds total
- **Context size**: 4096 tokens (tested without OOM on consecutive calls)
- **Generator mode**: `-n -2` (fill context efficiently, not granular streaming)

**Response characteristics:**
- Single-line responses: Returned with `'true'` mode (p7c adds line ending)
- Multi-line responses: Returned with `'size'` mode (proper newline handling)
- Completeness: Marked complete only if ends with `.!?` or is <80 chars
- Max resumes: 5 (configurable) before returning partial result
- GPU memory: Properly cleaned between passes (no OOM on consecutive calls)

### Legacy Direct Analysis

Measured with Qwen2.5-VL-7B-Instruct on RTX 3060 (optimized build):
- **Image encoding (GPU-accelerated CLIP)**: ~37.4 seconds
- **Model inference (Qwen2.5-VL-7B)**: ~2.8 seconds
- **End-to-end per image**: ~40.2 seconds
- **Batch throughput**: Sequential processing with job queue management
- **GPU utilization**: >90% during CLIP encoding and inference (significant improvement from upstream optimizations)

Performance varies based on:
- Image resolution and complexity
- Model quantization (Q4_K_M recommended for VRAM efficiency)
- Context window size (-c flag, default 4096 for complete-analysis)
- Generation mode (-n flag: -2 for complete-analysis, -1 for legacy)

## Key Optimizations Applied

### Complete-Analysis System (Jan 16, 2026)
1. **Auto-Resume Wrapper** - Transparent multi-turn generation until completion
   - Monitors response completeness via timer-based handler (100ms checks)
   - Spawns continuations automatically when truncated
   - Accumulates across multiple passes (max 5 resumes)

2. **Smart Completeness Detection** - Prevents false completion
   - Only marks complete if ends with `.!?` or is <80 chars
   - Previously looser heuristics caused incomplete responses

3. **GPU Memory Management** - Fixes out-of-memory on consecutive calls
   - Blocking `waitpid()` ensures process termination
   - GPU memory released before next analysis job
   - Tested on consecutive calls without OOM

4. **Reply Mode Adaptation** - Proper client formatting
   - Single-line → `'true'` mode with stripped trailing newline
   - Multi-line → `'size'` mode with normalized trailing newline
   - Clients like p7c format output correctly with own line endings

5. **Efficient Token Generation** - Changed from `-n -1` to `-n -2`
   - Fills context window instead of unlimited streaming
   - Larger packets (not byte-by-byte granular streaming)
   - Faster response generation

### Upstream Integration (49 commits, Dec 2025)
1. **Fused norm kernels** - 5-15% inference speedup
2. **CUDA device management** - Improved device initialization and memory handling
3. **Graph parallel optimizations** - Better computation scheduling
4. **CMake CUDA20 support** - Via Kitware APT repository for Ubuntu 22.04+

### Docker Build Improvements
1. **Hysteria tunnel proxy** - Eliminates "Hash Sum mismatch" errors on mobile networks
2. **NCCL2 library** - Added collective communications support
3. **CUDA architecture targeting** - Explicit `-DCMAKE_CUDA_ARCHITECTURES=86` for correct kernel compilation
4. **Binary verification** - Focus on multimodal binary (llama-mtmd-cli) exclusively

### IQK Symbol Linking
- Added `extern "C" IQK_API` to stub implementation in iqk_flash_attn.cpp

See `VISION-IMPLEMENTATION.md` for complete implementation status.

## References

- **VISION-IMPLEMENTATION.md** - Complete pipeline documentation
- **Dockerfile.cuda-build** - Reproducible GPU-accelerated build (source: /data/source/ik_llama.cpp)
- **data/patches/iqk-symbol-extern-c-fix.patch** - IQK symbol linking fix
- **Upstream commits** - fc3be34ea (fused norm, device management, graph optimizations)

#,,,,,.,,,,,.,,,.,...,,,,,,,.,,.,,.,.,...,..,,..,,...,..,,.,.,...,..,,.,,,,,,,
#XW5UCPNQ5JA552XP4FJDUDBVP4CP2TTRFH4FKFTYHJZF5WPEG5FE5LTHQVQHS3MR6TJCZBMHYSJ44
#\\\|UU3GNBGCMH6GLMBCYOLABX74PJL3CI76LHFLPGPI3JYQTLENSWE \ / AMOS7 \ YOURUM ::
#\[7]OJFQBY76MIJMCXENZNVFR6IHMYYRRVUHAMIS22XRN35EATKCAQBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
