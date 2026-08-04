## [:< ##

# name  = task: footer line 4 — reconciling litter-row-encoding vs harmonic-transit L-matrix
# descr = two independent design docs both claim the same 15-bit :::: footer field —
#         this reconciles them into one coherent layout instead of picking a winner

## context

two design documents, written separately, both describe "the 15-bit footer
field" living in the AMOS7 signature footer's fourth [ bottom, colon ] line —
and neither references the other:

```
data/tasks/litter-row-encoding.md
  → "15-bit bitmap — 7+1+7 neighborhood encoding"
  → zenka involvement flags + routing-trunk flags
  → 3 base32r chars, LEFT-aligned, right after the opening #:

data/md/documentation/harmonic-transit-vision-architecture.md
  section 2  "the 15-bit spatial coordinate"
  section 10 "cube boundary as self-contained packet geometry"
  → 13-bit L-matrix [ 5+7+1 ] + 2-bit orientation selector
  → interlaced dot/colon octal encoding, RIGHT-aligned, full 77-char width
```

a human reviewer [ session 2026-08-04 ] flagged the conflict and proposed a
concrete meaning for litter-row's previously-undefined bit 7: "transport
state [local|routing]". this doc works out whether the two schemes can
coexist, where the reviewer's bit-7 proposal lands, and what to fix in each
source doc so they stop contradicting each other.

## finding 1 — this is the same physical line, not two different fields

both docs describe a 77-character line, `#` followed by colons, at the
bottom of the standard 4-line AMOS7 footer [ checksum / signature /
version / litter ]. real footers on disk confirm the line is exactly this:

```
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
```

[ see modules/base.init_code footer, or any signed module — the 4-line
shape matches litter-row-encoding.md's diagram exactly. ]

harmonic-transit-vision-architecture.md calls it "footer line 5" in its
overview [ line 22 ] and "the fifth (bottom) line" in section 2 [ line 166 ].
this is a plain counting error in that doc — no real footer has a 5th line,
and the doc's own verbatim quote of the target line [ `#:::::` ] matches
litter-row's line 4 exactly. not evidence of a separate field, just a
label to fix.

conclusion: one physical field, two incompatible encodings proposed for
it. this is a real conflict, not a false one — proceed to reconcile.

## finding 2 — the two schemes don't collide in character position

laying out where each proposal actually writes characters on the 77-char
line resolves most of the conflict without anyone losing anything:

```
position:  1     2      3-5        6            7-46           47-77
content:   #     :      [litter]   :            : : : : ...    [harmonic payload]
           ^     ^      3 base32   ^            41 colons      31 chars, right-
           |     |      chars      |            [ unclaimed ]  aligned interlaced
           |     |                 |                            dot/colon encoding
         start  litter zone open  litter zone close
```

litter-row-encoding.md's format is `#:[CHARS]:::...` — 3 base32r chars
occupy positions 3-5, everything past that is "remaining colons maintain
visual consistency" [ litter-row-encoding.md, line 31 ] — explicitly
described as unclaimed decoration, not reserved payload.

harmonic-transit's format is right-aligned: 45 leading colons + a 31-char
interlaced payload = 77 total [ section 2, "footer encoding" ]. its
payload lives in positions 47-77. and — this is the load-bearing detail —
the doc says so itself:

> "the left side of the `#:::::` line is available for future prefix
> fields." [ harmonic-transit-vision-architecture.md, section 2, line 194 ]

litter-row's 5-character zone [ positions 2-6 ] sits entirely inside that
self-declared "available" left region. the two encodings do not overwrite
each other. they were independently sized to leave room for the other
without either author knowing about it.

alphabets don't collide: litter's base32r payload comes from
`Crypt::Misc::encode_b32r` [ see `modules/base.base32.encode` ] — RFC4648
base32, alphabet `A-Z2-7`, no `.` and no `:` in it. harmonic uses only
`.` and `:`. so the litter zone can never produce the `..` sequence
harmonic's validator treats as structurally invalid, and harmonic's
`:`-only payload can never be mistaken for a base32 letter.

that said, position alone is not enough — see the validation-hierarchy
gap below. the alphabets not colliding is necessary but not sufficient
for the two zones to actually coexist under harmonic's own validator as
currently specified.

### the validation hierarchy needs to be scoped, not just the payload

section 2 defines five validation levels for the `#:::::` line [ lines
181-189 ], and levels 1-3 read as whole-line structural checks, not
checks scoped to positions 47-77:

```
level 1  :  no .. anywhere                  structural, no decode needed
level 2  :  (length - 2) mod 6 == 0         group alignment
level 3  :  positions 2,4,6 mod 6 = :       separator positions
```

level 1 is safe regardless of scope [ base32r never contains `.`, shown
above ]. levels 2-3 are the risk: if a real implementation walks the
line from position 1 and expects the mod-6 separator pattern to hold
everywhere, a base32r letter sitting at position 4 [ inside the litter
zone ] would read as a violation of "position 4 mod 6 = `:`" and reject
every line carrying a litter payload — even though the harmonic payload
itself, at positions 47-77, is untouched.

this is not disqualifying, but it means the two zones don't coexist for
free — the composition needs one explicit rule added to section 2: **the
structural scan for levels 1-3 starts at position 7, not position 1**.
positions 2-6 [ the litter zone, `:` + 3 chars + `:` ] are exempt from
harmonic's own group-alignment and separator checks; a litter-aware
validator checks the litter zone with its own rules [ base32r decode of
positions 3-5 ] and hands the rest of the line to harmonic's levels 1-5
starting at position 7. this is a required part of the composition, not
an optional footnote — it's listed in "what to do" below.

## finding 3 — the two fields are semantically different kinds of data, which is why composition makes sense and isn't just a lucky fit

this isn't only a character-position coincidence — the two 15-bit values
describe genuinely different things, which is exactly the kind of split
that belongs in two independent sub-fields of one line rather than one
merged 15-bit space:

```
litter [ positions 3-5 ]:
  static routing manifest — computed once from the module's own
  namespace [ base., httpd., coding., ... ] at sign time. changes only
  when the module's zenka usage changes. answers "who touches this
  module, structurally."

harmonic [ positions 47-77 ]:
  dynamic spatial/harmonic state — derived from the 64-bit division-13
  assertion state at the moment of signing [ bits 49-63, the auxiliary
  field ]. changes on every re-sign. answers "where was this packet in
  mod-15 / L-matrix space when it was last signed."
```

one is a manifest, the other is a coordinate. they were never going to
be the same 15 bits even though both docs called their target "the
15-bit footer field" — they're two different 15-bit values that happen
to both fit, independently, in the same 77-character line.

## finding 4 — section 10's 13-bit L-matrix is load-bearing to the rest of that document; do not touch it

sections 11 through 16 of harmonic-transit-vision-architecture.md build
directly on the 13-bit L-matrix + 2-bit orientation split established in
section 10:

```
line 1030-1031  →  "19-bit boundary → 13-bit L-address + 6-bit face
                     selector" / "15-bit footer → 13-bit L-matrix +
                     2-bit orientation → transport address"
line 1079       →  section 13's relative-addressing rings reference
                     "via the L-matrix (Section 10)"
line 1162       →  section 13's mod-31 discussion maps onto the
                     15-bit footer
line 1233       →  section 13's 27-logical-bit collapse references the
                     same two 13-bit rows
```

the 13+2 split is not a throwaway aside — it's the numeric seed for the
19-bit boundary packet, the 8×63 face-group display matrix, and the
relative-addressing-ring math several sections later. recommend not
renumbering or resizing section 10's 13+2 bit allocation. the
reconciliation below does not ask harmonic-transit-vision-architecture.md
to change that math, only to stop implying it owns the whole line.

this is a load-bearing / do-not-resize judgment, not a claim that
section 10 is internally flawless as written — see the `footer[0-5]`
overlap noted in the secondary-note section below, which is a real
internal wrinkle in section 10 but doesn't touch the litter/harmonic
composition either way.

## finding 5 — a third candidate: 3×5-bit zenki-address chain

after the above was drafted, the human reviewer raised a third reading
of the same 15 bits, distinct from both documents: 3 slots of 5 bits
each, encoding a 3-hop routing chain rather than a flags-bitmap or a 2D
boundary address —

```
slot 1 [ 5 bits ]:  previous hop   — the zenka this came from
slot 2 [ 5 bits ]:  middle zenka   — neighbor to both previous and next
slot 3 [ 5 bits ]:  next hop       — where this is going, chainable
```

reviewer's own framing: "3 zenki like that imply travel already," and
the middle slot lets the chain represent a left-ward turn at that
point instead of a straight reversal.

**arithmetic**: checks out cleanly. 5+5+5 = 15, and 5 bits is exactly
one base32r character — so this reading packages into the same "3
base32 chars" litter-row-encoding.md already proposes for its own
payload [ line 12: "15 bits = 3 base32 chars" ]. it is not asking for
new character space; it is a different *interpretation* of the same 3
characters at positions 3-5.

**does it fit litter-row's 7+1+7 bitmap?** no — and this is a real,
not superficial, mismatch. litter's model is a *presence bitmask*: one
bit per zenka, multiple bits settable, static, computed once from the
module's own namespace at sign time [ "multiple bits can be set (module
serves multiple zenki)," litter-row-encoding.md line 81 ]. the chain
model is *positional identity*: three specific zenka IDs occupying
three specific slots, describing one directed edge of a specific
transit. these are different data models over the same bit budget —
adopting the chain reading would replace litter's bitmap, not extend or
refine it. bit 7's already-adopted "transport state" definition [ this
doc, finding on bit 7 above ] is a bitmap-shaped answer ["is this
routed further, yes/no"] that doesn't survive the swap to a
slot-shaped model — there is no "bit 7" in a 5+5+5 layout, only three
5-bit slots.

**does it fit harmonic's 13-bit L-matrix?** no, but there's a real
thematic resonance worth naming precisely rather than glossing over.
the L-matrix's 5-bit X-arm is a *lattice coordinate* — "mod-15 per
axis (base32 / TRUE window)," a position along a spatial axis, not an
identity chosen from a set of zenki. a coordinate and a zenka-ID are
different kinds of 5-bit values even though both happen to be 5 bits
wide. so the slot width matching the X-arm width is numerology
[ 5-bit units recur across this codebase per the T=5 / division-13
material ], not evidence the two schemes are the same idea.

where the resonance *is* real: harmonic's 2-bit orientation selector is
explicitly about a choice between "L vs ⌐" — which side the L-shape's
arm faces, described as determining whether a node was "routing
internally, externally, or at a boundary handover" [ section 10,
"dual-function boundary" ]. that is structurally the same shape as the
reviewer's "middle zenka gives the chain enough information to... enforce
a turnaround left-wards instead of direct reversal" — both are asking
one small field to distinguish a turn from a straight pass-through or
reversal at a junction point. section 3's "leftward travel is the
physics" [ the zulum step, `$Z <<= ...` always shifting left ] is the
same leftward-bias theme again. the *shape* of the insight — travel
with a turn option is richer than travel-or-reverse — is already present
in harmonic-transit-vision-architecture.md's orientation selector. the
reviewer's proposal is not introducing that idea; it's independently
arriving at it from a different direction [ zenka-graph traversal
rather than 2D lattice geometry ].

