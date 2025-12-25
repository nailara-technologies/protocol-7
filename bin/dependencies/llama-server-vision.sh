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

# Vision model configuration - prioritize models tested to work with llama-server
MODEL_SEARCH_PATHS=(
    "/mnt/ext-xfs-data/models-lmstudio/mradermacher/Gemma-3-Glitter-4B-Uncensored-GGUF"
    "/mnt/m/lmstudio-community/mradermacher/Gemma-3-Glitter-4B-Uncensored-GGUF"
    "/mnt/m/lmstudio-community/Qwen3-VL-8B-Instruct-GGUF"
    "/mnt/ext-xfs-data/models-lmstudio/Qwen3-VL-8B"
    "/mnt/ext-xfs-data/models-lmstudio/Qwen"
    "/mnt/m/lmstudio-community/Qwen3-VL-8B"
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
        # Look for vision model GGUF files (Gemma or Qwen, excluding mmproj)
        found=$(find "$search_path" -maxdepth 2 \( -name "*Gemma*Glitter*.gguf" -o -name "*Qwen*VL*.gguf" \) ! -name "*mmproj*" 2>/dev/null | head -1)
        if [ -n "$found" ]; then
            MODEL_PATH="$found"
            break
        fi
    fi
done

if [ -z "$MODEL_PATH" ]; then
    echo "ERROR: Vision model not found (searched for Gemma-3-Glitter or Qwen3-VL)"
    echo "Searched paths: ${MODEL_SEARCH_PATHS[@]}"
    exit 1
fi

if [ ! -f "$MODEL_PATH" ]; then
    echo "ERROR: Model file not found: $MODEL_PATH"
    exit 1
fi

MODEL_SIZE=$(du -h "$MODEL_PATH" | cut -f1)
echo "✓ Vision model found: $(basename "$MODEL_PATH") ($MODEL_SIZE)"
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
export LD_LIBRARY_PATH="${LLAMA_LIB_PATH}:${LD_LIBRARY_PATH}"

"$LLAMA_SERVER" \
    -m "$MODEL_PATH" \
    -p "$PORT" \
    -ngl 24 \
    -c 1024 \
    -t 4 \
    >> "$LOG_FILE" 2>&1

#,,..,,,,,,,,,..,,...,,,,,,,,,,,.,...,,,,,,.,,..,,...,...,...,,..,,.,,,..,...,
#AZTUHJKWK3PUHEW2SO5ORZFB2YIPEBOW4YVY5HPGYLMRUUOW5WJWGACV7FUICF642MFNX6ZPDDZOU
#\\\|G6MAWUPFXH2Q63HXNYMYOQTNB4LTXFT6KZW4AN7COM2XM7ZOUDS \ / AMOS7 \ YOURUM ::
#\[7]764HN2X43WUNRSPQC6NS3CK5NGWXQJNEEBMMUXG2GW7LYVS5TCCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
