#!/bin/sh
set -eu
printf '%s\n' "$*" >> "$FAKE_SSH_LOG"
while [ "$1" = "-o" ]; do shift 2; done
alias=$1
shift
[ "$#" -eq 1 ] || exit 90
cmd=$*
cmd=$(printf '%s' "$cmd" | sed "s|/holder|$FAKE_HOLDER_ROOT|g")
if [ "${FAKE_SSH_WRONG:-0}" = "1" ]; then
    case $cmd in
        *tail\ -c*) printf 'wrong-readback'; exit 0 ;;
    esac
fi
if [ "${FAKE_SSH_STDERR:-0}" = "1" ]; then
    i=0
    while [ "$i" -lt 10000 ]; do printf 'stderr-flood-line\n' >&2; i=$((i+1)); done
fi
if [ "${FAKE_SSH_READ_FAIL:-0}" = "1" ]; then
    case $cmd in
        *'cat -- '*|*'wc -c '*|*'tail -c '*) exit 74 ;;
    esac
fi
## the first download ends short but exits 0 [ a clean short read ] : only
## a cat right after a size query of the same file, as holder_download does
if [ -n "${FAKE_SSH_SHORT_ONCE:-}" ] && [ ! -e "$FAKE_SSH_SHORT_ONCE" ]; then
    case $cmd in
        *'wc -c '*)
            printf '%s' "${cmd##* }" > "$FAKE_SSH_SHORT_ONCE.wc"
            ;;
        *'cat -- '*)
            if [ -e "$FAKE_SSH_SHORT_ONCE.wc" ] &&
                [ "$(cat "$FAKE_SSH_SHORT_ONCE.wc")" = "${cmd##* }" ]; then
                : > "$FAKE_SSH_SHORT_ONCE"
                sh -c "$cmd" | head -c 5
                exit 0
            fi
            ;;
    esac
fi
if [ -n "${FAKE_SSH_DOWNLOAD_DROP:-}" ]; then
    case $cmd in
        *'cat -- '*)
            sh -c "$cmd" | head -c "$FAKE_SSH_DOWNLOAD_DROP"
            exit 75
            ;;
    esac
fi
case $cmd in
    'cat >> '*)
        if [ "${FAKE_SSH_FAIL:-0}" = "1" ]; then
            exit 74
        fi
        if [ "${FAKE_SSH_FAIL_AFTER_DROP:-0}" = "1" ] && [ -e "$FAKE_HOLDER_ROOT/.drop-done" ]; then
            exit 74
        fi
        if [ -n "${FAKE_SSH_DROP:-}" ] && [ ! -e "$FAKE_HOLDER_ROOT/.drop-done" ]; then
            target=${cmd#cat >> }
            : > "$FAKE_HOLDER_ROOT/.drop-done"
            sh -c "dd bs=1 count=$FAKE_SSH_DROP status=none >> $target" || exit 75
            exit 75
        fi
        ;;
esac
exec sh -c "$cmd"

#,,,,,.,.,,.,,...,...,..,,,..,,..,.,,,..,,...,..,,...,...,...,.,,,,..,,.,,.,.,
#YRVO5J7RUJA6KFK62CXGRJBFFZV5WMCC7KRFGRJYFGIHYOV23UUINWALDBYR7SLIKDHJI6TK3L4PY
#\\\|6VLY477CG5K5AS24VMDMAPEBYJ75QP5ASKAQHODDB4FQYQA4HI5 \ / AMOS7 \ YOURUM ::
#\[7]NLJUEPBGX4G2L3QYXKEDJZJZI7OWAYQGQHUTI4NQ2Z3NGVH354CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
