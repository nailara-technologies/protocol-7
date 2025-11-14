#!/bin/bash
# Protocol-7 Session Bootstrap - Quick startup context loader
# Purpose: Rapid session initialization with critical context verification

# Session Status
export SESSION_ID="01BE71ncAMyR7NYKASUBH3Kh"
export SESSION_STATUS_FILE="/home/user/protocol-7/docs/SESSION_STATUS_2025-11-14_template-auth-completion.md"
export LAST_SESSION_DATE="2025-11-14"

# Protocol-7 Paths
export PROTOCOL_7_ROOT="/home/user/protocol-7"
export WORKSPACE_TRANSFER_ROOT="/home/user/workspace-transfer"
export PROTOCOL_7_SOCKET_PATH="/var/run/.7/UNIX/NIW7OAQ"
export PROTOCOL_7_P7_CLIENT="${PROTOCOL_7_ROOT}/bin/p7"

# Critical Status
export CUBE_ZENKA_PID=""
export AUTH_TEST_USERS=("unix-root" "unix-kitten" "unix-taeki")

# Quick verification function
verify_session_state() {
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║           Protocol-7 Session State Verification                 ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    # Check cube zenka socket
    if [ -S "$PROTOCOL_7_SOCKET_PATH" ]; then
        echo "✅ Cube zenka socket exists: $PROTOCOL_7_SOCKET_PATH"
    else
        echo "❌ Cube zenka socket missing - needs restart"
        echo "   Run: cd $PROTOCOL_7_ROOT && ./bin/Protocol-7 cube -BK -v"
    fi

    # Check p7 client
    if [ -x "$PROTOCOL_7_P7_CLIENT" ]; then
        echo "✅ p7 client available: $PROTOCOL_7_P7_CLIENT"
    else
        echo "⚠️  p7 client needs recompilation"
        echo "   Run: cd $PROTOCOL_7_ROOT/bin/c_src && gcc -o ../p7 p7.c"
    fi

    # Check critical documentation
    if [ -f "$SESSION_STATUS_FILE" ]; then
        echo "✅ Session status doc available"
    else
        echo "❌ Session status doc missing"
    fi

    echo ""
}

# Quick test function
test_authentication() {
    if [ ! -S "$PROTOCOL_7_SOCKET_PATH" ]; then
        echo "❌ Socket not available - cannot test"
        return 1
    fi

    echo "Testing authentication..."
    cd "$PROTOCOL_7_ROOT"
    export PROTOCOL_7_UNIX_PATH="$PROTOCOL_7_SOCKET_PATH"

    for user in "${AUTH_TEST_USERS[@]}"; do
        result=$(USER="$user" ./bin/p7 whoami 2>&1)
        if echo "$result" | grep -q "unix-"; then
            echo "  ✅ $user: $result"
        else
            echo "  ❌ $user: Failed"
        fi
    done
}

# Print helpful context
print_context() {
    cat << 'EOF'

╔════════════════════════════════════════════════════════════════╗
║                  Session Context Summary                       ║
╚════════════════════════════════════════════════════════════════╝

COMPLETED WORK (Nov 14, 2025):
• Template-based user authentication system fully implemented
• Parser fixes in base.parser.config (removed escaped angle brackets)
• p7 client compiled and tested
• All three auth users verified: unix-root, unix-kitten, unix-taeki

CURRENT STATE:
• Cube zenka: Running in background (socket at /var/run/.7/UNIX/NIW7OAQ)
• p7 client: Compiled and ready
• Authentication: All tests passing
• Documentation: Updated with complete test results and continuity info

QUICK COMMANDS:
• Source this file: source ~/.session-bootstrap.sh
• Verify state: verify_session_state
• Test auth: test_authentication
• View session doc: cat $SESSION_STATUS_FILE
• Restart cube: cd $PROTOCOL_7_ROOT && ./bin/Protocol-7 cube -BK -v

KEY FILES TO READ FIRST:
1. /home/user/protocol-7/docs/SESSION_STATUS_2025-11-14_template-auth-completion.md
2. /home/user/protocol-7/data/asc/TEMPLATE-USER-CONFIGURATION.md
3. /home/user/workspace-transfer/STATUS.md

TESTING CHECKLIST:
□ Verify cube zenka running (check socket)
□ Run p7 whoami tests
□ Check documentation for any updates
□ Review parser fixes in base.parser.config
□ Verify git status on both repos

EOF
}

# Run verification on source
if [ "$1" == "--verify" ]; then
    verify_session_state
elif [ "$1" == "--test" ]; then
    test_authentication
elif [ "$1" == "--info" ]; then
    print_context
else
    print_context
fi
