# task: fix cred-mesh rotation-subscription cross-zenka registration

## context

`bin/dev/cred-mesh-test` got its first-ever live end-to-end run on
2026-07-16 (as part of closing `credential-fabric-integration-test.md`).
20 of 23 assertions now pass. The remaining 3 failures (scenario 4:
`proxy cache flush log`, `transport cache flush log`,
`after-rotation header value`) all trace to one real, previously
undiscovered architecture bug — not a test-script issue like the other
failures fixed that session.

## the bug

`modules/proxy.init_code` (around line 55) subscribes to credential
rotation events like this:

```perl
if ( exists $code{'cred-mesh.subscribe_rotation'} ) {
    <[cred-mesh.subscribe_rotation]>->(
        {   'slot'    => '*',
            'handler' => 'proxy.handler.cred_rotated',
        }
    );
}
```

This works by **loading cred-mesh's module code directly into the proxy
zenka's own process** (see the comment already in that file about the
SO_REUSEPORT double-bind incident, commit `0b52338ad`, from the same
co-loading mechanism). Per this project's per-zenka isolation model
(`CLAUDE.md`: "Each zenka has its own `%data`, `%code`, and `%keys` hash
instances"), calling `cred-mesh.subscribe_rotation` from *inside proxy's
own process* writes the subscription into **proxy's own local copy** of
`<cred-mesh.rotation_subscribers>` — never into the data tree of the
actual, standalone `cred-mesh` zenka process that later runs
`cred-mesh.rotate` → `cred-mesh.handler.rotation_strm` to push the
notification.

`modules/transport.init_code` (around line 43) does the exact same thing
for `transport.handler.cred_rotated`.

So the real `cred-mesh` zenka's `<cred-mesh.rotation_subscribers>->{'*'}`
is never populated by either subscriber. When `cred-mesh.rotate` fires
`cred-mesh.handler.rotation_strm`, live testing showed proxy's own
console buffer logging entries like:

```
[7471771] offline : 'handler' : 'cred_rotated'
```

(a route-send delivery failure, not the expected
`proxy.handler.cred_rotated: flushed N cache entries...` success line).
transport's buffer shows nothing related at all.

## what needs to change

`cred-mesh.subscribe_rotation` needs to be called via a **real
cross-zenka route**, not an in-process co-loaded call — i.e. proxy and
transport's own init_code should route-send an actual subscribe request
to the live `cred-mesh` zenka instance (the same way any other
cross-zenka command dispatch works in this codebase), not call the
function directly via `$code{'cred-mesh.subscribe_rotation'}`.

Two ways to get there, need a design decision before implementing:

1. **route-send at init time**: proxy/transport's init_code sends a real
   `cred-mesh.subscribe_rotation` command over the network (like any
   other cross-zenka call) instead of the local `<[...]>` call. Simplest
   conceptually, but need to handle the case where cred-mesh isn't up yet
   when proxy/transport initialize (retry/backoff, or defer until
   cred-mesh is confirmed online — this codebase already has
   `base.zenka.push` with `notify_online`+backoff for exactly this kind
   of offline-safe cross-zenka call, see
   `data/ai-mem/claude/feedback-...` memory on it, worth reusing rather
   than reinventing).

2. **shared subscriber storage**: keep the in-process co-loaded call, but
   make `<cred-mesh.rotation_subscribers>` a genuinely shared structure
   (file-backed or otherwise) that both the real cred-mesh zenka and any
   co-loading zenka read from the same source. More invasive, touches
   the whole subscribers data model, probably not worth it just for this.

Option 1 looks like the right shape given the codebase already has
`base.zenka.push`'s offline-safe pattern for this exact class of problem.

## verification

after the fix, `bin/dev/cred-mesh-test` (scenario 4 specifically) should
show:
```
[ OK ] scenario 4 : proxy cache flush log : proxy log shows cache flush for rotated slot
[ OK ] scenario 4 : transport cache flush log : transport log shows profile cache flush for rotated slot
[ OK ] scenario 4 : after-rotation header value : expected new value 'new-key-bbbb', got 'new-key-bbbb'
```
(the third assertion is downstream of the first two — proxy/transport
need to actually flush their caches before a follow-up request would
pick up the new credential value.)

## signatures note

do NOT manually write or edit signature lines. do not add stub
signatures to new files.

#,,.,,,,,,,,,,..,,,..,,,.,,.,,,..,,,.,,,.,,,,,..,,...,...,...,,..,..,,,,.,,.,,
#BSMQOGNO5JZ7R6KSM36ULQUFNP7X74VPGZMECQOOHNHWFNZ24COLU3SMS4SHZVZFX26KHL6US45HW
#\\\|BIQOXCEMLXJTESWS4GXHHXSREYNBRKCCAK7XM6RQEPNGVTTCVZQ \ / AMOS7 \ YOURUM ::
#\[7]UHHM3DJFIHZYAIYPBAMGR7RWXJ7CEYFN4CQZHL4EFKOKNNQ27WDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
