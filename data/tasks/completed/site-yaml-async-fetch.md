## task: make site-yaml's job-detail fetch non-blocking

### goal

`site-yaml.handler.fetch_tick` currently fetches each queued job-detail page
with a **synchronous** `LWP::UserAgent->get()` call
(`site-yaml.http.get:11`, 30s internal timeout). that call runs directly
inside the zenka's single-threaded event loop, so any one fetch that stalls
— for any reason: proxy outage, DNS stall, a slow upstream, a network hang —
blocks `site-yaml` from answering `heart` for as long as the stall lasts. with
`heartbeat.timeout` now enforced, a stall long enough trips it and v7 kills
the instance mid-fetch (confirmed live: `response timeout, retrying` →
`online --> error` → `<TERM>`).

replace the blocking fetch inside `fetch_tick` with the project's existing
async-worker pattern (fork + non-blocking pipe drain + timeout guard), so a
stalled fetch can never take the heartbeat responder down with it — this is a
transport fix, independent of and unrelated to whatever causes any particular
fetch to stall.

this is a **transport** change only. `fetch_tick`'s queue/backoff/retry
classification logic is settled and must not change in *behavior* — see "what
NOT to change" below.

---

### precedent to mirror

`povray.spawn_render` / `povray.handler.render_output` /
`povray.handler.render_timeout` / `povray.finalize_render` (landed and
live-verified 2026-07-27) is the established pattern in this codebase for
"blocking external I/O call → non-blocking, event-loop-safe": fork a worker,
drain its output via `event.add_io` watchers, guard with an
`event.add_timer` timeout, finalize on EOF. read all four files before
writing anything.

**two deliberate differences from povray, both load-bearing:**

1. **use `<[base.fork]>` (plain fork), not `IPC::Open3` + exec.** povray
   execs an external binary. here the worker must keep running the *same*
   already-configured Perl `LWP::UserAgent` object
   (`$data{'site-yaml'}{'ua'}`, set up once in `site-yaml.init_code` with the
   correct proxy env, headers, User-Agent string) — forking preserves that
   object's config in the child's copy for free; shelling out to `curl`
   would mean re-implementing proxy/header/gzip/charset handling that
   already works. see `weather.base.fork_weather_child` for this codebase's
   `<[base.fork]>` idiom (that one boots a full persistent child zenka,
   which is *not* wanted here — see pitfall below).
2. **capture the full payload, don't drain-and-discard it.** povray's
   stdout watcher only exists to detect EOF (povray writes its own output
   file) and caps the tail at 2048 bytes for diagnostics only. here stdout
   *is* the payload — a job-listing page body, potentially several hundred
   KB — so the accumulator must not truncate it. cap total accumulated size
   at a sane hard ceiling (e.g. 4MB) as a memory-safety backstop only, not
   as a normal-case truncation.

---

### where to implement

new modules:

| file | role |
|---|---|
| `src/site-yaml.async_fetch.spawn` | fork worker, set up io/timeout watchers — mirrors `povray.spawn_render` |
| `src/site-yaml.handler.fetch_io` | drain worker pipe, accumulate, finalize on EOF — mirrors `povray.handler.render_output` |
| `src/site-yaml.handler.fetch_timeout` | abort a stalled worker — mirrors `povray.handler.render_timeout` |
| `src/site-yaml.async_fetch.finalize` | reap worker, produce `http.get`-shaped result, invoke continuation — mirrors `povray.finalize_render` |
| `src/site-yaml.stepstone.job_from_html` | pure extraction, no fetch — the JSON-LD/salary/field logic currently inside `stepstone.job`, moved out verbatim |

modified:

