# task: select-region zenka — clone of window-place, generalized for screenshot-rect selection

## context

`window-place` is an interactive GTK overlay zenka: it opens a translucent,
undecorated, draggable/resizable rectangle the user positions with the mouse,
then on commit either saves the result as a named window-placement profile
(used later to place a *different* real window) or replies with the raw
geometry. The drag/resize/draw/damping mechanics have nothing to do with
"placing a window" — they're a generic rectangle-selection UI. We're cloning
this into a new `select-region` zenka that generalizes the same UI to also
support picking an arbitrary screen rect for screenshot capture, without
`select-region` ever knowing the screenshot zenka exists — it only returns
coordinates. Some future caller (e.g. `screenshot`) calls `select-region.*`
to get a rect, then captures it itself.

**`window-place` must keep working completely unchanged.** Do not edit, move,
or delete anything under `src/window.place.*` or
`cfg/zenki/window-place/`. This is a clone, not a rename — the two
zenki coexist; `window-place` may be retired later once `select-region` is
proven, but that is a separate future task.

## style reference

read and follow: `data/ai-mem/kimi/coding-style.md`
also: `data/yaml/docs/protocol-7-coding-style.md`

since every file is being rewritten anyway, apply style fixes during the
clone (don't carry over old issues from window-place):
- lowercase comments, `[ word ]` bracket annotations not `( word )`
- regex delimiters: `m||` / `s|||`, never `/.../`
- never redeclare `$call` in `.cmd.` modules — it's already provided
- internal helper args: `my ( $a, $b ) = @ARG` not `( my $a, my $b ) = @_`
- `TRUE`/`FALSE` constants, never bare `1`/`0`, for boolean returns
- no `die` in internal helpers — `warn` + `return undef`

## naming convention

zenka dir: `select-region` (hyphenated, matches `window-place`'s own
zenka-dir/module-namespace split — see `[[topic-zenka-naming-cleanup]]`).
module namespace: `select.region.*` (dotted, mirrors `window.place.*`).
the `.cmd.` suffix is stripped for network routing same as everywhere else —
`select.region.cmd.foo` on disk is callable as `select-region.foo`.

## source files to read first

read every file under `src/window.place.*` and
`cfg/zenki/window-place/*` before writing anything — the clone
needs the full interaction model (drag, resize-edge classification, damping,
hover cursor, poll-based pointer fallback, key handling) intact. key files:
`window.place.init_code`, `.start`, `.open_window`, `.commit`, `.cancel`,
`.apply_geometry`, `.update_x11_state`, `.handler.draw`,
`.handler.button_press/release`, `.handler.motion`, `.handler.key_press`,
`.handler.scroll`, `.handler.poll_pointer`, `.handler.scr_rect_reply`,
`.classify_region`, `.cursor_for_region`, `.apply_drag`, `.adjust`,
`.damp.set_target`, `.damp.tick`, `.set_hover_cursor`,
`.cmd.place_window`, `.cmd.coords`, `.cmd.clear-profile`.

## what changes vs. a 1:1 clone

### 1. generalized instance state

rename the shared per-instance hash everywhere:
`$data{window}{place}{instances}` → `$data{select}{region}{instances}`.

add a `'kind'` field to every instance: `'window'` for the ported
window-placement flow, `'screenshot'` for the new rect-selection flow.
`commit` and `.handler.draw` branch on this field (see below) — everything
else (drag math, resize-edge classification, damping, hover cursor, poll
fallback, key handling) is identical regardless of kind and needs no
branching.

### 2. ported commands (renamed, behavior unchanged)

| new command | old command | notes |
|---|---|---|
| `select-region.window-placement` | `window.place.cmd.place_window` | sets `kind=>'window'` on the instance |
| `select-region.window-coords` | `window.place.cmd.coords` | unchanged: instant saved-profile lookup, else opens UI |
| `select-region.clear-window-profile` | `window.place.cmd.clear-profile` | unchanged |

these three keep 100% of their existing parsing (`caller=`/`profile=`/`tag=`
key=value or positional), `window.profile.save/load/delete` calls, and reply
formats. only the network-visible command name and the `kind` field are new.

### 3. new command: screenshot-rect selection

`select-region.screenshot-rect [name]` — single optional **positional**
argument (not `name=`; there's only one parameter here, so no key=value
prefix is needed — see `[[topic-zenka-naming-cleanup]]`-style precedent of
keeping single-param commands plain-positional).

flow (parallel to `window.place.start`, but simpler — no caller, no
window-profile persistence):
- generate a unique id, same `<[base.prng.chars-anum]>->(8)` pattern
- store instance: `{ 'kind' => 'screenshot', 'tag' => $name, 'reply_id' => $call->{'reply_id'} }`
- get pointer-monitor geometry the same way `window.place.start` does
  (`<[window.gtk.get_pointer_monitor_geometry]>`, falling back to
  `<x11.geometry>` / 1920x1080)
- compute initial geometry via `<[window.profile.calculate]>->({ profile => 'center', fallback => 'center', caller => $name // '', screen_x/y/w/h => ... })`
  — reuse the existing 'center' fallback profile rather than inventing a new
  default-sizing rule
- schedule `select.region.open_window` (the generalized clone of
  `window.place.open_window`) via the same 0-delay timer pattern
- return `{ 'mode' => qw| deferred | }`

### 4. generalized commit

`select.region.commit` (clone of `window.place.commit`) branches on
`$inst->{'kind'}`:
- `'window'`: unchanged — `window.profile.save`, reply with
  `x=.. y=.. width=.. height=.. profile=saved caller=.. tag=..`
- `'screenshot'`: no profile save. reply with
  `x=.. y=.. width=.. height=.. name=..` (omit `name=` if no tag was given).
  also record the result into the "last" trackers (see below).

both branches still: destroy the window if visible, cancel poll/damp timers,
delete the instance — that part is identical to today's `window.place.commit`.

`select.region.cancel` needs no kind-branching — cancellation behavior
(reply false 'cancelled', cleanup) is identical for both kinds.

### 5. "last coords" trackers

on every commit (either kind), update a single global tracker:
```perl
$data{select}{region}{last_commit} = {
    'kind' => $kind,    # 'window' or 'screenshot'
    'x' => $x, 'y' => $y, 'width' => $w, 'height' => $h,
    'tag' => $tag,      # caller (window) or name (screenshot), may be undef
};
```

on every `'screenshot'` commit, additionally update:
```perl
$data{select}{region}{last_image_coords}{'global'} = { x/y/width/height };
$data{select}{region}{last_image_coords}{'by_name'}{$tag} = { x/y/width/height }
    if defined $tag and length $tag;
```

on every `'window'` commit, additionally update:
```perl
$data{select}{region}{last_window_commit} = { x/y/width/height, 'caller' => $caller };
```
(window-kind "by name" lookups should go through the existing
`window.profile.load($caller)` — that's already durable disk storage and is
the correct source of truth for "last placement for this caller", not a new
in-memory dict.)

new `.cmd.` modules:
- **`select-region.last-coords`** — no params. returns
  `{ 'mode' => qw| true |, 'data' => "kind=$kind x=.. y=.. width=.. height=.. tag=.." }`
  from `last_commit`, or `{ 'mode' => qw| false |, 'data' => 'no selection committed yet' }`
  if nothing has been committed this session.
- **`select-region.last-window-coords [name]`** — optional positional name.
  if given, `<[window.profile.load]>->($name)`; if not found or not given,
  fall back to `last_window_commit` (in-memory, most-recent-regardless-of-caller).
  reply false if neither source has data.
- **`select-region.last-image-coords [name]`** — optional positional name.
  if given, look up `last_image_coords{'by_name'}{$name}`; if not given,
  use `last_image_coords{'global'}`. reply false if not found.

### 6. appearance differences

`select.region.handler.draw` (clone of `window.place.handler.draw`)
branches on `kind`:
- `'window'`: unchanged — fill `set_source_rgba( 0.0, 0.0, 0.24, 0.72 )`,
  title `[%s]` with `$inst->{'caller'}`
- `'screenshot'`: more translucent fill — `set_source_rgba( 0.0, 0.0, 0.24, 0.40 )`
  — and title `[screenshot]`, or `[screenshot:%s]` with `$inst->{'tag'}` if set

everything else in the draw handler (corner brackets, geometry readout,
font handling) is identical for both kinds.

`select.region.open_window`'s window title (`$window->set_title(...)`)
should similarly read `'select-region [window:%s]'` or
`'select-region [screenshot%s]'` depending on kind, replacing the old
hardcoded `'window.place [...]'` string.

## config files to create

clone `cfg/zenki/window-place/{os-dep,pm-dep,source,start,subroutine.white-list,start.cfg}`
into a new `cfg/zenki/select-region/` directory:
- `start`: update `modules.load` to load the `select.region.*`/`window.gtk`/
  `window.profile` modules under their new filenames; keep the
  `access.cmd.usr.cube = commands heart reload verify-instance * *.*` line
  (same self-access pattern window-place uses)
- `subroutine.white-list`: regenerate, don't hand-edit (see below)
- `start.cfg`, `os-dep`, `pm-dep`, `source`: copy as-is, only changing
  any literal `window-place`/`window.place` strings to `select-region`/`select.region`

after all modules exist, run `bin/dev/gen-sub-whitelist select-region` to
generate the whitelist — do not write it by hand.

## verification

run `bin/ptd -c` on every new module before considering it done.

manual test sequence (report exact `p7c` output for each):
1. `p7c select-region.window-placement caller=test-clone` — UI opens,
   drag/resize it, press Enter to commit — reply should match the old
   `window-place.place_window` format exactly
2. `p7c select-region.screenshot-rect demo-tag` — UI opens with the lower-
   alpha translucent fill and `[screenshot:demo-tag]` title, drag/resize,
   commit — reply should be `x=.. y=.. width=.. height=.. name=demo-tag`
3. `p7c select-region.last-image-coords demo-tag` — returns the rect from
   step 2
4. `p7c select-region.last-image-coords` — also returns the rect from step 2
   (it was the only screenshot commit, so it's both "global" and "by name")
5. `p7c select-region.last-window-coords test-clone` — returns the rect from
   step 1
6. `p7c select-region.last-coords` — returns whichever of steps 1/2 happened
   last, with the correct `kind=` field
7. confirm `window-place.place_window` (the original zenka) still works
   unchanged — this proves the clone didn't disturb it

## acceptance

- `window-place` zenka and all its src/config are byte-for-byte
  untouched (`git diff` shows zero changes under `src/window.place.*`
  and `cfg/zenki/window-place/`)
- all 7 verification steps above pass
- `bin/ptd -c` passes on every new module
- no `die` calls, no `/.../ ` regex delimiters, no redeclared `$call` in any
  new module

## dispatch

## kimi: clone window-place into a new select-region zenka per the spec
## above. read all window.place.* modules first to understand the existing
## interaction model before writing anything — the drag/resize/damping/
## hover-cursor mechanics carry over unchanged, only the command surface,
## instance 'kind' branching (commit + draw), and the new last-coords
## trackers are new. verify with bin/ptd -c after each module, then run
## the full manual test sequence and report the actual output of each
## p7c command. do not modify any window.place.* or window-place/* file.

#,,,,,,..,,,.,.,.,...,,.,,...,,,,,..,,,,.,,.,,..,,...,..,,..,,.,,,..,,,..,,,,,
#V5BL4343BW5R2DR4JHXHGN7FTFZ4ZCOZE5KJWJPIDKVDU6KQ5ZAA3CPYBOW4X6MXZUTJPQ27FWBW4
#\\\|TP3FJJG5O7YG6LBVVNLD4ISWDM4GKAWY47Z642LJYLKHTJKOJD4 \ / AMOS7 \ YOURUM ::
#\[7]5Z3VVGV6N3IKI57IKYZ4TGM66NXBFQQRHXELHU7H5M2Y7NYLMYCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
