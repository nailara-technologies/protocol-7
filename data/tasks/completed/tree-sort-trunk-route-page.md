# task: tree.sort.trunk.* + tree.route.page.* — trunk sort and routing page

## relation to CONSOLE-FOLD-TREE-PHILOSOPHY

the trunk sort and routing page define how namespace entries propagate
through the tree protocol — the **wire-level mechanism** beneath the
console layer's address-resolves-to-handle guarantee that
`data/md/design/CONSOLE-FOLD-TREE-PHILOSOPHY.md` rests on. without
this layer, "fold confidently because the network underwrites
presence" lacks its concrete substrate.

## context

two tightly coupled systems that together define how bits and namespace
entries propagate through the tree protocol:

**trunk sort** — the 5×7 outer parent map. sorts namespace entries by
wave cancellation: symmetric pairs cancel, asymmetric remainder survives
as the trunk. applies itself recursively to the expansion front.

**routing page** — bit propagation through routing pages. direction is
state-dependent: bits awaiting rollover move right (circulate locally),
bits carrying move left (toward root/network). representative extraction
(harmonic truth test) selects which bits carry. vacated slots create
suction that pulls new bits upward.

design reference: `data/md/design/BRANCH-OPEN-CAPACITY-SESSION-DAG.md`
  (sections: "5×7 trunk sort" and "routing page propagation")
design reference: `data/md/design/TREE-PROTOCOL.md`

reference implementations:
- `bin/amos-data-pager`     — 72-bit raw binary pager (9 bytes/line)
- `bin/amos-data-pager-56`  — 56-bit routing word pager (7 bytes/line)
  specifically: `bin_to_comp_int_2` — the 7→8-bit leading-bit encoding
  and `true_int` — the harmonic truth (representative extraction) test

## signatures note

do not modify or regenerate AMOS7 signature lines. leave them untouched.

## the 7-bit routing word — typed protocol

every 7-bit word carries a type prefix that determines its interpretation.
this is the native protocol-7 wire format, implemented in `decoded_bits`
in `bin/dev/division-13-table`:

```
prefix  type        encoding
'00'    routing     00 [XX:direction] [YYY:hop-count]
                      direction: 00=UP  10=LEFT  01=RIGHT  11=DOWN
                      hop count: 1 + 3-bit value
'010'   BASE32      010 + 5 bits → RFC4648 BASE32 char (UTF-7 payload)
'011'   document    0110=monochrome header  0111=color header
'1'     graphical   1 + 6 bits → 5×7 matrix position <col:0-4><row:oct>
```

LEFT (10) = toward root/network. RIGHT (01) = toward leaf.
direction is encoded in the routing word type — not a property of the
bit's content but of its travel direction at this routing hop.

## the 56-bit routing word — segment encoding

7 bytes = 56 bits interpreted as 8 groups of 7 bits:

```perl
## from bin/amos-data-pager-56 bin_to_comp_int_2:
for my $i ( 0 .. $input_len ) {           ## input_len = 7
    if ( $i < 7 ) {
        $result .= pack 'B8', '1' . substr( $bits_56, $i * 7, 7 );  ## awaiting
    } else {
        $result .= pack 'B8', '0' . substr( $bits_56, $i * 7, 7 );  ## carry
    }
}
```

leading '1' = awaiting rollover = circulates rightward within segment
leading '0' = carry out = propagates leftward toward root/network

note: the leading bit is a SEGMENT PHASE flag, distinct from the type
prefix of the 7-bit word itself. a routing word (type '00') with leading
'1' is still a routing word — it is just waiting for its segment rollover.

## the 64-bit entropy structure (division-13-table)

the entropy generator in `bin/dev/division-13-table` produces 64-bit
integers with a fixed routing structure:

```
bits [ 0..41]  main entropy    42 = 6×7 (both generator periods combined)
bits [42..48]  routing word    7 bits — the current typed routing word
bits [49..63]  auxiliary 15    precision buffer, not entropy
```

