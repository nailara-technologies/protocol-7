# Build Scripts for Protocol-7 Infrastructure

This directory contains build automation scripts for compiling external dependencies and tools used by Protocol-7.

## Directory Structure

```
build-scripts/
├── README.md (this file)
└── llama-cpp/
    └── build-cuda-docker.sh    # Docker-based CUDA GPU build
```

## llama.cpp Integration

Protocol-7 includes intelligent inference capabilities through dual GPU+CPU inference backends using ik_llama.cpp.

### Available Builds

#### 1. GPU-Accelerated Build (Docker-based)
**Location:** `llama-cpp/build-cuda-docker.sh`

Compiles llama-mtmd-cli with full CUDA GPU acceleration using Docker to avoid glibc incompatibilities.

**IMPORTANT: Branch Requirement**
Before building, you must checkout the `fix_cli_log` branch to ensure proper output handling:
```bash
cd /data/source/ik_llama.cpp
git checkout fix_cli_log
```

This branch disables the broken LOG_TEE macro that was corrupting model output with debug messages. Required for clean vision analysis responses.

**Usage:**
```bash
cd /data/source/ik_llama.cpp
git checkout fix_cli_log
/data/projects/protocol-7/bin/build-scripts/llama-cpp/build-cuda-docker.sh
```

**Configuration Environment Variables:**
- `CUDA_VERSION` - CUDA version to use (default: 12.5.0)
- `UBUNTU_VERSION` - Ubuntu base image (default: jammy)
- `IMAGE_NAME` - Docker image name (default: ik_llama_cuda_gpu)
- `OUTPUT_DIR` - Where to place compiled binary (default: current dir)

**Output:**
- `llama-mtmd-cli-cuda-fa-{VERSION}` - GPU-accelerated vision binary with flash attention
- CUDA runtime libraries required for execution

**System Requirements:**
- NVIDIA GPU with CUDA Compute Capability 8.0+
- NVIDIA driver installed
- Docker installed and running

#### 2. CPU-Only Build (CMake-based)
**Location:** None (use CMake directly in source tree)

Compiles llama-server without CUDA for universal x86_64 compatibility.

**Usage:**
```bash
cd /data/source/ik_llama.cpp
cmake -B build-cpu -DGGML_CUDA=OFF -DCMAKE_BUILD_TYPE=Release
cmake --build build-cpu --config Release --target llama-server -j 8
```

**Output:**
- `build-cpu/bin/llama-server` - CPU-only binary (native x86_64 optimized)

**System Requirements:**
- x86_64 CPU with AVX2 support (Intel/AMD 2010+)
- GCC/Clang compiler
- CMake 3.10+

### Binary Locations in Production

Both compiled binaries are stored in `/data/source/ik_llama.cpp/`:

```
/data/source/ik_llama.cpp/
├── llama-server-cuda-12.5.0      # GPU-accelerated (6.2 MB)
├── llama-server-cuda              # Symlink to latest GPU build
├── llama-server-cpu               # CPU-only (6.1 MB)
└── llama-server-cpu-latest        # Symlink to latest CPU build
```

### Protocol-7 Configuration

The coding zenka (`cfg/zenki/coding/zenka.v7`) is configured to use both backends:

**GPU Backend (Preferred):**
- Binary: `llama-server-cuda`
- Timeout: 30 seconds
- Used when GPU has >8GB free VRAM
- Delivers 100x faster inference

**CPU Backend (Fallback):**
- Binary: `llama-server-cpu`
- Timeout: 300 seconds
- Used when GPU unavailable or timeout occurs
- Provides 100% reliable inference

### Inference Models

Both backends support the same models. Current configuration uses:

**Qwen2.5 7B Instruct 1M**
- Model path: `/mnt/m/lmstudio-community/Qwen2.5-7B-Instruct-1M-GGUF/`
- File: `Qwen2.5-7B-Instruct-1M-Q4_K_M.gguf`
- Context: 1 million tokens
- Quantization: Q4_K_M
- Performance: ~5-10 tokens/sec GPU, ~0.05-0.1 tokens/sec CPU

### Build Documentation

For comprehensive build documentation, see:
- `data/yaml/build-instructions/ik_llama_gpu_build_successful-2025-12-05.yaml` - GPU build details
- `data/yaml/build-instructions/ik_llama_cpu_build_successful-2025-12-05.yaml` - CPU build details
- `data/yaml/build-instructions/ik_llama_dual_strategy_2025-12-05.yaml` - Complete strategy guide

### Performance Characteristics

| Aspect | GPU | CPU |
|--------|-----|-----|
| Throughput | ~5-10 tok/s | ~0.05-0.1 tok/s |
| Latency | 100-200ms/token | 10-20s/token |
| VRAM | 7.5 GB | None |
| RAM | Minimal | 8-16 GB |
| Setup | Docker + CUDA | CMake only |
| Portability | GPU-dependent | Universal x86_64 |

### Troubleshooting

**CUDA Build Fails:**
- Ensure Docker is installed: `docker --version`
- Verify NVIDIA driver: `nvidia-smi`
- Check Docker can access GPU: `docker run --gpus all nvidia/cuda:12.5.0-runtime nvidia-smi`

**CPU Build Fails:**
- Verify CMake installed: `cmake --version`
- Check compiler: `gcc --version` or `clang --version`
- Ensure proper permissions on source directory

**Runtime Errors:**
- GPU: Verify CUDA libraries accessible via `ldconfig -p | grep cuda`
- CPU: Check AVX2 support: `grep avx2 /proc/cpuinfo`

### Maintenance

Build scripts are version-locked to specific compiler and CUDA versions for reproducibility. To update:

1. Document new build environment in this README
2. Create new build directory with version suffix: `llama-cpp-{version}/`
3. Test both GPU and CPU builds with representative models
4. Update Protocol-7 binary paths once validated
5. Archive old build scripts for historical reference

## See Also

- `bin/` - Main Protocol-7 executables
- `cfg/zenki/coding/zenka.v7` - Coding zenka configuration
- `data/yaml/build-instructions/` - Detailed build documentation
- `/data/source/ik_llama.cpp/` - Source and compiled binaries

#,,,,,,,.,.,.,,,.,,,.,...,,..,,,.,..,,,,,,,..,..,,...,...,...,..,,,,.,,,,,,..,
#UTA5YLXBHNPFOTZUSVTTMX4ZJ2M2AV6WWKHLPCH26D5SGXEZFEG7JAB6KZYNBG76VQACI2YDJISXK
#\\\|L7WPELVPZA4F6FGZAU3JQ7Z3CC6SQVCKJIHOSLHYLWQCKQXFF3Y \ / AMOS7 \ YOURUM ::
#\[7]7FNXEJM2BHTVKXSGBU4EXI2E6B5XVRLT2RRBT6FZ6U2RQRZ2L2BA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
