#!/bin/bash
# Link-upgrade test setup: Initialize v7-zenki zenka and cube
# Ensures proper system state before running negotiation tests

set -e

# Discover Protocol-7 source root path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
P7_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Verify we found the Protocol-7 root
if [ ! -f "$P7_ROOT/bin/nshell" ]; then
    echo "Error: Could not find Protocol-7 root directory"
    echo "Expected to find bin/nshell at: $P7_ROOT/bin/nshell"
    exit 1
fi

cd "$P7_ROOT"

echo "=== Link-Upgrade Test Setup ==="
echo ""

# Step 0: Check if system already running
echo "[0/7] Checking if system is already running..."
if p7 whoami 2>&1 | grep -q "@"; then
    echo "     System already running! Proceeding to reload..."
    SYSTEM_RUNNING=1
else
    echo "     No system running, will start v7-zenki"
    SYSTEM_RUNNING=0
fi
echo ""

if [ $SYSTEM_RUNNING -eq 0 ]; then
    # Step 1: Kill old processes (only if not running)
    echo "[1/7] Killing old v7-zenki and cube processes..."
    pkill -f "runsc\.v7-zenki" 2>/dev/null || true
    pkill -f "runsc\.cube" 2>/dev/null || true
    sleep 2
    echo "     Old processes cleaned up"
    echo ""

    # Step 2: Start v7-zenki in background
    echo "[2/7] Starting v7-zenki zenka in background..."
    ./bin/Protocol-7 v7-zenki -B 2>&1 | grep -E "protocol-7|backgrounding" || true
    echo "     V7-zenki started"
    echo ""

    # Step 3: Wait for initialization
    echo "[3/7] Waiting 7 seconds for v7-zenki and cube to initialize..."
    sleep 7
    echo "     Initialization complete"
    echo ""

    # Step 4: Verify sessions are running
    echo "[4/7] Checking active sessions..."
    echo "     Active sessions:"
    p7 list sessions 2>&1 | head -10 || echo "     (Could not list sessions)"
    echo ""

    # Step 5: Check zenka list
    echo "[5/7] Checking loaded zenki..."
    echo "     Loaded zenki:"
    p7 v7-zenki.list zenki 2>&1 | head -15 || echo "     (Could not list zenki)"
    echo ""

    # Step 6: Reload code
    echo "[6/7] Reloading modules and reinitializing..."
    p7 reload 2>&1 | grep -E "success|complete" || true
    sleep 2
    echo "     Code reload complete"
    echo ""

    # Step 7: Verify system is ready
    echo "[7/7] Testing connectivity with p7 heart..."
    if p7 heart 2>&1 | grep -q "beating"; then
        echo "     ✓ Heartbeat OK - System ready for testing"
    else
        echo "     ✗ Warning: No heartbeat detected"
    fi
    echo ""
else
    # System already running - just reload
    echo "[1/7] System already running, reloading code modules..."
    p7 reload 2>&1 | grep -E "success|complete" || true
    sleep 2
    echo "     Code reload complete"
    echo ""

    echo "[2/7] Verifying system status..."
    p7 whoami 2>&1 || true
    echo ""

    echo "[3/7] Testing connectivity with p7 heart..."
    if p7 heart 2>&1 | grep -q "beating"; then
        echo "     ✓ Heartbeat OK - System ready for testing"
    else
        echo "     ✗ Warning: No heartbeat detected"
    fi
    echo ""

    echo "[4/7] System ready for testing"
fi
echo ""
echo "=== Setup Complete ==="
echo ""
echo "System is now ready for link-upgrade testing."
echo "Run: ./bin/test-link-upgrade-workflow.sh"
echo ""

#,,..,.,,,,,.,..,,,,,,,,,,,.,,..,,,,.,,,.,...,..,,...,...,,.,,..,,...,.,.,,,,,
#I6RARKVVGGXAV4623SO2UELIC4ERINYM63EU7FKFGLEE7ABQM2LBNVCKU2NER53EP2X65QK4N2P2M
#\\\|VEBVAZ54T726FWXO2WBRERFB6WJ7S5PP2VEC2CVTNU2LO2QSD4J \ / AMOS7 \ YOURUM ::
#\[7]J45BTLAED5WTWUPZETY37VKMFASF4TYUD4N2LZIBUHLUYH5ATMAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
