---
name: topic-x11-multi-server
description: "X-11 zenka upgraded to multi-server support using jobqueue+dep system; display registry keyed by display string"
metadata:
  type: project
  originSessionId: eec99c76-3a6c-4a57-abb3-72c98c78bcdd
---

## what landed (2026-06-18)

X-11 zenka upgraded from single-server to multi-server using the same
jobqueue + dependency pattern as mpv:

- **`<X-11.servers>`** — registry hash keyed by display string (`:0`, `:2`, etc.)
  each entry: `mode`, `params`, `pid`, `fh`, `conn`, `connected`, `dep_id`, `bin_name`
- **`X-11.callback.object.x11_display_flag`** — dep type callback; returns TRUE
  when `<X-11.servers>->{$display}->{'connected'} == TRUE`
- **`X-11.handler.display_poll`** — async 100ms poll timer; checks
  `/tmp/.X11-unix/XN` socket exists, then `X11::Protocol->new($display_str)`;
  on success sets `connected=TRUE`, stores conn in server hash, calls
  `jobqueue.check_dependencies`
- **`X-11.job.start_server`** — forks X binary, registers PID, starts display_poll
  timer, adds dep object, queues `finalize_server` job
- **`X-11.job.finalize_server`** — runs when dep resolves; sets `<X-11.obj>`,
  creates `<X-11.WM>`, initializes RANDR/DPMS/Composite, wires keyboard handler,
  sets `<X-11.initialized> = TRUE`, tests window enumeration

## critical bug: host mode timing

in host mode, `connected=TRUE` must NOT be set in post_init immediately —
that would make the dep already-satisfied before X11::Protocol->new runs,
causing finalize_server to fire before `$server->{'conn'}` is defined.

**fix pattern in `X-11.post_init`:**
```perl
push @{ <system.callbacks.initialized> //= [] }, sub {
    my $host_server = <X-11.servers>->{$display_str};
    eval { $host_server->{'conn'} = X11::Protocol->new($display_str); };
    if ( not length $EVAL_ERROR ) {
        $host_server->{'connected'} = TRUE;
        <[jobqueue.check_dependencies]>;
    }
};
```
the callbacks.initialized coderef fires after cube connection; X11::Protocol->new
only succeeds once the display is actually up (which it is by then in host mode).

## guard added

`X-11.WM.update` now has `return unless defined <X-11.WM>;` at top to prevent
crashes when called during partial init or from a non-primary server path.

## tile display awareness

tile zenka received display-awareness additions from kimi (2026-06-18):
- `<tile.current_display> //= <X-11.display> // ':0'` in `tile.init_code`
- `tile.process-tile-group` tags groups with display, updates `current_display`
- `tile.cmd.assign_window` passes display to `X-11.fade_out` when non-default
- `tile.cmd.get-screen-size` (new) — returns screen dimensions for current display

## open

- xvfb-start/stop/status/list commands (separate kimi dispatch, not yet landed)
- tile-as-relay: tile calling X-11.job.start_server for on-demand xvfb per group
- any zenka that had `<X-11.obj>` as a given now needs to check which server it's
  targeting for multi-display scenarios

**Why:** many zenki (mpv, window-place, tile, xephyr clients) needed xvfb
support without exclusive ownership; the multi-server registry lets X-11 manage
all displays with a unified dep chain.

**How to apply:** when adding a new X server start path, use `X-11.job.start_server`
with `{display, mode, bin_name, primary=>FALSE}` params; never set `connected=TRUE`
outside of the display_poll or callbacks.initialized coderef.

[[topic-mpv-jobqueue-startup]]
[[tile-window-place-hybrid-desktop]]

#,,,,,,.,,,,,,,,.,,,.,.,,,,.,,,,,,,.,,,,,,...,..,,...,...,.,.,..,,...,.,,,.,.,
#CYDWERBGUR7H3BRROVUSXQS4F7C7OLTMLPWATWRJ3OSY6BM2LY72QXWFPXWWYYLJPFJILMORS5CIG
#\\\|QUD46S4EMUD7HCJEARKRPUYMOXJJG6BQ5XKY35YNRGSKFTOHLXP \ / AMOS7 \ YOURUM ::
#\[7]LTHWX3RUGXFQIKIYJLF7ZSCYE5ZNGKX25DKFHUDKSZO3HONWG4AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
