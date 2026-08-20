---
name: gtk-wsl-window-positioning
description: ongoing investigation into unreliable GTK window position-setting under WSLg/Weston; root cause still not fully isolated
metadata: 
  node_type: memory
  type: project
  originSessionId: 0167cea8-7299-4bd1-b3b4-a507800e7687
---

**Status as of 2026-06-19 (session ran ~464K tokens, no compaction yet —
write everything down before a possible cutoff):** unresolved, active
investigation. Do NOT assume `GDK_BACKEND=x11` alone is the fix — it was
disproven by direct test (see below).

## what's confirmed

- `protocol-7-menu` standalone (via `bin/protocol-7-gtk3`) had random/wrong-
  screen position bounce; v7-managed `protocol-7-menu`/`window-place`/
  `select-region` restore position pixel-exact.
- root cause of *that specific* divergence: standalone launch's
  `XDG_RUNTIME_DIR` pointed at the real `/run/user/1000` (where WSLg's
  Wayland socket lives), so GTK auto-selected the Wayland backend, and
  Wayland's `xdg-shell` protocol forbids clients from positioning their own
  toplevel windows at all (compositor-only placement, this is universal
  across Wayland compositors, not WSLg-specific). `window-place`/
  `select-region`/`ticker`'s own `open_window` code already explicitly sets
  `GDK_BACKEND=x11` + deletes `WAYLAND_DISPLAY` (forcing X11/XWayland,
  where direct positioning works) — `protocol-7-menu` never got that fix,
  it only worked under v7 *incidentally* because v7 sets
  `XDG_RUNTIME_DIR` to the zenka's home dir, which has the side effect of
  hiding the Wayland socket from GTK too.
- fix landed (uncommitted as of this note): `bin/protocol-7-gtk3` now sets
  `$ENV{'GDK_BACKEND'}='x11'` in its `BEGIN` block — confirmed by live user
  test to fix standalone `protocol-7-menu` position restore.
- separately, standalone (never-root) launches hit a real chown bug: see
  [[feedback-source-identity-spoofing]] and the `base.root.drop_privs` fix
  (uncommitted) — `<system.zenka-user.current>` was never set when
  drop_privs no-ops (already running as the target user), causing
  `base.file.zenka_dir.write` to try (and fail) to chown to the wrong
  expected owner, deleting the just-written file on failure.
- `v7.zenka.start`'s own `GDK_BACKEND` line (inside the `exec-external`
  branch) was found to be **dead code** — no `zenka-startup.v7` in the repo
  uses `start_mode = exec-external` (all use `stdin-zenka`), and even if one
  did, `<x11.display>` is never populated in v7's own process (v7 never
  calls `[base.X-11.get_display]` itself), so the `if defined $display`
  guard always skipped it. Removed (uncommitted).

## what's NOT confirmed / actively contradicted

A minimal standalone test script
(`bin/dev/script-scratchpad/gtk_position_restore`, new, uncommitted) that
mirrors `window-place.open_window`'s exact window attributes
(`decorated(0)`, `keep_above(1)`, `app_paintable(1)`, `accept_focus(1)`,
`focus_on_map(1)`, RGBA visual, gravity north-west) plus `move()` before
`show_all` — **still mismatches the target position**, regardless of:
- `GDK_BACKEND=x11` set or unset
- `WAYLAND_DISPLAY` set, unset, or deleted entirely

This was tested via Claude's own Bash-tool process (not the user's
interactive terminal) — possible confound: Bash-tool's process may not be
tied to the same desktop/seat session as the user's terminal even with
matching `DISPLAY`, and WM placement heuristics can depend on session
association invisibly. **User was asked to re-run the same 3 invocations
in their own terminal — answer not yet received when this note was
written.**

Also just reported (not yet investigated): the test script's window itself
doesn't render/map correctly — described as "very translucent, you almost
only see its shadow." Possibly a separate RGBA-visual/compositing issue in
the test script, not yet connected to the positioning question. Could be
the script setting RGBA visual without actually painting a background
(no `draw` handler, unlike `window-place.handler.draw` which explicitly
paints a translucent fill) — worth checking first.

## update 2026-06-19 (later same session) — confirmed in user's own terminal

