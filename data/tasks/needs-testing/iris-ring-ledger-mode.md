## [:< ##

# name  = task: iris ring ledger mode — resource count buffer with octal counters
# descr = the iris disc as a living NRT resource ledger. each ring encodes a
#         3-bit octal counter (0-7) per arc. consuming resources clears bits.
#         separator inversion on 000 triggers a visible ring flash.

## concept

the full disc = maximum resources available in every direction.
actions (packets departing, resources consumed) decrement the counters.
the disc transforms: full → dotted rings → sparse rays → empty spokes.
each ring encodes its count in the 3+1 bit stream framing format.
separator inversion at 000 = ring flash = field collapse protection visible.

## the 3+1 octal encoding per arc segment

each arc segment on each ring encodes one 4-bit frame (3+1):

```
value  bits   separator   visual (dots in arc segment)
  7    111    .  (0)      ●●●● (3 dots + separator = nearly solid)
  6    110    .  (0)      ●●○● (2+gap+separator)
  5    101    .  (0)      ●○●● (dot-gap-dot-separator)
  4    100    .  (0)      ●○○● (dot-gap-gap-separator)
  3    011    .  (0)      ○●●● (gap-dot-dot-separator)
  2    010    .  (0)      ○●○● (gap-dot-gap-separator)
  1    001    .  (0)      ○○●● (gap-gap-dot-separator)
  0    000    , (1)       ○○○, (all empty + INVERTED separator = FLASH)
```

the separator dot:  always the 4th position in the arc segment
                    normal (0/dot): resource present, field stable
                    inverted (1/comma): counter = 0, field flash triggered

## the flash on separator inversion

when any arc segment counter reaches 0:
  the separator bit inverts (000 , instead of 000 .)
  the arc segment: triggers a visible flash
  
flash visual:
  brief brightness spike on the arc (opacity 1.0 for ~200ms)
  then fades to the dim "empty but present" state
  color: the arc's natural hue shifted toward white/cyan briefly
  
the flash encodes:
  "this arc just hit zero"
  "field collapse protection active"
  "routing alternatives should be sought"
  
coupling opportunities:
  flash → trigger subtractive translucency increase on that arc
  flash → activate neighbor arc highlighting (spreading awareness)
  flash → notify the route negotiation layer
  flash → trigger NRT recharge request
  flash → the vortex intake animation increases speed toward that arc
           (trying to resupply via the intake path)
  
multiple flashes (cascade):
  if neighboring arcs also hit 0:
  the flashes propagate around the ring
  visual: a wave of flashes going CCW
  = a resource depletion wave
  = visible congestion signal
  = the network equivalent of a power brownout indicator

## the ledger state transitions

```
full disc (all 7):    solid rings, maximum capacity
                       color: full saturation, high opacity
                       
mid-depletion (4):    regular dot spacing visible
                       rings: clearly segmented
                       
low (1-2):            wide gaps, mostly dark arcs
                       individual dots scattered
                       
empty (0):            separator flash, then:
                       one dim comma-dot per arc
                       the minimum visible presence
                       field still held open
                       
recharging:           dots filling back in from inner rings outward
                       following the CCW intake spiral
                       new resources: arrive at outer rings first
                       propagate inward
```

## new config keys

```perl
<route.bmw384.cfg.ledger_mode>     // 0   (0=off, 1=on)
<route.bmw384.cfg.ledger_counts>   // hashref: { "arc:ring" => 0..7 }
<route.bmw384.cfg.ledger_flash>    // hashref: { "arc:ring" => timestamp }
<route.bmw384.cfg.ledger_max>      // 7 (default max per counter)
```

## new module: route.bmw384.visual.wheel.ledger

based on route.bmw384.visual.wheel but:

1. for each node, instead of fixed opacity, derive opacity from
   the ledger counter at its (arc, ring) position:

```perl
my $arc  = $coord->{'arc'};
my $ring_key = "$arc:$ring";
my $count = <route.bmw384.cfg.ledger_counts>->{$ring_key} // 7;

# [ 3+1 encoding: map count to opacity ]
my $opacity;
if ( $count == 0 ) {
    # [ separator inverted — flash or dim comma state ]
    my $flash_t = <route.bmw384.cfg.ledger_flash>->{$ring_key} // 0;
    my $age = <[base.time]>->(3) - $flash_t;
    if ( $age < 0.2 ) {
        $opacity = 1.0;   # [ flash: full brightness ]
    } else {
        $opacity = 0.08;  # [ comma: minimum presence ]
    }
} else {
    # [ normal counter: opacity proportional to count ]
    $opacity = sprintf '%.2f', 0.15 + 0.80 * ( $count / 7 );
}
```

2. the separator dot rendered as a distinct visual element:
   - at the 4th position within the arc segment
   - color: slightly different hue (shifted +30° toward cyan)
   - when inverted (count=0): brighter, briefly

