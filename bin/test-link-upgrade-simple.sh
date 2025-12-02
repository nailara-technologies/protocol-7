#!/bin/bash
# Simple link-upgrade test script
# Tests client-server negotiation without full Protocol-7 overhead

set -e

# Find Protocol-7 root using robust discovery utility
# Works from bin/ before migration, and from bin/dev/tests/link-upgrade/ after
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIND_ROOT_SCRIPT=""

# Try standard locations based on script depth
for candidate in \
    "$SCRIPT_DIR/dev/tests/find-protocol-7-root.sh" \
    "$SCRIPT_DIR/../dev/tests/find-protocol-7-root.sh" \
    "$SCRIPT_DIR/../find-protocol-7-root.sh"; do
    if [ -f "$candidate" ]; then
        FIND_ROOT_SCRIPT="$candidate"
        break
    fi
done

if [ -z "$FIND_ROOT_SCRIPT" ]; then
    echo "Error: Could not find find-protocol-7-root.sh utility"
    exit 1
fi

source "$FIND_ROOT_SCRIPT"
P7_ROOT=$(find_protocol_7_root) || exit 1

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

#,,.,,.,.,.,.,,..,,.,,,,.,...,.,,,..,,..,,,.,,..,,...,...,.,,,,.,,,.,,,..,.,.,
#ATGVHUOKPIXAI3QX6VYTXC5J6P3ROBX474EK7SAPUH2V4OQQBF4JEJG7CFIMT2UM6P7OZPMQVKPIC
#\\\|XAL2S4ZS5NKGDDRG3U4J4ZYKAAIRMW6HGLFROKKGLWXK45IWPG6 \ / AMOS7 \ YOURUM ::
#\[7]DWKS725E7WCZPAKSRBYJIM3UBQV4J5HRF3KKTPDBLU3XZTZ756AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
