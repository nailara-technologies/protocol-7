---
name: x11-protocol-hardening
description: WSLg/Weston full-freeze recurrence + blocking-call hardening for the X-11 zenka (base.exec.with_timeout COMMITTED 3b966708d; dual-connection pool w/ query-reroute + health-oracle ping COMMITTED e0f4fddd7, verified live after restart)
metadata:
  node_type: memory
  type: project
  originSessionId: cdffd7ae-0b7d-4332-8d33-703592bd60a1
---

## WSLg/Weston full-freeze — second occurrence 2026-07-10

Same failure class as the [[topic-gtk-wsl-window-positioning]] investigation's
"windows invisible" incident (fixed only by a full WSLg host reboot, via
`wsl --shutdown` from Windows) — now seen in a second, related shape:

**Signature**: a zenka's window opens but stops visually repainting, while
the zenka process itself stays fully responsive to protocol-7 network
commands (`X-11.heart`/`protocol-7-menu.heart` both replied in <1ms). But
any command touching the *X11 protocol connection itself* (`X-11.get-windows`
→ `X-11.WM.update`, which does synchronous `X11::Protocol` round-trips:
`GetProperty`, `QueryTree`, `GetWindowAttributes`) hangs indefinitely, no
reply at all.

**Diagnostic takeaway**: fast heartbeats + hung X11-protocol-touching
commands = the Weston/XWayland compositor connection is degraded, not a
protocol-7 code bug. Protocol-7's own command routing doesn't touch that
connection at all, which is why it stays responsive while anything doing
a real X11 round-trip stalls.

**Suspected trigger this time**: user was watching a video in Firefox on
the Windows host at the moment of the freeze. Under WSL2's virtualized
GPU (vGPU) model, host-side and guest-side GPU consumers share the same
underlying driver queue — heavy host GPU load can stall guest-side
`nvidia-smi`/`xrandr`/X11-protocol ioctls even though nothing in WSL
directly touches Firefox. Confirmed separately in the same session:
`nvidia-smi` hung directly in the user's own shell at the same time,
recovered on its own within minutes (transient contention, not a
permanent driver wedge — `nvidia-smi`/`xrandr` both responded instantly
once checked again a few minutes later, no orphaned processes).

**Fix**: same as before — full WSLg host reboot. No protocol-7-side
recovery exists for this class, and — see decisive finding below —
none is possible for the severe form of it either.

**Decisive finding (same incident, continued)**: user recalled seeing
this identical symptom before, during `powershell` zenka + pointer-hook.ps1
(coordinate-stream) development — see `modules/powershell.pointer-stream`,
which spawns a persistent `powershell.exe`-hosted script on the Windows
side streaming cursor coords into WSL via a shared-memory bridge. Ruled
out as the *fix* though: restarting the `powershell` zenka did not clear
it. Then user terminated the **entire backend** (`v7` shutdown, clean,
all 9 sub-processes including `protocol-7-menu` itself) — and the
`protocol-7-menu` window **stayed visible on screen, still frozen**,
after its owning process no longer existed. This is conclusive: with no
client process alive at all, the frozen window can only be a stale
cached surface the Weston/XWayland compositor never released or
repainted after the client disconnected. Pure compositor-side orphaned-
surface bug — not a protocol-7 connection/event-loop issue in this form,
and **not fixable by any client-side reconnect logic**, since there is
no connection left to reconnect. Only a WSLg/compositor-level reset
(host reboot, or possibly a lighter WSLg-specific restart if one is ever
found) can clear it. The `X11::Protocol` timeout+reconnect wrapper
planned below remains worthwhile for the *lighter* case (a live
connection hangs mid-round-trip while the compositor is otherwise
healthy) but would not have helped this specific incident.

Possible (unconfirmed) trigger correlation: both the pointer-hook.ps1
coordinate-stream dev period and today's incident involve sustained
cross-boundary (Windows host ↔ WSL) activity touching the shared
compositor pipeline — worth watching for next time this recurs, but not
established as causal (powershell restart alone didn't fix today's
instance, so if it's a trigger, the wedge outlives the triggering
process once created).

## Blocking-call hardening — in progress this session

Prompted by the above: `X-11.*` had multiple blocking external-tool calls
that could freeze the zenka's single-threaded event loop (and therefore
every STRM subscriber depending on it: `screen-setup`, `ticker`, `tile`,
`web-browser`, `protocol-7-menu`, `impressive`, `storchencam`) if the GPU
driver stalls.

