#!/bin/bash
# Quick connectivity test using p7 heart

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


echo "=== Protocol-7 Connectivity Test ==="
echo ""

echo "[1/3] Testing cube connectivity..."
echo "---"
p7 whoami 2>&1 | head -3 || echo "ERROR: Could not connect to cube"
echo "---"
echo ""

echo "[2/3] Testing latency with p7 heart..."
echo "     (Expecting 'beating' reply on working connection)"
echo "---"
p7 heart 2>&1 || echo "ERROR: Heart command failed"
echo "---"
if p7 heart 2>&1 | grep -q "beating"; then
    echo "✓ Connection is HEALTHY"
else
    echo "✗ Connection test FAILED - no heartbeat"
fi
echo ""

echo "[3/3] Listing active zenki..."
echo "---"
p7 v7-zenki.list zenki 2>&1 | head -10 || echo "ERROR: Could not list zenki"
echo "---"
echo ""

echo "=== Connectivity Test Complete ==="
echo ""
echo "If all tests show successful responses, system is ready for link-upgrade testing."
echo ""

#,,,,,..,,,..,,,.,,..,.,,,..,,,.,,...,,,,,,..,..,,...,...,,,,,,.,,.,,,..,,,,.,
#SVDMRTJUISSO6THD5V3Q6HE6BXJQEJDPEH3QLKZKXTN4NYPK4MW3MW6WAEVMGMLCJY3UFHGYCBSPG
#\\\|3M7UYWVLJ5BFN43WIQ6HRYELLVZ6KPU5BUZXUSZAAAHJUE46JTX \ / AMOS7 \ YOURUM ::
#\[7]JIGUFUPKOTHWZH3LGRGVHWPNONW26T7NSWO5P6IOKODIOY6MGCDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
