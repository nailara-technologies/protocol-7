#!/bin/bash
# Fast link-upgrade testing workflow using Protocol-7 buffer system
# Provides real-time debugging without full system overhead

set -e

# Discover Protocol-7 source root path (relative to this script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
P7_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Verify we found the Protocol-7 root
if [ ! -f "$P7_ROOT/bin/nshell" ]; then
    echo "Error: Could not find Protocol-7 root directory"
    echo "Expected to find bin/nshell at: $P7_ROOT/bin/nshell"
    exit 1
fi

cd "$P7_ROOT"

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

#,,..,,,.,,.,,,..,,,.,..,,,.,,.,.,,.,,,.,,,,,,..,,...,...,,.,,.,,,.,,,..,,,..,
#UB2UPZJKIMVKC2J5W32XYTHAT2H5GDSAHV52UM62YHXASCUR5B6DRQWQVYFTUQNENI3E6J5I74UGU
#\\\|DGQTSH5NCMF6BPS4IRF3O6PWWDIQF4GJQ756HWXNF57KNXGGRDK \ / AMOS7 \ YOURUM ::
#\[7]6L5MO7TWD54GIBPPGR3JFEO56WEA7VDPFXFRNMS6QKK3AFBWRYAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
