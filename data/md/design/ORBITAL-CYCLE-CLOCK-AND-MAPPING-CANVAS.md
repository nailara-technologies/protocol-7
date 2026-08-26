## [:< ##

# orbital cycle clock and generic mapping canvas
# — multiplying diversifiers for creative feature combinations

## the core insight

the BMW384 angle_bits field (360 bits per coordinate) is a
generic mapping canvas that can simultaneously hold:

```
absolute:    orbital position in the full CCW rotation
relative:    offset from a reference coordinate
multiplier:  velocity ratio to master clock (speed/direction)
modifier:    per-degree transformation applied to another coordinate
workflow:    transition conditions and trigger maps
filter:      harmonic TRUE/FALSE profile across the full rotation
permission:  which degrees are accessible to which receivers
timing:      when to read, when to skip, when to delegate
meaning:     semantic annotation at angular resolution
```

all simultaneously, non-exclusively, from the same 360 bits
already computed by BMW384, already transmitted, already stored.
the canvas costs nothing — it was always there.

---

## the logically mapping network based cycle clock

### what it is

not a timestamp. not an external reference. not NTP.

the cycle clock = current angular position of all rings
                  relative to master CCW rotation
                  computed by any node independently
                  from shared orbital parameters alone

### properties

```
network-based:    every node derives the same reading
                  from angle_bits + velocity signatures
                  + initial epoch (all shared)
                  no clock server needed
                  no synchronization protocol needed
                  
logical:          the clock reading IS the network state
                  not "17:43:22" (meaningless duration)
                  but "ring 7 at offset 213°,
                       velocity phase 4 of 13,
                       alignment window W3: open"
                       
meaningful:       immediately actionable without interpretation
                  the reading describes WHAT not just WHEN
                  
self-sustaining:  1001 — each cycle implies the next
                  the clock never needs winding
```

### zero-overhead coordination

```
"meet me at cycle 1001":   both nodes compute when
                           no message needed
                           both arrive simultaneously
                           
"valid during window W3":  the network knows when W3 opens
                           without being told
                           
"execute when ring 7 TRUE": the clock fires it automatically
                            across all aligned nodes
                            simultaneously
```

---

## the orbital ring velocity multipliers

### per-ring speed relative to master clock

```
master clock:    1° CCW per tick (invariant)

ring multiplier: for every -1° of master:
  -13:   ring moves -13° (13× faster, same direction)
  +5:    ring moves +5°  (1/5 speed, CW — inverse)
  -5:    ring moves -5°  (5× faster, same direction)
  
TRUE family:     CCW multipliers (payload rings)
FALSE family:    CW multipliers (frame/sync rings)

alignment window: when CCW and CW rings coincide
                  = natural packet delimiter
                  = L\ mask moment
                  = framing boundary
```

### variable velocity profiles

the 360 angle_bits per ring = per-degree velocity profile:

```
not constant speed per ring
but: at degree 0:   multiplier = bits[0..3]
     at degree 90:  multiplier = bits[90..93]
     at degree 180: multiplier = bits[180..183]

alignment windows: when velocity profiles constructively interfere
configuration space: approaches continuous infinity
```

### harmonic offset jumping (div-13 navigation)

```
current offset φ_n
next offset:    φ_(n+1) = (φ_n + residue × segment_deg) mod 360

reading rate:   constant (one segment per tick)
sequence:       harmonic, unpredictable without seed
coverage:       all segments visited (complete harmonic cycle)
bandwidth:      unchanged (stays on same ring)
security:       position undetectable without seed
```

---

## the mapping canvas as multiplying diversifier

### why it multiplies