**verdict**: partial fit, not a resolution of the litter/harmonic
conflict. arithmetic is sound and the 5-bit unit size is well-supported
by this codebase's existing numerology, but the semantics don't overlay
cleanly onto either existing allocation — it would replace litter's
bitmap if put in positions 3-5, and it is not the same construct as
harmonic's lattice coordinate even though both use 2-bit/5-bit
turn-vs-reversal framing at a junction. it does not belong in bit 7
[ already committed to "transport state," a bitmap-shaped answer this
chain model can't express ], and it does not need the harmonic zone
[ positions 47-77 ] disturbed, since that field's job — a per-signing
dynamic coordinate scraped passively off traffic — is conceptually
closer to what a hop-chain would need than litter's static manifest is.

**where it belongs, if pursued**: the unclaimed middle span [ positions
7-46, ~40 characters, room for several 15-bit fields ] is open design
space precisely for ideas like this. recommend treating the 3×5-bit
zenki-address chain as a third, independent candidate field for that
span, alongside litter's bitmap and harmonic's coordinate — not as a
replacement for either — and leaving it there as an open idea rather
than committing bit positions now. it would need its own follow-up: what
identifies a "zenka" in 5 bits [ an index into a fixed catalog, not a
namespace prefix — the existing catalog in litter-row-encoding.md's bit
list already has more than 5-bit-addressable headroom, 10 zenki named
plus "reserved for future," so a 5-bit ID space [ 32 values ] comfortably
covers it ], and whether this field is static [ signed once ] or
dynamic [ rewritten per hop, which raises the same re-signing question
the harmonic field already has to answer and this doc doesn't attempt
to resolve ].

## finding 6 — real precedent for turn-selector + hop-count already exists, and is already extensible (2026-08-04, added post-review)

`bin/dev/division-13-table` implements a live, working directional-route
decoder — `decoded_bits_route()` — directly relevant to finding 5's
turn-vs-reversal theme, verified against the actual source rather than
taken on description:

```perl
state $directions //= {
    qw| 00 | => qw| U |,
    qw| 10 | => qw| L |,
    qw| 01 | => qw| R |,
    qw| 11 | => qw| D |
};
my $turn = join( '', shift @bits, shift @bits );
my $hops = AMOS7::BitConv::bit_string_to_num( join '', @bits );
```

2 bits select a direction [ up/left/right/down ], remaining bits encode
a hop-count magnitude. This is not just demo code — it is already a
**named, productized addressing scheme**: `cursor-address-resolution-
layer.md`, scheme 3, "directional routing (division-13-table protocol)"
— `U3`/`L1`/`R5`/`D2` syntax, relative cursor movement, already wired into
a live 6-scheme address resolver.

**Directly relevant, stated in that doc's own words**: "the
division-13-table directional routing is intentionally limited to 2D
(XY plane) in this implementation. Z-axis routing and the full 7-bit
protocol decode can be added as additional schemes later without
changing the resolver interface." This is real, working prior art for
exactly the kind of thing finding 5 speculates about — a small
turn-selector field plus a magnitude field — and it is already designed
to be extended, not a closed/finished mechanism.

**Where this resonates with, but does not resolve, finding 5**: the
substrate is different — division-13-table's turn-selector operates over
an XY spatial grid (up/left/right/down as literal directions), while the
reviewer's 3×5-bit proposal operates over a zenki-adjacency graph
(previous/middle/next hop as *identities*, not grid directions). Same
general shape [ small selector + magnitude/identity payload, turn richer
than plain reversal ], different address space. Does not change finding
5's verdict [ still a real, unadopted third candidate for positions 7-46
] — but shows the *pattern itself* [ turn-selector beside a magnitude
field ] is proven, reused at least twice already in this codebase
[ harmonic's 2-bit L-orientation selector, and division-13-table's 2-bit
direction selector ], which strengthens the case for treating finding 5
as a serious follow-up rather than a one-off idea.

