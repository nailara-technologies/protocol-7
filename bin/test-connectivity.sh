#!/bin/bash
# Quick connectivity test using p7 heart
# Tests basic system responsiveness before running link-upgrade tests

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
P7_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ ! -f "$P7_ROOT/bin/nshell" ]; then
    echo "Error: Could not find Protocol-7 root directory"
    exit 1
fi

cd "$P7_ROOT"

echo "=== Protocol-7 Connectivity Test ==="
echo ""

echo "[1/3] Testing cube connectivity..."
echo "---"
p7 whoami 2>&1 | head -3 || echo "ERROR: Could not connect to cube"
echo "---"
echo ""

echo "[2/3] Testing latency with p7 heart..."
echo "---"
p7 heart 2>&1 | head -10 || echo "ERROR: Heart command failed"
echo "---"
echo ""

echo "[3/3] Listing active zenki..."
echo "---"
p7 v7.list zenki 2>&1 | head -10 || echo "ERROR: Could not list zenki"
echo "---"
echo ""

echo "=== Connectivity Test Complete ==="
echo ""
echo "If all tests show successful responses, system is ready for link-upgrade testing."
echo ""
