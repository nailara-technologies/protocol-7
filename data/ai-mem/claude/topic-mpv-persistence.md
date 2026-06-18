---
name: topic-mpv-persistence
description: "mpv state persistence layer: snapshot/restore + visual curve automation + cross-mapped parameter routing"
metadata: 
  node_type: memory
  type: project
  originSessionId: eec99c76-3a6c-4a57-abb3-72c98c78bcdd
---

## vision (2026-06-18)

mpv needs a full persistence layer beyond the current playlist zenka + built-in
watch-later. the zenka must own complete state recreation.

### layers

1. **state snapshot**: capture all runtime property values (observed properties +
   runtime adjustments diverged from defaults) + geometry + active curves + their
   phase. written to mpv's own profile directory with timestamp.

2. **smooth restore**: replay snapshot as deferred send_command jobs — all drain
   in order when socket dep resolves. player comes up already in prior state
   within one event loop sweep.

3. **visual curve automation**: extend `base.curve.*` (currently handles volume
   fade via `mpv.handler.audio_fade`) to cover brightness, contrast, gamma,
   saturation, hue, shader uniforms. same scalar-over-time shape.

4. **cross-mapped curve routing**: curve input is not time but another property
   or external signal. examples:
   - volume following ambient curve driven by time-of-day
   - saturation fading as function of playlist position
   - contrast transitioning between profiles when window moves monitor
   the curve system becomes a signal routing graph, not just independent envelopes.

5. **active curve state in snapshot**: persist current curve phase so restoration
   resumes automation mid-transition rather than snapping to endpoint value.

### integration with restart

the deferred send_command queue (from [[topic-mpv-jobqueue-startup]]) is the
restore mechanism: load snapshot → queue all property restoration as deferred
commands → drain when socket resolves on restart.

**Why:** current persistence is too rudimentary for graceful restart-with-restore,
LLM-assisted fallback recovery, and eventually cross-machine state propagation.

**How to apply:** snapshot module captures on graceful shutdown + periodic
checkpoint. restore pass issues `set_property` for each value. curve state
needs phase + target + current-value triple.

#,,..,..,,,.,,,,.,.,.,.,.,,.,,,,,,,,.,,.,,.,.,..,,...,...,...,..,,.,,,,,.,,.,,
#TEGUBVH7P5N4FBRGDNGUIHYQ3OQL5GMCCDGYWIKEDE7YZ3WO2LAHG6LSSCTPTMQTHU5LB7PVARRQK
#\\\|7RIDLWBM4CZNITNCFYEREVHDQWJXKFCOAVJCF7IUACI5HJ4BME2 \ / AMOS7 \ YOURUM ::
#\[7]S46XRMHNLR6M6APCEU47FSAHZWE2QALEHZOXCIW5BLWNSXJQV4DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