the routing word at bits 42-48 emerges naturally from the 1/13 harmonic
iteration. the truth test gates on both the full 64-bit value and the
42-bit main entropy body simultaneously.

## the 5×7 outer parent map

```
5 columns  = five layers (task/template/design/intent/address)
7 rows     = seven generator-family instances
35 elements = active matrix (5×7)
+ 5 gate   = one gate row per column (row 7, the carry/terminal row)
= 40 total = 5×8 addressing space  [ 8*5=40, 5*7=35+5 ]

aspect 5:7 = 0.714285... = rotation of 142857 (1/7 family, self-describing)
gravity core = reference-count centroid of the 35-element grid
```

the graphical type '1' routing word addresses this matrix directly:
`1 [col:0-4] [row:0-7 octal]` → 40 positions. control codes 48-63
occupy the upper positions (background/foreground/alpha/RGB channels).
the matrix IS the graphical character format for protocol-7.

the source.init_code propagation diagram encodes this at every digit depth.
`\` and `/` = carry bits in transit. `.` = circulating. `,` = segment
boundary. `|` = page boundary. read bottom-to-top for increasing depth.
at [14D]: `[7+1+8]` = 7 routing groups + 1 gate + 8 = routing word anatomy.
at [32D]: `[10=5+5]` = the two five-layer halves of the cluster structure.

trunk sort: collapse the 7-axis by canceling symmetric pairs.
result: 5 trunk elements, frequency halved.

## modules to create

### tree.sort.trunk.*

- `src/tree.sort.trunk.project` — given a list of namespace entries
  with reference weights, project onto the 5×7 map. assign each entry a
  (column, row) coordinate based on its layer type (column 1-5) and its
  position within the generator family (row 1-7). entries without a clear
  row position are placed by reference-weight proximity to the gravity core.

- `src/tree.sort.trunk.cancel_symmetric` — identify symmetric pairs
  along the 7-axis (entries at rows R and 8-R with matching layer column).
  cancel pairs: remove both, record their net contribution (difference in
  reference weight) as a residual. return list of unpaired entries + residuals.

- `src/tree.sort.trunk.remainder` — return the asymmetric survivors:
  unpaired entries + residuals from cancel_symmetric. these are the trunk
  elements — one per column, the highest-weight non-cancelled entry.

- `src/tree.sort.trunk.halve_frequency` — for each column, collapse
  the 7 row values to a single representative by summing and halving.
  this reduces one oscillation period to its net scalar value. return
  5-element array (one per layer column).

- `src/tree.sort.trunk.field_self` — apply the full sort (project →
  cancel → remainder → halve) to the expansion front of sub-branches.
  the trunk from the current level becomes the column axis of the next
  level. recurse until no further cancellation occurs or depth limit
  reached. return the fully reduced trunk hierarchy.

### tree.route.page.*

- `src/tree.route.page.word_type` — decode 7-bit word type prefix:
  return 'routing' | 'base32' | 'document' | 'graphical'. extract the
  remaining payload bits after the prefix. reference: `decoded_bits` in
  `bin/dev/division-13-table`.

- `src/tree.route.page.word_route` — decode routing word (type '00'):
  extract direction (UP/LEFT/RIGHT/DOWN from 2-bit field) and hop count
  (1 + 3-bit value). return hashref `{ dir => 'LEFT', hops => N }`.

- `src/tree.route.page.word_graphical` — decode graphical word (type '1'):
  extract column (0-4) and row (octal 0-7). return hashref
  `{ col => N, row => N, pos => N }` where pos = col*8 + row.
  positions 48-63 are control codes (color/alpha).

- `src/tree.route.page.encode_56` — encode 7 bytes as a 56-bit
  routing word: split into 8 groups of 7 bits, prepend '1' to groups
  0..6, prepend '0' to group 7. return 8 bytes.
  (reference: `bin_to_comp_int_2` in `bin/amos-data-pager-56`)

- `src/tree.route.page.decode_56` — decode 8-byte routing word:
  strip leading bits, return 8 groups of 7 bits + array of leading bits
  (direction flags).

- `src/tree.route.page.bit_direction` — given a decoded routing word
  and group index, return 'left' (carry, leading 0) or 'right' (awaiting,
  leading 1).

- `src/tree.route.page.read` — read N lines × W bytes from routing
  table at offset. return arrayref of routing words. wraps seek + sysread
  pattern from amos-data-pager.

- `src/tree.route.page.rollover` — given a segment at boundary:
  check harmonic truth of the terminal group (group 7).
  if true: carry over (return carry=1, segment resets to right end of next).
  if false: fall back (return carry=0, segment resets to right end of same).

- `src/tree.route.page.extract` — apply harmonic truth test
  (`AMOS7::Assert::Truth` / `true_int`) to a routing word. if true:
  mark as extracted, return representative value (the 7-bit payload of
  group 7). record extracted slot position for suction.

- `src/tree.route.page.suction` — given a list of vacated slot
  positions in a routing page, pull bits upward from the page below:
  read the corresponding positions from the lower page, move them up,
  clear the lower slots. return count of bits moved.

- `src/tree.route.page.attach` — given a passing segment (array of
  routing words in motion) and a waiting bit (new bit to insert), find
  the first available slot in the passing segment (leading '1' group with
  zero payload). insert the bit. return updated segment.

- `src/tree.route.page.navigate` — cursor operations over a routing
  table: line_up / line_down (±1 line = ±W bytes), page_up / page_down
  (±N lines = ±N×W bytes). clamp to [0, file_size - page_bytes].
  (reference: navigation subs in both amos-data-pager scripts)

## page geometry constants

```perl
## standard routing page (56-bit format):
use constant PAGE_LINE_BYTES => 7;    ## 7 bytes = 56 bits per routing word
use constant PAGE_LINES      => 20;   ## 20 lines per page
use constant PAGE_BYTES      => 140;  ## 20 × 7

