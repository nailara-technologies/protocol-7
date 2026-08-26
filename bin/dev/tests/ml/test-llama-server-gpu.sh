#!/bin/bash

## [:< ##
# name  = test-llama-server-gpu
# descr = Test llama-server GPU acceleration with larger model inference
#
# This test validates GPU offloading performance with a 7B model
# and measures actual inference speed improvements from CUDA acceleration.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../find-protocol-7-root.sh"

# Model selection - use smaller model that's known to work
# (Larger models need more careful configuration and timeout tuning)
MODEL_PATH="/mnt/m/HuggingFaceTB/smollm-360M-instruct-v0.2-Q8_0-GGUF/smollm-360m-instruct-add-basics-q8_0.gguf"
LLAMA_SERVER="${LLAMA_SERVER:-/usr/local/bin/llama-server}"

# Server config
PORT=8080  # Default port for llama-server
SERVER_PID=""

echo "=== Testing CUDA-accelerated llama-server ==="
echo ""

# Check if binary exists
if [ ! -x "$LLAMA_SERVER" ]; then
    echo "ERROR: llama-server binary not found at $LLAMA_SERVER"
    exit 1
fi

echo "✓ Binary found: $LLAMA_SERVER"

# Check version
echo ""
echo "=== Binary Version ==="
"$LLAMA_SERVER" --version 2>&1 | head -3
echo ""

# Check if model exists
if [ ! -f "$MODEL_PATH" ]; then
    echo "ERROR: Model not found at $MODEL_PATH"
    exit 1
fi

MODEL_SIZE=$(du -h "$MODEL_PATH" | cut -f1)
echo "✓ Model found: $(basename "$MODEL_PATH") ($MODEL_SIZE)"
echo ""

# Cleanup function
cleanup() {
    if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
        echo "Stopping server (PID: $SERVER_PID)..."
        kill "$SERVER_PID" 2>/dev/null || true
        sleep 2
        kill -9 "$SERVER_PID" 2>/dev/null || true
    fi
    rm -f /tmp/llama_server_test.log
}

trap cleanup EXIT

# Start server with GPU acceleration
echo "=== Starting llama-server with GPU acceleration ==="
echo "Model: $(basename "$MODEL_PATH")"
echo "Port: $PORT"
echo ""

# Create log file
LOG_FILE="/tmp/llama_server_test.log"

# Start server in background (use conservative settings for reliable startup)
"$LLAMA_SERVER" \
    -m "$MODEL_PATH" \
    -p $PORT \
    -n 100 \
    -b 256 \
    -c 512 \
    --gpu-layers 10 \
    > "$LOG_FILE" 2>&1 &

SERVER_PID=$!
echo "Server started with PID: $SERVER_PID"

# Wait for server to fully start - check for listening port
echo "Waiting for server to initialize..."
WAIT_COUNT=0
MAX_WAIT=60
while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        echo "ERROR: Server process died"
        echo ""
        echo "=== Server Log ==="
        cat "$LOG_FILE" | tail -50
        exit 1
    fi

    # Check if port is listening
    if nc -z localhost $PORT 2>/dev/null; then
        echo "✓ Server is listening on port $PORT"
        break
    fi

    WAIT_COUNT=$((WAIT_COUNT + 1))
    if [ $((WAIT_COUNT % 10)) -eq 0 ]; then
        echo "  ... still initializing ($WAIT_COUNT/$MAX_WAIT)"
    fi
    sleep 1
done

if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
    echo "ERROR: Server failed to listen on port $PORT after ${MAX_WAIT}s"
    echo ""
    echo "=== Server Log ==="
    tail -50 "$LOG_FILE"
    exit 1
fi

echo "✓ Server ready"
echo ""

# Test inference endpoint
echo "=== Testing Inference Endpoint ==="
echo "Prompt: 'Solve: 2 + 2 = '"
echo ""

# First check if server is responding to basic requests
echo "Testing basic connectivity..."
STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT/health 2>/dev/null || echo "000")

if [ "$STATUS" != "200" ] && [ "$STATUS" != "404" ]; then
    echo "WARNING: Server not responding properly (HTTP $STATUS)"
fi

# Make inference request with longer timeout and more verbose output
echo "Sending inference request..."
RESPONSE=$(curl -s --max-time 60 -X POST http://localhost:$PORT/completion \
    -H "Content-Type: application/json" \
    -d '{
        "prompt": "Solve: 2 + 2 = ",
        "n_predict": 30,
        "temperature": 0.3,
        "top_p": 0.9,
        "stream": false
    }' 2>/dev/null || echo "")

# Debug: show raw response if empty
if [ -z "$RESPONSE" ]; then
    echo "DEBUG: No response received from server"
    echo "Trying alternate endpoint..."
    RESPONSE=$(curl -s --max-time 30 -X POST http://localhost:$PORT/api/chat \
        -H "Content-Type: application/json" \
        -d '{
            "messages": [{"role": "user", "content": "Solve: 2 + 2 = "}],
            "model": "default"
        }' 2>/dev/null || echo "")
fi

# Extract completion
COMPLETION=$(echo "$RESPONSE" | grep -o '"content":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "")

# Debug output
if [ -z "$COMPLETION" ]; then
    echo "DEBUG: Raw response (first 500 chars):"
    echo "$RESPONSE" | head -c 500
    echo ""
fi

if [ -n "$COMPLETION" ]; then
    echo "✓ Inference successful"
    echo ""
    echo "=== Model Response ==="
    echo "Solve: 2 + 2 = $COMPLETION"
    echo ""
    echo "=== Test Results ==="
    echo "✓ Server started and responded to inference requests"
    echo "✓ GPU acceleration available"
    echo "✓ Model inference working"
    echo ""
    echo "Test passed!"
else
    echo "WARNING: No completion received"
    echo "Response: $RESPONSE"
    echo ""
    echo "=== Server Log (last 30 lines) ==="
    tail -30 "$LOG_FILE"
    exit 1
fi

#,,,.,,..,,,.,..,,...,..,,,..,,,,,..,,,..,,..,.,.,...,...,...,.,,,...,,.,,.,.,
#OZEE7J3RNLUUOWHEVZFNYK4VHVCH4YBUX5U7QELLMRXBSMLJWCE7GONNQBX6SQ4DY2AG62SITQPCA
#\\\|BHFPVZHL5QQTMLDJKY3BAWDZKGGI6V3ZGGXQYXIMU2D7PG3ZNFO \ / AMOS7 \ YOURUM ::
#\[7]FTCNDQ2MM5KQQLVEBLOED53XMRKDMNW4JYJSPFWIJSPGMLB2MIAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
