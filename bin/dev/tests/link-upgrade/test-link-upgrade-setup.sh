#!/bin/bash
# Link-upgrade test setup: Initialize v7 zenka and cube

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


echo "=== Link-Upgrade Test Setup ==="
echo ""

# Step 0: Check if system already running
echo "[0/7] Checking if system is already running..."
if p7 whoami 2>&1 | grep -q "@"; then
    echo "     System already running! Proceeding to reload..."
    SYSTEM_RUNNING=1
else
    echo "     No system running, will start v7"
    SYSTEM_RUNNING=0
fi
echo ""

if [ $SYSTEM_RUNNING -eq 0 ]; then
    # Step 1: Kill old processes (only if not running)
    echo "[1/7] Killing old v7 and cube processes..."
    pkill -f "runsc\.v7" 2>/dev/null || true
    pkill -f "runsc\.cube" 2>/dev/null || true
    sleep 2
    echo "     Old processes cleaned up"
    echo ""

    # Step 2: Start v7 in background
    echo "[2/7] Starting v7 zenka in background..."
    ./bin/Protocol-7 v7 -B 2>&1 | grep -E "protocol-7|backgrounding" || true
    echo "     V7 started"
    echo ""

    # Step 3: Wait for initialization
    echo "[3/7] Waiting 7 seconds for v7 and cube to initialize..."
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
    p7 v7.list zenki 2>&1 | head -15 || echo "     (Could not list zenki)"
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

#,,,.,,.,,..,,.,,,,.,,,.,,,..,.,.,,,.,.,.,..,,..,,...,...,,,,,...,,,,,.,,,.,.,
#KSZ2LZIUANQHMEHGECBYOT2QSZ6MYO6X6C57XWRLBKLR2QSZGU5OJHXKGXR5MA3XWVS67BULEZMN6
#\\\|J53DT6TKILJFLZDTWHKQCR4N6CY2RJB35QKSFXEPVKPWQHSZ77K \ / AMOS7 \ YOURUM ::
#\[7]BHGM527LGKADC3Y25YPNX57DNMSZRLYEW3XP7YZGC7F5GVCOEGCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
