# host-side synthetic mouse input — task

## status [ 2026-08-24 ] — design-only, not started

## context

source: same-session follow-on to the 2026-08-24 GTK/WSLg cross-process
mouse-freeze investigation (see [[feedback-weston-move-unreliable-use-
compositor-grab]]'s 2026-08-24 section, and [[topic-screen-setup-zenka]]).

**what's proven so far:**
- the freeze is real, reproducible, and clears when (and only when) a
  genuine right-click *lands and is processed* by protocol-7-menu's
  window — not from any window simply being mapped/shown.
- X-11's own `WarpPointer` (`X-11.cmd.set_mouse_pos`/`move_pointer`) does
  NOT move the real, visible cursor under WSLg — WSLg forwards the HOST's
  real cursor into the X11 session one-way; warping the X11-side pointer
  only updates the X server's internal bookkeeping, with no path back to
  the actual cursor Windows is rendering. Confirmed live: `set_mouse_pos`
  reported success but the visible pointer never moved.
- XTEST IS available on this X server (confirmed: `X11::Protocol`'s
  `init_extension('XTEST')` succeeds), but a synthetic `FakeButtonEvent`
  through it was never actually tried — likely subject to the same
  "doesn't reach the host-forwarded input path" limitation as WarpPointer,
  since both are X11-server-side, not host-side, in origin. Untested,
  not confirmed either way.

**the lever most likely to actually work:** originate the click from the
HOST side via `powershell.exec` (already a proven-working bridge, see
[[topic-powershell-native-toast-notifications]]) — move the real Windows
cursor and send a real synthetic click via `SendInput`/`mouse_event`
P/Invoke, exactly as if a physical click happened. WSLg would then forward
it into the X11 session the same way a genuine click is forwarded.

## scope for a first cut

1. **coordinate translation, the actual hard part.** WSLg maps each
   Windows monitor to its own XWayland RandR output (already have the
   X11-side rects via `screen-setup.display-layouts` / `X-11.get_monitors`
   — output name + x/y/w/h in the X11 virtual-desktop coordinate space).
   Windows' own screen-coordinate space for those same monitors is NOT
   guaranteed to share the same origin/ordering. To click at X11 point
   `(x, y)`:
   - find which XWayland output `(x, y)` falls in, and the offset within
     that output.
   - match that output to the corresponding Windows monitor — via
     PowerShell `[System.Windows.Forms.Screen]::AllScreens` (or
     `Get-CimInstance Win32_VideoController`), matched by resolution (and
     tie-broken by relative position if more than one output shares a
     resolution) — to get that monitor's real Windows screen-coordinate
     origin.
   - add the within-output offset to that origin → real Windows screen
     coordinate.
2. **new command**, e.g. `powershell.cmd.synthetic-click <x> <y> [button]`
   — takes X11 virtual-desktop coordinates, does the translation above,
   moves the cursor (`[System.Windows.Forms.Cursor]::Position` or
   `SetCursorPos` P/Invoke) and fires a `mouse_event`/`SendInput` click
   at the translated point.
3. **first real test**: reproduce the cross-process freeze, then fire a
   synthetic right-click at protocol-7-menu's ring center (its window
   geometry is already queryable via `X-11.get_geometry`) instead of a
   real physical click, and confirm whether it clears the freeze the same
   way. This is the actual open question the whole task exists to answer
   — if a synthetic click does NOT clear it either, that's strong evidence
   the fix depends on something host-input-stack-specific beyond just
   "the click landed" (e.g. real HID-driver-originated events specifically),
   which would rule out this whole approach and point back to needing a
   different lever entirely.

## possible later expansion (explicitly out of scope for the first cut)

taeki's framing: a full general-purpose synthetic-input fallback feature
on the powershell zenka (not just one throwaway test command) — including
WSL-environment auto-detection (mirroring the pattern already used for
`X-11.notify_recover.enabled`'s WSL auto-detect: `$ENV{WSL_DISTRO_NAME}`
or `-d '/mnt/wslg'`) so any future zenka that needs a synthetic click/key
event can route through one shared, general command rather than each
building its own coordinate-translation logic. Don't build this generalized
version until the first-cut test above actually confirms synthetic clicks
are the right lever at all — no point generalizing an approach that might
not work.

## related

[[feedback-weston-move-unreliable-use-compositor-grab]] ·
[[topic-screen-setup-zenka]] · [[topic-powershell-native-toast-notifications]]

#,,,,,,..,...,.,,,.,.,,,,,,..,,,.,,,,,,,,,..,,..,,...,...,..,,,,.,,..,,,,,.,.,
#XVXPPHPSBMQX5UDS3M5LBVXCNR6MRWROPBVHUVU57GXT466AVNRB5XK4IHYV46L3GCQBA6C4VQQHO
#\\\|3C45ULVQ6CUV3NYNPBQCCFCKV5O4KGO4QVI5DAUNUQ4TPEE6QMA \ / AMOS7 \ YOURUM ::
#\[7]KDKB7O42HPJWNHF66SOZZC2IXWVRESZXWJF7J2SSLS2NFOJYWSBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
