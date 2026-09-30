# v7-zenki : heartbeat reply 'offline' while a zenka is just ending

## problem [ 2026-09-30, mod-test ]

a zenka that ends itself [ exit after idle, a crash ] : its session is gone
at cube before v7-zenki has processed the end [ stdout \ stderr eof,
SIGCHLD, SIGPIPE ]. a heartbeat sent in that window gets cube's 'offline'
reply [ `offline : '<sid>' : 'heart'` ] -> v7-zenki counts a heartbeat
error -> status error -> restart, although the zenka is simply ending.
seen : `.:. mo.,.st :. . . . terminated . . . .` one line before
`heartbeat response ( error ) [..retrying..]`.

## direction [ decide after reading the code ]

when the heartbeat reply says the target session is offline, check the
instance's process first [ `v7-zenki.sub-process.pid_alive` \ its pipes ] :
- process gone or ending [ eof seen ] -> let the normal end path handle it
  [ no error status from the heartbeat ]
- process alive but no session -> a real problem, error path as today
bounded : at most one short re-check [ e.g. 1s ], no loop.

## read first

`v7-zenki.handler.heartbeat_timer_response`, `..heartbeat_response_timeout`,
`v7-zenki.process_zenka_end`, `v7-zenki.handler.children_left`, the stdout
\ stderr eof handling of zenka pipes, and
data/ai-mem/claude/feedback-llm-fix-regressions-pattern.md [ the pressure
extension in heartbeat_response_timeout from 6eabe182c must keep working ].

#,,..,.,,,,..,...,...,,..,,,,,...,,,.,.,.,,..,..,,...,...,,..,,,,,,,.,,.,,.,.,
#A4757L5SB66QLRYL5EPQN2ABMLXB7NMUM2LB2THBARHYX6PUADBD7G5XTQGAJCRQOT2GC4OAHKJYY
#\\\|VAZLKMDVINZ7MMGFC4Y5G623EIZIHYQN4XABV4WXQZXHXLILXFK \ / AMOS7 \ YOURUM ::
#\[7]KSJYYYBVQISWWG6HKJFZY2HBJKGLTCNILCFLSXRIN7GACSULBYDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
