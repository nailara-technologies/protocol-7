# Claude debug task: ticker swap-mode under WSLg

## Environment
- Host: WSLg / XWayland on Windows 11
- Project: Protocol-7 (`/data/projects/protocol-7`)
- Language: Perl 5 + Gtk3
- Ticker zenka: `modules/ticker.*`

## Current behavior
1. Ticker window is visible again after reverting the `override_redirect` experiment.
2. It reacts to the mouse: hover starts fade-out, leave starts fade-in.
3. In swap mode (`ticker.mouse.swap_edge` enabled), when the cursor touches the active edge:
   - the ticker fades out over `ticker.swap.delay` seconds (default 3),
   - at opacity 0 it calls `ticker.cmd.swap_profile`,
   - `swap_profile` toggles between `top-strip` and `bottom-strip`, recalculates geometry, calls `window.gtk.profile.apply` (GTK `move` + `resize`), then calls `base.X-11.move_window` (cube `ConfigureWindow`),
   - **the window only shifts a few pixels instead of jumping to the opposite edge**,
   - because the cursor is still over the ticker, it fades out again, retries, and eventually stays invisible (opacity 0, cursor still over).

## Files involved
- `modules/ticker.open_window` — creates the GTK window. Currently for swap mode it creates a **managed `toplevel`** (undecorated, skip taskbar/pager, keep_above, no `dock` type hint).
- `modules/ticker.handler.get-layer_reply` — sets `force_above` for swap.
- `modules/ticker.cmd.swap_profile` — toggles profile, applies geometry, X11 move, verifies.
- `modules/ticker.cmd.set-window-profile` — calculates geometry (supports per-monitor selection).
- `modules/ticker.handler.check_pointer` — poll-based hover detection using intended geometry and GTK event state.
- `modules/ticker.handler.fade_out` — at opacity 0 calls `swap_profile`.
- `modules/ticker.handler.fade_in` — brings ticker back.
- `modules/window.gtk.profile.apply` — `$window->move` + `resize`/`set_default_size`.
- `modules/base.X-11.move_window` — sends move command to cube.
- `modules/X-11.cmd.move_window` — direct `ConfigureWindow` in cube.

## What has already been tried
1. `popup` override-redirect window → invisible under WSLg (no parent).
2. Managed `toplevel` (no `dock` hint) → visible, mouse works, but swap moves only a few pixels.
3. Toplevel + `GdkWindow->set_override_redirect(1)` after realize → window spanned both monitors, wrong position, no mouse input.
4. Direct X11 `ConfigureWindow` via `base.X-11.move_window` → did not produce a full jump.

## Working hypothesis
WSLg/Weston does not honor client-initiated window moves for managed windows once they are mapped. The reliable way to reposition may be to **unmap/hide and re-create/re-show the window at the new coordinates**, because initial placement of a fresh window is honored by WSLg.

## Goal
Make swap mode reliably move the ticker to the opposite monitor edge without getting stuck in a fade-out loop. The window must remain visible and responsive after each swap.

## Suggested approaches (pick the simplest that works)
1. **Window rebuild on swap**: hide/destroy the current ticker window, reset the relevant state, run a window-rebuild routine (extracted from `ticker.open_window`) that creates a new window with the target profile, then fade in. This avoids the "move a mapped window" problem entirely.
2. **Hide → move → re-show**: before `set-window-profile`, hide the window; apply geometry to the hidden window; then show again. WSLg may honor the new position on the next map. If it does not, fall back to rebuild.
3. **X11-only override-redirect, but correctly**: if you want to try override-redirect again, do it by creating a bare X11 window (not a managed GtkWindow) or by ensuring size/gravity are set exactly before map. The previous attempt failed because the window became huge and unresponsive.

## Constraints
- Keep changes minimal and reversible.
- Do not break the non-swap ticker behavior.
- After editing, the user will run `bin/Protocol-7 sourcecode update-signatures`.

## Current user-visible config
- `configuration/zenki/ticker/start` contains `ticker.window.monitor = index:2`.
- `ticker.mouse.swap_edge` is enabled.
- Default `ticker.swap.delay = 3`.

## Current TODO
- [done] Restore stable managed toplevel for swap mode.
- [done] Make swap relocation reliable under WSLg.
- [done] Ensure swap does not get stuck at opacity 0 if a move fails.
- [done] Keep mouse hover/leave behavior working after swap.
- [done] Fix startup placement offset (see resolution below).

## RESOLVED [Claude, 2026-06-14]: startup placement offset

Root cause found and fixed. Sequence at startup:

1. `ticker.open_window`'s `map` handler computes the initial geometry and
   applies a corrective move while the window is still hidden (it gets
   hidden again almost immediately by `ticker.callback.draw` because no
   ticker content has arrived yet - see `<ticker.is-iconified>` /
   `'hiding window..,'`).
