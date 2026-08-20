
 .:[  zulum + cube-13 + decoder : entropy stream utility infrastructure  ]:.

## Context

Three zenka stubs have been waiting for initialization:

```
cfg/zenki/zulum/start    ##  stream-13 producer   [ stub ]
cfg/zenki/cube-13/start  ##  division-13 router   [ stub ]
cfg/zenki/decoder/start  ##  stream decoder       [ stub ]
```

Research scripts (`bin/dev/division-13-table`, `bin/dev/gen-div`) already
implement the mathematics. This task promotes that research into live utility
infrastructure by initializing the stubs with the stream protocol designed
alongside the decoder zenka task.

## Architecture

```
zulum        →  generates 13 parallel division-by-13 entropy streams
cube-13      →  routes, switches, and jumps between streams
decoder      →  receives stream via cube-13, decodes multi-encoding layers
```

The `stream-add / stream-remove / stream-attach` interface is already
defined identically on both zulum and decoder — protocol-compatible without
new machinery. cube-13 is the switch matrix between them.

## Zulum : 13 Parallel Entropy Streams

Each of the 13 streams starts from one cycle position and applies repeated
division by 13, expanding entropy as `bin/dev/division-13-table` already
demonstrates for a single stream:

```
stream  1  →  gen×1  =  076923  entropy expansion
stream  2  →  gen×2  =  153846  [ UNKNOWN position ]
stream  3  →  gen×3  =  230769
stream  4  →  gen×4  =  307692
stream  5  →  gen×5  =  384615  [ TRUE position ]
...
stream 13  →  gen×13 =  999999  [ harmonic ceiling ]
```

Streams run independently, accumulating entropy without blocking each other.
Each stream is a named channel accessible via cube-13 routing.

### Stream State

```perl
## $data{'zulum'}{'streams'}{$n} = {
##     'seed'      => $generator * $n,   ## cycle position
##     'current'   => $value,            ## current expansion value
##     'iteration' => $count,            ## steps taken
##     'is_true'   => is_true($value),   ## harmonic truth of current value
## }
```

## Cube-13 : Switch Matrix

Routes between the 13 zulum streams. Switching is navigation between cycle
positions — the same jumps the 0.6/0.7 operators perform, now as live
routing decisions:

```
jump 3 → 5     ##  /0.6 operator: from ×3 position to TRUE (×5)  ##
jump N → rev   ##  /0.7 operator: digit reversal, back to generator ##
jump N → N+1   ##  step forward one cycle position                  ##
broadcast      ##  send to all 13 streams simultaneously            ##
```

The jump table maps operator names to stream transitions:

```perl
my %jump = (
    'true'    => sub { 5 },                      ## always to TRUE position   ##
    'reverse' => sub { rev_cycle_pos($ARG) },    ## /0.7 reversal             ##
    'next'    => sub { ($ARG % 13) + 1 },        ## step forward              ##
    'prev'    => sub { (($ARG - 2) % 13) + 1 },  ## step back                 ##
);
```

## Decoder : Verified Test Harness

The decoder receives zulum streams via cube-13 and decodes multi-encoding
layers. Harmonic properties of the streams are fully known — every decoded
packet is verifiable against `gen-div` output and AMOS7 truth checks:

```
decoded value → asc-enc → TRUE/FALSE/L\ result
             → gen-div  → cycle position, membership, reversal
             → is_true  → harmonic truth assertion
```

Any decoding error produces a non-harmonic result detectable without a
separate error channel. The entropy stream IS the test oracle.

### Encoding Layers in div-13 Streams

Division-by-13 output naturally exercises all decoder levels:

```
binary layer    [ level 1 ]  →  bit shifts in entropy expansion
octal layer     [ level 3 ]  →  3-bit boundaries in cycle digits
decimal layer   [ level 4 ]  →  the 076923 decimal cycle itself
base32 layer    [ level 5 ]  →  AMOS7-encoded cycle values
byte layer      [ level 8 ]  →  raw entropy bytes between cycle positions
```

One stream from zulum exercises all five decoder levels simultaneously,
making it a complete integration test with known-correct expected output.

## Initialization Sequence

### Phase 1 : zulum module

Implement `src/zulum` — initialize 13 streams from cycle positions,
expose `stream-attach` to connect a consumer (decoder or any zenka),
`stream-add` / `stream-remove` for dynamic consumer management.

Port the inner loop from `bin/dev/division-13-table` into the zenka:

```perl
## from division-13-table, adapted for stream emission ##
$Z <<= 4;
$Z /= 13;
$Z <<= is_true($Z) ? 2 : 1;
## emit $Z to attached consumers ##
```

### Phase 2 : cube-13 jump routing

Implement jump table in `src/cube-13` — accept jump commands, switch
active stream, notify attached decoder of stream change with a boundary
marker so the decoder can close the previous level buffers cleanly.

### Phase 3 : decoder integration

Wire `stream-attach` from decoder to cube-13. The decoder's level buffers
fill from zulum output via cube-13. `show-buffer` displays live stream state.
`buffer-erase-level` clears on clean harmonic boundaries (TRUE values, cycle
position changes, generator appearances in digit reversals).

### Phase 4 : Operator commands

Expose the navigation operators as decoder-side commands:

```
decoder.jump true     ##  cube-13 switches to stream 5 [TRUE]  ##
decoder.jump reverse  ##  cube-13 applies /0.7 reversal         ##
decoder.show-buffer   ##  current level buffer state             ##
decoder.verify        ##  run is_true on current buffer content  ##
```

## From Research to Utility

`bin/dev/division-13-table`  →  single-stream reference, stays as dev tool
`bin/dev/gen-div`            →  operator map reference, stays as dev tool
`zulum`                      →  live multi-stream producer, always available
`cube-13`                    →  live routing matrix, always available
`decoder`                    →  live stream decoder, testable at any time

The research scripts become the specification against which the zenka output
is verified. The zenki become the production infrastructure that makes the
entropy streams available as a network utility — addressable by any zenka,
routable via @INDEXCUBE cube coordinates, decodable at any encoding level.

## Connection to @INDEXCUBE

Each zulum stream has a cube coordinate derived from its cycle position:

```perl
## stream N → ADDR_B32 = amos7_chksum( gen × N ) ##
## TYPE = 'STREAM', tint = stream number          ##
$stream_p7ref = "STREAM:$chksum:$addr_b32";
push @INDEXCUBE, $stream_p7ref;    ## decoder marks current stream in stack ##
```

Switching streams = pushing a new P7REF onto the decoder's @INDEXCUBE.
The route log records every stream jump — the traversal proof IS the
sequence of cycle positions visited.

#,,.,,,..,,,.,,,.,,,.,,..,,,.,,,,.,.,,,,.,,,.,,..,,.,,,.,..,.,,,,.,..,,...,..

#,,.,,...,,..,.,,,.,,,,,.,,..,..,,,.,,,..,,,,,..,,...,.,.,..,,..,,.,.,..,,.,,,
#M4EBNDVGGXOUJVW43MOUC2VEX5P5UNFVMRJALXISHTGNNWQ633RBSI44NKQSCADZBBYONR37U2J3G
#\\\|VODB5VBQAJF7CZOOMU3PVVMNUDQIFBNLCSPUWSGTBKMOX5MJPLN \ / AMOS7 \ YOURUM ::
#\[7]OVBBA2BGQFQYXJTFIFJWMZQTM2TRZK2PRHP4OF3I4Y3BUWMMAYCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
