## task: on-demand heartbeat idle-term — let heartbeat-enabled zenki idle-timeout cleanly

### context

on-demand zenki conventionally set `heartbeat.disabled = 1` + `restart.disabled = 1`
alongside `start.on-demand = 1` and `[base.zenki.set_ondemand_timeout:N]`, so v7 neither
monitors nor restarts them, and they self-terminate after idle via a bare `exit(0)` in
`base.handler.ondemand_timeout`.

that convention is a trade-off: without heartbeat, a blocking/crashed on-demand zenka
goes undetected until the next command attempt (which may never come). the `tile` zenka
was set up as a test case for the opposite trade-off — heartbeat left enabled, no idle
timeout configured — because it holds live window-group/layout state used by many
always-on desktop zenki and losing crash detection wasn't worth idle-timeout savings.
see `data/ai-mem/claude/topic-ondemand-heartbeat-upgrade.md` and
`data/md/design/ZENKA-LIFECYCLE-ONDEMAND-HEARTBEAT.md` (hybrid-mode section) for the
fuller design context this task deliberately narrows down from — do not implement the
"configurable timeout modes" / forensic / recovery-mode sections of that design doc here,
they're separate follow-up work.

this task closes the specific gap: let an on-demand zenka keep heartbeat monitoring
enabled *and* still have a working idle timeout, by (1) excluding heartbeat traffic from
resetting the idle timer, and (2) giving the zenka a clean way to tell v7 "I'm going idle
on purpose" before it exits, so v7 never treats it as a crash needing a restart.

### two parts, in dependency order

**part 1 must land first.** without it there is no heartbeat-enabled + idle-timeout zenka
to exercise part 2 against — the idle timer literally cannot expire while heartbeat is on
(see below), so `v7.idle-term` would be correct code nothing can ever reach.

---

### part 1 — exclude heartbeat traffic from resetting the on-demand idle timer

**the problem, exactly:** `v7.handler.heartbeat_timer` sends a `heart` command to the
monitored zenka roughly every ~5.7s (`heartbeat.interval` default, see
`src/v7.enable_heartbeat_timer`). on the zenka side, `src/base.handler.command:116-121`
unconditionally cancels `<base.timer.ondemand_timeout>` on *every* incoming command —
including `heart` — before the command has even been parsed:

```perl
# cancel ondemand timeout [ reinstalled in idle watcher ]
if ( defined <base.timer.ondemand_timeout> ) {
    <base.timer.ondemand_timeout>->cancel
        if <base.timer.ondemand_timeout>->is_active;
    delete <base.timer.ondemand_timeout>;
}
```

`src/base.event.callback.io-idle-restart:34-53` then re-arms the timer for the *full*
`<system.ondemand_timeout>` duration once the zenka goes io-idle again. with heartbeat
every ~5.7s and any real idle timeout being much longer, the timer never survives long
enough to fire.

**the fix — do not restructure the cancel above.** `base.handler.command` has early
returns between that cancel and where the command name becomes known further down, so
moving the cancel past command-parsing is real ordering surgery in a hot path. instead:

1. after the command has been parsed and its name is known (further down in
   `base.handler.command`, wherever `$call_args`/command name is settled), record
   `<base.ondemand.last_activity> = <[base.ntime]>` — but skip that update when the
   parsed command is `heart` (the same command name used in `src/base.cmd.heart`).
2. in `src/base.event.callback.io-idle-restart`, when arming
   `<base.timer.ondemand_timeout>`, use the remaining time since last real activity
   instead of always the full window:
   `after => <system.ondemand_timeout> - (<[base.ntime]> - <base.ondemand.last_activity>)`,
   clamped to a sane minimum (e.g. don't arm a negative/zero-or-below delay — fire almost
   immediately instead, or just let the existing full-timeout path apply on very first
   idle when `<base.ondemand.last_activity>` is still unset).
3. `<base.ondemand.last_activity>` should default to zenka-start time so the very first
   idle window after startup isn't artificially shortened.