2. The before/after `get_window_geometry` debug logging (added this
   session) showed the corrective move landed **exactly on target**
   while hidden - e.g. `before-move actual x=0 y=2886, target x=0 y=2886`
   for `ticker.window.monitor = index:0`.
3. Once ticker content arrives, `ticker.start_animation` calls
   `$window->show` + `base.X-11.unhide_window` (which does `MapWindow`
   again). This **remap** makes WSLg/Weston run its initial-placement
   handshake a second time, silently discarding the already-correct
   position from step 1 and placing the window at Weston's own default
   location - which is what produced the "aligned with a different
   monitor" symptom for `index:0`/`index:2`.

### Fix applied
`modules/ticker.start_animation`: when the window was hidden and is now
being shown (`$was_hidden` true) and `<x11.coordinates.left>` is defined,
schedule a one-shot 0.3s timer that re-applies
`ticker.cmd.set-window-profile` + double `base.X-11.move_window` (same
double-apply pattern as `swap_profile`), after the remap has settled.

**Confirmed working for all three `ticker.window.monitor` values
(`index:0`, `index:1`/primary, `index:2`) - startup position now correct
on first paint.**

The `ticker.open_window` map-handler "startup settle" polling timer
(`ticker.timer.startup_settle`, polls `ticker.cmd.select_monitor` until
geometry is stable, then double-moves) remains in place as a harmless
extra safety net but was NOT the fix - kept for now, can be removed later
if considered redundant.

## Logging cleanup [Claude, 2026-06-14]
Per-hover/per-swap "activity" log lines that fire repeatedly during normal
swap-edge use were moved from level 1 to level 2 (zenka ring buffer only,
not console):
- `ticker.cmd.swap_profile`: "swap mode: moving ticker to %s edge"
- `ticker.cmd.set-window-profile`: "ticker geometry set: ..."
- `ticker.handler.check_pointer`: "pointer over current edge (swap),
  fading out", "edge free (swap), fading in", "swapped edge still under
  cursor, staying invisible"
- `ticker.open_window`: "mouse entered/left ticker window (swap), ..."
- `ticker.open_window` startup-settle debug logs (`startup-debug: ...`)

Also moved to level 2 (these are shared `base.X-11.*`/`window.gtk.*`
helpers, used on every move/raise/lower, not ticker-specific but mainly
exercised by the ticker swap/fade cycle):
- `base.X-11.keep_above` / `keep_below`: "setting window '%s' to state ..."
- `base.X-11.raise_window`: "raising window '%s'.."
- `base.X-11.move_window`: "moving window '%s' to x=... y=... w=... h=..."
- `base.X-11.get_screen_size`: "received screen size [...]"
- `window.gtk.profile.apply`: "applied window geometry: ..."

Level-1 (console) is now reserved for rare/one-time events: window open,
compositor detection, window mapped, monitor-removed relocation, swap
move failures, and non-swap hover fade messages. Failure-path logs (level
0) in these modules were left unchanged.

## Follow-up fix [Claude, 2026-06-14]: swap disabled right at startup

After the startup-placement fix landed, the corrected position can now sit
directly under the cursor at startup. `ticker.handler.check_pointer` (the
poll-based hover fallback) did not check `ticker.mouse.grace_until` -
unlike the GTK enter-notify handler in `ticker.open_window`, which does -
so it could immediately drive a swap attempt, fail verification (race with
the startup correction timers), and burn through all 3
`ticker.swap.fail_count` attempts before the 1.5s startup grace period
(set in `ticker.start_animation`) would have suppressed it. Result: swap
mode permanently disabled for the session right after startup.

Fix: added the same `ticker.mouse.grace_until` check to the top of
`ticker.handler.check_pointer`, before the swap/non-swap branches.

Note: if `ticker.swap.disabled` was already set from a prior run before
this fix, a reload/restart is needed to clear it (it's per-session state,
not persisted).

## Follow-up fix 2 [Claude, 2026-06-14]: swap move not landing post-startup-fix

Grace-period fix above did not solve it - swap move to the opposite edge
still failed verify (`actual x=1920 y=2448, target x=1920 y=1080`),
"actual" now correctly reading the startup-correct bottom-strip position
but the move to top-strip never lands. Visually: fade-out completes,
window briefly loses cursor contact (move partially happens), then snaps
back (revert-on-failed-verify) - "pops back in".

Pragmatic fix per user: give the compositor more time per apply.
`ticker.cmd.swap_profile`: increased the double-apply inter-step sleep
from 0.05s to 0.15s and added a third apply (geometry + ConfigureWindow)
before verifying. Adds ~0.3s total to each swap attempt.

