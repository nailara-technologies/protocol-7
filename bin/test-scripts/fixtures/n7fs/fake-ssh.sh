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

#,,..,.,.,..,,,..,.,.,,,.,...,,,.,...,...,,,,,..,,...,...,,.,,...,,,,,,.,,..,,
#2RYJSY56EQEEQKXXHVFGUIXEK2HRZ4FQRY32HIYDUOHA5YG7RNQC5IZZTSYRLOXVB6FEQXT4VDQAO
#\\\|HUSZVSI67RMFM4ZSOIH3MC4OUC6CRP2VLUGPCN5PAVMLT6FF35P \ / AMOS7 \ YOURUM ::
#\[7]URBGEKY6P7KIQXU3YNT3ZJ36JUFUIJL6AA7DTXDLV3MKF67ZLYBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
