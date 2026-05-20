# X-11 zenka: reliability and window registry

## overview

three related upgrades to the X-11 zenka, in dependency order:

1. **protocol reconnect** — transient X11 errors trigger reconnect with
   exponential backoff instead of immediate zenka exit
2. **wrapper process** — X server decoupled from zenka lifecycle using the
   `decoupled` child category (see `CHILD-PROCESS-LIFECYCLE-POLICY.md`)
3. **window registry + STRM subscription** — self-registered window inventory
   with stream-based lifecycle events replacing the polling `wait_visible` model

each layer builds on the previous. reconnect reduces restart frequency. wrapper
means restarts don't disrupt the X server. window registry means restarts don't
disrupt window management either.

---

## 1. protocol reconnect with exponential backoff

### current state

`modules/X-11.post_init` lines 135-148 registers a custom error handler:
```perl
<X-11.obj>->{'error_handler'} = sub {
    ...
    ## reconnect here, if not successful call: ## [ LLL ]
    #  <[X-11.error_handler]>->($err_str);
};
```

the reconnect was planned, marked LLL, commented out. on protocol error the
handler logs and returns — the next X11 call will then die, causing zenka exit.

`modules/X-11.connect_X11` already retries indefinitely on *initial* connection.
the reconnect logic needs to be extracted and reused from the error handler.

### implementation

**new module: `X-11.reconnect`**

```
- extract retry loop from X-11.connect_X11 into X-11.reconnect
- X-11.reconnect: attempts display reconnect with exponential backoff
  delays: 1s → 2s → 4s → 8s → 16s → 32s → give up after max_attempts
- on give up: calls <[base.exit]> cleanly (allows v7 to restart)
- on success: re-initialises display state (RANDR, DPMS, compositing check)
              re-registers background image
              emits 'reconnected' to window stream subscribers
```

**modify `X-11.post_init` error handler:**
```perl
<X-11.obj>->{'error_handler'} = sub {
    my $err_str = shift;
    <[base.log]>->( 0, "x11 protocol error: $err_str" );
    <[X-11.reconnect]>;    ## was: LLL comment
};
```

**configuration:**
```
X-11.reconnect.enabled       = yes
X-11.reconnect.max_attempts  = 7
X-11.reconnect.initial_delay = 1
X-11.reconnect.max_delay     = 60
```

---

## 2. wrapper process (decoupled X server)

### problem

when X-11 zenka exits (even after exhausting reconnect attempts), the X server
process dies with it — it's a child in the current process model. all X11
applications lose their display. this is disruptive on interactive hosts where
users have running applications and unsaved state.

### wrapper design

a minimal wrapper process (`bin/x11-wrapper` or compiled C stub) owns the X
server as its child. the X-11 zenka communicates with the wrapper via unix
socket.

```
┌──────────────────────────────────┐
│  x11-wrapper [PID: W]           │
│  - owns X server as child       │
│  - unix socket for zenka cmds   │
│  - commands: status / pid / quit │
│                                  │
│  ┌──────────────────────────┐   │
│  │  Xorg/Xephyr/Xvfb [P]  │   │
│  │  (survives zenka restart)│   │
│  └──────────────────────────┘   │
└──────────────────────────────────┘
        ↕ unix socket
┌──────────────────────────────────┐
│  X-11 zenka                     │
│  - connects to wrapper on start │
│  - reconnects after restart     │
└──────────────────────────────────┘
```

### zenka startup flow (wrapper mode)

```
1. check wrapper socket: /var/run/.7/X-11-wrapper-<mode>.sock
2. if socket exists and wrapper alive:
      get X server PID from wrapper
      connect to existing display (skip server start)
      register as decoupled child (see CHILD-PROCESS-LIFECYCLE-POLICY.md)
3. if socket absent or wrapper dead:
      start wrapper process
      wrapper starts X server
      zenka connects to display
      register wrapper PID as decoupled child
```

### v7 coordination

wrapper PID reported to v7 via `v7.report-child` as `decoupled` category.
v7 does not kill wrapper on zenka restart.
v7 can terminate wrapper explicitly: `v7.terminate_child X-11-wrapper`.

### configuration

```
X-11.xserver.wrapper.enabled  = no     ## off by default — opt-in
X-11.xserver.wrapper.socket   = /var/run/.7/X-11-wrapper.sock
X-11.xserver.wrapper.recover  = yes    ## reconnect to existing server on restart
X-11.xserver.wrapper.bin      = /usr/local/lib/p7/x11-wrapper
```

when `wrapper.enabled = no`: current behavior unchanged — X server is direct
child of zenka, killed when zenka exits.

---

## 3. window registry and STRM subscription

### problem

