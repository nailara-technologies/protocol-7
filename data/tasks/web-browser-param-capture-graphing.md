# web-browser zenka: JS param-capture, named graph templates, watchers

## what this is

A debug-infrastructure upgrade to the web-browser zenka, motivated by the
unresolved zoom-momentum-reversal bug in
`data/web-root/vhosts/space.v7.ax/visualization.html` (see
[[topic-zoom-jump-debug-instrumentation]]), but scoped as general-purpose
visibility tooling, not a one-off fix for that bug. Design was worked out
conversationally across session 2bf5be89 (console-capture root-cause) and
this session; nothing below is implemented yet.

## background: why this came up

The existing `web-browser.console_capture.*` pipeline (js-injection ->
`p7cons` message handler -> per-view ring buffer, LANDED+verified in
2bf5be89) was used to add a `[zoom-jump]` debug block to
`visualization.html` gated on `abs(dz) > 0.02 || rel > 0.03` per frame.
The bug was reproduced live but **nothing logged**. Root cause of the
non-log: `zoom` is eased every frame via
`zoom += (targetZoom - zoom) * CURVES.ZOOM_FOLLOW`, so each frame's delta
stays under the jump threshold even while the value drifts substantially
over a sustained drag+wheel-zoom, driven by a velocity-coupled offset
(`velocityZoomOffset = -speedFactor * 0.135`) that pulls `zoom` away from
`manualZoom` during motion and eases back when velocity decays — reading
visually as a "momentum reversal" without ever being a discontinuous jump.
This ruled out the two prior theories (untracked state mutation; pure
`calcRangeAlpha` crossfade illusion) and pointed at a third: the
velocity-responsive zoom offset itself, working as coded but perceptually
surprising when accumulated over a long drag.

That in turn motivated: instead of hand-rolling one more bespoke
threshold-gated console.log block per bug, build reusable capture +
graphing infra so future investigations (this bug and others) get
continuous visibility into named variables' evolution over time, not a
single-shot jump detector.

## design (agreed so far)

### 1. param-capture command

New web-browser command, working name `graph-params` (or
`param-capture`):

```
web-browser.graph-params [interval] [template=<name>] var1 var2 ...
```

- `interval` — optional int/float, sampling interval in seconds (default
  TBD, e.g. matches existing timer conventions elsewhere in web-browser).
- remaining args — names of JS variables to capture, each must be
  reachable as `window.<name>` (or a `window.debug.*` sub-namespace by
  convention) since WebKit UserScripts run in the main world and can see
  `window` globals but not closure-locals. This matches the existing
  `window.__prevZoomDbg` convention already used in visualization.html.
- **abort semantics**: before starting capture, check
  `typeof window[name] !== 'undefined'` for every requested name. If one
  or more are missing, abort the whole capture and report the missing
  names (do not start a partial capture).
- capture starts on the **foreground view** (whichever view is currently
  visible/active in the web-browser zenka).

### 2. named JS template library (graph renderers)

Concern raised: if the in-page graphing JS is edited in place every time
we want a different visualization, we lose prior working versions and
can't run concurrent perspectives on the same data. Fix: treat graph
renderers as a named template library, one file per variant, following
the **exact existing module convention** already used for
`web-browser.console_capture.js_source` — i.e. Perl modules that
`return <<'JS_SRC'; ...JS...  JS_SRC` (NOT raw `.js` files in
`modules/`, since the module system loads everything as Perl).

Proposed layout:

```
modules/web-browser.graph_template.default.js_source
modules/web-browser.graph_template.sparkline.js_source
modules/web-browser.graph_template.multi-axis.js_source
...
modules/web-browser.graph_template.list          # like base.list.subroutines:
                                                  # return [ qw[ default sparkline multi-axis ] ];
```

`graph-params` takes an optional `template=<name>` argument (default
falling back to a baseline line-chart) selecting which renderer variant
to inject alongside the sampler.

Naming convention: name templates by purpose/visual form (`sparkline`,
`multi-axis`, `scatter-vs-time`), not by version (`v2`, `v3`), to avoid
template sprawl standing in for lost-version sprawl.

### 3. where the graph renders (open question, leaning toward JS-side first)

Considered three options: (a) live canvas/SVG overlay drawn in-page via
injected JS, (b) Perl-side static image render (GD/Chart/gnuplot-style)
from buffered samples, (c) realtime GTK-side plotting embedded in the
web-browser window chrome.

Leaning: build (a) first — real-time, zero extra Perl rendering path,
reuses the page's own visual style, no per-sample IPC latency. (b)/(c)
matter for headless/archival use (viewing a plot after the page/view is
gone, comparing across sessions) and would ride on top of a Perl-side
buffer if/when that's built (see below) — treat as a deliberate
follow-up, not deferred-by-default scope creep.

### 4. Perl-side buffer + event-system watchers (follow-up layer)

Once (or if) captured samples are also streamed into Perl — reusing the
same `p7cons`-style message channel and a named ring buffer per capture
session (same pattern as `console_capture`'s per-view buffers) — this
unlocks **variable watchers**: register a callback against a named
capture buffer that checks a condition on each incoming sample and fires
(e.g. dispatch to another zenki, log, or trigger an action) once
conditions are met. This doesn't need a new mechanism — it's a callback
hung off the existing buffer-write path, same shape as
`base.buffer.add_line` already being the sink for `console_message`.

Concrete motivating case: a watcher on `zoom` vs `manualZoom` divergence
exceeding some threshold for N consecutive frames could have caught the
momentum-reversal case directly, instead of requiring a human to eyeball
a 60-minute drag.

This layer is explicitly sequenced *after* the JS→Perl streaming path
exists (not viable on the in-page-only canvas approach), so if watchers
are wanted soon, the Perl-side buffer path should be built sooner rather
than purely as an eventual nice-to-have.

## suggested build order

1. `graph-params` command: variable-existence check + abort-with-missing-names.
2. Template library skeleton: `web-browser.graph_template.list` +
   one `default` template (simple line chart, in-page canvas overlay).
3. Wire sampler (interval-based `window[name]` reads) to the chosen
   template's renderer, all in-page, no Perl round-trip yet.
4. Validate against the zoom-momentum-reversal case specifically: capture
   `zoom`, `manualZoom`, `velocity` live during a reproduction and confirm
   the graph visibly shows the drift-and-ease-back pattern predicted by
   the `velocityZoomOffset` analysis above.
5. (follow-up) Perl-side streaming buffer per capture session.
6. (follow-up) watcher/condition-callback registration API on top of (5).

## status

Design-only, nothing implemented. No code written yet in this session.

#,,.,,...,,.,,,..,,.,,,..,,.,,.,,,.,,,...,,,,,..,,...,...,,.,,,..,.,,,,,,,,,.,
#N7UNBG7A4K7LJQM6OGSLUAYGPLIRR4ZSFATE2OQZ43TBGXZO3IEEU2KE66FJ6SBMGQHEYDNNHBYH4
#\\\|TFJDU5LN5WNJLY73IXDCOJQIWFW6ITLLT4PCXW5RQ6WVDGYEQPM \ / AMOS7 \ YOURUM ::
#\[7]FNWWZIDG5OD7OVZ4LSQPMURKUHVUUBMZV2Q2RYTGXYAJASVU5ODY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
