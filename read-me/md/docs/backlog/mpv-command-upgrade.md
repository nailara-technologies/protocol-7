# mpv Zenka Command Upgrade Plan

> Status: planning document — no code changes committed yet.  
> Goal: review the mpv zenka command surface (plus the tile, window-place, X-11 and universal namespaces it touches) for namespace coherence, symmetry, and modern convention alignment, then propose a low-risk migration.

---

## 1. Executive Summary

The mpv zenka is functional: playback, playlist handling, volume/speed control, OSC theming, idle logo, and rescaling all work.  However, the command namespace accumulated several style mixes and missing symmetric pairs:

- **Naming is inconsistent**: about half of `mpv.cmd.*` use kebab-case (`set-volume`, `pause-toggle`), the other half use `snake_case` (`clear_playlist`, `drop_buffers`).
- **Colour values are fragile**: the config parser strips `#` from `key=value` lines, so the `--script-opts` colour string is now built via a separate `mpv.hash` helper and a composed `mpv.script_opts` variable.
- **Several useful read/write pairs are missing**: `mute`/`unmute`, `get-loop`/`set-loop`, `get-zoom`, `fullscreen`, current subtitle/audio track queries, etc.
- **Neighbouring namespaces share the same inconsistencies**: `tile`, `window-place`, `X-11`, and `universal` also mix kebab/snake/plain naming and have asymmetric command sets.

This document proposes a cleanup that keeps existing commands working (via aliases during a transition) while introducing canonical kebab-case names, symmetric pairs, and a clearer cross-zenka API.

---

## 2. Current mpv Command Surface

| Command | Current style | Notes |
|---|---|---|
| `play`, `stop`, `quit`, `next`, `prev`, `pause`, `resume`, `seek`, `pos`, `loop`, `fade`, `zoom`, `version`, `pid`, `command` | plain | stable, keep as-is or alias |
| `append`, `append-play` | plain / kebab | pair already exists |
| `get-volume`, `set-volume`, `get-speed`, `set-speed`, `pause-toggle`, `align-x`, `align-y`, `current-file`, `current-vo`, `current-ao`, `current-hwdec`, `is-idle`, `shuffle-playlist` | kebab | good modern convention |
| `clear_playlist`, `show_playlist`, `reload_playlist`, `playlist_update`, `change_subname`, `drop_buffers`, `pipe_cmd_raw`, `start_autoskip`, `stop_autoskip`, `autoskip_interval` | snake_case | **primary cleanup target** |
| `setting` | plain | generic get/set wrapper |

All commands are exposed through `cfg/zenki/mpv/subroutine.white-list` and `access.cmd.usr.cube`.

---

## 3. Naming Convention Audit

### Proposed canonical rule

| Layer | Canonical style | Rationale |
|---|---|---|
| User-facing `*.cmd.*` | **kebab-case** | Matches `cube.clear-cons`, reduces Shift-key use, consistent with mpv property names |
| Internal `*.handler.*`, `*.callback.*`, `*.init_*` | snake_case | Perl convention, not user-typed |
| Config/state variables | snake_case dotted | Already dominant (`mpv.current.volume_target`) |
| mpv property mirrors | kebab-case | mpv itself uses `core-idle`, `video-aspect-override`, etc. |

### High-priority renames (old name → new name, old kept as alias)

| Old (snake_case) | New (kebab) | Why |
|---|---|---|
| `clear_playlist` | `clear-playlist` | reads as one command |
| `show_playlist` | `show-playlist` | pair with `clear-playlist` |
| `reload_playlist` | `reload-playlist` | playlist family consistency |
| `playlist_update` | `playlist-update` | remove underscore |
| `change_subname` | `change-subname` | user command |
| `drop_buffers` | `drop-buffers` | matches mpv command style |
| `start_autoskip` | `start-autoskip` | pair with `stop-autoskip` |
| `stop_autoskip` | `stop-autoskip` | pair with `start-autoskip` |
| `autoskip_interval` | `autoskip-interval` or `get-autoskip-interval` | clearly a query |
| `pipe_cmd_raw` | `pipe-cmd-raw` or `raw-pipe-command` | clearer, avoids `_cmd_` stutter |

### Commands to keep unchanged

- Plain verbs: `play`, `stop`, `quit`, `next`, `prev`, `pause`, `resume`, `seek`, `loop`, `fade`, `zoom`, `version`, `pid`.
- Already-kebab pairs: `get-volume`/`set-volume`, `get-speed`/`set-speed`, `align-x`/`align-y`, `append-play`, `pause-toggle`, `current-file`, `current-vo`, `current-ao`, `current-hwdec`, `is-idle`, `shuffle-playlist`.
- `setting` can stay as a convenience wrapper, but see §5 for a possible `get-setting`/`set-setting` split.

