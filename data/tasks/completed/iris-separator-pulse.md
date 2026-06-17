## [:< ##

# name  = task: iris separator pulse layer
# descr = make the invisible separator cube activity briefly visible
#         buffer swaps appear as brief pulses on arc spoke boundaries

## concept

separator cubes are normally invisible — they ARE the grid.
in diagnostic mode: show their activity as brief pulses on spoke boundaries.
each pulse: one buffer swap event.
pulse color: which lane is being served (horizontal/vertical onboarding).

## pulse data structure

<bmw384.separator.pulses> = [
  { arc => N, timestamp => T, type => 'HH'|'HV'|'VH'|'VV', intensity => 0-1 },
  ...
]

new entries added by the routing layer when buffer swaps occur.
entries older than 0.5s: pruned.

## pulse type colors

```
HH (horizontal→horizontal):  white pulse  (pass-through)
HV (horizontal→vertical):    magenta pulse (onboarding — intake path)
VH (vertical→horizontal):    cyan pulse    (offboarding — delivery)
VV (vertical→vertical):      blue pulse    (deep routing)
```

## new module: route.bmw384.visual.separator-pulse

```perl
# name  = route.bmw384.visual.separator-pulse
# descr = render active separator cube pulse events on spoke boundaries

my $pulses = <bmw384.separator.pulses> // [];
my $now    = <[base.time]>->(3);
my $svg    = '';

my $PI          = 3.14159265358979;
my $segment_deg = 360 / 26;
my $outer_r     = <route.bmw384.cfg.outer_radius> // 320;

for my $pulse (@$pulses) {
    my $age       = $now - $pulse->{'timestamp'};
    next if $age > 0.5;
    
    my $arc       = $pulse->{'arc'};
    my $type      = $pulse->{'type'} // 'HH';
    my $intensity = $pulse->{'intensity'} // 1.0;
    
    # [ fade over 500ms ]
    my $opacity = sprintf '%.2f', $intensity * ( 1 - $age / 0.5 );
    next if $opacity < 0.05;
    
    # [ spoke boundary position: between arc N and N+1 ]
    my $boundary_angle = -( $arc + 0.5 ) * $segment_deg * $PI / 180;
    
    # [ pulse colors by type ]
    my $color = $type eq 'HH' ? 'rgba(255,255,255,%s)'
              : $type eq 'HV' ? 'rgba(255,0,255,%s)'
              : $type eq 'VH' ? 'rgba(0,255,255,%s)'
              :                  'rgba(80,80,255,%s)';
    my $fill = sprintf $color, $opacity;
    
    # [ pulse shape: small diamond on the spoke at mid-radius ]
    my $r   = 80 + ( $outer_r - 80 ) * 0.5;
    my $cx  = 400 + $r * sin($boundary_angle);
    my $cy  = 400 - $r * cos($boundary_angle);
    my $sz  = 3 + $intensity * 4;
    
    $svg .= sprintf
        '  <circle cx="%.2f" cy="%.2f" r="%.1f" fill="%s">'
        . '<title>sep pulse %s</title></circle>' . "\n",
        $cx, $cy, $sz, $fill, $type;
}

return $svg;
```

## integration

inject separator-pulse SVG before </svg> in iris-svg handler
(same pattern as flying-elements and route-commitment).

the pulse layer is always active as an overlay —
not a separate mode but a diagnostic layer controlled by:
  <route.bmw384.cfg.show_separator_pulses>  // 0

toggle in UI: small checkbox or button "sep" in the controls row.

## simulating pulses for testing

POST /iris/pulse:
  arc: 0-25
  type: HH|HV|VH|VV
  intensity: 0.0-1.0

adds a test pulse to the pulse buffer.
useful for demonstrating the visual before real routing data exists.

## auto-refresh when pulses active

if show_separator_pulses = 1 and pulse buffer is non-empty:
  auto-refresh the iris SVG every 100ms (fast enough to see pulse decay)

## signatures note

new module: leave clean. existing: re-signed on commit.

#,,.,,,..,...,,..,...,,..,,.,,.,.,.,.,..,,.,.,..,,...,..,,,.,,.,,,.,.,,.,,,..,
#QXMH5QFBTML73Y6F7QICLPSKZVWWMI4J4NBVGLKKTCF2YXUZMZ7YUW6BDIJ5I2BKEJ7EJGDTM42VM
#\\\|FVZSFPEENCPIUEHT7OQR3USKE6FUT36Y36DO2HRE3IY5HZRRHDX \ / AMOS7 \ YOURUM ::
#\[7]DOJPVMQV45IXIMEXLKIADVETNUY7ZFEAN635N3OWTFDKYMOKY4BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
