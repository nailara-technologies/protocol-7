## [:< ##

# name  = task: generic zenka window placement profiles
# descr = self-contained proportional window placement for GTK zenki that works
#         without tile-groups — config profiles + runtime switching + save/restore

## context

under WSL/Wayland in host mode, X-11 cannot enumerate windows, so tile-groups
has no placement control over zenki like ticker, rss-ticker, osd-logo, etc.
on kiosk hardware this is fine — tile-groups manages everything. on interactive
hosts the zenki default to fallback positions (often fullscreen or 0,0) which
is wrong for desktop use.

the protocol-7-menu zenka recently got save/restore of absolute pixel positions
(src/protocol-7-menu.position.*). tile-groups uses proportional % coordinates
calculated from screen dimensions. this feature combines both approaches:

- **proportional profile** — position and size as % of screen, relative to anchor
- **self-contained** — no tile-groups dependency, works in host mode
- **named profiles** — switchable by config or runtime command
- **save/restore** — user-dragged position saved and restored as a custom profile
- **generic** — reusable base modules any GTK zenka can load

reference implementations to read:
```bash
cat src/tile-groups.calculate_coordinates   ## proportional % math
cat src/protocol-7-menu.position.load       ## yaml save/restore pattern
cat src/protocol-7-menu.position.save
cat src/protocol-7-menu.graphical-startup-init  ## how position is applied
cat src/ticker.init_code                    ## ticker window setup
cat src/ticker.open_window                  ## where GTK window is created
```

## signatures note

do not add signature stubs. do not run `bin/Protocol-7 sourcecode update-signatures`.
do not add or modify subroutine whitelists — these are managed separately.

---

## built-in profiles

profiles express position and size as percentages of screen dimensions,
relative to an anchor point. screen dimensions are fetched from X-11 zenka
(`X-11.cmd.get_screen_size`) or from `$ENV{DISPLAY}` geometry as fallback.

### standard profiles

| profile name | anchor | x% | y% | w% | h% | description |
|---|---|---|---|---|---|---|
| `fullscreen` | top-left | 0 | 0 | 100 | 100 | kiosk default |
| `bottom-strip` | bottom-left | 0 | 95 | 100 | 5 | horizontal bar at bottom |
| `top-strip` | top-left | 0 | 0 | 100 | 5 | horizontal bar at top |
| `bottom-right` | bottom-right | 75 | 90 | 25 | 8 | compact corner widget |
| `top-right` | top-right | 75 | 0 | 25 | 8 | compact corner widget |
| `center` | center | 25 | 25 | 50 | 50 | centered floating window |
| `saved` | — | — | — | — | — | use last user-dragged position |
| `config` | — | — | — | — | — | use explicit cfg.window.* values |

anchor affects which screen edge x%/y% is measured from:
- `top-left` — standard: x from left, y from top
- `bottom-left` — x from left, y from bottom (y% = distance from bottom edge)
- `top-right` — x from right, y from top
- `bottom-right` — x from right, y from bottom
- `center` — x and y as offset from screen center

---

## modules to implement

### base.window.profile.calculate

generic module, loadable by any GTK zenka.

```
args: {
  profile     => 'bottom-strip',  ## profile name or 'config' or 'saved'
  screen_w    => 2560,            ## screen width in pixels
  screen_h    => 1440,            ## screen height in pixels
  window_w    => undef,           ## current window width (for 'saved' anchor)
  window_h    => undef,
}

returns: {
  x      => 0,
  y      => 1368,
  width  => 2560,
  height => 72,
  profile => 'bottom-strip',
}
```

implements the proportional math from tile-groups.calculate_coordinates,
extended with anchor semantics. handles all built-in profiles.

for `config` profile: reads `<{zenka}.window.x_pct>`, `<{zenka}.window.y_pct>`,
`<{zenka}.window.w_pct>`, `<{zenka}.window.h_pct>`, `<{zenka}.window.anchor>`.

### base.window.profile.apply

applies calculated position to a GTK window object:

```perl
my ( $window, $geometry ) = @_;

$window->move(   $geometry->{'x'}, $geometry->{'y'} );
$window->resize( $geometry->{'width'}, $geometry->{'height'} );
```

### base.window.profile.save

