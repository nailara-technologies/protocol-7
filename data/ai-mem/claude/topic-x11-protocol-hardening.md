---
name: x11-protocol-hardening
description: WSLg/Weston full-freeze recurrence + in-progress blocking-call hardening for the X-11 zenka (base.exec.with_timeout landed, X11::Protocol timeout wrapper mid-design, paused)
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

**Landed (staged, uncommitted as of this session's pause point)**:
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
- `X-11.*` subroutine.white-list + `base.list.subroutines` updated
  accordingly.

**NOT yet built — paused mid-design when the freeze above interrupted it**:
a second, architecturally different wrapper for raw `X11::Protocol` calls
(`X-11.WM.update`, `GetProperty`, `QueryTree`, etc.) — these are blocking
reads on the already-open X11 socket connection, not spawned subprocesses,
so `base.exec.with_timeout`'s open3/kill model doesn't apply. Plan as of
the pause:
- `alarm()` **is** appropriate here (unlike for subprocess calls) — it
  reliably interrupts an ordinary blocking Perl socket read, this isn't a
  kernel-driver ioctl in D state.
- a timed-out round-trip likely desyncs `X11::Protocol`'s internal
  sequence-number tracking, so recovery must be a **full reconnect**, not
  a retry on the same connection — this is exactly what the *existing*
  `modules/X-11.reconnect` already does (`<X-11.obj>->init(...)`, full
  reinit with exponential backoff, already wired to the connection's own
  `error_handler` for actual protocol *errors*). The new wrapper's job is
  only to *detect a true hang* (no error packet ever arrives, so
  `error_handler` never fires) and call the existing `<[X-11.reconnect]>`
  on timeout — not to reimplement reconnection.
- was surveying callers of `X-11.WM.update` (9 call sites: `X-11.cmd.
  get-windows`, `.hide-window-frame`, `.move-window`, `.set_geometry`,
  `.show-window-frame`, `X-11.connect_X11`, `X-11.get_window_ids`,
  `X-11.handler.monitor_settle_check`, `X-11.handler.screen_change`,
  `X-11.job.finalize_server`) to decide: wrap the timeout **inside**
  `X-11.WM.update` itself (protects all 9 callers uniformly, one change)
  vs. wrapping at each call site (more control, more diffs). Leaning
  toward wrapping inside `X-11.WM.update`, not yet decided/started.

**Note on `X-11.reconnect` itself**: it's synchronous/blocking too
(`base.sleep` in a `while` retry loop, up to 7 attempts × exponential
backoff capped at 60s = potentially minutes of blocking) but that's
pre-existing, out of scope for this session's hardening pass, and only
triggers on an actual protocol error today (not a silent hang) — worth a
note for a future pass, not touched.

## related

[[topic-gtk-wsl-window-positioning]] · [[feedback-weston-move-unreliable-use-compositor-grab]] · [[feedback-wslg-deiconify-limitation]]

#,,.,,,..,...,..,,,,,,,,.,...,.,,,,.,,,,.,,.,,..,,...,..,,,,.,.,,,,,.,...,.,,,
#C42XXOIFJ3A2L6Q3AKHFMVVZSCBMSCYHTVFXCZHHUOZ7UQFEH7NIZISRIDJV32JUTT2QVTBQPSVJQ
#\\\|2ETENHW5BBU4S7FUJXJ3ZTPPALZUJXYG43M4HXVGX5BE5WGI6D2 \ / AMOS7 \ YOURUM ::
#\[7]PYRGFRFUJVXNLPVIRPVBA7Y6X44JDD44SZE2UX4QYRWMABF7YMDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
