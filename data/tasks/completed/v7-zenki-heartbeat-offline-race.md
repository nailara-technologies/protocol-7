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
extension in heartbeat_response_timeout from 776d3f8bf must keep working ].


## done [ 2026-09-30, kimi ]

### root cause

two independent teardown paths run in two processes when a zenka ends, and
the heartbeat path in v7-zenki never checks which one already ran :

1. zenka process exits [ idle exit, crash, deliberate TERM for restart ].
   the kernel closes its cube socket immediately ; the process stays a
   zombie until v7-zenki reaps it.
2. cube processes the socket EOF first [ independent process ] and deletes
   the session.
3. v7-zenki still has SIGCHLD + stdout/stderr EOF queued : instance still
   'online', heartbeat timers active. the end path [ sig_chld ->
   process_zenka_end -> stop_heartbeat_timer, status change ] has not run.
4. src/v7-zenki.handler.heartbeat_timer:57 sends '<sid>[.<cube_sid>].heart'
   in exactly this window [ or one is already in flight ].
5. src/base.handler.command.route_to_target:75-98 finds no session ->
   logs "offline : '<sid>' : 'heart'" [ HMNXQRY, l.197-199 ] and replies
   'FALSE client not present' [ IRW7V6A, l.194 +
   src/protocol.protocol-7.message-templates:34 ].
6. src/base.handler.command.process_reply:59-66 dispatches the reply to
   v7-zenki.handler.heartbeat_timer_response with cmd='FALSE',
   call_args.args='client not present'.
7. the handler treated ANY non-TRUE-beating reply identically : error++,
   2s retry, second FALSE -> zenka.change_status 'error' -> restart,
   although the zenka simply ended [ or was already being restarted ].

real occurrences :
- v7-zenki log 3XLOLE43DSV7C5A : X-11 during deliberate restart :
  'restart --> error' from an in-flight heartbeat FALSE.
- cube log 3XUMTAO3GOW34MA + 8 more [ 2026-09-30 04:10:08, resolved via
  p7c localtime ] : "offline : 'mod-test' : 'heart'" bursts while mod-test
  sessions churned.
variant : zenka exits after the heartbeat was sent but before replying ->
heartbeat_response_timeout retry sends a new heartbeat -> lands in step 5.

### fix [ working tree only ]

src/v7-zenki.handler.heartbeat_timer_response only [ new branch l.21-93,
error counting moved after it to l.95-96 ] : on a FALSE
'client not present' reply, before any error counting :
- status ne 'online' -> dropped, the end/restart path owns the instance
- process is a zombie [ /proc/<pid>/stat state X/Z/x, pid_alive-gated ] ->
  dropped, sig_chld -> process_zenka_end is guaranteed to follow
- otherwise one 1s re-check via event.add_timer cb re-entering the same
  handler with the checked pid stored in the reply params [ no loop ] :
  status changed or process now ending -> dropped ; pid changed [ instance
  restarted within the 1s ] -> dropped ; same pid still online with no
  session -> real problem, falls through to the unchanged error path.
no base.* module touched. heartbeat_response_timeout untouched -> the
pressure extension from 776d3f8bf keeps working. pid_alive untouched
[ its get_children caller relies on '-d /proc' semantics ; the zombie
check is local to the handler instead ].

### callers checked

- v7-zenki.handler.heartbeat_timer:60 -- only registration as reply
  handler ; relies on error reset on TRUE 'beating' replies, stats, retry
  escalation. behavior for all non-offline replies unchanged.
- base.handler.command.process_reply:59-66 -- invokes it for
  TRUE/FALSE/WAIT/GET/TERM route replies ; route cleanup is done by the
  dispatcher itself, unaffected.
- self re-entry via the one-shot re-check cb [ instance-gone case handled
  by the existing guard at l.7-12 ].
- v7-zenki.sub-process.pid_alive callers : only get_children:38 -- not
  changed.

### how to test live

needs a v7-zenki reload [ code change ] -- left to the user. then :
1. start mod-test, let it idle-exit [ or p7c v7-zenki.restart mod-test ] :
   expect level-2 'session gone, zenka ending .. left to the end path' and
   NO 'heartbeat response ( error )', no error status.
2. watch the cube log for "offline : .. : 'heart'" followed by v7-zenki
   NOT counting a heartbeat error.
3. real-problem path [ process alive, session gone ] : expected shape is
   the level-2 're-checking once in 1s' line followed by the normal error
   path ~1s later.

verified : bin/format-code -c src/v7-zenki.handler.heartbeat_timer_response
[ syntax valid, reflow applied ]. NOT verified live : no zenka was
reloaded or restarted [ task rules ], so the fix has not run in production
yet ; the 'process changed during re-check' guard branch exists by
construction only.

#,,,,,,,,,,..,,,,,,..,,..,,.,,,,,,..,,.,.,,,,,...,...,..,,,..,,.,,,,.,...,...,
#PP6IV25HD3MKGTSLBWT3RISLSTU7KCD425CP7JC7T5RR6XNICW7OJWSA6SARF4O7WKGAX7DD6GKSO
#\\\|WM7LUWJ3LZYKG2MRIWYHGWSO4HLECZMBAKHB6S7LRTJUQWNZ6Y2 \ / AMOS7 \ YOURUM ::
#\[7]JOI5XFIBN5BME5PHQ2QE5FCCH3XPD5L7WORSSB5JE2ILPLOILUAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
