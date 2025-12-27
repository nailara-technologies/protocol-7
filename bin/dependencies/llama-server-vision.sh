#!/bin/bash

## [:< ##
# name  = llama-server-vision
# descr = HTTP server wrapper for GPU-accelerated vision model inference
#
# Starts GPU-accelerated llama-server on port 8080 with optional vision support
# Primary Model: Qwen2.5-VL-7B-Instruct (verified working with >90% GPU utilization)
# Fallback: 4b-opus100-manga, Gemma-3-Glitter-4B for text-only models
# Build: Upstream-optimized with fused norm kernels, CUDA device improvements
# HTTP Server: llama-server for API endpoints
# CLI Analysis: llama-mtmd-cli-cuda available for subprocess image analysis
# Managed as v7 ext-bin zenka for image-quality dependencies

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Vision model configuration
# Primary: Qwen2.5-VL (verified working with >90% GPU utilization, fused norm optimizations)
# Fallback: 4b-opus100-manga and Gemma-3-Glitter for text-only or alternative analysis
MODEL_SEARCH_PATHS=(
    "/mnt/ext-xfs-data/models-lmstudio/Qwen"
    "/mnt/m/mradermacher/Qwen"
    "/mnt/m/mradermacher/4b-opus100-manga-GGUF"
    "/mnt/ext-xfs-data/models-lmstudio/mradermacher/4b-opus100-manga-GGUF"
    "/mnt/ext-xfs-data/models-lmstudio/mradermacher/Gemma-3-Glitter-4B-Uncensored-GGUF"
    "/mnt/m/lmstudio-community/mradermacher/Gemma-3-Glitter-4B-Uncensored-GGUF"
)

# Multimodal vision binary (llama-mtmd-cli-cuda) - has CLIP vision support
# Falls back to text-only llama-server-cuda if not available
LLAMA_MTMD_CLI="${LLAMA_MTMD_CLI:-/data/source/ik_llama.cpp/llama-mtmd-cli-cuda}"
LLAMA_SERVER="${LLAMA_SERVER:-/data/source/ik_llama.cpp/llama-server-cuda}"
LLAMA_LIB_PATH="${LLAMA_LIB_PATH:-/data/source/ik_llama.cpp}"
PORT="${LLAMA_SERVER_PORT:-8080}"
LOG_FILE="/var/log/protocol-7/llama-server-vision.log"

echo "=== Starting Vision Model Server (llama-mtmd-cli) ==="
echo "Port: $PORT"
echo ""

# HTTP server uses llama-server (not multimodal CLI)
# Note: llama-mtmd-cli is for direct image analysis (subprocess), not for HTTP server
if [ -x "$LLAMA_SERVER" ]; then
    LLAMA_BIN="$LLAMA_SERVER"
    echo "✓ Using llama-server for HTTP endpoint: $LLAMA_SERVER"
else
    echo "ERROR: llama-server binary not found at $LLAMA_SERVER"
    exit 1
fi

# Multimodal binary note for subprocess image analysis
if [ -x "$LLAMA_MTMD_CLI" ]; then
    echo "✓ Multimodal binary available for subprocess image analysis: $LLAMA_MTMD_CLI"
else
    echo "⚠ Multimodal binary not found (will use server for image analysis)"
fi

echo "✓ Library path: $LLAMA_LIB_PATH"

# Find model - prioritize Qwen2.5-VL vision models
MODEL_PATH=""
MODEL_TYPE=""

# Priority 1: Qwen2.5-VL (verified working with >90% GPU utilization)
for search_path in "${MODEL_SEARCH_PATHS[@]}"; do
    if [[ "$search_path" == *"Qwen"* ]] && [ -d "$search_path" ]; then
        found=$(find "$search_path" -maxdepth 2 -name "*Qwen*2*5*VL*.gguf" ! -name "*mmproj*" 2>/dev/null | head -1)
        if [ -n "$found" ]; then
            MODEL_PATH="$found"
            MODEL_TYPE="Qwen2.5-VL (vision)"
            break
        fi
    fi
done

