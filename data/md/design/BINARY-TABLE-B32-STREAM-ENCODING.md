# binary table mapping on B32 page streams

## concept

encode a secondary binary data stream within a base32 text stream by treating
the characters `I` and `O` as a canvas for bit values `1` and `0`.

the base32 alphabet naturally produces `I` and `O` characters at predictable
rates. the encoder observes the outgoing B32 stream, and when an `I` or `O`
appears, it replaces it with the bit value needed for the current position
in the binary table being transferred.

the result: the B32 stream remains valid base32 text, but carries an embedded
binary payload recoverable by correlating replacement positions.

## encoding rules

### character-to-bit canvas

```
  B32 stream character    canvas for bit
  ─────────────────────────────────────
  I                       1
  O                       0
```

when the encoder needs to send a `1`, it waits for the next `I` in the B32
stream and replaces it with `1`. when it needs a `0`, it waits for `O` and
replaces with `0`. the receiver knows the original B32 content [ or can
reconstruct it from context ] and reads back the binary table from the
replacement positions.

### bit-row structure

binary data is organized into **bit-rows** — fixed-width rows matching the
B32 stream column width [ typically 76 characters, matching the signature
footer line width ].

```
  B32 line:   VSIDPSO7DUTWCQEKDPMH36ABL4OB5HYMF5NKJJJVCN6UFRGTM255M25OTMDNSKPG7M3WNV
  bit-row:    ........................................0.............................1..
                                                     ^                             ^
                                              O replaced with 0              I replaced with 1
```

each bit-row maps to one row of the binary table. a bit-row is **complete**
when all columns requiring a bit have been filled by matching `I`/`O`
occurrences.

### completion and correlation

- a bit-row can only be read [ cleared ] when **all** its columns are complete
- the receiver tracks which columns have been filled per row
- column positions correlate 1:1 with the B32 stream character positions
- once a row is fully populated, it yields one row of binary data

### asymmetric column stacking

when too many binary columns stack up asymmetrically [ many `1`s needed but
few `I` characters appearing, or vice versa ], the encoder inserts **padding
rows**:

```
  padding row of 0s:   000000000000000000000000000000000000000000000000000000000000000000000000000000
  padding row of 1s:   111111111111111111111111111111111111111111111111111111111111111111111111111111
```

a padding row of `0`s provides `O` canvas positions for all pending `0` bits.
a padding row of `1`s provides `I` canvas positions for all pending `1` bits.

the number of padding rows scales with the deficit — as many `000...0` rows
as needed to drain the `0`-bit backlog, then resume the B32 stream.

### row completion boundary rule

**a padding row of all-zeros can only complete the current bit-row, never
mix with the next one starting.**

this boundary rule means:
- no vertical bitstream protocol is needed
- the receiver knows exactly where one bit-row ends and the next begins
- partial completion state is always unambiguous

### octal encoding variant

instead of raw `0`/`1` replacement, bit-rows can use **octal encoding**
[ or a similar scheme ] where:

- the **majority case flips to `1`** instead of `0` when a `0` is to be set
- implicitly all `0` except the set bits
- eliminates the `11111101111` inversion case entirely

this mirrors the existing AMOS octal encoding conventions where the common
case is encoded as absence [ all zeros ] and only exceptions are marked.

```
  raw bit-row:     00000000000010000000000000000000100000000000000000000001000000000000000000000000
  octal variant:   ...........[1]...................[1]........................[1]....................
                   implicit 0s except marked positions
```

## integration with P7 infrastructure

### signature footer as canvas

the 76-character-wide AMOS signature footer lines are natural B32 streams:

