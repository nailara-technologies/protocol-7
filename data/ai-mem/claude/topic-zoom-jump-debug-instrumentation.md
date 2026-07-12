---
name: topic-zoom-jump-debug-instrumentation
description: unresolved zoom-jump bug in space.v7.ax visualization.html; DEBUG console.log block intentionally shipped/staged to catch it live
metadata: 
  node_type: memory
  type: project
  originSessionId: 2bf5be89-eeae-4c2f-be89-c65b129014d2
---

`data/web-root/vhosts/space.v7.ax/visualization.html` `updateCamera()` (~line 829-849) has a
`// DEBUG: zoom-jump instrumentation for unbroken-drag reset bug` block that logs
`[zoom-jump]` to `console.log` whenever `zoom` changes >0.02 absolute or >3% relative in one
frame. It is intentionally left in place [ staged/committed 2026-07-11 ], not leftover cruft —
do not strip it on sight.

**Why:** during a fully unbroken mouse drag (single mousedown held 60+ min) combined with
wheel-zoom-out, the zoom visually "resets" back toward the starting position with an eased/
momentum-like motion. Three related-but-distinct bugs were already found and fixed
(pinch-zoom / mousedown / stale-clickTimer all failing to null `zoomTargetRotX/Y/Zoom`) — code
tracing proved none of those three can explain this case, since `mouseup`'s
`if (dragMoved) return` blocks all click/dblclick/nav-pop logic during a real drag. Every
writer to `manualZoom`/`zoom`/`velocity`/`camX/Y/Z` was grepped and enumerated; nothing
unaccounted-for mutates them.

Two live theories: (A) a genuine untracked state mutation during drag+wheel, or (B) a
rendering illusion from `calcRangeAlpha()`'s log-scale, rotation-dependent, easing-curve
layer crossfade — `zoom` could stay monotonic while the crossfade *reads* as a bounce.

As of 2026-07-11 a reproduction attempt did not trigger the bug — inconclusive, not resolved.

**How to apply:** this is exactly what [[topic-web-browser-js-console-capture]] was built
for — next reproduction, check `web-browser.show-buffer js-cons-view-000x` for `[zoom-jump]`
lines instead of needing devtools. If lines appear during the perceived reset, they name the
actual writer (confirms A); if none appear, that confirms B (investigate `calcRangeAlpha`
layer-crossover next). Once root-caused and fixed, strip the DEBUG block and this memory.

#,,,,,,,,,,,.,,,,,...,,.,,.,,,..,,,,,,,.,,,..,..,,...,...,,.,,,,.,,..,,,,,,..,
#2XE7YM6BJY2XYAHR4GMDMQ5PRXAYKKUGXVN4OU4WIZRAXD4RAEYTKO5GY2345YWWJ4B7ITL34OB2S
#\\\|XCUCB2WMEVXJQVQ4DX2MX67KOL7MR24DNGTLNAXYFFAK2SKZ2OR \ / AMOS7 \ YOURUM ::
#\[7]G7EAGSSDJXVVLMHFBG2XAESWHBMJBJ3KL2VPYJ2HV4TAYEFPTKDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
