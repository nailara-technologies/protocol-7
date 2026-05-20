## [:< ##

# name  = task: iris stream oscilloscope mode
# descr = map the 13 zulum harmonic streams to 13 iris rings
#         live brightness per ring = current stream value
#         the div-13 table made spatial and live

## concept

the zulum zenka runs 13 parallel division-by-13 entropy streams.
each stream has a current value and an is_true() state.
map each stream to one iris ring: brightness = normalized stream value.
the iris becomes a live oscilloscope of the harmonic field.
no namespace filter needed — this mode reads from zulum directly.

## data source

zulum streams are accessible via:
  p7c zulum.stream-status  — returns all 13 stream states
  
each stream returns:
  stream_id:  1-13
  state:      current Z value (large integer)
  entropy:    42-bit binary string
  is_true:    boolean
  iteration:  count

## new mode: route.bmw384.visual.wheel.oscilloscope

```perl
# name  = route.bmw384.visual.wheel.oscilloscope
# descr = iris rings as live zulum stream oscilloscope
#         ring N = stream N, brightness = normalized stream value

return undef if not defined <bmw384.index>;

# [ fetch zulum stream states ]
my $streams = {};
for my $sid ( 1 .. 13 ) {
    my $reply = <[protocol-7.call]>->(
        { 'command' => 'zulum.stream-status',
          'call_args' => { 'args' => $sid } }
    );
    $streams->{$sid} = $reply->{'data'} if defined $reply;
}

# [ parameters ]
my $outer_radius = <route.bmw384.cfg.outer_radius> // 320;
my $rings        = 13;  # one per zulum stream
my $ring_step    = ( $outer_radius - 30 ) / $rings;

my $PI          = 3.14159265358979;
my $segment_deg = 360 / 26;

my $svg = '<?xml version="1.0" encoding="UTF-8"?>' . "\n";
$svg .= '<svg xmlns="http://www.w3.org/2000/svg"'
    . ' viewBox="0 0 800 800" width="800" height="800">' . "\n";
$svg .= '  <rect width="800" height="800" fill="#0a0a0f"/>' . "\n";

# [ render 13 rings, one per stream ]
for my $sid ( 1 .. 13 ) {
    my $stream  = $streams->{$sid} // {};
    my $entropy = $stream->{'entropy'} // '0' x 42;
    my $is_true = $stream->{'is_true'} // 0;
    my $radius  = $outer_radius - ( $sid - 1 ) * $ring_step;
    
    # [ hue: TRUE family = warm (orange/yellow), FALSE family = cool (blue/cyan) ]
    # streams 1-6: FALSE family (076923 rotations)
    # streams 7-12: TRUE family (153846 rotations)  
    # stream 13: convergence (special)
    my $hue = $sid <= 6  ? int( 200 + $sid * 10 )   # blue-cyan
            : $sid <= 12 ? int( 30 + ($sid-7) * 15 ) # orange-yellow
            :               120;                      # green (convergence)
    
    # [ brightness from entropy bit density ]
    my $bit_count = ( $entropy =~ tr/1// );
    my $brightness = $bit_count / 42;
    
    # [ is_true ring: slightly brighter, different saturation ]
    my $sat     = $is_true ? '95%' : '70%';
    my $light   = int( 20 + $brightness * 50 );
    my $opacity = sprintf '%.2f', 0.3 + $brightness * 0.65;
    
    # [ render full ring circle ]
    $svg .= sprintf
        '  <circle cx="400" cy="400" r="%.1f" fill="none"'
        . ' stroke="hsl(%d,%s,%d%%)" stroke-width="%.1f"'
        . ' opacity="%s"/>' . "\n",
        $radius, $hue, $sat, $light,
        2 + $brightness * 4,   # thicker when more active
        $opacity;
    
    # [ stream label ]
    $svg .= sprintf
        '  <text x="%.1f" y="%.1f" fill="hsl(%d,%s,%d%%)"'
        . ' font-size="7" text-anchor="middle"'
        . ' dominant-baseline="middle" opacity="0.5">%d</text>' . "\n",
        400 + ( $radius + 8 ) * sin( -0.1 ),
        400 - ( $radius + 8 ) * cos( -0.1 ),
        $hue, $sat, $light + 20, $sid;
}

# [ center void ]
$svg .= '  <circle cx="400" cy="400" r="24" fill="none"'
    . ' stroke="rgba(255,255,255,0.15)" stroke-width="1"/>' . "\n";

# [ legend ]
$svg .= '  <text x="400" y="790" fill="rgba(255,255,255,0.3)"'
    . ' font-size="9" text-anchor="middle">'
    . 'zulum · 13 streams · blue=FALSE · amber=TRUE · brightness=entropy</text>' . "\n";

$svg .= '</svg>' . "\n";
return $svg;
```

## add protocol-7.call module to httpd source if not present

check configuration/zenki/httpd/source/ for protocol-7 or base.call modules.
if zulum is not reachable from httpd, fall back to reading
<zulum.stream.N> data keys if httpd and zulum share memory (same zenka).

alternatively: poll zulum via p7c and cache in <bmw384.oscilloscope.cache>
with a short TTL (0.5s) so repeated renders don't hammer zulum.

## wire into wheel-mode and iris UI

wheel-mode: add `elsif ( $mode eq 'oscilloscope' )`
iris UI: `<button class="mode-btn" data-mode="oscilloscope">osc</button>`
whitelist: route.bmw384.visual.wheel.oscilloscope

## auto-refresh

the oscilloscope mode should auto-refresh every 500ms:
in iris index.html, when mode = 'oscilloscope':
  setInterval(() => render(), 500);
stop interval when mode changes.

## signatures note

new module: leave clean. existing: re-signed on commit.

#,,,.,..,,...,.,.,..,,,..,.,.,,,.,,.,,,,,,.,,,..,,...,...,..,,,,.,.,.,,.,,...,
#J3ZZFUNHVXVQQZOLVUAEMTW5JK6Z2YCHW63DDJYQQZFQ5SHDZ34JLM7GPF5UYYRMJUEUHZ5QYLN2O
#\\\|D22JISMEKA3BNJ7MMSL26BXTZ5LOC2ACFM5G6TEDDIN744L6IR3 \ / AMOS7 \ YOURUM ::
#\[7]G7DCPMV2GLAJE5WRPA2W7B7SK6RB2GSHKDJRVTG72K4U5MR7BMAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
