## coding zenka — twin restart gpu pid isolation + crash restart resilience

### context

during `:twin:` concurrent restart the coding zenka has a mutual kill loop:
both old and new instances share `state/inference.gpu.pid`. each reads the
other's pid and kills the other's freshly-spawned llama-server →
infinite crash-restart loop.

four targeted fixes across four existing modules. no new modules needed.

---

### fix 1 — instance-scoped pid file with timestamped routines

**file**: `src/coding.spawn_inference_server`

replace the orphan-detection block (currently lines 74-101) and the pid-file
write (currently line 410) with instance-scoped versions using the timestamped
file routines.

current (to replace):
```perl
my $pid_rel   = "state/inference.$backend.pid";
my $saved_ref = <[file.zenka_dir.load]>->($pid_rel);
if ( defined $saved_ref ) {
    my ( $saved_pid, $saved_bin ) = split m|\n|, $saved_ref->$*;
    ...kill orphan...
    <[file.zenka_dir.unlink_file]>->($pid_rel);
}
```

current write (to replace):
```perl
<[file.zenka_dir.write]>->( $pid_rel, \"$pid\n$binary\n" );
```

**replacement** — instance-scoped glob + timestamped routines:

```perl
## instance-scoped pid file: old and new twins never clobber each other ##
my $zenka_dir = <[file.zenka_dir.data_path]>;
my $pid_rel   = "state/inference.$backend.$$.pid";

## ensure state/ subdir exists ##
<[file.make_path]>->( "$zenka_dir/state" )
    unless -d "$zenka_dir/state";

## scan ALL instance pid files for this backend and kill any live orphans ##
for my $orphan_path ( glob "$zenka_dir/state/inference.$backend.*.pid" ) {
    my ( $age_s, $pid_bin_str )
        = <[file.timestamped_delta_s]>->($orphan_path);
    next unless defined $pid_bin_str;
    my ( $saved_pid, $saved_bin ) = split m|\s+|, $pid_bin_str, 2;
    $saved_pid //= '';
    $saved_bin //= '';
    if ( $saved_pid =~ m|^\d+$| and kill( 0, $saved_pid ) ) {
        my $proc_cmd = '';
        if ( open my $cfh, '<', "/proc/$saved_pid/cmdline" ) {
            local $/;
            $proc_cmd = <$cfh>;
            close $cfh;
        }
        if ( length $saved_bin and $proc_cmd =~ m|\Q$saved_bin\E| ) {
            my $age_str = defined $age_s
                ? <[base.parser.duration]>->($age_s)
                : 'unknown age';
            kill( 'KILL', $saved_pid );
            <[base.waitpid]>->($saved_pid);
            <[base.logs]>->(
                1,
                '[spawn_inference_server] killed orphan %s server'
                    . ' [pid:%d age:%s] from pid file',
                $backend, $saved_pid, $age_str
            );
        }
    }
    unlink $orphan_path;    ## clean up regardless of kill result ##
}
```

and replace the pid-file write at the bottom:
```perl
## write timestamped pid file for this instance ##
<[file.write_timestamped]>->( "$zenka_dir/$pid_rel", "$pid $binary" );
```

`file.write_timestamped` accepts an absolute path (detects `/`) — stores
`$ntime $pid $binary\n`.  `file.timestamped_delta_s` returns `($delta_s, $value)`
where value is `"$pid $binary"` — split on whitespace to recover both fields.

`base.parser.duration` takes seconds (numeric) and returns e.g. `"2m 14s"`.
if it is not callable for any reason, fall back to `sprintf '%.0fs', $age_s`.

**also remove** the stale `$saved_ref` / `file.zenka_dir.load` variable
declarations that are no longer used.

---

### fix 2 — remove pkill from restart_server

**file**: `src/coding.handler.restart_server`

remove these lines (roughly lines 31-35):
```perl
## Kill existing server on this port ##
my $pkill_cmd = sprintf 'pkill -f "llama-server.*--port %d" 2>/dev/null',
    $port;
system($pkill_cmd);
sleep 1;    ## brief pause for cleanup ##
```

`spawn_inference_server` already kills the old server via in-memory
`<coding.inference_servers>` state (`kill('KILL', -$old_pid)` + waitpid block).
the `pkill` here is redundant and dangerous during `:twin:` — it kills any
llama-server on that port including the new twin's just-spawned server.

---

### fix 3 — skip crash-restart when draining (inference_server_sigchld)

**file**: `src/coding.handler.inference_server_sigchld`

inside the `for my $backend (qw| gpu cpu |)` loop, after the
`$server_info->{'exit_status'} = $exit_status` assignment and before the
restart_count / backoff logic, add:

```perl
## skip crash recovery if zenka is draining [ new twin instance owns GPU ] ##
if ( <coding.draining> ) {
    <[base.logs]>->(
        1,
        '[inference_server_sigchld] draining — skipping %s crash restart',
        $backend
    );
    next;
}
```

this mirrors the identical guard already in `coding.handler.inference_crash_restart`
(lines 10-15 of that module).

---

### fix 4 — await_resources: stop → cancel

**file**: `src/coding.handler.await_resources`

find:
```perl
$event->w->stop if defined $event->w;
```
change to:
```perl
$event->w->cancel if defined $event->w;
```

`->cancel` removes the watcher permanently. `->stop` only pauses it, leaving
it eligible to re-fire — wrong for the one-shot "port is free, spawn now" path.

---

### what NOT to do

- do not touch the 4-line `#,,...` / `#\\\|` / `#\[7]` / `#:::::` footer —
  it is a cryptographic signature; `bin/Protocol-7 sourcecode update-signatures`
  regenerates it. leave existing signatures exactly as-is.
- do not add a `#,,.,,,...` stub to new files — that blocks the signing system.
- do not use `$_` in place of `$ARG` — check the calling convention in each module.
- do not add `SUPER::` calls — this is a flat module system.
- do not add `sub { }` wrappers — the file IS the subroutine body.

---

### verification

after implementing:
```
grep -n 'inference\.[a-z]*\.pid' src/coding.spawn_inference_server
```
should show `$backend.$$.pid`, not bare `$backend.pid`

```
grep -n 'pkill' src/coding.handler.restart_server
```
should return nothing

```
grep -n 'draining' src/coding.handler.inference_server_sigchld
```
should show the new guard

```
grep -n 'cancel' src/coding.handler.await_resources
```
should show the fix

#,,,.,,,.,.,,,,,,,,,.,,..,,.,,,,,,...,,.,,,,.,..,,...,...,...,,.,,..,,,,,,...,
#FC3QJZERULU22Y37V5NJMI5BOGPJDQBSNCVEGT3YTL5W4D4JYLEQMFUX32QTIDR65U3VVWZSIWBEG
#\\\|ZXXTOF5VSRB6FB7ANA7FADDJXGTBBAVOJMNGJPHBZRWONBWKE3Z \ / AMOS7 \ YOURUM ::
#\[7]S52V6GQRVBS24H3UPMJKWI7BSMAGDL45UO5HXOFZMSU6WZELDIDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
