---
name: screen-setup-zenka
description: "screen-setup zenka, display-layouts scaled monitor minimap; LANDED 2026-06-24 commit ce80398d5"
metadata: 
  node_type: memory
  type: project
  originSessionId: e46832a1-30ee-4a35-b48d-ba1e45979b28
---

**LANDED 2026-06-24, commit `ce80398d5` (branch base). Worked first try
once signed; refined over two iterations + an optical pass, all below.** New
on-demand GTK zenka `screen-setup` cloned/simplified from `window-place`,
providing a `display-layouts` command that opens a scaled translucent
*minimap* of the discovered monitor rects (blue, dim backdrop), with the
void gaps between staggered monitors showing through. Also returns an
xrandr-like text summary as the command reply.

**Iteration 1 (post first-run), 2026-06-24:** two fixes after live test —
(1) **placement**: dropped the absolute `profile.apply` cross-output move
(it computed `+3190+1490`, logically inside XWAYLAND1, but Weston clamped
it per-output and the window rendered half off-screen top-left — the
documented confinement biting our OWN window). Now `set_default_size` +
`set_position('mouse')`, letting the compositor place it under the pointer.
(2) **drag handle**: removed click-anywhere-closes (it dismissed before any
drag was possible). New `screen.setup.handler.button_press`: the
translucent **border band (26px) is a drag handle** that calls
`begin_move_drag` (compositor grab — the proven seam-crossing mechanism;
this window now dogfoods the eventual move-fix), **right-click dismisses**,
and the **center is reserved free** for future functions (hit-testing the
rects / relative repositioning), per taeki's protocol-7-menu analogy
(edges move, center free). Border band rendered visibly in handler.draw;
$border=26 must stay in sync between handler.draw and handler.button_press.
New module screen.setup.handler.button_press added → white-list regen'd
(12 subs). Files touched this iteration need re-signing.

**Iteration 2, 2026-06-24:** `set_position('mouse')` ALSO placed badly
(mostly off-screen) — so adopted protocol-7-menu's exact working sequence
in open_window: `set_gravity('north-west')` + `set_default_size` + `move()`
before show_all (the one programmatic placement empirically working on this
stack; gravity is part of the working sequence, not proven to be THE fix).
Plus persistence via the shared `window.profile` module like window-place:
restore on open / centered-on-pointer-monitor fallback; auto-save on drag
end. New `screen.setup.handler.button_release` reads `get_position`/
`get_size` after the grab and calls `window.profile.save`; button_press
sets `$inst->{dragging}` first. Caller key = `display-layouts.<vW>x<vH>`
(virtual-resolution-keyed via window.profile's per-caller files = the
menu's resolution-keying idea). **OPEN/UNVERIFIED:** restore does a
programmatic move to a possibly cross-monitor saved coord — the exact case
that may hit the per-output clamp; first-run uses the centered fallback
(no saved file) so that path is the isolated placement test; restore's
cross-monitor ceiling still needs the save-on-A/reopen-on-B test. Also
watch get_position→move round-trip drift (menu needed +38/+58 offset
correction, "root cause unknown"; we start with none). Optical pass:
swapped light/dark — luminous translucent-blue FIELD with monitors as
DARK glass panels (was inverted), crisp luminous borders, muted steel-blue
labels (was near-white). Verified the window via the **screenshot zenka**
(`p7c screenshot.capture-to-disk` → full Windows desktop png; X-11
capture-region gave black for the XWayland output). White-list now 13 subs.

**Why it exists:** the multi-monitor "virtual boundary" bug — under this
WSLg/Weston build, coordinate-based positioning (`ConfigureWindow` /
GTK `move()`) is clamped per-output and cannot cross the monitor offset
seam; only a compositor interactive grab crosses (see
[[feedback-weston-move-unreliable-use-compositor-grab]] for the full
mechanism + the `_NET_WM_MOVERESIZE` lever). `window.place.adjust` has
*zero* monitor awareness (free x/y arithmetic). This zenka builds the
relational layout model that was missing and makes the staggered layout
legible. This live layout: XWAYLAND0 1920x1080+0+1860, XWAYLAND1
3440x1440+1920+1080, XWAYLAND8 1920x1080+1062+0, virtual 5360x2940.

**Key design decisions:**
- data source = **GDK in-process** (`$display->get_n_monitors` /
  `get_monitor($i)->get_geometry`), NOT routing to `X-11.get_monitors`.
  Reasons: (a) `get_monitors` replies `mode=>'size'` which the
  synchronous TRUE-matching client-helper pattern can't parse (would
  hang); (b) `window.place` already reads monitor geom via GDK
  (`get_pointer_monitor_geometry`), so GDK is consistent with the eventual
  adjust-fix consumer; (c) registry==GDK==xrandr already confirmed live.
