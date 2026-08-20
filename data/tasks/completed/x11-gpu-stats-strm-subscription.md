## task: X-11 GPU stats STRM subscription + coding zenka utilization feed

### context

`X-11.handler.read_gpu_nvidia` (and `read_gpu_top` for intel) updates the
`X-11.gpu_top.stats.load_average` namespace every second. currently this data
is only readable on-demand via `X-11.cmd.gpu_load`.

the goal is to make GPU utilization available as a live STRM stream so other
zenki (starting with the coding zenka) can subscribe once and receive updates
automatically.

### what to read first

```bash
cat modules/X-11.handler.read_gpu_nvidia  ## stats update loop (bottom of file)
cat modules/X-11.cmd.gpu_load             ## how stats are read + formatted
cat modules/radio.cmd.listen              ## STRM open pattern to follow
cat modules/radio.gap_fill.tick           ## base.stream.push usage example
cat modules/base.callback.cmd_reply       ## STRM reply mode reference
```

---

### phase 1: X-11.cmd.gpu_load — add STRM subscription mode

file: `modules/X-11.cmd.gpu_load`

add a subscription mode: when called with arg `subscribe`, open a STRM stream
and register the caller's stream handle in `<X-11.gpu_top.listeners>`.

```perl
if ( defined $call->{'args'} and $call->{'args'} eq 'subscribe' ) {
    my $h = <[base.stream.open]>->(
        {   sid    => $call->{'session_id'},
            cmd_id => $call->{'command_id'},
            type   => qw| STRM |,
            total  => undef,
        }
    );
    return <[base.callback.cmd_reply]>->(
        $call->{'reply_id'},
        { 'mode' => qw| false |, 'data' => 'stream open refused' }
    ) if not defined $h;

    push @{<X-11.gpu_top.listeners>}, $h;
    <[base.logs]>->( 2, 'gpu stats listener added [sid=%d]',
        $call->{'session_id'} );
    return { 'mode' => qw| deferred | };
}
```

---

### phase 2: emit stats to listeners after each update

file: `modules/X-11.handler.read_gpu_nvidia`
file: `modules/X-11.handler.read_gpu_top`

after the existing stats log line (the `< GPU >  %3s%%` log), add an emit
to all registered listeners. follow the radio.gap_fill.tick pattern:

```perl
if ( defined <X-11.gpu_top.listeners> and @{<X-11.gpu_top.listeners>} ) {
    my $load_1s  = $load_ref->{1} // 0;
    my $avg_5s   = $load_ref->{5};
    my $payload  = defined $avg_5s
        ? sprintf( '%s %s', $load_1s, $avg_5s )
        : sprintf( '%s', $load_1s );

    my @keep;
    for my $h ( @{<X-11.gpu_top.listeners>} ) {
        push @keep, $h if <[base.stream.push]>->( $h, \$payload );
    }
    <X-11.gpu_top.listeners> = \@keep;
}
```

the payload is intentionally minimal: `<load_1s>` or `<load_1s> <avg_5s>` —
the subscriber decides how to interpret it.

---

### phase 3: coding zenka — subscribe and store

files to read first:
```bash
cat modules/coding.init_code          ## init pattern, timer setup
cat cfg/zenki/coding/start  ## modules.load
```

in `modules/coding.init_code` (or a new `modules/coding.gpu_monitor`),
after initialization completes, subscribe to the X-11 GPU stats stream:

```perl
## subscribe to gpu load stream if X-11 is available
<[protocol-7.command.send.local]>->(
    {   'command'  => 'X-11.gpu_load',
        'call_args' => { 'args' => 'subscribe' },
        'reply_cb'  => $code{'coding.handler.gpu_stats_update'},
    }
);
```

add a new handler `modules/coding.handler.gpu_stats_update`:

the handler is the **single writer** to the gpu stats namespace. all other
coding zenka modules read from it directly — no subscription or acquisition
logic anywhere else. the data is simply always current.

