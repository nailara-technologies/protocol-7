## [:< ##

# name  = task: iris translucency intensity + expanse controls
# descr = add intensity (0.0-1.0) and expanse (1-5) parameters
#         to the subtractive translucency mode

## context

the arc-opacity-map module currently has two hardcoded values:
  leak weight per black neighbor: 0.25
  window size (how far leak travels): 3 neighbors

these should be configurable:

  intensity:   scales the per-neighbor leak weight
               0.0 = no effect (mode=0 equivalent but mode stays)
               0.5 = current behavior (0.25 * 2 = 0.50 max per neighbor)
               1.0 = strong fade (0.25 per neighbor at full)
               default: 0.5 (current behavior is intensity=0.5
                              since 0.25 = 0.5 * 0.5)
               
  expanse:     number of neighbors to check in each direction
               1 = immediate neighbor only
               3 = current behavior
               5 = wide shadow, distant black regions still leak
               default: 3

## config keys

<route.bmw384.cfg.translucency_intensity>  // 0.5
<route.bmw384.cfg.translucency_expanse>    // 3

## changes to route.bmw384.visual.arc-opacity-map

current hardcoded values to replace:

```perl
# current (hardcoded):
for my $dist ( 1 .. 3 ) {           # expanse = 3
    ...
    $leak += $weight;                # weight = 1/$dist
    ...
}
my $modifier = 1.0 - ( $leak * 0.25 ) + $resilience;  # 0.25 = intensity*0.5
```

updated signature:

```perl
# name  = route.bmw384.visual.arc-opacity-map
# args  = \@names, \%by_name, $mode, [$intensity], [$expanse]

my $names     = shift;
my $by_name   = shift;
my $mode      = shift // 0;
my $intensity = shift // <route.bmw384.cfg.translucency_intensity> // 0.5;
my $expanse   = shift // <route.bmw384.cfg.translucency_expanse>   // 3;

return {} if $mode == 0;

$expanse = 1 if $expanse < 1;
$expanse = 5 if $expanse > 5;
```

in the leak calculation loop:

```perl
for my $dist ( 1 .. $expanse ) {
    ...
    $leak += $weight;
    ...
}

my $leak_factor = $intensity * 0.5;  # 0.5 at intensity=1.0 matches original
my $modifier = 1.0 - ( $leak * $leak_factor ) + $resilience;
```

note: intensity=0.5 with leak_factor=0.25 matches current behavior exactly.
      intensity=1.0 gives leak_factor=0.5 (stronger effect).

## changes to wheel modules

in each wheel module that calls arc-opacity-map, pass the new params:

```perl
my $translucency_mode      = <route.bmw384.cfg.translucency_mode>      // 1;
my $translucency_intensity = <route.bmw384.cfg.translucency_intensity>  // 0.5;
my $translucency_expanse   = <route.bmw384.cfg.translucency_expanse>    // 3;

my $arc_opacity_mod = <[route.bmw384.visual.arc-opacity-map]>->(
    \@sorted_names, $by_name,
    $translucency_mode, $translucency_intensity, $translucency_expanse
);
```

apply to all 5 wheel modules:
  route.bmw384.visual.wheel
  route.bmw384.visual.wheel.gauss
  route.bmw384.visual.wheel.arc-width
  route.bmw384.visual.wheel.overlay  (uses \@ns_names)
  route.bmw384.visual.wheel.density

## changes to httpd.route.handler.iris-svg

parse two new query params:

```perl
my $intensity = $qparam{'intensity'} // '';
my $expanse   = $qparam{'expanse'}   // '';
```

apply if valid:

```perl
if ( length $intensity and $intensity =~ m{^\d*\.?\d+$} ) {
    <route.bmw384.cfg.translucency_intensity> = $intensity + 0;
}
if ( length $expanse and $expanse =~ m{^\d+$} ) {
    <route.bmw384.cfg.translucency_expanse> = int($expanse);
}
```

save/restore both (same pattern as other params).
include both in cache key:
  join ':', $mode, $rings, $param, $label_mode, $ns, $tl, $intensity, $expanse

## changes to cmd.visual-wheel

parse intensity=N and expanse=N params alongside tl=N.
save/restore pattern same as tl.

## iris UI

add two controls below the translucency mode buttons:

```html
<div class="param-row">
  <span class="param-label">intensity</span>
  <input class="rings-input" id="tl-intensity" type="number"
         min="0" max="1" step="0.1" value="0.5" style="width:4.5rem">
  <span class="param-label" style="margin-left:0.5rem">expanse</span>
  <input class="rings-input" id="tl-expanse" type="number"
         min="1" max="5" step="1" value="3" style="width:3rem">
</div>
```

wire into render URL: &intensity=N&expanse=N
trigger re-render on change (same as rings-input).

## overlay-search.html

same intensity + expanse inputs, same wiring.

## signatures note

existing modules: re-signed on commit.
no new modules needed.

## style

$ARG not $_ in loops
lowercase comments, [ word ] bracket annotations

#,,..,,.,,...,,,,,,.,,.,.,,,,,.,,,,,.,,,.,.,,,..,,...,...,,..,...,,,.,.,,,.,.,
#ADIX622RAEKXQI4C53U62WQIVANAPVMRMAY7B7525HMG6FWDFAPYTPGB3WA6B35YDTTVUTUYDLBXE
#\\\|KTUTWQUN32AO2GWRYATKHJILKPVP3SEVDJ2HDTDJZTMSAIETMIB \ / AMOS7 \ YOURUM ::
#\[7]VQAVOSQORSWAD7ZFFCLK2YHJTZ5XPUMVSSID4EUD4IWYCLUTTMCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