---

## 4. Symmetry & Completeness Gaps

### Missing getters for set-only commands

| Set command | Missing getter | Note |
|---|---|---|
| `zoom` | `get-zoom` | returns `video-zoom` |
| `align-x` / `align-y` | `get-align-x` / `get-align-y` | returns `video-align-x`/`y` |
| `loop` | `get-loop` | returns `loop-file`/`loop-playlist` state |
| `fade` | `get-fade-target` or `get-volume-target` | returns target volume of active fade |

### Missing toggle pairs

| Area | Proposed commands | Maps to mpv property |
|---|---|---|
| Mute | `mute`, `unmute`, `mute-toggle` | `mute` |
| Fullscreen | `fullscreen`, `fullscreen-toggle` | `fullscreen` |
| Subtitles | `sub-visible`, `sub-cycle`, `sub-reload` | `sub-visibility`, `sub`, `sub-reload` |
| On-screen stats | `stats-toggle` | `stats-overlay` script message |
| Pause | `pause-force` (already have `pause`, `resume`, `pause-toggle`) | — |

### Missing track/media queries

| Proposed | Purpose |
|---|---|
| `current-sub` | current subtitle track id/lang |
| `current-audio` | current audio track id/lang |
| `current-chapter` | current chapter index/title |
| `get-playlist` | return raw playlist (currently only `show_playlist` text and `reload_playlist` fetch) |
| `playlist-add`, `playlist-remove`, `playlist-move` | richer playlist editing |

### Raw-command surface clarity

- `command` — JSON-encodes and sends a command to mpv IPC (blacklists `run`/`hook`/`subprocess`).
- `pipe_cmd_raw` — writes a raw string to the IPC socket (same blacklist).

**Proposal**: keep `command` as the generic JSON path; rename `pipe_cmd_raw` → `pipe-cmd-raw` and document that it bypasses JSON encoding.

---

## 5. Proposed New / Upgraded Commands

Priority reflects usefulness without duplicating the generic `setting` command.

| Priority | Command | Type | Description |
|---|---|---|---|
| High | `clear-playlist` | rename alias | clear playlist except current |
| High | `show-playlist` | rename alias | display playlist |
| High | `reload-playlist` | rename alias | re-fetch playlist from content zenka |
| High | `playlist-update` | rename alias | alias for `reload-playlist` |
| High | `drop-buffers` | rename alias | call mpv `drop-buffers` |
| High | `change-subname` | rename alias | change subname and reload playlist |
| High | `start-autoskip` / `stop-autoskip` / `autoskip-interval` | rename aliases | timer-based skipping |
| High | `get-zoom` | new getter | returns `video-zoom` |
| High | `get-align-x` / `get-align-y` | new getters | returns alignment values |
| Medium | `mute` / `unmute` / `mute-toggle` | new toggles | mute control |
| Medium | `fullscreen` / `fullscreen-toggle` | new toggles | fullscreen control |
| Medium | `get-loop` | new getter | returns loop state |
| Medium | `get-fade-target` | new getter | active fade target volume |
| Medium | `current-sub` / `current-audio` / `current-chapter` | new queries | track/chapter info |
| Medium | `get-playlist` | new query | raw playlist JSON/array |
| Low | `playlist-add` / `playlist-remove` / `playlist-move` | new edit cmds | finer playlist control |
| Low | `sub-visible` / `sub-cycle` / `sub-reload` | new subtitle cmds | subtitle convenience |
| Low | `stats-toggle` | new utility | toggle stats overlay |

---

## 6. Settings Map Expansion

`src/mpv.init_settings_map` defines validated aliases for `mpv.cmd.setting`.  Current aliases cover video geometry, audio delay, and basic colour controls.  Proposed additions:

| Alias | mpv property | Type / range |
|---|---|---|
| `sub-delay` | `sub-delay` | float `-42..42` |
| `sub-scale` | `sub-scale` | float `0..10` |
| `sub-pos` | `sub-pos` | int `0..100` |
| `sub-visibility` | `sub-visibility` | `yes\|no` |
| `audio-device` | `audio-device` | string |
| `audio-pan` | `audio-pan` | float `-1..1` (per channel) |
| `deinterlace` | `deinterlace` | `no\|yes\|auto` |
| `cache` | `cache` | `no\|auto\|yes` or size string |
| `framedrop` | `framedrop` | `no\|vo\|decoder` |
| `hwdec-override` | `hwdec` | string, validated against `no\|auto\|vaapi\|vdpau\|nvdec` |
| `video-rotate` | `video-rotate` | int `0..360` or `no` |

