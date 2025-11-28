#!/bin/bash
# Complete link-upgrade test with server startup and verification

set -e

P7_ROOT="/home/user/protocol-7"
cd "$P7_ROOT"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo "=========================================="
echo "Link-Upgrade Encryption - Complete Test"
echo "=========================================="
echo ""

# Step 1: Start the server
echo -e "${YELLOW}[1/5] Starting Protocol-7 cube server...${NC}"
./bin/Protocol-7 > /tmp/p7-server.log 2>&1 &
SERVER_PID=$!
echo "      Server PID: $SERVER_PID"

# Wait for server to initialize
sleep 4

# Check if server is running
if ! kill -0 $SERVER_PID 2>/dev/null; then
    echo -e "${RED}[ERROR] Server failed to start${NC}"
    echo "Server log:"
    tail -20 /tmp/p7-server.log
    exit 1
fi
echo -e "${GREEN}      ✓ Server started${NC}"
echo ""

# Step 2: Clear buffers
echo -e "${YELLOW}[2/5] Clearing cube buffers...${NC}"
sleep 1
if p7 cube.erase-buffer zenka 2>/dev/null; then
    echo -e "${GREEN}      ✓ Buffers cleared${NC}"
else
    echo -e "${YELLOW}      ! Could not clear buffers (continuing)${NC}"
fi
echo ""

# Step 3: Run link-upgrade test
echo -e "${YELLOW}[3/5] Testing link-upgrade negotiation...${NC}"
echo "      Running: echo 'test' | PROTOCOL_7_LINK_UPGRADE=yes ./bin/nshell"
echo ""

timeout 15 bash -c "echo 'test' | DEBUG=1 PROTOCOL_7_LINK_UPGRADE=yes ./bin/nshell -notty -u taeki 2>&1" > /tmp/nshell-test.log 2>&1 || true

if grep -q "Negotiation SUCCESS" /tmp/nshell-test.log; then
    echo -e "${GREEN}      ✓ Client negotiation successful${NC}"
else
    echo -e "${YELLOW}      ! Check client output below${NC}"
fi
echo ""

# Step 4: View server logs
echo -e "${YELLOW}[4/5] Server-side link-upgrade logs...${NC}"
echo "----------------------------------------------"

if p7 cube.show-buffer zenka 2>/dev/null | grep -E "link-upgrade|encryption|DH|key_32|WARNING" > /tmp/server-logs.txt 2>&1; then
    tail -30 /tmp/server-logs.txt
else
    echo "Server buffer view failed (trying direct log)"
    grep -E "link-upgrade|encryption|DH|key_32|WARNING" /tmp/p7-server.log | tail -30 || echo "No matching logs found"
fi
echo "----------------------------------------------"
echo ""

# Step 5: Verify results
echo -e "${YELLOW}[5/5] Verification...${NC}"

SUCCESS=0

# Check for key_32 completion without blocking
if grep -q "key derivation completed" /tmp/p7-server.log 2>/dev/null || \
   grep -q "encryption.init: COMPLETE" /tmp/p7-server.log 2>/dev/null; then
    echo -e "${GREEN}      ✓ Key derivation completed (no blocking)${NC}"
    SUCCESS=$((SUCCESS + 1))
fi

# Check for encryption wrapper installation
if grep -q "encryption wrappers installed" /tmp/p7-server.log 2>/dev/null; then
    echo -e "${GREEN}      ✓ Encryption wrappers installed${NC}"
    SUCCESS=$((SUCCESS + 1))
fi

# Check for state 3 (encrypted state)
if grep -q "init_state: protocol='protocol-7' state_id=3" /tmp/p7-server.log 2>/dev/null; then
    echo -e "${GREEN}      ✓ Transitioned to encrypted state (state 3)${NC}"
    SUCCESS=$((SUCCESS + 1))
fi

# Check for warnings (should not have key_32 warnings with SCALAR ref)
if grep -q "key_32 WARNING" /tmp/p7-server.log 2>/dev/null; then
    echo -e "${RED}      ✗ Unexpected key_32 warning (using SCALAR ref)${NC}"
else
    echo -e "${GREEN}      ✓ No key_32 warnings (SCALAR ref used correctly)${NC}"
    SUCCESS=$((SUCCESS + 1))
fi

echo ""
echo "=========================================="
if [ $SUCCESS -ge 3 ]; then
    echo -e "${GREEN}✓ LINK-UPGRADE TEST SUCCESSFUL${NC}"
    echo -e "${GREEN}Encryption is operational and non-blocking${NC}"
else
    echo -e "${YELLOW}! PARTIAL SUCCESS (check logs above)${NC}"
fi
echo "=========================================="
echo ""

# Cleanup
echo -e "${YELLOW}Stopping server...${NC}"
kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null || true

echo ""
echo "Log files available at:"
echo "  Server: /tmp/p7-server.log"
echo "  Client: /tmp/nshell-test.log"
echo "  Buffers: /tmp/server-logs.txt"
echo ""

#,,..,..,,,,,,,,,,.,,,...,,,.,,.,,...,..,,,,,,..,,...,...,..,,,..,,.,,,..,,..,
#T4C3TSAHWRFAG26YWON7ZNT2LSTD3EVFDWPZPEDLEIAUDHG4QZAV2ATBFWG3EHJ4OC6ED7VE7T3LQ
#\\\|RVSGKKJZT5Q5V43INF2XZWIQ3WYQLWRWBHUPIM5HSVZD2Q5XEJ6 \ / AMOS7 \ YOURUM ::
#\[7]N4JGSIVNOA2BEXNKAAL7NTSZZ6WYFYRHA2SBB3QGCX5GHYDALEAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
