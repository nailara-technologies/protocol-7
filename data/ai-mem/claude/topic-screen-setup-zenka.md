---
name: screen-setup-zenka
description: "new screen-setup zenka with display-layouts command — scaled minimap of monitor rects; built 2026-06-24, UNSIGNED/UNCOMMITTED"
metadata: 
  node_type: memory
  type: project
  originSessionId: e46832a1-30ee-4a35-b48d-ba1e45979b28
---

**Built 2026-06-24 (this session), WORKED FIRST TRY clean once signed;
NOT YET COMMITTED, re-sign needed after the iteration below.** New
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

**Deferred (planned next):** (1) overlay detected window rects from
`X-11.get-windows` — note that cmd returns only XID+title, needs
`get_window_geometry`/`get_geo_async` per-window async fan-out; (2) the
actual move-handler fix — live-probe whether Weston honors
`_NET_WM_MOVERESIZE` direction 10 (MOVE_KEYBOARD) to cross seams; (3)
taeki's idea — make the thin per-monitor border **dynamic**: react to
state + mouse proximity (brighten on hover, colour by active/drag-target/
pointer-over-screen). Reuses the same per-monitor hit-testing
(`screen.setup.monitor-at-point`) the placement fix needs — turns the map
from static diagram into live instrument.

## related

[[feedback-weston-move-unreliable-use-compositor-grab]] · [[topic-gtk-wsl-window-positioning]] · [[topic-tile-window-place-hybrid-desktop]]

#,,,,,,.,,,.,,,..,..,,.,,,.,.,,..,...,,..,,.,,..,,...,...,..,,,,.,.,,,,,,,.,.,
#MZ3EX7DS7TWM3GASCH2QEXFDGHT74W54YVSXMIZIMBYTTD5VJ2L2LSDSVTNBVISIGSN7VETQD2CUY
#\\\|WIHKSEDFYW46HCVGCAWNYVKZKEETINGQDC4DJNUB7AIEOAXUOG6 \ / AMOS7 \ YOURUM ::
#\[7]UVRMWKZUYEMJ7R27LBLVW6OPQZ2XKUFD3SONBVJUPHZBIRBQHQCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
