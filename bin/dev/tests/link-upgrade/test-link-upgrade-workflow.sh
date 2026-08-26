#!/bin/bash
# Fast link-upgrade testing workflow using Protocol-7 buffer system

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

    echo "Expected to find bin/nshell at: $P7_ROOT/bin/nshell"
fi


echo "=== Link-Upgrade Testing Workflow ==="
echo ""

# Test parameters
TIMEOUT=10
USER="taeki"

# Step 1: Clear buffer to isolate new test output
echo "[1/5] Clearing cube buffer..."
p7 cube.erase-buffer zenka 2>/dev/null || true
echo "     Buffer cleared"
echo ""

# Step 2: Reload modules and restart cube
echo "[2/5] Reloading modules and restarting cube..."
p7 reload 2>/dev/null || true
sleep 2
echo "     Cube restarted"
echo ""

# Step 3: Run nshell with link-upgrade
echo "[3/5] Testing nshell with PROTOCOL_7_LINK_UPGRADE=yes..."
timeout $TIMEOUT bash -c "echo 'echo test' | DEBUG=1 PROTOCOL_7_LINK_UPGRADE=yes ./bin/nshell -notty -u $USER 2>&1" > /tmp/nshell-output.log 2>&1 || true
echo "     Test completed (client output saved)"
echo ""

# Step 4: View server-side logs from buffer
echo "[4/5] Server-side link-upgrade logs:"
echo "---"
p7 cube.show-buffer zenka | grep -E "link-upgrade|ephemeral|DH|shared|encryption" | tail -30 || echo "No link-upgrade messages found"
echo "---"
echo ""

# Step 5: Show client-side debug output
echo "[5/5] Client-side link-upgrade debug output:"
echo "---"
grep "\[link-upgrade\]" /tmp/nshell-output.log || echo "No client debug messages found"
echo "---"
echo ""

# Analysis
echo "=== Analysis ==="
echo ""

# Check for success indicators
if grep -q "Negotiation SUCCESS" /tmp/nshell-output.log 2>/dev/null; then
    echo "✅ Client-side: Link-upgrade negotiation SUCCEEDED"
else
    echo "❌ Client-side: Link-upgrade negotiation FAILED"
    echo "   Check client output above for error details"
fi

if p7 cube.show-buffer zenka 2>/dev/null | grep -q "link-upgrade negotiation complete" ; then
    echo "✅ Server-side: Link-upgrade negotiation COMPLETE"
elif p7 cube.show-buffer zenka 2>/dev/null | grep -q "ephemeral keypair lost"; then
    echo "❌ Server-side: Ephemeral keypair lost"
elif p7 cube.show-buffer zenka 2>/dev/null | grep -q "DH computation failed"; then
    echo "❌ Server-side: DH computation failed"
elif p7 cube.show-buffer zenka 2>/dev/null | grep -q "sent ephemeral public key"; then
    echo "⏳ Server-side: Sent ephemeral pubkey, awaiting client response"
else
    echo "❓ Server-side: No link-upgrade activity detected"
fi

echo ""
echo "=== Quick Debug Tips ==="
echo "View full cube buffer:     p7 cube.show-buffer zenka | tail -50"
echo "View all link-upgrade logs: p7 cube.show-buffer zenka | grep link-upgrade"
echo "Check for errors:          p7 cube.show-buffer zenka | grep -i error"
echo "View client output:        cat /tmp/nshell-output.log"
echo ""

#,,,,,,..,,,.,,,,,,..,...,,.,,,.,,...,,,,,,,.,..,,...,...,,,,,,,.,...,,..,,.,,
#FONXWHGJPP72K6VJYMRY4UKVZUTGIIO7XGRZM22U6TNI7VS5HMWEF4RX5DARCJJZJGXJ5BZH72RCS
#\\\|UXTXJML5VXIROC4TCHHQ5A5MTZH4FTBRG4D7EEDNF2STUTJUTBO \ / AMOS7 \ YOURUM ::
#\[7]KLLC6DK2MUEZKRES6CEW43N4INBTJD622C742Q36MEEFQF7PXKDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