- the map window is sized to 60% (capped 900x620) and placed **on the
  pointer's monitor**, entirely within it, applied BEFORE show_all — so
  the window never itself crosses a seam (the one move Weston honors).
- `screen.setup.layout-model` derives the virtual bbox; `screen.setup.
  monitor-at-point` is the containment primitive `window.place.adjust`
  will consume for the actual cross-seam fix.

**Files (all need signing — user signs, passphrase):**
modules: screen.setup.{init_code,startup,ensure-display,enumerate-monitors,
layout-model,monitor-at-point,cmd.display-layouts,open_window,close,
handler.key_press,handler.draw}; configs: configuration/zenki/screen-setup/
{start,zenka-startup.v7,subroutine.white-list}; edit:
configuration/zenki/cube/auth.zenki (added `auth.setup.usr.screen-setup =
:zenka:`). Access needs nothing else — `access.cmd.usr.*` wildcard already
grants X-11 read cmds + the `get_display` it uses.

**Bring-up (UNTESTED — never parsed under the real loader; gen-sub-whitelist
`0 failed` only proves the `<[...]>` refs extracted, not a compile):**
1. sign: `bin/Protocol-7 sourcecode update-signatures` on the new modules +
   config files + the white-list. **NB: configuration/zenki/cube/auth.zenki
   was already signed — the edit invalidated its signature; it MUST be
   re-signed too or `reload config` may reject it.** (white-list regen cmd:
   `./bin/dev/gen-sub-whitelist screen-setup`, already run, 521 subs.)
2. **v7 reload/restart FIRST** so it rediscovers the new zenka-startup.v7 and
   registers the on-demand zenka at cube (else routing silently goes
   nowhere).
3. `p7c reload config` on cube (picks up auth.zenki).
4. `p7c screen-setup.display-layouts` — this first call IS the integration
   test. Expected: text summary reply + a translucent map window on the
   pointer's monitor. If it hangs (~0 CPU), read the on-disk zenka log not
   the ring buffer (gtk-ondemand startup quirk).

**First-run things to watch:** GDK `get_model`/`is_primary` availability in
this Gtk3 binding; that the size-mode text reply renders; that initial
placement lands the window on the pointer monitor.

**Optical pass SETTLED + confirmed good by taeki 2026-06-24** (swap +
muted labels + outer drag band matched to the dark monitor-glass tone
`0.0,0.015,0.075,α0.74`). NOTE: the thin per-monitor border
(`0.10,0.45,0.95`) is kept BRIGHT *on purpose* — it's the single luminous
accent giving the dark screens edge-definition against the field; taeki
likes it, do not "fix"/dim it.

**Iteration 3 — shared placement sanitizer, 2026-06-24 (post-commit
ce80398d5, NEW uncommitted):** trigger = protocol-7-menu crash-looped on
this staggered layout. Its default = top-right of the VIRTUAL box
(`5360-230-20=5110, 20`), which is a VOID (rightmost monitor XWAYLAND1 sits
at the bottom; the top row only reaches x=2982) → window mapped off all
outputs → verification timeout → restart loop. General gap taeki named:
placement code clamps to the virtual bounding box, but the box has holes on
offset layouts — sanitization must snap to a real MONITOR. Built TWO shared
helpers in **`base.gtk.*`** (universally available — menu/screen-setup both
use `base.gtk.main_loop` with no explicit load, confirming): `base.gtk.
list_monitors` (canonical GDK enumeration, returns index/x/y/width/height/
name/primary) and `base.gtk.snap_to_monitor($x,$y,$w,$h)` → returns an
(x,y) guaranteed on a monitor (containing-monitor by window centre, else
nearest by edge-distance, then clamp fully inside). Wired into: protocol-7-
menu.graphical-startup-init (before its move()), screen.setup.open_window
(restore path — replaces the crude top/left clamp, also closes the
cross-monitor-restore gap), and screen.setup.enumerate-monitors now
DELEGATES to base.gtk.list_monitors (deduped, one enumerator). Menu's
(5110,20) now snaps to (5110,1080) = top-right of the ultrawide. Both
white-lists regen'd (screen-setup 527, menu 462). NEEDS SIGNING; menu was
crash-looping so `p7c v7.stop protocol-7-menu` while iterating.

**LANDED 2026-06-27 (unsigned): window rect overlay + PNG snapshot.**

