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

## Status

User said "let us first dispatch something" while still mid-riff — dispatched
to opus via claude_dispatch to draft a design doc capturing this material
(see commit/doc once written). More nodes in this tree are expected to follow.

#,,.,,.,.,.,,,,,.,,,.,,.,,,,,,...,.,,,,..,.,.,..,,...,...,,..,,,.,,.,,..,,,..,
#FVU2WXG7BKHHHMCHGVLDWLNP3KWSX5ITQ42I4GMEYIR67RERUNZQJUHBI5HGI2ITYLH2RPZF3OEMC
#\\\|NURHBNDPO7R7GOM5FPMZYPNB7IRGF3ABRPNHFF6K7BCCIDRKO3G \ / AMOS7 \ YOURUM ::
#\[7]P33IOTKXSQOIFPEDWAXKWZPIVBBECKGRUQA3YUULZ3J57JMM7ACI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
