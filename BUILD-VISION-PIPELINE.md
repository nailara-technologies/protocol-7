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

```bash
cd /data/source/ik_llama.cpp

# Build the Docker image with CUDA and vision support
docker build -f Dockerfile.cuda-build -t ik-llama-vision-cuda:latest .

# Extract binaries from the built image
docker create --name extract-vision ik-llama-vision-cuda:latest
docker cp extract-vision:/usr/local/bin/llama-mtmd-cli ./llama-mtmd-cli-cuda-fixed
docker cp extract-vision:/usr/local/bin/llama-server ./llama-server-cuda-fixed
docker cp extract-vision:/usr/lib/x86_64-linux-gnu/libggml.so ./libggml.so.fixed
docker cp extract-vision:/usr/lib/x86_64-linux-gnu/libllama.so ./libllama.so.fixed
docker rm extract-vision

# Deploy to working location
cp llama-mtmd-cli-cuda-fixed llama-mtmd-cli-cuda
cp llama-server-cuda-fixed llama-server-cuda
cp libggml.so.fixed libggml.so
cp libllama.so.fixed libllama.so
chmod +x llama-mtmd-cli-cuda llama-server-cuda
```

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

## Step 6: Test Batch Vision Processing

Create a test batch:

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
- [ ] image-quality processes requests
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

- **Image encoding (GPU-accelerated CLIP)**: 2.8-4.7 seconds
- **Model inference (Qwen2.5-VL-7B)**: 8-13 seconds
- **End-to-end per image**: 13-18 seconds
- **Batch throughput**: Sequential processing with job queue management
- **GPU utilization**: Active during CLIP encoding and inference

## Key Fixes Applied (Dec 27, 2025)

1. **IQK Symbol Linking** - Added `extern "C"` to stub implementation
2. **Protocol Message Format** - Fixed parameter redundancy in batch dispatcher
3. **Wrapper Script** - Updated to use Qwen2.5-VL model

See `VISION-IMPLEMENTATION.md` for complete implementation status.

## References

- VISION-IMPLEMENTATION.md - Complete pipeline documentation
- DOCKER-CUDA-BUILD.md - ik_llama.cpp build details
- data/patches/iqk-symbol-extern-c-fix.patch - IQK fix for potential upstream contribution
