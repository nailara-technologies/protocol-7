---
name: checksum-parenting-namespace-trees
description: checksum auto-parenting (<C0>:<C1> where C0=chksum(<C1>:<name>)) as collision protection for namespace trees; user-trunk/transit-ring/parabolic-mirror topology riff; -nest truth-harmonization fix + mutual-harmonization anonymization + BMW384-style third-checksum fast-reject + epoch_v7 layered resolution
metadata:
  node_type: memory
  type: project
  originSessionId: 9ecacc19-6948-4beb-892e-5af7d7d24068
---

## Checksum auto-parenting (2026-06-11)

Core mechanism: `<C0>:<C1>` where `C0` = AMOS checksum of `<C1>:<name>`.

- `<C0>:<C1>` is collision-protected as long as `<name>` is also known (or
  guessable) for verification — a collision in `C0` would require the SAME
  `name` too, but then it's already the same input value, so it's not a
  collision at all.
- This makes checksum auto-parenting a **collision-protection mechanism for
  an entire namespace tree**, as long as the entry-level constraint holds:
  every entry has a `name`, never *only* a checksum.
- This is also "perfect... in terms of sorting work saved" — the
  parent/child checksum relationship is derivable, not stored/sorted
  separately.
- Relates to [[checksum-based-universal-addressing]] (AMOS7 checksums as
  universal routing primitive) and [[addressing trinity]] (name + checksum +
  timestamp) — this adds a *recursive parenting* relation on top of the
  checksum axis specifically, using `name` as the disambiguating anchor at
  every level.

## User-trunk / transit-ring / parabolic-mirror topology (2026-06-11, same riff)

- Multiple trees, each with a "user trunk" concept.
- User trunk connects to a "transit ring" — this is where routing decisions
  are mirrored/reflected.
- The transit ring behaves like a parabolic-mirror arc: it reflects back
  *behind* the user, rather than routing point-to-point.