verify: a zenka with `start.on-demand = 1`, `start.on-demand.timeout` set to something
short for testing (e.g. 10s), and heartbeat left enabled (no `heartbeat.disabled`) should
now actually hit `base.handler.ondemand_timeout` and exit after the configured timeout
even while heartbeat keeps responding — instead of never timing out.

### part 2 — `v7.idle-term`: pre-exit termination notice, wired through cube

**goal:** an on-demand zenka that's about to self-terminate from idle asks v7 to stop
tracking/heartbeating it and terminate it cleanly, instead of just calling `exit(0)`
directly and hoping v7's post-hoc status logic sorts it out.

**template to clone almost verbatim:** `src/v7.zenka.cmd.restart_own-zenka`. it already
solves "resolve the calling zenka's own instance from an injected sid" — same problem
`v7.idle-term` has:

```perl
my ( $zenka, $zenka_sid ) = split( m| |, $call->{'args'}, 3 );
# ... validate $zenka_sid is numeric (cube-injected) ...
my $instance_id;
foreach my $id (<[v7.instance_ids]>) {
    my $instance = <v7.zenka.instance>->{$id};
    $instance_id = $id
        and last
        if exists $instance->{'cube_sid'}
        and defined $instance->{'cube_sid'}
        and $instance->{'cube_sid'} == $zenka_sid;
}
# ... reject if not found ...
```

**new module: `src/v7.zenka.cmd.idle-term`** (or `v7.cmd.idle-term`, match whichever
naming `restart_own-zenka` actually uses for its `[load_modules]` — check
`cfg/zenki/v7/zenka.v7` for how these command modules get loaded/aliased), following that
same resolution pattern, then:

1. reject (return `{ mode => false, ... }`) if the resolved instance isn't configured
   on-demand (`start.on-demand` — check how this is stored per-instance/zenka_config,
   probably under `<v7.start_setup.zenki.config>->{$zenka_name}` or similar — grep
   `on-demand` in `src/v7.*` and `src/base.zenki.set_ondemand_timeout` callers for the
   actual config path). don't let an always-on zenka self-idle-term by mistake.
2. call `<[zenka.instance.stop]>->($instance_id)` (i.e. `src/v7.zenka.instance.stop`).
   return `{ mode => true, ... }`.

**why step 2 alone is already race-proof — do not add anything extra for this:**
`v7.zenka.instance.stop` sets `<zenka.instance.shutdown>->{$instance_id}` as its very
first action and calls `v7.cancel_instance_timers`, which synchronously cancels the
`heartbeat-timeout`/`heartbeat-status` `Event::timer` objects before the process is even
killed. even if something downstream still calls `v7.zenka.change_status` with some other
status for this instance, `v7.handler.zenka_status` has an unconditional override near
its end:

```perl
if ( $status eq qw| shutdown |
    or exists <zenka.instance.shutdown>->{$instance_id} ) {
    $status = qw| shutdown | if $status ne qw| shutdown |;
    ...
    delete <v7.zenka.instance>->{$instance_id};
    delete <zenka.instance.shutdown>->{$instance_id};
```

— once the shutdown flag is set, the eventual status is forced to `shutdown` no matter
what was computed, and `v7.init_restart_timer` never gets a chance to fire. this is
`src/v7.zenka.change_status` (thin wrapper) → `src/v7.handler.zenka_status` (the actual
gate). a sentinel/special exit-code scheme was considered as an alternative and rejected —
it would only inform v7 *after* the process has died, whereas this flag is set *before*,
which is strictly better and needs no new exit-code convention.

**cube wiring:** add `v7.idle-term` to `setup.aliases.source_zenka_sid` in
`cfg/zenki/cube/command_aliases`, right alongside the existing `v7.restart_own-zenka`
entry — this is what makes cube inject the caller's zenka name + numeric sid into
`$call->{'args'}` the same way it does for `restart_own-zenka`.