saves current window position to zenka-local yaml (same path as protocol-7-menu):
`cfg/zenki/<name>/window/position.yaml`

```perl
my ( $zenka_name, $x, $y, $width, $height ) = @_;
## write yaml to cfg/zenki/<name>/window/position.yaml
## format: { x: N, y: N, width: N, height: N, profile: 'saved' }
```

### base.window.profile.load

loads saved position, returns undef if no saved position exists.
same pattern as `protocol-7-menu.position.load`.

### base.window.get_screen_size

fetches screen dimensions. tries in order:
1. `p7 X-11.cmd.get_screen_size` via P7 route
2. `$ENV{DISPLAY}` + Gtk3::Gdk::Screen geometry
3. fallback 1920x1080

---

## ticker integration

### cfg defaults to add in `src/ticker.init_code`

```perl
<ticker.window.profile>  //= 'bottom-strip';  ## sensible desktop default
<ticker.window.anchor>   //= 'bottom-left';
## for 'config' profile:
# <ticker.window.x_pct>  //= 0;
# <ticker.window.y_pct>  //= 95;
# <ticker.window.w_pct>  //= 100;
# <ticker.window.h_pct>  //= 5;
```

### apply profile in `src/ticker.open_window`

after the GTK window is created and before it is shown:

```perl
my $screen = <[base.window.get_screen_size]>;
my $geo = <[base.window.profile.calculate]>->({
    profile  => <ticker.window.profile>,
    screen_w => $screen->{'width'},
    screen_h => $screen->{'height'},
});
<[base.window.profile.apply]>->( $window, $geo );
```

### new command: `ticker.cmd.set-window-profile`

switches profile at runtime and saves if profile is 'saved':

```perl
my $profile = $call->{'args'} // 'bottom-strip';
<ticker.window.profile> = $profile;
## recalculate and apply
my $screen = <[base.window.get_screen_size]>;
my $geo = <[base.window.profile.calculate]>->({
    profile  => $profile,
    screen_w => $screen->{'width'},
    screen_h => $screen->{'height'},
});
<[base.window.profile.apply]>->( <ticker.gtk_obj.window>, $geo );
return "window profile: $profile";
```

---

## start.cfg example

```
## window placement profile
## options: fullscreen bottom-strip top-strip bottom-right top-right center saved config
ticker.window.profile = bottom-strip
```

---

## test sequence

```bash
## default profile (bottom-strip)
p7c v7.restart ticker
## verify: ticker appears as horizontal bar at screen bottom

## switch to top-strip at runtime
p7c ticker.cmd.set-window-profile top-strip
## verify: ticker moves to top of screen

## switch to fullscreen (kiosk mode)
p7c ticker.cmd.set-window-profile fullscreen
## verify: ticker fills screen

## switch back to saved position
p7c ticker.cmd.set-window-profile bottom-strip
```

## success criteria

- [ ] `base.window.profile.calculate` implements all standard profiles
- [ ] proportional math correct: `bottom-strip` on 2560x1440 → y≈1368, h≈72
- [ ] anchor semantics work: `bottom-right` y% measured from bottom edge
- [ ] `base.window.profile.apply` moves and resizes GTK window
- [ ] `base.window.profile.save` / `.load` use yaml in cfg/zenki/<name>/
- [ ] ticker uses `bottom-strip` as default profile (not fullscreen on desktop)
- [ ] `p7c ticker.cmd.set-window-profile <name>` switches at runtime
- [ ] works without tile-groups running
- [ ] `fullscreen` profile still works for kiosk deployments
- [ ] no signature stubs added, no subroutine whitelist changes made

#,,,.,,,.,,..,..,,,..,,,.,,,,,.,,,.,.,,..,,.,,..,,...,...,..,,...,,,,,,,,,,..,
#Z73KFJ5PCHY3ABRWQY7TTTUNQTYLMUQWRU255L4AMMMNQHK6PH4TZE4PR2VBFO5M5ULRZLTTF6O3O
#\\\|43PPB5KTNUJSK4DZVAJACJVQPCTDES65WENMHZL6WMFP4CONZ5C \ / AMOS7 \ YOURUM ::
#\[7]YWD75YUNSZ427INE7B4SWEXSBF7HV3XTQWXVDUDQUJHC54TAP4CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
