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

**HAZARD (found 2026-06-28):** `begin_move_drag` can leave a stale Weston
button-1 compositor grab if the window is destroyed while the grab is still
active (e.g., user right-clicks to dismiss during or just after a border drag
before button-1 is fully released). The stale grab blocks left-click delivery
to ALL clients. `protocol-7-menu.graphical-startup-init` documents the same
hazard and avoids `begin_move_drag` entirely for this reason; it uses manual
drag tracking instead (no compositor grab). **Fix pattern:** before destroying
a window that uses `begin_move_drag`, call `Gtk3::Gdk::pointer_ungrab($time)`
(wrapped in `eval{}` for safety). Also call it when mapping a new window
(clears stale grabs from other windows). Landed in `screen.setup.handler.
button_press` (right-click close) and `screen.setup.open_window` (map signal),
commit `0285a96f5`.

**Same fix landed for `window.place` 2026-07-16 (commit `fff81c212`)** —
it had the identical unprotected `begin_move_drag`/`begin_resize_drag`
usage with no ungrab anywhere; grepped the whole tree, confirmed the only
other zenka with this gap. Fixed in `window.place.commit` (ungrab before
destroy) and `window.place.open_window` (ungrab on map). Live test was
inconclusive on root cause: restarting X-11 alone (which restarts
`window-place`, since it depends on X-11) did not clear an existing
freeze; also restarting `tile` did. `tile` has no GTK/grab code of its
own (checked directly), so it's unconfirmed whether `tile`'s restart
actually mattered or just coincided with something else clearing — the
fix itself is real and correct regardless, but don't treat "restart tile"
as a confirmed recovery step without re-testing it in isolation.

**Sharpened 2026-06-24 (multi-monitor seam):** the "virtual boundary" the
keyboard move-handler hits is the *same* per-output confinement. User
confirmed `X-11.move-window` (which is `$X->ConfigureWindow`, raw X11
absolute through XWayland) hits the wall, while mouse drag does not.
Mechanism table on this WSLg/Weston build:
- coordinate-based positioning — `ConfigureWindow` / GTK `move()` /
  `X-11.cmd.set_geometry` — is **clamped to the window's current output**;
  cannot walk or jump a window across the monitor offset seam.
- only a **compositor-driven interactive grab** crosses the seam:
  `begin_move_drag` for own windows (proven); `_NET_WM_MOVERESIZE` (EWMH)
  is the equivalent for *foreign* windows — **NOT implemented anywhere in
  the codebase**, and it is pointer-anchored (starts a drag that follows
  the cursor, not a clean set-absolute-coords), so keyboard cross-seam
  stepping stays awkward even with it.
**Consequence for the planned screen-setup/display-layouts visualizer:** a
read-only cairo map of the monitor rects is worth building (diagnostic +
the coordinate model `window.place.adjust` totally lacks today — it does
free x/y arithmetic with no monitor awareness), BUT it will NOT fix
cross-monitor *movement* by itself, because commit still routes through
the clamped `ConfigureWindow`/`set_geometry` path. Two unrun probes that
decide feasibility: (1) is the boundary the current-monitor edge or the
global-desktop edge; (2) does this Weston honor `_NET_WM_MOVERESIZE` at
all. If (2) is no, there is no programmatic cross-seam path on this build.

**Broadened + escalated 2026-08-24 — the hazard is NOT limited to
begin_move_drag, and it can get WORSE, not just persist.** Chasing a
freeze where closing one `screen-setup` minimap window (via ANY close
path — right-click, Escape, or WM delete_event, no drag ever involved)
froze mouse input (not keyboard) on the other still-open window, and
simultaneously on an unrelated `protocol-7-menu` window too — proving
this is a genuinely global, cross-process compositor state, not a
per-client X11 grab:

- **Confirmed dead ends, in order tried:** `Gtk3::Gdk::pointer_ungrab`
  from the closing client's own process — no effect. `GdkSeat::ungrab()`
  (the modern, device-agnostic API, confirmed live this zenka's default
  pointer is a `GdkX11DeviceXI2` not the core pointer) — also no effect.
  `powershell.display-switch-toggle` (DisplaySwitch.exe host-side
  re-push) — no effect. Restarting the affected zenka, X-11 itself, and
  even `explorer.exe` on the Windows host — none cleared it.
