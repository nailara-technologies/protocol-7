## [:< ##

# name  = task: migrate direct Event->io() calls to base.event.add_io wrapper
# descr = replace the two remaining direct Event->io() call sites with the
#         event.add_io wrapper, now that its prio-passthrough bug is fixed,
#         verified under real load via siege against httpd + httpsd

## background

`base.event.add_io` had a real bug (fixed 2026-07-25, see
data/ai-mem/claude/topic-anyevent-bridge-vs-replace.md and
feedback-base-prefix-stripped.md for the discovery path): its `prio` field
read `$params->{'desc'}` instead of `$params->{'prio'}` -- a copy-paste
error from the line directly above it, silently discarding any caller's
explicit priority. Confirmed live-affected caller:
`nshell.setup_stdin_watcher`.

**Why the direct `Event->io()` calls exist -- settled.** Two theories
ruled out first: not the prio bug (didn't exist as a deterrent reason),
and not "the wrapper was added later" (`base.event.add_io` has existed
since 2015, well before these call sites). `event.add_idle` (added
`c3628410d`, 2026-04-23) turned out to be a different, unrelated wrapper
in the same family, not the explanation either. **Actual answer**: LLMs
writing/editing this code over time simply ignored the existing wrapper
-- and requests to use it -- falling back to direct `Event.pm` calls
instead of checking for/using the already-established `event.add_io`
convention. Same class of gap as the `swap_subs` pre-swap-name mistakes
already tracked in [[feedback-swap-subs-not-fragile]] and
[[feedback-base-prefix-stripped]] -- check for a promoted wrapper before
writing new code near an established primitive family, don't assume none
exists just because the immediate surrounding code doesn't use one.

Now that the bug is fixed, these direct calls should go back through the
wrapper for consistency (single choke point for future event-core work --
see the anyevent-bridge-vs-replace memory file for why that consolidation
matters: every variable/IO watcher registration being traceable from one
place is what makes future event-core experiments tractable at all).

## scope -- confirmed via `grep -rln "Event->io(" modules/`

Exactly two files, three call sites (excluding `base.event.add_io` itself,
the wrapper's own real implementation, and
`httpd.route.handler.web-relay`, which is a **legitimate exception** --
see below):

1. `modules/base.session.init` -- two direct calls:
   - `input_handler` watcher (~line 241): `poll => 'r'` or `'rt'`
     [ depends on `@timeout_callback` ], `prio => 1`, includes
     `@timeout_callback` splice for auth/http/generic input timeouts.
   - `input_error` watcher (~line 254): `poll => 'e'`, `prio => 2`.

2. `modules/httpd.route.handler.web-relay` (~line 49) -- **check before
   migrating**: this call explicitly cancels and replaces
   `base.session.init`'s own `input_handler` watcher mid-session
   ("replace input watcher : keep EOF detection, disable timeout" --
   read the comment at line 45 in the file). If migrating
   `base.session.init`'s version to the wrapper changes anything about
   watcher identity/fields the way `web-relay` depends on for its
   cancel-and-replace logic, this second site may need to stay as direct
   `Event->io()` or be migrated in lockstep with careful attention to
   that dependency. Do not migrate this one blindly just because it
   matches the same textual pattern -- verify the relationship first.

## the actual change, for base.session.init's two watchers

Replace:
```perl
$session->{'watcher'}->{'input_handler'} = Event->io(
    'fd'     => $fd,
    'cb'     => sub { &{ $code{'base.handler.read'} } },
    'poll'   => scalar(@timeout_callback) ? qw| rt | : qw| r |,
    'prio'   => 1,
    'repeat' => FALSE,
    'data'   => $id,
    'desc'   => sprintf( '[%d] input handler', $id ),
    @timeout_callback
);
```
with the wrapper equivalent:
```perl
$session->{'watcher'}->{'input_handler'} = <[event.add_io]>->(
    {   'fd'      => $fd,
        'handler' => qw| base.handler.read |,
        'poll'    => scalar(@timeout_callback) ? qw| rt | : qw| r |,
        'prio'    => 1,
        'repeat'  => FALSE,
        'data'    => $id,
        'desc'    => sprintf( '[%d] input handler', $id ),
        @timeout_callback   ## check wrapper accepts these keys passthrough --
                            ## read base.event.add_io fully, it may need a
                            ## small extension to accept timeout/timeout_cb,
                            ## confirm before assuming it already does
    }
);
```
**Important difference from a bare find-replace**: `event.add_io` takes a
`handler` key (a `%code` name, looked up as `$code{$callback}`) OR a
`cb` direct coderef -- not a raw `cb => sub {...}` closure the way
`Event->io` takes directly. `base.handler.read`/`base.handler.session_error`
are real `%code` entries (confirmed: `grep -rn "name.*base.handler.read"
modules/`), so use the `handler` key form, not `cb`. Read
`base.event.add_io` fully before writing the replacement calls -- do not
assume every `Event->io` param maps 1:1 to a wrapper param without
checking (e.g. confirm `timeout`/`timeout_cb` passthrough actually works
in the wrapper, since `base.session.init`'s `input_handler` call is the
only place currently combining `@timeout_callback` with an IO watcher --
this may be new territory for the wrapper).

## style
- $ARG not $_, lowercase comments, `[ word ]` bracket annotations
- no signature stubs on modified files -- repo's own pre-commit signs them

## verification -- real load testing required, not just syntax checks

This touches the input-read/exception watcher for **every session, on
both httpd and httpsd, for every protocol they serve** -- per the scope
note in topic-anyevent-bridge-vs-replace.md, this is not a place to trust
`perl -c`/`ptd -c` alone.

1. `bin/ptd -c` / `perl -c` clean on all touched files (baseline, not
   sufficient alone).
2. Start httpd and httpsd zenki fresh, confirm normal startup with no
   errors in the boot log.
3. **Load test via `siege` against both `httpd` and `httpsd`** -- basic
   sustained-connection test first (e.g. `siege -c 10 -t 30s <url>`) to
   confirm connections establish, serve, and close cleanly under
   concurrent load -- watch for: connections hanging (broken watcher
   registration), auth/http timeout callbacks firing at the wrong time
   or not at all (the `@timeout_callback` passthrough is the highest-risk
   part of this change), and exception-path behavior (`input_error`
   watcher) still triggering correctly on abrupt client disconnects
   during the siege run.
4. Compare siege's own summary stats (availability %, response time,
   failed transactions) against a baseline run captured *before* this
   change, on the same hardware/load profile -- not just "did it not
   crash," but "did throughput/latency stay the same."
