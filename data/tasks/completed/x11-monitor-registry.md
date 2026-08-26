# task: X-11 async monitor registry

## context

monitor geometry is currently retrieved in three different ways, all with problems:

1. **`X-11.cmd.get_pointer_scr_rect`** — spawns `xrandr --listmonitors` as a blocking
   subprocess inside the X-11 zenka event loop. correct data, but synchronous shell-out.

2. **`base.X-11.get_pointer_scr_rect`** — calls the above via blocking readline from the
   calling zenka before returning. blocks the caller's event loop while waiting for X-11
   round-trip + xrandr process.

3. **`window.gtk.get_pointer_monitor_geometry`** — uses GDK to find the monitor under
   the pointer. under WSLg/XWayland, GDK reports the entire virtual desktop (e.g.
   5360x2940) as a single monitor — completely wrong for multi-monitor placement.
   used by `window.place.cmd.coords` and `window.place.start`.

4. **`window.geometry.resolve`** — has a second inline `qx|xrandr --listmonitors|` call
   as a fallback, duplicating the logic already in `X-11.cmd.get_pointer_scr_rect`.

the X-11 zenka already has RANDR initialized (`<X-11.has_randr>`) and subscribes to
screen-change events in host mode (`X-11.handler.screen_change`). the RANDR data is
never stored — it is thrown away and re-fetched from xrandr every time it is needed.

this task replaces all of the above with a single in-memory monitor registry that is
built once at connection time and refreshed on RANDR screen-change events.

## what exists

- `X-11.job.finalize_server` — initializes RANDR extension; sets `<X-11.has_randr>`;
  subscribes to screen-change events for host mode (lines 74-101)
- `X-11.handler.screen_change` — fires on RANDR event; currently only refreshes
  cached screen dimensions, not per-monitor data
- `<X-11.obj>` — the `X11::Protocol` connection object; RANDR extension already loaded
- `X-11.cmd.get_pointer_scr_rect` — existing command interface; callers keep using it
- `base.X-11.get_pointer_scr_rect` — synchronous per-zenka proxy to the above

## new module: X-11.build_monitor_registry

reads monitor geometry from RANDR and stores in `<X-11.monitors>` (arrayref of hashrefs):

```perl
# name  = X-11.build_monitor_registry
# descr = populate X-11.monitors from RANDR; call at startup and on screen-change

return unless <X-11.has_randr>;

my @monitors;
eval {
    my @crtcs = <X-11.obj>->RRGetScreenResources( <X-11.obj>->root );
    ## RRGetScreenResources returns ( timestamp, config_timestamp, roots,
    ##   crtcs, outputs, modes ) — index 3 is the crtc list ##
    for my $crtc ( @{ $crtcs[3] // [] } ) {
        my %ci = <X-11.obj>->RRGetCrtcInfo( $crtc, 0 );
        next unless $ci{'width'} and $ci{'height'};
        push @monitors, {
            'x'      => $ci{'x'}      + 0,
            'y'      => $ci{'y'}      + 0,
            'width'  => $ci{'width'}  + 0,
            'height' => $ci{'height'} + 0,
        };
    }
};
if ($EVAL_ERROR) {
    <[base.log]>->( 1, '[monitors] RANDR query error — registry not built' );
    return;
}

<X-11.monitors> = \@monitors;
<[base.logs]>->( 1, '[monitors] registry built : %d monitor(s)', scalar @monitors );
```

notes:
- `RRGetScreenResources` and `RRGetCrtcInfo` are in `X11::Protocol::RANDR`; verify
  the exact return structure with `perl -e 'use X11::Protocol; ...'` if needed
- if `RRGetMonitors` (RANDR 1.5) is available and cleaner, prefer it
- skip CRTCs with zero width or height — those are disconnected outputs
- store nothing if `<X-11.has_randr>` is false; callers must handle undef `<X-11.monitors>`

## changes to existing modules

### X-11.job.finalize_server

after the existing RANDR init block (after line 87 where `<X-11.has_randr> = TRUE`),
add:

```perl
<[X-11.build_monitor_registry]> if <X-11.has_randr>;
```

### X-11.handler.screen_change

after whatever screen-dimension refresh logic is already there, add:

```perl
<[X-11.build_monitor_registry]> if <X-11.has_randr>;
```

### X-11.cmd.get_pointer_scr_rect

replace the xrandr subprocess block with a registry lookup:

```perl
## current: xrandr --listmonitors subprocess — replace entirely ##

my $monitors = <X-11.monitors>;
if ( not defined $monitors or not @$monitors ) {
    return { 'mode' => qw| false |, 'data' => 'monitor registry not available' };
}

my ( $first_x, $first_y, $first_w, $first_h );
for my $m (@$monitors) {
    my ( $x, $y, $w, $h ) = @{$m}{qw| x y width height |};
    ( $first_x, $first_y, $first_w, $first_h ) = ( $x, $y, $w, $h )
        if not defined $first_w;
    if (    $px >= $x and $px < $x + $w
        and $py >= $y and $py < $y + $h ) {
        return { 'mode' => qw| true |, 'data' => "$x $y $w $h" };
    }
}
return defined $first_w
    ? { 'mode' => qw| true |,  'data' => "$first_x $first_y $first_w $first_h" }
    : { 'mode' => qw| false |, 'data' => 'no monitors in registry' };
```