# Priority 2: Any other models (4b-opus100-manga, Gemma-3-Glitter, etc)
if [ -z "$MODEL_PATH" ]; then
    for search_path in "${MODEL_SEARCH_PATHS[@]}"; do
        if [ -d "$search_path" ]; then
            found=$(find "$search_path" -maxdepth 2 -name "*.gguf" ! -name "*mmproj*" 2>/dev/null | head -1)
            if [ -n "$found" ]; then
                MODEL_PATH="$found"
                MODEL_TYPE="Alternative model"
                break
            fi
        fi
    done
fi

if [ -z "$MODEL_PATH" ]; then
    echo "ERROR: Model not found in search paths"
    echo "Searched paths: ${MODEL_SEARCH_PATHS[@]}"
    exit 1
fi

if [ ! -f "$MODEL_PATH" ]; then
    echo "ERROR: Model file not found: $MODEL_PATH"
    exit 1
fi

# Auto-detect mmproj file in same directory
# Matches: mmproj-*.gguf, *mmproj*.gguf, etc.
MODEL_DIR=$(dirname "$MODEL_PATH")
MMPROJ_PATH=$(find "$MODEL_DIR" -maxdepth 1 -name "*mmproj*.gguf" 2>/dev/null | head -1)

MODEL_SIZE=$(du -h "$MODEL_PATH" | cut -f1)
echo "✓ Model type: $MODEL_TYPE"
echo "✓ Model found: $(basename "$MODEL_PATH") ($MODEL_SIZE)"

# For vision models, mmproj is required
if [[ "$MODEL_TYPE" == *"vision"* ]]; then
    if [ -n "$MMPROJ_PATH" ]; then
        MMPROJ_SIZE=$(du -h "$MMPROJ_PATH" | cut -f1)
        echo "✓ Multimodal projection: $(basename "$MMPROJ_PATH") ($MMPROJ_SIZE)"
    else
        echo "ERROR: Vision model requires mmproj file but none found in: $MODEL_DIR"
        echo "Expected file patterns: mmproj-*.gguf, *mmproj*.gguf"
        exit 1
    fi
elif [ -n "$MMPROJ_PATH" ]; then
    # Text-only model but mmproj available - will be used if provided
    MMPROJ_SIZE=$(du -h "$MMPROJ_PATH" | cut -f1)
    echo "✓ Multimodal projection available: $(basename "$MMPROJ_PATH") ($MMPROJ_SIZE)"
fi
echo ""

# Create log directory if needed
mkdir -p "$(dirname "$LOG_FILE")"

# Start server in foreground (systemd/v7 will manage lifecycle)
echo "Starting GPU-accelerated HTTP server..."
echo "[$(date)] Starting llama-server-vision" >> "$LOG_FILE"

# Server configuration using GPU-accelerated llama-server
# Uses upstream-optimized build with fused norm kernels and CUDA device improvements
# CUDA 12.5.0 with architecture 86 (RTX 3060) - adjust for your GPU
# Parameters:
# - ngl 99: GPU offload all layers (performance optimization with vision models)
# - c 1024: Context size suitable for vision analysis
# - t 4: Thread count for CPU processing
# - mmproj: Multimodal projection for vision support (if available)
export LD_LIBRARY_PATH="${LLAMA_LIB_PATH}:${LD_LIBRARY_PATH}"

# Build server command
SERVER_CMD="$LLAMA_BIN -m $MODEL_PATH -p $PORT -ngl 99 -c 1024 -t 4"

if [ -n "$MMPROJ_PATH" ]; then
    SERVER_CMD="$SERVER_CMD --mmproj $MMPROJ_PATH"
    echo "Launching HTTP server with vision support (mmproj)..."
else
    echo "Launching HTTP server (text-only model)..."
fi

eval "$SERVER_CMD >> $LOG_FILE 2>&1"

#,,.,,..,,.,.,,,,,..,,,..,...,,,.,,,.,,..,.,.,..,,...,..,,.,.,,.,,.,.,,..,,..,
#RP7SXUFT3QLYRQM3BYYJMSI6EHWJVNMNEZ4WXQLOMSE7LBE55HBBZZZEPLNWIZAW6SS6LEYLRHVPA
#\\\|DFYQ2XYKCY4D4WQJBEJC6YF6BX42T5ITZC4K7U7LIWMUKHISP3B \ / AMOS7 \ YOURUM ::
#\[7]YYPJNMMLQGZFRAOEXBNMUWVZFNU27CQTZ4NHSMSRH32BAQXY3OBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
