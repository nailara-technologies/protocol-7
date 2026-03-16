#!/bin/bash
# Quick link-upgrade test (assumes system already running and initialized)

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


echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Quick Link-Upgrade Test (Fast Iteration)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if system is running
echo "[1/4] Verifying system connectivity..."
if ! p7 whoami 2>&1 | grep -q "@"; then
    echo "✗ System not responding. Run setup first:"
    echo "  ./bin/test-link-upgrade-setup.sh"
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

#,,..,,.,,,,,,.,,,,..,,.,,,.,,,,,,,,,,,.,,..,,..,,...,...,.,,,,,,,.,,,,,,,...,
#UZNNBFEFQTYNCHVIMBK37T733D5NJDEEGIGLJND5K2XH3Y7APQYOZVOURHBKIQ5J2A3GMKMV4EFGO
#\\\|HSAUPXG55S65YRWDPNJOPYLFNOTJNGG4UOJCTGHP6SGDDT45JLW \ / AMOS7 \ YOURUM ::
#\[7]R2E5EXM2RRVGRKD4XWHLHZ777WNXEPAEJYH3PT6MATTK7IX3ZMCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