**zenka-side caller:** `src/base.handler.ondemand_timeout` currently does:

```perl
<[base.log]>->( 1, "zenka idle shutdown.., [ $timeout sec$s ]" );
exit(0);
```

change this to call `v7.idle-term` first (send via whatever this codebase's standard
zenka→v7 route-send call looks like — see how other zenki call v7 commands on themselves,
e.g. how `v7.zenka.cmd.restart_own-zenka` is invoked *from* a zenka, not v7's side of it),
and only fall through to the existing `exit(0)` if the reply is `false` **or no reply
arrives within a short guard timeout** (a few seconds) — don't just gate on an explicit
false reply, since a lost message or busy cube must not leave the zenka sitting alive
forever waiting to be killed.

### key files (read these, don't re-derive)

- `src/base.handler.command:116-121` — unconditional ondemand-timeout cancel on every
  incoming command (part 1 target)
- `src/base.event.callback.io-idle-restart:34-53` — where the timeout timer gets
  (re)armed
- `src/base.handler.ondemand_timeout` — current self-exit handler (bare `exit(0)`)
- `src/base.zenki.set_ondemand_timeout` — sets `<system.ondemand_timeout>`
- `src/base.cmd.heart` — the heartbeat probe command, name to match against in part 1
- `src/v7.handler.heartbeat_timer` — sends `heart` every `heartbeat.interval` (~5.7s
  default)
- `src/v7.zenka.cmd.restart_own-zenka` — clone this pattern for sid→instance resolution
- `src/v7.zenka.instance.stop` — sets `<zenka.instance.shutdown>`, cancels timers,
  terminates the process
- `src/v7.cancel_instance_timers` — cancels all active `Event::timer`s on an instance
  (heartbeat included)
- `src/v7.zenka.change_status` + `src/v7.handler.zenka_status` — the shutdown-flag
  override gate that makes this race-proof; also where `v7.init_restart_timer` would
  otherwise get triggered
- `src/v7.process_zenka_end:78-106,128` — normal (non-idle-term) exit-status logic,
  useful for contrast but not to be modified by this task
- `cfg/zenki/cube/command_aliases` — add `v7.idle-term` to
  `setup.aliases.source_zenka_sid`

### explicitly out of scope

- the "configurable timeout modes" (forensic-first / recovery-first / observe /
  notify-only / cascade) from `ZENKA-LIFECYCLE-ONDEMAND-HEARTBEAT.md` — future work
- wake permissions / network priority levels from the same design doc — unrelated
- a sentinel exit-code mechanism — considered, rejected, see part 2 above
- changing `v7.process_zenka_end`'s status logic — not needed, the shutdown flag already
  overrides it

### done when

- a heartbeat-enabled, idle-timeout-configured on-demand zenka (e.g. a test zenka
  modeled on `tile`'s config but with a short `start.on-demand.timeout` added) actually
  times out and exits while heartbeat keeps responding throughout.
- on exit, v7 does not attempt a restart (check logs / `list zenki` status transitions —
  should land on `shutdown`/`offline`, never `error` → restart).
- killing cube (or otherwise making the `v7.idle-term` round-trip fail/never reply)
  still results in the zenka exiting on its own within a bounded time, not hanging alive
  indefinitely.

#,,,.,..,,.,.,,..,,,,,...,..,,,..,,,,,..,,,,.,..,,...,.,.,,,.,,,.,,.,,...,..,,
#Y3CHEJLWGKJPIEVGH2P2LWZDZ7HOP2QPCWGHWWSK3KP7Y6VFNKDGZF26GVXABIYR3ZME35FPMATOK
#\\\|MMBQEK7QITSXDNIKTCRFWCWSXTHI4MW2RNYBR4U5DIX5LBJV6GM \ / AMOS7 \ YOURUM ::
#\[7]XOCWLDQWPJNO6SSTGYOQYT5DBYMNIYHS3TWOEHKFXRXRE4Z3HSAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