Window rects: `screen.setup.cmd.display-layouts` fires `X-11.get-windows`
via route-send (added to `access.cmd.usr.*` wildcard); reply handler
`screen.setup.handler.windows_reply` fans out `X-11.get_geometry` per
window; `screen.setup.handler.geometry_reply` collects and triggers
`queue_draw`. Draw handler renders amber rects (fill rgba 0.8,0.5,0.1,0.18 /
stroke 0.9,0.6,0.2,0.55) after monitor panels; skips own XID. KEY BUG
FOUND: SIZE replies carry payload in `$reply->{'data'}`, not
`$reply->{'call_args'}{'args'}` (that's TRUE-mode only) — see
`base.handler.command.process_reply` line 146. Verified live: off-screen
web-browser window shows below both monitors, confirmed accurate.

PNG snapshot: `screen.setup.cmd.snapshot [instance_id]` creates a
`Cairo::ImageSurface` at 1200×800 (configurable via
`screen.setup.cfg.snapshot_width/height`), runs the draw handler with a
fake widget bless, saves via `$surface->write_to_png`. Snapshots go to
`screen.setup.cfg.snapshot_dir` (default `<root>/data/snapshots/`).
Confirmed working — first snapshot showed off-screen web-browser rect
clearly below both monitor panels. White-list updated (+3 entries).

**LANDED 2026-06-27 (kimi): minimap window drag + intent layer.**

Each window entry carries two geometry slots: `actual_geo` (from
X-11.get_geometry, never user-touched) and `intended_geo` (set on drag,
cleared only on successful move). Draw handler uses `intended_geo` when set,
`actual_geo` otherwise; pending rects rendered with dimmer amber fill
`rgba(0.7,0.4,0.05,0.12)` + dashed stroke `rgba(0.8,0.5,0.1,0.40)` via
`set_dash([4,3],0)`.

Coordinate inversion caches `map_params` (`off_x`, `off_y`, `scale`,
`min_x`, `min_y`) per draw call so button_press can invert minimap pixels
to virtual coords. `handler.button_press` hit-tests the center zone per
window rect, records drag state. `handler.button_release` fires
`X-11.move-window` with reply routed to `screen.setup.handler.move_reply`
(clears `intended_geo` on success). `handler.motion` updates `intended_geo`
during drag.

**Screen-change subscription LANDED** (same session): `screen.setup.
subscribe-screen-change` registers with `X-11.subscribe-screen-change`;
`screen.setup.cmd.screen-change` fires on each event and retries all
pending `intended_geo` moves. **NOTE: the subscription mechanism uses
route-send (a handler name string stored in X-11's subscriber list), NOT
STRM — this was identified as architecturally wrong; the X-11 emit/subscribe
pair should be rewritten to use `base.stream.open`/`base.stream.push` like
`ticker.cmd.events` / `graphics-matrix.cmd.orbital-sync`.** The current
implementation functions but is not the correct pattern.

**BUG fixed 2026-06-28:** `screen.setup.cmd.screen-change` previously only
retried pending moves — it never re-enumerated monitors or rebuilt the model.
After a topology change `min_y`/scale etc. were stale so window coords mapped
into the old virtual space and drew outside monitor bounds. Fix: now calls
`screen.setup.enumerate-monitors` + `screen.setup.layout-model`, updates
`$inst->{'monitors'}` + `$inst->{'model'}` for every instance, then calls
`$win->queue_draw` before retrying pending moves.

**Resize deferred**: `X-11.resize-window` does not exist; right-drag reserved
for it but not wired. Right-click still dismisses everywhere; if resize is
added, button-3 in center zone must be separated from the dismiss path.

Deferred: (1) STRM-based screen-change subscription (rewrite X-11 side);
(2) STRM-based live window list (X-11 pushes on open/close);
(3) dynamic per-monitor border (brighten on hover);
(4) `_NET_WM_MOVERESIZE` direction-10 cross-seam probe.

## related

[[feedback-weston-move-unreliable-use-compositor-grab]] · [[topic-gtk-wsl-window-positioning]] · [[topic-tile-window-place-hybrid-desktop]]

#,,,,,...,,.,,,,,,,,,,,,.,.,.,.,,,.,.,,..,,,,,..,,...,...,.,.,,..,,..,,,,,.,,,
#OFL46ILL54GRR5LV2JRQLLW7AS363TP62CCKFGNPMF22NNBTHGVGWMSJP3CMP6M2OH4KRQ6OZCGTS
#\\\|YCYEDV64RFGGHAZDJTM2F6LGVQWJYGHWKOZC7K3E42JL6FAMLNT \ / AMOS7 \ YOURUM ::
#\[7]BKEUL4DSTA5MC4P43B6WIUQOKPSL3TDD2B5PR24LVLXXXOW2W4AI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
