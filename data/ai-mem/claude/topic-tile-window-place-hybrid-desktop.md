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

**Status — multi-window refactor LANDED 2026-06-15** (commits 82e65f2d6
tile rename, 9c899f360 multi-window state/Event.pm fixes, 68dec757b
resident-after-commit/cancel + multi-monitor sizing; all pushed). Kimi's
keyed `data{window}{place}{instances}{$id}` refactor was structurally
right but had two Event.pm bugs (watcher accessor order, `->cancel` vs
`->stop`) - fixed by taeki. Verified live: two simultaneous placements
(mpv + nshell callers) opened independently, each draggable/committable
on its own.

Follow-up fixes landed in the same pass:
- removed legacy self-`Gtk3->main_quit`+exit-on-empty-instances from
  `window.place.commit`/`cancel` - zenka now stays resident (on-demand +
  heartbeat per [[ondemand-heartbeat-upgrade]]), so subsequent placements
  open instantly with no startup cost
- `window.profile.calculate`: 'center' fallback profile now 70%/70%
  (was 50%/50%); 'saved' profile's no-size-hint fallback also defaults to
  70% centered (was 100%)
- multi-monitor fix: `window.place.start` now uses
  `window.gtk.get_pointer_monitor_geometry` (monitor under pointer) for
  screen_w/h/x/y instead of the full virtual-screen bounding box, and
  `window.profile.calculate` applies that monitor's x/y offset to the
  final position - previously windows could be sized for one monitor but
  positioned on another

**Open follow-up (not yet addressed):** taeki noted commit/cancel
currently act on "all" rather than a specific instance in some path
during the crash-induced two-window-closed-together observation - revisit
whether an optional dismiss-target-id param (ticker.dismiss-style) is
still needed now that instances are properly keyed; may already be moot
since cancel/commit already take `$id`.

**Next:** tile-hybrid-relay implementation (tile calls out to window-place
when no configured placement hints exist) and minimal-desktop/kiosk-mode
work can now proceed - no longer blocked.

---

**2026-06-16 — integration architecture design**

Two integration paths identified, both sharing the same window-place
interaction — the difference is only what happens to the resulting geometry:

**Path A — standalone (geometry oracle)**
Client asks window-place directly → gets geometry back → uses it
immediately. No tile dependency. Suited for one-off placements, temporary
windows, anything that doesn't need coordination or persistence. window-place
as a pure interactive geometry oracle.

**Path B — tile-integrated (intent → configuration)**
Placement result flows into tile as a new or updated tile definition. This
inverts the kiosk model: instead of a separate tool producing a config that
tile consumes, window-place IS the configuration act. The drag gesture
authors the tile definition in real time.

This requires tile to accept **intent-first entries**: tiles that know their
geometry but were authored by dragging rather than edited in a config file.
Two sub-variants:
- **geometry-only tile**: knows position/size, waiting for a window match
  to be assigned later
- **matched tile**: has both geometry (from window-place) and a window
  pattern — fully resolved, just not persisted yet

**The "half-configured tile" design question:**
A tile with geometry but no window assignment is a valid intermediate state.
tile currently requires full config. Introducing intent-first tiles means
tile needs to hold runtime state for placements it *received* but hasn't
persisted. This is new territory — the kiosk system always had complete
configs before tile started.

**Persistence question (open):**
For a true "start from intent" flow, tile needs to persist new entries to
disk so the layout survives a restart without re-dragging. Runtime-only
state is easier to implement first, persistence is the eventual goal.
The config format tile uses on disk would need an "authored via placement"
marker vs. "hand-configured" so the two sources remain distinguishable.

**Lifecycle picture:**
1. System boots with minimal desktop + protocol-7-menu
2. User opens an app → no tile entry exists → tile falls through to
   window-place → user drags to position → geometry returned
3. tile stores result as a runtime intent-first entry (Path B) or
   discards after use (Path A), depending on whether the app is
   "managed" by tile or not
4. Over time, intent-first entries get reviewed and promoted to
   persistent config — or auto-promoted after N successful placements

**Current priority:** establish the two-path API contract first (what
does a client send to request standalone vs. tile-integrated placement),
then implement tile's ability to hold and serve intent-first entries,
then add persistence. The X-11 infrastructure improvements in this
session (window enumeration, get-windows, GDK_BACKEND) are a prerequisite
that is now complete.

#,,,,,,,,,...,.,,,,,.,.,,,,..,,.,,,.,,,..,..,,..,,...,...,...,,,,,,,,,.,.,..,,
#AKF7TAAERAGSCERTXIHE6HSX7ISYDRU52RO4D73FAGMKMW6M4YYZ75V5C3TYXIUCVCNK3EJAZQ4UO
#\\\|DBDIY3D3IFQQ7QW7LBPRGCHTSJKZ7XYKYEQKIO7T34533BKLESF \ / AMOS7 \ YOURUM ::
#\[7]JTCAWOPSOAUDWH76OFZGKSGRFKKSZTPCPNMQK5ROEC467FKINUCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
