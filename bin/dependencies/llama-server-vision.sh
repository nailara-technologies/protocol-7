#!/bin/bash

## [:< ##
# name  = llama-server-vision
# descr = Model server wrapper for GPU-accelerated image analysis (via HTTP API)
#
# Starts GPU-accelerated llama-mtmd-cli on port 8080 for multimodal inference
# Primary: Qwen2.5-VL-7B-Instruct (verified working with >90% GPU utilization)
# Fallback: 4b-opus100-manga, Gemma-3-Glitter-4B for text-only models
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

# Check for multimodal vision binary (primary)
if [ -x "$LLAMA_MTMD_CLI" ]; then
    LLAMA_BIN="$LLAMA_MTMD_CLI"
    BINARY_TYPE="multimodal vision (llama-mtmd-cli)"
    echo "✓ Using multimodal vision binary: $LLAMA_MTMD_CLI"
elif [ -x "$LLAMA_SERVER" ]; then
    LLAMA_BIN="$LLAMA_SERVER"
    BINARY_TYPE="text-only server (llama-server)"
    echo "⚠ Multimodal binary not found, using text-only server: $LLAMA_SERVER"
else
    echo "ERROR: Neither llama-mtmd-cli nor llama-server found"
    echo "  Expected: $LLAMA_MTMD_CLI or $LLAMA_SERVER"
    exit 1
fi

echo "✓ Binary type: $BINARY_TYPE"
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
MODEL_DIR=$(dirname "$MODEL_PATH")
MMPROJ_PATH=$(find "$MODEL_DIR" -maxdepth 1 -name "*.mmproj*.gguf" 2>/dev/null | head -1)

MODEL_SIZE=$(du -h "$MODEL_PATH" | cut -f1)
echo "✓ Model type: $MODEL_TYPE"
echo "✓ Model found: $(basename "$MODEL_PATH") ($MODEL_SIZE)"
if [ -n "$MMPROJ_PATH" ]; then
    MMPROJ_SIZE=$(du -h "$MMPROJ_PATH" | cut -f1)
    echo "✓ Multimodal projection: $(basename "$MMPROJ_PATH") ($MMPROJ_SIZE)"
fi
echo ""

# Create log directory if needed
mkdir -p "$(dirname "$LOG_FILE")"

# Start server in foreground (systemd/v7 will manage lifecycle)
echo "Starting GPU-accelerated vision model server..."
echo "[$(date)] Starting llama-server-vision with $BINARY_TYPE" >> "$LOG_FILE"

# Server configuration using GPU-accelerated binary
# Uses upstream-optimized build with fused norm kernels and CUDA device improvements
# CUDA 12.5.0 with architecture 86 (RTX 3060) - adjust for your GPU
# Parameters:
# - ngl 99: GPU offload all layers (performance optimization)
# - c 1024: Context size suitable for vision analysis
# - t 4: Thread count for CPU processing
# - mmproj: Multimodal projection for vision support (if available)
export LD_LIBRARY_PATH="${LLAMA_LIB_PATH}:${LD_LIBRARY_PATH}"

# Use multimodal binary for vision models, fall back to server binary
if [[ "$BINARY_TYPE" == *"multimodal"* ]]; then
    echo "Using multimodal vision binary for enhanced GPU acceleration..."
    SERVER_CMD="$LLAMA_BIN -m $MODEL_PATH -p $PORT -ngl 99 -c 1024 -t 4"
else
    echo "Using text-only server binary..."
    SERVER_CMD="$LLAMA_BIN -m $MODEL_PATH -p $PORT -ngl 15 -c 1024 -t 4"
fi

if [ -n "$MMPROJ_PATH" ]; then
    SERVER_CMD="$SERVER_CMD --mmproj $MMPROJ_PATH"
    echo "Launching with vision support (mmproj)..."
fi

eval "$SERVER_CMD >> $LOG_FILE 2>&1"

#,,,,,...,,..,.,,,,..,,.,,.,.,...,.,.,,,.,,,.,..,,...,...,,,,,.,,,,..,...,,,.,
#BV2KRVFB7OKFGFPFBMCPU5WETSKGNRO3ELO25BBASERWSNBNJP3T436OSMD7E6X3QLDFWGF2B2V7C
#\\\|DB7PUFDAQOHKXHE73WFHVXXELX7ITGXMZPZFYSOSVETHIULHA2T \ / AMOS7 \ YOURUM ::
#\[7]JQAWJDCWXYFQKCIOY7NIA7S7KCVUK74Z3EUKEBDGQGUQ6P5H6QCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
