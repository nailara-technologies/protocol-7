#!/bin/bash
# Quick session state verification for Protocol-7
# Purpose: Rapid system health check and status reporting

PROTOCOL_7_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOCKET_PATH="/var/run/.7/UNIX/NIW7OAQ"
P7_CLIENT="$PROTOCOL_7_ROOT/bin/p7"
SESSION_DOC="$PROTOCOL_7_ROOT/docs/SESSION_STATUS_2025-11-14_template-auth-completion.md"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         Protocol-7 Session State Verification              ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo -e "${BLUE}━━━ $1 ━━━${NC}"
}

check_socket() {
    print_section "Cube Zenka Socket"

    if [ -S "$SOCKET_PATH" ]; then
        echo -e "${GREEN}✅ Socket exists${NC}"
        ls -lh "$SOCKET_PATH" | awk '{print "   " $0}'
        return 0
    else
        echo -e "${RED}❌ Socket missing${NC}"
        echo "   Expected: $SOCKET_PATH"
        echo "   Action: Restart cube zenka"
        return 1
    fi
}

check_p7_client() {
    print_section "p7 Client Binary"

    if [ -x "$P7_CLIENT" ]; then
        echo -e "${GREEN}✅ p7 client ready${NC}"
        echo "   Path: $P7_CLIENT"
        file "$P7_CLIENT" | sed 's/^/   /'
        return 0
    else
        echo -e "${RED}❌ p7 client missing or not executable${NC}"
        echo "   Expected: $P7_CLIENT"
        echo "   Action: Recompile with: cd $PROTOCOL_7_ROOT/bin/c_src && gcc -o ../p7 p7.c"
        return 1
    fi
}

check_documentation() {
    print_section "Documentation"

    if [ -f "$SESSION_DOC" ]; then
        echo -e "${GREEN}✅ Session documentation available${NC}"
        echo "   Path: $SESSION_DOC"
        lines=$(wc -l < "$SESSION_DOC")
        echo "   Content: $lines lines"
        return 0
    else
        echo -e "${RED}❌ Session documentation missing${NC}"
        echo "   Expected: $SESSION_DOC"
        return 1
    fi
}

check_git_status() {
    print_section "Git Status"

    cd "$PROTOCOL_7_ROOT" || return 1

    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    commits_ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null)

    if [ -z "$branch" ]; then
        echo -e "${YELLOW}⚠️  Not a git repository${NC}"
        return 1
    fi

    echo -e "${GREEN}✅ Git repository healthy${NC}"
    echo "   Branch: $branch"

    if [ -z "$commits_ahead" ] || [ "$commits_ahead" -eq 0 ]; then
        echo -e "   Status: ${GREEN}Up to date${NC}"
    else
        echo -e "   Status: ${YELLOW}$commits_ahead commits ahead${NC}"
    fi

    return 0
}

test_authentication() {
    print_section "Authentication Test"

    if [ ! -S "$SOCKET_PATH" ]; then
        echo -e "${YELLOW}⚠️  Socket not available - skipping tests${NC}"
        return 1
    fi

    if [ ! -x "$P7_CLIENT" ]; then
        echo -e "${YELLOW}⚠️  p7 client not available - skipping tests${NC}"
        return 1
    fi

    export PROTOCOL_7_UNIX_PATH="$SOCKET_PATH"
    cd "$PROTOCOL_7_ROOT" || return 1

    # Test default user
    result=$(./bin/p7 whoami 2>&1)
    if echo "$result" | grep -q "unix-root"; then
        echo -e "${GREEN}✅ Default user (unix-root)${NC}"
        echo "   Result: $result" | sed 's/^/   /'
    else
        echo -e "${RED}❌ Default user test failed${NC}"
        echo "   Result: $result" | sed 's/^/   /'
    fi

    # Test kitten user
    result=$(USER=kitten ./bin/p7 whoami 2>&1)
    if echo "$result" | grep -q "unix-kitten"; then
        echo -e "${GREEN}✅ Kitten user (unix-kitten)${NC}"
        echo "   Result: $result" | sed 's/^/   /'
    else
        echo -e "${RED}❌ Kitten user test failed${NC}"
        echo "   Result: $result" | sed 's/^/   /'
    fi

    # Test taeki user (template-based)
    result=$(USER=taeki ./bin/p7 whoami 2>&1)
    if echo "$result" | grep -q "unix-taeki"; then
        echo -e "${GREEN}✅ Taeki user (unix-taeki)${NC}"
        echo "   Result: $result" | sed 's/^/   /'
    else
        echo -e "${RED}❌ Taeki user test failed${NC}"
        echo "   Result: $result" | sed 's/^/   /'
    fi
}

print_summary() {
    echo ""
    print_section "Summary & Next Steps"

    # Count checks
    if check_socket > /dev/null 2>&1 && \
       check_p7_client > /dev/null 2>&1 && \
       check_documentation > /dev/null 2>&1; then
        echo -e "${GREEN}✅ All critical systems ready${NC}"
        echo ""
        echo "Quick commands:"
        echo "  • Test auth: $0 --test"
        echo "  • View session doc: cat $SESSION_DOC"
        echo "  • Start development: cd $PROTOCOL_7_ROOT"
    else
        echo -e "${YELLOW}⚠️  Some systems need attention${NC}"
        echo ""
        echo "Required actions:"

        if ! check_socket > /dev/null 2>&1; then
            echo "  1. Restart cube zenka:"
            echo "     cd $PROTOCOL_7_ROOT && ./bin/Protocol-7 cube -BK -v"
        fi

        if ! check_p7_client > /dev/null 2>&1; then
            echo "  2. Recompile p7 client:"
            echo "     cd $PROTOCOL_7_ROOT/bin/c_src && gcc -o ../p7 p7.c"
        fi
    fi
}

main() {
    print_header

    case "${1:-}" in
        --test)
            test_authentication
            ;;
        --full)
            check_socket
            echo ""
            check_p7_client
            echo ""
            check_documentation
            echo ""
            check_git_status
            echo ""
            test_authentication
            echo ""
            print_summary
            ;;
        *)
            check_socket
            echo ""
            check_p7_client
            echo ""
            check_documentation
            echo ""
            check_git_status
            echo ""
            print_summary
            ;;
    esac
}

main "$@"
