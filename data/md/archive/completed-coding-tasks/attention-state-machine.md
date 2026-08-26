# task: attention state machine — skeleton + first states

## context

the visualization has a growing set of navigation modes, camera targets, and
layer weight states. currently these are scattered ad-hoc across the JS.
this task introduces an `attention` state machine as a structured module in
the web zenka (`src/plugin.web.attention.*`) that centralizes this logic.

the attention machine consumes: selection state, cursor position, zoom level,
layer weights. it emits: a current parameter blend (camera follow target,
zoom envelope hint, layer weight overrides, active curve set name).

## signatures note

do NOT add the single-line `#,,.,,,...` stub at end of any new files.
leave new files clean for the signing system.

## architecture

### state definition

each state is a named hashref with:
- `name` — identifier (e.g. `ambient`, `single-focus`, `group-view`)
- `camera_target` — `'selection'`, `'group-centroid'`, `'free'`, `'orbit-field'`
- `zoom_envelope` — `{ min, max, preferred }` hint for camera
- `layer_overrides` — hashref of layer name → weight multiplier
- `curve_set` — name of base.curve profile to activate
- `follow_speed` — camera lerp rate override (undef = default)
- `transition_budget` — seconds to blend into this state

### state stack

- `push_state($name, $params)` — enter a sub-state, preserve parent
- `pop_state()` — return to parent state
- `switch_state($name, $params)` — replace current state (no stack push)
- `blend_states($a, $b, $t)` — interpolate two parameter sets at ratio t

### first states to implement

**`ambient`** — default idle, no selection
- camera_target: `orbit-field`
- zoom: preferred 1.0
- layer_overrides: all at base weight
- curve_set: `ambient`
- follow_speed: 0.03 (slow drift)

**`single-focus`** — one node selected
- camera_target: `selection`
- zoom: preferred 2.5
- layer_overrides: `orbital-self` × 1.2, `orbital-known` × 0.6
- curve_set: `focus`
- follow_speed: 0.08

**`group-view`** — multiple nodes selected or formation detected
- camera_target: `group-centroid`
- zoom: computed from bounding volume of group
- layer_overrides: all orbital layers × 1.0
- curve_set: `survey`
- follow_speed: 0.05

### output

`plugin.web.attention.blend` returns current blended parameter set as hashref,
called each render tick from the web zenka or from JS via a `/attention.json`
endpoint (7s poll, same pattern as `/templates.json`).

## modules to create

- `plugin.web.attention.init_code` — initialize state registry and stack
- `plugin.web.attention.states` — state definitions hashref
- `plugin.web.attention.push_state` — push onto stack
- `plugin.web.attention.pop_state` — pop from stack
- `plugin.web.attention.switch_state` — replace top
- `plugin.web.attention.blend` — compute current output blend
- `plugin.web.attention.cmd.set-state` — p7c command interface

## visualization.html integration (stub only)

add a `fetchAttentionData()` function matching `fetchTemplateData()` pattern.
poll `/attention.json` every 7s. store result in `attentionData`.
do NOT wire it into rendering yet — just confirm the fetch works.
add a stub `attention.json.tmpl` that calls `plugin.web.attention.blend`.

## acceptance

- `p7c plugin.web.attention.cmd.set-state single-focus` changes state
- `p7c plugin.web.attention.blend` returns valid parameter hashref
- `/attention.json` endpoint returns JSON with current blend
- JS fetches it without errors (check browser console)
- state stack push/pop preserves parent parameters

#,,,,,,..,,.,,.,,,..,,.,,,...,,,,,.,.,,,.,.,,,..,,...,...,...,,..,.,,,,.,,,,,,
#XO4SH7NAPOOYDMB73SPDSDVGH3IPER6GJ47NTSRWARKVUJG3XNWAYCMJO4ONFM6FMAUKF7XZA7MCQ
#\\\|3QPWPLMFX2D7Z7IVKPLMNMQTG3FYIUMATLKXZCNVDQNFQZO3M7C \ / AMOS7 \ YOURUM ::
#\[7]CF7URIGXAU7LEUZJNN4SXYM7RZYB2GXCEPPNMQMMTQI2HA7TXABY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
