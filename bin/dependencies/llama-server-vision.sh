#!/bin/bash

## [:< ##
# name  = llama-server-vision
# descr = Vision model server wrapper for image-quality zenka
#
# Starts llama-server with vision-capable model on port 8080
# Prioritizes Gemma-3-Glitter model (tested compatibility)
# Falls back to Qwen3-VL if Gemma not available
# Managed as v7 ext-bin zenka for image-quality dependencies

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Vision model configuration - prioritize models with mmproj (multimodal projection)
# Samantha-vision and Qwen3-VL both have mmproj for vision capabilities
MODEL_SEARCH_PATHS=(
    "/mnt/m/Guilherme34/Samantha-vision-gguf"
    "/mnt/ext-xfs-data/models-lmstudio/Guilherme34/Samantha-vision-gguf"
    "/mnt/m/lmstudio-community/Qwen3-VL-8B-Instruct-GGUF"
    "/mnt/ext-xfs-data/models-lmstudio/lmstudio-community/Qwen3-VL-8B-Instruct-GGUF"
)

LLAMA_SERVER="${LLAMA_SERVER:-/data/source/ik_llama.cpp/llama-server-cuda}"
LLAMA_LIB_PATH="${LLAMA_LIB_PATH:-/data/source/ik_llama.cpp}"
PORT="${LLAMA_SERVER_PORT:-8080}"
LOG_FILE="/var/log/protocol-7/llama-server-vision.log"

echo "=== Starting Vision Model Server (llama-server) ==="
echo "Port: $PORT"
echo ""

# Check if binary exists
if [ ! -x "$LLAMA_SERVER" ]; then
    echo "ERROR: llama-server binary not found at $LLAMA_SERVER"
    exit 1
fi

echo "✓ Binary found: $LLAMA_SERVER"
echo "✓ Library path: $LLAMA_LIB_PATH"

# Find vision model
MODEL_PATH=""
for search_path in "${MODEL_SEARCH_PATHS[@]}"; do
    if [ -d "$search_path" ]; then
        # Look for vision model GGUF files (Qwen3-VL or Samantha vision, excluding mmproj)
        found=$(find "$search_path" -maxdepth 2 \( -name "*Qwen3*VL*.gguf" -o -name "*Samantha*vision*.gguf" \) ! -name "*mmproj*" 2>/dev/null | head -1)
        if [ -n "$found" ]; then
            MODEL_PATH="$found"
            break
        fi
    fi
done

if [ -z "$MODEL_PATH" ]; then
    echo "ERROR: Vision model not found (searched for Qwen3-VL or Samantha vision models)"
    echo "Searched paths: ${MODEL_SEARCH_PATHS[@]}"
    exit 1
fi

if [ ! -f "$MODEL_PATH" ]; then
    echo "ERROR: Model file not found: $MODEL_PATH"
    exit 1
fi

# Auto-detect mmproj file in same directory
MODEL_DIR=$(dirname "$MODEL_PATH")
MMPROJ_PATH=$(find "$MODEL_DIR" -maxdepth 1 -name "*mmproj*.gguf" 2>/dev/null | head -1)

MODEL_SIZE=$(du -h "$MODEL_PATH" | cut -f1)
echo "✓ Vision model found: $(basename "$MODEL_PATH") ($MODEL_SIZE)"
if [ -n "$MMPROJ_PATH" ]; then
    MMPROJ_SIZE=$(du -h "$MMPROJ_PATH" | cut -f1)
    echo "✓ Multimodal projection found: $(basename "$MMPROJ_PATH") ($MMPROJ_SIZE)"
fi
echo ""

# Create log directory if needed
mkdir -p "$(dirname "$LOG_FILE")"

# Start server in foreground (systemd/v7 will manage lifecycle)
echo "Starting llama-server with vision model..."
echo "[$(date)] Starting llama-server-vision" >> "$LOG_FILE"

# Server configuration for vision model with GPU acceleration
# Uses GPU-accelerated llama-server binary compiled with CUDA 12.5.0 support
# Parameters:
# - ngl 24: GPU layers (reduced for stability with vision models)
# - c 1024: Context size suitable for image analysis
# - t 4: Thread count for CPU fallback
# - mmproj: Multimodal projection file (auto-detected)
export LD_LIBRARY_PATH="${LLAMA_LIB_PATH}:${LD_LIBRARY_PATH}"

# Build llama-server command with optional mmproj parameter
# Note: Vision models with mmproj need lower GPU layers for stability
SERVER_CMD="$LLAMA_SERVER -m $MODEL_PATH -p $PORT -ngl 10 -c 1024 -t 4"
if [ -n "$MMPROJ_PATH" ]; then
    SERVER_CMD="$SERVER_CMD --mmproj $MMPROJ_PATH"
fi

eval "$SERVER_CMD >> $LOG_FILE 2>&1"

#,,.,,,,,,,,,,,..,,..,.,,,,,.,,.,,..,,,,.,,..,..,,...,..,,..,,.,,,.,.,,,.,.,,,
#5SGG63DYDQL5QVSK36QBADUDYVHOKEMC72TGRR3LDAJJ2IZQYLM7F4LBKNCTZWKUGQKSUAOEYTJRU
#\\\|WTMH7NQRM2344RVJSBYOQ6NQZX2AL25DBUIYMJZJXWOBMOK5AMX \ / AMOS7 \ YOURUM ::
#\[7]R2HNCHB5VWD5DN3ZLKYELPWHTBYNS76ZELZPQABDADX2LXTZXIBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
