#!/bin/bash

## [:< ##
# name  = llama-server-vision
# descr = Vision model server wrapper for image-quality zenka
#
# Starts llama-server with Qwen3-VL-8B vision model on port 8080
# Managed as v7 ext-bin zenka for image-quality dependencies

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Vision model configuration
MODEL_SEARCH_PATHS=(
    "/mnt/ext-xfs-data/models-lmstudio/Qwen3-VL-8B"
    "/mnt/ext-xfs-data/models-lmstudio/Qwen"
    "/mnt/m/lmstudio-community/Qwen3-VL-8B"
)

LLAMA_SERVER="${LLAMA_SERVER:-/usr/local/bin/llama-server}"
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

# Find vision model
MODEL_PATH=""
for search_path in "${MODEL_SEARCH_PATHS[@]}"; do
    if [ -d "$search_path" ]; then
        # Look for Qwen3-VL GGUF file
        found=$(find "$search_path" -maxdepth 2 -name "*qwen*vl*.gguf" -o -name "*Qwen*VL*.gguf" 2>/dev/null | head -1)
        if [ -n "$found" ]; then
            MODEL_PATH="$found"
            break
        fi
    fi
done

if [ -z "$MODEL_PATH" ]; then
    echo "ERROR: Qwen3-VL vision model not found"
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
echo "Starting llama-server with Qwen3-VL vision model..."
echo "[$(date)] Starting llama-server-vision" >> "$LOG_FILE"

# Server configuration for vision model
# Key parameters:
# - ngl 33: Maximum GPU layers for CUDA acceleration
# - c 2048: Context size suitable for image analysis
# - t 8: Thread count for CPU
"$LLAMA_SERVER" \
    -m "$MODEL_PATH" \
    -p "$PORT" \
    -ngl 33 \
    -c 2048 \
    -t 8 \
    --slot-save-path /tmp/llama_slots \
    >> "$LOG_FILE" 2>&1
#,,.,,,,.,..,,.,,,.,.,,,,,..,,,.,,.,.,.,.,.,.,..,,...,...,...,.,,,,..,.,.,,,.,
#VJPGSZC2LPHQEIP5UKNCFRCIXFSIA2DSU4PWPZ4SFD3PIXYWA6G222IR562W4O6GLQW4ELONI7TR6
#\\\|BUZRQKMHIPTXFU5HH3JPMOWBLEMTXLN5YPDIBLVHIITPFU7L6YR \ / AMOS7 \ YOURUM ::
#\[7]S7WFJSXRRMBAQY3SNW6MWITJFR4IF7Z36NV2YM4N2PQYPHCKRUCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
