#!/bin/bash
# Complete link-upgrade testing workflow

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


echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     Protocol-7 Link-Upgrade Complete Testing Workflow         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Track test results
SETUP_OK=0
CONNECT_OK=0
DIAG_OK=0

# Step 1: System Setup
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 1: System Setup and Initialization"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if ./bin/test-link-upgrade-setup.sh; then
    SETUP_OK=1
    echo "✓ Setup completed successfully"
else
    echo "✗ Setup failed"
fi

echo ""
sleep 2

# Step 2: Connectivity Check
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 2: Connectivity Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if ./bin/test-connectivity.sh; then
    CONNECT_OK=1
    echo "✓ Connectivity verified"
else
    echo "✗ Connectivity check failed"
    echo "  Cannot proceed with link-upgrade testing"
fi

echo ""
sleep 2

# Step 3: Detailed Diagnostic
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 3: Link-Upgrade Negotiation Diagnostic"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if ./bin/test-link-upgrade-diagnostic.sh; then
    DIAG_OK=1
    echo "✓ Diagnostic completed"
else
    echo "✗ Diagnostic encountered issues"
fi

echo ""
sleep 2

# Step 4: Full Workflow Test
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 4: Full Link-Upgrade Workflow Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

./bin/test-link-upgrade-workflow.sh

echo ""

# Step 5: Results Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "RESULTS SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "System Setup:              $([ $SETUP_OK -eq 1 ] && echo '✓ PASS' || echo '✗ FAIL')"
echo "Connectivity:              $([ $CONNECT_OK -eq 1 ] && echo '✓ PASS' || echo '✗ FAIL')"
echo "Diagnostic:                $([ $DIAG_OK -eq 1 ] && echo '✓ PASS' || echo '✗ FAIL')"
echo ""

# Step 6: Next Actions
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "NEXT STEPS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ $DIAG_OK -eq 1 ]; then
    echo "Check detailed diagnostic output:"
    echo "  cat /tmp/link-upgrade-diag.log"
    echo ""
    echo "Check server logs for state transitions:"
    echo "  p7 cube.show-buffer zenka | grep -E 'link-upgrade|state' | tail -20"
    echo ""
    echo "Check for errors:"
    echo "  p7 cube.show-buffer zenka | grep -iE 'error|failed' | tail -10"
else
    echo "Review setup and connectivity checks above."
    echo "Common issues:"
    echo "  - System not fully initialized (try again in 10 seconds)"
    echo "  - p7 command not in PATH (check Protocol-7 installation)"
    echo "  - Socket/IPC issues (check /var/run/.7/ directory)"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              Testing Workflow Complete                        ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

#,,..,.,,,..,,..,,..,,.,.,,.,,..,,,..,,,,,,,,,..,,...,...,.,,,,..,,,,,..,,..,,
#EX2IM4HPOLEVXKNIWR6S5SPRKUGII3UGF5F4SFLTUPHTNUICOJ4HRET4OXE67SAZUIH6XWRS7TB6U
#\\\|DA7KGL7MNZMFML2YPOTHQXR2UEGOFL5OQBTF4GKOWNNGIDSBBVF \ / AMOS7 \ YOURUM ::
#\[7]JQ7I2IZJKT2E7B77W6LZJVXEOUQIXN4S3LQQTPYIV2OXQ5CWDEDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
