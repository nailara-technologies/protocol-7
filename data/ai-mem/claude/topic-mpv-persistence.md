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

## layers 1-2 landed (2026-07-31, `218cc382b`, kimi K3 dispatch,
live-verified)

state snapshot + smooth restore are done, built differently than the
original "deferred send_command queue" plan above: instead of queuing
snapshot-restore as `mpv.job.deferred_send_command` entries, restore
runs synchronously from `mpv.startup.job.finalize` (after the control
socket dep resolves) via direct `set_property_string` calls — simpler,
and avoids interleaving ordering issues with the cube playlist's own
`get_list_reply`/`file-loaded` flow. `mpv.snapshot.save` collects the
full `mpv.map.settings` property cache (observed properties expanded
from a hardcoded 5), path, position, and playlist; writes
`state/snapshot.yaml` via the same `file.zenka_dir.write` convention as
`window.profile.save`. Periodic checkpoint (`mpv.snapshot_interval_
seconds`, default 60s) + graceful pre-quit save (`mpv.cmd.quit` →
`mpv.snapshot.send_quit`, 2s safety-timer fallback if save stalls).

Real bug found post-dispatch: `mpv.handler.event.property-change.path`
(pre-existing, unrelated to this dispatch) deletes the whole
`<mpv.current>` cache when the player goes idle/stops — without a
guard, the next periodic checkpoint or quit-time save would silently
overwrite a good snapshot with an empty one. `mpv.snapshot.write` now
skips the write entirely when the collected state is empty.

Layers 3-5 (curve automation, cross-mapped routing, active-curve-state
in snapshot) remain open — see [[topic-next-steps]] "open — mpv".

## restore-seek non-seekable guard (2026-08-01, `bac000eef`)

live testing surfaced a real gap: restoring a saved position against a
live/network stream (radio's `http://127.0.0.1/radio/stream`) tried to
seek to a meaningless timestamp. Fixed by observing mpv's own `seekable`
and `partially-seekable` properties (same property-cache mechanism as
the rest of this feature) and gating `mpv.snapshot.apply_pending`'s
restore seek on both: `seekable` must be true AND `partially-seekable`
must be false, since restore does a large absolute seek — exactly the
case mpv's own docs say "may fail anyway" for cache-only (partial)
seekability. Undefined (property never observed yet) is treated as
not-seekable, the safe default.

#,,,,,.,,,...,.,,,.,.,,,,,,.,,,.,,..,,,..,...,..,,...,...,.,.,,,.,.,,,,,.,.,.,
#5BFZ66MKFKJ3EXMGG74Y6HDYUUD4EBGSLSY6U34OONBFNNGLIXASF5ROCKR63NHCCTNT4NBYIWA2E
#\\\|3TXCPVBSI5HFVUFNP7T6VIMMCYUIN2SMXXKFYAUH4FAURTDYFXC \ / AMOS7 \ YOURUM ::
#\[7]Z3JL267ZJVDRMVANGDYSF4WVQSYR6P6M735YYY3QT6CP5AHROIBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
