#!/bin/bash
# Complete link-upgrade testing workflow
# Orchestrates setup, connectivity checks, and diagnostics in sequence

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
P7_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ ! -f "$P7_ROOT/bin/nshell" ]; then
    echo "Error: Could not find Protocol-7 root directory"
    exit 1
fi

cd "$P7_ROOT"

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
    exit 1
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
    exit 1
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

#,,,,,,,,,..,,.,.,,,,,,,.,,,.,...,,.,,,..,...,..,,...,...,.,,,...,,,,,...,,,,,
#6ITLUPKOAVWRSDNXVXMLWZS2FOWEJDK34Y7KY76HY3GXXSHRH6HENIDBUUFEY4TLTS6OW22RKZGTM
#\\\|5OPPX2DVVPXMG47E2664Z5SZBUH3MHTMZ6X5RLA7K6FXBBCIBCX \ / AMOS7 \ YOURUM ::
#\[7]PNQYBCHP7NQ66VKQELSA5QS5PRP5BRZLKNHF23HECDUGXYZZVIDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