These keep the existing `setting` wrapper useful while avoiding raw `command` for common adjustments.

---

## 7. Cross-Zenka Coherence

The mpv zenka does not exist in isolation; it is orchestrated by `universal`, positioned by `tile`/`window-place`, and rendered by `X-11`.  All four namespaces should be cleaned together so the same command style applies everywhere.

### 7.1 `tile`

Current command style is roughly half snake, half kebab.

**Proposed canonical renames (aliases)**:

| Old | New |
|---|---|
| `add_overlay` | `add-overlay` |
| `remove_overlay` | `remove-overlay` |
| `assign_window` | `assign-window` |
| `get_geometry` | `get-geometry` |
| `get_coordinates` | `get-coordinates` |
| `get_subconfig` | `get-subconfig` |
| `get_tile_color` | `get-tile-color` |
| `get_underscan` | `get-underscan` |
| `gpu_load_alert` | `gpu-load-alert` |
| `show_intent` | `show-intent` |
| `size_hint_x` / `size_hint_y` | `size-hint-x` / `size-hint-y` |
| `sort_layers` | `sort-layers` |

**Missing symmetric commands**:
- `clear-overlays`, `list-overlays`
- `unassign-window`, `get-assigned-windows`
- `set-geometry`, `set-coordinates`, `set-layer` (or document that these are write-once via set-up)
- `previous-group`, `list-recent-groups`
- `enable-polling` / `disable-polling` / `polling-status`

**Ambiguities to resolve**:
- `base-group` returns the fallback group; rename concept to `fallback-group` or document clearly.
- `show-active` returns one name, `show-groups` lists all; consider `current-group` / `list-groups`.
- Param notation is inconsistent (`<tile_group_name[s]>` vs `<tile-group[s]>`); standardise on kebab in docs.

### 7.2 `window-place` / `window`

- The public command `place_window` should be `place-window`.
- Config keys mix `font.face`, `font-size.margin`, `gtk.main_running`, `gtk.inited`; standardise to kebab: `font.face` (acceptable), `gtk.main-running`, `gtk.initialized`, profile keys `x-pct`, `y-pct`, etc.
- `window.gtk.profile.apply` actually applies a geometry hash, not a profile; rename to `window.gtk.geometry.apply`.
- Add `window.profile.delete` / `window.color.delete` for CRUD symmetry.

### 7.3 `X-11`

`X-11` has the largest command surface and the most style mixing.

**Proposed canonical renames (aliases)**:

| Old | New |
|---|---|
| `bg_color` | `bg-color` |
| `fade_out` | `fade-out` |
| `get_display` | `get-display` |
| `get_driver` | `get-driver` |
| `get_geometry` | `get-geometry` |
| `get_mode` | `get-mode` |
| `get_opacity` | `get-opacity` |
| `get_orientation` | `get-orientation` |
| `get_params` | `get-params` |
| `get_pointer_scr_rect` | `get-pointer-screen-rect` |
| `get_screen_size` | `get-screen-size` |
| `get_window_title` | `get-window-title` |
| `get_wm_name` | `get-wm-name` |
| `get_xauth_data` | `get-xauth-data` |
| `get_xorg_pid` | `get-xorg-pid` |
| `gpu_load` | `gpu-load` |
| `keep_above` / `keep_below` | `keep-above` / `keep-below` |
| `mouse_over_coords` | `mouse-over-coords` |
| `move-window` | already kebab |
| `raise-window` / `lower-window` | already kebab |
| `screen_size_ranges` | `screen-size-ranges` |
| `set_geometry` | `set-geometry` |
| `set_gravity` | `set-gravity` |
| `set_mouse_pos` | `set-mouse-pos` |
| `set_opacity` | `set-opacity` |
| `set_screen_size` | `set-screen-size` |
| `show_size_list` | `show-size-list` |
| `subscribe-screen-change` | already kebab |

**Asymmetries to fix**:
- `hide-window` / `unhide-window` → `hide-window` / `show-window`.
- `dpms-blanking-set` → `dpms-blanking-enable` to pair with `dpms-blanking-disable`.
- Add `start-slideshow` as explicit counterpart to `stop-slideshow`.
- Add `unsubscribe-screen-change`.
- Add `fade-in` to pair with `fade-out`.
- Add `keep-normal` or `clear-keep` to undo `keep-above`/`keep-below`.

**API clarity**:
- `set-geometry` uses `WxH+X+Y`; `move-window` uses `id,x,y,w,h`.  Either pick one format or rename to `set-geometry-string` vs `set-geometry-fields`.
- `get-orientation` returns `landscape`/`portrait` while `rotate-screen` accepts `left/right/normal/inverted[-x|-y]`.  Align vocabularies or rename `get-orientation` → `get-screen-aspect`.

