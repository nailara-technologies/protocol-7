## task: intelligent user/fallback selection for X11-needing zenki + global audio device awareness

### origin

Surfaced debugging why the radio stream wouldn't play cleanly through the
`mpv` zenka: traced through several layers (WSL has no real ALSA hardware,
`protocol-7` lacks `audio` group membership, a hardcoded `PULSE_SERVER =
tcp:10.0.110.7` pointing at a manually-run Windows-host `pulseaudio.exe`
that WSLg's own native bridge at `/mnt/wslg/PulseServer` makes entirely
unnecessary) before discovering the actual mpv zenka runs as `taeki` (the
interactive desktop user), not `protocol-7` — because `<system.AMOS-user>`
(`cfg/X11-vars`) is currently pinned to `<system.admin-user>` as
a deliberate, acknowledged-temporary bridge for any X11-needing zenka,
pending "automatic detection" (the file's own comment) and a
not-yet-activated dedicated `amos7-x11` user already scaffolded
(commented out) in the same config.

### part 1: X11 user/fallback selection

Current state: every X11-needing zenka rides the same single
`<system.AMOS-user>` value, which is either a real interactive user
(fragile — ties zenka operation to a specific human's desktop session
being present and configured correctly) or, eventually, `amos7-x11` (a
dedicated auto-created X11 user, once automatic detection exists).

There's a third option already partially built and not being used for
this: `X-11.cmd.get_xauth_data` returns the X11 authorization protocol
name + hex-encoded cookie from `<X-11.obj>` — the exact mechanism kiosk
mode already relies on to let a non-owning user get valid X11 access via
a transferred `XAUTHORITY` cookie, rather than needing to *be* the user
that owns the display's native auth file. If `protocol-7` can get valid
X11 access this way, there's no fundamental reason video-capable zenki
need the admin-user bridge at all — they could run as `protocol-7`
uniformly, same as backend zenki already do, once xauth transfer is wired
up as a first-class fallback path.

Proposed fallback order for any X11-needing zenka at spawn time (or
retry), roughly: (1) a running X-11 instance exists → resolve via
`resolve_primary_sid`/subname-group as already done, retrieve its xauth
cookie via `get_xauth_data`, write a local `XAUTHORITY` file, run as
`protocol-7`; (2) no X-11 instance available yet → fall back to the
current `<system.AMOS-user>` bridge (admin-user today, `amos7-x11` once
its detection lands). Audio-only zenki (e.g. `mpv[audio-0]`, no video
output, no X11 need at all) are the trivial degenerate case: they never
need step (1)'s X11 resolution, and could run as `protocol-7` immediately
independent of whatever this fallback mechanism decides for video-capable
instances — not blocked on this work landing, just naturally subsumed by
it once it exists.

### part 2: global audio device awareness

The deeper, parallel gap: v7 already has a working pattern for exactly
this class of problem, just not extended to audio. `v7.zenka.start`
resolves the correct DISPLAY for a spawning zenka via
`resolve_primary_sid('X-11', ..., $zenka_subname)` and preps
`$ENV{'DISPLAY'}` before exec — X-11 is the standing source of truth a
zenka can query instead of every caller hardcoding a value. There's no
audio equivalent: nothing tracks what audio backends actually exist and
are reachable right now (WSLg's native bridge, a possible future local
proxy absorbing the bridge's pause/cork/resume fragility, whatever real
ALSA devices exist if any), so `mpv`'s config just hardcoded one specific
address and had no way to discover, adapt to, or recover from it being
wrong — exactly what happened today.

Proposed: a zenka (X-11 itself, or a new sibling with the equivalent
role for audio) maintains this awareness and exposes it the same way
`get_xauth_data`/display resolution already work — a queryable "what's
the right audio backend/address right now" primitive. `v7.zenka.start`
gets the audio-equivalent of its existing DISPLAY-prep logic: before
spawning a zenka that declares an audio need, resolve the correct
`PULSE_SERVER` (or whichever backend) from this registry rather than
trusting a hardcoded value.

**Integration with mpv specifically should be cheap once this exists**:
mpv ships a native `audio-device`/`audio-device-list` property pair with
a default cycle hotkey (`#`) out of the box — this codebase doesn't
exercise the cycle mechanism itself yet, that's just stock mpv default
config/behavior, untouched so far. What *is* already in use is a
different, narrower touch point on the same property:
`mpv.callback.silenced` does `set_property_string audio-device` directly
(setting a specific device, not cycling). So the property itself is
already real plumbing in this codebase, even though the cycle-hotkey
behavior riding on top of it hasn't been used. Feeding the awareness
registry's known backends into mpv's own `audio-device-list` would let
mpv's stock cycle mechanism become a free, ready-made way to
select/switch between them, rather than needing custom selection UI or
logic built specifically for this.

### relation to the earlier local-audio-proxy idea (same conversation)

A local Pulse proxy (absorbing pause/cork/resume against WSLg's bridge,
keeping its own upstream connection permanently alive) is a candidate
*backend* this awareness mechanism would need to know about and prefer,
once built — not a replacement for this task. The awareness/resolution
layer is what lets `mpv` (and anything else needing audio) stay agnostic
to whether it's talking to WSLg's bridge directly or a local proxy sitting
in front of it; that decision should live in the registry, not be
hardcoded per-zenka again.

### open questions

- Where does audio-backend awareness actually get detected from — probed
  live (does `/mnt/wslg/PulseServer` exist, is a local proxy's socket
  live) at query time, or registered/pushed by whatever starts each
  backend, mirroring how X-11 itself registers its own auth data at
  startup rather than being probed externally?
- Whether the X11 fallback order and the audio-awareness registry should
  be two independent mechanisms or share a common "capability resolution"
  primitive, given they're solving structurally the same problem
  (a zenka needs a resource whose correct value depends on runtime
  environment state, not static config) for two different resource types.
- Whether `<system.AMOS-user>`'s eventual `amos7-x11` activation is a
  prerequisite for the xauth-transfer fallback, or fully independent
  (xauth transfer working for `protocol-7` doesn't obviously need
  `amos7-x11` to exist at all — worth confirming before assuming an
  ordering dependency that isn't actually there).

#,,,,,.,,,,,,,,,,,.,.,,.,,,.,,,.,,,,,,...,..,,..,,...,...,..,,.,.,.,.,,..,,..,
#RCAONHI5ZXZH7FRFF2UIDVSN54ZMPCZFEME6FXU2PYEFHK7KCFPFQ6XTBHFARKOQYGOJL36C3T54A
#\\\|76GEJP4IFBJAUDUW7PJM6I6EBCHRMVVBBM3UFFTOCZZ7X7CFDHF \ / AMOS7 \ YOURUM ::
#\[7]SQSXQLYIDRLIHN7TS6UA5XH6MOUXLTRDQ5NX4APYRHOBP3Y3HQDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
