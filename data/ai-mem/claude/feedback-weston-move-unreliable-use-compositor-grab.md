---
name: weston-move-unreliable-use-compositor-grab
description: "GTK move() on an already-mapped toplevel is unreliable under this WSLg/Weston build — use begin_move_drag/begin_resize_drag instead"
metadata:
  node_type: memory
  type: project
  originSessionId: 0f2dd921-9be7-4405-beed-2cc0db7e1b8f
---

**Found 2026-06-24, debugging window-place's drag/resize freeze.**

Confirmed via direct testing: `$window->resize()` on an already-mapped
GTK toplevel reliably applies under this WSLg/Weston build, but
`$window->move()` on the same window does not — it can silently fail to
apply while the calling code's own tracked position state keeps
advancing as if it had succeeded, producing a visual freeze with a
"frozen but state still updating" signature. Confirmed independently via
a *separate* code path too: raw X11 `ConfigureWindow` through the X-11
zenka's `move-window` command hits a similar "stops advancing" boundary
under some conditions (see [[topic-tile-window-place-hybrid-desktop]]
2026-06-24 entry for the full investigation, including a precisely
characterized Weston multi-monitor constrain bug that's a *different*,
platform-level issue from this one).

**Root mechanism (best understanding):** resize is client-controlled in
Wayland's model; repositioning an *already-mapped* toplevel is not —
only a genuine compositor-driven interactive grab reliably repositions
one. Calling `move()` directly is "asking nicely" and Weston doesn't
reliably honor it post-map, even though it *is* honored as an
initial-placement hint before the first map/show.

**Fix that worked, confirmed live:** switch interactive
move/resize-by-dragging to the compositor's own grabs —
`$widget->begin_move_drag($button, $x_root, $y_root, $time)` and
`$widget->begin_resize_drag($edge, $button, $x_root, $y_root, $time)`
(edge is a GDK window-edge nick string: `north`, `north-west`, `west`,
etc — all 8 confirmed reachable directly as plain strings in this Gtk3
binding, no enum conversion needed). Both let the compositor itself own
the operation; our own code never calls `move()`/`resize()` directly for
either. Landed in `window.place.handler.button_press` (commit
`6cb99b0c8`).

**Caveat — after switching to grabs, our own tracked geometry state
(`$inst->{geom}`) no longer updates during the drag** (grabs don't go
through `update_x11_state`). Must re-read the real position/size via
`$window->get_position`/`get_size` once the grab ends (`button_release`)
to keep the HUD readout and `commit`/`profile.save` in sync with reality.

**What did NOT work, and why:**
- Re-issuing `move()` a second time after `resize()` in the same tick —
  doesn't help; the unreliability isn't about call order or repetition,
  it's that the compositor doesn't honor post-map repositioning from a
  plain client request at all in some cases.
- Disabling the secondary pointer-poll-driven `apply_drag` call (theory:
  two coordinate sources fighting) — made it *worse* (total freeze, no
  partial movement at all), proving the poller was actually load-bearing
  for whatever partial movement *was* getting through, not a competing
  source.
- Using `$window->get_position()`/`get_size()` for synchronous read-back
  immediately after a plain `move()`/`resize()` call (attempted for the
  keyboard-stepping path, which has no grab to anchor a read-back to) —
  these GTK getters themselves proved unreliable for this purpose in
  this environment: returned outright garbage (`-32768`-ish, INT16
  underflow-looking values) in a sandboxed reproduction, and using them
  for read-back-and-correct on the real keyboard path caused chaotic
  jumps (every second arrow-key press moving left+up regardless of which
  key was pressed) rather than fixing the drift. Reverted; **keyboard
  move/resize still has the same coordinate-drift bug, unresolved** as
  of this writing — would need a read-back path that bypasses GTK's own
  position cache entirely (eg. a direct X11 protocol query) to fix
  properly, not yet attempted.

**How to apply:** any future interactive-drag code for an already-mapped
GTK toplevel under this stack should use `begin_move_drag`/
`begin_resize_drag` from the start, not plain `move()`/`resize()` in a
tick handler. `select.region.damp.tick` has the *identical* architecture
to `window.place.damp.tick` (kimi applied the same speculative fix
attempt to both, reverted on both) — **likely has the same freeze bug,
unverified, not yet fixed** — same fix should apply directly if/when it's
hit there too.

## related

[[topic-tile-window-place-hybrid-desktop]] · [[topic-gtk-wsl-window-positioning]] · [[feedback-wslg-deiconify-limitation]]

#,,,.,,..,.,.,,,,,..,,.,.,...,,,.,.,,,,,.,,.,,..,,...,...,.,.,.,.,...,..,,.,,,
#7HSCPHAGGMIJA3HXQP4TVPVFQF7SEBUFFYURRCL56EPJERCVANYB5UFKSIM4QFD6PPXLUPK6URAWM
#\\\|7JAFQQYIG42Q7YR3KVM5ZWS5CAGAYALF4D3YXQ5YF7BEWZ4OOH7 \ / AMOS7 \ YOURUM ::
#\[7]3KOUOORAH3OVT4ULGIKWVMFIWNOZMKUGJV4C7O3RKHSHF4CFXYCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
