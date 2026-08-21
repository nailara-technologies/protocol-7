# mpv / Tile / Window / X-11 / Universal Cross-Namespace Wiring Report

> Method: applied the `cross-namespace-wiring` context-template methodology using available tools (Glob/Grep/Read, parallel explore agents, and manual code inspection).  The template's native agent tools (`list_modules`, `dep_graph`, `tree_list`, `module_deps`) are not exposed through the MCP server yet, so the report is based on namespace sampling rather than exhaustive dependency graph extraction.

---

## 1. Connections Discovered

| Connection | Namespaces | Evidence | Value |
|---|---|---|---|
| **Geometry strings are parsed/formatted in at least 4 places** | mpv, tile, window-place, X-11, universal | `mpv.align-x/y/zoom`, `X-11.set_geometry` (`WxH+X+Y`), `X-11.move-window` (`id,x,y,w,h`), `window-place` drag geometry, `tile.get_geometry`, `universal` coordinate caching | High — one canonical geometry model reduces bugs and inconsistent syntax |
| **Opacity / fade-in / fade-out logic is scattered** | mpv, X-11, universal | `mpv.callback.fade_in` calls `X-11.set_opacity`; `X-11.fade_out` exists; `universal.handler.switch_fade` does its own 0→100 opacity loop | High — reuse `base.curve` + a shared opacity driver |
| **Window-ID assignment is done by both tile and universal** | tile, universal, X-11 | `tile.cmd.assign_window` reports IDs; `universal.cmd.set_window_id` receives them; `base.X-11.assign_window` exists | Medium — a single assignment/window-registry API would remove ambiguity |
| **GPU load handling exists in tile and X-11** | tile, X-11 | `tile.cmd.gpu_load_alert` triggers auto-speed; `X-11.cmd.gpu_load` collects stats | Medium — alerts and stats should share state instead of being separate surfaces |
| **Playlist fetching uses two names for the same content zenka reply** | mpv, universal | `mpv.get_playlist` asks `cube.content.get_list`; `universal.cmd.get_list` is a reroute to the same | Low/Medium — naming alignment helps caller understanding |
| **Idle-state query is already wired** | mpv, universal | `universal.callback.mpv_idle_check` calls `mpv.is_idle` | ✅ Already good — keep |
| **Theme / palette data is not shared** | mpv, window | mpv OSC colours live in `cfg/zenki/mpv/zenka.v7`; window colour themes live in YAML under `window.profile.color` | Medium — protocol-7 palette document exists but is not imported by either | 
| **Pause / resume coordination** | mpv, universal | `universal.cmd.report_paused` / `mpv.handler.event.pause/unpause` | ✅ Already wired — keep, but add `report-resumed` for symmetry |

---

## 2. Wiring Proposals (not yet implemented)

### 2.1 Shared geometry model (`base.geometry`)

**Problem**: mpv uses relative align/zoom; X-11 uses `WxH+X+Y` or comma fields; tile returns raw coordinates; window-place stores drag geometry hashes.  Callers must know which format each namespace expects.

**Proposal**: introduce `base.geometry` helpers:
- `base.geometry.parse` — accepts `WxH+X+Y`, `id,x,y,w,h`, or percentage strings and returns a normalised hash `{ x, y, w, h, right, bottom }`.
- `base.geometry.to_x11_string` — returns `WxH+X+Y`.
- `base.geometry.to_mpv_align` — converts absolute geometry to mpv `video-align-x/y` + `video-zoom`.
- `base.geometry.to_tile_coords` — returns `left top right bottom`.

**Callers to update**: `X-11.set_geometry`, `X-11.move-window`, `window-place` drag/commit, `tile.get_geometry`, `mpv.align-x/y/zoom`, `universal` coordinate cache.

### 2.2 Shared opacity fader (`base.X-11.fade` or `base.curve.opacity`)

**Problem**: `universal.handler.switch_fade`, `mpv.callback.fade_in`, and `X-11.fade_out` all manipulate `X-11.set_opacity` with their own timers/easing.

**Proposal**: add a small driver around `base.curve`:
- `base.X-11.fade.window(<w_id>, <from>, <to>, <ms>, [curve])`
- `base.X-11.fade.cancel(<w_id>)`

**Callers to update**: `universal.handler.switch_fade`, `mpv.callback.fade_in`, `X-11.fade_out`.

### 2.3 Single window-registry assignment API

**Problem**: `tile.assign_window` pushes window IDs; `universal.set_window_id` receives them; the semantics differ and `set_window_id` currently ignores the optional `tilename` argument.

**Proposal**: centralise in `base.X-11.assign_window` or a new `window.registry.assign`:
- One source of truth for "which zenka owns which window ID".
- Tile and universal become thin reroutes with validation.
- Fix the ignored `tilename` parameter or remove it from the signature.

### 2.4 Unify GPU stats and alerts

**Problem**: `X-11.gpu_load` is a query/subscription; `tile.gpu_load_alert` is an action that changes behaviour.  They do not share state, so a load alert may not know the current load.