keep the `QueryPointer` block at the top — that part is correct.

### window.place.cmd.coords

replace the `window.gtk.get_pointer_monitor_geometry` call with a route-send to
`X-11.get_pointer_scr_rect`. the cmd is already deferred (returns `{ mode => 'deferred' }`)
so an async step fits naturally.

current flow (simplified):
```
1. $screen_geom = window.gtk.get_pointer_monitor_geometry  [gdk, broken under wsl]
2. fallback to x11.geometry / hardcoded if undef
3. add_timer(after=>0) → open_window
4. return deferred
```

new flow:
```
1. route-send X-11.get_pointer_scr_rect → handler: window.place.handler.scr_rect_reply
   (carries $id, $geo, $caller, $tag as closure or stored in instance)
2. return deferred
```

`window.place.handler.scr_rect_reply`:
```perl
my $reply = shift // {};
my $mode  = lc( $reply->{'cmd'} // '' );
my $rdata = $reply->{'call_args'}->{'args'} // '';
my $id    = $reply->{'call_args'}->{'id'} ?? ... ; ## carry id via reply context

my $screen_geom;
if ( $mode eq qw| true | and $rdata =~ m{^(-?\d+) (-?\d+) (\d+) (\d+)$} ) {
    $screen_geom = { x => $1+0, y => $2+0, width => $3+0, height => $4+0 };
} else {
    ## fallback: centered on screen as before ##
    my $geom_str = <x11.geometry> // '1920x1080+0+0';
    $geom_str =~ m|^\s*(\d+)\s*x\s*(\d+)|;
    $screen_geom = { width => $1 // 1920, height => $2 // 1080, x => 0, y => 0 };
}

## then continue with the existing geo calculation and add_timer → open_window ##
```

carry the instance `$id` forward: either store it on `$data{window}{place}{instances}{$id}`
before the route-send, or pass it as part of the `call_args` context if the routing
system supports it. the instance hash already exists at that point.

### window.geometry.resolve

remove the second inline xrandr block (lines 61-79 in the current file):

```perl
## remove this entire block: ##
if ( not defined $screen_w and -x qw| /usr/bin/xrandr | ) {
    ...
}
```

`base.X-11.get_pointer_scr_rect` (which calls `X-11.get_pointer_scr_rect` via the
cube) is already tried above it and now uses the registry — no xrandr fallback needed.
keep the final fallback to `<x11.coordinates>` / hardcoded 1920×1080 as the last resort
for pre-cube contexts.

## new module: X-11.cmd.get_monitors

expose the registry as a command for diagnostics / callers that want all monitors:

```perl
# name  = X-11.cmd.get_monitors
# descr = return all known monitor rects from registry

my $monitors = <X-11.monitors> // [];
return { 'mode' => qw| false |, 'data' => 'monitor registry empty' }
    unless @$monitors;

my @parts = map { sprintf '%d %d %d %d', @{$_}{qw| x y width height |} } @$monitors;
return { 'mode' => qw| true |, 'data' => join( "\n", @parts ) };
```

add `X-11.get_monitors` to `cfg/zenki/cube/access.zenki` in the `usr.*`
blocks that currently have `X-11.get_pointer_scr_rect`.

## acceptance

- `p7c X-11.get_monitors` returns one line per physical monitor with `x y w h`
- `p7c X-11.get_pointer_scr_rect` returns the monitor rect under the pointer
  without spawning any subprocess (verify with `strace -e execve` or log check)
- window-place UI opens centered on the correct physical monitor when pointer is
  on the right-hand screen
- `window.geometry.resolve` no longer contains any `qx|xrandr` calls

## signatures note

do not modify or regenerate any AMOS7 signature lines. the signing system
handles all footer blocks — leave them untouched.

## dispatch

## kimi: implement async X-11 monitor registry as described above.
## start with X-11.build_monitor_registry + finalize_server hook.
## then update get_pointer_scr_rect, screen_change handler, window.place.cmd.coords,
## and window.geometry.resolve in that order. verify each step in the live system
## using `p7c X-11.get_monitors` and `p7c X-11.get_pointer_scr_rect` before moving on.

#,,..,,.,,..,,,.,,,.,,.,.,,,.,,,.,.,.,..,,...,..,,...,...,..,,.,,,.,.,,..,,.,,
#L27NENZPR7ONLUCUX3HCT6S2VUFTCLHLJRAFC2EX6T5HA3D3WPHQITVWQC4GXUGAQJIQRMPHSRCCO
#\\\|FDZC7RXPPZ2JQV4YSNC45J76VU6DJ4H4SSNZZ6NF4LX7LVE7IRN \ / AMOS7 \ YOURUM ::
#\[7]WELWENSOQXK2MV3WGPUQHML7UCIASTTZCLPXP7V63O4GNGBQIICQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
