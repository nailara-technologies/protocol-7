---
name: topic-zoom-jump-debug-instrumentation
description: RESOLVED — zoom-momentum-reversal bug in space.v7.ax visualization.html was a stray click misfiring the empty-space zoom reset; fixed via graph-params live capture
metadata:
  node_type: memory
  type: project
  originSessionId: 2bf5be89-eeae-4c2f-be89-c65b129014d2
---

RESOLVED 2026-07-13, commit cae42647d. Root cause: neither theory (A: untracked state
mutation, B: `calcRangeAlpha` crossfade illusion) was right. A third path: a stray click
(`mousedown`+`mouseup` with **zero** intervening `mousemove`, so `dragMoved` stays false)
landing in the ~1s gap between two rotate-drag/wheel-zoom gestures hits
`handleSingleClick`'s empty-space branch, which sets `zoomTargetZoom = 1.0` and
`zoomTargetRotX/Y = current rotation`. Because target rotation already equals current
rotation, `updateCamera()`'s `< 0.05` convergence check passes almost immediately, snapping
`manualZoom` straight to `1.0` in one frame regardless of where it had drifted — read
visually as a "momentum reversal" with no relation to velocity or the easing curve itself.

Diagnosed live using [[web-browser-param-capture-graphing]] (`web-browser.cmd.graph-params`,
landed same session) — exposed `window.debugZoom/debugManualZoom/debugVelocity/debugRotX/
debugRotY/debugIsDragging/debugDragMoved` and pulled `window.__p7GraphData.samples` as JSON
after each reproduction. This is what actually cracked it: velocity stayed provably zero
throughout every capture (ruling out theory A's velocity path), and the exact
`0.34→1.0` style jump matched only the `zoomTargetZoom = 1.0` constant used in exactly one
code site.

**Fix:** `CLICK_RESET_COOLDOWN = 2000`ms — a `lastInteractionTime` timestamp updated on every
`mousemove`-while-dragging and `wheel` event; the empty-space click's zoom-reset branch only
fires if `Date.now() - lastInteractionTime >= CLICK_RESET_COOLDOWN`. (First attempt at 500ms
was too short — the real gap observed was ~950ms.) The old `[zoom-jump]` DEBUG console.log
block was left in place, not stripped, in case of recurrence.

**How to apply:** if any dynamic-input bug in this file (or others using the same
mousedown/mousemove/mouseup click-vs-drag disambiguation pattern) resurfaces, reach for
`graph-params` capture first — it found this in one focused session after multiple prior
attempts (console-capture, code tracing) stalled. See also
[[project-input-capture-replay-website-templates]] — spun off from this same session to make
this class of reproduction fully deterministic instead of live-capture-and-hope.

#,,..,..,,.,,,,.,,.,.,...,,,.,,..,,..,.,,,,..,..,,...,...,.,,,..,,...,,,,,.,,,
#CNYFETGKAV5YN643MJX6XLXRJA7QWHAEDO7PIGWTJONQ4CKAVYJ5V3OPFRHVRZQIIF7MDXLBJQA5K
#\\\|UZNA6RST2ZZAXVPRGLOA7QNXC6LEOAAL6PCRESN66YSK7EOCGMG \ / AMOS7 \ YOURUM ::
#\[7]MKYCA2OYK53GZA5ARJKMHA4JZOGCTZ3BKAI5S3P37YTNVIZYPIAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