```
  #,,..,..,,.,,,,,,,,..,,,.,,,.,,,,,..,,..,,,,.,..,,...,..,,...,...,.,.,.,,,..,,
  #VSIDPSO7DUTWCQEKDPMH36ABL4OB5HYMF5NKJJJVCN6UFRGTM255M25OTMDNSKPG7M3WNVILE3IUA
  #\\\|T2Y7JBAY3WIRGDTQJNRFUCMKSQXCM7HTMKD22IXXCUEIBHUR4BS \ / AMOS7 \ YOURUM ::
  #\[7]LEIBVJAJ5TXB56WDBEX7D3ZLHH5LOIM6UCT3BLYT4UNCQ2C5YKCI 7  DATA SIGNATURE ::
```

the hash line [ line 2 ] contains dense B32 — ideal canvas for binary table
embedding.

### pager integration

the pager system can render binary tables as virtual pages:
- `pager.source.checksum-list` already handles B32 formatted data
- binary table extraction becomes a pager filter
- SHM-backed mmap files can hold decoded binary tables

### data stream applications

- **inline metadata**: embed structured binary data within B32 checksums
- **steganographic channel**: carry secondary payloads within B32 streams
- **compression hints**: encode entropy statistics alongside checksum data
- **parity / error correction**: embed ECC bits within the B32 carrier stream

## advantages over serial bitstream

### out-of-order bit reception

a serial bitstream requires strictly ordered delivery. the column-based table
does not — each bit position is addressed by [ row, column ] and can arrive
in any order. this enables:

- **distributed tree acquisition**: bits arrive from multiple network sources
  in parallel, each filling different columns of the same bit-row
- **implicit channel infrastructure**: each column is effectively an independent
  channel that can be fed by a different source or path
- **partial progress**: a bit-row with 70 of 76 columns filled is immediately
  useful for speculative decoding; the remaining 6 can trickle in

```
  source A fills columns 0-25  ──┐
  source B fills columns 26-50 ──┼──▶ bit-row completes when all 76 arrive
  source C fills columns 51-75 ──┘    [ order within each source irrelevant ]
```

### multi-line tree addressing

the effective channel width is **not limited** to the 76-character column
wrapping width. when bit positions are addressed via multi-line binary tree
paths, a single logical bit-row can span across multiple B32 lines:

```
  tree depth 1:  76 columns   [ single line ]
  tree depth 2:  76 x 76      [ line + column within line ]
  tree depth N:  76^N          [ N-level hierarchical addressing ]
```

this turns the column-based table into a **hierarchical bit-space** where:

- tree nodes address sub-tables within sub-tables
- each level of the tree multiplies the addressable channel width
- routing through the tree determines which physical B32 line carries which
  logical bit position
- naturally maps to P7 checksum-addressed branch structures [ L13 → B32 ntime → content ]

the combination of out-of-order reception and tree-addressed width means
this encoding scales from inline metadata [ single 76-char row ] to
distributed acquisition of arbitrarily wide binary structures across
a network of P7 nodes.

## properties

- **self-synchronizing**: row boundaries are unambiguous via completion rule
- **no framing overhead**: uses existing B32 characters as canvas
- **graceful degradation**: padding rows maintain throughput under asymmetry
- **format-preserving**: output remains valid B32 text
- **width-aligned**: 76-char rows match existing P7 signature conventions
- **order-independent**: column addressing allows out-of-order bit arrival
- **width-unbounded**: multi-line tree addressing exceeds single-line limits
- **distributed-native**: parallel acquisition from multiple network sources

#,,,.,..,,,,.,.,,,..,,,.,,..,,.,,,...,,,,,.,.,..,,...,...,,..,.,.,,.,,..,,..,,
#T35JUQCOJNMKFHNYRNGWF3N3IMKENTK6DGG6PPJVWLPWQ6DTCRRVRZWE4SUSK7NLY4ZY4NPB6AO64
#\\\|BHHRNAVNQXFGNYS7IOGGD2M2GD7J3O76TP35PWX6HZVQ7J2MJQO \ / AMOS7 \ YOURUM ::
#\[7]L2GDRPDWFWY7IOPMX3FRE2GJQTJYRGPK7UJ7PTITD7PFQJSSXSCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
