#!/bin/bash
# Link-upgrade negotiation diagnostic
# Provides detailed analysis of each step in the handshake

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
P7_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ ! -f "$P7_ROOT/bin/nshell" ]; then
    echo "Error: Could not find Protocol-7 root directory"
    exit 1
fi

cd "$P7_ROOT"

echo "=== Link-Upgrade Negotiation Diagnostic ==="
echo ""

# Clear buffer before test
echo "[Step 0] Clearing server buffer..."
p7 cube.erase-buffer zenka 2>/dev/null || true
sleep 1
echo ""

# Run nshell with link-upgrade
echo "[Step 1-5] Running client handshake..."
echo "Command: DEBUG=1 PROTOCOL_7_LINK_UPGRADE=yes ./bin/nshell -notty -u taeki"
echo ""

timeout 15 bash -c "echo 'echo test' | DEBUG=1 PROTOCOL_7_LINK_UPGRADE=yes ./bin/nshell -notty -u taeki 2>&1" > /tmp/link-upgrade-diag.log 2>&1 || true

echo "Client output:"
echo "---"
grep "\[link-upgrade\]" /tmp/link-upgrade-diag.log || echo "(No link-upgrade messages found)"
echo "---"
echo ""

# Analyze server-side
echo "[Server Analysis] Checking server logs for link-upgrade..."
echo "---"
p7 cube.show-buffer zenka 2>&1 | grep -E "link-upgrade|state.*2|state.*3|ephemeral|DH|encoding" | tail -20 || echo "No matching logs found"
echo "---"
echo ""

# Check for errors
echo "[Error Check] Looking for failures..."
echo "---"
p7 cube.show-buffer zenka 2>&1 | grep -iE "error|failed|timeout|connection" | tail -10 || echo "No errors found"
echo "---"
echo ""

# Show full client output for analysis
echo "[Full Client Output]"
echo "---"
cat /tmp/link-upgrade-diag.log | head -100
echo "---"
echo ""

# Summary
echo "=== Diagnostic Summary ==="
echo ""
echo "To investigate further:"
echo "  1. Server logs: p7 cube.show-buffer zenka | tail -100"
echo "  2. Full output: cat /tmp/link-upgrade-diag.log"
echo "  3. Grep for state: p7 cube.show-buffer zenka | grep state"
echo "  4. Check errors: p7 cube.show-buffer zenka | grep -i error"
echo ""

#,,,,,,,.,..,,...,...,.,,,,,,,,..,,.,,,,.,...,..,,...,...,,..,,.,,.,,,...,,,.,
#4GAA4WHUON4JAADBC7L5LKE3YMZ4ZCZXDPLQ3YGX2BRDPUGF4I24TGZ3NOV46GN3Q7GTNVG7CMHXW
#\\\|FRDKNAXNWL6GI2ZTCHJA7ADEPLXTRXD6VGPZZ4MEDRTDL5QT5QS \ / AMOS7 \ YOURUM ::
#\[7]YN5HGNXHXJYWH2YRHXJYCCOP7SXLJFLDC7PF533VHQJWSWBMWOCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
