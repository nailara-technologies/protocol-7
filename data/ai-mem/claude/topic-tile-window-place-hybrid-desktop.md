---
name: tile-window-place-hybrid-desktop
description: "roadmap - tile zenka as dynamic placement relay, window-place multi-window support, minimal desktop -> protocol-7-menu -> user/kiosk configuration"
metadata: 
  node_type: memory
  type: project
  originSessionId: 1fae67f1-7fe7-41e7-9119-372afacccc2b
---

**2026-06-15 — roadmap captured from user riff**, after [[zenka-naming-
cleanup]] tile-groups->tile rename and [[ondemand-heartbeat-upgrade]]
on-demand+heartbeat setup for `tile`.

**Vision:**
- Many zenki already have kiosk-era (7+ years old) infrastructure to
  request their window coordinates from the tile zenka
  (`tile.get_coordinates`, `tile.get_geometry`, `tile.assign_window`,
  `tile.get_subconfig`, etc.) — this is live, working query
  infrastructure for static/configured tile layouts.
- Upgrade `tile` to a **hybrid** capability: when a client/tile has no
  configured placement hints, `tile` calls out to [[window-place]]
  (interactively or via stored profile) to *resolve* a placement, then
  serves it through the existing query commands — seamless for callers
  either way.
- Overall direction: system can boot a **minimal desktop** +
  `protocol-7-menu`, from which a user configures either a full
  user/developer desktop (dynamic, window-place-driven) or locks down
  into **kiosk mode** with fixed configured tiles/layouts. window-place
  becomes the *editor* for tile configuration in both cases.

**Blocking prerequisite — window-place multi-window support:**
Currently `modules/window.place.*` is a singleton: per-request state
lives in flat `%data` slots (`<window.place.obj.window>`,
`<window.place.caller>`, `<window.place.reply_handler>`,
`<window.place.reply_id>`, `<window.place.drag.active/region/
start_geom/start_x/start_y>`, `<window.place.hover.region>`,
`<window.place.last_click>`, `<window.place.damp.shown/target/timer>`,
`<window.place.poll.timer>`). `<window.place.font.face>` is a shared
resource cache and should stay global.

Symptom: a second concurrent placement request opens a second window
with its own name, but internally only the *last* request's state
exists — X-11 event handlers (`handler.button_press/release/motion/
scroll/key_press/draw/poll_pointer`) and drag/damp logic all act on the
last window only, even when the event originated in the first window.

**Required refactor:** key all per-request state above by a
request/window id (e.g. keyed hash `<window.place.instances>{$id}{...}`),
and dispatch each X-11 event handler based on which `Gtk3::Window`
object triggered it. Once this lands:
- the zenka no longer needs to terminate on `commit`/`cancel` — it can
  stay resident (on-demand + heartbeat, per [[ondemand-heartbeat-
  upgrade]])
- subsequent placement requests open immediately without full zenka
  startup time
- this is the concrete unlock for the tile-hybrid-relay vision above

**Status:** design captured, multi-window refactor dispatched to kimi
2026-06-15 (see kimi task / commit history for outcome). Tile hybrid
relay and minimal-desktop/kiosk-mode work are NOT yet scoped further —
revisit once multi-window lands.

#,,,.,,.,,,,,,..,,,..,..,,,,,,.,.,.,,,,,.,,..,..,,...,...,...,,..,,..,..,,.,,,
#GJ4UOHR5HILZODDKYSFF24P6RNAEJJIJ4DABRNHRFEU7AMV2XPHLKPFTP4HIMSYMZ4X76KRHHPYOO
#\\\|N4HIDR66ENUX3SQUFF5CNIX5POJGNG7AROTLI5GFZ3PU45VJVUW \ / AMOS7 \ YOURUM ::
#\[7]OCGGFKVNTDPOA6X26KR4RCUTMFMXA6NPNSSAK3NPPQ6Y4OJNGYAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
