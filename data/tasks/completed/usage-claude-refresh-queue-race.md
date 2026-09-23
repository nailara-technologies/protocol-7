## [:< ##

# name  = task: port kimi's refresh-queue fix to claude's usage path
# descr = usage.status's claude probe races its own in-flight token refresh
# param = single-file fix, `src/plugin.usage.claude.refresh_token`

## symptom

reported live 2026-09-23: `usage.status` fails --

    no rate-limit headers in response [ http status 401 ] -- local token
    was rejected, a refresh was already attempted and did not help

-- and the very next `usage.claude` call, moments later, succeeds
immediately. same shape kimi's usage path used to have.

## root cause, found by diffing the two refresh_token modules

`plugin.usage.kimi.refresh_token` and `plugin.usage.claude.refresh_token`
are otherwise correctly, deliberately different (pty vs pipes, mcp-config
suppression, binary lookup order -- each has its own confirmed-live
rationale in its module notes, none of that is broken). one piece was
never ported: the single-slot-busy branch.

kimi (current, fixed 2026-09-17 per its own module note): a caller
arriving while a refresh is already running queues onto the existing
cycle's `on_done_list` instead of doing anything else. every waiter --
the original caller, a watchdog trigger, any number of reactive 401s
landing mid-refresh -- gets notified exactly once, when the one real
refresh actually completes. returns TRUE ["on_done WILL fire"], not
FALSE.

claude (current): the busy branch just `return FALSE`. its caller,
`plugin.usage.claude.handler.response`, treats FALSE as "nothing will
ever call me back" and fires its own immediate `refresh_retry` --
racing the already-running refresh child. kimi's own module note
describes this exact pattern as a bug it used to have: "almost always
raced the already-running refresh child ... and reported a false
'refresh already attempted and did not help' error moments before the
SAME in-flight refresh would have succeeded on its own." that's the
"second call immediately works" symptom -- by the second call, the
refresh raced the first time has had time to finish on its own.

## the fix

port kimi's `on_done_list` queuing to `plugin.usage.claude.refresh_token`:
- single-slot-busy branch pushes `{ handler, params }` onto
  `<usage.provider.claude>->{'refresh_state'}->{'on_done_list'}` instead
  of returning FALSE, and returns TRUE
- whatever currently fires the single `on_done` handler when a claude
  refresh cycle completes (check `plugin.usage.claude.refresh_cleanup` /
  `refresh_finish`) needs to iterate `on_done_list` the same way kimi's
  equivalent already does
- `plugin.usage.claude.handler.response`'s own `if (not $refresh_started)`
  fallback (lines ~65-71) can likely stay as-is once refresh_token
  correctly returns TRUE for the queued case -- it should only ever be
  reached now for the genuine "refresh could not be attempted at all"
  case, same as kimi's

## verify

reproduce two overlapping claude 401s close together (a proactive
watchdog trigger plus a live probe, or two probes in quick succession
against an already-expired token) and confirm both get the real
refreshed result instead of the second one racing and failing.

#,,,.,.,.,,,,,,..,,..,.,,,,.,,,,,,...,.,.,...,..,,...,..,,,,,,,,,,...,..,,,,,,
#2D7WW5KVWI3C22XYU6RUF3ENRZ7ZZ6HO34KKDJAQLPLV4W4KY74CIFUC4PL63MMBPCJDZKK6KQ56C
#\\\|H5NZA7F53Y4AE6SID3UENBERQ7RQPVOXI2E6YXDX5LCTCIHPLBA \ / AMOS7 \ YOURUM ::
#\[7]FFREQKA7ZS27XCMSH5YB2NSXFK6PAWSOX276H4XATMPMZ5T5UMDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
