# Rebuilding llama-server for CUDA 12.8 Compatibility

## Problem
The current llama-server binary was built with CUDA 13.0, but the system NVIDIA driver (576.88) only supports up to CUDA 12.8. This causes GPU inference to fail, though CPU inference works fine.

## Solution
Rebuild ik_llama.cpp with CUDA 12.8 to match the driver version.

## Prerequisites
- Sudo access (for CUDA package installation)
- ~30 minutes for compilation
- ~10 GB disk space in `/data/source/ik_llama.cpp`

## Option 1: Automatic Rebuild (Recommended)

A ready-made script handles everything:

```bash
# Download the script
cat > rebuild-llama.sh << 'EOF'
#!/bin/bash
set -e
echo "=== Installing CUDA 12.8 and Rebuilding llama-server ==="
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Must run as root"
    exit 1
fi

LLAMA_SOURCE="/data/source/ik_llama.cpp"
BUILD_DIR="$LLAMA_SOURCE/build"
INSTALL_PATH="/usr/local/bin/llama-server"
BACKUP_PATH="/usr/local/bin/llama-server.cuda-13.0.backup"

echo "[1/5] Installing CUDA 12.8..."
apt-get update -qq
apt-get install -y cuda-runtime-12-8 cuda-toolkit-12-8 2>&1 | tail -3

echo "[2/5] Verifying CUDA 12.8..."
CUDA_12_8_PATH="/usr/local/cuda-12.8"
test -f "$CUDA_12_8_PATH/bin/nvcc" || { echo "ERROR: CUDA 12.8 not found"; exit 1; }

echo "[3/5] Backing up current binary..."
test -f "$INSTALL_PATH" && cp "$INSTALL_PATH" "$BACKUP_PATH"

echo "[4/5] Rebuilding with CUDA 12.8..."
cd "$LLAMA_SOURCE"
rm -rf "$BUILD_DIR"
cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_CUDA=ON \
    -DCUDAToolkit_ROOT=$CUDA_12_8_PATH \
    -DCMAKE_CUDA_COMPILER=$CUDA_12_8_PATH/bin/nvcc

cmake --build build --config Release -j $(nproc)

echo "[5/5] Installing new binary..."
cp "$BUILD_DIR/bin/llama-server" "$INSTALL_PATH"
chmod +x "$INSTALL_PATH"

echo "✓ Build complete. Backup: $BACKUP_PATH"
EOF

# Run as root
sudo bash rebuild-llama.sh
```

## Option 2: Manual Build

If you prefer step-by-step control:

```bash
# 1. Install CUDA 12.8 (requires sudo)
sudo apt-get update
sudo apt-get install -y cuda-runtime-12-8 cuda-toolkit-12-8

# 2. Backup current binary
sudo cp /usr/local/bin/llama-server /usr/local/bin/llama-server.cuda-13.0.backup

# 3. Rebuild
cd /data/source/ik_llama.cpp
rm -rf build
cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_CUDA=ON \
    -DCUDAToolkit_ROOT=/usr/local/cuda-12.8 \
    -DCMAKE_CUDA_COMPILER=/usr/local/cuda-12.8/bin/nvcc

cmake --build build --config Release -j $(nproc)

# 4. Install new binary
sudo cp build/bin/llama-server /usr/local/bin/llama-server
```

## Option 3: Keep Current Setup

The CPU-only mode works perfectly fine for testing. If you don't need GPU acceleration:

```bash
# CPU inference still works:
./bin/dev/tests/ml/test-llama-server-gpu.sh  # Runs on CPU, ignores GPU unavailability
```

## Testing After Rebuild

```bash
# Verify binary
/usr/local/bin/llama-server --version

# Test inference (GPU should now work)
./bin/dev/tests/ml/test-llama-server-gpu.sh
```

## Fallback: Restore Original

If rebuild has issues:

```bash
sudo cp /usr/local/bin/llama-server.cuda-13.0.backup /usr/local/bin/llama-server
```

## Timeline

| Option | Time | Effort | GPU Available |
|--------|------|--------|----------------|
| **Automatic Script** | 5-10 min setup + 10 min build | Low | ✓ Yes |
| **Manual Build** | 5-10 min setup + 10 min build | Medium | ✓ Yes |
| **CPU Only** | Immediate | None | ✗ No |

## Recommendation

For validating GPU inference performance:
- **Use Automatic Script** (Option 1) - handles everything safely

For immediate testing without GPU:
- **Use CPU Mode** (Option 3) - no setup needed, tests work fine

## Additional Notes

- CUDA 12.8 is the highest version compatible with driver 576.88
- Compilation uses all available CPU cores (`-j $(nproc)`)
- Original binary is always backed up before replacement
- Build takes ~10 minutes on typical hardware