- **The one thing that DID clear it, reproducibly:** a genuine right-
  click landing inside protocol-7-menu's own menu-zone (hit-radius
  around its window center) that successfully opens the menu. This
  unfroze BOTH the menu's own window AND the unrelated frozen
  screen-setup window simultaneously. It is specifically the click
  *landing and being processed*, not "a new window getting mapped" —
  a standalone command that just does `$window->present()` +
  delayed `->hide()` (no real click event) did NOT reproduce the fix,
  ruling out the "any window map" theory. Two untested/unwired
  diagnostic commands exist for whoever picks this back up:
  `protocol-7-menu.cmd.gtk-focus-recover` (present+hide the real menu)
  and `screen.setup.cmd.gtk-focus-recover` (flick a throwaway dummy
  window) — both built, neither confirmed to fix anything, since the
  real fix needed an actual processed click, not a window-map event.
- **XTEST/synthetic input is unreliable for testing this.** `X-11.cmd.
  set_mouse_pos` (raw `XWarpPointer`) visibly does nothing under WSLg —
  WSLg forwards the HOST's real cursor into the X11 session, but
  `WarpPointer` only updates the X server's internal notion of pointer
  position with no path back to actually move the cursor Windows is
  rendering. A synthetic XTEST `FakeButtonEvent` was never actually
  tried (blocked on this same coordinate problem — the click needs to
  land on real host screen coordinates, requiring translation from the
  X11-side XWayland-output rect to the corresponding Windows monitor's
  own screen-coordinate origin, e.g. via PowerShell's
  `[System.Windows.Forms.Screen]::AllScreens` matched by resolution).
  Worth attempting from the powershell-zenka side (real `SendInput`,
  originates from the host like a genuine click) if this gets picked up
  again, not from X-11's own connection.
- **DANGER — a "helpful" fix attempt made things categorically worse.**
  Tried self-healing on close by synchronously destroying + immediately
  recreating each surviving instance's own window in the SAME call
  (right after the closed window's own destroy). Result: mouse input
  broke on EVERY window, including ones that had never been touched.
  Reverting the code did NOT fix the now-broken live process — needed
  `v7.restart` of the affected zenka (no effect), a Windows
  `explorer.exe` restart (no effect), and finally a **full Windows host
  reboot** before it recovered. Lesson: don't chain a destroy and a
  recreate synchronously in the same call under this stack when
  debugging a freeze already caused by window destruction — a broken
  live state from live experimentation can escalate past what a process
  restart, an X-11 restart, or even an explorer.exe restart can recover
  from, and land you needing a full host reboot. Prefer read-only
  diagnosis (stacking order via `X-11.get-stack-order`, geometry
  read/write via `X-11.set_geometry` from a SEPARATE connection to
  confirm the window itself is still responsive to non-input requests)
  over live destroy/recreate experiments once a freeze is reproduced.
- **Also confirmed:** the frozen window remained fully responsive to
  non-input X11 requests the whole time (an `X-11.set_geometry` call
  from a separate connection successfully moved/resized it) — the
  process/event loop and the window's own X11 resource were never
  actually stuck, only mouse *input delivery* was. Rules out a hung
  main loop as the mechanism; whatever's broken lives inside
  XWayland/Weston's own input-routing state, external to any zenka
  process.

## related

[[topic-tile-window-place-hybrid-desktop]] · [[topic-gtk-wsl-window-positioning]] · [[feedback-wslg-deiconify-limitation]]

#,,,.,...,,,,,,..,,..,.,,,,..,...,,,,,...,,,,,..,,...,...,...,.,,,,,.,.,,,..,,
#J3HPHLTCFGGVQIJM7LTYKQFGZE36GIN53FCA3O2QHOISYGHMZBMRXAJTCAYMEW7JQ5ERCV53LHEPM
#\\\|6ILKIU77XYFMAMMNXXMXKN5HYGX27TIRY3EUCCQEPZTLI7EWGL7 \ / AMOS7 \ YOURUM ::
#\[7]IIJLOAHDYIVEC4RQH7VSMILOESVB3GJ5JRCYPVUSJ67AQQT7JQDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
