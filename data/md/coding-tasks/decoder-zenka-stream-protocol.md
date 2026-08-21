
 .:[  decoder zenka : multi-encoding terminal stream protocol  ]:.

## Existing Infrastructure

`cfg/zenki/decoder/zenka.v7` already defines:

```
modules.load  = auth net protocol io.unix decoder.zenka
commands      = stream-add stream-remove stream-attach
              = show-buffer buffer-erase buffer-erase-level
              = list list-deps save-state load-state ...
```

The command set was pre-specified for exactly this protocol.
`decoder.zenka` module is the stub to implement.

## Stream Protocol Design

### Bit-Width Level Table

Each encoding layer operates at a fixed bit-width boundary:

```
level 1  →  binary    [ 1-bit  ]  delimiter flips at each bit
level 3  →  octal     [ 3-bit  ]  existing octal header system
level 4  →  BCD/hex   [ 4-bit  ]  signed BCD, source.init_code 04D
level 5  →  base32    [ 5-bit  ]  full entropy width — no invalid patterns
level 8  →  byte      [ 8-bit  ]  raw byte boundary
```

Base32 uses the full 5-bit entropy width: every possible 5-bit pattern maps
to a valid symbol. "Not decodable" does not exist at the character level —
the full entropy width IS the escape mechanism.

### Zero-Prefix Stream Disambiguation

First character determines routing with zero lookahead:

```
∈ [2-9A-Z]  →  level 5 (base32 buffer)   [ no leading zero possible ]
= 0         →  count prefix zeros:
  1 zero    →  level decimal  [ 0 + {1..3 decimal digits}  ]
  2 zeros   →  level binary   [ 00 + {8 binary digits}     ]
  3 zeros   →  level octal    [ 000 + {3 octal digits}     ]
```

Existing base32 charset `[2-9A-Z]` is zero-free by design — base32 streams
are always unambiguous from zero-prefixed numeric forms without any extra rule.

### Fixed Field Widths (unambiguous at stream boundaries)

```
decimal  :  0   + 3 digits  =  4 chars  [ 0..999, one cube axis range ]
binary   :  00  + 8 digits  =  10 chars [ 00000000..11111111, one byte ]
octal    :  000 + 3 digits  =  6 chars  [ 000..377, one byte in octal  ]
base32   :  no prefix, variable length  [ full entropy, no padding     ]
```

Fixed width makes total string length unambiguous — stream reader counts
prefix zeros, reads exactly the expected field width, closes the packet.

### Flipping Delimiter Principle

At each bit-width boundary, the delimiter flips state rather than being
inserted as a separate token. Inherited from the existing octal header
system (3-bit payload, flip at zero-payload case):

```
octal header:   1 | 000   →  delimiter = leading 1, payload = 000
binary header:  same principle at 1-bit boundary
decimal:        same at 4-char boundary
base32:         delimiter fires at 5-bit boundary close
```

No large buffer needed — each level only asserts its own payload window.
The zipper inserts markers at boundary transitions as they occur in the
stream, not after buffering the whole segment.

## Command Semantics

### stream-attach

Connect a source stream (unix socket, pipe, channel) to the decoder.
The decoder begins routing incoming characters to level buffers:

```
stream-attach <source-id> [level-filter]
  ## level-filter: only route specified levels, default all ##
```

### stream-add / stream-remove

Add or remove a secondary stream source to an existing decode session.
Multiple sources can feed the same level buffers (fan-in routing).

### show-buffer

Display current state of all active level buffers simultaneously:

```
show-buffer           ##  all levels  ##
show-buffer <level>   ##  specific level  ##
```

Output format: one line per active level, current accumulated value,
boundary status (open/closed), packet count since last erase.

### buffer-erase-level

Flush one encoding layer's accumulator at its packet boundary:

```
buffer-erase-level 5   ##  flush base32 buffer  ##
buffer-erase-level 3   ##  flush octal buffer   ##
```

Erase is boundary-aware — only flushes at a clean packet close, or forces
flush if `--force` is passed (for error recovery).

### buffer-erase

Flush all level buffers simultaneously. Used on stream detach or reset.

## Separation and Rerouting

Base32 segments and numeric segments can be processed independently:

```
stream-attach <src>
  → base32 chars     → level-5 buffer → paired with routing coordinate
  → numeric prefix   → level-N buffer → routed to numeric decoder branch
```

If base32 and numeric carry the same routing coordinate (via @INDEXCUBE
stack), they are paired on output. If unrelated, split into separate
packets. The packet markers inserted by the zipper carry the coordinate
for pairing — no separate registry needed.

## Connection to Existing Infrastructure

- **Octal header system**: level-3 encoding is already implemented; the
  decoder zenka extends the same flip-delimiter logic to all levels
- **@INDEXCUBE**: cube coordinate in each packet header routes the decoded
  output to the correct downstream zenka or buffer layer
- **base.parser.decode_harmonized_refstr**: P7REF strings arriving in a
  base32 stream are decoded here and routed by TYPE field
- **source.init_code dimensional table**: levels 1-32 are pre-mapped;
  the decoder operates on the subset that are "clean" (not marked
  `[not clean]` in the table: avoid 14D and 15D as primary levels)
- **%colors / tint registry**: TYPE field from decoded P7REFs looked up
  in %colors to determine which service buffer receives the payload

## Implementation

### decoder.zenka module

```perl
## [:< ##
# name  = decoder.zenka
# descr = multi-encoding terminal stream protocol handler

## stream state per attached source ##
## $data{'decoder'}{'streams'}{$id} = {
##     'buffers'  => { 3 => '', 5 => '', 8 => '' },  ## per-level accumulators
##     'boundary' => { 3 => 0,  5 => 0,  8 => 0  },  ## open/closed state
##     'packets'  => { 3 => 0,  5 => 0,  8 => 0  },  ## packet counts
##     'source'   => $fh,
## }
```

### Phase 1 : Level-5 base32 stream handler
Accept a base32 stream, accumulate in level-5 buffer, fire on 5-bit
boundaries. `show-buffer 5`, `buffer-erase-level 5`. No numeric routing yet.

### Phase 2 : Zero-prefix numeric routing
Add first-character routing: count prefix zeros, dispatch to level 3/4/8
buffer. All levels active simultaneously.

### Phase 3 : Zipper delimiter insertion
Insert boundary markers at level transitions. `stream-attach` wires sources.
Pairing logic for base32 + numeric segments sharing a cube coordinate.

### Phase 4 : @INDEXCUBE integration
Each decoded packet tagged with current `@INDEXCUBE[-1]` coordinate.
Routing decisions use cube neighborhood queries for nearest downstream buffer.

#,,.,,,..,,,.,,,.,,,.,,..,,,.,,,,.,.,,,,.,,,.,,..,,.,,,.,..,.,,,,.,..,,...,..

#,,..,..,,.,,,,.,,..,,.,.,,..,,..,..,,,,.,,.,,..,,...,..,,,..,,,,,.,,,..,,.,.,
#2LEU2YDYFSQRM3SABHCMUXE727DCA6VGPE6DR4LGQDYZ45MZPJMHDR6MNSFONXCW7WSLC4AN2NQZ6
#\\\|67QQAW5OK4FK3BWKBVH62HNTVUGP4LMED3FMCL4HK672UVV6W7F \ / AMOS7 \ YOURUM ::
#\[7]K5H4NQU3FXQKUDBNXDS2SGX6VJHKTUAYUHIS4LK57FEBDCT4TUCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
