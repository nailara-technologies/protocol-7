---
name: gtk-ondemand-zenka-startup
description: required pieces for an on-demand gtk3 zenka to start cleanly without hanging
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 1fae67f1-7fe7-41e7-9119-372afacccc2b
---

an on-demand gtk3-using zenka (`start_mode = stdin-zenka`, `command_line_modules = Gtk3 ##init##`)
needs ALL of the following or it silently hangs until v7's start-timeout kills it:

1. `start.cfg` — `start.on-demand = 1`, `restart.disabled = 1`,
   `heartbeat.disabled = 1` (pattern from `cfg/zenki/mpv/start.cfg`),
   plus `command_line_modules = Gtk3 ##init##` (pattern from
   `cfg/zenki/protocol-7-menu/start.cfg`).
2. a `<zenka>.init_code` module that does:
   - `<[base.perlmod.autoload]>->('Gtk3')` + `'Glib::Object::Introspection'`
   - `<[base.gtk.attempt_load.glib_event]>` (optional `Glib::Event` for perf,
     same fallback pattern as `web-browser.init_code`)
   - explicit `Gtk3->init` — `command_line_modules = Gtk3 ##init##` only does
     `use Gtk3`, it does NOT initialize the Gdk display connection. without
     this, `Gtk3->main` in `base.gtk.main_loop` enters a loop with no live
     display context and just sits there (no error, no further log lines).
3. `start` file, before `[base.gtk.main_loop]`:
   - `[base.X-11.get_display]` / `[base.X-11.get_geometry]`
   - `[base.get_session_id]` — also required before the event loop, missing
     it caused a silent hang even after Gtk3->init was fixed.
   - then `[base.gtk.main_loop]` as the final statement (GTK main loop if
     graphical, falls back to `Glib::Timeout` + `<[event.once]>` polling
     otherwise).

**Why:** discovered while bringing up `window-place` zenka (2026-06-15) —
two separate silent-hang causes (missing `Gtk3->init`, then missing
`[base.get_session_id]`), each only visible via "instance start timed out
after Ns" in the v7 log, no other error.

**How to apply:** use this as a checklist for any new/renamed gtk3
on-demand zenka (e.g. future window-* or *-vision style desktop helpers).
also: `Gtk3::Gdk::*` constants (SHIFT_MASK, KEY_Escape, etc.) are subs, not
barewords — need `()` call form under `strict subs`
(`Gtk3::Gdk::KEY_Escape()`, not `Gtk3::Gdk::KEY_Escape`).

#,,,.,...,.,,,,,,,..,,..,,,.,,,,,,.,,,,,.,,.,,..,,...,...,...,..,,.,,,..,,,,,,
#SPJS5OZ442DMM52MS24P65WVEPHISBKQRZTELV5F2UEN4DUMIBEYISC5S3EOYULQ57XQFEL75LJKA
#\\\|XWAKJNJIQVJX7TTZJQ5RLCAQHMO7GGKYCHE3EZUKTE2BQPTJ6DK \ / AMOS7 \ YOURUM ::
#\[7]RBR73HOD5LENKXUWDOQRJQLU2KQLHN2WOGXL3VK3RL6ZYK6OXYDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
