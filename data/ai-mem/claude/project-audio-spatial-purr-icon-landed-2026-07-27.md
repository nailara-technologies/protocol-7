---
name: project-audio-spatial-purr-icon-landed-2026-07-27
description: "landed: audio.cmd.spatial-purr-icon, a sibling command to spatial-purr pinned to the current best-known icon recipe (v3 render + rotation_stack.v4 mirror background + waveform_trace.v1 foreground, auto-cropped wide via crop_wide.v1 when am_depth crosses format_hint_threshold) -- exists so there's always one immediately working command producing the latest deliberately-adopted combination, independent of whatever audio.cfg.render_style/post_process/overlay currently holds mid-experiment via devmod"
metadata:
  node_type: memory
  type: project
  originSessionId: 16c8ce74-d9e2-429d-bafb-25fae9c0c30f
---

## why this exists

by this point in the session the audio-icon pipeline had three
independent, devmod-tunable global knobs (`audio.cfg.render_style`,
`.post_process`, `.overlay`) that get set/reset constantly while
testing new variants (`rotation_stack.v1`-`.v4`, `crop_wide.v1`,
alpha/tint tuning, etc). user's ask: keep that experimentation surface
free for new variants, but always have one command that reliably
produces the *current best* combination without needing to remember
to set three config values first (or accidentally leaving them mid-
experiment and getting a broken/inconsistent render for a real use).

## how it's built

`audio.cmd.spatial-purr-icon` is a near-identical sibling of
`audio.cmd.spatial-purr` — same validation, same
`audio.decode_to_pcm` spawn — but after spawning, it stashes a fixed
`pipeline` hashref directly into `<audio.decode>->{$id}`:

```perl
<audio.decode>->{$id}{'pipeline'} = {
    'render_style' => 'v3',
    'post_process' => 'rotation_stack.v4',
    'overlay'      => 'waveform_trace.v1',
    'auto_crop'    => TRUE,
};
```

`audio.finalize_decode` was extended to check `$state->{'pipeline'}`
first for each of `render_style`/`post_process`/`overlay`, falling
back to the global `audio.cfg.*` value exactly as before when the
override key isn't set — so ordinary `audio.cmd.spatial-purr` calls
(and any future caller that doesn't set a pipeline) are completely
unaffected, confirmed live: global cfg stayed at `v1`/`none`/`none`
throughout testing `spatial-purr-icon`, and a plain `spatial-purr`
call afterward still used those untouched globals correctly.

`auto_crop` is a pipeline-only opt-in, not exposed via `audio.cfg.*`
at all — after the post_process/overlay stages run, if
`format_hint` (from the already-existing `am_depth` signal, see
`data/tasks/audio-icon-format-hint-from-am-depth.md`) came out `wide`,
`audio.post_process.crop_wide.v1` gets invoked as an explicit fourth
step specific to this command. this sidesteps the single-slot
`post_process` limitation (can't select both `rotation_stack.v4` and
`crop_wide.v1` via the same config value) without solving that
limitation generally — `spatial-purr-icon` just chains both directly
in code for its own fixed recipe.

**access note**: had to add `spatial-purr-icon` to
`cfg/zenki/audio/zenka.v7`'s `access.cmd.usr.cube` line before
`bin/dev/gen-sub-whitelist audio` would discover the new command as
reachable — the generator filters by that access line when present,
not just by static call-graph reachability from `init_code`. cost one
extra step/confusion (initial whitelist regen silently did nothing)
before finding this.

## live-verified

`p7c audio.spatial-purr-icon` tested against all 3 calibration
samples: `aa` → 512x512 square, `saturnians` → 512x512 square (both
correctly stay square per the corrected `0.9` threshold), `ac` → 512x285
genuinely wide, auto-cropped cleanly with visible boundary padding.
global `audio.cfg.*` confirmed untouched before/during/after.

## how to keep this current

whenever a new variant is adopted as the new best (a `v5` render
style, a different post_process default, etc), update the `$pipeline`
hashref inside `audio.cmd.spatial-purr-icon` itself — it's a plain
hardcoded recipe by design, not derived from config, so "what's
current best" is a deliberate one-line code edit each time, not
automatic.

#,,,.,,,.,.,,,,,,,,..,,.,,.,.,.,.,,..,.,.,..,,..,,...,...,...,,,,,...,,,.,..,,
#IZ75KBHVMZHC64SJINK7JWYYDFV4ULOR7NWNNOFYKAGRMABNRZJPQSL7V2DV64ZQP2OGINNND6HFI
#\\\|HADNAH4ISX743LAVTV3TWUJQSD7CGHLQDNHJQNAL4FIQT2AWWPN \ / AMOS7 \ YOURUM ::
#\[7]JHWJ3ROBJSSLWIBIRKVQ5DVK4UQOG6I4RDGIADZ4EEEFQXW6YEDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
