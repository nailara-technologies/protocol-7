## [:< ##

# checksum route binary framing — self-delimiting address format
# descr = B32R routes with binary [0,1] separators and 4-bit type prefix

---

## insight

B32R alphabet is `2-9A-Z` — characters `0` and `1` are NOT in the set.
this makes them available as structural delimiters within addresses,
creating self-parsing variable-length routes with zero ambiguity.

---

## format

```
[4-bit type][1-sep][checksum-B32R][0-sep][addr-B32R]
  binary      |     payload         |    payload
```

### type prefix [ 4-bit binary, 16 slots ]

```
0000  model endpoint
0001  task node
0010  consensus group
0011  dependency edge
0100  cache entry
0101  shared context
0110  review page
0111  pipeline stage
1000  remote node
1001  zenka instance
1010  channel
1011  file reference
1100-1111  reserved
```

### delimiter semantics

- `1` — structural separator [ type boundary, hierarchy level ]
- `0` — field separator [ within same hierarchy level ]

### examples

```
0000 1 AKXEYFQ 0 3TN7V2    model AKXEYFQ at address 3TN7V2
0010 1 BCTT2HQ 0 AKXEYFQ 0 JT4HGQA   consensus group with 3 members
0001 1 LBULHXQ               task node [ no address needed ]
1000 1 ZYKKBV3 0 9RJLT4X    remote node ZYKKBV3 at hop 9RJLT4X
```

---

## properties

- **self-delimiting**: type bits are visually and programmatically distinct from payload
- **variable length**: no fixed field widths — delimiters mark boundaries
- **hierarchical**: `1` separates levels, `0` separates siblings
- **parseable in one pass**: scan left to right, switch on character class
- **token efficient**: minimal overhead — 4 bits + 2 delimiter chars
- **composable**: routes can nest — a group address contains member addresses

---

## parsing [ pseudocode ]

```perl
## split on first '1' — type prefix vs rest ##
my ($type_bits, $rest) = $route =~ m{^([01]{4})1(.+)$};

## split rest on '0' for fields ##
my @fields = split m{0}, $rest;

## first field is always primary checksum ##
my $primary = shift @fields;

## remaining fields are context-dependent on type ##
```

---

## integration with P7REF

current format: `TYPE:CHKSUM7:ADDR_B32`
proposed evolution: binary-framed route replaces the colon-delimited format

the colon format remains as human-readable display form.
binary-framed format is the wire/routing format — more compact,
self-parsing, and directly usable as hash keys and routing table entries.

---

## open questions

- should the 4-bit type be expandable? [ e.g., `1111` as escape to 8-bit extended type ]
- should hop count be encoded in the address or remain a routing-table property?
- can this format encode the "defined hop sizes" concept directly?

#,,,,,..,,,.,,.,,,.,.,...,.,,,,,,,..,,,.,,,.,,..,,...,...,.,,,.,.,...,,,.,.,,,
#QNRIQILFHRRAWOSJBMOHW3C432Z6LM56YGG7AQ37PD5TMST5DFRDEAVRYIPMAAFYMUMZ733OC7LZY
#\\\|DTTVLXMR6POAUDOBHAHKK4KNVT2LZP4BBZADQ6TOPWTEUQNGGIO \ / AMOS7 \ YOURUM ::
#\[7]4M5DZA7KETV3L4YH4YSB3SL2Y6MAQKMC4Y3NVG6UNFCYF6FKNQDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
