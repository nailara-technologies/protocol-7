#!/bin/bash

## [:< ##
# name  = llama-server-vision
# descr = Model server wrapper for image analysis (via HTTP API)
#
# Starts GPU-accelerated llama-server on port 8080 for model inference
# Current: Gemma-3-Glitter-4B (text/encoding model, stable)
# NOTE: Vision models with mmproj segfault/OOM - under investigation
# Managed as v7 ext-bin zenka for image-quality dependencies
# Can be extended to image analysis once vision model issues resolved

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Vision model configuration
# Using Qwen2.5-VL (verified working vision model with GPU acceleration)
# Falls back to 4b-opus100-manga and Gemma-3-Glitter if Qwen unavailable
MODEL_SEARCH_PATHS=(
    "/mnt/ext-xfs-data/models-lmstudio/Qwen"
    "/mnt/m/mradermacher/4b-opus100-manga-GGUF"
    "/mnt/ext-xfs-data/models-lmstudio/mradermacher/4b-opus100-manga-GGUF"
    "/mnt/ext-xfs-data/models-lmstudio/mradermacher/Gemma-3-Glitter-4B-Uncensored-GGUF"
    "/mnt/m/lmstudio-community/mradermacher/Gemma-3-Glitter-4B-Uncensored-GGUF"
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

# Find model
MODEL_PATH=""
for search_path in "${MODEL_SEARCH_PATHS[@]}"; do
    if [ -d "$search_path" ]; then
        # Look for model GGUF files (Gemma-3-Glitter)
        found=$(find "$search_path" -maxdepth 2 -name "*.gguf" ! -name "*mmproj*" 2>/dev/null | head -1)
        if [ -n "$found" ]; then
            MODEL_PATH="$found"
            break
        fi
    fi
done

if [ -z "$MODEL_PATH" ]; then
    echo "ERROR: Model not found (searched for Gemma models)"
    echo "Searched paths: ${MODEL_SEARCH_PATHS[@]}"
    exit 1
fi

if [ ! -f "$MODEL_PATH" ]; then
    echo "ERROR: Model file not found: $MODEL_PATH"
    exit 1
fi

# Auto-detect mmproj file in same directory
MODEL_DIR=$(dirname "$MODEL_PATH")
MMPROJ_PATH=$(find "$MODEL_DIR" -maxdepth 1 -name "*.mmproj*.gguf" 2>/dev/null | head -1)

MODEL_SIZE=$(du -h "$MODEL_PATH" | cut -f1)
echo "✓ Model found: $(basename "$MODEL_PATH") ($MODEL_SIZE)"
if [ -n "$MMPROJ_PATH" ]; then
    MMPROJ_SIZE=$(du -h "$MMPROJ_PATH" | cut -f1)
    echo "✓ Multimodal projection: $(basename "$MMPROJ_PATH") ($MMPROJ_SIZE)"
fi
echo ""

# Create log directory if needed
mkdir -p "$(dirname "$LOG_FILE")"

# Start server in foreground (systemd/v7 will manage lifecycle)
echo "Starting llama-server with vision model..."
echo "[$(date)] Starting llama-server-vision" >> "$LOG_FILE"

# Server configuration using GPU-accelerated binary
# Uses compiled llama-server with CUDA 12.5.0 support
# Parameters:
# - ngl 15: GPU layers (reduced for stability with vision models + mmproj)
# - c 1024: Context size suitable for analysis
# - t 4: Thread count for CPU processing
# - mmproj: Multimodal projection for vision support (if available)
export LD_LIBRARY_PATH="${LLAMA_LIB_PATH}:${LD_LIBRARY_PATH}"

# Build command with optional mmproj
SERVER_CMD="$LLAMA_SERVER -m $MODEL_PATH -p $PORT -ngl 15 -c 1024 -t 4"
if [ -n "$MMPROJ_PATH" ]; then
    SERVER_CMD="$SERVER_CMD --mmproj $MMPROJ_PATH"
    echo "Launching with vision support (mmproj)..."
fi

eval "$SERVER_CMD >> $LOG_FILE 2>&1"

#,,,.,...,..,,.,,,.,,,,,.,,..,,.,,..,,,.,,,,.,..,,...,.,.,,.,,,,.,,,.,.,,,.,,,
#E2ZJ55XHVEXHQL25JBO5OS3UMBLBNEEIVLXGKP7VYYGHOX4JHVPB54KTWCMJTEIXLU2IMHTJD25I6
#\\\|6F4SML4VINDRQWFE5ZAN4RGE44RBSUSPEE4IBHPV425GPJK3PLT \ / AMOS7 \ YOURUM ::
#\[7]YOCZXVKI7VFLL65NTQ3TXCWR27ZTCGHNCVWB67ILHVLMQE7NQSBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
