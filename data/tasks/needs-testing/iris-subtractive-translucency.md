## [:< ##

# name  = task: iris subtractive translucency mode modifier
# descr = black arc spokes leak translucency onto colored neighbors
#         proportional to isolation. grouped colored arcs gain resilience.
#         4 modes: 0=off, 1=bidirectional, 2=CCW, 3=CW

## concept

empty arcs (black, no nodes) "leak" opacity reduction onto adjacent
colored arcs. isolated colored arcs become more translucent. grouped
colored arcs protect each other (resilience).

the effect: anti-aliasing / blur but with ALPHA as the channel —
producing a psychedelic depth effect where sparse regions fade and
dense regions glow.

## algorithm

### step 1: build arc occupancy map

for each arc 0..25:
  $arc_occupied[$arc] = 1 if any nodes exist at that arc
  $arc_occupied[$arc] = 0 if no nodes (black spoke)

### step 2: compute opacity modifier per arc

for each arc that IS occupied (colored):
  count black neighbors in the mode direction:
  
  mode 1 (bidirectional): check left AND right
  mode 2 (CCW):           check CCW neighbor only
  mode 3 (CW):            check CW neighbor only
  
  window: check up to 3 neighbors in each direction
  weight by distance:
    distance 1: weight 1.00  (full leak)
    distance 2: weight 0.50  (half leak)
    distance 3: weight 0.25  (quarter leak)
    
  leak_total = sum of (weight * is_black) for each neighbor checked
  
  resilience: count immediately adjacent occupied arcs
  resilience_bonus = 0.10 per adjacent colored arc
  
  opacity_modifier = 1.0 - (leak_total * 0.25) + resilience_bonus
  clamp: max(0.25, min(1.0, opacity_modifier))

### examples from spec

```
0: blue  : 1.00  <- no black neighbors
1: blue  : 0.75  <- 1 black neighbor at distance 1 (arc 2)
2: black : 1.00  <- black always 1.00
3: black : 1.00

0: black : 1.00
1: blue  : 0.50  <- 2 black neighbors (arcs 0 and 2)
2: black : 1.00
3: black : 1.00
```

verified:
  blue(1) with 1 black: 1.0 - (1.0 * 0.25) = 0.75 ✓
  blue(1) with 2 black: 1.0 - (2 * 1.0 * 0.25) = 0.50 ✓

## config key

<route.bmw384.cfg.translucency_mode>  // 0

0 = disabled (default, no change)
1 = bidirectional
2 = CCW only
3 = CW only

## new module: route.bmw384.visual.arc-opacity-map

```perl
# name  = route.bmw384.visual.arc-opacity-map
# descr = compute per-arc opacity modifiers for subtractive translucency
# args  = \@names, \%by_name, $mode
# returns hashref: { arc => opacity_modifier (0.25..1.0) }

my $names   = shift;   # arrayref of module names to consider
my $by_name = shift;   # BMW384 index by_name
my $mode    = shift // 0;

return {} if $mode == 0;

# [ build occupancy map ]
my @occupied = (0) x 26;
for my $ARG (@$names) {
    my $arc = $by_name->{$ARG}{'arc'} // next;
    $occupied[$arc] = 1;
}

# [ compute modifier per occupied arc ]
my %mod;
for my $arc ( 0 .. 25 ) {
    next unless $occupied[$arc];

    my $leak       = 0;
    my $resilience = 0;

    # [ neighbor directions based on mode ]
    my @directions;
    push @directions, -1 if $mode == 1 or $mode == 3;  # CW  = -1
    push @directions,  1 if $mode == 1 or $mode == 2;  # CCW = +1

    for my $dir (@directions) {
        for my $dist ( 1 .. 3 ) {
            my $neighbor = ( $arc + $dir * $dist ) % 26;
            my $weight   = 1 / $dist;
            if ( $occupied[$neighbor] ) {
                $resilience += 0.10 if $dist == 1;
                last;    # stop at first colored neighbor
            } else {
                $leak += $weight;
            }
        }
    }

    my $modifier = 1.0 - ( $leak * 0.25 ) + $resilience;
    $modifier = 0.25 if $modifier < 0.25;
    $modifier = 1.0  if $modifier > 1.0;
    $mod{$arc} = $modifier;
}

return \%mod;
```

## integration in wheel modules

in each wheel module, after building @names/@sorted_names
and BEFORE the node rendering loop:

```perl
# [ subtractive translucency arc opacity map ]
my $translucency_mode = <route.bmw384.cfg.translucency_mode> // 0;
my $arc_opacity_mod   = <[route.bmw384.visual.arc-opacity-map]>->(
    \@sorted_names, $by_name, $translucency_mode
);
```

then in the node rendering loop, modify the opacity:

```perl
# existing: my $opacity = sprintf '%.2f', 0.85 * ( 0.75**$ring );
# add after:
if ( $translucency_mode and exists $arc_opacity_mod->{ $coord->{'arc'} } ) {
    $opacity = sprintf '%.2f',
        $opacity * $arc_opacity_mod->{ $coord->{'arc'} };
}
```

## cmd.visual-wheel parsing

add 'translucency' or 'tl' as a mode modifier parameter:
  p7c index.visual-wheel file 26 ring tl=2

parse tl=N, save/restore <route.bmw384.cfg.translucency_mode>

## iris UI addition

in iris.v7.ax/index.html, add translucency mode selector:

```html
<div class="param-row">
  <span class="param-label">translucency</span>
  <button class="mode-btn active" data-tl="0">off</button>
  <button class="mode-btn" data-tl="1">bi</button>
  <button class="mode-btn" data-tl="2">ccw</button>
  <button class="mode-btn" data-tl="3">cw</button>
</div>
```

pass as &tl=N in render URL.
in httpd.route.handler.iris-svg: parse tl param,
save/restore translucency_mode, include in cache key.

## apply to these modules

  route.bmw384.visual.wheel           (ring mode)
  route.bmw384.visual.wheel.gauss     (gauss mode)
  route.bmw384.visual.wheel.arc-width (arc-width mode)
  route.bmw384.visual.wheel.overlay   (overlay mode — per namespace pass)
  route.bmw384.visual.wheel.density   (density mode)

skip: heatmap (no individual nodes), metric (uses different rings)

## signatures note

new module: leave clean, no stub footer.
existing modules: re-signed on commit.

## style

$ARG not $_ in loops (use for my $ARG, not grep/map with $_)
lowercase comments, [ word ] bracket annotations

#,,,.,.,,,.,,,,,.,.,,,.,.,.,.,,,,,..,,,.,,...,..,,...,..,,,..,,,,,,.,,.,.,,.,,
#ZIX7HG2VDVLZ6TTTNYCZZCFVWMEAHAYGOZYAJZ4IUOOG7D7EM45XYW5ACICR66OI4EN2IVMPA34QQ
#\\\|Y5EGPBW5ZLAET2O725VSF4JSDPFGE3CGAR3LT44LF64EZAINRBS \ / AMOS7 \ YOURUM ::
#\[7]DZN3KFEDSGYGTH6UOY3TEUSB2AAG3QBHP5SV3PVJGCBFZFOKISAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
