## [:< ##

# name  = task: iris cascade early warning
# descr = predict resource depletion before it happens: warming amber glow
#         on arcs approaching 000 state. cascade front detection.

## concept

given: current ledger counters + depletion rates per arc
compute: which arcs will hit 0 within N clock cycles
show: warming color before the flash occurs

the cascade:
  three adjacent arcs warming simultaneously = congestion front approaching
  visible 1-2 rotations before the brownout
  the network has time to reroute

## depletion rate tracking

new data structure: <bmw384.ledger.rates>
  { "arc:ring" => depletion_rate }  # units per second
  
updated by route.bmw384.ledger.decrement:
  track timestamps of decrements
  compute rolling average rate over last 10 decrements

## warning calculation

```perl
# name  = route.bmw384.ledger.warning_map
# descr = compute which arc:ring positions will deplete within N seconds
# args  = $horizon_secs (default 5)

my $horizon = shift // 5;
my %warnings;

my $counts = <bmw384.ledger.counts> // {};
my $rates  = <bmw384.ledger.rates>  // {};
my $now    = <[base.time]>->(3);

for my $key ( keys %$counts ) {
    my $count = $counts->{$key};
    my $rate  = $rates->{$key} // 0;
    
    next if $rate <= 0;  # not depleting
    
    my $time_to_zero = $count / $rate;
    
    if ( $time_to_zero <= $horizon ) {
        # [ warning intensity: 0.0 (far) to 1.0 (imminent) ]
        $warnings{$key} = 1 - ( $time_to_zero / $horizon );
    }
}

return \%warnings;
```

## visual integration in wheel.ledger

add warning overlay pass after normal rendering:

```perl
my $warnings = <[route.bmw384.ledger.warning_map]>->( 5 );

for my $key ( keys %$warnings ) {
    my $intensity = $warnings->{$key};
    my ( $arc, $ring ) = split ':', $key;
    
    # [ amber warning glow on this arc segment ]
    # [ intensity 0=barely visible, 1=bright amber pre-flash ]
    my $warn_color = sprintf 'hsl(35,90%%,%d%%)', int(30 + $intensity * 40);
    my $warn_op    = sprintf '%.2f', 0.1 + $intensity * 0.6;
    
    # [ render a warning arc segment at this position ]
    # ... arc SVG path covering the affected arc segment
}
```

## cascade front detection

```perl
# detect three adjacent arcs all warning simultaneously
# same ring, arcs N, N+1, N+2 all with intensity > 0.5

my @cascade_fronts;
for my $ring ( 0 .. $rings - 1 ) {
    for my $arc ( 0 .. 25 ) {
        my $n0 = $warnings{"$arc:$ring"}           // 0;
        my $n1 = $warnings{"$(($arc+1)%26):$ring"} // 0;
        my $n2 = $warnings{"$(($arc+2)%26):$ring"} // 0;
        
        if ( $n0 > 0.5 and $n1 > 0.5 and $n2 > 0.5 ) {
            push @cascade_fronts, {
                arc => $arc, ring => $ring,
                intensity => ($n0 + $n1 + $n2) / 3
            };
        }
    }
}

# [ cascade front: render a larger warning arc spanning 3 segments ]
# [ color: deeper amber/red based on intensity ]
```

## UI notification

when cascade front detected:
  status bar: "⚠ cascade front at arc [N] ring [M]"
  color: amber
  
when cascade resolves (NRT recharged):
  status bar returns to normal

## ledger mode dependency

this feature requires the ledger mode to be active.
add to ledger module:
  after each decrement: call warning_map
  if any warning > 0.8: log at level 1

## signatures note

new modules: leave clean. existing: re-signed on commit.

#,,,,,.,.,.,,,...,...,.,.,,.,,,.,,..,,...,,..,..,,...,...,.,,,,,,,,..,,..,,,,,
#SYM6E2L5RZ5PIPQIA3AUVXILZ47VIZXJLZ5G5VVUY6G4XHJ6VNULVYQY5ZZ453DHDY2VAVHUYY3MY
#\\\|PIBILZYZIIJ3ACVFPRK46764A3YPGWVSHRBELMXZQEB5Y7U366A \ / AMOS7 \ YOURUM ::
#\[7]DPLI4LPPTQTINSAS4BFJI6NL5ZUL72T44GZEX5LTOZPOJXAFDEBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
