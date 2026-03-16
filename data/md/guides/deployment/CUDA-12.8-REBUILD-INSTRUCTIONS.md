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

echo "[1/6] Removing CUDA 13.0 packages..."
apt-get remove -y \
    'cuda-13-0' \
    'cuda-*-13-0' \
    'cuda-runtime-13-0' \
    'cuda-toolkit-13-0' \
    'cuda-libraries-13-0' \
    'cuda-compiler-13-0' \
    'cuda-command-line-tools-13-0' \
    'cuda-cccl-13-0' \
    'cuda-cudart-13-0' \
    'cuda-minimal-build-13-0' \
    2>&1 | tail -5
apt-get autoremove -y 2>&1 | tail -2
echo "✓ CUDA 13.0 packages removed"

echo "[2/6] Installing CUDA 12.8 from local repository..."
# Skip internet update - use local sources already configured
apt-get install -y cuda-runtime-12-8 cuda-toolkit-12-8 2>&1 | tail -3

echo "[3/6] Verifying CUDA 12.8..."
CUDA_12_8_PATH="/usr/local/cuda-12.8"
test -f "$CUDA_12_8_PATH/bin/nvcc" || { echo "ERROR: CUDA 12.8 not found"; exit 1; }

echo "[4/6] Backing up current binary..."
test -f "$INSTALL_PATH" && cp "$INSTALL_PATH" "$BACKUP_PATH"

echo "[5/6] Rebuilding with CUDA 12.8..."
cd "$LLAMA_SOURCE"
rm -rf "$BUILD_DIR"
cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_CUDA=ON \
    -DCUDAToolkit_ROOT=$CUDA_12_8_PATH \
    -DCMAKE_CUDA_COMPILER=$CUDA_12_8_PATH/bin/nvcc

cmake --build build --config Release -j $(nproc)

echo "[6/6] Installing new binary..."
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
# 1. Remove CUDA 13.0 packages (requires sudo)
sudo apt-get remove -y \
    'cuda-13-0' \
    'cuda-*-13-0' \
    'cuda-runtime-13-0' \
    'cuda-toolkit-13-0' \
    'cuda-libraries-13-0' \
    'cuda-compiler-13-0' \
    'cuda-command-line-tools-13-0' \
    'cuda-cccl-13-0' \
    'cuda-cudart-13-0' \
    'cuda-minimal-build-13-0'

sudo apt-get autoremove -y

# 2. Install CUDA 12.8 from local repository
# (Local sources already configured in /etc/apt/sources.list.d/)
sudo apt-get install -y cuda-runtime-12-8 cuda-toolkit-12-8

# 3. Backup current binary
sudo cp /usr/local/bin/llama-server /usr/local/bin/llama-server.cuda-13.0.backup

# 4. Rebuild
cd /data/source/ik_llama.cpp
rm -rf build
cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_CUDA=ON \
    -DCUDAToolkit_ROOT=/usr/local/cuda-12.8 \
    -DCMAKE_CUDA_COMPILER=/usr/local/cuda-12.8/bin/nvcc

cmake --build build --config Release -j $(nproc)

# 5. Install new binary
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

#,,,,,...,,..,...,,..,.,,,,..,,,.,..,,,,.,,.,,..,,...,...,.,.,.,,,...,,,.,,.,,
#D24JRM6IYKX3VZ2IAUWPRFE5STMIYIL5TGPBROMTZZTTPGMMNDDT3EK7JCQ6DO74HTWSIFWPXSHDM
#\\\|MYXGPU227VU4OLR4PKH7XJOEMNJD6FERVJDQTQGGX3UQKROJU2A \ / AMOS7 \ YOURUM ::
#\[7]PFXGDIF4LNAJSED2CAKIECWJSRJP3JX7ANO4UNHXHZ7R3ASWI6DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