User ran `gtk_position_restore` directly (not via Claude's Bash tool),
ruling out the session/seat-confound theory from earlier. Findings:

- **draw-handler fix confirmed**: added a `draw` signal handler painting a
  translucent fill (mirroring `window.place.handler.draw`'s
  `set_operator('source')` + `paint`), returning `FALSE` instead of `TRUE`
  so the default handler chain still draws the child `Label`. Window now
  renders as solid translucent dark blue with visible text — the
  shadow-only/transparent rendering was purely the missing paint, as
  suspected (question 2 closed).
- **GDK_BACKEND=x11 does NOT fix the position mismatch**: tested with and
  without `GDK_BACKEND=x11`, no difference. Positions still come out
  effectively random.
- **XDG_RUNTIME_DIR changes also had no effect** on the mismatch — directly
  contradicting the working theory that hiding the Wayland socket
  (matching how v7 incidentally fixes `protocol-7-menu` standalone) is
  sufficient.
- **All test windows land on the primary monitor only**, regardless of
  target x/y — user describes this as matching the known/original
  `window-place`-style bug pattern, not a new symptom.
- Conclusion: the `GDK_BACKEND=x11` fix that solved *protocol-7-menu*
  standalone was solving a *different, narrower* problem (Wayland's
  xdg-shell forbidding client-side positioning entirely). The deeper bug
  that the minimal script reproduces is NOT that problem — something else
  in the full `window-place`/`select-region` zenka makes positioning work
  there that this minimal script still isn't replicating, and backend
  selection / runtime-dir tricks are not it.

### checked and ruled out as the differentiator

Read `src/window.gtk.profile.apply` (the actual function `window-place`
calls for positioning, via `window.place.apply_geometry`). Its only
non-obvious technique: call `resize()`/`set_default_size()` **before**
`move()`, because under Wayland the initial-placement configure request is
computed from the window's default size, so moving before sizing can be
off by the size delta. **This is already what `gtk_position_restore` does**
(`set_default_size` at line 25, `move()` at line 56) — so this is not the
missing ingredient either. No retry loop, no timer, no X11-protocol call,
no separate X11/display zenka coordination exists anywhere in
`window.gtk.profile.apply`, `window.place.apply_geometry`, or
`window.place.update_x11_state` (confirmed by direct read) — the latter is
pure local bookkeeping, doesn't touch the window or talk to X11 at all.

`window.place.open_window`'s only other notable technique: a deferred
`map`-signal handler that calls `set_keep_above(1)` + `present` +
`grab_focus` *after* map (to avoid a focus race under WSLg) — but this is
about focus/stacking, not position, and contains no `move()`.

## open questions for next session

1. **Primary suspect now**: multi-monitor / WSLg virtual-display geometry.
   "Lands on primary monitor only regardless of target x/y" smells like an
   absolute-coordinate-space mismatch between what GTK/X11 thinks the
   monitor layout is and what WSLg's compositor actually exposes — e.g.
   target x/y meant for monitor 2 get silently clamped/wrapped onto
   monitor 1's coordinate space. Check `xrandr`/`Gdk::Display` monitor
   geometry as seen by the test script's X session vs. what the user
   expects, and check whether `window-place`'s "pixel-exact" success was
   ever actually tested with a *non-primary-monitor* target — if all past
   successful tests only targeted the primary monitor, the bug may have
   been present all along and simply never exercised.
2. What does `window-place`/`select-region` do differently that the
   minimal script still lacks, given `window.gtk.profile.apply` itself is
   now proven equivalent? Candidates not yet checked: whether `move()` is
   called again after the deferred `map` handler fires (the live zenka's
   poll-timer (`window.place.handler.poll_pointer`, 50ms interval) might
   re-apply geometry repeatedly during drag — worth checking whether a
   *first* placement ever actually relies on a single `move()` sticking,
   or whether continuous reapplication during an active drag is what
   actually produces "pixel-exact" results, masking the same underlying
   single-shot unreliability).
3. `mpv`'s working fix (`X-11.wait_visible` → `set_geometry`, see
   [[topic-mpv-jobqueue-startup]]) bypasses GTK's `move()` entirely via
   external X11-zenka-driven reposition after the window is confirmed
   visible — still untested against this script for comparison, and now a
   stronger candidate than before given GTK-internal `move()` is
   increasingly looking unreliable as a single-shot operation under
   WSLg/Weston regardless of backend/sizing-order tricks.

## related

[[feedback-source-identity-spoofing]] · [[topic-mpv-jobqueue-startup]] ·
[[topic-zenka-naming-cleanup]] (select-region clone landed this session)

#,,.,,.,,,.,,,,,.,..,,,,.,,.,,...,,.,,,,.,,,,,..,,...,...,...,,.,,,,.,.,.,...,
#Z72TJYAYUFVUSM7NQ7ETSGAVHA2OK6GPOENXK45ZHHFKHPG2LMXJZ2RHPWZNAB34WUT3PXTYCR6TQ
#\\\|EDNDS37TJSZ6PFAZOGJVJT2TSHYA2XIF2YNYYTUSRBLMJTIJYNZ \ / AMOS7 \ YOURUM ::
#\[7]WP3DDGER546JZ6AGZ2V5OC5Z2GRB46DU772FTJZXW3QZL2MMVIBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
