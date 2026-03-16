#!/bin/bash


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


# Test 1: Directory endpoint
echo "Test 1: GET /directory"
curl -s "$BASE_URL/directory" | python3 -m json.tool
echo ""

# Test 2: Get nonce
echo "Test 2: GET /nonce"
curl -s "$BASE_URL/nonce" | python3 -m json.tool
echo ""

# Test 3: Check log file
echo "Test 3: Recent log entries"
if [ -f "$LOG_FILE" ]; then
    echo "Log file: $LOG_FILE"
    tail -20 "$LOG_FILE"
else
    echo "Log file not found: $LOG_FILE"
fi
echo ""

echo "Tests complete!"
echo "To start the server, run: ./bin/dev/acme-mock-server.pl"
echo "To view full logs: tail -f $LOG_FILE"

#,,..,..,,.,,,.,,,,,,,,,.,,,.,..,,,,.,...,.,,,..,,...,...,.,.,.,.,...,,..,.,,,
#K45RROECLVOXZCTBW4NB7TRKV4U622IXQRYCCCJZDEC7HA6PPTMI6LZIFWYVGA623XLXS4FVFFAU2
#\\\|KGA7KUSHPKAM2OJZXSGD6WPY7H724F63EFWS2BPEZIT2PBYOFAN \ / AMOS7 \ YOURUM ::
#\[7]EAJRPDHAYXY7BMMV54Y6RW7YZB4VMYRLEO6B4F5WRPJCY63PKABI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
