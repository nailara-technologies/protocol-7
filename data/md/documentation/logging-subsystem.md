# logging subsystem

## usage — entry points

three entry points for emitting log output, covering all normal cases:

### `base.log` — plain string

```perl
<[base.log]>->( $log_level, $message );
<[base.log]>->( $message );                          ## level defaults to 1 ##
<[base.log]>->( $log_level, $message, $buffer );     ## named buffer ##
<[base.log]>->( $log_level, $message, $buffer, $timestamp );  ## explicit timestamp ##
```

`log_level` is optional — if the first argument is a single digit it is treated
as the level; otherwise level 1 is assumed. level 0 = error (always visible),
level 1 = default, level 2 = info, level 3+ = debug.

`log_buffer` is an optional buffer name (default: `'zenka'`, formerly `'system'`).
selects which in-memory buffer the entry is added to.

`time_stamp` is optional — defaults to current network time when not specified.

message is passed as a plain string — no format interpolation. control
characters (`\n`, `\r`, `\0`, `\e`) are escaped before output.

### `base.logs` — sprintf format string

```perl
<[base.logs]>->( $log_level, $format, @args );
<[base.logs]>->( $format, @args );      ## level defaults to 1 ##
```

thin wrapper around `base.log`: runs `sprintf( $format, @args )` then
delegates to `base.log`. warns on undef parameters. level follows same
convention as `base.log`.

### `base.logt` — template-indexed message

```perl
<[base.logt]>->( $log_level, $template_id, @params );
<[base.logt]>->( $template_id, @params );   ## level defaults to 1 ##
```

looks up `$template_id` (a 7-char AMOS checksum) in
`protocol.protocol-7.message-templates`, formats with `@params` via
`base.sprint_t`, then delegates to `base.log`. the checksum is derived from
the template string itself — changing the string invalidates the id, making
call sites self-verifying. used exclusively for protocol-layer messages in
`base.handler.command`. template strings have `\n` for wire output; log output
strips the newline via `base.sprint_t`.

### `base.sprint_t` — template-indexed string (no log output)

```perl
my $str = <[base.sprint_t]>->( $template_id, @params );
```

same template lookup as `base.logt` but returns the formatted string instead
of emitting it. used when the result needs to go to the network rather than
the log (see `weather.base.calc_zoom_level` for an example).

---

## early startup — core subs

before `base.log` is fully loaded and the log chain is ready
(`log.base_log_complete` returns true), logging is handled by core subs
defined as `p7__log__*` functions in `bin/Protocol-7` and installed into
`%code` as `log.*` via `p7_import_main_subroutines`. each has a two-phase
implementation: direct console output + early-buffer accumulation before
the chain is ready, then delegation to `base.log` after.

| core sub      | maps to       | level | purpose                              |
|---------------|---------------|-------|--------------------------------------|
| `log.noerr`   | `p7__log__noerr`  | 1 | normal startup messages, plain string |
| `log.error`   | `p7__log__error`  | 0 | error messages, always visible        |
| `log.devmod`  | `p7__log__devmod` | 2 | developer/verbose output              |

`log.noerr` also serves as the fallback installed at `base.log` before the
real module loads — the guard `$code{'base.log'} eq $code{'log.noerr'}` detects
this condition and sets emergency verbosity levels.

### planned: `log.string` and `log.fmt`

`log.noerr`, `log.error`, and `log.devmod` are fixed-level wrappers. two
general-purpose wrappers are planned to replace `base.log` and `base.logs`
respectively:

- `log.string` — plain string, level parameter, delegates to `base.log`
- `log.fmt` — sprintf format + args, level parameter, delegates to `base.logs`

both will be implemented as `p7__log__string` / `p7__log__fmt` core subs in
`bin/Protocol-7`, following the same two-phase early/late pattern. this
enables gradual transition without a flag-day rename. see task file:
`data/yaml/coding-tasks/log-namespace-wrappers.yaml`.

---

## internal modules (for tracing and debugging)

the following modules form the internal pipeline. they are not called
directly in normal usage — `base.log` dispatches to them.

| module | role |
|--------|------|
| `base.log.format_entry` | formats the final output string: prefix + level-to-color mapping |
| `base.log-delayed` | deferred log emission for messages that arrive before the buffer is ready |
| `base.log.auto_decay_check` | stub — initializes `log.level.auto-decay.zenka` and `system.timers.loglevel_auto_decay` data paths; intended for wave-based decay of higher log levels in ring buffers, keeping level 0/1 entries longer than level 2/3; planned upgrade: reverse template processing, LLM-assisted compaction rule generation, automated summaries, repetitive pattern grouping |
| `base.log.next_buffer_tstamp` | timestamp sequencing for the send buffer |
| `base.log.send-buffer.init` | initializes the async send buffer |
| `base.log.send-buffer.add-queue` | enqueues a formatted log entry for forwarding |
| `base.log.send-buffer.send-idle-callback` | flushes the queue during event loop idle |
| `base.log.send-buffer.idle-callback-set` | registers the idle flush callback |
| `base.log.send-buffer.idle-callback-clear` | deregisters the idle flush callback |
| `base.log.send-buffer.reply-handler.notify-online` | handles p7-log zenka coming online |
| `base.log.send-buffer.reply-handler.send-reply` | handles send confirmations from p7-log |

the send-buffer pipeline provides async forwarding of log entries to the
`p7-log` zenka (the network log sink). entries are queued locally and flushed
during event loop idle time, so logging never blocks the main event loop.

---

## verbosity levels

three independent verbosity thresholds are checked per entry:

| key | default | controls |
|-----|---------|----------|
| `system.zenka.verbosity.console` | 0 | what appears on stdout |
| `system.zenka.verbosity.buffer` | 1 | what is kept in the in-memory zenka buffer |
| `system.zenka.verbosity.logfile` | 0 | what is forwarded via the send-buffer to p7-log (which writes to disk) |

no zenka writes log files directly to disk — disk logging is exclusively
handled by the `p7-log` zenka receiving forwarded entries via the send-buffer
pipeline. `buffer` and `logfile` thresholds can overlap depending
on configured levels.

an entry is suppressed entirely only if its level exceeds all three thresholds.

harmony calculation (for log timestamps) is skipped at level > 1 or when
`system.zenka.verbosity.logfile > 1`, reducing calculation load for
high-frequency debug output.

#,,,.,.,.,.,.,,,.,,.,,,,,,,..,,,.,.,,,,,.,,,.,..,,...,...,,.,,.,,,.,,,,,.,,,,,
#5VQPXTIRLB7V6PMQTEDA3ICE5OUZNNVBISPVASKFF37HJQKNXL4N4DC66RXQLOKJ6QQSO3JJUIZUY
#\\\|LRICOC6QAFHFL4GZALIUUWVALV37CM3BYXJ42TOWFF57WOZXCLW \ / AMOS7 \ YOURUM ::
#\[7]NPLUOTIEDW3OPB5Y45QI2BK37HDWGNECPAO3K6HMGRIJRJN4Z4AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
