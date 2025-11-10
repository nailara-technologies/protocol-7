#!/bin/bash

# Test script for ACME mock server
# This verifies the mock server is running and responding correctly

BASE_URL="http://localhost:8555"
LOG_FILE="/tmp/acme-mock-server.log"

echo "ACME Mock Server Test Suite"
echo "============================"
echo ""

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

#,,,,,..,,..,,,.,,,,.,.,.,..,,.,,,..,,.,,,..,,..,,...,..,,...,,,,,...,.,,,,,,,
#7NVGAGPMUM5YERWTIVD75WJL6AUFQFAVBYUWQACUTWNNAV27QOFRKZDQ7BGFHX6U4NSPTPO24VDCC
#\\\|YUBCYQ2FSGD4V63JCSAIPAE27ILNTKSUQBX4BTASVTA5RWKDQDF \ / AMOS7 \ YOURUM ::
#\[7]UTIH5JLN3D6UV7MNTZXEBBHGVWQZ4ADR4NZMAGKYG6ZJ4ITHEMBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
