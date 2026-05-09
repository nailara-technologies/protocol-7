# coding-state-machine-namespace — reactive state with variable watchers

**Priority:** High
**Type:** Refactor + Infrastructure
**Component:** coding zenka async infrastructure

## Overview

Replace polling-timer-based coordination (backend_busy_retry, deferred reply
loops) with a proper reactive state machine rooted at `<coding.state>`. Tasks
register AnyEvent variable watchers on state keys and wake exactly once when
state changes — no polling, no stacked timers.

## Namespace Design

```
coding.state.backend.gpu.lock        → task_id holding lock | undef
coding.state.backend.gpu.queue       → [ task_ids waiting in order ]
coding.state.backend.cpu.lock        → task_id holding lock | undef
coding.state.backend.cpu.queue       → [ task_ids waiting in order ]
coding.state.task.<id>.status        → pending|streaming|waiting|complete|failed
coding.state.task.<id>.subtask_ids   → [ child task_ids ]
coding.state.task.<id>.result        → final result string when complete
```

## Lifecycle

### coding.pre_init
```perl
<coding.state> //= {};
<coding.state.backend> //= { gpu => {}, cpu => {} };
<coding.state.task>    //= {};
```

### coding.init_code
Restore from zenka_dir if snapshot exists:
```perl
my $snap = <[file.zenka_dir.load]>->('coding-state.yaml');
if ( defined $snap ) {
    my $data = <[format.yaml.load_str]>->( $snap->$* );
    <coding.state> = $data if ref $data eq 'HASH';
}
## re-register watchers for any tasks that were in-progress ##
```

### coding.end_code
```perl
<[format.yaml.pre_init]>;
my $yaml = <[format.yaml.dump_str]>->( <coding.state> );
utf8::encode($yaml);
<[file.zenka_dir.write]>->( 'coding-state.yaml', \$yaml );
```

## Backend Lock — Replace Polling Timer

### Current (polling)
```perl
## 0.7s retry timer fires repeatedly until lock clears ##
<[event.add_timer]>->({ after => 0.7, handler => 'coding.callback.backend_busy_retry' });
```

### New (watcher)
```perl
## register watcher on lock key — fires once when lock clears ##
<[event.var_watcher]>->(
    \<coding.state.backend.gpu.lock>,
    sub {
        return if defined <coding.state.backend.gpu.lock>;  ## still locked ##
        <[coding.async.backend_acquire]>->($task_id);       ## try to acquire ##
    }
);
## add task_id to queue so release knows who to wake ##
push @{ <coding.state.backend.gpu.queue> }, $task_id;
```

### Release (wake next waiter)
```perl
<coding.state.backend.gpu.lock> = undef;  ## watcher fires automatically ##
```

## Task Status — Replace Deferred Reply Polling

`task.wait-done` registers a watcher on `<coding.state.task.$id.status>` instead
of polling via timer. Fires once when status becomes `complete` or `failed`.

## Timers Remaining (legitimate)

- `inference_timeout` — kill hung inference server after N seconds
- `task_stale_cleanup` — remove completed task state after TTL
- `task_buffer_save` / `task_buffer_drop` — 47m/63m periodic persistence
- `backend_monitor` startup readiness poll (short-lived, already correct)

## Implementation Order

1. Add `<coding.state>` bootstrap to `coding.pre_init`
2. Add persist/restore to `coding.init_code` / `coding.end_code`
3. Replace `coding.async.request` backend_busy polling with watcher + queue
4. Replace `coding.callback.backend_busy_retry` with `coding.async.backend_acquire`
5. Replace `task.wait-done` deferred polling with status watcher
6. Remove `coding.callback.backend_busy_retry` once replaced

## Notes

- signatures_note: leave signing to the system, no stub lines
- `event.var_watcher` may need verification — check base.event.* for the
  correct call signature before implementing
- watchers do not need persisting — re-registered when tasks resume after restart
- only state values survive restart, watcher callbacks are ephemeral
- the `<coding.state>` tree can later be written via zenka_dir routines and
  reloaded on startup — same pattern as valued tree persist/restore

#,,,,,..,,,..,.,.,,,,,...,,,,,,.,,,.,,...,.,.,..,,...,...,.,.,.,,,,,.,,,,,.,.,
#ADTDFGXPVYQQTEQV6YK4TFZFIXJV44WIQHJAKTHKFQX27X7QT5EQGMMSFF3R2ERX7XV2MDIOLYEWK
#\\\|TRSF7VYVLTN3YSHHM32DW5PLES3EMQRXYSVZLKW26ZHPBRELXFO \ / AMOS7 \ YOURUM ::
#\[7]P3GNDOLQL5726RPQ6RK32QGNT25ONDVGCC2UFLAC2YCRGNXXRQCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
