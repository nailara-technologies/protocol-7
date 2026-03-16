#!/bin/bash

## [:< ##
# name  = test-llama-cli-cuda
# descr = Test GPU-accelerated llama-cli-cuda binary with inference
#
# This test validates that the ik_llama.cpp CUDA-accelerated build
# works correctly with the smollm-360M model.

set -e

# Find project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../find-protocol-7-root.sh"

MODEL_PATH="/mnt/m/HuggingFaceTB/smollm-360M-instruct-v0.2-Q8_0-GGUF/smollm-360m-instruct-add-basics-q8_0.gguf"
LLAMA_CLI="${LLAMA_CLI:-/usr/local/bin/llama-cli-cuda}"

echo "=== Testing CUDA-accelerated llama-cli ==="
echo ""

# Check if binary exists
if [ ! -x "$LLAMA_CLI" ]; then
    echo "ERROR: llama-cli-cuda binary not found at $LLAMA_CLI"
    exit 1
fi

echo "✓ Binary found: $LLAMA_CLI"

# Check version
echo ""
echo "=== Binary Version ==="
"$LLAMA_CLI" --version 2>&1 | head -3
echo ""

# Check if model exists
if [ ! -f "$MODEL_PATH" ]; then
    echo "ERROR: Model not found at $MODEL_PATH"
    exit 1
fi

echo "✓ Model found: $(basename "$MODEL_PATH") ($(du -h "$MODEL_PATH" | cut -f1))"
echo ""

# Run a quick inference test
echo "=== Running Inference Test ==="
echo "Prompt: 'Protocol-7 is a'"
echo ""

# Create a temporary output file
OUTPUT_FILE=$(mktemp)
trap "rm -f $OUTPUT_FILE" EXIT

# Run inference with timeout
if timeout 60 "$LLAMA_CLI" \
    -m "$MODEL_PATH" \
    -n 30 \
    -e \
    --prompt "Protocol-7 is a" \
    > "$OUTPUT_FILE" 2>&1; then

    # Extract output (skip the prompt part)
    OUTPUT=$(cat "$OUTPUT_FILE")

    # Check that we got some output
    if [ -z "$OUTPUT" ]; then
        echo "ERROR: No output from inference"
        exit 1
    fi

    echo "✓ Inference completed successfully"
    echo ""
    echo "=== Output ==="
    echo "$OUTPUT"
    echo ""
    echo "=== Test Results ==="
    echo "✓ Model loaded successfully"
    echo "✓ Inference executed without errors"
    echo "✓ Output generated"
    echo ""
    echo "Test passed!"

else
    echo "ERROR: Inference test failed or timed out"
    cat "$OUTPUT_FILE" 2>&1 | tail -20
    exit 1
fi

#,,.,,,.,,,,.,,..,..,,.,,,,..,,..,,,,,..,,..,,.,.,...,...,,..,...,.,,,.,.,,..,
#ZJYZH5PMZHOPJO7UO3VDZ6IURFCYB3W2JDG2NAGH4HKAQ2JRTLIB2FPCWFT3P7CLFRKZJBIXORN6C
#\\\|FFBCINNODIBJJCDZAA4WIYOUGKYE7BPD4T7FM4LHCPAVJ4RZ5ID \ / AMOS7 \ YOURUM ::
#\[7]3YTY6Z6SATITI53KSDSY7G7L3Q2HGEZIMEKY2QPLNYKATDH35QAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