- Not yet elaborated — captured verbatim for later folding together with
  the checksum-parenting mechanism above. Likely connects to the "mirror
  principle" / "route as symmetry condition" material in
  [[checksum-based-universal-addressing]] (BMW384 section: "route is not a
  stored path, it is a symmetry condition between two field regions... mirror
  point is in the field between endpoints").

## Tree root = COMMON root of encoded prev/current/next epoch (2026-06-11, revised)

Revised from the first formulation below: the native root of the
protocol-7 tree is not *an* encoded epoch timestamp, but the **common root
of the three encoded epoch timestamps** (previous/current/next) from the
rolling epoch window ([[topic-addressing-trinity]] "Rolling Epoch Validity
Window").

User-supplied reference, existing `cube` zenka commands:

```
.: 'cube' zenka commands :.

epoch-num [prev|curr.|next] [n] __ return current [\requested] V7 epoch time
epoch_v7  [epoch-num] _____________ encoded V7 epoch timestamp [current or req.]

epoch-num prev  -> 311
epoch-num next  -> 313

epoch_v7 313  -> <V7L36RQ;;;:>
epoch_v7 311  -> <V7L36SA:;::>
_
```

- `epoch-num` gives the integer epoch number for prev/curr/next; `epoch_v7`
  encodes a given epoch-num (or current, if none given) as the `V7...`
  base32 string — internally the integer is first BER-packed (`pack 'w'`)
  for tightness, then base32-encoded (`encode_b32r`), so the visible
  characters are base32 (matching `$b32_re{5}`) over a BER-packed binary
  payload.
- The **common root** is whatever shared prefix/structure the encodings of
  311/312/313 share — since epoch numbers are sequential and the encoding
  is presumably a monotonic/positional encoding, adjacent epochs likely
  share a long common prefix that diverges only in the low-order encoded
  digits. That shared prefix IS the tree root for the current rolling
  window.
- This makes the tree root itself a **rolling, three-epoch-wide quantity**
  — not a fixed point. As the window rolls (epoch advances), the root
  itself shifts, but by definition always covers exactly the
  prev/curr/next triple. Same overlap-without-cliff property as the rest
  of the rolling-epoch design, now applied to the tree's own origin.
- Still ties to [[checksum-parenting-namespace-trees]] mechanism above: the
  root-of-everything is the ultimate `C1` that all top-level `C0`s parent
  against, and per the mandatory-name constraint, this root needs a
  name too — `epoch_v7` (the command/concept name) may serve as that name,
  with the *value* being the shared-prefix-derived root rather than any
  single epoch's full encoding.
- Trailing `_` in both the original snippet and this one — still
  unexplained, possibly a placeholder/separator or empty-name sentinel for
  unnamed children of the root. Flagged for follow-up.

### open tension: is "common root" actually better, or just a shortcut? (2026-06-11)

User immediately questioned the revision above:

- the common-root (shared-prefix) framing has to be updated just as often
  as the single-epoch version — it doesn't reduce maintenance.
- but it **loses the exact rolling-range center position** (i.e. which
  epoch-num is "current" within the prev/curr/next triple).
- without that center position, you don't know **when to regenerate** an
  index for the new precise root — the shared-prefix value alone doesn't
  tell you whether you're still safely inside the current window or about
  to roll over.
- so: common-root may be a useful **shortcut/derived view** (e.g. for
  fast-reject / coarse addressing, similar to the BMW384 24-bit
  fast-reject prefix in [[topic-checksum-addressing]]), but it should
  probably NOT *replace* the explicit prev/curr/next triple +
  current-epoch-num as the canonical root representation — the triple
  carries strictly more information (exact center position = regeneration
  trigger) than the shared prefix derived from it.
- open question carried forward: is there a representation that keeps both
  — a compact common-root value for fast addressing AND an explicit/cheap
  way to recover "how far into the current window are we" for
  regeneration scheduling? (possibly: store center epoch-num alongside the
  shared-prefix root, rather than trying to derive position from the
  prefix itself)

**partial resolution (2026-06-11)**: common root might just be a
**lower-resolution perspective** on the same triple — not a competing
representation, but a zoom level. Usefulness then depends on context and
direction of usage:
- coarse/outward-facing (fast-reject, cross-tree addressing, "is this even
  in my neighborhood") -> common root suffices, like the BMW384 24-bit
  prefix fast-reject.
- fine/inward-facing (regeneration scheduling, knowing exact center
  position) -> needs the full prev/curr/next triple.
- so both representations coexist naturally as different zoom levels of
  the same underlying triple, rather than one superseding the other —
  consistent with the project's general pattern of progressive
  narrowing/hierarchical resolution (see BMW384 "hierarchical routing:
  coarse color-range filtering... fine angular resolution only within
  matching segment" in [[topic-checksum-addressing]]).
- concretely: the existing `amos-chksum -L` (shorter-length AMOS checksum)
  flag is plausibly the *literal* mechanism for "lower resolution
  perspective" here — shorter checksums = coarser zoom level, same
  underlying value truncated, rather than a separate derivation. Worth
  checking `bin/amos-chksum` / `AMOS7::CHKSUM::*` for how `-L` actually
  truncates/derives, to confirm whether it composes cleanly with the
  common-root idea above.

### original (superseded) formulation

```
epoch_v7
<V7L36RY::;:>
_
```
Single-epoch version, superseded by the prev/curr/next common-root framing
above — kept for reference since the `V7` prefix observation and the tying
to [[topic-addressing-trinity]] / [[topic-triple-twofish-name-entropy]]
still hold, just applied to the shared root rather than one timestamp.

## Harmonization format history + refinement (2026-06-12)

### why `epoch_v7` is harmonized at all — original goals

The `;`/`:` suffix in `base.ntime.harmonized_epoch` (nonce search 0..12
against `AMOS7::Assert::Truth::is_true`) was never just decoration. Original
goals, now captured explicitly:

- **uniqueness vs. entropic noise in search results**: a harmonized network
  timestamp needs to stand out clearly from other "entropic noise" so it's
  recognizable/greppable as *the* timestamp, not confused with adjacent
  incidental data.
- **"holographic" completeness**: ties to [[topic-hyperspace-topology]] /
  [[topic-field-coherence-synthesis]] — the harmonized value should be a
  complete, self-consistent "frame," not a partial fragment.
- **"harmony" / avoiding "dirty entropy"**: per the project's current best
  understanding, unharmonized/raw entropy has a measurable negative impact
  on the human mind when read; harmonization is partly a *readability /
  wellbeing* property, not just a technical one.
- **direct integration in an "all true" namespace**: the harmonized value
  should be usable as-is inside a namespace where every entry satisfies
  `is_true` — i.e. harmonization is the admission ticket into that
  namespace.

### the refinement still achieves all of these — and fixes two problems

Moving the nonce-search to the parent layer (previous section) and using
**`0`/`1` directly** instead of `;`/`:` as the harmonizing expansion
characters:

- still achieves uniqueness, holographic completeness, harmony, and
  all-true-namespace integration — none of those goals depended on `;`/`:`
  specifically, only on *some* nonce-search-to-truth mechanism existing.
- **fixes horizontal-alignment unevenness**: `;` and `:` have different
  visual weight/width than the surrounding base32/digit characters,
  disrupting horizontal alignment in columnar/tabular displays (ascii
  frames, etc. — see [[topic-ascii-frame-system]]). `0`/`1` are already
  part of the same character class as the rest of the encoded value, so
  alignment is preserved.
- **fixes `:` overload**: `:` is "stolen" from its much more functionally
  important role as the group-boundary separator
  ([[punctuation-topology]], and used throughout this doc's `<C0>:<C1>` /
  `<Ca>:<epoch>:<Cb>` constructions). `0`/`1` carry no such competing
  meaning at the parenting/separator layer.
- `0`/`1` as "closer to native" — directly readable as binary, no
  intermediate symbol mapping required, which also supports the
  "holographic completeness"/"harmony" goals more directly than an
  arbitrary punctuation encoding of the same bits.

### tangent: de-emphasizing classical search engines (2026-06-12)

Broader point raised alongside the above: classical search engines (a)
lack regex support and (b) have increasingly questionable reliability —
both are reasons to **not** design P7's addressing/harmonization formats
around being "greppable by Google," etc.

- protocol-7 instead "natively redefines search into a functional
  expression of multi-dimensionality" — ties to
  [[topic-searchable-index-and-visualization]] (checksum-indexed dataspace)
  and [[topic-namespace-tree-intelligence]] (tree IS intelligence): search
  is a property of the namespace-tree/checksum structure itself, not a
  bolted-on external index.
- framed as: "we are free to provide our working implementations to
  ourselves without waiting for any external paradigm shifts of systemic
  cooperations" — i.e. don't let external search-engine constraints (regex
  support, ranking opacity, etc.) shape internal format decisions like the
  harmonization character set. The uniqueness-vs-noise goal above is about
  P7's *own* search/recognition mechanisms, not external engines.

## Resolution: short epoch_v7 + parent harmonization, no dual-format migration (2026-06-12)

Question raised: current `epoch_v7` returns `<V7L36RY::;:>` (includes `< >`
wrapper AND the `;:` harmonization suffix) — what do we do about old vs
new format, given generation and validation don't have to match
char-for-char as long as the *final* form satisfies the truth template?

**Resolution**: switch `epoch_v7` to emit the short/raw form (drop the
`;:` suffix; `< >` wrapper is orthogonal, can be kept or dropped
independently). Move the 0/1-harmonization nonce search
([[#Harmonization format history + refinement (2026-06-12)]] above) to the
parent/reference-checksum construction layer
([[checksum-parenting-namespace-trees]] `<C0>:<C1>` /
[[topic-triple-twofish-name-entropy]] `<Ca>:<epoch>:<Cb>`).

**Why no dual-format migration is needed**: generator and validator are the
same algorithm family, defined together by the truth template — there is
no independently-meaningful "old harmonized epoch_v7 value" anything needs
to keep matching against. Epoch values are always regenerable on demand
from the epoch number (not stored as opaque long-lived artifacts), and the
rolling 3-epoch window ([[topic-addressing-trinity]]) means nothing
long-lived depends on a past encoding surviving unchanged. This is exactly
"a full state transition... as controlled as work was invested to cover
all transformations" — the next construction of any `epoch_v7`-based
reference simply uses the new chain end-to-end; no branching for
old/new format in code.

## Status update: 0/1 harmonization suffix already landed in code (2026-06-12)

User already changed `base.ntime.harmonized_epoch`'s suffix from `;`/`:` to
literal `0`/`1` (same 4-char nonce-search suffix, same algorithm — just
digit chars). Confirmed examples:

```
epoch_v7 310 -> <V7L36SI1100>
epoch_v7 311 -> <V7L36SA1000>
epoch_v7 312 -> <V7L36RY1100>
epoch_v7 313 -> <V7L36RQ1110>
epoch_v7 314 -> <V7L36RI0110>
```

This is a **drop-in, structural-no-op improvement** — same length, same
search loop, just character set swapped — independent of, and not blocked
by, the larger "move harmonization to the parent/reference-checksum layer,
short epoch_v7" idea two sections above. Both can coexist: this is the
immediate fix for the alignment/`:`-overload problems in the *current*
`epoch_v7` format; the parent-layer move is a separate future refinement
that would further shorten `epoch_v7` itself. **Decision: keep this
0/1 change as-is.**

## Drop `< >` wrapper too? Yes — base32 has no 0/1 (2026-06-12)

Question: does `V7` prefix + `[01]{4}` tail give enough recognizability
that `< >` can be dropped entirely?

**Yes.** Base32 (`A-Z2-7`, used throughout P7's other encodings/checksums)
contains **no `0` or `1` characters**. So `V7...[01]{4}` is self-delimiting
when embedded among base32 strings:

- the trailing `[01]{4}` run is a character class that cannot occur in
  surrounding base32 data — unambiguous right boundary.
- the leading `V7` (digit adjacent to letters) is similarly distinctive.
- **higher-probability self-verification**: even without `< >`, if a
  parser guesses the boundary wrong (too few/many trailing `0`/`1`
  chars), re-running `AMOS7::Assert::Truth::is_true` on the extracted
  candidate fails — the truth constraint computed at generation time is
  re-checkable at extraction time, so wrong boundary guesses are
  self-rejecting. Harmonization therefore does double duty: uniqueness
  AND parse-boundary verification.

**Decision: drop `< >` as well** — `epoch_v7` values become bare
`V7L36SI1100`-style strings, recognizable and self-verifying without any
wrapper.

**Landed (2026-06-12, signed + staged)**: confirmed `< >` was never part of
the truth template's input anyway (only added for display) — so dropping
it is a zero-cost representation cleanup, no change to the harmonization
search itself. Current values:

```
epoch_v7 311 -> V7L36SA1000
epoch_v7 312 -> V7L36RY1100
epoch_v7 313 -> V7L36RQ1110
```

Both the 0/1 suffix change and the `< >` drop are now landed in code.

## Synthesis: epoch-time-as-root generalizes beyond the in-memory tree (2026-06-11)

Stepping back from the common-root/triple/zoom-level details above: the
**true value** of this whole sub-thread is recognizing that "epoch time as
root" is useful as a mapping pattern in *multiple* places, not just as the
abstract namespace-tree root:

- **on-disk layout**: mandatory log/data directory prefixes keyed by epoch
  time make data-over-time manageable — e.g. `<epoch>/...` directory
  structure, naturally bucketing by the same ~1-week epoch unit.
- **1 epoch ~= 1 week is a sweet spot for a rolling index window** — long
  enough to be a meaningful management unit (logs, data retention), short
  enough to keep the rolling prev/curr/next window ([[topic-addressing-
  trinity]]) small and cheap.
- **eventually: a branch root of the network itself** (or many such roots)
  — epoch-rooted branches become the **perfect default parent** in the
  [[checksum-parenting-namespace-trees]] `<C0>:<C1>` scheme: every
  namespace tree, on disk or in-memory, gets a natural, non-arbitrary,
  globally-synchronized default `C1` to parent against — the current
  epoch's branch root — without needing a separately-chosen/configured
  parent.
- this reframes the whole prev/curr/next-root discussion above: it's less
  about finding *the one true* root representation, and more about epoch
  time being a **recurring, fractal default-parent pattern** usable at
  many scales (in-memory namespace tree, on-disk dir layout, network
  branch roots) — each instance independently choosing its own
  resolution/zoom level as discussed above.

## Epoch string as join string for references (2026-06-11)

A natural extension of the epoch-as-default-parent idea above: the epoch
string also works as the **join string between two checksums**, forming a
*reference* checksum that has its expiration date baked in.

User-supplied example:

```
amos-chksum LOVES    -> PKHKHVA
amos-chksum SWEETIE  -> RARRTRI
epoch_v7             -> <V7L36RY::;:>

amos-chksum PKHKHVA:V7L36RY:RARRTRI -> XRDBKJI
```

- `XRDBKJI` is a **reference checksum** between two named entities
  (`LOVES` and `SWEETIE`, here just example names) that is itself a fresh
  AMOS checksum of `<C_a>:<epoch>:<C_b>`.
- **Advantage: expiration is already encoded.** Because the epoch is part
  of the input, the reference checksum `XRDBKJI` is intrinsically tied to
  the epoch it was created in — no separate "created-at" or "expires-at"
  field needed.
- This enables **auto-cleaning or auto-upgrading reference caches**: a
  cache entry whose embedded epoch has rolled out of the
  prev/curr/next window ([[topic-addressing-trinity]] rolling window) is
  recognizably stale by construction — no lookup needed, just compare the
  reference checksum's epoch component against the current window.
- Relation to [[checksum-parenting-namespace-trees]] `<C0>:<C1>` mechanism
  above: this is structurally similar (checksum of a colon-joined string
  of other checksums/names) but here the **middle element is the epoch**
  rather than a name — a *binary* reference between two entities, dated by
  construction, rather than a parent/child *unary* relation. Both forms
  likely coexist: `<C0>:<C1>` for tree parenting, `<Ca>:<epoch>:<Cb>` for
  dated cross-references between tree entries.

## -nest truth-harmonization bugfix surfaces mutual-harmonization + coarse-checksum riff (2026-08-04)

Landed a real bug in `AMOS7::CHKSUM::Nested::child_chksum()`
(`bin/amos-chksum -nest`, `data/yaml/coding-tasks/amos-chksum-nest-truth-
harmonization.yaml`): the `[child:parent]` bracket notation was never
itself run through `is_true()` — only the raw child value was, via
`amos_chksum()`'s always-on convergence loop. A caller doing `-T
<parent>:%s <child>` manually got a guaranteed-true composite; `-nest`
didn't. Fixed by routing `child_chksum()` through `amos_template_chksum()`
with a comma-joined multi-template (`[%s:parent],%s:parent` — reusing
`AMOS7::TEMPLATE::split_truth_templates()`/`template_is_true()`, the exact
mechanism `modules/crypt.C25519.key_bin_checksums` already uses for
"harmonized checksums that are true combined and seperate"), so both the
bracketed and bare-colon forms validate true — relevant because terminal
double-click word-selection stops at brackets, so a copy-pasted value
would otherwise be the unguaranteed bare form. Landed, tested (34/34,
`bin/test-scripts/test-amos-chksum-nest.pl`), not yet committed.

Live-review of that fix opened a longer riff, captured here since it
extends this doc's `<C0>:<C1>` / `<Ca>:<epoch>:<Cb>` material directly
rather than being a separate topic:

### order asymmetry today, and what mutual (2nd-level) harmonization would change

- Today: `child_chksum = amos_chksum(parent_chksum . '.' . child_name)` —
  parent is genuinely the **namespace/context** (concatenated first into
  the hashed input), child is the item within it; changing parent changes
  the derived child value entirely. This is the same category-translation
  property `-T` already exhibits, and matches the `image.kittens` / `a
  gray one` framing: parent-as-namespace, child-as-item-within-it.
- The convergence loop only ever searches the **output** bits of that one
  hash — `parent_chksum`'s literal text never changes across iterations.
  So even post-fix, the parent side of a `-nest` result stays exactly the
  raw, independently-recognizable checksum a caller already has (e.g.
  `PKHKHVA` from `amos-chksum LOVES` stays `PKHKHVA` verbatim inside
  `[X:PKHKHVA]`). Truth-harmonization and traceability are separate
  properties — this fix closed the former, not the latter.
- A **mutual/2nd-level** scheme — searching over both sides jointly until
  neither, alone, matches its "clean" origin value — would actually
  anonymize the pairing, not just harmonize it. Once both sides are
  jointly perturbed by a shared constraint, **which one you call parent
  vs. child stops being load-bearing** — order becomes arbitrary metadata
  on a symmetric relation rather than a structural asymmetry security
  depends on. This reframes `<C0>:<C1>` itself as more relation than
  derivation, once collision-protection/anonymity is the goal rather than
  a one-directional computation pipeline.
- Open costs, not yet resolved: joint search is multiplicative, not
  additive (single-template fix already measured ~2.5x average iteration
  cost; two-variable joint search is a different order of magnitude, no
  termination guarantee — two independently-walked constraints can
  oscillate). Also breaks `verify_nesting()`'s current contract, which
  recomputes from the *known, stable* parent value and compares — a
  jointly-perturbed parent is no longer that stable reference.

### third combined checksum = BMW384 fast-reject, applied to -nest

Directly the same shape as the already-documented BMW384 24-bit
color-channel fast-reject in [[topic-checksum-addressing]] (*"receiver
checks color prefix against target range first; no match → skip entire
360-bit body"*; *"hierarchical routing: coarse color-range filtering...
fine angular resolution only within matching segment"*):

- generate a third, single checksum from **both** entropies combined —
  cheap, one-way, ambiguous by construction (can't recover which
  child/parent produced it without the full pair).
- **two-pass assertion**: check the coarse combined checksum first; no
  match → skip the expensive full `[child:parent]` verification entirely.
  Match → route to "the area of the network grouped by the first" for the
  full check — i.e. the coarse checksum acts as a routing/sharding key,
  not just a reject filter.
- "distribute the search index homogeneously onto cubic space" = the same
  "map to cubic routing space" property already in
  [[topic-addressing-trinity]]. Ambiguity of the collapsed single checksum
  is a **feature** here (keeps the fast-reject pass cheap and one-way),
  not a bug — full resolution still happens in the second pass.

### epoch_v7-compatible resolution layers

Extends "Epoch string as join string for references" above
(`amos-chksum PKHKHVA:V7L36RY:RARRTRI -> XRDBKJI`) into an explicit
layered-resolution scheme:

```
<epoch_v7>:<third_amos>                              -- coarse/fast-reject layer
  resolves to
<epoch_v7>:<amos-0>:<amos-1>                          -- full pair, dated
  next resolution layer:
<epoch_v7>:<amos-3>:<amos-0>:<amos-1>                 -- combined + pair together
```

- `amos-3` here is the third/combined checksum from the fast-reject
  section above — carried *alongside* the full pair rather than replacing
  it, so a lookup can fast-reject on `amos-3` without re-deriving it from
  `amos-0`/`amos-1` first.
- deeper layers "perhaps only virtually existing" — i.e. not necessarily
  materialized/stored, consistent with the lambda principle already in
  [[topic-checksum-addressing]] (*"route identity = relationship identity
  ... derived, not stored"*, also `data/asc/what-AI-thinks/protocol7-
  holistic-convergence-architecture.yaml:118`) — a deeper resolution layer
  can be a computable view rather than a persisted structure, same as the
  common-root/zoom-level resolution earlier in this doc.
- encapsulation options raised, not settled: bracket form (matches
  `-nest`'s existing `[...]`), dot notation (matches namespace-tree `a.b.c`
  addressing), or a **separator-free fixed-length special form** —
  multiple checksums concatenated to *look like* one regular longer
  checksum, each individually true and true-when-appended (same
  simultaneous-truth mechanism as the `-nest` fix above, just fixed-width
  instead of comma-templated).
- **size note**: `bmw-L13` is already a 13-char base32 harmonized checksum
  (~65 bits, division-by-13 loop — see `topic-summary-tree-phase1.md`). A
  26-char combined form = 2×13, i.e. literally two `bmw-L13`s
  concatenated — not a new size to invent, a natural doubling of an
  already-landed primitive. Divisibility by 2 into `2x13` raised as
  possibly meaningful for a **second half in reverse** — which would tie
  directly to the mirror/return-path symmetry already documented in
  [[topic-checksum-addressing]] (*"mirror point is in the field between
  endpoints... return path similar but distinct"*): a reversed second half
  would encode that return-path symmetry into the checksum's own data
  rather than only in routing behavior. Not worked out further — flagged
  for follow-up.
- ASCII 7-bit uppercase addressability noted as a property of the combined
  fixed-length form (26 or 2×13 chars), not yet connected to a specific
  mechanism.

### correction: lambda principle's actual origin is C25519 keypairs, applied generically

User correction to the mirror/reversed-second-half riff above: the lambda
principle wasn't developed for routing in the abstract — it was
**specifically developed for C25519 public keys** ("one forward, one
reverse"), then found to generalize. Checked the code rather than guess at
the crypto-math meaning of "reverse": `modules/crypt.C25519.init_code`'s
`sizetype` table shows an unencrypted private key is 64 bytes = secret(32)
`.` public(32) straight concatenation — not a literal byte/string reversal
— so "forward/reverse" refers to the **asymmetric derivation direction**
(private→public is the easy/forward computation; public→private is the
hard/one-way direction that makes the scheme secure), not a string-level
mirror. This is the real-world instance the abstract mirror-principle
material in [[topic-checksum-addressing]] was generalized from.

**Generic application, per user**: solves **session discovery and
creation** directly via the pub-key's forward/reverse asymmetry, while a
**"home zenki ring" at the core of the network** controls session setup —
filtering/routing by latency, bandwidth, priority, or reachability.

This maps directly onto an already-documented formation rather than being
new: the **dancing zenki ring** in `data/md/protocol-7-knowledge/
03_FORMATIONS/dancing_kittens_formation.md` ("Part 7: Reference Resolution
Layer") — a 2-zenki ring is the stable transport-layer state, temporarily
becoming a 3-zenki ring during a feeding/overwatch handoff so the
just-saturated zenki stays "accessible on ring" to answer questions/resolve
references before descending again. Structurally identical role split to
what's described here: **feeding zenki = session-bearing workers**,
**ring zenki = gatekeeper/session-controller**, filtering and routing
exactly the way the ring decides shift-changes (by who's saturated /
who started earliest — a capacity+priority ordering, same shape as
latency/bandwidth/priority/reachability filtering for session setup).
Also matches the "7 ZENKI ring" portal/gate concept in
`crystal_desktop.md` (`06_INTERFACE_PARADIGM`): ring center as a
controlled, zero-perceived-latency entry/exit point — same
core-of-the-network gating role.

Not yet connected: the specific mechanism by which a C25519 keypair's
forward/reverse asymmetry maps onto which zenki-ring role (does the
"forward" direction identify the discoverable/public session address, and
the "reverse"/hard direction correspond to the ring-internal-only control
plane?). Flagged for follow-up, not resolved here.

### 5-of-7 is the default zenki formation, and it's the same BFT bound as T=5

User: 5 of 7 is the default zenki formation family. "home" zenki were
meant as 5 (the feeders), with 2 additional zenki forming a
**complementary, not just protective**, ring — 2 zenki is enough to form a
sustainable ring (above or around), 5 worker zenki sit within its radius.
Connected explicitly to T=5 and the "5 of 7 consensus algorithm."

Checked `data/md/design/TASK-CUBE-CONSENSUS-ARCHITECTURE.md` — this is an
**exact structural match**, not just thematic resonance:

```
quorum:  n=7, accept threshold 5 of 7 — standard BFT bound (n >= 3f+1)
         tolerates f=2 faulty/dishonest participants without losing
         correctness
```

`f=2` is precisely the ring's size. The dancing-zenki formation (5 feeding
+ 2 ring = 7 total, `dancing_kittens_formation.md` Part 7) is a concrete
embodiment of this abstract BFT bound: the formation can lose/exclude the
2 ring zenki's input entirely and still reach valid 5-of-7 consensus from
the feeders alone — same guarantee the consensus architecture doc
specifies for the task-cube rotation. `T=5` (`AMOS7::Assert::Truth`
constant, `TRUE => 5` per `CLAUDE.md`) being the same digit as the
accept-threshold is not coincidental within this project's own framing —
`holographic-cubic-topology-research-2026-01-13.md` already lists "5
appears in: 5×13 ratios, 5 of 7 consensus, 5×7=35" as a deliberate,
tracked numerical resonance, so T=5 doing double duty as both "the truth
value" and "the consensus quorum size" is consistent with, not
additional to, material already on record.

**Resolved** (found in [[topic-node-group-geometry]], "5-of-7 as the
natural consensus + litter configuration"): it's neither symmetric BFT
tolerance nor a fixed control-role split — it's **5 active + 2
initialized-idle alternates at the same coordinate**. 5 active = working
quorum; 2 alternates = pre-initialized, already-oriented-in-the-field
standbys that absorb up to 2 simultaneous failures by promotion, zero
startup cost. That's a cleaner match to the dancing-zenki description than
either of my two guesses above: the ring zenki aren't malicious-tolerant
peers *or* a permanently-fixed control caste, they're standby capacity
that rotates into the working 5 (the "dance" itself — shift-change by
promotion, longest-working feeder replaced by earliest-arrived ring zenki)
— same shape node-group-geometry describes generically for any
co-located coordinate. That doc also states directly: **"5-of-7 and 2×13
are the same harmonic structure at different scales"** — which folds back
into the `bmw-L13` / 26-char (2×13) sizing note above: the 5-of-7 formation
count and the doubled-checksum-length observation aren't two separate
resonances, they're the same harmonic ratio applied at the
node-coordinate scale and the checksum-length scale respectively.

## Follow-up research pass: verdicts on the three open questions (2026-08-04)

Research/design-only pass (no code touched) on the three questions flagged
unresolved in the 2026-08-04 `-nest` riff above. Grounding re-read:
`AMOS7::CHKSUM.pm`'s `INVERT_TRUTH_STATE` loop, `AMOS7::CHKSUM::Nested.pm`,
the task yaml's resolution/iteration-cost block, `dancing_kittens_formation.md`
Part 7 + Home-Ring Architecture, `crystal_desktop.md` ring gates,
`crypt.C25519.init_code` sizetype table + `key_bin_checksums` templates.

### Q1 — joint/mutual 2nd-level harmonization: RESOLVED (in design), with a constraint

Key structural observation that collapses the problem: as long as the
**derivation relation stays intact** (`child = H(parent . name)`), the joint
search is NOT 2-dimensional. The child value is fully determined once the
parent candidate is chosen — the only free variable is the parent-side
entropy. So "search over both jointly" decomposes into exactly one search
with more acceptance predicates:

```
search parent-layer entropy P' (e.g. nonce-suffixed parent, same 0/1-suffix
mechanism already documented for epoch_v7) until ALL of:
    is_true(P')                       -- parent alone, anonymized
    is_true(H(P' . name))             -- raw derived child alone
    is_true(combined/bracketed forms) -- the -nest fix's template clauses
```

- This is the **existing convergence loop with more template clauses**, not
  a new algorithm. Cost asymptotics: each step of `INVERT_TRUTH_STATE` is an
  independent re-draw (XOR with 32 fresh pool bits, resaturated from the BMW
  512-bit pool at +13 offsets), so steps-to-success is geometric with mean
  p^-1 where p = joint acceptance probability. Adding k near-independent
  clauses multiplies expected cost by the product of their rejection
  factors. Measured data point from the task yaml: going from ~3 effective
  constraints to ~5 cost 2.5x (~1.58x per added clause, i.e. clauses are
  correlated, not fully independent — bare and bracketed forms share most of
  the string). Extrapolating: 2-3 extra clauses for the mutual scheme lands
  at ~4-10x the current ~793 steps/call — SAME order of magnitude, wall time
  still tens of milliseconds. Not the "different order of magnitude" feared
  in the riff.
- **Termination**: geometric tail, terminates with probability 1 — same
  guarantee class as the current loop, and the existing
  `AMOS7::TEMPLATE::template_timeout()` backstop applies unchanged.
- The **naive alternating version** (harmonize parent given tentative child,
  then re-harmonize child given new parent, repeat) is genuinely bad and
  should not be built: each side's re-roll destroys the other side's joint
  constraints, there is no monotone objective/Lyapunov function, and each
  inner `child_chksum()` call is itself a ~793-step search — cost becomes
  multiplicative (outer candidates x inner search, ~10^5-10^6 steps,
  seconds-scale and frequently timeout-hitting). It terminates only in the
  almost-sure/geometric sense (each outer round is a Bernoulli trial),
  never with a hard bound.
- **The one rule that keeps it cheap: never nest two convergence loops —
  flatten to one loop with more predicates.** Check the raw derived child as
  a pass/fail predicate inside the parent search instead of harmonizing the
  child per candidate.
- **Verdict: RESOLVED — practical** under the flattened single-loop design
  with bounded clause count (say <= 6 effective clauses, cost ~10x current,
  cf. `key_bin_checksums` already runs 4-clause templates in production).
  Fully-symmetric two-sided perturbation (breaking derivation, `<C0>:<C1>`
  as pure relation) is NOT practical as alternation; if ever wanted, only
  as outer geometric retry loop with hard depth cap N_max and fallback to
  the landed one-sided scheme. Concrete next step: prototype the flattened
  parent-side search (nonce suffix on parent input, raw-child-truth as an
  added predicate) and measure the real per-clause cost exponent against
  the 2.5x data point.

### Q2 — verify_nesting() under mutual harmonization: RESOLVED (contract redesign)

Re-reading `verify_nesting()`: it recomputes `child_chksum(parent, name)`
and compares. Crucially, that check verifies the **derivation direction
forward from the supplied parent** — it never needed the parent to be the
*clean* origin value, only to be the value the child was actually derived
from. So the recompute-and-compare contract SURVIVES mutual harmonization
almost unchanged, with a semantic split into levels:

- **Level 1 — relational verification (current code, unchanged)**: caller
  supplies the *anonymized* parent P' (the one embedded in the notation
  anyway, per `parse_nested`), plus child_name. Recompute C' from P' and
  compare. This still proves internal consistency of the pair: "this child
  was derived from this parent under this name." No original needed.
- **Level 0 — structural/PoW verification (new, no inputs beyond the
  notation)**: check `is_true` on all guaranteed forms (child alone, parent
  alone, bare, bracketed). Under mutual harmonization a jointly-true pair is
  expensive to produce (Q1's multiplied search cost), so joint-truth itself
  becomes a proof-of-work-style validity witness — exactly the human
  reviewer's stated tradeoff from the fix ("more clauses = more PoW cost =
  fewer degenerate collisions"), now doing security duty.
- **Level 2 — identity anchoring (optional, new parameter or third-party
  lookup)**: proving the anonymized pair corresponds to a *specific* clean
  parent identity P0 requires either the caller to supply P0 (+ the
  parent-layer nonce, so the P0->P' perturbation is re-verifiable) OR a
  lookup against whoever holds the mapping. Property traded off: without
  Level 2 you verify *consistency*, not *identity* — which is not a bug but
  precisely the anonymization goal the riff asked for (traceability and
  truth-harmonization are separate properties; the pair becomes
  self-certifying as a relation).
- Natural home for the Level 2 mapping: the third/combined checksum
  (`amos-3`, the BMW384-style fast-reject value from this thread) committed
  to a dated registry — `<epoch_v7>:<amos-3>` resolving to
  `<epoch_v7>:<amos-3>:<amos-0>:<amos-1>`. The registry holder (see Q3:
  the home zenki ring) is then the *only* party that can anchor identity;
  everyone else gets Levels 0-1. This makes verification-capability
  tiering a structural property instead of a policy.
- **Verdict: RESOLVED.** Signature can stay `(notation, parent, name)` with
  `parent` redefined as the anonymized value; add an optional original-
  parent parameter for Level 2. No verification-without-original scheme is
  needed for consistency — only for identity, and that gap is the intended
  anonymization, closable via the ring-backed registry when wanted.

### Q3 — C25519 forward/reverse -> zenki-ring role mapping: PARTIALLY RESOLVED

Grounding in the actual one-way property (not verbal analogy): C25519
`public = scalarmult(secret, basepoint)`; private->public is cheap, the
reverse (ECDLP) is infeasible. ECDH makes both *holders* compute the same
shared secret cheaply — so the role asymmetry can't be "client computes,
ring un-computes" (both compute S). The real asymmetry that maps to roles
is **possession of the private scalar**, and the OWF guarantees nobody
else can compute what the scalar-holder computes. Concretely:

- **Forward (easy, public, stateless) = data plane / session discovery.**
  Any client derives a discoverable session address from the ring's
  published identity key: pick ephemeral secret e, compute
  `S = scalarmult(e, ring_pub)`, then
  `session_addr = amos_chksum(S . epoch_v7)` (or the dated
  `<Ca>:<epoch>:<Cb>` form — expiration baked in, staleness self-evident
  after window rollover, no lookup needed). Anyone can do forward;
  session addresses are publishable, route via normal BMW384/checksum
  field addressing, and cost nothing to create. This is the 5 feeding
  zenki + clients side of the formation.
- **Reverse (hard, ring-internal) = control plane / session setup.** Only
  a holder of `ring_secret` can complete the ECDH from the client's
  ephemeral public key (`S = scalarmult(ring_secret, client_eph_pub)`) and
  thereby re-derive/validate session_addr — i.e. only the ring can map a
  presented session address back to an authenticated session and hence to
  a control decision: admit, schedule, filter by
  latency/bandwidth/priority/reachability. To everyone else session_addr
  is an opaque, unlinkable checksum (one-way by the ECDLP assumption).
  This is the 2 ring zenki / home-ring role: the ring gates in
  `crystal_desktop.md` (controlled, zero-perceived-latency entry point)
  are this control plane visualized.
- **Dancing-zenki handoff = time-boxed grant of reverse capability.**
  Part 7's temporary 3-ring state (saturated feeder ascends, stays
  "accessible on ring" to resolve references, then descends) maps exactly:
  during handoff the ascending zenki transiently holds the live session
  context (its own S values / session state) and can answer reference
  requests — a bounded admission to the control plane — which it loses on
  descent. Session continuity = controlled, TTL'd reverse-direction
  capability, matching `ttl => $HANDOFF_PERIOD` in the reference
  resolution protocol.
- **5-of-7 wraps the control decisions**: session admission/filtering is a
  quorum decision (5-of-7, tolerating f=2 = the ring pair itself, per
  [[topic-node-group-geometry]]: 5 active + 2 initialized-idle alternates).
  Ring rotation (the dance) then doubles as key-custody rotation: the
  ring-held scalar should rotate with shift-change and be epoch-bound, so
  session addresses from a rolled-out epoch fail ring validation
  structurally.
- **Verdict: PARTIALLY RESOLVED.** The forward=discoverable-address /
  reverse=ring-only-control mapping holds and is grounded in the real OWF
  (possession asymmetry via ECDH, not a byte-level mirror). Residual open
  item, concrete: how the ring scalar is shared/rotated between the 2 ring
  zenki (threshold split vs. alternating custody during the dance) and the
  exact epoch-binding wire format. Next step: sketch the handshake against
  the existing `crypt.C25519.*` modules — `key_bin_checksums` already
  harmonizes key-derived checksums through 4-clause templates, so the
  `session_addr` derivation has a direct in-repo precedent to build on.

## Dot-notation checksum routes, implying routing (2026-08-04)

New addition to the thread, distinct from the `[child:parent]` nested-pair
notation above: a **flat dot-joined string as a single route address**,
where each dot-separated segment is a hop. Live example (verified,
reproducible):

```
amos-chksum -v P.KY.62.BY
  input-string : P.KY.62.BY
  VAX-encoded  : I2NNYAY : 64789062
```

- Unlike `[child:parent]`, this is not two checksums paired — it's ONE
  checksum of a single string that already encodes a hierarchical path
  (`P` -> `KY` -> `62` -> `BY`, 1/2/2/2 chars). The route structure lives
  in the input, not in the output pairing.
- **26 chars + `.` = 27-symbol route alphabet**: base32 here contributes
  its 26 letters as hop-name characters (`P`, `KY`, `BY` above); `.` as
  the 27th symbol is the hop separator, distinct from any hop-name
  character. Numbers and binary (`62` above) layer in as an additional
  character class for hop segments — consistent with the existing
  0/1-suffix harmonization mechanism already used for `epoch_v7`.
- **"3 axis x 255 bits [base32]"** — raised, not yet worked out how this
  maps onto the dot-hop structure; flagged for a follow-up pass rather
  than guessed at here.
- **Namespace separation by hop length, checked against real data**:
  claim was "zenki names start with 3 characters, so 1 and 2 character
  routes stay available for routing/coordinate hops." Checked
  `cfg/zenki/` (125 entries): **1-char is fully free — zero
  1-char zenki names exist.** **2-char is *mostly* free but not
  entirely** — `v7` and `fs` are real 2-char zenki names already in use
  (2 of 125), so a 2-char hop segment isn't unconditionally
  collision-free the way 1-char is; anything routing through 2-char hops
  would need to special-case those two names or accept the (very small)
  collision surface.
- **Character = grid, number = angle**: proposed mapping of hop-segment
  character class to coordinate type — alphabetic hops as discrete
  grid/cell addressing, numeric hops as continuous angle addressing, with
  angle+distance resolving onto grid coordinates in some contexts. This is
  the same grid/angular split already documented for BMW384 in
  [[topic-checksum-addressing]] (24-bit color/angular channel vs. the grid
  based node-group geometry in [[topic-node-group-geometry]]) — not a new
  duality, an application of the existing one to hop-segment typing.
- **Each hop adds precision by lengthening the address, direction/scale
  agnostic**: matches the lambda-principle framing already documented
  ("each hop encodes routing decision into local field state... hop
  decision deterministic from coordinates" in
  [[topic-checksum-addressing]]) — progressive resolution refinement via
  address length, same shape as the coarse-to-fine BMW384 routing already
  established, now stated generically for dot-hop routes of arbitrary
  length rather than just the color-prefix/angle split.
- **Memory efficiency**: local routing decisions stay cheap (short
  hop segments, small local lookup), while the full dotted path can grow
  to arbitrary length for deep addressing — standard trie/hierarchical
  property, consistent with the namespace-tree material earlier in this
  doc (`<C0>:<C1>` parenting) but applied to a flat path string instead
  of a checksum-pair chain.
- Also raised: ring structure or direct cubic-space routes as alternate
  hop-resolution topologies — not elaborated, ties to the cubic routing
  space material in [[topic-addressing-trinity]].

### Host-digit as statistically-derived address, not assigned (2026-08-04, same riff)

Extends the dot-notation hop-addressing idea above: a node's single-
character host digit need not be assigned — it can be **derived from the
node's own reference pool**. If, among all immediate references a node
holds, `L` is statistically the most-held character [ relative to all
other candidate characters present ], that node's address to its
neighbors becomes `L` — emergent from content, not allocated.

- **Routing consequence — pool, not pointer**: a neighbor needing to route
  something keyed on `L` is not required to route through the specific
  node that "is" `L` — it chooses whichever reachable node currently has
  the **widest reference count for `L`**, which may be a different node
  entirely. The nominal `L`-node stays **in the pool** as a valid fallback
  — degraded routing, not broken routing, if the top-ranked node is
  unreachable.
- This is the **same mirror-principle mechanism already documented**, not
  a new one: [[topic-checksum-addressing]]'s "route as symmetry condition"
  section states routing is *"not constructed, revealed by attained
  symmetry"* and *"mirror point shifts with field conditions → load
  distributes automatically."* Here the field condition being sensed is
  literally per-character reference density; the route resolving to
  "whoever currently scores highest for `L`" rather than a fixed
  address-holder is exactly that shifting-mirror-point property, applied
  to the dot-notation hop addressing from the section above.
- Closest outside-world analogue for calibration (not a repo precedent,
  just a sanity-check reference point): this is structurally similar to
  rendezvous/highest-random-weight hashing, except the weight is *real,
  observed reference density* rather than a synthetic hash-of-(key,node)
  score — so the ranking is content-derived and changes as the network's
  actual reference distribution shifts, rather than being fixed at
  assignment time.
- Open: how ties are broken (two nodes statistically equal for `L`), how
  often the ranking needs re-evaluation vs. being cached, and whether this
  composes with the 1-char/2-char zenki-name-collision finding above [ a
  zenki with a real fixed name like `v7` presumably can't also become a
  statistically-derived `L`-address without a namespace-priority rule ].
  Not worked out — flagged for the same later pass as the rest of this
  section.
- **Sort key is pluggable, not just reference-count**: same "widest wins,
  nominal holder stays fallback" mechanism generalizes to additional
  routing-preference attributes — lowest latency, highest bandwidth — not
  a new idea here, the same list already named earlier in this thread for
  the home-zenki-ring's session-control filtering [ "latency, bandwidth,
  priority, or reachability" ]. Open question raised alongside this: is
  latency/bandwidth better represented as a **cycle-distributed** metric
  [ measured per rotation, same clocked-rotation mechanism
  `TASK-CUBE-CONSENSUS-ARCHITECTURE.md` already uses — "a logical
  (virtual, calculated) clock... counts face advances, not wall-clock
  ticks" ] rather than a single instantaneous scalar? If so, the sort key
  itself would be a per-cycle distribution rather than a point value —
  not resolved here, flagged alongside the other open items in this
  section.

**Status**: recorded per user request ("either now or later is likely
worth another pass") — not yet dispatched for a deeper pass. The live
example and the zenki-name-length check above are verified; everything
else in this section, including this host-digit addition, is
open/unelaborated.

### Grounding pass: pluggable sort key + cycle-distributed metric vs. existing material (2026-08-04)

Research/design-only pass (no code touched) on the two claims in the
"Sort key is pluggable" bullet above, against the existing latency/
bandwidth corpus (`topic-latency-algorithmic-authority-entropy-toll.md`,
`bandwidth_optimization.md`, `models-zenka-complete-architecture.md`,
`WEIGHTED-NETWORK-TIME-PRECISION-CONSENSUS.md`, plus two docs surfaced
on the way: `ROUTING-AS-SEARCH-DISTRIBUTED-DISCOVERY.md` and
`OBSERVER-CENTRIC-REFERENCE-SPACE.md`).

- **"Sort key is pluggable" — CONFIRMED-EXISTING, three independent
  precedents.** (1) `ROUTING-AS-SEARCH-DISTRIBUTED-DISCOVERY.md`
  already sketches per-hop multi-attribute route metrics as code shape:
  `update_route_metrics($hop, { latency => measure_latency(...),
  reliability => ..., popularity => ..., resonance => ... })` — a
  pluggable metrics vector, not a single key. (2) `TASK-CUBE-CONSENSUS-
  ARCHITECTURE.md` layer 2: "network routes around it using nodes with
  better success statistics" — routing preference by observed statistic,
  same "best-currently wins, not assigned" shape as the host-digit pool.
  (3) `topic-latency-algorithmic-authority-entropy-toll.md` names
  latency itself as "a third algorithmic authority" and describes a
  self-organizing latency grid that places nodes "not by central
  assignment" — the emergent-ordering claim of this riff, already stated
  for latency specifically. What remains new here is only the
  *application* to the 1-char host-digit reference pool, not the
  mechanism.
- **Cycle-distributed bandwidth — RESOLVED by existing material, in a
  stronger form than the question posed.** `OBSERVER-CENTRIC-REFERENCE-
  SPACE.md` ("temporal bandwidth — the serialization clock") already
  *defines* bandwidth as a per-cycle distribution: clock period = 13
  slots (harmonic, generator 076923), faces get slots proportional to
  reference count, "leaf count per face per cycle = bandwidth... the
  sequence IS the allocation," and explicitly "spatial: reference count
  -> distance from darksun [position] / temporal: reference count ->
  slots per clock cycle [bandwidth] / same gravity. two domains. one
  mechanism." Mirrored in `topic-observer-centric-space.md`. So for
  bandwidth the answer isn't "should it be per-rotation" — it already
  is, and it's driven by the *same* reference-count statistic as the
  host-digit address itself, i.e. the sort key and the cycle-
  distribution are one mechanism there, not two.
- **Cycle-distributed latency — CORRECTED/REFINED, not "measured per
  rotation."** The open question assumed the choice was raw per-rotation
  measurement vs. instantaneous scalar. The existing corpus rejects the
  scalar but establishes a *different* alternative:
  `WEIGHTED-NETWORK-TIME-PRECISION-CONSENSUS.md` treats measured
  time-precision as a **weighted historical statistic** — "a node's
  historical precision determines how much its current time sample
  counts," a dynamic tolerance window that "shrinks over successive
  cycles," "integer-per-cycle-type consequences," plus second-order
  scoring on *predicted* vs. actual precision. The epistemic split that
  matters: the task-cube/orbital clock is logical — "calculated is more
  precise than measured" — while latency is physical and per the
  WEIGHTED doc "has to be measured and agreed on across independently-
  clocked nodes," which is exactly why the weighted consensus exists.
  So the established shape is: bandwidth = *calculated* per-cycle slot
  density (free, derived from references); latency = *measured*,
  weighted-consensus statistic with per-cycle accounting and shrinking
  windows — not a raw per-rotation sample. Supporting habit-level
  evidence that the project never uses point scalars for latency:
  `SETTINGS-STATISTICS-ZENKA.md` classifies "Synchronization latency
  distributions" as statistics-zenka data; `models-zenka-complete-
  architecture.md` tracks latency as avg/p95/p99 percentiles.
- **Residual genuinely-new items** (not found answered anywhere in the
  corpus): (a) the two cycle vocabularies are not yet unified — the
  task-cube logical clock counts face advances, the serialization clock
  counts 13 slots; folding the weighted-precision latency statistic into
  either frame is unworked. (b) Multi-statistic pool ranking: bandwidth
  and position share one statistic (reference count), so "widest wins"
  is unambiguous there; adding latency as a *second, independent*
  statistic raises unaddressed tie-break/composite-ordering questions
  for the fallback pool (same open class as the tie-breaking item
  already flagged in the host-digit section).

**Verdict**: pluggable sort key = confirmed-existing (cite the three
precedents above when developing it further); cycle-distributed
bandwidth = resolved-existing, stronger form (13-slot serialization
clock); cycle-distributed latency = corrected — existing answer is the
weighted precision consensus with per-cycle accounting, not per-rotation
measurement; genuinely new = cycle-clock unification + multi-statistic
pool ranking only.

## Status

User said "let us first dispatch something" while still mid-riff — dispatched
to opus via claude_dispatch to draft a design doc capturing this material
(see commit/doc once written). More nodes in this tree are expected to follow.

#,,.,,.,.,..,,,,.,,,.,,,.,,..,.,,,...,,,,,,,,,..,,...,...,...,,,.,...,.,,,,,,,
#O55EXL5PKALYFTF6KI6B43NY5J3JOC7EPJHIPEUNIZ7N5EIIE5EEDCPG37H5NZTCCVPP5RACK6HGE
#\\\|73XECTU24LPAI6KR6W42QINLUGGDGNMS6P5LZ4USPRSSSGRRIYX \ / AMOS7 \ YOURUM ::
#\[7]GTXXJN6H65G3PJJQQEES2YJOPDKDMIHDIOOSVMA5VOA3V35MVAAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
