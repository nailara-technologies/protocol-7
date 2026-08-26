---
name: web-browser-param-capture-graphing
description: "LANDED — web-browser.cmd.graph-params live-graphs any window.<name> JS variable via in-page canvas overlay; reusable debug tool, not a one-off"
metadata: 
  node_type: memory
  type: reference
  originSessionId: bb0cf140-dd76-483c-a959-f138f5260815
---

Landed commit cae42647d (task doc `data/tasks/web-browser-param-capture-graphing.md`).
`web-browser.graph-params [interval] [template=<name>] var1 [var2 ...]` samples
`window.<name>` JS globals at an interval and renders them live via an in-page `<canvas>`
overlay — no Perl round-trip per sample, no devtools needed. Existence-checks all requested
names against `window` before starting; aborts with the missing list rather than a partial
capture.

Modules: `web-browser.cmd.graph-params`, `web-browser.graph_params.install` (fire-and-forget
`run_javascript` injector), `web-browser.graph_template.list` /
`web-browser.graph_template.default.js_source` (named JS renderer templates, Perl files
`return <<'JS_SRC'...JS_SRC`, same convention as `console_capture.js_source` — **not** raw
`.js` files, and avoid `sprintf` on them since template JS commonly contains literal `%`).
Style: default template uses the project's window-place blue (`rgba(0,0,61)` fill /
`rgb(6,71,195)` border-accent, alpha `0.47` matching visualization.html's own constant) as a
translucent base, golden-angle (137.508°) HSL hue spacing per series for max color
distinctness at any series count, `shadowBlur`/`shadowColor` glow on lines, and stroked
(outlined) legend text so labels stay legible when a bright line drifts behind them.

**Why it matters:** proved itself same-session by root-causing
[[topic-zoom-jump-debug-instrumentation]] (a stray-click/timing bug that had stalled under
console-log-threshold debugging and code tracing alone) — pulling
`window.__p7GraphData.samples` as JSON after a reproduction and diffing values frame-by-frame
is what actually found it, not the visual overlay alone.

**How to apply:** default first move for "acts weird, doesn't log anything predictable" bugs
in the web-browser zenka — expose the suspect state as `window.debug<Name>` (convention
established in visualization.html), run `graph-params`, reproduce, then pull
`window.__p7GraphData.samples` via `web-browser.run_js` for exact frame-by-frame values
rather than only eyeballing the canvas (the ring buffer is capped at 300 samples — pull
promptly after reproduction or the event scrolls out). See
[[project-input-capture-replay-website-templates]] for the planned next layer (deterministic
input replay + state-vector snapshots) that removes the "hope you catch it live" step
entirely.

#,,,,,...,.,.,,..,,..,,,,,,,,,...,.,.,,,,,,,.,..,,...,...,.,,,..,,...,...,,,,,
#UJYNPVXPJKYAVYRPBL64WVVV7IA6LPNYNQLSZP5T5YY2AWRQOSQAL3BKR6SSJKTS626NKFH3T5HPA
#\\\|JWY73JVSMACZ45EZUAJZZF7B4QDMD46W6ISISQFIDW3M5FRJJOU \ / AMOS7 \ YOURUM ::
#\[7]G6BSVREBGPQLZLWBBTL5JBHST3SKRTFHCT77S4ZFQIK7MUQIPWBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
