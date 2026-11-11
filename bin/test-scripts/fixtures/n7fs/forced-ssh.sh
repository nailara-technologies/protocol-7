#!/bin/sh
## stands in for ssh to a host whose authorized_keys forces n7fs-receive :
## the requested command arrives as SSH_ORIGINAL_COMMAND, as sshd sets it
set -eu
while [ "$1" = "-o" ]; do shift 2; done
shift
SSH_ORIGINAL_COMMAND=$*
export SSH_ORIGINAL_COMMAND
exec "$FORCED_PERL" "$FORCED_RECEIVE" "$FORCED_DIR" ${FORCED_ARGS:-}

#,,..,.,,,,,.,..,,,..,..,,,..,,..,.,.,,.,,.,,,..,,...,...,..,,..,,,..,,,.,,.,,
#XEJVUYT2UP64ACRAYSJLTJFKH5EYRFYFNTRWQVUWN72IUEAR7M7ULM63MDPBKVWBWIVXI7WBURTK4
#\\\|ZE62J5G2KLXNPEN6LZ7LDBHCDQ7LKZCUSZF2KDDKH5B6UT66FVY \ / AMOS7 \ YOURUM ::
#\[7]Y76MEKGVGILIELQIMFKJVFNV5L6DL6NKAFUEQ2DUKZOXE6X6BMBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
