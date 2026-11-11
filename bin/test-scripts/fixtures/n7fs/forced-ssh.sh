#!/bin/sh
## stands in for ssh to a host whose authorized_keys forces n7fs-receive :
## the requested command arrives as SSH_ORIGINAL_COMMAND, as sshd sets it
set -eu
while [ "$1" = "-o" ]; do shift 2; done
shift
SSH_ORIGINAL_COMMAND=$*
export SSH_ORIGINAL_COMMAND
## the first put loses its connection after a few bytes [ ssh exit 255 ] ##
if [ -n "${FORCED_DROP_ONCE:-}" ] && [ ! -e "$FORCED_DROP_ONCE" ]; then
    case $SSH_ORIGINAL_COMMAND in
        put\ *)
            : > "$FORCED_DROP_ONCE"
            head -c 100 > /dev/null
            exit 255
            ;;
    esac
fi
exec "$FORCED_PERL" "$FORCED_RECEIVE" "$FORCED_DIR" ${FORCED_ARGS:-}

#,,..,,..,,.,,,.,,,.,,.,,,.,,,.,,,,,,,,,.,,..,..,,...,...,.,.,,..,.,,,...,..,,
#HMCUKR7WJNJYMNEPNE5JPTPYSFENKRAB5GZDA46XYNOZPFI2NRLSVTL7JN6D5TO7KFCO4L5YEBH6I
#\\\|3LZEDR7D6N6LVJ4H4RH5M65Z3EEONRRDJGJ5OTVDOVUCQGCOS5Z \ / AMOS7 \ YOURUM ::
#\[7]NIYIY2BYZSLYGQG2ACDAP22NYUGKU6HB7ZRKPQPIZUDN56QRJEDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
