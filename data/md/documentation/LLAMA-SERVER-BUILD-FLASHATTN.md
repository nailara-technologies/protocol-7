# Building llama-server with Flash Attention Support

## Problem

The current `llama-server` binaries in `/data/source/ik_llama.cpp` were compiled without Flash Attention (`-DGGML_CUDA_FA`) support. This causes the server to fail when loading quantized models (like Qwen2.5-7B-Instruct-1M-Q4_K_M) that require flash attention:

```
llama_new_context_with_model: V cache quantization requires flash_attn
llama_init_from_gpt_params: error: failed to create context with model
free(): invalid size
```

This prevents the coding zenka from running inference tasks.

## Solution

Rebuild `llama-server` with Flash Attention support enabled (`-DGGML_CUDA_FA=ON`) using the Docker build system.

## Prerequisites

- Docker installed and running
- NVIDIA GPU with CUDA support (RTX 3060 or similar)
- NVIDIA driver installed (`nvidia-smi` command available)
- ~30GB free disk space for build
- 15-30 minutes for build time

## Build Instructions

### Option 1: Docker Build (Recommended - Avoids Dependency Issues)

```bash
cd /data/projects/protocol-7/bin/build-scripts/llama-cpp

# Run the build script
./build-llama-server-cuda-flashattn.sh
```

This will:
1. Build a Docker image with CUDA 12.5.0 devel environment
2. Compile llama.cpp with:
   - `DGGML_CUDA=ON` - CUDA GPU support
   - `DGGML_CUDA_FA=ON` - Flash Attention for quantized KV cache
   - Architecture 86 (RTX 3060)
   - Full optimization `-O3`
3. Extract binary and libraries to current directory
4. Create symlinks for easy access

### Option 2: Direct Build (If Docker Not Available)

```bash
cd /data/source/ik_llama.cpp

cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_CUDA=ON \
    -DGGML_CUDA_FA=ON \
    -DCMAKE_CUDA_ARCHITECTURES=86 \
    -DBUILD_SHARED_LIBS=ON

cmake --build build --config Release -j$(nproc) --target llama-server

# Binary will be at: build/bin/llama-server
# Libraries at: build/ggml/src/libggml.so, build/src/libllama.so
```

## Build Outputs

After successful build, you'll have:

- `llama-server-cuda-fa-12.5.0` - Server binary with flash attention
- `llama-server-cuda-fa` - Symlink to latest version
- `libggml.so` - GGML library
- `libllama.so` - Llama library
- CUDA runtime libraries (libcudart.so.12, etc.)

## Using the New Binary

### Method 1: Direct Execution

```bash
export LD_LIBRARY_PATH=/data/source/ik_llama.cpp:$LD_LIBRARY_PATH

/data/source/ik_llama.cpp/llama-server-cuda-fa \
    -m /mnt/ext-xfs-data/models-lmstudio/lmstudio-community/Qwen2.5-7B-Instruct-1M-GGUF/Qwen2.5-7B-Instruct-1M-Q4_K_M.gguf \
    --port 8000 \
    -ngl 33 \
    -t 4
```

### Method 2: Update Coding Zenka Configuration

Edit `/data/projects/protocol-7/configuration/zenki/coding/start`:

```perl
inference.backend.gpu.binary = /data/source/ik_llama.cpp/llama-server-cuda-fa
inference.backend.cpu.binary = /data/source/ik_llama.cpp/llama-server-cuda-fa
```

Then reload the coding zenka:

```bash
p7c coding.reload
```

### Method 3: Update Spawn Parameters

The coding zenka will automatically use the new binary if you restart it after building.

## Verification

Test that the binary works:

```bash
export LD_LIBRARY_PATH=/data/source/ik_llama.cpp:$LD_LIBRARY_PATH

/data/source/ik_llama.cpp/llama-server-cuda-fa --version
```

Should output version info like: `llama-server-cuda-fa: version 0.x.x`

Test model loading (will take 30-60 seconds):

```bash
export LD_LIBRARY_PATH=/data/source/ik_llama.cpp:$LD_LIBRARY_PATH

timeout 60 /data/source/ik_llama.cpp/llama-server-cuda-fa \
    -m /mnt/ext-xfs-data/models-lmstudio/lmstudio-community/Qwen2.5-7B-Instruct-1M-GGUF/Qwen2.5-7B-Instruct-1M-Q4_K_M.gguf \
    --port 9999 \
    -ngl 33 \
    -t 2 \
    2>&1 | head -100
```

If successful, you should see:
- GPU memory allocation messages
- Model loading messages
- "Server is listening" message (before timeout)

## Troubleshooting

### Build Fails: "Docker build failed"
- Ensure Docker daemon is running: `sudo systemctl start docker`
- Check disk space: `df -h` - need at least 30GB free
- Check Docker permissions: `docker ps` should work without sudo

### Binary fails: "libcuda.so.1 not found"
- Set LD_LIBRARY_PATH: `export LD_LIBRARY_PATH=/data/source/ik_llama.cpp:$LD_LIBRARY_PATH`
- Or copy CUDA libraries to system path: `sudo cp /data/source/ik_llama.cpp/libcuda*.so* /usr/local/lib/`

### Model loading hangs or crashes
- Check GPU memory: `nvidia-smi` - need 7.4GB free for Qwen2.5-7B-Instruct-1M
- Reduce GPU layers: use `-ngl 20` instead of 33
- Try CPU: `llama-server-cuda-fa ... -ngl 0` (will be very slow)

### "V cache quantization requires flash_attn" error
- Binary was not rebuilt with flash attention
- Make sure you're using the new binary, not the old one
- Verify: `ldd /path/to/binary | grep flash` should show flash attention library

## Performance Notes

- **GPU Offload** (`-ngl 33`): ~200ms per inference, lower latency
- **CPU Only** (`-ngl 0`): ~5-10 seconds per inference, uses RAM
- **Hybrid**: `-ngl 20` offloads most layers to GPU

## Related Files

- Build script: `/data/projects/protocol-7/bin/build-scripts/llama-cpp/build-llama-server-cuda-flashattn.sh`
- Coding zenka config: `/data/projects/protocol-7/configuration/zenki/coding/start`
- Coding zenka source: `/data/projects/protocol-7/modules/coding.*`
- Auto-resume docs: `/data/projects/protocol-7/data/md/documentation/CODING-COMPLETE-ANALYSIS.md`

## Next Steps

After building and testing llama-server with flash attention:

1. Update coding zenka configuration to use new binary
2. Restart coding zenka
3. Test complete-analysis command with code generation
4. Commit the build script to version control

---

**Status**: Build script created and ready to use
**Priority**: CRITICAL - Blocks coding zenka inference execution
**Last Updated**: 2025-01-17

#,,.,,.,.,,,.,.,,,.,,,,,,,,.,,,,,,.,.,...,,..,..,,...,.,.,.,,,...,,..,...,,.,,
#AAGG6KH6RW3UFQSGFIGZQIMWXGEVBP57R5PQPNXGUBVKKFXNRCECYUVM5WATIXUV22KGSSUE6LAFO
#\\\|YXHOEXGU3MMT3QSF52ITWUCVDWC7DF5IYKS66UYKJ76WNZDEGWD \ / AMOS7 \ YOURUM ::
#\[7]7I5UU5CR7GMQJFEKVZ2UQDDNMT5FXU5CLPRSLSY44XMQ4PGEFUBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
