# task: replace lerp constants with named base.curve lookups

## context

`data/web-root/vhosts/space.v7.ax/visualization.html` uses hardcoded lerp
multipliers throughout the animation loop (`* 0.07`, `* 0.08`, `* 0.05` etc).
these are magic numbers that make tuning require code edits and prevent the
attention state machine from dynamically adjusting animation feel.

this task replaces them with named curve lookups from a config block, making
all timing and easing data rather than code. base.curve signal shapes are
already available in the P7 system (`topic-base-curve-system.md` in memory).

## signatures note

do NOT add the single-line `#,,.,,,...` stub at end of any new files.
leave new files clean for the signing system.

## audit — lerp constants to replace

locate and name each of these in visualization.html:

| current | location (approx line) | proposed name |
|---------|------------------------|---------------|
| `* 0.07` | rotX/rotY zoom-target lerp (~683) | `CURVE_ZOOM_TARGET_ROT` |
| `* 0.07` | manualZoom lerp (~686) | `CURVE_ZOOM_TARGET_ZOOM` |
| `* 0.08` | targetZoom lerp (~722) | `CURVE_ZOOM_FOLLOW` |
| `* 0.06` | camX/Y/Z → selX/Y/Z (~695) | `CURVE_CAM_FOLLOW` |
| `* 0.05` | layerWeight lerp (~747) | `CURVE_LAYER_FADE` |
| `* 0.7`  | manualZoom kick on double-click (~1784) | `CURVE_ZOOM_KICK` |
| `* 0.3`  | touch drag sensitivity (~1911) | `CURVE_TOUCH_DRAG` |

verify line numbers against the actual file before editing.

## task

### 1. named curve config block

add a `CURVES` const object near the top of the script section (after the
existing constants like `CUBE_SIZE`, `FIELD_SPACING`):

```javascript
const CURVES = {
    CAM_FOLLOW:       0.06,   // camera lerp toward selection cursor
    ZOOM_FOLLOW:      0.08,   // zoom lerp toward target zoom
    ZOOM_TARGET_ROT:  0.07,   // rotation lerp toward zoom-click target
    ZOOM_TARGET_ZOOM: 0.07,   // zoom lerp toward zoom-click target
    LAYER_FADE:       0.05,   // layer weight lerp speed
    ZOOM_KICK:        0.70,   // immediate zoom kick fraction on double-click
    TOUCH_DRAG:       0.30,   // touch drag rotation sensitivity
    NODE_GLOW_PULSE:  0.90,   // glow pulse frequency (radians/sec)
};
```

### 2. substitute all occurrences

replace each hardcoded multiplier with its `CURVES.*` reference.
example: `rotX += (zoomTargetRotX - rotX) * 0.07`
becomes: `rotX += (zoomTargetRotX - rotX) * CURVES.ZOOM_TARGET_ROT`

also replace the glow pulse `* 0.9` in the sin expression with
`CURVES.NODE_GLOW_PULSE`.

### 3. add curve set switching stub

add a `setCurveSet(name)` function that swaps `CURVES` values from a
predefined `CURVE_SETS` map:

```javascript
const CURVE_SETS = {
    ambient: { CAM_FOLLOW: 0.03, ZOOM_FOLLOW: 0.05, LAYER_FADE: 0.03 },
    focus:   { CAM_FOLLOW: 0.08, ZOOM_FOLLOW: 0.10, LAYER_FADE: 0.07 },
    survey:  { CAM_FOLLOW: 0.05, ZOOM_FOLLOW: 0.07, LAYER_FADE: 0.05 },
};

function setCurveSet(name) {
    const set = CURVE_SETS[name];
    if (!set) return;
    Object.assign(CURVES, set);
}
```

this is the insertion point for the attention state machine to drive curve
switching when it emits a `curve_set` in its blend output.

### 4. wire to attention data (stub)

in `fetchAttentionData()` (added by the attention state machine task), after
storing `attentionData`, call `setCurveSet(attentionData.curve_set)` if present.
if the attention task is not yet complete, add the call as a comment stub.

## acceptance

- no bare `* 0.07` / `* 0.08` / `* 0.05` / `* 0.06` multipliers remain in
  the animation loop (grep confirms)
- `CURVES` object at top, all values matching original behavior
- `CURVE_SETS` map with ambient/focus/survey defined
- `setCurveSet('focus')` called in browser console visibly tightens camera
  follow speed — confirm by observation
- `setCurveSet('ambient')` visibly slows it down

#,,..,...,,..,,..,...,,.,,.,,,..,,,,.,.,,,.,.,..,,...,...,.,.,.,,,.,.,.,,,...,
#DHZOPOMI6OLDE2LDBBBH4I3RQKQ3KRYK35R2TLR3XO2HZXJI5IAUSWJVGLNWQH6LFLQI4P75AOEGW
#\\\|7ZZENLG3TDQDXJNRZOILGGMTRSE5PTZFXPTATLJ64TVQMIBCHYH \ / AMOS7 \ YOURUM ::
#\[7]MWXLSTXNSVRCK7HFO46NUNIDHPYZLHJEIE6DD527P2E55KPWJYAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
