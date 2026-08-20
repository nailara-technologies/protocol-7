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
Currently `src/window.place.*` is a singleton: per-request state
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

**API contract LANDED 2026-06-16:**

Path A (standalone oracle) was already working — client calls
`window-place.place_window caller=X` and gets geometry back.

Path B (tile-integrated) API contract is now implemented:
- `window.place.start` accepts a generic opaque `tag=X` param (stored
  in instance; window-place stays agnostic — no tile semantics baked in)
- `window.place.commit` echoes `tag=X` in reply_args whenever set; tag
  also flows through the `reply_id`-based deferred reply, giving any
  handler-based caller request correlation for concurrent placements
- `tile.handler.receive_placement` (new) — receives the reply from
  window-place, parses tag+geometry, stores into `<tile.coordinates>`
  with `intent_authored => TRUE` marker; existing `get_geometry` /
  `get_coordinates` serve intent-first entries transparently since they
  only read `left/top/right/bottom`
- `tile.cmd.show_intent` (new) — lists all intent-first entries for
  inspection via `p7c tile.show_intent`

**Path B test invocation:**
```
p7c window-place.place_window \
  'caller=tile reply_handler=tile.handler.receive_placement tag=mpv'
# drag window to position, press Enter to commit
p7c tile.show_intent
```

**Next — Phase 2 (tile fall-through):**
Modify `tile.cmd.get_geometry` to fall back to window-place when no
configured entry exists: return `{mode => deferred}`, call
`window-place.place_window caller=tile reply_handler=...
tag=<zenka_name>`, store `reply_id` to complete the original caller's
reply once `tile.handler.receive_placement` is triggered. Same deferred
pattern window-place itself uses.

---

**2026-06-24 — self-referential startup deadlock fixed; drag/resize
freeze root-caused and fixed; keyboard drift still open; Weston
multi-monitor constrain bug precisely characterized**

**Startup deadlock (FIXED, commit `2ba903b7c`):** `window-place` is
itself the `tile` zenka, so its own startup geometry fetch
(`base.X-11.get_geometry`, blocking `readline()`) routed back to itself
through cube — but it can't service that request while blocked waiting
on it, deadlocking forever the first time its own `tile.coordinates`
entry was missing (which triggers `tile.cmd.get_geometry`'s deferred
interactive-placement fallback instead of an immediate reply). Fixed via
new async helpers `base.X-11.get_geo_async` +
`base.X-11.handler.geo_reply`/`geo_fallback_reply`, and
`window.place.startup`/`.geo_ready` replacing the blocking calls in the
start file. General lesson: **any zenka that might query itself through
cube needs an async-callback path, not a blocking one** — a blocking
self-query can never resolve, deferred-or-not.

**Drag/resize freeze (FIXED, commit `6cb99b0c8`):** see
[[feedback-weston-move-unreliable-use-compositor-grab]] for the full
investigation and fix (switch to `begin_move_drag`/`begin_resize_drag`
compositor grabs instead of plain `move()`/`resize()`). Also fixed in
the same pass: HUD readout was showing stale tracked geometry instead of
live widget state during an active resize (`window.place.handler.draw`),
and the readout wasn't refreshing continuously during a grab at all
since Weston only requests a repaint at grab start/end, not
continuously (`window.place.handler.poll_pointer` now forces a redraw
every tick).

**Keyboard move/resize drift — still UNRESOLVED.** `window.place.adjust`
(arrow-key stepping) has the identical "tracked state advances past
where the window actually stopped" bug as the old mouse-drag freeze, but
the mouse fix (compositor grabs) doesn't transfer — grabs need a real
button-press serial, keyboard can't trigger one. Two read-back attempts
both failed (see [[feedback-weston-move-unreliable-use-compositor-grab]]
"what did NOT work" section) — `$window->get_position()`/`get_size()`
themselves are unreliable for this in this environment, not just a
timing issue. Needs a fix that bypasses GTK's own position cache
entirely (eg. direct X11 protocol query) — not yet attempted.

**Weston multi-monitor constrain bug — precisely characterized, NOT
fixable from our code, confirmed via two independent code paths.**
On a real 3-monitor host setup with an irregular/staggered layout (one
monitor offset at x=1062 not aligned with anything else), both
`window.place.adjust` (keyboard) and the raw X11 zenka's `move-window`
command hit a boundary that doesn't correspond to the window's actual
current monitor — it uses the **primary monitor's bounds** (both height
and left edge) regardless of which monitor the window is really on.
Confirmed by removing the 3rd monitor entirely (clean `xrandr --query`
snapshot taken *during* the test, not after): with just 2 simple
top-aligned monitors, the bug disappears completely. This isolates it
to Weston's own multi-monitor constrain logic mishandling non-trivial
topologies — not a bug in `<X-11.monitors>` (verified byte-for-byte
accurate against `xrandr` independently), not in window-place, not in
the X-11 zenka. Don't chase this further in our code if it recurs;
it's a platform limitation tied specifically to irregular monitor
offsets, same category as [[feedback-wslg-deiconify-limitation]].

**Process note:** several "platform limitation, can't fix" conclusions
in this session were premature and walked back after pushback —
worth remembering that "it used to work" is strong evidence against a
platform-limitation explanation, and git-history bisection (`git log
--oneline -- <file>`, diffing each candidate commit) found the real,
fixable regression (`06c710952`, an unrelated ticker fix that reordered
`move()`/`resize()` in a function window-place's drag tick also calls)
when guessing at new fixes had repeatedly failed. Don't accept "platform
limitation" without testing the actual mechanism (eg. the xrandr
before/after snapshot above) when the user says something regressed.

#,,,.,.,.,,,,,.,,,,,.,,,.,.,.,.,.,,..,,,,,..,,..,,...,...,.,,,..,,,.,,.,.,..,,
#RUY7DVQ3I5Q225FTA5O3THG5FP6Q3GS2LXQDY2WJ5IQOE4IM24H7C65PNEWSM4GQPWI7MECCGBC6C
#\\\|X6F3TSG6YUQDQMCW35MIRCBAXY5LJ4GJSVQI7HF4IFENTYVQTDD \ / AMOS7 \ YOURUM ::
#\[7]7N2HSQDDMTUEDDQQ6BZOXTL2LNMYIGM4KEUCL3TVHRI6UZLM6GAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