**This is not confined to the dev tool — it's a live, currently-wired
pipeline**, confirmed by tracing actual module code:

```
modules/zulum.*      13 parallel entropy-generation streams
                      [ zulum.cmd.step -> zulum.loop.generate_entropy,
                        stream_id 1..13 — same 13 as the harmonic cycle ]
        |
        v
modules/cube-13.*     tracks per-stream is_true state, routes only the
                      active stream's entropy+boundary onward
                      [ cube-13.cmd.receive-entropy ->
                        protocol-7.command.send.local ->
                        "decoder.receive-entropy" ]
        |
        v
modules/decoder.base.decode_d13_bits
                      7-bit-chunk decoder, VERBATIM reimplementation of
                      division-13-table's type-prefix dispatch and the
                      identical `qw| 00 U 10 L 01 R 11 D |` turn table
```

`decoder.base.decode_d13_bits` is a faithful port, not a rewrite — same
type-accumulation logic, same dispatch shape (`GFX`/`PIX`/`B32`/`DOC`/
`RT[<dir><hops>]`), explicitly scoped to a fixed 7-bit input chunk
(`param = <7-bit-string>`, rejects anything shorter). The `RT[...]`
[ routing ] output is the direct live equivalent of `decoded_bits_route`.
This means the turn-selector + hop-count pattern isn't hypothetical or
dev-tool-only — it is actively receiving real entropy from a running
[ experimental ] zenka pipeline right now.

**The dead-code bug carried over into the live port — fixed (2026-08-04)**:
the same `'01'`-prefix branch (`return sprintf('PIX[%s]', $work) if
$type eq qw| 01 |`) was unreachable in both files for the identical
reason — the accumulation logic always extends `'01'` to 3+ bits before
this check runs. Resolved per the author's own protocol comment above
`decoded_bits()` in `bin/dev/division-13-table` (lines 140-174): the
`'1'`-prefix branch is documented as the sole graphical/5x7-pixel-matrix
case, and `'01'` is documented as always resolving further into BASE32
(`'010'`) or a document header (`'0110'`/`'0111'`) — so the dead
`'01'`/`PIX[...]` line was simply erroneous, not a sign of a missing
extension rule. Removed the dead line from both `bin/dev/
division-13-table`'s `decoded_bits()` and `modules/
decoder.base.decode_d13_bits` [ the live production port ]. Verified: no
code anywhere in `modules/` or `bin/` referenced the `PIX[...]` output;
both files pass their respective syntax checks (`perl -c`,
`bin/dev/ptd -c`) after the removal. Not committed, left for review.

## recommendation — compose, don't choose

the two *specified* designs stay, in disjoint zones of the same
77-character line 4. the reviewer's third [ finding 5 ] is logged as an
open candidate for the still-unclaimed middle span, not committed now:

```
#:[LLL]::::::::::::::::::::::::::::::::::::::::[HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH]
  ^^^                    ^                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  litter                 open [ positions 7-46 ]   harmonic spatial coordinate
  [ positions 3-5,        candidate: reviewer's     [ positions 47-77, interlaced
    3 base32r chars ]     3×5-bit zenki-address      dot/colon, 15 bits ]
  static zenka-           chain [ finding 5 ] —
  involvement bitmap      not adopted, logged only
  [ 15 bits ]