5. Specifically re-verify `httpd.route.handler.web-relay`'s
   cancel-and-replace behavior still works if that file ends up touched
   too -- a relay session mid-flight should still correctly swap its
   input watcher without dropping the connection or double-firing
   callbacks.
6. Only once siege results look clean on both httpd and httpsd should
   this be considered ready to sign/stage.

## dispatch

Not yet dispatched -- this is exactly the kind of task where the
verification step (siege load-testing two live network daemons) benefits
from a human watching results interactively rather than a cold dispatch
self-certifying "looks fine." Scope it further / decide dispatch-vs-
interactive once ready to pick this up.

#,,,,,...,,,.,.,.,...,,,,,,,.,,,.,,,,,...,.,,,..,,...,...,,.,,..,,..,,,,.,...,
#GJH7G6IRZB556QTSYI7KXSVCB2MVLM6B65JPYVEJ26QU2YXCHDFZ4V2UKFQYGSW7E6XJK2OS6SGBU
#\\\|TCWPU4FSFPVTKKDV5EZR6W6KH6IS3QFG6DLXOHTPBGJZBMXED5I \ / AMOS7 \ YOURUM ::
#\[7]3E2SZSYWOOO3YOQZ2GXFJRJJLVFP6ZWDWSE2BMRZX22UX22TA4DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