store all gpu state under a structured sub-tree in `$data{'coding'}`:

```perl
$data{'coding'}{'stats'}{'gpu'}{'load_1s'}       ## latest 1s reading (0-100)
$data{'coding'}{'stats'}{'gpu'}{'load_5s'}        ## 5s rolling avg if present
$data{'coding'}{'stats'}{'gpu'}{'sparkline_buf'}  ## arrayref, 20-slot ring
$data{'coding'}{'stats'}{'gpu'}{'updated_at'}     ## base.time epoch of last sample
```

in P7 module syntax: `<coding.stats.gpu.load_1s>` etc.

handler logic:
- parse payload (space-separated numbers)
- update the four keys above
- push `load_1s` onto `sparkline_buf`, shift oldest when length > 20
- log at level 3

any routine needing GPU context reads the key directly. if
`<coding.stats.gpu.updated_at>` is undef or stale, X-11 is unavailable —
caller handles gracefully, no other acquisition needed.

what the coding zenka does with the data is otherwise left open — future work
can use these keys for throttling, model selection, error state detection
(GPU idle during active inference = possible stall), or a `coding.gpu_load`
command.

also add `modules/coding.gpu_sparkline` — reads
`<coding.stats.gpu.sparkline_buf>`, renders and returns an ASCII string:

```
  0-15%  : ' '   (space)
 15-35%  : '.'
 35-60%  : ':'
 60-80%  : '|'
 80-100% : '#'
```

example: `[.  .:.:::.::]` left=oldest, right=newest. any inference log
message appends `<[coding.gpu_sparkline]>->()`:

```
task XYZABCD complete [ 47s ]  gpu: [.  .:.:::.::]
```

---

### notes

- `<X-11.gpu_top.listeners>` should be initialized as `[]` in `X-11.init_code`
  or lazily in the emit block with `//= []`
- the subscription is best-effort: if X-11 is not running, the subscribe
  call fails silently — coding zenka should handle the false reply gracefully
- add `coding.handler.gpu_stats_update` to coding zenka's subroutine whitelist
- no signature stubs, no update-signatures run

### signatures note

do not add signature stubs (`#,,.,,,...`). do not run
`bin/Protocol-7 sourcecode update-signatures`. write clean module bodies only.

### success criteria

- [ ] `p7c X-11.gpu_load subscribe` opens a STRM stream
- [ ] subsequent handler invocations push `<load> [avg5s]` to stream
- [ ] dead listeners pruned from list automatically
- [ ] coding zenka stores `coding.gpu.load_1s` updated every second
- [ ] coding zenka handles X-11 unavailable gracefully

### dispatch

model: kimi
reasoning: medium

prompt: |
  Implement the task at data/tasks/x11-gpu-stats-strm-subscription.md

  Read modules/X-11.cmd.gpu_load, modules/X-11.handler.read_gpu_nvidia,
  modules/X-11.handler.read_gpu_top, modules/radio.cmd.listen, and
  modules/coding.init_code before writing anything.

  Implement all 3 phases. The coding zenka handler should store the values
  and nothing more — leave utilization-based decision logic for later.
  No signature stubs, no update-signatures run.

#,,,.,.,,,,,,,,,,,,..,,,.,,.,,..,,,,,,.,.,,.,,..,,...,...,..,,..,,,.,,..,,.,,,
#RQFG3MHJZ4NYVRJNUYLZWLVDZUNASL7L4OCW5ZSZFTH3OLADEI3HNSCQSHGNOBHCSPRF5MCV7DMBW
#\\\|PN6ECZIKJIUCSBFC34TKF6R7D63FFTYXA2RUPENLE3XPRZB46JT \ / AMOS7 \ YOURUM ::
#\[7]FUJ5T5AJ6C4HQLQNBBCRXOX3WOYPCM4C3JOYFUFHVN2GWHFJIGAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