### 7.4 `universal`

The `universal` zenka is the orchestrator; small surface, large state.

**Naming fixes**:
- `start-anim_running`, `start-anim_timeout`, `stop_start-anim` mix hyphen and underscore.  Pick one: `start_anim_running` / `start_anim_timeout` / `stop_start_anim` (internal), or `start-anim-running` / `start-anim-timeout` if state keys move to kebab.
- Config drift: `universal.cfg.self_restart_delay` in config vs `universal.cfg.self_restart_timeout` in code.  Standardise on one key.
- Fix typo: `playlist update initated` → `playlist update initiated`.

**Missing symmetric commands**:
- `report-resumed` to pair with `report_paused`.
- `speed-up` / `resume-normal` to pair with `slow_down`.
- `get-window-id` to pair with `set_window_id`.
- `stop` / `shutdown` graceful stop.
- `playlist-clear` / `playlist-reset` to pair with `playlist_update`.

**Ambiguities to resolve**:
- `set_window_id` accepts `[tilename]` but ignores it; remove the parameter or implement it.
- `slow_down` with no argument enables auto mode; document or add `slow-down-auto`.
- `start-anim_timeout` is used both for splash timeout and for `switch_timeout`; separate the concepts.

---

## 8. Migration Plan

1. **Phase 1 — alias + document** (safe, backward-compatible)
   - Add kebab-case command modules for every snake_case user command.
   - Make the old snake_case module a thin wrapper/alias to the new kebab-case module.
   - Update `subroutine.white-list` and `access.cmd.usr.cube` to expose both names.
   - Add the new getters/toggles as fresh modules.

2. **Phase 2 — internal callers migrate**
   - Update `universal`, `tile`, and any other zenki that call snake_case mpv/tile/X-11 commands to use the canonical kebab names.
   - Update documentation and the `commands` help text.

3. **Phase 3 — deprecation**
   - After a transition period, remove the snake_case aliases from `subroutine.white-list`.
   - Keep internal handler/callback names in snake_case (they are not user-typed).

4. **Phase 4 — expand settings**
   - Extend `mpv.init_settings_map` with the new aliases from §6.
   - Add the missing cross-zenka commands from §7.

---

## 9. Notes on the Colour / Script-Opts Fix

Because the protocol-7 config parser strips `#` to end-of-line on every `key=value` line, the mpv colour values can no longer be stored with a literal `#`.  The current working approach is:

- `cfg/zenki/mpv/hash` — a one-byte file containing `#`.
- `mpv.hash = [base.file.read:<system.root_path>/cfg/zenki/mpv/hash]` — loads the `#` after parsing.
- `mpv.script_opts` — composes the full `--script-opts=...` string using `<mpv.hash><mpv.osc_bg_color>` to build valid `#RRGGBB` hex values.
- `mpv.params` passes `--script-opts=<mpv.script_opts>`.

Any future OSC option that needs a `#` prefix should follow the same pattern.

---

## 10. Appendix: Current mpv Commands Quick Reference

| Category | Commands |
|---|---|
| Lifecycle | `play`, `stop`, `quit`, `next`, `prev`, `pause`, `resume`, `pause-toggle` |
| Playlist | `append`, `append-play`, `clear_playlist`, `shuffle-playlist`, `reload_playlist`, `playlist_update`, `show_playlist`, `change_subname` |
| Volume / Speed | `get-volume`, `set-volume`, `get-speed`, `set-speed`, `fade` |
| Geometry | `zoom`, `align-x`, `align-y` |
| Queries | `pos`, `pid`, `version`, `is-idle`, `current-file`, `current-vo`, `current-ao`, `current-hwdec` |
| Autoskip | `start_autoskip`, `stop_autoskip`, `autoskip_interval` |
| Utility | `command`, `pipe_cmd_raw`, `drop_buffers`, `setting`, `loop`, `seek` |

---

*End of plan.  Next step is user review of priorities before implementing Phase 1.*

#,,..,,.,,,,,,,..,,,,,,,.,,..,.,,,.,.,...,,,.,..,,...,...,...,,..,,,.,.,,,..,,
#D5WGLF4DGLPK36PF6RVKC3P62DC7BLSUNU2FT3VHR3JLQF5UOHW4MNCRHQW7VWE75KCQVZ4AHXAZQ
#\\\|MFJF5BWSW423HMJO2WC6IVXWZNEXLRU6D5LUZA2Z5ITDIRPG7PX \ / AMOS7 \ YOURUM ::
#\[7]L4TKOT5DTFZVRDDK4V4JS7OT4NYG6B7Z5UGKBA65YLKDMC3JEUDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
