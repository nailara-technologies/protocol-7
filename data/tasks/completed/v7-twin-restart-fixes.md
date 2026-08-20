## task: v7 :twin: restart — fix double-instance bug + ambiguity check

### context

`v7.restart :twin: web` was tested and produced 3 running web instances instead of
doing a clean handover. two bugs and one missing feature need to be fixed.

---

### bug 1: double-instance creation (root cause of 3-instance mess)

`v7.zenka.cmd.restart` (twin mode) calls:
1. `<[v7.zenka.instance.track_handover]>->($iid, $drain_time)` → creates instance N
   with `handover_expansion=TRUE, replaces_instance=$iid`
2. `<[zenka.cmd.start]>->({args=>$zname, mode=>'concurrent-handover', source=>$iid})`
   → queues job J → when job executes, `v7.zenka.start` runs

In `v7.zenka.start` (lines 32-33):
```perl
my $instance_id = <jobqueue.joblist.by_id>->{$job_id}->{'instance_id'};
$instance_id //= <[zenka.instance.add]>->($zenka_id);
```

It would reuse a pre-allocated instance IF `instance_id` is set in the job. But
`zenka.cmd.start` never wires instance N into job J. So `v7.zenka.start` creates
a second new instance M (without the handover flags). Instance N sits as a zombie
with no process. Instance M comes online without `replaces_instance` → drain never
triggers → old instance keeps running.

**fix** (in `v7.zenka.cmd.restart`, twin block, after `zenka.cmd.start` call):

```perl
## wire pre-allocated handover instance into the queued job
## so v7.zenka.start reuses it (with replaces_instance + handover_expansion flags)
## [ P7 event loop won't execute the job until current block returns — timing safe ]
if ( $reply->{'mode'} eq qw| true |
    and $reply->{'data'} =~ m|\[ID=(\d+)\]| ) {
    <jobqueue.joblist.by_id>->{$1}->{'instance_id'} = $new_id;
}
```

This must come AFTER the `$reply->{'mode'} ne 'true'` failure check (which calls
handover_cleanup and next). Only wire when start succeeded.

---

### bug 2: ambiguity when multiple instances are running

Currently the twin restart loop iterates over ALL matching instance IDs silently.
If two `web` instances are running, it would attempt twin-restart on both.

**fix** (in `v7.zenka.cmd.restart`, twin mode, BEFORE the `for my $iid` loop):

if `scalar @instance_ids > 1`, reject with an ambiguous error that lists the options:
- for each instance: show instance_id, status, and subname (if set via `$instance->{'subname'}`)
- prompt: "specify an instance id or zenka subname"

```perl
if ( $twin_mode and scalar @instance_ids > 1 ) {
    my @desc = map {
        my $inst = <v7.zenka.instance>->{$ARG};
        my $sn   = defined $inst->{'subname'}
            ? sprintf( ' [%s]', $inst->{'subname'} )
            : '';
        sprintf( 'instance %d%s [%s]', $ARG, $sn, $inst->{'status'} )
    } @instance_ids;
    return {
        'mode' => qw| false |,
        'data' => sprintf(
            "ambiguous: %d %s instances running"
                . " — use 'zenka[subname]' or instance id:\n  %s",
            scalar @instance_ids, $zenka_name, join( "\n  ", @desc )
        )
    };
}
```

note: subname filtering already works via the existing restart parser —
`v7.restart :twin: mpv[audio-0]` narrows @instance_ids to just the audio-0
instance before the twin block. ambiguity only fires when nothing narrows it to one.

---

### bug 3: notify_online dangling on twin failure (already in zenka_status)

In `v7.handler.zenka_status`, the twin failure path (lines 238-246) calls
`handover_cleanup`, logs failure, calls `zenka.cmd.stop`, and returns early.
The early return skips the notify_online deferred-reply handling (lines 298+).
Any caller waiting on `v7.notify_online <instance_id>` would dangle indefinitely.

**fix** — already present in the file from a previous pass. verify it reads:

```perl
if ( defined $old_instance_id ) {
    <[base.logs]>->(...failure message...);
    ## resolve notify_online callbacks for this specific failed instance
    if ( exists <v7.zenka.notify_online>->{$instance_id} ) {
        map {
            <[base.callback.cmd_reply]>->($ARG, { mode=>'false', data=>... });
        } <v7.zenka.notify_online>->{$instance_id}->@*;
        delete <v7.zenka.notify_online>->{$instance_id};
    }
    <[zenka.cmd.stop]>->({args=>$instance_id, mode=>'implicit'});
    return;
}
```

If not present, add it between the failure log and the stop call.

---

### key files

- `src/v7.zenka.cmd.restart` — bugs 1 + 2
- `src/v7.handler.zenka_status` — bug 3 (verify/apply)
- `src/v7.zenka.start` — READ ONLY; do not modify

### signatures note

do not modify the 4-line checksum footer. module format: `## [:< ##` header,
no `sub {}` wrappers. `<[module.name]>->()` invocation; `<data.key>` for tree.
`$ARG` is loop variable; `@ARG` is args array.

#,,.,,..,,,,.,,,,,..,,...,...,.,.,,,.,.,.,,,.,..,,...,.,.,...,...,,..,..,,.,.,
#5RGM6UMY4NZJR6KIZUC7NJO6EDJ5W53FFGUVSF6AKTEN4RBYMFSFCR6C65NWZASS6M2PEOWF6XJ7W
#\\\|BOVFRBURJMSQE7D3ISYZPP7XUWAUZVR3XWLR7L3DL6NWMNFNGRB \ / AMOS7 \ YOURUM ::
#\[7]TKZCG42EOMMZTYCKGXBN2LVPJQUMS2REONQSHOWDRD7OVIN4DWBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
