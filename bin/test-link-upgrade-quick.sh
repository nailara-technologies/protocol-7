#!/bin/bash
# Quick link-upgrade test (assumes system already running and initialized)
# Useful for rapid iteration after code changes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
P7_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ ! -f "$P7_ROOT/bin/nshell" ]; then
    echo "Error: Could not find Protocol-7 root directory"
    exit 1
fi

cd "$P7_ROOT"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Quick Link-Upgrade Test (Fast Iteration)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if system is running
echo "[1/4] Verifying system connectivity..."
if ! p7 whoami 2>&1 | grep -q "@"; then
    echo "✗ System not responding. Run setup first:"
    echo "  ./bin/test-link-upgrade-setup.sh"
    exit 1
fi
echo "✓ System is responsive"
echo ""

# Reload code to pick up latest changes
echo "[2/4] Reloading code modules..."
p7 reload 2>&1 | grep -E "success|complete" || true
sleep 2
echo "✓ Code reloaded"
echo ""

# Run diagnostic
echo "[3/4] Running diagnostic..."
./bin/test-link-upgrade-diagnostic.sh 2>&1 | tail -50
echo ""

# Quick analysis
echo "[4/4] Quick Analysis..."
echo "---"
echo "Server-side events:"
p7 cube.show-buffer zenka 2>&1 | grep -E "link-upgrade|state.*2|state.*3" | tail -10 || echo "(No events logged)"
echo ""
echo "Client output:"
tail -20 /tmp/link-upgrade-diag.log 2>/dev/null | grep "\[link-upgrade\]" || echo "(No client output)"
echo "---"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Quick Test Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "For full analysis:"
echo "  cat /tmp/link-upgrade-diag.log | grep '\[link-upgrade\]'"
echo "  p7 cube.show-buffer zenka | grep -E 'link-upgrade|error' | tail -30"
echo ""

#,,.,,...,,,.,,.,,...,..,,.,.,...,,..,...,,..,..,,...,...,.,.,,,,,..,,..,,.,,,
#23DB2GUDJVMJJ7O3R245PAWTYLAOZ7TOG5CSYHRJCV2FJ4UGRLUI4LJXWJR3FKRV3FPUPVTQJ5PFK
#\\\|GBIHCOZXQTSZQN7LBXHBI4SXNSHFCLY54AGP5ZI3TNUE74AMQPM \ / AMOS7 \ YOURUM ::
#\[7]JQU7S4XCBQQCAH34UTEQOSIXXU5XRCVNBWS4GGTDDTHTLJCWLAAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