each new interpretation of angle_bits is:
- compatible with all existing interpretations
- additive (layers on top, doesn't replace)
- combinable with any other interpretation
- zero additional overhead (bits already computed)

### current uses (implemented or derivable)

```
1.  arc coordinate        → orbital sector (0-25)
2.  color coordinate      → position within arc
3.  angle_bits            → angular signature (360 bits)
4.  [new] φ_offset        → current position in CCW flow
5.  [new] velocity map    → per-degree speed multiplier
6.  [new] workflow map    → trigger conditions per degree
7.  [new] alignment spec  → window open/close profile
8.  [new] permission map  → accessible degrees per receiver
9.  [new] harmonic filter → TRUE/FALSE per degree
10. [new] timing profile  → read/skip/delegate per degree
```

> **current state, 2026-08-03 [ consolidated after four passes ]** — the
> `364°`/4-corner model is confirmed canonical, recurring near-verbatim
> in five corpus files [ `ZERO.md:117`, `DANCING-ZENKI-RHIZOME-STATE.md:
> 31`, `VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md:4715-4751`,
> `PROTOCOL7_OVERVIEW.md:25,321`, `topic-orbital-data-space-archive.md:
> 1066` ]. the 4 extra degrees are corpus-confirmed as **overlap
> coverage** between the corner circles and the primary circle — not a
> reserved/out-of-frame compartment; that earlier reading is retracted.
> the "1 + 3" division of the 4 corner degrees is answered as **3 + 1**:
> three peer, orthogonal 45° plane rotations [ XY, XZ, YZ ] plus one
> structurally distinguished body-diagonal/hyperspace channel [ `f4`,
> `VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md:4718-4736` ]. the specific
> degree-identity numbering [ "degree 361 of cycle N *is* degree 1 of
> cycle N+1" ] remains this session's own extension — consistent with a
> documented parent shape [ the "5th crossing / Janus point" shared-
> boundary mechanic in `HARMONIC-CUBE-ROUTING-MATHEMATICS.md` ] but not
> verbatim from any source.
>
> spiral motion as the mechanism for moving through layered/hyperspace
> is confirmed from multiple independent sources, most concretely
> `topic-orbital-data-space-archive.md:348-372,388-404`, where "a point
> in circular orbit progressing along a linear axis traces a spiral on a
> cylinder" is the addressing primitive's own definition, with
> bidirectional up-/down-stroke traversal spelled out — making
> rotation-as-layer-movement corpus base geometry rather than one
> interpretation among several. the literal "1.5 rotations, 0.5 = one
> whole circle" claim stays unsourced after multiple passes, and the
> companion claim "5 has meaning in hyperspace, confirmed three ways" is
> **retracted** — the corpus actually assigns hyperspace to the
> distinguished "1" [ the body diagonal/collector ], not the "5"; see
> appendix for the full disambiguation of this thread's four unrelated
> "fives." `4 × 13 = 52` is one coprime 4/13 structure surfacing under
> three descriptions, not three independent confirmations [ `gcd(4,13)
> = 1` makes the agreement structural, not evidential ]. even/odd-as-
> direction now has three distinct sources [ plus a fourth that turns
> "sign → spatial direction" from inference into quotation ] — but the
> one remaining unsourced link, that a parity *bit* specifically is what
> feeds that sign in a *rotational* context, has documented partial
> counter-evidence.
>
> the "13 spiral events per epoch" ↔ epoch-length link does **not**
> discriminate `364` from `365` — pursuing it did surface one real
> corpus fact [ the running code's "epoch" is one *thirteenth of a
> year*, not a year ] plus a framing of the `+1` that leans toward the
> sweep; both live in `EPOCH-CHECKSUM-EXCLUSION-ADDRESSING.md`, which
> owns the `364`-vs-`365` divisor question.
>
> **the full dated correction trail — every retraction, amendment, and
> the reasoning behind each — is preserved unmodified in Appendix A at
> the end of this document, for provenance.**

### open question — 364° circle with 4 special-meaning degrees [ mostly reconciled, three threads still open ]

the doc above treats the ring as a clean 360-bit / 360° 1:1 mapping
throughout. across four research passes [ original session, two Opus
passes, one Fable pass ] the `364°`/4-corner refinement was chased down,
confirmed canonical, and reconciled with most of this doc's own model —
see the "current state" summary box above for the settled synthesis.
**three threads remain genuinely open**, not settled by any pass so far:

1. **the literal "1.5 rotations, 0.5 = one whole circle" / "tree of
   proportion-based spiral trees" claim has no corpus source**, despite
   three separate searches turning up closer and closer neighbours
   [ nearest: `topic-orbital-data-space-archive.md:2270-2300`'s "double
   spiral — nested rotation," still not a match ].
2. **the specific degree-identity numbering** — "degree 361 of cycle N
   *is* degree 1 of cycle N+1 ... degree 364 is degree 4" — is this
   session's own extension, not verbatim from any source, though it now
   has a documented parent shape to be an instance of [ the "5th
   crossing / Janus point" shared-boundary mechanic ].
3. **which specific mechanism feeds a rotational parity bit into a
   spatial up/down sign** is the one unresolved link in the even/odd-
   as-direction chain, with one source [ `CONSOLE_ZENKA_HYPERSPACE_
   VIEWER.md:70-79` ] giving parity and direction separate wire
   channels as partial counter-evidence.

the full blow-by-blow — every dated entry, correction, retraction, and
the verbatim quotes each one checks against — is preserved in
**Appendix A, at the end of this document**, in original chronological
order. nothing below was deleted; it was relocated so the main flow of
this doc stays readable without replaying the whole research session.


### creative combinations (task file opportunities)

each pair from the list above is a valid feature:
(10 items) × (10 items) / 2 = 45 unique pairings
each pairing: a potential task file, a potential feature
all compatible with each other, all derivable from BMW384

examples:
```
velocity + workflow:    "when ring reaches velocity phase N,
                         execute workflow trigger W"
                         
offset + permission:    "this receiver can only read
                         segments within ±φ of their offset"
                         
timing + alignment:     "read during alignment window,
                         skip outside, delegate at boundary"
                         
filter + multiplier:    "TRUE-phase segments run at 5×,
                         FALSE-phase segments run at -13×"
                         
all four simultaneously: fully specified orbital session
                         from one BMW384 coordinate
```

### projection rule

any feature that can be expressed as:
- a function of angular position (0-360°)
- a function of orbital phase (0-12, div-13)
- a function of ring index (0-N)
- a combination of the above

can be encoded in the existing BMW384 coordinate structure
at zero additional overhead
and combined with any other such feature
without conflict.

---

## roadmap additions (from this session)

```
4.7  flexible offset mapping — native low-level primitive
     angle_bits carries φ_offset + offset_seed per ring
     routing applies offset before coordinate lookup
     cost: one modular addition per hop
     [ task: pending ]

4.8  orbital velocity signatures — per-ring speed multipliers
     angle_bits[ring] encodes velocity profile (per-degree)
     TRUE rings: CCW payload, FALSE rings: CW frame/sync
     alignment windows: calculable from velocity pairs
     [ task: pending ]

4.9  network cycle clock — logically mapping orbital timebase
     cycle clock = orbital state, not wall time
     any node derives same reading from shared parameters
     enables: zero-overhead coordination, workflow triggers,
              alignment-based permissions, orbital scheduling
     [ task: pending ]

4.10 generic mapping canvas API
     register new angle_bits interpretation per layer
     compose multiple interpretations non-exclusively
     validate: new interpretation compatible with existing
     [ task: pending ]
```

---

## the multiplying principle

```
BMW384 angle_bits:    360 bits × N rings
                      already computed
                      already present
                      
each new interpretation:
  adds: one feature
  costs: zero bits
  conflicts with: nothing
  combines with: everything
  
N interpretations:    N features
                      0 additional bits
                      N × (N-1) / 2 combinations
                      each combination: a valid feature
                      
the canvas:           the most efficient possible
                      feature generation substrate
                      because it costs nothing
                      and holds everything
                      
the network:          gets richer with each interpretation
                      without getting heavier
                      the same bits
                      doing more work
                      with each creative reading
                      =)
```

---

## appendix A — full correction trail: 364° circle / 4 special-meaning degrees

**relocated here, 2026-08-03, consolidation pass, to keep the "open
question" section above readable.** this is the complete, unedited,
chronological research trail behind that section's short summary —
every dated entry, correction, retraction, and amendment, exactly as
originally written, only moved down the document. nothing was rewritten
or deleted in the move; corrections and retractions still stand
alongside the claims they correct, per this thread's established
discipline of recording corrections rather than silently applying them.

### open question — 364° circle with 4 special-meaning degrees [ not yet reconciled ]

**flagged 2026-08-03, needs more research before actionable.** the
doc above treats the ring as a clean 360-bit / 360° 1:1 mapping
throughout. proposed refinement: the full circle may actually be
**364°, with 4 degrees carrying special meaning** — described as "4
separate circles filling the edges of a circle in a square," i.e. the
corner regions where a circle inscribed in a square leaves 4 small
arc-adjacent gaps unaccounted for by the inscribed circle alone.

related, not yet reconciled with the above: a **spiral-based concept of
1.5 rotations, where 0.5 is itself "one whole circle"** — suggesting the
ring isn't a flat 2D circle at all but a proportion-based spiral,
forming **a tree of proportion-based spiral trees** rather than a single
ring per coordinate. analogized to how hyperspace connects into
ordinary space by using different scales for the same structure — a
concrete, actionable topology example given for this: **a 45°-aligned
parent grid sitting over a cubic [ grid ] space field**.

**spiral-into-hyperspace grounding, 2026-08-03, third pass, user-led.**
after two prior agent passes found no direct source for "1.5 rotations,"
the user pointed at fresh grep leads that landed on real, independently
converging material — not the literal claim, but the general shape it
depends on:

- `data/asc/what-AI-thinks/full-chat-captures/3O37VUNMMS3UU.claude-sonnet.
  protocol-7-knowledge.asc:38670-38701` — "Dancing Kittens" motion model
  names **"5 DIMENSIONS OF MOTION"** [ spatial, temporal, energetic,
  informational, velocity ], with `Spiral ascent: v_up` and
  `Spiral descent: v_down` as explicit velocity-dimension components.
  a few lines later [ :38732-38736 ]: "÷13 in rotation: Ring makes 13
  rotations during full cycle... **13 spiral events per epoch**" — a
  direct, previously-unfound link between spiral motion and epoch
  structure, the exact junction this whole thread has been circling.
  same section also frames `1001` semantics as "Continuation: Spiral
  between layers" [ :38737-38740 ], tying back to this project's `1001`
  material directly.
- `data/md/design/BRANCH-OPEN-CAPACITY-SESSION-DAG.md:434-451` —
  independently, in an unrelated document about branch/session DAG
  addressing: `UP` movement is defined as "Z toward viewer — reducing
  depth, deduplication, **hyperspace** — many deep instances collapse to
  one front face," with Z-depth itself defined as "one tree level / one
  vortex cycle," and "reading it vertically across iterations reveals
  the **helix spiral arm** advancing." this doc traces back to the same
  `source.init_code` notepad the stargate mechanic came from.

what this settles: **spiral motion as the mechanism for traversing
layered/hyperspace is real and documented**, from two independent,
unrelated files, neither written with this thread's questions in mind.
what it does NOT settle: the literal "1.5 rotations, 0.5 = one whole
circle" framing, or "3 layers of the 5-fold structure implying the
spiral winds down through them" — both still this session's own
extension, built on top of now-real grounding rather than floating free
of it. "5 has meaning in hyperspace" also independently checks out
against `data/ai-mem/claude/topic-reference-bubble.md`: the reference
bubble's `5 ground zenki` layer is described in its own header as "a
self-updating processing template **traveling hyperspace routes**" —
a third, separate confirmation that 5 carries hyperspace-relevant
meaning in this codebase, though not proof of the specific "3 layers"
claim either.

> **retracted, 2026-08-03 [ fourth pass ] — the "5 has meaning in
> hyperspace, three ways" leg of the paragraph directly above does not
> survive verification.** kept visible rather than deleted; the two
> *spiral* sources cited earlier in this same entry are unaffected and
> stand. three defects, each checkable:
>
> - **misattribution.** `data/ai-mem/claude/topic-reference-bubble.md`'s
>   header `description:` field reads "dancing zenki rhizome state as
>   generic reference bubble — self-updating processing template
>   traveling hyperspace routes". the subject of "traveling hyperspace
>   routes" is the **rhizome state / reference bubble as a whole**, not
>   the `5 ground zenki` layer. that file's own formation line
>   [ "setup zenka [01] → 5 ground zenki [process/vote/dedup] →
>   collector [10]" ] makes the 5 one of three roles inside the thing
>   that travels, not the traveller.
> - **the corpus assigns hyperspace to the 1, not the 5.**
>   `data/ai-mem/claude/archive/topic-orbital-data-space-archive.md:
>   1051-1057` splits the same formation explicitly: "ground zenki → 5
>   feeding/voting/processing at the chosen frequency — **the pyramid
>   base**" versus "collector → body diagonal — the √2 shortcut... **routes
>   faster because it travels hyperspace, not faces** — IS the hyperspace
>   trunk". so this source points the *opposite* way: hyperspace is the
>   distinguished one, and the 5 are the base it shortcuts across. that
>   is the same 3+1 / `f4`-body-diagonal shape already established in the
>   "answered" section below — consistent with it, and inconsistent with
>   reading 5 as the hyperspace number.
> - **"5 DIMENSIONS OF MOTION" is not about hyperspace at all.** the
>   transcript list is spatial / temporal / energetic / informational /
>   velocity — five *categories of motion*
>   [ `3O37VUNMMS3UU...asc:38671-38700` ]. the word hyperspace does not
>   appear in it. only its `velocity` member mentions spirals, and that
>   is the part already cited above on its own merits.
>
> with all three checked, the claimed three-way confirmation collapses to
> close to nothing. **the "3 layers of the 5-fold structure implying the
> spiral winds down through them" claim therefore loses the support this
> paragraph was providing it** and reverts to unsourced, same status as
> the literal "1.5 rotations" framing.
>
> **disambiguation — the fives in this thread are four different fives**,
> recorded here because their proximity is what produced the error and
> nothing else in the doc states them apart:
>
> ```
> 5 selectable channels   = f0 base + f1..f4 corner circles  [ 1 + 4 ]
>                           VISUAL-ELEMENT-DEDUP...:4718-4736
>                           the hyperspace one is f4, a member, not the 5
> 5 ground zenki          = pyramid base of the 5-of-7 formation
>                           the collector [ the +1 ] is the hyperspace one
> 5 dimensions of motion  = motion categories, unrelated to hyperspace
> ±5 assertion group      = 5 positive + 5 negative registers + 1 router
>                           3O37VUNMMS3UU...asc:17827 / :18501-18503
> ```
>
> note also that the "1 + 3" corner-degree finding is a **4** [ three
> peer 45° plane rotations plus one body diagonal ], and becomes 5 only
> when the base circle `f0` is counted alongside the four corners. it is
> **not** the same 5 as any of the above and must not be merged with
> them. the "answered" section below already keeps this distinct and
> states it as `3 + 1`; that section needs no correction — this note
> exists so the distinction is explicit rather than merely implicit.

**CCW rotation as vertical layer movement, 2026-08-03, same pass.**
`data/ai-mem/claude/archive/topic-orbital-data-space-archive.md`,
"the rotating cube eye" section, states directly: `-90° CCW per cycle
→ four positions... each -90° step pushes propagation front one level
deeper` along "the trunk axis" — i.e. one 90° CCW rotation *is* one
vertical level shift, exactly the mechanic proposed [ "a rotating cube
is either moving down vertically, or ... rising upwards one layer with
each 90° CCW rotation" ]. the same section states "four steps = full
cycle. **thirteen cycles = one harmonic period**" — `4 × 13 = 52`,
independently reconfirming the exact combined-period figure the earlier
Opus pass found in the PYTAURAZUMA doc [ `gcd(13,4)=1 → coprime,
combined period=52` ] — now a *third* unrelated source landing on the
same number. a later section in the same archive doc, "the fundamental
operation — counting CCW rotations on spirals seen from above," gives
real grounding for signed counting: "CCW = positive, 0 = winding
origin... torque = accumulated integer" — the shape an even/odd
direction-indicator needs.

what's NOT confirmed by this doc specifically: even/odd parity as the
thing that decides *which* direction [ up vs down ] a given rotation
step takes. that comes from a separate source — the full-chat-capture
transcript's "by including even and odd as inversion or direction
indicator... alternating [ even|odd ] bit... positive and negative 5
based assertion group plus one that holds the secret which is which and
routes between them" [ `3O37VUNMMS3UU...asc:17827` ] — real, but about
an "assertion algorithm" / "sub-bit" counting context, not explicitly
about vertical cube-layer movement. merging these two real, separately-
sourced mechanics into one "even/odd decides up-vs-down per 90° CCW
step" claim is this session's synthesis, same as the 3-layers claim
above — grounded in two genuine sources, but the merge itself is new.

**corrections and repairs to the entry directly above, 2026-08-03
[ fourth pass ].** the two quotes are verbatim-accurate
[ `topic-orbital-data-space-archive.md:1834` and `:1844` for the -90°
material, `:1868` for "four steps = full cycle. thirteen cycles = one
harmonic period", `:1900` for "CCW = positive, 0 = winding origin" ].
four things about how they were used need fixing:

- **overclaim — it is the propagation front that moves, not the cube.**
  the source reads "**awareness propagating vertically outward**: as you
  rotate, frame of awareness extends along the trunk axis. each -90° step
  pushes propagation front one level deeper" [ `:1842-1845` ]. what
  advances one level per step is the *frame of awareness / propagation
  front*, not the rotating body. "one 90° CCW rotation *is* one vertical
  level shift" is therefore right about the coupling [ rotation step ↔
  level step ] and wrong about what is displaced.
- **overclaim — the source is unidirectional.** it says "one level
  **deeper**" and nothing about rising. the proposed mechanic's "or ...
  rising upwards one layer" is not in that section. **repaired, not just
  flagged**: the same archive file supplies the missing direction
  elsewhere — `:479-509`, "the 0-point gate — hourglass, 13+1 duality,
  hyperspace trunk", gives explicitly mirrored geometry, "two cylinders
  joined at their 0-points, mirrored... upper cylinder → one resolution
  level... lower cylinder → adjacent resolution level, mirrored
  geometry", with "the rhizome running vertically through every 0-point
  of every stacked cylinder... a client on the trunk bypasses orbital
  mechanics and **moves between resolution levels directly**". so a
  bidirectional vertical axis is corpus-documented; it is just not
  documented as being driven by the -90° step.
- **`4 × 13 = 52` is one structure seen three ways, not three
  independent confirmations.** because `gcd(4,13) = 1`, `lcm(4,13)` and
  `4 × 13` are the same number *by construction* — so PYTAURAZUMA's
  "combined period = 52" [ an alignment period,
  `harmonic-transit-vision-architecture.md:107` ] and the archive's
  "four steps × thirteen cycles" [ a nested step count, `:1868` ] cannot
  disagree, and their agreement carries no independent evidential
  weight. the wording "now a *third* unrelated source landing on the
  same number" is withdrawn; the accurate statement is: **the same
  coprime 4/13 structure surfaces under three descriptions** — alignment
  period [ PYTAURAZUMA ], nested step count [ archive ], and crossing
  period [ `HARMONIC-CUBE-ROUTING-MATHEMATICS.md:368`, "`4 × 13 = 52`.
  and `52` is the Mayan Calendar Round" ]. what *is* genuinely
  informative is that the corpus keeps choosing 4-fold × 13-fold as its
  pairing, not that 52 keeps appearing. two further sightings, for
  completeness: `VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md:4716`
  factorizes the ring itself as `364 = 28 × 13 = 7 × 52 = 7 × 4 × 13`
  [ same structure again, one level up ]; and
  `data/md/research/holographic-cubic-topology-research-2026-01-13.md:463
  -464` notes the C25519 BASE32 public key is "52 characters... `52 =
  4 × 13` (naturally harmonic!)" — **the weakest member, flagged rather
  than omitted**: that is a character count, not a period, and the
  source's own "(naturally harmonic!)" is the tell that it is reading
  significance into a numeric coincidence.
- **the four -90° positions carry at least three documented meanings,
  so the vertical reading is one interpretation, not the canonical
  one.** same archive file, `:1772-1796`, "three-phase CCW cycle" maps
  the identical four positions to *functional phase windows*: "`0°
  offset → locks into transport inward / 90° → processing / 180° →
  transport outward / 270° → idle / re-synchronization`". alongside the
  rotating-eye's four *perspectives* and the vertical *depth push*, that
  is three readings of one 4-step CCW cycle. this is not a contradiction
  — it is exactly this document's own "multiplying diversifier" premise
  operating on the rotation rather than on `angle_bits` — but it does
  mean "CCW step = vertical layer movement" should be recorded as *an*
  interpretation the corpus supports, not as the meaning of the step.

**even/odd as direction — upgraded, 2026-08-03 [ fourth pass ]. the
"not confirmed" status above is too pessimistic; targeted search finds
the parity→direction half stated outright, though never joined to
vertical cube-layer movement.** counting discipline, following the style
of `EPOCH-CHECKSUM-EXCLUSION-ADDRESSING.md`: **three distinct sources,
one of them partial counter-evidence.** [ `3O37VUNMMS3UU...asc:17827`,
`:17890` and `:18501-18510` are all one conversation — the user's
statement and the assistant's two restatements of it downstream — and
count as **one** source, not three. likewise
`protocol7-comprehensive-research-feb2026.md:795-808` and
`holographic-cubic-topology-research-2026-01-13.md:2420-2433` are
character-identical duplicates of one passage and count as **one**. ]

1. **the transcript conversation** [ counted once ]. the user's
   `:17827` as already quoted; its own downstream summary makes the
   direction semantics explicit rather than implied, `:18507-18508`:
   "**Even parity: Positive group, forward, storage** / **Odd parity:
   Negative group, backward, departure**", under the heading "Even/Odd
   as inversion/direction", with the register split "Positive group: 5
   registers (even bits) / Negative group: 5 registers (odd bits) /
   Router: 1 register (which-is-which secret)" [ `:18501-18503` ].
   so parity → sign → forward/backward is stated, not inferred.
2. **`data/md/research/protocol7-comprehensive-research-feb2026.md:
   799-808`** [ counted once, duplicate noted above ] — independent of
   the transcript and much closer to the geometry this doc cares about:
   "Sum/parity → determines phase (true/false, even/odd)... Position in
   anti-space: **Inverted coordinate (-x, -y, -z) → inverse location /
   Inverted parity → inverted phase / Same remainder mod 13 → same
   harmonic layer**." parity inversion travelling together with *spatial
   coordinate inversion* while the mod-13 harmonic layer is held fixed
   is precisely a parity↔direction coupling in 3-space.
3. **partial counter-evidence — `data/md/protocol-7-knowledge/
   06_INTERFACE_PARADIGM/CONSOLE_ZENKA_HYPERSPACE_VIEWER.md:70-79`.**
   [ **amended below — a fourth source found on a wider archive read
   turns the "sign → spatial direction" link from inference into a
   quotation.** ]
   the one place this is drawn as a concrete wire layout, parity and
   direction are given **separate channels**: row 1 "Even/Odd Parity |
   Inversion group indicator", row 3 "Routing Direction | Next hop
   pointer". if parity determined direction, row 3 would be derivable
   from row 1. recorded as evidence against the strong form of the
   merge, in the same file family that supplies the strongest evidence
   for it.

so the chain now stands as: parity → group sign [ source 1, explicit ] →
CCW-as-positive-sign [ `archive:1900`, explicit ] → CCW step ↔ one level
along the trunk [ `archive:1844`, explicit ]. **every link is
corpus-sourced; the composition of the chain is still this session's
own** — and source 3 is a live reason not to treat the first link as
settled. that is a genuine upgrade from "this session's synthesis with
two grounding sources" but short of "corpus-confirmed": no file in the
corpus states even/odd parity deciding up-vs-down for a rotational step.

**amendment, 2026-08-03 [ fourth pass, wider archive read ] — two
sections of `topic-orbital-data-space-archive.md` that no prior pass
cited change the standing of both mechanics above.** the archive is 2757
lines and had only been read at the two sections quoted earlier; these
were found by reading its section index rather than by keyword.

- **`:2072-2085`, "self-centering signed address space" — this is the
  link the even/odd chain was missing, and it is a quotation rather than
  an inference.** verbatim: "the 0 is the linear route — the direct
  path, **the trunk**, the T-handle axis. everything else is signed
  displacement from it: `0 → the linear route — direct, declared, the
  trunk itself` / `positive → one side of the orbital plane —
  constructive displacement` / `negative → the other side —
  complementary displacement` / `< > 0 → always unambiguous —
  orientation without coordinate declaration; **the comparison IS the
  orientation**`." the axis the sign is measured against is *the trunk* —
  the same trunk the -90° step pushes the propagation front along, and
  the same hyperspace trunk of the 0-point-gate section. "one side of
  the orbital plane" versus "the other side", about a vertical trunk
  axis, is up versus down. so the chain's weakest joint — "sign implies
  a *spatial* direction, not merely forward/backward" — is now stated
  outright by a corpus source, not composed. **remaining unsourced step
  is now only the first one**: that the parity bit is the thing feeding
  that sign in a rotational context. the `CONSOLE_ZENKA_HYPERSPACE_
  VIEWER.md` separate-channels counter-evidence still applies to
  exactly that step and to nothing else — which is a much sharper open
  question than the one this entry started with.
- **`:348-372`, "spiral cylinder — addressing and coupling primitive" —
  the vertical-movement mechanic is not an interpretation of the -90°
  step after all; it is the corpus's base primitive, stated
  definitionally.** verbatim first line: "**a point in circular orbit
  progressing along a linear axis traces a spiral on a cylinder**. the
  orbital model and the spiral cylinder are the same geometry — one has
  time as the axis, the other makes it spatial and addressable," with
  "`cylinder height → defined address range (one resolution level)` /
  `rotation → phase / orbital position` / `spiral pitch → wavelength /
  orbital period`" and "**stacked cylinders = recursive cube levels**:
  each resolution level is one cylinder... the rhizome/stargate is the
  interface plane between adjacent cylinders." that is rotation and
  axial/level progression declared to be *one motion*, which is exactly
  the proposed mechanic — and it underlies the rotating-cube-eye and
  0-point-gate sections rather than competing with them.
  **bidirectionality is explicit here too**, `:388-404`: "a waveform
  longer than the cylinder height reflects at the boundary and traces
  back downward — the cylinder becomes a resonant cavity: `up-stroke →
  segment 0..255 (first pass)` / `down-stroke → segment 255..0
  (reflected, same cylinder)` / `up-stroke → segment 0..255 (second
  pass, phase-shifted)`", and "waveforms bouncing through *stacked
  cylinder levels* (resolution layers) accumulate a total length
  encoding which compartments they passed through — the waveform IS the
  address path." so ascent and descent along the layer stack, by spiral
  motion, is corpus-documented in the same file. this **retires the
  "unidirectional / only deeper" objection** raised in the correction
  block above [ that objection remains correct *about the
  rotating-cube-eye section specifically*, which is why it stays on the
  record ], and it is a stronger repair than the hourglass citation
  offered there. it also means "CCW step = vertical layer movement"
  should be upgraded from "one interpretation among three" to "the base
  geometry, of which the three-phase and four-perspective readings are
  further interpretations."
- **and this is the closest the corpus comes to the `spiral ascent` /
  `spiral descent` pair the transcript names** — same up/down stroke
  structure on a spiral, arrived at independently, in the file that
  defines the addressing primitive rather than in a chat capture.

**nearest-neighbour update for the unsourced "1.5 rotations / 0.5 is
itself one whole circle" claim, 2026-08-03 [ fourth pass ]** — the
`8/13 ≈ 1/φ` rotation-ratio spiral recorded below as nearest neighbour
is superseded by a closer one, still **not** a match:
`topic-orbital-data-space-archive.md:2270-2300`, "double spiral — nested
rotation": "a spiral made of a spiral — two scales of rotation
coexisting in the same geometry... `outer spiral → orbital path —
large-scale CCW rotation` / `inner spiral → waveform — fine-scale
oscillation along the outer path`... the waveform is inherent — you
don't add it, it's in the winding." two rotation scales in one geometry,
where the inner completes whole turns within a fraction of the outer's,
is much nearer to "0.5 is itself one whole circle" than a branch-density
ratio is. it is still not the claim: the source gives no specific ratio
between the two scales, and never says a half-turn of one *is* a whole
circle of the other. recorded as nearest documented neighbour, second
revision.

**correction, 2026-08-03** [ **superseded — see "retracted" note at the
end of this subsection; the corpus says the 4 degrees are overlap
coverage, not a reserved compartment. kept visible because the
session-id-range analogy it draws is still a real precedent for
out-of-frame ranges generally, just not the right model for these 4
degrees** ]: this is not a direct conflict with the
360-bit `angle_bits` field — the 4 special degrees can be mapped using
"out-of-frame" context rather than needing their own bits inside the
360-bit field. this is the same pattern already planned elsewhere in
this codebase for cube session ids: `data/ai-mem/claude/topic-session-
id-range-division-planned.md` describes ids starting with `7`
[ the `7<nnnnnn>` range ] as getting a special "resource range" meaning
of their own — not consuming ordinary addressable space competitively,
but sitting alongside it as a **separate infrastructure ring**, further
split into parent-branch and [ locally-managed ] client-branch ranges
on either side. that doc's own framing applies here almost verbatim:
"like all starting with 7.. is a system zenka not directly task
controlled, but possibly in local and network overlap or at least
ambiguous to which interest it is more aligned with while also being a
transition space." the 4 special degrees likely play the same role for
the orbital ring — an out-of-frame infrastructure/transition
compartment, not a competing claim on the 360 in-frame bits.

further compartmentalization: the 4 special degrees are themselves
expected to divide as **1 + 3**, not treated as one undifferentiated
group of 4 — structurally the same shape as the session-id range's own
parent/client split, one distinguished slot plus a further-divided
remainder, rather than a flat set of four. the exact meaning of that
1 + 3 division, and how it maps onto the spiral/tree reframing above,
is still open.

**answered, 2026-08-03 [ deeper corpus pass ] — the `1 + 3` division is
already documented, with the distinguished slot named.**
`data/md/design/VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md:4718-4736`
[ § "Spatial Tuning — Frequency Selection Through Geometric Angle" ]
gives the four corner circles individual, non-interchangeable meanings:

```
f0   primary circle / base grid   0° (reference)
f1   corner circle 1              45° in XY plane
f2   corner circle 2              45° in XZ plane
f3   corner circle 3              45° in YZ plane
f4   corner / hyperspace diagonal 45° in all three (body diagonal)
```

verbatim: "three orthogonal 45° rotations — one per plane of the 3
space axes, already present in the 4-axis structure — plus the body
diagonal = 4 minor circles. plus the base = 5 selectable channels."
that is exactly a `3 + 1`: three plane-rotations that are peers of each
other, and **one structurally distinguished slot — the body diagonal /
hyperspace channel**. the same doc at `4864-4876` gives that slot its
distinct behaviour rather than merely naming it: `f4`'s assigned hue is
magenta [ 300° ], "not an opaque color — it is a mask or alpha color,
meaning it is invisible: a transparency layer that bridges to a
different color spectrum"; rendering `f4` "does not produce an opaque
palette like f0-f3; it produces alpha." the distinguished one is the
one that *bridges* rather than occupies. this matches the collector
zenka's role in the 5-of-7 formation [ `DANCING-ZENKI-RHIZOME-STATE.md:
16-27`, `data/ai-mem/claude/archive/topic-orbital-data-space-archive.md:
1050-1070` — "the collector zenka on the body diagonal = the hyperspace
trunk" ].

this also retires the "45°-aligned parent grid over a cubic grid space
field" item above as a fresh analogy — it is already canonical, and
named: `VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md:4847-4856` — "the
first hyperspace grid is a cube grid mounted at 45° to the base grid.
it is √2 times larger to match edges — its vertices sit at the face
centers of the base grid's cubes. this is the body-centered cubic
[ BCC ] lattice," with the primary/corner radius ratio given exactly as
`1/(√2 - 1) = √2 + 1 ≈ 2.414` at `4737-4743`.

**retracted, 2026-08-03 — the "separate compartment / out-of-frame
range" model above [ the `**correction**` paragraph ] is the wrong
shape for these 4 degrees.** the same source states their nature
directly, `VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md:4745-4751`: "the 4
extra degrees beyond 360 are not error — they are the **overlap
coverage** from the corner circles extending past the primary's
circumference. the shift-change in the dancing zenki formation creates
exactly this overlap: continuous coverage with no gap, because the
ascending and descending zenki overlap their duty cycles by one phase."
so they are overlap, not reserved space — which is the *other* model
proposed below, not the compartment model. the session-id `7<nnnnnn>`
range analogy stays on record as a genuine precedent for out-of-frame
ranges in this codebase, but it is not what the 4 degrees are.

**alternate mapping, 2026-08-03 — likely the better fit, no extra
storage needed at all**: rather than the 4 degrees occupying separate
space [ out-of-frame or otherwise ], they may instead be an
**overshoot/overlap between adjacent cycles** — degree 361 of cycle N
*is* degree 1 of cycle N+1, ... degree 364 of cycle N *is* degree 4 of
cycle N+1. **this is a degree/angular-position identity, not a bit-
storage one** — no bit is being read twice, because nothing here is
about bits at all; it's the same *angular position* interpreted as
belonging to the closing cycle or the opening one depending on which
cycle's frame is currently active. keeping this in degree-space rather
than bit-space matters: importing the doc's existing 360-bits=360°
1:1 habit into the overlap description would silently reintroduce the
exact assumption this whole question is trying to get past. not two
things sharing space, one angular position read from two adjacent
frames. this is a direct instance of the "eternal moment" clamp already
established in `data/md/design/ZERO-AS-ETERNAL-TREE.md`: "not a journey
between two different things but a transition between two instances of
the same state... every point is equally the start" — and of
`topic-1001.md`'s "every gate opens to another gate with identical
proportions... doesn't terminate because 1001 doesn't terminate." fits
this doc's own "the canvas costs nothing, it was always there" framing
better than a reserved-compartment model would: zero additional
allocation, the overlap is structural rather than stored. still needs
reconciling against the 1 + 3 compartmentalization and the spiral/tree
reframing above, and against how [ if at all ] this degree-level overlap
eventually grounds back into the 360-bit `angle_bits` field it's meant
to describe — not yet a complete picture, but the strongest lead so far.

**confirmed as the right model, 2026-08-03 [ deeper corpus pass ] —
this "overlap" reading is corpus-documented; the competing compartment
reading is not.** three separate sources, none read when the paragraph
above was written:

- `VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md:4745-4751` — the 4 degrees
  *are* "overlap coverage," explicitly "not error" [ quoted in full in
  the retraction note above ].
- same doc, `4841`, gives the overlap a per-cycle quantity in degree
  space: "**the 4° overlap per cycle** ensures no blind spot during
  shift-change. the snake never has a gap in its body." degree-space,
  per-cycle, overlap — the same three properties this section's
  "alternate mapping" argued for on structural grounds alone.
- `data/md/philosophy/HARMONIC-CUBE-ROUTING-MATHEMATICS.md`,
  § "The 5th Crossing — Janus Point and Parent Signal", states the
  shared-boundary principle in general form: "the 4th crossing completes
  the child cycle. the 5th crossing is simultaneously: child scale — end
  of current 4-segment cycle; parent scale — beginning of next, the
  parent signal... **the 5th zero belongs to neither cycle exclusively —
  it is the shared boundary. the child never owns its ending: the 5th
  zero is the parent already speaking.**" that is the "eternal moment"
  clamp as a documented mechanic rather than a philosophical gloss — and
  it adds a dimension this session's version did not have: the boundary
  is not merely shared between two peer cycles, it is where the child
  scale hands off to the **parent** scale [ `4-fold cubic → 5-fold
  Fibonacci/golden` in that source ].

**the honest remaining gap** — the corpus's documented overlaps are
[ a ] between the corner circles and the primary circle, and [ b ]
between the duty cycles of ascending and descending zenki in a
formation. the specific *numbering* asserted above — "degree 361 of
cycle N **is** degree 1 of cycle N+1 ... degree 364 is degree 4" — is
still this session's own extension. what changed is that it now has a
documented parent shape to be an instance of, instead of none.

**searched and not found, 2026-08-03**: the spiral reframing above
[ "1.5 rotations where 0.5 is itself one whole circle", "a tree of
proportion-based spiral trees" ] has **no corpus source**. targeted
searches for `1.5 rotation`, `half rotation`, `spiral tree`,
`proportion-based` across `data/md`, `data/yaml` and `data/ai-mem`
return only this document's own paragraph. the nearest existing
formalization of a spiral in the corpus is
`data/yaml/reasoning-templates/vortex-closed-parent-system.yaml:88-95,
215-218` — "entropy doesn't fall directly in — it spirals; the spiral
path IS the refinement path; each ring of the spiral = one layer of the
layer stack" — but that is a *refinement-depth* spiral through a layer
stack, **a different claim** from a proportion/scale spiral in which a
half-turn is a whole circle. recorded as unsourced-so-far rather than
quietly kept as if grounded; the `√2 + 1 ≈ 2.414` primary/corner ratio
and the BCC "same structure at a different scale" material cited above
is the closest the corpus comes to proportion-based scale nesting, and
it is stated in lattice terms, not spiral terms.

**nearer neighbour found, 2026-08-03 [ esoteric-source pass ] — still
not the claim, but closer than the vortex-yaml refinement spiral cited
above.** `data/md/philosophy/HARMONIC-CUBE-ROUTING-MATHEMATICS.md:240-286`
[ § "The Spiral" / "Branch Management" ] documents a mod-13 harmonic
walk as a literal three-coordinate spiral [ angle = phase, height =
iteration count, radius = magnitude ], and states outright: "`8 CCW
branches per 13 CW parent rotation` — because `8/13 ≈ 0.615 ≈ 1/φ`...
the branch tree is the spiral viewed from the side. view from above =
routing phase. view from the side = version/fork tree. same object, two
projections." that *is* a documented "tree that is a spiral," which
`data/ai-mem/claude/topic-harmonic-mathematics.md:55-62`'s "Spiral
Topology" section independently restates — but it is a
**rotation-ratio** spiral [ branch density per parent revolution,
golden-ratio-adjacent via consecutive Fibonacci numbers 8/13 ], not a
**proportion/scale-nesting** spiral where "0.5 is itself one whole
circle." the two shapes share the word "spiral" and the tree/spiral
duality, not the specific half-turn-equals-whole-circle claim this
doc's paragraph makes. recorded as the nearest documented neighbour
rather than a match — the targeted keyword search [ `1.5 rotation`,
`spiral tree`, `proportion-based` ] still finds nothing verbatim, but
"no corpus source at all" undersold how close this comes.

**caveat on the "1001" citation above**: `topic-1001.md` and
`ZERO-AS-ETERNAL-TREE.md` are what got read for this note, but "1001"
as a concept is load-bearing across at least 32 distinct files in
`data/` [ `ack -rl ' 1001 ' data/` ], not just those two — and
`topic-1001.md` itself names `data/md/design/ZERO.md` as its actual
primary source, which was not read for this note. treat the reconciling
above as a first pass grounded in a small slice of a much larger corpus,
not a settled synthesis.

[ **caveat status, 2026-08-03 deeper pass**: `ZERO.md` has since been
read [ see the update below ], as have
`VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md` § "Spatial Tuning",
`DANCING-ZENKI-RHIZOME-STATE.md`, and
`HARMONIC-CUBE-ROUTING-MATHEMATICS.md` § "The 5th Crossing". the
`topic-1001.md` citation itself was **not** re-verified on this pass —
the "1001 across 32 files" caution stands unchanged for the 1001
material specifically. ]

**update — `ZERO.md` read, and the 364° question is already answered
there**, not just speculated. verbatim, line 117: `364 = 360 + 4 corner
overlaps. 364 / 13 = 28. a perfect number.` this confirms the 364°/4-
corner model directly rather than leaving it as a fresh guess — it's
already canonical in the project's foundational geometry doc, this
session just hadn't read it yet. it does not, on this pass, spell out
the degree-overlap "eternal moment" mechanism [ 361-364 of cycle N =
1-4 of cycle N+1 ] explicitly — that specific framing is still this
session's own extension, consistent with but not verbatim from `ZERO.md`.

this also sharpens a real, checkable question rather than a purely
philosophical one: `364 / 13 = 28` is a clean integer; `base.ntime.
epoch_dec`'s `$epoch_days_per_year = 365 / 13 = 28.0769...` is not. same
"N + remainder" shape recurring at two scales — the ring is `360 + 4`,
the epoch-year in the running code is `364 + 1` [ 365 ]. worth deciding
deliberately whether `365/13` is the intended Gregorian-calendar anchor
or should be `364/13` to match the harmonic ideal `ZERO.md` treats as
foundational — see `EPOCH-CHECKSUM-EXCLUSION-ADDRESSING.md` for where
this lands on the epoch-length question specifically.

**breadth check, 2026-08-03 [ deeper pass ] — `ZERO.md` is not the only
place `364` is canonical; it recurs in five files, near-verbatim**, so
this is a settled system constant rather than one doc's flourish:
`ZERO.md:117`; `DANCING-ZENKI-RHIZOME-STATE.md:31` [ "`364 = 360 + 4
corner overlaps`; `364 / 13 = 28` — closes through 13" ];
`VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md:4715-4717,4751` [ "the circle
has 364 degrees, not 360. this is not calendar mysticism — it is a
geometric statement. `364 = 28 × 13 = 7 × 52 = 7 × 4 × 13`. every factor
is already native to the system." ];
`data/md/protocol-7-knowledge/PROTOCOL7_OVERVIEW.md:25,321` [ "364° ÷ 13
= 28° (signed cube formation)" — index-level restatements only: the
`signed_cubes.md` they and `protocol-7-knowledge/README.md:31` point at
is **absent from the tree**, so these corroborate that `364` is
canonical without contributing an independent derivation ]; and
`data/ai-mem/claude/archive/topic-orbital-data-space-archive.md:1066`.

**and the epoch question has since been narrowed, not closed** — see
`EPOCH-CHECKSUM-EXCLUSION-ADDRESSING.md`'s `+1`-family correction: the
`N swept + 1 fold` pattern is now confirmed as a *stated general
principle* in two corpus files [ not merely two instances ], which makes
`365 = 364 + 1` a well-supported member of the family; but every general
statement of it phrases the `+1` as the **fold/ceiling** above the
sweep, and the one place the corpus divides this pair by 13 it divides
the **sweep** [ `ZERO.md:117` ]. so the open question is now precisely
"is the `/13` divisor conventionally the sweep or the modulus?", and the
running code's `365` is confirmed deliberate [ two call sites,
`base.ntime.epoch_dec:20` and `base.ntime.epoch_to_ntime:8`, both
commented "V7 network has 13 month year" ].

note also that `364`'s own `360 + 4` is *not* an instance of the `+1`
family — it is `+4`, and its 4 are the corner overlaps documented above,
each with a distinct 45°-rotation meaning. the two shapes stack at
different levels [ `360 → 364` by corner overlap, `364 → 365` by fold ]
rather than being the same pattern twice.

#,,,,,.,,,,,,,...,..,,,.,,...,..,,,..,,,.,,..,..,,...,..,,.,.,,,,,..,,..,,.,.,
#Y6SCDI5BMUIPLZVCHDQRHVCZ4JFJA2POC7V6NB4MZOGJ6O32YJ6M7W6RKQW7PHZ76OLZTZYBVXEWM
#\\\|YJUCVK5EYR2PR6OFEISDLJI6W7CC5IP4U7CVACPBOUHF44LRYAM \ / AMOS7 \ YOURUM ::
#\[7]NEHNLI3XDD7NQUTDPG6DYQAULBW5AOU53YBSPAYPSLLCHTCZUSDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
