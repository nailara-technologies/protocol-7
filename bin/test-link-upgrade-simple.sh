#!/bin/bash
# Simple link-upgrade test script
# Tests client-server negotiation without full Protocol-7 overhead

set -e

# Discover Protocol-7 source root path (relative to this script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
P7_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Verify we found the Protocol-7 root
if [ ! -f "$P7_ROOT/bin/nshell" ]; then
    echo "Error: Could not find Protocol-7 root directory"
    echo "Expected to find bin/nshell at: $P7_ROOT/bin/nshell"
    exit 1
fi

cd "$P7_ROOT"

# Configuration
TIMEOUT=10

echo "=== Link-Upgrade Negotiation Test ==="
echo ""

# Test 1: Basic connection
echo "[Test 1] Testing basic nshell connection..."
timeout $TIMEOUT bash -c "echo 'echo connected' | DEBUG=1 PROTOCOL_7_LINK_UPGRADE=yes ./bin/nshell -notty -u taeki 2>&1" | head -20 || true

echo ""
echo "[Test 2] Testing link-upgrade with debug output..."
timeout $TIMEOUT bash -c "echo 'echo test' | DEBUG=1 PROTOCOL_7_LINK_UPGRADE=yes ./bin/nshell -notty -u taeki 2>&1" | grep -E "\[link-upgrade\]|DH|ephemeral" || echo "No link-upgrade messages found"

echo ""
echo "=== Test Complete ==="
