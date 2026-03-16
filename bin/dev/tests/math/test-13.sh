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

#IF3GU76A46JHHWXQQU2DTWQGBNLXSSXRBX5WNHKWAMY3FK2YCF4IBSY77E2RSGPZNICIP2JJT5KB6
#\\\|4FTK4PYFNU7AT7CPAZVAUJMQJOC6M3ZAWQZA4OAB34ZAKACYHQD \ / AMOS7 \ YOURUM ::
#\[7]3RBX4JVP6YB6NHDGRT4ADEKAAJBFQLVDPP24XQMH5VQOTBPE74AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

#,,.,,,,.,,.,,,,.,,.,,..,,.,,,,.,,,.,,.,.,.,,,..,,...,...,..,,,,.,...,,,.,.,.,
#D2NEHEFCBYP7XCAEWC67564T7MLTTMMEHQGA6RT6HB7Z5NBRAEIYVSLMQ6C2CPD37FU757YP7GLE6
#\\\|P3GW5ABEKNKDQEEZFUTD73BA2FXN5UFXFGUTGBFR6G2F65MOBQ7 \ / AMOS7 \ YOURUM ::
#\[7]6VRA2GMBP2FUDMTWVB5ZJI6Y3UQFPJEGLO7OU6LHYED7XJNOAOCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