**Proposal**: make `X-11.gpu_load` the canonical stats provider; `tile.gpu_load_alert` subscribes to it or reads the latest value instead of maintaining a separate counter.

### 2.5 Import protocol-7 palette into colour systems

**Problem**: mpv OSC colours and window YAML themes are hand-maintained separately.  The palette already exists in `data/gfx/palette/protocol-7-palette.md`.

**Proposal**: add a tiny loader `base.color.palette.load` that reads the palette document (or a derived YAML file) and returns named colours.  mpv and window-place can then refer to `palette.truth`, `palette.blacklight`, etc., instead of raw hex values.

### 2.6 Symmetric pause/resume reporting

**Problem**: universal has `report_paused` but no `report_resumed`.

**Proposal**: add `universal.cmd.report_resumed` (or make `report_paused` accept a state argument) so mpv's `unpause` event has a clean reroute target.

---

## 3. Promotion Candidates

These modules look generic enough to move out of their specific namespace, but promotion needs human approval because it touches white-lists and call sites.

| Module | Current namespace | Why promote | Blockers |
|---|---|---|---|
| `window.geometry.resolve` | `window.*` | Used by many zenki; pure geometry resolution with no GTK-specific code | Would need to keep a backward-compatible `window.geometry.resolve` alias |
| `window.profile.calculate` | `window.*` | Geometry profile math is useful for any zenka that needs window placement | Depends on `window.profile.*` state |
| `tile.calculate_coordinates` | `tile.*` | Coordinate math is reusable by window-place and X-11 | Tightly coupled to `tile.subconfig` |
| `mpv.handler.audio_fade` | `mpv.*` | Generic curve-driven value transition; could drive opacity, brightness, etc. | Currently wired to `mpv.current.volume` |
| `base.X-11.assign_window` | already `base.*` | Good — should be the canonical window registry | None |

---

## 4. Duplication Hotspots

| Pattern | Namespaces | Suggested shared home |
|---|---|---|
| Geometry parsing / formatting | X-11, tile, window-place, mpv | `base.geometry` |
| Opacity fade loops | X-11, mpv, universal | `base.X-11.fade` |
| GPU load countermeasures | tile, X-11 | `X-11.gpu_load` as source + `tile.gpu_load_alert` as consumer |
| Timer-based skip/slowdown | mpv (autoskip), universal (slow_down), web-browser (slow_down) | `base.timer.rate_limit` or similar |
| YAML colour theme loading | window.profile.color, (future) mpv OSC theme | `base.color.theme` |
| Window visibility stacking | tile, universal | `base.X-11.stack` or `window.manager` |

---

## 5. Left Alone (for now)

| Pattern | Reason |
|---|---|
| `mpv.command` vs `mpv.pipe_cmd_raw` | Both serve different IPC paths; the duplication is intentional and documented in §3.4 of the upgrade plan. |
| Per-zenka rescaling in mpv | Tightly coupled to mpv/ffmpeg; not generic. |
| `window-place` interactive GTK UI | Specific to placement workflow; not reusable as a library. |
| `universal` child lifecycle | Orchestration logic is universal-specific. |

---

## 6. Recommended Implementation Order

1. **Wire existing unused shared utilities first** (no new code):
   - Replace inline geometry parsing in `X-11.move-window` and `window-place` with calls to `window.geometry.resolve` / `window.profile.calculate` where possible.
   - Route `tile.assign_window` and `universal.set_window_id` through `base.X-11.assign_window`.

2. **Create shared modules second**:
   - `base.geometry` (parse/format helpers).
   - `base.X-11.fade` (opacity curve driver).
   - `base.color.palette` (palette loader).

3. **Promote after approval**:
   - Move geometry/profile math to `base.geometry.*`.
   - Generalise `mpv.handler.audio_fade` to `base.curve.transition`.

4. **Connect cross-zenka features**:
   - Add `universal.report_resumed`.
   - Make `tile.gpu_load_alert` consume `X-11.gpu_load`.

---

## 7. Relation to the mpv Command Upgrade Plan

The wiring report and the command-upgrade plan are two views of the same cleanup:

- **Upgrade plan** focuses on the *surface* (command names, symmetry, new getters/setters).
- **Wiring report** focuses on *shared internals* (geometry, fade, palette, window registry).

Both should be executed in the same migration window so that new commands (e.g. `get-align-x`, `fullscreen`) can reuse the shared geometry/fade layers instead of duplicating them.

---

*End of wiring report.  Next step: human review of promotion candidates and priority order.*

#,,,,,..,,..,,..,,,,,,,.,,...,,.,,...,.,,,..,,..,,...,...,.,.,.,,,..,,,,,,,..,
#MSPYFUGEXE66YHXOX2QDSSN76GYRCAQB5ED2FSFVL3NBN325WHRS3K3YU3GUO4SADI7ILLLQTWIG2
#\\\|IX6AIIUZV6N352IYBBJPCDDAV55RJOVLT6M3GYYOXOBP3RIUZ5O \ / AMOS7 \ YOURUM ::
#\[7]KQ27LBPW3X5KOAE6IRNTUFVP3BS3C5Z24ZSM77LC64KZ2JOI62AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
