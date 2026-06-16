---
name: wslg-deiconify-limitation
description: "WSLg/Weston does not support programmatic deiconification via X11 or GTK — iconify works, deiconify does not"
metadata: 
  node_type: memory
  type: project
  originSessionId: 97900352-efbd-48aa-b08b-a369dd0c6e1e
---

On WSLg (Weston + XWayland), `iconify-window` works via `X11::Protocol::WM::iconify` (sends `WM_CHANGE_STATE(IconicState=3)` ClientMessage to root). But deiconification is blocked at the compositor level — nothing works:

- `MapWindow` on titled-child XID → no effect
- `MapWindow` on root-child container XID → no effect  
- `WM_CHANGE_STATE(NormalState=1)` ClientMessage → no effect
- `_NET_ACTIVE_WINDOW` ClientMessage → no effect
- `_NET_WM_STATE remove HIDDEN` → no effect
- GTK `$window->deiconify()` → no effect (both Wayland and x11 GDK backends)
- GTK `$window->present()` → no effect
- GTK `$window->raise()` → no effect

**Why:** Weston/WSLg responds to iconify requests but does not expose a reverse path via either X11 or Wayland protocols for client-initiated deiconification.

**How to apply:** Do not re-investigate deiconify on WSLg unless the WSLg/Weston version changes. The 4-approach fallback in `modules/X-11.cmd.deiconify-window` is the ceiling. On a real WM (GNOME, KDE, i3, etc.) these approaches will work.

#,,,,,,.,,.,.,,..,,,,,,..,..,,,,,,,,,,.,.,.,,,..,,...,...,...,,,.,,,,,,,.,.,,,
#MYXKHOBRLBDCPTGRCRJAV6OKLW7ASVSMZQKWL2XHKA5LCOJQPMLNBCOHY5CGGUWP6QN6WEJCL5POM
#\\\|VMW72YX5VDZGVIZKH7OOTQ5D53352NRCRMLYRRGLIALCJGU6Z6E \ / AMOS7 \ YOURUM ::
#\[7]VZ5CY5JC3H3XJYYE3ZLZTRJ6ARZ2LY64XMR4HQW4IOPMTAIY5KAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
