## [:< ##

# name  = task: iris negotiation window counter
# descr = show remaining time at each logical route hop as shrinking arc brightness
#         urgency signal: pulse rate increases as floor budget depletes

## concept

from the logical/physical route split:
  at each logical hop: the entity descends vertical floors while waiting
  each floor consumed = one more clock cycle of negotiation time
  
the visual:
  each active route's current logical hop arc: shows remaining floor budget
  full budget (just arrived): bright
  50% consumed: slightly pulsing
  80% consumed: fast pulsing (urgent)
  timeout: flash (ledger 000, behavior) + alternate route triggered

## data structure

<bmw384.route.negotiations> = {
  "$session_id:$hop_index" => {
    arc:           N,          # which arc this hop is at
    floor_budget:  N,          # total floors allowed at this hop
    floors_used:   N,          # floors consumed so far
    started_at:    timestamp,
    timeout_action: 'flash'|'reroute'|'fail'
  }
}

## negotiation urgency levels

```perl
sub negotiation_urgency {
    my ($budget, $used) = @_;
    return 0.0 if $budget <= 0;
    my $ratio = $used / $budget;
    return $ratio;  # 0.0 = fresh, 1.0 = expired
}
```

## new module: route.bmw384.visual.negotiation-overlay

```perl
# name  = route.bmw384.visual.negotiation-overlay
# descr = render negotiation urgency as arc brightness + pulse rate

my $negs = <bmw384.route.negotiations> // {};
my $now  = <[base.time]>->(3);
my $svg  = '';

my $PI          = 3.14159265358979;
my $segment_deg = 360 / 26;
my $outer_r     = <route.bmw384.cfg.outer_radius> // 320;

for my $key ( keys %$negs ) {
    my $neg     = $negs->{$key};
    my $arc     = $neg->{'arc'};
    my $budget  = $neg->{'floor_budget'} // 10;
    my $used    = $neg->{'floors_used'}  // 0;
    my $urgency = $used / ( $budget || 1 );
    
    # [ arc center angle ]
    my $angle_deg = -( $arc + 0.5 ) * $segment_deg;
    my $rad       = $angle_deg * $PI / 180;
    
    # [ urgency colors ]
    my $hue = int( 120 - $urgency * 120 );  # green → red
    my $op  = sprintf '%.2f', 0.2 + $urgency * 0.6;
    
    # [ pulse: fast when urgent ]
    # SVG animate element for opacity pulsing
    my $pulse_dur = sprintf '%.1f', 2.0 - $urgency * 1.5;  # 2s → 0.5s
    
    # [ render arc segment glow ]
    my $r = $outer_r * 0.4;  # negotiation ring at 40% radius
    my $cx = 400 + $r * sin($rad);
    my $cy = 400 - $r * cos($rad);
    
    $svg .= sprintf
        '  <circle cx="%.2f" cy="%.2f" r="8"'
        . ' fill="hsl(%d,85%%,55%%)" opacity="%s">' . "\n",
        $cx, $cy, $hue, $op;
    
    if ( $urgency > 0.5 ) {
        # [ add pulse animation for urgent negotiations ]
        $svg .= sprintf
            '    <animate attributeName="opacity" values="%s;%s;%s"'
            . ' dur="%ss" repeatCount="indefinite"/>' . "\n",
            $op, sprintf('%.2f', $op * 0.3), $op, $pulse_dur;
    }
    
    $svg .= sprintf
        '    <title>hop %s: %d/%d floors</title>' . "\n",
        $key, $used, $budget;
    $svg .= '  </circle>' . "\n";
    
    # [ timeout: trigger flash behavior ]
    if ( $urgency >= 1.0 ) {
        # [ mark as timed out — the 000, flash ]
        $svg .= sprintf
            '  <circle cx="%.2f" cy="%.2f" r="12"'
            . ' fill="white" opacity="0.9">'
            . '<title>TIMEOUT hop %s</title></circle>' . "\n",
            $cx, $cy, $key;
        # [ signal to the routing layer: find alternate ]
    }
}

return $svg;
```

## integration

inject negotiation-overlay SVG before </svg> in iris-svg handler.
always active as an overlay layer (no separate mode needed).
controlled by: <route.bmw384.cfg.show_negotiations> // 1

## floor budget increment

called by route execution layer each clock cycle:
  route.bmw384.negotiation.tick:
    for each active negotiation:
      increment floors_used by 1
      if floors_used >= floor_budget: trigger timeout action

## test simulation

POST /iris/negotiate:
  session_id: "test"
  hop: 0
  arc: N
  budget: 10
  used: M

## signatures note

new module: leave clean. existing: re-signed on commit.

#,,,,,...,...,...,..,,,,.,,,,,,,,,,,,,.,,,..,,..,,...,...,.,,,,,,,.,,,,.,,,,,,
#AWGPXO6GHSMQ7ZLN3AGKWRZFEJNMDHRIJMFSUG67YRSSCECSSQJJVROXQW4RK5PLXHDJD6JO2JF2K
#\\\|CVOMW65WRHVH67RU73RDJOI2OU7CLHQKEX4EHGYKHGHU4BFAADF \ / AMOS7 \ YOURUM ::
#\[7]SGLWRBDO64MA2OP7WKWE25QBUTDGHK5ZDSTBJFCKHBIWVHUP4QCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