**Landed (COMMITTED 3b966708d 2026-07-11, verified working after host reboot — menu logo/web-browser no longer freeze on Wayland when backend is gone)**:
- new `modules/base.exec.with_timeout` — reusable synchronous drop-in for
  `system()`/`qx()` calls to external tools. Built on `select()` +
  `base.s_read` (same non-blocking read primitive `coding.handler.http_io`
  uses) rather than `alarm()`. On timeout, sends `SIGKILL` to the child but
  does **not** block waiting to reap it (`base.waitpid` non-blocking only)
  — a driver-wedged child can sit in an uninterruptible kernel sleep
  (D state) that `SIGKILL` can't touch until the kernel call returns, so a
  blocking `waitpid` there would defeat the whole point; `base.sig_chld`
  reaps it whenever it actually exits.
- wired into `X-11.job.finalize_server`'s custom-xrandr-settings loop (was
  blocking `system()`, now 7s-bounded) and `X-11.start_gpu_top`'s intel
  capability probes (`intel_gpu_top -h` / `intel_gpu_frequency`, was
  blocking `qx()`, now 5s-bounded each). The nvidia branch of
  `start_gpu_top` was already correctly async (`open3` + `event.add_io`,
  no read at all in the hot path) — untouched.
- `X-11.*` subroutines.load-early + `base.list.subroutines` updated
  accordingly.

**Landed (COMMITTED e0f4fddd7 2026-07-11, verified live — X-11 zenka restarted clean after a follow-up fix, see below)**:
superseded the single-connection alarm()+reconnect sketch below with a
**dual-connection pool** design — a second `X11::Protocol` connection kept
permanently idle/pre-dialed, ready to take over at the first sign of
trouble instead of dialing fresh only after a hang is detected. Session
that produced the design: `cdc77f2e`. Implemented by kimi from
`data/tasks/x11-connection-pool.md` (dispatched via `kimi_dispatch`/
`kimi_continue`), reviewed and iterated twice before landing:
- fixed a select()-timeout gap where only the wait for the first byte of
  a reply was bounded — `handle_input()`'s internal
  `X11::Protocol::Connection::Socket::get()` is a blocking read loop with
  no deadline of its own, so a reply that started arriving then stalled
  mid-transfer could still hang past the intended timeout. Fixed in
  `X-11.pool.req_with_timeout` by temporarily overriding the connection
  class's `get()` (`local *{"${pkg}::get"}`, scoped to one `eval`, always
  restored) with a `select()`+`base.s_read` loop that re-enforces the
  deadline across the *entire* multi-byte reply, header and body.
