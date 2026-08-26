## task: twin restart drain — cube backchannel + web.cmd.drain + restore on failure

### context

`v7.restart :twin: <zenka>` now works for handover but drain is slow:
- httpsd already has `httpsd.cmd.drain` — stops listen socket, polls sessions ✓
- web has no drain handler → 30s timeout always fires even when idle
- drain is sent as `<cube_sid>.drain` but there's no generic pause mechanism
- if the new twin fails startup, the old instance's routing is never paused
  (the cube backchannel pause hasn't been implemented yet)

the design: two-layer drain
1. **generic**: cube temporarily unsets `initialized` on old zenka's session →
   cube stops delivering new commands (same gating as pre-init) → zenka drains
   naturally → terminates or is force-killed by timeout
2. **specific**: `<cube_sid>.drain` still sent for zenki with explicit handlers
   (httpsd uses it to stop the listen socket, which is the right extra step)

restore: if the new twin fails startup, restore the old zenka's initialized state
so commands resume flowing — it should keep running normally.

---

### 1. cube.cmd.unset-initialized — new cube command

inverse of `cube.cmd.set-initialized`. sets `initialized` back to 0/false for
a zenka session, pausing cube command delivery (only replies pass through).

model on `cube.cmd.set-initialized` (src/cube.cmd.set-initialized):
- param: `<sid>` (session id of the zenka to pause)
- validate: session exists, is in 'zenka' auth mode, IS currently initialized
- set `$data{'session'}{$sid}{'initialized'} = 0`
- log: "[%s] zenka '%s' [uninitialized — drain mode]"
- return true

file to create: `src/cube.cmd.unset-initialized`

---

### 2. v7.zenka.cmd.drain-instance — add cube pause before drain signal

file: `src/v7.zenka.cmd.drain-instance`

currently sends `<cube_sid>.drain` and starts drain timeout timer.
add before the drain command send:

```perl
## generic cube-level pause: stop delivering new commands to old zenka
## [ same gating as pre-initialized state — zenka finishes in-flight work ]
if ( exists $instance->{'cube_sid'} ) {
    my $root_sid = <[base.determine_root_sid]>;
    <[base.net.send_command]>->(
        {   'target'  => $root_sid,
            'command' => sprintf( 'cube.unset-initialized %d',
                $instance->{'cube_sid'} )
        }
    );
}
```

look at how v7 sends cube commands in other modules (e.g.
`v7.callback.connect_to_cube` line 70 or `v7.handler.zenka_status` line 506)
to get the exact call pattern for sending to cube from v7.

---

### 3. web.cmd.drain — new module

file to create: `src/web.cmd.drain`

web is the application layer zenka (not the HTTP server). it handles cross-zenka
requests via route-send patterns. check for active in-flight routes:

```perl
my $active = scalar keys %{ $data{'web'}{'route'} // {} };
## also check: $data{'web'}{'pending'} or similar active-request tracking
```

if active == 0: terminate immediately via `<[base.exit]>` or equivalent
if active > 0: log count, set up a short poll timer (0.5s) to re-check
               using `event.add_timer` with handler `web.handler.drain_check`
               (create this handler too, same pattern as httpsd.handler.drain_check)

read `src/web.init_code` first to understand what data web tracks,
specifically look for anything that tracks active/pending requests or routes.
if web is effectively stateless between requests (no such tracking), just
terminate immediately — web doesn't hold long-lived connections.

---

### 4. v7.handler.zenka_status — restore initialized on twin failure

file: `src/v7.handler.zenka_status`

in the new-twin-instance failure path (around line 262, where `defined $old_instance_id`):
after the notify_online resolution and before the stop call, restore the old
instance's cube session initialized state:

```perl
## restore cube command delivery to old instance (was paused at drain initiation)
my $old_inst = <v7.zenka.instance>->{$old_instance_id};
if ( defined $old_inst and exists $old_inst->{'cube_sid'} ) {
    my $root_sid = <[base.determine_root_sid]>;
    <[base.net.send_command]>->(
        {   'target'  => $root_sid,
            'command' => sprintf( 'cube.set-initialized %d',
                $old_inst->{'cube_sid'} )
        }
    );
}
```

use the same cube command-sending pattern as step 2.

---

### key files to read first

- `src/cube.cmd.set-initialized` — model for unset-initialized
- `src/v7.zenka.cmd.drain-instance` — add cube pause here
- `src/httpsd.cmd.drain` — reference for web.cmd.drain pattern
- `src/httpsd.handler.drain_check` — reference for web.handler.drain_check
- `src/web.init_code` — understand web's active-request tracking
- `src/v7.handler.zenka_status` — twin failure path ~line 262

### signatures note

do not modify the 4-line checksum footer. module format: `## [:< ##` header,
no `sub {}` wrappers. `<[module.name]>->()` invocation; `<data.key>` for tree.
`$ARG` is loop variable; `@ARG` is args array. comments lowercase.

#,,,.,...,.,,,,,,,,..,...,,,,,..,,,..,,.,,,..,..,,...,...,.,.,.,,,,,,,,,,,,,,,
#6QAILU7YY62CB3USIXVTTIV6ZR6LUBBYZSAWCCUXZYZCLU3GCAP4FZUPHZPJF245NRAY72DU5WLRG
#\\\|H64BE723HGVXXP45TZQSQRQDDBHFPWSW5WCLDIYLUAAPPDRYKKV \ / AMOS7 \ YOURUM ::
#\[7]WE3N47DWNDC3TEBMVCPUYXPOJQ7CYUISN2CDZIUCWZTHI4XZQKAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