`X-11.cmd.wait_visible` polls the X server window tree to detect when a window
appears. on WSL/Wayland in host mode, window enumeration returns empty — all
callers block for the full timeout (default 7 seconds) on every startup.

tile-groups has no reliable notification when windows appear or disappear. it
queries on demand, which races against startup order.

### push model

zenki self-report their windows to X-11 at the moment of creation (in-process,
zero latency, no X server roundtrip needed). X-11 maintains a registry and
pushes lifecycle events to subscribers over a STRM stream.

### self-registration

**cube command_aliases addition:**
```
# configuration/zenki/cube/command_aliases
setup.aliases.source_zenka_sid = ... X-11.register_window X-11.unregister_window
```

cube injects calling zenka's name + SID into every `register_window` call.
the registry is cube-authenticated — zenki cannot register under false identity.

**zenka side — `base.gtk.register_window`:**
```perl
$window->signal_connect('map-event' => sub {
    my $xid   = $window->get_window->get_xid;
    my $title = $window->get_title // <system.zenka.name>;
    <[base.X-11.report_window]>->( $xid, $title );
    return FALSE;
});
```

`base.X-11.report_window` sends `X-11.register_window <xid> <title>` — cube
injects zenka name and SID from session context.

**X-11 registry:**
```perl
<X-11.window_registry>->{$sid} = {
    xid    => $xid,
    name   => $zenka_name,   ## injected by cube
    title  => $title,
    time   => <[base.time]>->(3),
};
```

then: `XSelectInput($display, $xid, StructureNotifyMask)` to watch for
`DestroyNotify` as a secondary signal for external-process windows.

### window disappearance

**primary path — v7 lifecycle:**
`v7.handler.zenka_status` on `offline` transition sends:
```perl
<[base.protocol-7.command.send.local]>->(
    'X-11', "X-11.unregister_window $dying_session_id\n"
);
```
X-11 looks up registry by SID, emits `window.gone` on stream, evicts entry.

**secondary path — `DestroyNotify`:**
XLib event fires when window is destroyed (external processes, crashes).
catches cases where v7 is not involved (external mpv process, SDL window).

**self-unregister:**
`X-11.unregister_window` also in `source_zenka_sid` — a zenka can clean up
its own registration on graceful exit, SID injected by cube.

### STRM subscription

**new command: `X-11.cmd.window-stream`:**
```
p7c X-11.cmd.window-stream [regex-filter]
```

opens unbounded STRM (no total — `STRM open\n`). X-11:
1. sends current registry as initial burst of `window.appeared` packets
2. pushes event packets as registry changes

**event packet format:**
```
window.appeared  <xid>  <zenka-name>  [<subname>]  <title>
window.gone      <xid>  <zenka-name>  [<subname>]
window.moved     <xid>  <x>  <y>  <width>  <height>
window.renamed   <xid>  <new-title>
```

stream persists over cube session — no timeout, stable as long as both zenki run.

**tile-groups side:**
opens stream on startup with filter for its managed zenki.
`tile-groups.handler.window_stream` receives packets, updates state table,
triggers placement via existing coordinate assignment.

### wait_visible replacement

`X-11.cmd.wait_visible` checks registry first (immediate return if registered).
falls through to timer-based poll only for external-process windows not in
registry. capability flag `<X-11.window_enumeration>` skips poll loop on WSL.

zenki that need to wait for a specific window can open a filtered stream and
act on the first `window.appeared` packet — event-driven, no blocking.

---

## implementation order

1. **protocol reconnect** — isolated, no dependencies, high immediate value
2. **window registry + stream** — unlocks tile-groups and wait_visible fixes
3. **wrapper process** — most complex, builds on reconnect + child policy

each is independently deployable. start with reconnect, ship, then registry,
then wrapper.

---

## related documents

- `CHILD-PROCESS-LIFECYCLE-POLICY.md` — disposable/decoupled/monitored model
- `ZENKA-WINDOW-PLACEMENT-PROFILES.md` (task) — uses window registry for placement
- `X11-WAIT-VISIBLE-HOST-MODE-SKIP.md` (task) — superseded by window registry
  (keep as fallback for external-process windows not using self-registration)

#,,..,...,,,,,.,.,,,,,.,.,.,.,,.,,,.,,...,,..,..,,...,...,,..,.,,,.,,,...,.,,,
#5XYPE7WXEL5NRPWQAU4WCFMFUW5FJEYIQJBIAGZ3SQPQSF6YICKGQN2L3QJXWJEBDCB476S26D7LE
#\\\|FJFNLVBMPWMFXMDLCZ3JDFZNJY2HPA7KU275E633NYCD5VLDFJN \ / AMOS7 \ YOURUM ::
#\[7]IIW3AQ6SYFSNBBL3MAMVXVVCMVVEPP4Y73252RBMLHMWODKIRCBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
