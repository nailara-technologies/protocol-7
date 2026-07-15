## task: v7 twin restart — proper failure handling on startup timeout

### context

`v7.restart :twin: <zenka>` initiates a concurrent zero-downtime restart:
- new instance starts alongside old via `v7.zenka.instance.track_handover`
- new instance has `replaces_instance` + `handover_expansion` flags
- when new goes online, `v7.handler.zenka_status` triggers drain on old
- when new fails/times out, `handover_cleanup` runs → old instance is safe

### problem

when the new twin instance fails startup (timeout or error):

1. `v7.handler.start-time-out` fires → sets status `error`
2. `v7.handler.zenka_status` (line 228-238): sees `replaces_instance` →
   runs `handover_cleanup` → old instance `being_replaced_by` cleared ✓
3. then falls through to normal restart logic (line 240+) → v7 auto-restarts
   the failed new instance as a REGULAR instance (handover_expansion cleared
   by cleanup) → spawns a second running instance alongside original ✗
4. no clear log message that the twin restart specifically failed ✗

### required fix

in `v7.handler.zenka_status`, when handling `error` or `offline` for an
instance that has `replaces_instance` (i.e. it was a twin replacement):

1. after `handover_cleanup`, log a clear failure message:
   `"twin restart failed for '%s' [instance %d] — original instance %d still running"`
   with $zenka_name, $new_instance_id, $old_instance_id (captured BEFORE cleanup)

2. suppress auto-restart of the failed twin instance — return early or
   mark it stop-implicit so v7 doesn't queue another start attempt.
   the simplest approach: after cleanup, call
   `<[zenka.cmd.stop]>->({ 'args' => $instance_id, 'mode' => 'implicit' })`
   and return.

### key files

- `modules/v7.handler.zenka_status` — main change; lines 228-238 is the hook point
- `modules/v7.zenka.instance.track_handover` — adds `replaces_instance` to new instance
- `modules/v7.zenka.instance.handover_cleanup` — clears both sides of pair

### what NOT to change

- the drain trigger at line 472+ (only fires on online, already correct)
- the old instance restart logic (old instance is unaffected)
- `v7.handler.start-time-out` (already correct, sets error status)

### signatures note

do not modify the 4-line checksum footer at end of module files.
module format: `## [:< ##` header, no `sub {}` wrappers, filename = module name.
`<[module.name]>->()` invocation syntax; `<data.key>` for data tree access.
`$ARG` is the loop variable (not `$_`); `@ARG` is the args array.

### expected result after fix

```
p7c v7.restart :twin: httpd
# new httpd starts, fails to initialize within timeout
# log: "twin restart failed for 'httpd' [instance 5] — original instance 3 still running"
# only one httpd instance running (the original)
# no second httpd spawned
```

#,,.,,.,.,,..,...,..,,.,,,.,,,...,.,.,,..,,,.,..,,...,...,...,,..,..,,,,,,..,,
#IU22QOSC3OGQ6CL43BMQEYSODOFYAGZ7LQMYF6EQDP7LCYCDTCGQCIQT6VZAOQJ7FWIEYBNW5AJ2G
#\\\|X5FYMURLA5ANJ47XDXCXP5HEPTYEVSQ7L3PF6O7DPR4QTRU43AV \ / AMOS7 \ YOURUM ::
#\[7]CVJ5MS5GVOOSFIEDNM4RYC7JB3CAZYSLCQG5RDEHV3Y3LKMBASBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
