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

## status

design reconciliation only — no code, no signing-system changes. leave
this file clean; the signing system adds the real footer on commit, per
litter-row-encoding.md's own "signatures note" convention.

#,,,,,.,,,...,,,,,,,.,,..,,..,,,.,...,,,,,,,,,..,,...,..,,,,.,...,,,.,.,,,...,
#65IVBL3ALVAT3OZ6OIF5ATYHZZZY6HSVHPUE35U3SCWROGJTBDHMJ4SDZSLPMKUXGYULFFND7MFLU
#\\\|Z4JDRRGOAUVMSOLOPXPV6Z3HVVKVQ535K4G7LDBY3EENN7C7N3Q \ / AMOS7 \ YOURUM ::
#\[7]TGWUNWQVHB4PH4NTP7AVSHHJDD6F2S2GU3RD4EPRDQ2EMY2VYQCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