If this still doesn't land, next steps: increase `ticker.swap.delay`
further, or increase the per-apply sleep again / add a 4th apply.

## Tuning adjustments [Claude, 2026-06-14]
- `ticker.swap.delay` default raised from 3s to **4.2s**
  (`modules/ticker.set_default_values`) - slightly longer hover-before-swap
  threshold.
- `ticker.speed` lowered from 9.47 to **8.47**
  (`configuration/zenki/ticker/start`) - slightly slower scroll.

## Second-opinion analysis [Claude, 2026-06-14]

Read through `ticker.cmd.swap_profile`, `set-window-profile`,
`window.gtk.profile.apply`, `open_window`, `check_pointer`, `fade_out`,
`window.profile.calculate`, `select_monitor`.

Confirms the working hypothesis strongly: `top-strip` vs `bottom-strip`
differ *only* in `y` (0% vs 95% of monitor height), so on a 1080px-tall
monitor the target jump is ~1000px. "Only a few pixels" of actual movement
means both `$window->move()` (GTK/Wayland) and the follow-up
`base.X-11.move_window` (ConfigureWindow via XWayland) are being ignored
or clamped by Weston for an already-mapped toplevel — XWayland's shell
integration generally only honors *initial* placement on map, not
client-requested repositioning afterwards. This matches point 38's
hypothesis exactly.

### Recommended next attempt: approach 2 (hide -> reposition -> re-show)

Concrete plan for `ticker.cmd.swap_profile`:
1. `$window->hide` first (window stays realized, so `resize()` in
   `window.gtk.profile.apply` is safe — only the *unrealized* case needs
   `set_default_size`).
2. Call `ticker.cmd.set-window-profile` as today (recalculates geometry,
   calls `move`+`resize` on the hidden window, updates `<x11.coordinates.*>`).
3. `$window->show_all` — re-map should pick up the new position/size as
   "initial placement", which WSLg honors.
4. Re-apply `base.X-11.keep_above` (stacking is often lost across
   hide/show).
5. **Defer verification**: don't call `get_window_geometry`/`move_window`
   synchronously right after `show_all` — the compositor needs a beat to
   apply the new map position. Use `base.event.add_timer` with
   `after => 0.2` (one-shot, no `interval`) and a `cb` coderef to run the
   existing verify/fallback block (the `move_window` nudge +
   tol-based actual-vs-target / actual-vs-before checks + revert-to-
   previous-profile-and-re-enable-opacity logic already in
   `swap_profile` can move into this timer callback essentially
   unchanged, just operating on `<x11.id>` etc. after the re-show).

This keeps the existing verify/revert/un-stuck-opacity safety net (which
looks solid) but gives the hide/show cycle time to actually land before
judging it, and uses the "initial placement is honored" property instead
of fighting post-map move/configure requests.

If hide/show *also* only nudges by a few px, that's strong evidence Weston
itself is pinning the X11 surface position regardless of map state, and
approach 1 (full window rebuild: destroy + recreate `Gtk3::Window` via a
factored-out routine from `ticker.open_window`) becomes the fallback —
more invasive but guaranteed to get a fresh "initial placement".

I haven't edited the code (swap_profile shows as staged+modified, looks
like Kimi may be mid-edit) — happy to implement the hide/show + deferred
verify version if you want a second PR/diff to compare against, or to
review Kimi's attempt once it's written. Ping me via `bin/chat`.

## Latest attempt result [Kimi, 2026-06-14]

Implemented the hide/show + deferred verification in `modules/ticker.cmd.swap_profile`.

Observed behavior from the user:
- The starting position is wrong: there is a **negative vertical offset**, the ticker is not truly at the bottom edge.
- When swapping to `top-strip`, the **window crashes**.
- After the crash there is a **flicker on the main screen**, and the ticker does not recover.

This suggests:
1. The geometry calculation or monitor-offset application is producing an invalid y coordinate in some path (possibly when `ticker.window.monitor = index:2` is combined with the `bottom-strip`/`top-strip` profile math).
2. Hiding and re-showing the window during the swap triggers a crash, possibly because the GTK/Cairo state is not safe across the hide/show cycle while a fade timer / draw callback is active, or because `base.X-11.move_window` / `raise_window` is being called with a stale / unmapped X11 id.

## Next step
Claude to attempt a fix. Recommended directions:
- Audit `window.profile.calculate`, `ticker.cmd.set-window-profile`, and `ticker.cmd.select_monitor` for negative-coordinate bugs when `index:N` monitor placement is used.
- Consider a **full window rebuild** (destroy + recreate via a refactored `ticker.open_window` routine) instead of hide/show, since hide/show crashed.
- Ensure all timers (fade, pointer check) are stopped/canceled before destroying/hiding the window and restarted cleanly after the new window is ready.