## new module: route.bmw384.ledger.decrement

```perl
# name  = route.bmw384.ledger.decrement
# descr = decrement a ledger counter, trigger flash on separator inversion
# args  = $arc, $ring

my $arc  = shift;
my $ring = shift;
my $key  = "$arc:$ring";

<route.bmw384.cfg.ledger_counts> //= {};
my $count = <route.bmw384.cfg.ledger_counts>->{$key} // 7;

if ( $count > 0 ) {
    $count--;
    <route.bmw384.cfg.ledger_counts>->{$key} = $count;
}

# [ separator inversion at 0 — trigger flash ]
if ( $count == 0 ) {
    <route.bmw384.cfg.ledger_flash>->{$key} = <[base.time]>->(3);
    <[base.logs]>->( 1, 'ledger: arc %d ring %d → 0 [FLASH]', $arc, $ring );
    # [ could trigger NRT recharge request here ]
}

return $count;
```

## new module: route.bmw384.ledger.increment

```perl
# name  = route.bmw384.ledger.increment
# descr = increment a ledger counter (resource recharge)
# args  = $arc, $ring, [$amount]

my $arc    = shift;
my $ring   = shift;
my $amount = shift // 1;
my $max    = <route.bmw384.cfg.ledger_max> // 7;
my $key    = "$arc:$ring";

<route.bmw384.cfg.ledger_counts> //= {};
my $count = <route.bmw384.cfg.ledger_counts>->{$key} // 0;
$count = $max if ( $count + $amount ) > $max;
$count += $amount if $count < $max;
<route.bmw384.cfg.ledger_counts>->{$key} = $count;

return $count;
```

## iris UI additions

add 'ledger' to mode buttons:
```html
<button class="mode-btn" data-mode="ledger">ledger</button>
```

add ledger simulation controls (for testing):
```html
<div class="param-row" id="ledger-controls" style="display:none">
  <button class="preset-btn" id="ledger-drain">drain arc</button>
  <button class="preset-btn" id="ledger-fill">refill</button>
  <input class="rings-input" id="ledger-arc" type="number"
         min="0" max="25" value="0" style="width:3rem">
</div>
```

POST /iris/ledger endpoint:
  action: 'decrement' | 'increment' | 'reset'
  arc: 0-25
  ring: 0-N
  amount: 1-7

## the flash as event coupling point

the flash is observable from the SVG consumer (the browser).
the iris page can detect flash states via the SVG data or a
separate event endpoint and couple them to:

  - audio: brief tone on flash (resource exhaustion sound)
  - animation: flying element launched toward depleted arc
                (the intake vortex responding to depletion)
  - UI highlight: flash arc labeled in status bar
  - network action: POST to /iris/route to create resupply route
  - the vortex mode: switch to that arc momentarily
                     (showing the intake trying to resupply)

## connection to NRT economy

the ledger counters represent actual NRT balance per route direction:
  counter 7: full NRT allocation for this arc/ring
  counter 0: NRT depleted, flash = request for reallocation
  
the loves-it tree determines recharge rates:
  popular arcs (high reference count): faster recharge
  depleted arcs: attract the intake vortex (CCW spiral response)
  
the visual:  the NRT economy made spatially visible
             depletion: the disc draining toward rays
             recharge:  the intake spiral refilling from outside
             flash:     the moment a direction asks for help
             =)

## signatures note

new modules: leave clean, no stub footer.
existing modules: re-signed on commit.

## style

$ARG not $_ in loops
lowercase comments, [ word ] bracket annotations

## dispatch

model: kimi
reasoning: medium

prompt: |
  Implement the task at data/tasks/iris-ring-ledger-mode.md

  Read the task file carefully — it describes the 3+1 octal encoding per arc segment,
  the separator inversion flash at count=0, and the new modules (route.bmw384.ledger.*
  and route.bmw384.visual.wheel.ledger). Also adds a ledger mode button to the iris UI
  with drain/fill simulation controls and a POST /iris/ledger endpoint. Read
  src/route.bmw384.visual.wheel first for SVG rendering patterns. New modules:
  leave clean, no signature stubs. Use $ARG not $_, lowercase comments.

#,,,.,..,,,,.,..,,..,,.,,,,,,,...,.,.,.,.,,..,..,,...,...,.,,,,,.,,,,,,..,...,
#KAM2ZNKROZD7UKTYX3OSLSVIWXY7O7WJVLCKGC2WNYZGY57EYFWLRRCKENGRUVYWFSZE24XOVMOHM
#\\\|KN4MJVG2AJ3ZGIRKTFMJJBCZOU6BVQYDRAFJ7W6LDCGVWB3ZFFZ \ / AMOS7 \ YOURUM ::
#\[7]36CLIBAXVPKUAY74TYEVLZORDNIUPREAKCA2YB3DFBO4EEFLMABQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
