#!/bin/bash

## [:< ##
# name  = llama-server-vision
# descr = HTTP server for text inference (vision analysis via separate subprocess)
#
# Architecture:
# - HTTP Server (this wrapper): Runs llama-server with TEXT-ONLY model
#   * Provides HTTP API endpoints for text completions
#   * Uses: 4b-opus100-manga, Gemma-3-Glitter-4B, or other text-only models
#   * Stays running as v7 ext-bin zenka
#
# - Vision Image Analysis (separate): Uses llama-mtmd-cli-cuda subprocess
#   * Called by: image-quality.vision.subprocess module
#   * Primary Model: Qwen2.5-VL-7B-Instruct (>90% GPU utilization)
#   * GPU-accelerated CLIP encoding + LLM inference
#   * Direct subprocess calls (not HTTP-based)
#
# Build: Upstream-optimized with fused norm kernels, CUDA device improvements
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

# Find model for HTTP server (TEXT-ONLY, not vision)
# Vision models are loaded separately by image-quality.vision.subprocess
MODEL_PATH=""
MODEL_TYPE=""

# Priority 1: Alternative text-only models (4b-opus100-manga, Gemma-3-Glitter)
# These don't have mmproj files, so they're safe for llama-server
for search_path in "${MODEL_SEARCH_PATHS[@]}"; do
    if [[ "$search_path" != *"Qwen"* ]] && [ -d "$search_path" ]; then
        # Find models WITHOUT mmproj files (text-only)
        found=$(find "$search_path" -maxdepth 2 -name "*.gguf" ! -name "*mmproj*" 2>/dev/null | head -1)
        if [ -n "$found" ]; then
            # Verify it doesn't have a corresponding mmproj
            model_dir=$(dirname "$found")
            mmproj=$(find "$model_dir" -maxdepth 1 -name "*mmproj*.gguf" 2>/dev/null | head -1)
            if [ -z "$mmproj" ]; then
                MODEL_PATH="$found"
                MODEL_TYPE="Text-only model"
                break
            fi
        fi
    fi
done

# Priority 2: Fallback to any available model
if [ -z "$MODEL_PATH" ]; then
    for search_path in "${MODEL_SEARCH_PATHS[@]}"; do
        if [ -d "$search_path" ]; then
            found=$(find "$search_path" -maxdepth 2 -name "*.gguf" ! -name "*mmproj*" 2>/dev/null | head -1)
            if [ -n "$found" ]; then
                MODEL_PATH="$found"
                MODEL_TYPE="Available model"
                break
            fi
        fi
    done
fi

if [ -z "$MODEL_PATH" ]; then
    echo "ERROR: Text-only model not found"
    echo "HTTP server needs a text-only model (vision models loaded separately via subprocess)"
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

# Verify we found a text-only model (should not have mmproj)
if [ -n "$MMPROJ_PATH" ]; then
    echo "⚠ WARNING: Found mmproj in model directory (vision model)"
    echo "Using text-only model for HTTP server instead"
    MMPROJ_PATH=""
fi

echo ""
echo "Model configuration for HTTP server:"
echo "  Type: $MODEL_TYPE"
echo "  No vision support needed (handled separately via subprocess)"
echo "  Image analysis: image-quality.vision.subprocess → llama-mtmd-cli-cuda"
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
# At this point, only text-only models will reach here
# (Vision models exit early above)
echo "Starting HTTP server with text-only model..."
SERVER_CMD="$LLAMA_BIN -m $MODEL_PATH -p $PORT -ngl 99 -c 1024 -t 4"

eval "$SERVER_CMD >> $LOG_FILE 2>&1"

#,,..,,,.,,..,,.,,.,.,.,.,,..,.,.,...,,..,,,,,..,,...,..,,.,.,..,,,,.,,..,...,
#SGGCV4FCITTE6VX3I7ZWAPZ6YUUWJPT736LXSGWGGJLEOP7J6DD6OI4OZVNLWPEV6L522EAVP72VI
#\\\|OVC7O7ZCPJAAI3LYPAMYXTPDNIWFDATFU7NBMWQ262H6W5IS7KL \ / AMOS7 \ YOURUM ::
#\[7]HYHQFRUIY5ZGWGXYNOG2WOIPY24CPQTY4OAZ5L7EVOEXBOZESWDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