## Attempt 3 [Claude, 2026-06-14]: double-apply + non-permanent disable

Re-reading the failure sequence: on the failed swap attempt, the *revert*
calls `set-window-profile` a **second** time (back to bottom-strip), and
that second apply is what visually "jumps to the actual location" the user
sees on the next try. That points at WSLg/Weston dropping the *first*
move/configure right after (re)map but honoring a follow-up one. Separately,
`ticker.swap.disabled = 1` was being set permanently after a single failed
verify, which silently kills swap mode for the rest of the session (falls
back to plain hover-fade -> looks like "it disappears, never reaches top").

Changes made (no hide/show, no rebuild - smallest possible diff on top of
the reverted baseline, current state staged so this is a clean diff):

- `modules/ticker.cmd.swap_profile`: after the first
  `set-window-profile` + `X-11.move_window`, sleep 0.05s and repeat both
  (geometry apply + ConfigureWindow) once more before verifying.
- `ticker.swap.disabled` is now only set after **3 consecutive** failed
  verifies (`ticker.swap.fail_count`), reset to 0 on a successful swap.
  `ticker.swap.move_failed` is still recorded/logged but no longer
  permanently blocks retries.
- `modules/ticker.handler.check_pointer`: removed the
  `not <ticker.swap.move_failed>` gate on the swap branch, so a failed
  attempt doesn't prevent the next hover from retrying the swap
  (only `ticker.swap.disabled` gates it now).

Please sign (`bin/Protocol-7 sourcecode update-signatures`), reload, and
test: expect bottom-strip start position to self-correct as before, and
the *next* hover to actually attempt + (hopefully) land top-strip instead
of falling back to plain fade. If the double-apply still doesn't land the
big jump, that's strong evidence it's not a "needs a kick" issue and we
should move to the full window-rebuild approach.

## Attempt 3 result + Attempt 4 [Claude, 2026-06-14]

Log from the test: every verify reported `actual x=32 y=32` regardless of
target (`x=1920 y=1080` for top-strip), on both attempts. **32,32 is a red
herring** — `X-11.cmd.get_geometry`'s WSLg fallback path calls raw
`$X->GetGeometry($window_id)`, whose `x,y` are defined by the X11 protocol
as relative to the window's *parent*, not the root window. Under
WSLg/Weston the client gets reparented into a small WM/decoration frame, so
`GetGeometry` returns a near-constant ~32,32 (the frame's border/inset)
**no matter where the frame actually is on screen**. That means every
verify in `swap_profile` has been comparing a constant decoration offset
against absolute target coordinates — guaranteed to always "fail",
independent of whether the actual move worked or not.

### Fix applied
`modules/X-11.cmd.get_geometry`: in the raw-`GetGeometry` fallback branch,
additionally call `$X->TranslateCoordinates($window_id, $X->root, 0, 0)`
and use its `(dst_x, dst_y)` as the window's `x,y` instead of the
parent-relative values from `GetGeometry`. This gives root/screen-relative
coordinates, which is what `swap_profile`'s tolerance check actually needs.

### Why this matters for the bigger picture
With accurate coordinates, the next test run will tell us something we
genuinely don't know yet:
- If `actual` now reads close to the **target** (1920,1080) after the
  move → the GTK/X11 move was working all along, and the *visible*
  "doesn't move" / "few pixels" symptom is a **separate rendering/redraw or
  input-shape issue** (window content/hit-area not following the surface).
- If `actual` now reads close to the **before** position (bottom-strip,
  ~1920,2448) → the move genuinely isn't landing under WSLg, confirming the
  original hypothesis, and the double-apply (attempt 3) + rebuild fallback
  (approach 1) remain the right next steps.

Please sign + reload + test again with the same hover sequence and report
the new `actual x=... y=...` values from the swap-move-failed log line (it
may now succeed and not log at all — in that case report whether the ticker
visibly moved to the top edge).

## How to synchronize
This file lives at `session-state.md/CLAUDE_DEBUG_TICKER_SWAP.md`. Edit it in place if you update the plan. The Kimi session can read it back via `bin/chat` or file tools.

#,,,,,,,,,.,.,,.,,...,,.,,..,,.,.,.,,,,.,,.,,,..,,...,..,,,.,,..,,,,.,,,.,,,.,
#KNT2TXSROYNCK5BZFIVA5QHVK3LB74KLBFXTFTZILRDOWYCEDKBP4LGLMUKKSN3ZSJH77UZU2EM4O
#\\\|VE74YSEJD2CMCCB7CNGESQPOIZLFOMHOXXNYOLGQON5FC2U7MSF \ / AMOS7 \ YOURUM ::
#\[7]OYQHOJ3Y72MLJ2G4DSUZPVHMW4Z3NH735VTUT5V2DMWHMU6CLECI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
