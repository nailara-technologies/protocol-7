# child process lifecycle policy

## problem

zenki spawn child processes for external tools, servers, and hardware interfaces.
the current mechanism — `system.kill_list` — is a blunt instrument: every
registered PID gets killed when the zenka exits. this forces a choice between
two bad options:

- register child → child always dies with zenka (even on restart)
- don't register → child becomes an orphan with no cleanup path

some children should survive zenka restarts (X server, inference servers).
some should not (GPU monitors, temporary encoders). currently there is no way
to express this distinction.

---

## child categories

### disposable

default behavior. child is registered on `system.kill_list`. killed when zenka
exits for any reason. no reconnect path.

```
use when: child has no independent value beyond the zenka's current session.
examples: intel_gpu_top, temporary ffmpeg encoder, scrot capture process.
```

### decoupled

child outlives zenka restarts. the zenka holds a reconnect path (unix socket,
PID file) to reattach after restart. v7 knows the child exists but does not
manage it — the zenka is responsible for reattachment.

```
use when: child state is valuable and restart would disrupt users or lose work.
examples: Xorg/Xvfb/Xephyr server, llama-server inference backend.
v7 override: can terminate via explicit command if full teardown needed.
```

### monitored

child outlives zenka restarts. v7 tracks the child PID independently and can
terminate it via command. used when v7 needs direct lifecycle control over the
child separate from the zenka.

```
use when: child is a long-running service that v7 should be able to stop/restart
          independently of its parent zenka.
examples: (future) dedicated GPU service process, shared media transcoder.
```

---

## registration API

### disposable (current behavior, unchanged)

```perl
push @{<system.kill_list>}, $child_pid;
```

### decoupled

```perl
<[base.child.register_decoupled]>->({
    'pid'     => $child_pid,
    'name'    => 'xorg-server',         ## human-readable label
    'socket'  => $wrapper_socket_path,  ## reconnect path (optional)
    'pidfile' => $pidfile_path,         ## alternative reconnect path
});
```

stores in `<{zenka}.child.decoupled>` hash. does NOT add to kill_list.
extends existing `v7.zenka.cmd.register_child` with a `category` parameter —
v7 already tracks child PIDs via `register_child` / `gone_child` pair;
decoupled simply means v7 skips the kill on restart for that child.

### monitored (future)

```perl
<[base.child.register_monitored]>->({
    'pid'     => $child_pid,
    'name'    => 'shared-gpu-service',
    'socket'  => $management_socket,
});
```

v7 takes ownership — can terminate via `v7.terminate_child <label>`.

---

## v7 coordination

### child inventory

v7 maintains a per-zenka child inventory in instance data:
```
<v7.zenka.instance>->{$id}->{'children'} = {
    'xorg-server' => { pid => N, category => 'decoupled', socket => ... },
    'gpu-monitor'  => { pid => N, category => 'disposable' },
}
```

populated via `v7.register_child <pid> [category]` — existing command extended
with optional category param. `gone_child <pid>` is the deregister counterpart.
both already exist in `modules/v7.zenka.cmd.*`; category param is the only addition.

### on zenka restart

- `disposable` children: kill_list cleanup as before
- `decoupled` children: do NOT kill. zenka reconnects on next startup.
  v7 flags them as "orphaned pending reconnect" until zenka comes back online.
- `monitored` children: v7 decides based on restart reason and config.

### full teardown

`v7.teardown` terminates all children regardless of category.
override: `v7.terminate_decoupled yes` for staged shutdown.

### orphan detection

on startup, zenka checks for existing decoupled children via socket/pidfile.
if found alive → reconnect. if found dead → clean up pidfile, start fresh.
v7 clears "orphaned pending reconnect" flag when zenka comes back online.

---

## configuration

per-zenka in `zenka-startup.v7`:

```
## child process lifecycle
child.decoupled.reconnect = yes    ## attempt reconnect on restart (default yes)
child.decoupled.timeout   = 30     ## seconds to wait for reconnect before giving up
child.kill_on_teardown    = yes    ## kill decoupled children on full teardown
```

---

## migration path

1. existing `system.kill_list` usage: unchanged, no migration needed
2. zenki with children that should survive restart: adopt `base.child.register_decoupled`
3. new zenki: use the appropriate category from the start

first implementation: X-11 zenka wrapper process (Xorg/Xvfb/Xephyr).
see `X11-RELIABILITY-AND-WINDOW-REGISTRY.md` for the reference implementation.

---

## open items

- `v7.register_child` already exists with `gone_child` counterpart — extend with
  optional `category` param (disposable default, decoupled opt-in)
  auto-discovers parent instance from ppid — no source alias needed
- monitored category: defer until a concrete use case drives it
- `v7.teardown` access control: restrict to `system` zenka only
  (currently `access.cmd.usr.cube = *` — any zenka can trigger full shutdown)

#,,..,..,,,,.,..,,,.,,,..,,..,,,.,,.,,...,,,.,..,,...,...,...,.,.,..,,.,.,..,,
#7YXL5NASE2JOKN74CMP6DTB2XHDOU2667HWH7NGWUV3JNKQEXK4OHUM2WJDW2EPGXWXT367KGIIXY
#\\\|ZBXWH4RZKPYIYDEPOB6C6JWNIMHFGOHL22SQKLYVSZDQ5E43A4G \ / AMOS7 \ YOURUM ::
#\[7]XBYZCEUH4WAHFG42WU6O4Y7E66VBKO373NKXGFLYVSPOAZCABCDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