- **self-inflicted bug, worth remembering**: assistant misdiagnosed
  correct `<[event.add_timer]>`/`<[event.add_io]>` calls (bare namespace)
  as broken because `ls modules/` shows no file by that literal name, and
  told kimi to rename them to `<[base.event.add_timer]>`/
  `<[base.event.add_io]>` — the actually-broken direction.
  `base.event.pre_init` calls `<[base.swap_subs]>->('base.event','event')`,
  which *moves* (not aliases) those subs into the `event.*` namespace at
  init, so the `base.event.*` keys stop existing in `%code` entirely once
  that runs. Zenka crashed on restart ("undefined value as subroutine
  reference"). User found + fixed via a global `ncode replace`, which also
  caught one pre-existing unrelated instance of the same wrong-direction
  bug in `modules/data.mount.shm.feedback.watch`. Full writeup + the
  general `base.swap_subs` mechanism (a growing list of families get
  moved this way, not just `event`) now in
  [[feedback-base-prefix-stripped]] — check that before ever "fixing" a
  bare/short-namespace `<[...]>` call that looks unprefixed.

Design, in the order it was derived:

- **existing replay gap, found by reading the code, not new to this
  design**: `modules/X-11.reconnect` today only calls `<X-11.obj>->init(...)`
  (re-dial the *same* object) + `X-11.init_display_states` (reload state
  from file). It never re-issues `RRSelectInput` (registered once, in
  `X-11.job.finalize_server` line 111) or `<[X-11.grab_key]>` (same file,
  line 247). So a reconnect *today* already silently drops randr-change
  events and hotkey grabs — pre-existing bug, independent of the pool.
  Fixing this means factoring a `X-11.reconnect.replay_registrations`
  (name TBD) that re-issues every per-connection registration (event
  masks, key grabs, any future selection ownership) — needed regardless
  of whether the target is a freshly-dialed connection or a pre-warmed
  standby, so build it once and call it from both paths.
- **pool is not new complexity, just earlier timing**: a pool connection
  is exactly a `X-11.reconnect`-produced connection, just dialed and
  replay-registered *before* it's needed instead of after a failure —
  trading permanent second-fd/idle-connection overhead for zero
  promotion latency (no dial + handshake + replay in the failure path,
  all of that already happened ahead of time).
- **query rerouting — the strongest part of this design, no promotion
  needed at all**: window IDs, atoms, and their properties are
  server-global state, not connection-scoped. So a **read-only** call
  stuck on the primary (`GetProperty`, `QueryTree`, `GetWindowAttributes`,
  `GetGeometry`, `TranslateCoordinates`, `GetInputFocus` — precisely the
  calls that hung in the 07-10 incident) can be reissued on the standby
  connection directly and the answer is exactly as valid, with **no**
  promotion/reconnect decision involved. Mutating or per-client calls
  (`GrabKey`, `SelectInput`/`ChangeWindowAttributes`) must stay pinned to
  whichever connection currently owns that registered state (or be
  double-issued to both, if kept fully mirrored) — they can't be rerouted
  ad hoc the way queries can.
- **standby doubles as a health oracle**: when the primary stalls, firing
  a cheap no-op round trip (`GetInputFocus`) on the standby distinguishes
  the two failure classes already identified above: standby answers fast
  → primary-specific stall (fd/socket-level, or a single wedged
  round-trip) → safe to reroute/promote. Standby *also* stalls → systemic
  /compositor-level failure (matches the orphaned-surface class from the
  07-10 incident) → no client-side action helps, don't burn reconnect
  attempts, surface the failure instead.
- **the standby's own ping must not itself block the event loop** — use
  the same `select()`-with-deadline pattern `base.exec.with_timeout` just
  landed for subprocess reads, applied to a socket read instead of an
  `open3` pipe fd.
- two independent layers fall out of this, useful even if only one gets
  built first:
  1. **per-request reroute** (query hits standby transparently on
     primary stall/timeout) — resolves most of what actually hung in the
     07-10 incident, no state-machine decisions required.
  2. **full promotion** (standby becomes primary, old primary retired,
     fresh standby dialed+replayed in the background) — only needed for
     a stuck *mutating* call, or to stop periodically re-servicing a
     primary that's clearly gone.
- still open / not yet decided: where the reroute+promotion logic lives
  (inside `X-11.WM.update` uniformly vs. per call-site — the 9-caller
  survey from the earlier single-connection sketch still applies), and
  the exact replay-registration list beyond `RRSelectInput`/`GrabKey`
  (audit for anything else per-connection before calling the replay
  function complete).

**Framing**: this is explicitly a further step past two prior stages —
old kiosk-era recovery restarted the *entire* X-11 process on protocol
lock errors that were often themselves recoverable; the current
`X-11.reconnect` improved that to an in-place re-dial with backoff, but
still eats full dial+handshake+state-reload latency and (per the replay
gap above) loses grabs/event-masks silently. The pool+reroute design is
two steps further: most stalls resolve via reroute with no reconnect at
all, and the failure classification (primary-specific vs systemic) is
now explicit instead of assumed.

**Note on `X-11.reconnect` itself**: it's synchronous/blocking too
(`base.sleep` in a `while` retry loop, up to 7 attempts × exponential
backoff capped at 60s = potentially minutes of blocking) but that's
pre-existing, out of scope for this session's hardening pass, and only
triggers on an actual protocol error today (not a silent hang) — worth a
note for a future pass, not touched.

## related

[[topic-gtk-wsl-window-positioning]] · [[feedback-weston-move-unreliable-use-compositor-grab]] · [[feedback-wslg-deiconify-limitation]]

#,,,,,.,.,,.,,.,.,,,,,,,.,,,,,,,.,.,,,,..,,.,,..,,...,...,.,.,,.,,,,,,,,,,,.,,
#EAS27VBTB5HF6XVQSOKJTT5GZK4YVKJZWTTUF7USFUK4OVF5WMRVPAXHRSETZF4E6RMUOZZ5EQGGS
#\\\|6N3N5HXKSOYZF7CHYO3BNMTY64SX7NJFITXE4BNGZT6PCUAMYFR \ / AMOS7 \ YOURUM ::
#\[7]7DMFJTGIMNP4FCJLKUQ6I2ICCKBBK7HTIKG37L2QVIVO7IUHAGCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
