#!/bin/bash
# Link-upgrade negotiation diagnostic

set -e

# Find Protocol-7 root using robust discovery utility
# Works from bin/ before migration, and from bin/dev/tests/* after
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

fi


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

#,,.,,,,.,.,,,.,,,.,.,..,,,.,,,.,,...,...,...,..,,...,...,.,,,.,.,,,,,.,.,,,.,
#BJQZYOMXIP5KJQJCSQS2HWTHAIZ6S5GLATEC4RS75NOTF4QAUYMH2NRAJXOFHC2TNTTLFBPYAJ27E
#\\\|SGWEJK6ZTZCIG4MEX2LBNYVEPPKCAJBOPHX4WMP7OLZYGEHLSFA \ / AMOS7 \ YOURUM ::
#\[7]4BM7YGH4MIXYQHMZJJFEOZZTIF3G6YTTYY2U5ME6IPUAPQNG4AAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