| file | change |
|---|---|
| `src/site-yaml.handler.fetch_tick` | replace the synchronous `<[site-yaml.stepstone.job]>->($url)` call with `<[site-yaml.async_fetch.spawn]>->($id, $url, $on_done)`; everything from `my $ql = ...` onward moves into `$on_done`, unchanged in logic |
| `src/site-yaml.stepstone.job` | becomes a thin wrapper: fetch via `site-yaml.http.get`, then delegate to `site-yaml.stepstone.job_from_html`. kept synchronous and unchanged in *behavior* — still used by `site-yaml.cmd.fetch` (out of scope, see below) |
| `cfg/zenki/cube/access.zenki` | add `access.cmd.usr.site-yaml = v7.register_child` (site-yaml's existing grant block at the `access.cmd.usr.site-yaml` line does not have it yet — mirrors `access.cmd.usr.audio`/`access.cmd.usr.povray`; povray's own first live test hit exactly this "no perm" gap, don't repeat it) |

**explicitly out of scope — do not touch:**

- `site-yaml.cmd.fetch`, `site-yaml.extract`, `site-yaml.stepstone.search`,
  `site-yaml.cmd.import`, `site-yaml.cmd.import-url` — all unchanged.
  `cmd.import` in particular has its *own* synchronous fetch-per-page loop
  (`stepstone.search` inside a `for my $page` loop, plus a blocking
  `select(undef,undef,undef,$delay_search)` sleep between pages) that is a
  comparably real blocking hotspot — arguably the one actually captured in
  the incident log this task originated from. it is a legitimate follow-up
  once this primitive is proven, not part of this dispatch: converting it
  needs its own deferred-cmd-reply design (`cmd.import` currently replies
  synchronously with a summary it can no longer compute inline), which is
  more surface than this task should take on at once.
- `site-yaml.fetch.schedule` / `site-yaml.fetch.state` / `site-yaml.fetch.backoff`
  — unchanged, called from `fetch_tick`'s continuation exactly as today.

---

### implementation spec

#### 1. `site-yaml.async_fetch.spawn`

signature: `($id, $url, $on_done)` — `$on_done` is a coderef,
`$on_done->($result)`, called exactly once, where `$result` matches
`site-yaml.http.get`'s existing return contract: a content string on
success, a numeric HTTP status code on failure (never `undef` — `http.get`
only returns `undef` for an empty `$url`, which cannot happen here since
`fetch_tick` already guards `return unless length $url`).

```perl
## [:< ##

# name  = site-yaml.async_fetch.spawn
# descr = fork a one-shot worker to fetch $url, non-blocking [ mirrors
#         povray.spawn_render, but plain fork + full-payload capture ]

my ( $id, $url, $on_done ) = @ARG;

socketpair( my $child_pipe, my $parent_pipe, AF_UNIX, SOCK_STREAM, PF_UNSPEC )
    || die "can't create socketpair. [ \l$OS_ERROR ]";
map { binmode($ARG) } ( $child_pipe, $parent_pipe );

my $t0  = time;
my $pid = <[base.fork]>;

if ( not defined $pid ) {
    <[base.logs]>->( 0, 'site-yaml.fetch: spawn failed [ %s ] %s', $id, $OS_ERROR );
    $on_done->(0);
    return;
}

if ( $pid == 0 ) {    ## child : one-shot, never returns to the event loop ##
    close($parent_pipe);

    ## reuse the already-configured UA [ proxy / headers / agent string ] ##
    my $res  = eval { $data{'site-yaml'}{'ua'}->get($url) };
    my $body = '';
    if ( not $res or not $res->is_success ) {
        $body = 'ERR ' . ( $res ? $res->code : 599 ) . "\n";
    } else {
        $body = 'OK' . length( $res->decoded_content ) . "\n" . $res->decoded_content;
    }

    ## write-then-exit : parent drains until EOF, no length negotiation ##
    print {$child_pipe} $body;
    close($child_pipe);

    ## never fall through to normal zenka teardown -- this process never  ##
    ## entered the event loop and must not touch the parent's shared      ##
    ## epoll/AIO state on exit [ see pitfalls below ]                     ##
    POSIX::_exit(0);
}

## parent ##
close($child_pipe);
POSIX::setpgid( $pid, $pid );    ## own process group : clean kill on timeout ##
<[base.zenki.report_child_pid]>->($pid);

<site-yaml.fetch_worker>->{$id} = {
    'pid'      => $pid,
    'url'      => $url,
    'on_done'  => $on_done,
    'buf'      => '',
    'started'  => $t0,
    'fh'       => $parent_pipe,
};

<site-yaml.fetch_worker>->{$id}{'w_io'} = <[event.add_io]>->(
    {   'fd'      => $parent_pipe,
        'handler' => qw| site-yaml.handler.fetch_io |,
        'data'    => { 'id' => $id },
        'poll'    => qw| re |
    }
);

<site-yaml.fetch_worker>->{$id}{'timer'} = <[event.add_timer]>->(
    {   'after'   => <site-yaml.cfg.fetch_worker_timeout> // 45,
        'handler' => qw| site-yaml.handler.fetch_timeout |,
        'data'    => { 'id' => $id }
    }
);

<[base.logs]>->( 2, 'site-yaml.fetch: spawn [ %s ] pid=%d url=%s', $id, $pid, $url );

return;
```

note the protocol is deliberately trivial: the child writes `"OK<n>\n"` +
`<n>` bytes of content, or `"ERR <code>\n"`, then closes. the parent doesn't
need to parse `<n>` mid-stream — it just accumulates everything until EOF,
then parses the first line off the complete buffer in `finalize`. (`decoded_content`
is arbitrary bytes and can itself contain `\n` — that's exactly why the
length prefix on the `OK` line matters, don't switch to scanning for a
delimiter.)

#### 2. `site-yaml.handler.fetch_io`

```perl
## [:< ##

# name  = site-yaml.handler.fetch_io
# descr = drain one async fetch worker's pipe; finalize at eof

my $event  = shift;
my $wdata  = eval { $event->w->data } // {};
my $id     = $wdata->{'id'} // '';
my $state  = <site-yaml.fetch_worker>->{$id};
return unless defined $state;

my $fh = $state->{'fh'};
return unless defined fileno($fh);

my $buf = '';
my $n   = sysread( $fh, $buf, 65536 );

if ( not defined $n ) {
    return if $OS_ERROR == Errno::EAGAIN() or $OS_ERROR == Errno::EWOULDBLOCK();
    <[site-yaml.async_fetch.finalize]>->($id);    ## real read error : finalize with whatever we have ##
    return;
}

if ( $n > 0 ) {
    $state->{'buf'} .= $buf if length( $state->{'buf'} ) < 4_194_304;    ## 4MB hard cap ##
    return;
}

## eof ##
<[site-yaml.async_fetch.finalize]>->($id);
return;
```

(fill in the same closed-fd/EBADF precheck `povray.handler.render_output`
uses before `sysread` — copy that guard, the reasoning is identical.)

#### 3. `site-yaml.handler.fetch_timeout`

mirror `povray.handler.render_timeout` almost exactly: look up
`<site-yaml.fetch_worker>->{$id}`, log at **level 0** (this is a real
failure, not routine diagnostics — matches povray's own precedent), kill
the worker's process group, then call `finalize` with a `timed_out` flag so
it reports the failure rather than trying to use a partial buffer.

#### 4. `site-yaml.async_fetch.finalize`

```perl
## [:< ##

# name  = site-yaml.async_fetch.finalize
# descr = reap async fetch worker, produce http.get-shaped result, continue

my $id    = shift;
my $state = delete <site-yaml.fetch_worker>->{$id};
return unless defined $state;

$state->{'w_io'}->cancel  if defined $state->{'w_io'};
$state->{'timer'}->cancel if eval { $state->{'timer'}->is_active };
close( $state->{'fh'} ) if defined fileno( $state->{'fh'} );

## reap : avoid a zombie -- WNOHANG is fine, worker already closed its ##
## write end so it's exiting or already gone                           ##
waitpid( $state->{'pid'}, POSIX::WNOHANG() );

my $elapsed = time - $state->{'started'};
my $buf     = $state->{'buf'} // '';

my $result;
my $log_tail;
if ( $buf =~ m{\AOK(\d+)\n}s ) {
    my $len = $1;
    $result   = substr( $buf, length("OK$len\n"), $len );
    $log_tail = sprintf 'ok %dB', length($result);
} elsif ( $buf =~ m{\AERR (\d+)}s ) {
    $result   = 0 + $1;
    $log_tail = sprintf 'err %d', $result;
} else {
    $result   = 599;    ## worker died / timed out / malformed, no usable status ##
    $log_tail = $state->{'timed_out'} ? 'timeout' : 'no reply';
}

<[base.logs]>->(
    2, 'site-yaml.fetch: done [ %s ] %.2fs %s',
    $id, $elapsed, $log_tail
);

$state->{'on_done'}->($result);
return;
```

this is the log line called out in the dispatch instructions below — every
fetch attempt gets exactly one level-2 line with its outcome and wall-clock
duration, regardless of whether it succeeded, errored, or timed out. no
other new per-fetch logging should be added; this one line is meant to be
sufficient on its own for future latency/stall diagnosis without needing
another investigation like the one that produced this task.

#### 5. `site-yaml.stepstone.job_from_html`

move everything from today's `stepstone.job:11` (`## extract JSON-LD...`)
through the end verbatim into this new file, taking `($url, $html)` instead
of `($url)`. no logic changes.

#### 6. `site-yaml.stepstone.job` becomes

```perl
my $url  = $ARG[0] // '';
my $html = <[site-yaml.http.get]>->($url);
return "fetch failed: $url" if not defined $html;
return <[site-yaml.stepstone.job_from_html]>->( $url, $html );
```

byte-identical behavior to today, still synchronous — `cmd.fetch` keeps
working exactly as it does now.

#### 7. `site-yaml.handler.fetch_tick`

```perl
my $queue = $data{'site-yaml'}{'fetch_queue'} // [];

if ( not @{$queue} ) {
    <[site-yaml.fetch.schedule]>;
    return;
}

my $item          = shift @{$queue};
my $url           = $item->{'url'}           // '';
my $id            = $item->{'id'}            // '';
my $reply_handler = $item->{'reply_handler'} // '';

return unless length $url;

<[site-yaml.async_fetch.spawn]>->(
    $id, $url,
    sub {
        my $raw_result = shift;    ## content string, or numeric http code ##

        my $job
            = ( $raw_result =~ m{\A\d+\z} )
            ? $raw_result
            : <[site-yaml.stepstone.job_from_html]>->( $url, $raw_result );

        ## everything from here to the end of today's fetch_tick is        ##
        ## UNCHANGED -- same $ql computation, same is_gone/is_ratelimit    ##
        ## classification, same retry/backoff/reply/reschedule calls       ##
        ...
    }
);

return;
```

the `...` above is today's `fetch_tick` body from `my $ql = scalar @{$queue} + 1;`
onward, copied verbatim into the closure — every `<[site-yaml.fetch.backoff]>`,
`<[site-yaml.fetch.state]>`, `<[site-yaml.fetch.schedule]>`, and
`<[protocol-7.route-send]>` call stays exactly where it is today, just
inside a callback instead of inline. do not restructure the classification
logic itself.

---

### pitfalls [ read before writing the fork/io code ]

- **the child must `POSIX::_exit(0)` immediately, never fall through to
  normal zenka shutdown.** this worker never registers as a session, never
  enters the event loop, and shares the parent's epoll/AIO fds by virtue of
  fork — a normal `exit`/global-destruction path could touch or double-close
  that shared state out from under the still-running parent. `weather.base.
  fork_weather_child` is a *different, heavier* pattern (a full persistent
  child zenka with its own session/event loop) — do not copy its
  `IO::AIO::reinit()` / `base.session.init` / `load_runtime_modules` machinery
  here, none of it applies to a one-shot worker that talks over a plain pipe
  and exits in milliseconds.
- **`access.cmd.usr.site-yaml` needs `v7.register_child` added** in
  `cfg/zenki/cube/access.zenki` (see table above) — without it, every spawn
  logs `no perm. [ src 'site-yaml' cmd|usr 'v7.register_child' ]` and the
  worker is never tracked by v7. this is the exact gap povray hit on its own
  first live test.
- **EAGAIN on a non-blocking read is not EOF.** `site-yaml.handler.fetch_io`
  must NOT finalize on EAGAIN — only on `sysread` returning `0` (true EOF)
  or a real error. copy `povray.handler.render_output`'s exact EAGAIN/EBADF
  handling, don't reinvent it.
- **`$data{'site-yaml'}{'ua'}` reuse across fork is safe here specifically**
  because the parent never calls `->get()` on it concurrently with a
  worker — the worker's copy lives in a separate process's address space
  after fork, and the parent process only ever spawns the next worker after
  the previous one's `finalize` has already run (one item at a time, per
  `fetch_tick`'s existing queue design). don't build a separate UA instance
  per worker "to be safe" — it's unnecessary complexity and would lose the
  proxy/header config subtly if built wrong.

---

### what NOT to change

- `fetch_tick`'s retry/backoff/gone/ratelimit classification logic — same
  conditions, same retry counts (2 generic, 5 ratelimit), same log tags.
- `site-yaml.fetch.schedule` / `.backoff` / `.state` — untouched.
- `site-yaml.cmd.fetch`, `.extract`, `.stepstone.search`, `.cmd.import`,
  `.cmd.import-url` — untouched, see "explicitly out of scope" above.
- `site-yaml.http.get`'s own contract (string on success / numeric code on
  failure) — the new worker protocol must preserve this exactly, since
  `stepstone.job`'s unconverted synchronous path still depends on it.

---

### verify

```bash
grep -n "site-yaml.stepstone.job\b" src/site-yaml.*     ## should show job_from_html split cleanly ##
grep -rn "ENV=()" src/site-yaml.*                       ## must be empty -- no exec-external wipe path used ##
grep -n "v7.register_child" cfg/zenki/cube/access.zenki | grep site-yaml
perl -c src/site-yaml.async_fetch.spawn src/site-yaml.handler.fetch_io \
    src/site-yaml.handler.fetch_timeout src/site-yaml.async_fetch.finalize \
    src/site-yaml.stepstone.job_from_html src/site-yaml.stepstone.job \
    src/site-yaml.handler.fetch_tick
```

### test plan

no live network execution required to sign off the mechanism; the queue
retry logic is unit-testable by hand-tracing, same as `stepstone.job`'s
error branches are today. if a live instance is reachable:

```bash
p7c site-yaml.import-url url=<a-real-stepstone-job-posting-url>
## while the fetch is in flight [ p7-log or v7.list shows a worker pid ] ##
p7c site-yaml.heart          ## must reply immediately, not after the fetch completes ##
```

the load-bearing check is the second line: the zenka must answer heartbeat
*while a fetch is in flight*, exactly like povray's own live verification
confirmed non-blocking behavior by calling `povray.status` mid-render.

**correction — ignore any earlier note in this dispatch about a "known
proxy issue":** that claim was wrong and has been retracted. the proxy is
confirmed working correctly (`site-yaml.eval-code $ENV{'http_proxy'}`
returns the correct address from inside the live zenka). do not assume a
live-fetch failure during testing is environmental — if a real fetch
fails or hangs, treat it as a genuine bug in this implementation and debug
it normally, same as any other test failure. `site-yaml.bypass_proxy` is
unrelated to this task; don't touch it.

---

## signatures_note

module files end with a 4-line `#,,,` AMOS7 data signature block. do not
hand-write or copy those blocks for new/changed files — leave signing to
`bin/Protocol-7 sourcecode update-signatures`. register the 5 new modules
in `cfg/zenki/site-yaml/subroutines.load-early`.

---

### dispatch

model: k2.7

prompt: |
  implement the task at data/tasks/site-yaml-async-fetch.md

  read povray.spawn_render / povray.handler.render_output /
  povray.handler.render_timeout / povray.finalize_render first — they are
  the structural precedent this task mirrors, with the two deliberate
  differences spelled out in the task file's "precedent to mirror" section.

  the task file's code sketches are close to final but not gospel — fix
  anything that doesn't actually compile or doesn't match this codebase's
  real event/fork/io primitives (event.add_io, event.add_timer,
  base.fork) as you find them, same as you would for any other module.

  the level-2 diagnostic log line in async_fetch.finalize is a specific,
  deliberate requirement, not decoration — keep it as the one line per
  fetch attempt, don't add per-chunk io logging.

  read the "pitfalls" section before writing the fork/io code — the
  child-process-exit and access.zenki gotchas are both things a prior
  dispatch on a near-identical pattern (povray) got wrong on the first try.

  read the "known, unrelated environment issue" note in the test plan
  before you do any live verification — if a real fetch hangs or errors
  immediately, that is a pre-existing proxy-reachability issue on this
  host, not your code. set site-yaml.bypass_proxy = yes to test around it,
  don't debug your own rewrite against it.

  use $ARG not @_ where the file already does; lowercase comments; bracket
  annotations [ like this ]; do not touch the trailing signature blocks.

#,,.,,,,,,,,,,,,.,,,,,.,,,..,,,..,,,,,,..,,,,,..,,...,...,,,,,.,,,.,.,..,,,,.,
#EJ7GZTCISE5GBHWG5BJPKA6FLET6OX3DBCJC6TFINCN4XQB5MOEN4TJWFFGD3GTUIGGZSGQ3GZJVA
#\\\|ZMSMHSRBQS6S2ILMTFCDXTQ24J7CLU3JFSS4A6QIJRUZ3C7XPMW \ / AMOS7 \ YOURUM ::
#\[7]5HI3YZ5HYLVCOZELRIMTE35NRO6CLVNDBW5PXIJ5Y4KQ6RGH72DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
