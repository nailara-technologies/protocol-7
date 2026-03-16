#!/bin/bash
# Simple link-upgrade test script
# Tests client-server negotiation without full Protocol-7 overhead

set -e

# Find Protocol-7 root using robust discovery utility
# This works regardless of where the script is located in the repo
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../dev/tests" && pwd)"
source "$TEST_DIR/find-protocol-7-root.sh"
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

#,,..,...,..,,,.,,,.,,,,.,.,,,,,.,..,,,,,,,.,,..,,...,...,...,,,,,.,.,...,,..,
#UT74SP7SCPQTYBYZMTQ3PBAQAMGGWCSOVYMLVK74BY7S4SED3QNEP6ZF6H2DJVPJL5FBHPBHUXXJ4
#\\\|XKGMKMB7WYYGDE2EPLLLCWLEBXMNRIFGARX6IIQSROTJXHFG3KN \ / AMOS7 \ YOURUM ::
#\[7]J2A4CW5D567N7ZSZRQMILIAK6NYXTMHJQW3JZLTAOTT76UDHC2AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