## wide routing page (72-bit format, 13-BCD aligned):
use constant PAGE_LINE_BYTES_72 => 9;    ## 9 bytes = 72 bits, 52/4=13 BCD groups
use constant PAGE_BYTES_72      => 180;  ## 20 × 9

## group structure:
use constant WORD_GROUPS   => 8;    ## 8 groups of 7 bits
use constant GROUP_BITS    => 7;    ## 7 payload bits per group
use constant CARRY_GROUP   => 7;    ## index of terminal/carry group (leading 0)
```

## style

- `$ARG` not `$_`; `@ARG` not `@_`
- use `AMOS7::Assert::Truth` for `true_int` test (harmonic truth)
- use `AMOS7::13::key_32` patterns for bit manipulation helpers
- sysread/syswrite for page I/O (not IO::File readline)
- lowercase comments, `[ word ]` bracket annotations

## acceptance

- encode_56(decode_56($word)) is identity for any 7-byte input
- bit_direction returns 'left' for group 7, 'right' for groups 0..6
- rollover returns carry=1 exactly when true_int passes on terminal group
- cancel_symmetric removes symmetric pairs leaving only asymmetric entries
- field_self applied to a fully symmetric 7-row map returns empty trunk
- navigate clamps correctly at both ends of file
- suction moves exactly the bits vacated by extract, no more

#,,..,,,,,..,,,.,,.,,,.,.,,,.,,..,,.,,.,.,,..,..,,...,...,..,,.,,,,..,,,,,,,,,
#7SA7WFFZKS6BC5QEUQZQQOV6HBYCAJXD3J5WBR2LV2VQME3YOYJGUPANIU3ZS3AN3WSJGVUGRGA3E
#\\\|HIKWYO2HZFZADQGNPVU574CPFVP7TF4O67KESCMUZM32LSQXTIJ \ / AMOS7 \ YOURUM ::
#\[7]AYUE75NIU2U6VXIOOT5YDGY4VCODLOPL6R7FCJJGK5F22DUWGKBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
