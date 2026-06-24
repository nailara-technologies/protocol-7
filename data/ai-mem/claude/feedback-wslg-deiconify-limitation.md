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

**How to apply:** Do not re-investigate deiconify on WSLg unless the WSLg/Weston version changes. The 4-approach fallback in `modules/X-11.cmd.deiconify-window` is the ceiling for client-initiated (X11/GTK) deiconify. On a real WM (GNOME, KDE, i3, etc.) these approaches will work.

**Update 2026-06-24:** the host-side Windows taskbar restore path is NOT blocked by this limitation — clicking a minimized window's entry in the Windows taskbar successfully restored a `protocol-7-menu` window that had gone iconic (confirmed live). So the compositor-level block is specific to deiconify requests issued *from within* Linux/X11/Wayland; the host (Windows/WSLg integration) has its own restore path that still works. If a window gets stuck minimized, try the host taskbar before assuming it's permanently lost.

#,,..,...,...,,,,,,..,,,.,,.,,...,,,.,,.,,..,,..,,...,...,...,.,,,,.,,.,,,..,,
#NHQNOOZWKCJEDGX64LCL67ODYZ5UHXLXZ2WCAZDYFQIRICLLSOAKDLWZKJSVRWI3P7RKE7QWA7FCQ
#\\\|DJSTWXIGNLJAIOOD7AWNRLAMYY6Y3AUXXF3JGKJ4XDWVXZUMQ3F \ / AMOS7 \ YOURUM ::
#\[7]RE56I7EV3ONGUHW6BHD2CPBJGFVSISO3DZEKKA7W2COAOCI4NUAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