```

neither doc needs its numeric design changed. the fix is two small
edits:

1. litter-row-encoding.md gains bit 7's meaning [ see below ] and a note
   that its 3-char payload occupies only positions 3-5 of line 4, not
   the whole line.
2. harmonic-transit-vision-architecture.md gets its "line 5" mislabel
   fixed to "line 4", and its "available for future prefix fields" note
   [ section 2 ] updated to point at litter-row-encoding.md by name,
   since that future field now has an owner.

## bit 7 — the reviewer's "transport state [local|routing]" proposal

adopted as-is into litter-row-encoding.md's 7+1+7 layout. it was the one
genuinely undefined bit in either scheme, and the proposal fits the
existing structure cleanly rather than needing a redesign:

```
bits 0-6:   zenka involvement flags   [ which zenki use this module ]
bit  7:     transport state           [ 0 = local, 1 = routing ]
bits 8-14:  routing / transport-trunk flags   [ which trunks carry it ]
```

read as a sentence: bits 0-6 say *who* touches the module, bit 7 says
*how far* that touch travels [ contained to the local litter
neighborhood, vs. handed off across a longer routing path ], bits 8-14
say *which trunks* carry it when it does travel. bit 7 is the natural
hinge between the two halves rather than an arbitrary spacer — a module
with only local zenka involvement can leave bits 8-14 at zero and bit 7
at 0; a module that's also routed cross-trunk sets bit 7 and populates
the trunk flags. no conflict with the harmonic scheme: bit 7 lives
entirely inside the litter zone [ positions 3-5 of line 4 ], nowhere
near the harmonic payload at positions 47-77.

## what to do in each source doc [ design only, no code ]

### data/tasks/litter-row-encoding.md

- replace `bit 7: (void/special)` with `bit 7: transport state [0=local, 1=routing]`
- add a one-line note under "litter row format" that the 3-char payload
  occupies positions 3-5 of the 77-char line only; positions 47-77 are
  reserved by harmonic-transit-vision-architecture.md's spatial-coordinate
  field, see this doc.
- note the reviewer's 3×5-bit zenki-address-chain idea [ finding 5 ] as
  an open, unadopted candidate for the unclaimed positions 7-46 span —
  do not fold it into the 7+1+7 layout, it's a different data model
  [ identity slots vs a presence bitmap ] and would replace, not
  extend, the current bitmap if placed at positions 3-5.

### data/md/documentation/harmonic-transit-vision-architecture.md

- overview line 22 and section 2 line 166: "footer line 5" → "footer
  line 4" [ counting error, no real footer has a 5th line ]
- section 2, near line 194 ["the left side ... is available for future
  prefix fields"]: add that this space is now claimed by
  data/tasks/litter-row-encoding.md's zenka-litter bitmap [ positions
  3-5 ], not fully open — the remaining unclaimed span is positions
  7-46.
- section 2, validation hierarchy [ lines 181-189 ]: add that levels
  1-3's structural scan starts at position 7, exempting the litter
  zone [ positions 2-6 ] from harmonic's own mod-6 group-alignment and
  separator checks. without this, a validator implementing section 2
  literally would reject every line carrying a litter payload — see
  the validation-hierarchy discussion in finding 2 above.
- section 10's 13+2 bit allocation: do not renumber or resize — it is
  load-bearing for sections 11-16 [ finding 4 ]. the `footer[0-5]`
  overlap noted below is a separate, pre-existing wrinkle in section 10
  itself and is out of scope for this reconciliation.

## secondary note — not part of this reconciliation, flagged for later cleanup

section 10 [ line 945 ] writes `footer[0-5] → face selector`, but the
same section's own composition [ lines 860-863 ] puts the L-matrix at
bits 0-12 and the orientation selector at bits 13-14 — so `footer[0-5]`
as written overlaps the L-matrix's own low bits rather than naming a
distinct range. reads like a conflation between the 15-bit footer field
and the 19-bit boundary packet's face-selector [ which is a different,
larger structure per lines 891-905 ], not an error introduced by this
reconciliation. flagged for a future pass on section 10; does not
change the litter/harmonic composition either way since it's entirely
inside the harmonic zone [ positions 47-77 ].

section 2 of harmonic-transit-vision-architecture.md itself contains a
small internal inconsistency worth a follow-up pass someday: it opens
with "three base32 symbols [ 5 bits each ] cover the full 15-bit
register" [ line 161 ] as the mathematical framing, then two paragraphs
later defines the actual footer encoding as interlaced `.`/`:` bits, not
base32 letters at all [ line 164-179, and the Phase 2 perl at line
691-703 ]. the math section and the implementation section describe two
different alphabets for the same value. this doesn't affect the
litter-row reconciliation [ litter's zone and harmonic's zone still
don't collide either way ] but should be cleaned up if/when section 2 is
next touched.

## finding 7 — the RT[...] output dead-ends: the live pipeline never
produces the 7-bit chunk decode_d13_bits decodes (2026-08-04)

traced the full live wiring, module by module, to check whether the
`RT[<dir><hops>]` output finding 6 confirmed is a real production
signal or just reachable from a dev command. answer: **it dead-ends,
and the reason is more specific than "nobody reads the output" — the
live streaming path never even computes the 7-bit chunk in the first
place.**

`zulum.loop.generate_entropy` builds `$num_bits_64` [ a 64-bit binary
string ] every iteration, then only ever takes `substr( $num_bits_64,
0, 42 )` — the leading 42 bits — as `$main_entropy_bin`. Bits 42-48
[ the 7-bit d13 type-prefix chunk that `bin/dev/division-13-table`'s
`display_result()` extracts as `$decoded` and feeds through
`decoded_bits()` ] and bits 49-63 [ the 15-bit auxiliary field ] were
computed as part of `$num_bits_64` but simply never sliced out or
forwarded. `cube-13.cmd.receive-entropy`'s wire format was `<stream_id>
<bits> <is_true>` — no chunk field to carry it even if it had been
computed. `decoder.cmd.receive-entropy`'s parse regex was `^(\d+)
([01]{42})`, unanchored at the end, so nothing downstream of it was
even looking for a trailing token.

meanwhile `decoder.base.decode_d13_bits` — confirmed by
`grep -rn decode_d13_bits modules/ bin/` — has exactly one caller in
the entire tree: `decoder.cmd.D13-collection`, a manual/dev command
that reseeds its own `$Z` from a user-supplied value or the level-5
accumulator's last value and runs its own independent `Z <<= 4; Z /=
13; ...` loop. It does not read from any live zulum stream. Its
`RT[...]` result is formatted into a display string and returned to
the caller — nothing acts on it. So the dead-end has two layers: (1)
the live entropy pipeline never manufactures the input
`decode_d13_bits` needs, and (2) even the one place that does call
`decode_d13_bits`, the output is display-only.

corollary bug caught while verifying the wire format:
`cube-13.cmd.receive-entropy` parsed with `split m| +|, $args, 3` —
a hard 3-token limit. Any future 4th token appended to the args string
[ e.g. exactly the fix below ] would have been silently absorbed into
`$is_true`, which is used as a bare boolean in `cube-13.jump_table`'s
`'true'` branch (`return $sid if $streams->{$sid}{'is_true'}`) — a
string like `"1 0010110"` is truthy in Perl regardless of its bits, so
`jump true` would have started matching streams that are not actually
harmonic-true. Fixed as part of the change below by bumping the split
limit to 4 in the same edit that added the 4th token, so the bug was
never actually shipped in a reachable state.

## finding 8 — cube-13.cmd.jump's direction vocabulary undocumented
4th value, and its relationship to U/L/R/D (2026-08-04)

`cube-13.cmd.jump`'s validator accepts `qw| true reverse next root |`
[ four values ], but the command's own `# param` comment and its
error-message string both say `<true|reverse|next>` — `root` is real,
wired [ jumps to stream 10, the "convergence attractor" per the jump
table's own comment ], and silently undocumented in two places in the
same file. Small, one-line doc-drift bug, unrelated to the RT[...]
question, noted here since it was found while reading the same file.

on the actual question — do cube-13's jump directions (`true | reverse
| next | root`) relate to `decode_d13_bits`'s U/L/R/D turn selector —
the answer is no, confirmed now that the wiring is fully read: they are
genuinely separate concerns that happen to share the word "direction".
cube-13's directions select among 13 *streams* by harmonic-truth
adjacency [ a 1-dimensional ring with one distinguished "attractor"
node ]; U/L/R/D selects a *2D grid heading* decoded out of live entropy
bits, orthogonal data with no stream-selection meaning at all. Nothing
in the traced code paths treats them as interchangeable, and unifying
them would be a category error [ per finding 6's own reasoning, now
verified against the full call graph rather than partial reads ]. Left
separate, as already recommended.

## finding 9 — INDEXCUBE already is a hop-chain; the reviewer's 3×5-bit
idea is testable against real accumulated data without touching the
footer bit-layout (2026-08-04)

`decoder.handler.on-boundary` already pushes one entry per harmonic
boundary crossing onto `$data{'decoder'}{'INDEXCUBE'}`:
`{ stream_id, boundary_value, boundary_n, p7ref, timestamp, depth }`.
Consecutive entries in that array are, structurally, already a
prev-hop → next-hop trace across the 13 zulum streams — the same shape
finding 5's reviewer proposal wants to put in 3×5 footer bits [ 13
streams needs only 4 bits, comfortably inside the reviewer's proposed
5-bit zenka-ID slot width ]. This is a stronger answer than the footer
question alone: the "previous / middle / next hop" idea doesn't need
new bit positions committed to be evaluated — it can be tested today
by deriving prev/next fields from three consecutive INDEXCUBE entries
and checking whether that reconstruction is stable/meaningful over a
real run. Not implemented here [ would need `decoder.cmd.show-
indexcube` or a new sibling command to project triples out of the
array — small, but a separate follow-up, not done in this pass ], but
this changes finding 5's status from "arithmetically sound, semantically
unadopted" to "arithmetically sound, and now empirically testable
against live data without any footer/signing changes."

## finding 10 — the "verbatim port" claim in finding 6 was wrong for the
BASE32 branch: decoder.base.decode_d13_bits diverged from division-13-
table's decoded_bits_BASE32(), now fixed (2026-08-04)

caught while double-checking the change above, since it was about to
make this branch reachable with real traffic for the first time.
comparing the two implementations directly:

```
bin/dev/division-13-table :: decoded_bits_BASE32()
    return $num + 2 if $num <= 5;   ## 2 .. 7 ##
    return chr( 59 + $num );        ## A .. Z ##

modules/decoder.base.decode_d13_bits  [ before this fix ]
    my $char = $num <= 5 ? chr( 48 + $num ) : chr( 55 + $num );
```

these are not the same mapping. for num 0-5 the reference returns the
RFC 4648 digits `2`..`7` [ `$num + 2`, matching the file's own doc
comment "RFC 4648 BASE32 alphabet ## 2-7 A-Z ##" ]; the live port
returned `chr(48+num)` = `0`..`5` instead — off by exactly the `+2`
offset the reference applies and the port dropped. for num 6-31 the
reference returns `chr(59+num)` = `A`..`Z`; the live port returned
`chr(55+num)`, which is `A`..`Z` shifted down by 4 into the wrong part
of the ASCII table for the low end of that range [ num=6 → `=` instead
of `A`, num=7 → `>` instead of `B`, etc -- verified by direct
enumeration of both formulas over num 0-31 ]. so the "verbatim port,
not a rewrite" characterization in finding 6 was correct for the type-
prefix dispatch and the routing branch, but not for this one branch.

fixed in modules/decoder.base.decode_d13_bits to `$num <= 5 ? $num + 2
: chr( 59 + $num )`, now byte-for-byte matching the reference formula.
in scope [ decoder.base.decode_d13_bits is one of the two division-13-
table-family files this whole thread has always covered ], small,
mechanical, and directly relevant: without this fix, the newly-wired
level-7-D13 buffer [ see "change made" below ] would have started
emitting systematically wrong BASE32 characters into real output the
moment zulum produces a `010`-prefixed chunk, which is not a rare case
[ 1/8 of the input space under uniform bits -- the type-prefix tree's
majority leaf is GFX at 1/2, not B32, but 1/8 is still routine traffic,
not an edge case ]. caught before any commit, so no bad data was ever
produced.

## change made (2026-08-04) — wire the missing 7-bit chunk through as a
passive, additive observability path

closes the finding-7 dead-end at its root cause [ the chunk was never
computed/carried, not just never consumed ] with a change scoped to be
reversible and behavior-neutral: it adds a new optional field end-to-end
and a new counter/buffer; it does not change any existing routing,
jump, or entropy-generation behavior. No footer/signing files touched.

```
modules/zulum.loop.generate_entropy
  - extracts $decode_chunk = substr($num_bits_64, 42, 7) [ same offset
    division-13-table's display_result() uses for $decoded ]
  - stores it on $stream->{'decode_chunk'}, passes it as a 4th arg to
    attached-consumer callbacks, includes it in the returned data hash

modules/zulum.cmd.stream-attach
  - callback wrapper now accepts the 4th ($decode_chunk) callback arg
    and appends it as a 4th token in the args string sent to cube-13

modules/cube-13.cmd.receive-entropy
  - split limit bumped 3 -> 4 to actually capture the new token instead
    of letting it corrupt $is_true [ see finding 7's corollary bug ]
  - forwards the chunk on to decoder.receive-entropy as an optional
    trailing token [ empty string if not present -- decoder tolerates
    a missing/short chunk ]

modules/decoder.cmd.receive-entropy
  - parsing switched from a fixed regex to split-based token parsing;
    validates entropy is exactly 42 bits and, if present, decode_chunk
    is exactly 7 bits, else drops it to undef rather than erroring
  - # param updated to document the now-optional trailing field

modules/decoder.zenka.receive_entropy
  - if a valid 7-bit decode_chunk arrived, calls
    decoder.base.decode_d13_bits on it
  - increments $data{'decoder'}{'d13_types'}{$type}++ [ type tag parsed
    off the GFX[.../B32[.../DOC[.../RT[... prefix ]
  - appends a line to a new rolling buffer 'level-7-D13', following the
    same pattern already used for level-5-B32 and level-6-D3, with one
    deliberate difference: decoder.handler.on-boundary closes level-5-B32
    and level-6-D3 [ per-boundary-segment accumulators ] but does not
    touch level-7-D13, which is a continuous run-long histogram/log, not
    a segment buffer -- intentional, not an oversight, but worth flagging
    for a reviewer since the other two levels behave differently
  - includes 'd13_decoded' in its own return payload

modules/decoder.base.decode_d13_bits  [ bug fix, finding 10 below ]
  - the BASE32 branch's character mapping did not actually match
    division-13-table's decoded_bits_BASE32() despite finding 6's
    "verbatim port" claim -- see finding 10. fixed to match exactly.

modules/decoder.zenka.init_code
  - initializes $data{'decoder'}{'d13_types'} = {} and the new
    level-7-D13 rolling buffer, mirroring the level-5/level-6 init
    blocks already present

modules/decoder.cmd.show-d13-types  [ new file ]
  - new read-only command, modeled directly on decoder.cmd.show-
    indexcube's shape: prints the d13_types histogram [ counts and
    percentages per decoded tag ] accumulated from live stream traffic
    since decoder init. note: `UNK` is listed in decode_d13_bits'
    dispatch as a fallback but is not actually reachable from this
    pipeline -- the type-prefix accumulation only ever terminates at
    `1`/`00`/`010`/`0110`/`0111`, all five are dispatched, and both
    callers [ this new wiring, gated by decoder.cmd.receive-entropy's
    `^[01]{7}$` check, and the pre-existing decoder.cmd.D13-collection
    ] only ever pass a full 7-bit string. same for `decoded_bits_route`'s
    `$dir->{$turn} // '?'` fallback -- `$turn` is always one of the four
    keys, so `?` cannot appear either. both fallbacks are correctly left
    in place as defensive guards, just noted here so a reviewer doesn't
    expect to see `UNK` or `?` show up in real histograms.
```

all eight touched/added files pass `bin/dev/ptd -c` [ syntax ok ].
**not committed** — left for review, per this doc's existing convention
of logging design/code changes without committing them directly.

what this buys, concretely: the question "does RT[...] actually appear
in real zulum entropy, and with what direction/hop-count distribution"
changes from unanswerable [ the signal never existed in the live path ]
to something `p7c decoder.show-d13-types` can answer empirically once
zulum is running. Over uniform random 7-bit input, the dispatch tree's
own prefix widths predict GFX 1/2 [ leading `1` ], RT 1/4 [ `00` ], B32
1/8 [ `010` ], DOC 1/8 aggregate [ `0110` + `0111`, each 1/16, merged
under one tag by this histogram ]. If the observed histogram never
diverges from that baseline, that itself is informative — it would mean the 42-bit/7-bit split point
carries no structure beyond what division-13-table's own bit-tree
predicts, i.e. the D13 protocol's type field is not currently harmonic-
correlated the way the entropy-quality gates [ `is_true` checks ] make
the 42-bit main field. That would be a real, testable claim, not
speculation, and it would only be answerable because the wiring in this
change now exists.

not done, and deliberately out of scope for an additive/reversible
step: routing RT[...]'s decoded direction into cube-13.cmd.jump or any
other behavior-changing consumer [ finding 8's category-error argument
applies — a 2D grid heading is not a stream-selection signal ], and
projecting INDEXCUBE triples into an actual 3×5-bit prototype [ finding
9 — real next step, but a distinct piece of work with its own command
surface, not folded into this pass ].

## recommendation for what happens next

in priority order, based on what this session found:

1. **run it and read the histogram.** the change above is inert until
   zulum is actually generating live traffic; `p7c decoder.show-d13-
   types` after some run time is the fastest way to turn finding 7 from
   a structural claim into a measured one. reachability confirmed by
   reading `configuration/zenki/decoder/start` [ `modules.load =
   auth.client net protocol io.unix ui decoder` ] and `bin/Protocol-7`'s
   `p7_load_code()`, which discovers modules by disk file-name prefix
   matching the loaded namespace rather than an explicit per-file list --
   the new `decoder.cmd.show-d13-types` file needs no separate
   registration to be picked up on decoder zenka start. `modules/
   base.list.subroutines` [ the flat name index some commands appear in
   ] looks generated and was deliberately left untouched.
2. **finding 9's INDEXCUBE-triple projection** is the most promising
   concrete next step after that — it tests the reviewer's 3×5-bit idea
   against real data with no footer/signing risk at all, and would
   either strengthen finding 5's "arithmetically sound" verdict with
   empirical support or reveal that stream-hop sequences don't actually
   carry the kind of previous/middle/next structure the proposal
   assumes.
3. finding 8's `root` doc-drift is a one-line fix in `cube-13.cmd.jump`
   whenever that file is next touched; not urgent, logged so it isn't
   lost.
4. the footer/signing-layer questions [ findings 1-6, the recommendation
   above ] are unchanged by this session — this work was entirely on
   the zulum/cube-13/decoder side, no footer bit positions were claimed
   or altered.

## finding 11 — reviewer's 3+1+3=7-slot extension of finding 5: the two
endpoint numbers (35, 63) verify exactly against independent existing
docs; the progression connecting them does not, and the 63 "match" to
the 8×63 face-group matrix is a new, unreconciled coincidence, not a
confirmed link (2026-08-04)

the reviewer extended finding 5's flat 3×5-bit zenki-address-chain idea
with a symmetric "-3..0..+3" framing (3 slots back + 1 center/coupling
slot + 3 slots forward = 7 slots × 5 bits = 35 bits) and a stated
progression 15 → 30 → 60+3 bits, connected to the already-documented
8×63 face-group matrix and 2×2×2-cube-with-void geometry, plus a
screenshot offered as loose visual support. checked each claim
independently against the cited source docs rather than trusting the
reviewer's own verification notes. verdict is mixed and worth stating
plainly rather than rounding up: **two individual numbers check out
exactly against real, independent, pre-existing material; the
narrative that strings them together does not, and one of the two
"matches" is itself a coincidence stacked on top of an already-known,
already-unreconciled coincidence.**

### the 35-bit / 7×5 claim — verified exact, but only under one of two
real, non-equivalent orientations documented for the same 35 bits;
the reviewer's proposal matches one and not the other, and my first
draft of this finding conflated them

checked the primary source directly rather than trusting the two
summary docs that cite it. this matters because the summaries
(`topic-harmonic-mathematics.md:429-436`,
`sub-bit-element-definition.md:236-243`) both cite *two different* docs
for "the 35-bit AMOS checksum matrix" as if they describe one
structure, and they don't:

- `data/ai-mem/claude/topic-base32-namespace.md:21`: "AMOS checksum is
  base32-native (**7 chars × 5 bits** = 35 bits)" — a base32-string
  view. 7 character positions, each an independent 5-bit value. This
  is structurally identical in shape to "7 slots, each holding a 5-bit
  zenka ID" — a base32 character *is* a 5-bit value, so this orientation
  is a genuine, close structural match to the reviewer's 3+1+3 proposal,
  not just a bit-count coincidence.
- `data/md/design-specs/fractal-data-architecture-holographic-tty.md:
  94-105`, with an explicit diagram: "the 7x5 bit matrix (35 bits)
  encodes **5 rows of 7-bit sub-states**" — Row 0 through Row 4, each
  row 7 bits wide, row 4 specifically called out as "5th sub-bits vote
  to set true bit in next layer." This is the *transpose*: 5 groups of
  7 bits, not 7 groups of 5 bits. Same 35 bits, opposite grouping, and
  a functionally different concept (a voting/consensus sub-bit
  structure, not 7 independently-addressable slots).

both are real and both are cited, confirmed-not-speculative structures
in this codebase — they are just not the same structure, despite
sharing a bit-count and being cited together in the same breath by the
summary docs. **the reviewer's "7 slots × 5 bits" proposal matches the
base32-string orientation exactly** [ 7 independently-addressed 5-bit
positions is precisely what a 7-char base32 checksum already is ] —
this is a stronger, closer match than a bare bit-count coincidence,
because the *shape* (N independent slots, not a transposed sub-bit
matrix) actually agrees. **it does not match the consensus-matrix
orientation** [ 5 rows of 7-bit channels serves a voting function
internal to one value, not slot-addressed identity ], and that
orientation is the one with a worked diagram and the more concrete
functional description in its own source doc.

so, correcting my own first pass at this finding: this is not "matching
bit-count, not matching data model" the way the flat 3×5-vs-litter
comparison was. Under the base32-string orientation, the reviewer's
7-slot proposal is a real shape match, not just an arithmetic one. The
caveat is narrower than I first wrote: this still doesn't resolve
finding 5's original identity-slots-vs-presence-bitmap conflict [ a
7-slot base32-native structure is still identity-slot-shaped, not
bitmap-shaped, so it still couldn't replace litter's 15-bit bitmap at
positions 3-5 without the same substitution problem finding 5 already
described ] — but it is a materially better match to *an* existing
structure than I initially credited it, specifically because AMOS
checksums are already, natively, 7 independently-addressed 5-bit
slots, not merely 35 bits arranged some way.

also worth flagging plainly: 35 bits no longer fits inside the
footer's 15-bit-unit convention this whole task has used throughout
[ litter's field is 15 bits / 3 chars, harmonic's is 15 bits / interlaced
across positions 47-77 ] — it would occupy 7 of the ~40 open characters
at positions 7-46, which is still comfortably inside that span, so it
is not a budget problem, just a break from the "everything here is a
15-bit unit" pattern the rest of this doc has relied on as one of its
own pieces of supporting evidence.

### the 15 → 30 → 60+3 progression — not independently grounded; reads
as working backward from two known-good numbers, not forward from a
stated mechanism

searched for any existing doc support for "30 bits" or "6×5" as a
meaningful intermediate structure comparable to the 35-bit and 63
endpoints — found none. No file in `data/ai-mem/claude/` or
`data/tasks/` describes a 30-bit or 6-slot structure as "decodable
where 3×5 is not," and the reviewer's proposal doesn't state what
makes 15 bits undecodable or what specifically 30 bits adds that
resolves it. This middle step is presented as self-evident but isn't
derived from anything checkable the way the two endpoints are.

the "60+3" endpoint is arithmetically unclear on its own terms even
before checking whether it means anything: is it 12 slots × 5 bits
[ continuing the 3→6→12 doubling implied by "3×5 → 6×5" ] plus 3
leftover bits, or something else? the reviewer's framing doesn't say,
and "+3 leftover bits" with no stated purpose is exactly the shape of
a number chosen to land on a target rather than derived from a
requirement. **this is the honest read**: 35 and 63 are both real,
verified matches to independently-existing structures [ next section
], and it is genuinely notable that a doubling-ish progression from 15
happens to pass near both — but "15 → 30 → 60+3" as a *stated
mechanism* is not established by anything found in this codebase. Log
the progression as an interesting numerical observation connecting two
independently-solid endpoints, not as a third verified claim in its
own right.

### the 60+3=63 match — real number, multiply-attested in this
codebase, but via unrelated arithmetic each time; no bit-to-cell
addressing scheme connects any of them to "63 bits in a footer field"

60+3 = 63 is correct arithmetic on its face. checked what 63 actually
means elsewhere in this codebase, independently, rather than accepting
the reviewer's single citation:

- `data/ai-mem/claude/topic-node-group-geometry.md`: 4×4×4 = 64 subcubes
  minus 1 missing innermost corner = **63 blue ambient subcubes** per
  ambient cube; 8 such cubes in a 2×2×2 arrangement around a
  4×4×4 central void = 8×63 = 504 total. this is the structure the
  reviewer cited, and the number is exactly as they said.
- `data/md/documentation/harmonic-transit-vision-architecture.md:917-940`:
  a **separately-derived** "8×63 face-group display matrix," where
  63 = 7×9 [ 7 nodes × 9 columns per node ], not 4×4×4-1. same digits,
  different arithmetic, different object [ a 2D display-matrix layout
  for a 7-node face group, not a 3D subcube count ]. worth naming: the
  collision doesn't stop at 63 -- it extends one level up to the
  products too. this doc's own line 924 states "8 × 63 = 504 = 42 × 12
  (entropy frame × CCW cycle length)," the *same* 504 the node-group
  doc reaches via 8×63 subcubes, and factored through 42 -- the same
  42-bit entropy frame the "change made" section above just wired live
  through zulum/cube-13/decoder. not claiming this proves a link; it's
  the same class of coincidence one level up, and it gives any future
  reconciliation pass a concrete number [ 504 = 8×63 = 42×12 ] to work
  from rather than just "both structures use 63."
- `data/ai-mem/claude/topic-iris-spoke-labels.md:26,37`: a **third**
  independent derivation, 63 = 8×8-1, explicitly labeled in that doc
  as "(cube void geometry)" and referencing "the 8×63 field geometry"
  by name — meaning this doc already treats "8×63" as an established
  combined term.
- `data/ai-mem/claude/topic-decision-node-polarity-geometry.md:42-46`:
  already flags, independently of this session, that a *different*
  27-subcube (3×3×3) geometry is "distinct from
  [[topic-node-group-geometry]] (8×63=504 subcubes...) — a different
  count... Not yet reconciled with that geometry." So the pattern of
  "same evocative number, multiple structures, not actually reconciled"
  is already a known open thread in this codebase before this session
  touched it.

so: 63 is real and recurs across at least three independently-derived
contexts already in this project [ subcube count, face-group matrix
columns, iris-ring count ], which means the reviewer's bit-progression
landing on 63 is landing on a number this codebase already treats as
structurally significant — that's worth taking seriously rather than
dismissing as arbitrary. **but** none of the three existing 63s were
ever bit-counts — they are all *cell counts* [ subcubes, matrix
columns, label-ring positions ] in navigable geometric or visual
structures. The reviewer's 63 is a *bit-count* of a proposed footer
field. Treating "63 bits" and "63 [subcubes / columns / rings]" as the
same 63 requires an explicit addressing correspondence — e.g. "one bit
per subcube," "one bit per matrix column" — that is not proposed
anywhere, by the reviewer or in any existing doc. Without that bridge,
this is a fourth independent arrival at a recurring number, which is
suggestive precisely because the number keeps recurring, not because
this particular arrival is derived from the others. It should be
logged as a real, striking coincidence worth further attention — most
plausibly as a candidate lead toward finally reconciling the three
already-unreconciled 63s topic-decision-node-polarity-geometry.md
already flagged — not as confirmation that a 63-bit or 60+3-bit footer
sub-field is the right design.

**Update, same day**: found a genuine internal decomposition of one of
the three 63s [ not a bridge between all three, but real, not
numerology ]. `harmonic-transit-vision-architecture.md`'s face-group
display matrix already states, in its own words: "63 columns = 7 nodes
× 9 columns per node" and "9 columns per node: 8 payload columns
[matching the 8-row depth] plus 1 separator column." Summing along the
payload/separator axis instead of the node/column axis: `7 nodes × 8
payload columns = 56`; `7 nodes × 1 separator column = 7`; `56+7=63`,
exactly. This was independently spotted [ user connected `56` — from
`data/md/coding-tasks/checksum-route-binary-framing-harmonic-
foundations.md`'s `42+7+7=56` page-structure math and the real
`bin/amos-data-pager-56` tool — to this doc's `63` ] and confirmed
against the primary source rather than assumed. Caveat that still
holds: this is a *column* decomposition of a 2D display matrix, not a
*bit* decomposition of anything, so it does not by itself supply the
"one bit per subcube/column" addressing correspondence this section
already said was missing for treating any of the three 63s as a
footer-field bit-count. It does confirm the face-group-matrix route to
63 has real internal structure worth checking against the other two
routes [ subcube-count, iris-ring-count ] for a similar hidden split.

### the screenshot

the coordinator's own framing of the attached capture [ dark
background, 2×2 grid of gridded panels with visible dark gaps between
them ] is already appropriately hedged as "consistent with, not
confirmed by" the 2×2×2-with-central-void geometry, and I have not
been given the image itself to check pixel-level correspondence, so I
can't add independent verification either way. worth one honest
caveat beyond the existing hedge: a 2×2 grid of panels with gaps
between them is also what a 2×2×2 arrangement of *anything* would
produce in a naive 2D cross-section or top-down projection, void or
no void — the described image is consistent with the claimed geometry,
but it would be similarly consistent with several other 2×2×2 or
simple 4-quadrant layouts that have nothing to do with subcube
addressing or footer bit-fields specifically. treat it as weak,
shape-level corroboration of "this system does render 2×2×2-ish
grouped layouts somewhere," not as evidence for the specific 35-bit or
63-bit proposals above.

### verdict

- **35 bits / 7×5, matching the AMOS checksum's own confirmed
  structure**: real, exact, independently verified — but the checksum's
  35 bits are documented under two different, non-equivalent
  orientations [ 7 chars × 5 bits, vs. 5 rows × 7-bit sub-states ], and
  the reviewer's proposal matches only the first. Under that first
  orientation it's a genuine shape match [ 7 independently-addressed
  5-bit slots ], not just a bit-count coincidence. Still does not
  resolve finding 5's identity-slots-vs-bitmap conflict — it's the same
  identity-chain model at a different [ also-real ] bit budget.
- **the 15→30→60+3 progression**: not grounded in anything found in
  this codebase. reads as working backward from two already-known
  numbers rather than forward from a stated design need. log as an
  observation, not a finding.
- **60+3=63, matching the node-group subcube count**: real number,
  but 63 already recurs independently at least twice more in this
  codebase via unrelated arithmetic [ face-group matrix, iris rings ],
  and none of the three are bit-counts — they're cell/column/ring
  counts. no addressing scheme bridges "63 bits in a footer field" to
  "63 [cells] in a geometry" anywhere in this project yet. striking
  and worth flagging precisely because 63 keeps recurring — genuinely
  suggestive — but not yet a structural match the way finding 6's
  turn-selector precedent or this section's own 35-bit match are.
- **screenshot**: shape-consistent, not evidentiary; already correctly
  hedged by the coordinator and I have no independent way to check it
  further.
- finding 5's own original verdict [ arithmetically sound, semantically
  unadopted, belongs in the open positions 7-46 span if pursued at all ]
  is unchanged by this extension. Nothing here raises it to "adopted"
  or lowers it to "rejected" — it stays exactly where finding 5 and
  finding 9 already left it: a real, logged, open candidate, now with
  one more real-but-partial piece of supporting arithmetic and one
  clearly-flagged unresolved thread [ the three-way 63 coincidence ]
  worth a dedicated look of its own, separate from the footer question.

## status

design reconciliation only for findings 1-6 and this section's findings
7-11 — no signing-system changes. the code change described in
"change made" above is real and does touch modules/, scoped additively
per the reasoning there; everything else in this file, including this
finding, remains design-only. leave the signing-relevant portions of
this file clean; the signing system adds the real footer on commit,
per litter-row-encoding.md's own "signatures note" convention.

## finding 12 — a second dead field, same shape as finding 7: the "auxilary_15" bits decompose into a documented but never-implemented 7-bit complement field (2026-08-04)

`data/md/coding-tasks/checksum-route-binary-framing-harmonic-foundations.md`
[ the same doc that documents `1001` as the zenka center-pulse/inversion
marker, section "42+7+7 = 56 = 64-8 optimization" ] specifies the full
64-bit division-13-table value as:

```
42 bits (main entropy) + 7 bits (decoded protocol) + 7 bits
(complement/error-correction) + 8 bits (structure/overhead) = 64 bits
```

Checked against the actual code: `bin/dev/division-13-table` line 122
computes `my $auxilary_15 = substr($num_bits_64, 49, 15)` — bits 49-64,
already commented `## AUXILARY 15 ARE NOT USED FOR ENTROPY, ONLY KEPT ##`.
`42+7+7+8 = 64`, and `49..64 = 15` — the doc's `7+8` split of the
"auxiliary 15" is arithmetically exact, not approximate. Grepped
`complement` across `division-13-table`, `zulum.*`, and
`decoder.base.decode_d13_bits`: zero hits. The 7-bit
complement/error-correction field this design doc specifies has never
been extracted or used anywhere in the live code — it has been sitting,
undifferentiated, inside the "auxiliary, not used" 15 bits the whole
time.

**This is the same shape as finding 7** [ the D13 type-prefix chunk was
computed every cycle and discarded until this session threaded it
through zulum -> cube-13 -> decoder ]. Not yet acted on — flagged as the
next concrete candidate for the same treatment: extract bits 49-56 as
`complement` alongside the already-wired `decode_chunk` (bits 42-49),
leaving bits 56-64 [ the 8-bit "structure/overhead" remainder ] as still
genuinely unaccounted for even under this doc's own decomposition. Not
implemented here — logged for a future pass, same discipline as the rest
of this document: state what's found, not what's assumed useful.

## finding 13 — a fourth "8", flagged with the same caution as the three unreconciled 63s (2026-08-04)

User noted `7×8=56` also connects to "8×63 sub-cube cubes" — i.e. the
outer 8-ambient-cube count from `topic-node-group-geometry.md`, framed
as "perhaps hinting to a holographic composite void."

**Same caution applied as finding 11's three 63s, deliberately**: the
`8` in "8 ambient cubes around a central void" is a 3D spatial
arrangement count; the `8` in "8 rows [ 7 harmonic levels + 1 root/meta
row ]" from the face-group display matrix (finding 12's update) is a
2D display-matrix row count. Nothing found in this session establishes
these are the same `8` rather than two independently-arrived-at `8`s
sharing a digit — the exact pattern `topic-decision-node-polarity-
geometry.md` already flags as open and unreconciled for the 63s. Logged
honestly as a fourth instance of that same open pattern, not as a
fourth confirmed bridge. The user's own framing ["perhaps hinting"] is
already appropriately hedged.

**Recommendation given the accumulation**: findings 11-13 have now
surfaced four separately-arrived-at instances of "same small number [
56, 63, 7, 8 ], different structure, not yet bridged." Rather than keep
adding isolated sightings, the next useful pass on this specific thread
is consolidation: enumerate every documented occurrence of 56/63/7/8
across `topic-node-group-geometry.md`, `harmonic-transit-vision-
architecture.md`, `checksum-route-binary-framing-harmonic-
foundations.md`, and `topic-decision-node-polarity-geometry.md` in one
place, and check specifically for or against a genuine addressing
correspondence — not another sighting, an actual bridge or a clear
statement that none exists. Not attempted here.

**Done, elsewhere (2026-08-04)**: the consolidation this recommendation
asked for is `data/tasks/recurring-cube-number-collision-audit.md` —
full enumeration of 7/8/9/19/26/27/28/56/63/504 across the docs listed
above plus two more that turned out load-bearing
(`topic-iris-spoke-labels.md`, `VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-
CORE.md`), a center-parity rule explaining why the void/filled split
recurs, one confirmed genuine bridge (the 7/26/27 filled-center cluster
across three independent docs), one real error found (`topic-iris-
spoke-labels.md`'s "void center" mislabel on that same 27), and an
explicit verdict that the 63/56/504 cluster remains unbridged. Also
covers a follow-up on four distinct "5-of-7"-shaped structures and a
bit-bookend-vs-heartbeat-sequence check. Not duplicated here — read
that file for the full result.

#,,,.,,,,,...,,,,,,,,,...,,,.,,,,,,,.,,.,,..,,..,,...,...,...,.,.,..,,.,,,.,,,
#NJDMDIKXJ7B55PKEDBBMGCEYDGXU2SZQ477FAP2M2ULFXBHLUNYS4Z3BGQXPZWVBWSSR53INN4GDO
#\\\|MWJ6UJNDUJFNENAMITH6A4WHMVLBEMESLSOYIAPW6GHNC762LHT \ / AMOS7 \ YOURUM ::
#\[7]X2ET3K2FYQ3YU7SG4JIPPMDTON2DOQ3UOG5WITUXL25J5754JQCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
