## [:< ##

# nested checksum harmonization and addressing
# — landed bugfix, order asymmetry, and the open riffs it surfaced

## purpose and status discipline

this doc extends `CHECKSUM-PARENTING-NAMESPACE-TREES.md` [ the `<C0>:<C1>`
auto-parenting mechanism ] and `CHECKSUM-NESTED-ADDRESSING-AND-EPOCH-
VALIDITY.md` [ early ideation on `[CHECKSUM:NAME]` nesting and epoch-rooted
addressing ] with material from a single thread: a real bug found and fixed
in `AMOS7::CHKSUM::Nested::child_chksum()`, and the design riff that opened
up while reviewing the fix live.

as with this thread's sibling docs, every claim below is tagged
**[ landed ]**, **[ verified, not speculative ]**, or **[ open / design-only
]**. section 1 is settled fact — read it as a changelog, not a proposal.
sections 3 onward get progressively more speculative; do not treat them as
committed design.

---

## 1. [ landed ] the `-nest` truth-harmonization fix

### the gap

`bin/amos-chksum -nest <parent> <child_name>` builds the bracketed
`[child:parent]` nesting notation via
`AMOS7::CHKSUM::Nested::child_chksum()`. every other checksum-generation
path in the codebase that claims a result is "true" — version strings
[ `-VCS`/`-VL7`/`-VS` ], `base.ntime.harmonized_epoch`'s suffix search, `-T`
sprintf templates — runs a convergence loop before returning, so the result
is guaranteed to pass `AMOS7::Assert::Truth::is_true()`. `-nest` did not:
it returned the raw parent/child computation unharmonized, and could come
out FALSE.

live-demonstrated before the fix:

```
amos-chksum LOVES                 -> PKHKHVA
amos-chksum LOVES SWEETIE         -> CY4FN3A
amos-chksum -nest PKHKHVA CY4FN3A -> [METUEMA:PKHKHVA]
is-true [METUEMA:PKHKHVA]         -> FALSE
```

### the fix

`child_chksum()` now builds the nest output shape as a truth template and
routes it through `AMOS7::CHKSUM::amos_template_chksum()` — the same entry
point `-T` uses — so the convergence loop in `AMOS7::CHKSUM.pm` only exits
once `is_true()` passes on the full bracketed string, not just on the raw
child value [ the child value alone was already harmonized by
`amos_chksum()`'s always-on loop; the bracketed composite was not ].

a human-review follow-up the same day extended the fix further: the
initial version only guaranteed the *bracketed* `[child:parent]` form true,
not the *bare* `child:parent` form with brackets stripped — relevant
because terminal double-click word-selection stops at brackets, so a
copy-pasted checksum comes out bare, not bracketed. the final fix builds a
**comma-joined multi-template** covering both shapes at once:

```perl
## bracketed and bare notation shapes as comma-joined truth templates [ ##
## split_truth_templates splits on unescaped commas and                 ##
## template_is_true requires all clauses to pass, so the result is true ##
## combined and separate : both [child:parent] and the bare             ##
## child:parent form [ e.g. terminal double-click copy-paste, where     ##
## word-boundary selection stops at the brackets ] validate ]           ##
my $nest_template = join( ',',
    sprintf( qw| [%s:%s] |, qw| %s |, $parent_chksum ),
    sprintf( qw| %s:%s |,   qw| %s |, $parent_chksum ) );
```

this is not new machinery — `split_truth_templates()` /
`template_is_true()` require **all** comma-separated clauses to pass
`is_true()` before the convergence loop exits, and this exact
"harmonized checksums that are true combined and separately" pattern
already exists in `modules/crypt.C25519.key_bin_checksums`:

```perl
my $checksum_template         = qw| <:%s:> |;
my $pubkey_str_truth_template = '<:%s:>,:%s:';
```

`-nest` now reuses the same mechanism rather than inventing a parallel one.

### result

```
amos-chksum -nest PKHKHVA CY4FN3A -> [B5JI5LY:PKHKHVA]
is-true '[B5JI5LY:PKHKHVA]'       -> TRUE
is-true 'B5JI5LY:PKHKHVA'         -> TRUE
```

- rollout: default-on, no opt-out — matching `-T` and
  `base.ntime.harmonized_epoch`, which also harmonize unconditionally. no
  stored `[child:parent]` notations exist anywhere in repo data, so no
  persisted values shifted; pre-fix example values [ e.g. the original
  `[METUEMA:PKHKHVA]` ] no longer verify, as expected for a value-changing
  fix.
- cost: an additional simultaneous truth clause is a proof-of-work-style
  cost, not free — measured roughly **~2.5x average convergence-search
  cost** [ ~323 steps/call before, ~793 steps/call after, 5 sample pairs ],
  wall time still negligible in absolute terms [ 0.003s..0.025s per call ].
  the tradeoff is deliberate: more simultaneous constraints costs more to
  satisfy but also reduces the chance of a degenerate "everything happens
  to read true at once" collision across unrelated representations.
- `format_nested()` is unchanged — it still emits only the bracketed form.
  the bare form is not a separate output shape, it is now a *guarantee*
  about what you get if you strip the brackets from the one output shape
  that exists.
- tested: `bin/test-scripts/test-amos-chksum-nest.pl`, **34/34 passing**
  [ full-bracket `is_true`, bare-form `is_true`, child-alone `is_true`,
  `verify_nesting()` round-trip, `parse_nested()`, `reconstruct_chain()`,
  invalid-input handling ]. no pre-existing test suite covered
  `AMOS7::CHKSUM::Nested` or `amos-chksum` before this.
- caller audit: only `bin/amos-chksum -nest` and the zenka modules
  `amos.chksum.cmd.nest` / `.verify-nested` / `.parse-nested` consume the
  module. `reconstruct_chain()` has no callers and is parse-only.
  `verify_nesting()` recomputes via `child_chksum()` itself, so it stays
  consistent automatically.
- committed: **not yet** as of writing — landed and tested against
  `base`, staged for commit.

full detail: `data/lib-path/pm/AMOS7/CHKSUM/Nested.pm`,
`data/yaml/coding-tasks/amos-chksum-nest-truth-harmonization.yaml`.

---

## 2. [ verified against real code ] order asymmetry: parent is context, child is derived

reading `child_chksum()` directly:

```perl
return amos_template_chksum( $nest_template,
    $parent_chksum . '.' . $child_name );
```

the input to the hash is `parent_chksum . '.' . child_name` — **parent
concatenated first**. this is not incidental: the parent is genuinely the
**namespace/context** the child is being addressed within, not a
symmetric partner in a pairing. changing the parent changes the derived
child value entirely, which is exactly what `CHECKSUM-PARENTING-NAMESPACE-
TREES.md` section 1 already establishes about `<C0>:<C1>`.

this is the same category-translation property `-T` already demonstrates
[ `AMOS-SIGNATURE-FOOTER-BIT-FRAME-HIERARCHY.md`'s `-T` section, live: one
item `loves.png` translated through two different category contexts
`MCBZXFY` = `"file.name"` vs `LERCKVI` = `"image.kitten"` yields two
independently TRUE-guaranteed, non-leaking keys ] — parent-as-namespace,
child-as-item-within-it, matching the `image.kittens` / `a gray one`
framing already on record.

**the convergence loop only searches the output side.** the fix in
section 1 adds a search over the *combined* `[child:parent]`/`child:parent`
string, but the search space is still only the child's derived entropy —
`parent_chksum`'s literal text never changes across iterations. so even
post-fix, the parent side of a `-nest` result stays exactly the raw,
independently-recognizable checksum a caller already has [ e.g.
`PKHKHVA` from `amos-chksum LOVES` stays `PKHKHVA` verbatim inside
`[X:PKHKHVA]` ]. **truth-harmonization and traceability are separate
properties.** section 1's fix closed the former, not the latter — this is
stated plainly so the fix is not mistaken for anonymizing anything.

---

## 3. [ open / speculative ] mutual (2nd-level) harmonization as anonymization

a scheme where both sides are searched **jointly**, rather than only the
child side, until neither, alone, matches its own "clean" origin value —
would do something qualitatively different from section 1's fix: it would
**anonymize the pairing**, not just harmonize it.

once both sides are jointly perturbed by a shared constraint, which one you
call parent vs. child stops being load-bearing — order becomes arbitrary
metadata on a symmetric *relation*, rather than the structural asymmetry
section 2 shows security currently depends on. this reframes `<C0>:<C1>`
itself as more relation than derivation, but **only if this scheme is
built** — nothing here changes that framing today.

### known costs and open problems, not resolved

- **multiplicative, not additive search cost.** the single-template fix in
  section 1 already measured ~2.5x average iteration cost for one
  additional simultaneous constraint. a joint two-variable search over
  both parent and child sides is a different order of magnitude — no
  termination guarantee is established; two independently-walked
  constraints can in principle oscillate against each other rather than
  converge.
- **breaks `verify_nesting()`'s contract.** `verify_nesting()` currently
  recomputes `child_chksum(parent_chksum, child_name)` from the *known,
  stable* parent value and compares against the supplied notation. a
  jointly-perturbed parent is no longer that stable reference — the
  verification contract would need to change shape [ e.g. verify against
  the *un-perturbed* origin values plus the perturbation record, rather
  than against the parent checksum directly ], not just get slower.

this section is a design riff, not a task. no task file has been written
against it.

---

## 4. [ open / design-only ] third combined checksum as a BMW384-style fast-reject

this idea is explicitly the same shape as an already-landed precedent
elsewhere in the corpus, not a new mechanism: `topic-checksum-addressing.md`
documents BMW384's 24-bit color-channel prefix doing exactly this for
field-routing —

> *"fast-reject: receiver checks color prefix against target range first;
> no match → skip entire 360-bit body"*
> *"hierarchical routing: coarse color-range filtering at outer nodes, fine
> angular resolution only within matching segment — no routing table, just
> progressive narrowing"*

applied to `-nest`:

- generate a **third, single checksum** from both entropies combined —
  cheap, one-way, and ambiguous by construction [ cannot recover which
  child/parent produced it without the full pair — the ambiguity is a
  **feature**, keeping the fast-reject pass cheap and one-way, not a bug ].
- **two-pass assertion**: check the coarse combined checksum first; no
  match → skip the expensive full `[child:parent]` verification entirely.
  match → route to "the area of the network grouped by the first" for the
  full check — the coarse checksum functions as a routing/sharding key, not
  only a reject filter, matching BMW384's "distribute the search index
  homogeneously onto cubic space" property [ same "map to cubic routing
  space" property already documented in `topic-addressing-trinity.md` ].

**not implemented anywhere.** no code or task file exists for this — it is
recorded here as a design-shape match to an already-working precedent, not
as a proposal ready to build.

### size note, flagged for follow-up, not worked out

`bmw-L13` is already a landed 13-char base32 harmonized checksum [ ~65
bits, division-by-13 loop ]. a 26-char combined form for the third checksum
would be `2 × 13` — literally two `bmw-L13`s concatenated, not a new size
to invent. divisibility into `2×13` was raised as possibly meaningful for
a **second half in reverse**, which would tie to the mirror/return-path
symmetry `topic-checksum-addressing.md` already documents [ *"mirror point
is in the field between endpoints... return path similar but distinct"* ]
— a reversed second half would encode that return-path symmetry into the
checksum's own data, not only in routing behavior. not worked out further.
encapsulation shape [ bracket form matching `-nest`'s existing `[...]`, dot
notation matching namespace-tree `a.b.c` addressing, or a separator-free
fixed-length form where multiple checksums are individually and jointly
true, same simultaneous-truth mechanism as section 1's fix but fixed-width
instead of comma-templated ] is also unresolved — three options listed,
none chosen.

---

## 5. [ open / design-only ] epoch_v7-compatible layered resolution

extends "epoch string as join string for references" [ already documented:
`amos-chksum PKHKHVA:V7L36RY:RARRTRI -> XRDBKJI`, a dated cross-reference
checksum whose expiration is baked into the epoch component, per the
rolling prev/curr/next window ] into an explicit layered scheme combining
section 4's fast-reject checksum with the dated-pair form:

```
<epoch_v7>:<third_amos>                    -- coarse/fast-reject layer
  resolves to
<epoch_v7>:<amos-0>:<amos-1>               -- full pair, dated
  next resolution layer:
<epoch_v7>:<amos-3>:<amos-0>:<amos-1>      -- combined + pair together
```

- `amos-3` here is section 4's third/combined checksum — carried
  *alongside* the full pair rather than replacing it, so a lookup can
  fast-reject on `amos-3` without re-deriving it from `amos-0`/`amos-1`
  first.
- deeper layers "perhaps only virtually existing" — consistent with the
  lambda principle discussed in section 6 below [ *"route identity =
  relationship identity ... derived, not stored"* ]: a deeper resolution
  layer can be a computable view rather than a persisted structure, the
  same zoom-level relationship `CHECKSUM-NESTED-ADDRESSING-AND-EPOCH-
  VALIDITY.md` describes for the common-root/prev-curr-next epoch window.

**status: design-only.** no encapsulation format, storage shape, or
resolution-triggering code exists for this layering. it is a sketch of how
section 1's harmonization mechanism, section 4's fast-reject idea, and the
already-landed epoch-as-join-string mechanism would compose, nothing more.

---

## 6. [ genuine cross-connection, verified separately in each source ] the C25519 lambda principle and the 5-of-7 ring

this section connects three pieces of material that were each documented
independently, in separate threads, for unrelated reasons. it is presented
as a *found* connection, not an invented one — each piece stands on its own
regardless of whether the connection holds.

### 6a. correction: the lambda/mirror principle's real origin

an earlier riff in this thread speculated that a "reversed second half"
[ section 4's size note above ] might connect to a general
routing mirror-principle. that speculation was **corrected**: the
forward/reverse ["lambda"] principle was not developed for routing in the
abstract — it was developed specifically for **C25519 keypairs**, "one
forward, one reverse," and only later found to generalize.

checked directly against code rather than guessed: `modules/
crypt.C25519.init_code`'s `keys.sizetype` table shows an unencrypted
private key is `64` bytes = secret(32) `.` public(32), a straight
concatenation — **not** a literal byte/string reversal. so "forward" and
"reverse" name the **asymmetric derivation direction** [ private → public
is the easy/forward computation; public → private is the hard/one-way
direction that makes the scheme secure ], not a string-level mirror. this
is the real-world instance the abstract mirror-principle material in
`topic-checksum-addressing.md` was generalized *from* — not an application
of it.

`modules/crypt.C25519.key_bin_checksums` [ cited already in section 1 as
the precedent for comma-joined simultaneous-truth templates ] is the same
module family this correction is grounded in — the "harmonized checksums
that are true combined and separately" pattern and the lambda/forward-
reverse principle both live in the C25519 key-handling code, not as two
separate ideas that happen to share a name.

### 6b. generic application, and the dancing-zenki-ring match

**per the riff's own framing**: the C25519 forward/reverse asymmetry
generically solves **session discovery and creation**, while a **"home
zenki ring" at the core of the network** controls session setup —
filtering/routing by latency, bandwidth, priority, or reachability. this
is not new architecture — it maps onto an already-documented formation:

`data/md/protocol-7-knowledge/03_FORMATIONS/dancing_kittens_formation.md`,
Part 7 ["Reference Resolution Layer"] describes a **2-zenki ring** as the
stable transport-layer state, temporarily becoming a **3-zenki ring**
during a feeding/overwatch handoff — the just-saturated ground zenki stays
"accessible on ring" to answer questions / resolve references before
descending again:

```
Normal state (2 ring):        Handoff state (3 ring, temporary):
     6 ↻ 7                        6 ↻ 1 ↻ 7
    ╱     ╲                      ╱     │     ╲
═══════════════              ═══════════╪════════
 [2 3 4 5 1]                     [2 3 4 5]

                              Z1 accessible on ring!
                              Can answer questions!
                              Can resolve references!
```

the role split matches structurally, not just thematically: **feeding
zenki = session-bearing workers**, **ring zenki = gatekeeper/session-
controller**, filtering and routing exactly the way the ring decides
shift-changes [ by who's saturated / who arrived earliest — a capacity +
priority ordering, the same shape as the latency/bandwidth/priority/
reachability filtering the riff describes for session setup ].

also matches the "7 ZENKI ring" portal/gate concept in `crystal_desktop.md`
[ `06_INTERFACE_PARADIGM`, "Ring Gates in Crystal" ]: a glowing heptagon
ring is a portal — cursor enters at the ring, instant jump, emerges at the
destination ring, zero travel time. same core-of-the-network, controlled,
zero-perceived-latency entry/exit gating role as the dancing-zenki ring's
handoff period.

note on register: `dancing_kittens_formation.md` and `crystal_desktop.md`
are written in a decorative, high-enthusiasm style [ emoji, exclamation
points, "bioluminescence" framing ] — the structural claims cited above
[ 2-ring/3-ring handoff mechanics, ring-as-portal ] are taken at face
value as documented formation specs, not as evidence for the surrounding
narrative flourishes.

**not yet connected**: the specific mechanism by which a C25519 keypair's
forward/reverse asymmetry maps onto *which* zenki-ring role — does
"forward" identify the discoverable/public session address, and does
"reverse" [ the hard direction ] correspond to the ring-internal-only
control plane? flagged open, not resolved.

### 6c. the 5-of-7 match — resolved, not merely resonant

the riff also connected "5 of 7" directly to `TASK-CUBE-CONSENSUS-
ARCHITECTURE.md`'s BFT quorum:

```
quorum:  n=7, accept threshold 5 of 7 — standard BFT bound (n >= 3f+1)
         tolerates f=2 faulty/dishonest participants without losing
         correctness
```

`f=2` is precisely the dancing-zenki ring's size [ 5 feeding + 2 ring = 7
total ]. the initial reading of this match — that the 2 ring zenki are
malicious-tolerant peers under a symmetric BFT bound — was **superseded**
by a cleaner, independently-documented explanation:
`topic-node-group-geometry.md`, "5-of-7 as the natural consensus + litter
configuration":

> 5 active + 2 initialized-idle at the same coordinate
> 5 active = working majority for truth consensus — quorum always available
> 2 alternates = can absorb 2 simultaneous failures by promoting
> already-initialized nodes — no startup cost, already at position,
> already oriented in the field

this is neither symmetric BFT fault tolerance nor a fixed control caste —
it is **5 active + 2 initialized-idle alternates at the same coordinate**.
the 2 ring zenki are standby capacity, already oriented in the field, that
rotate into the working 5 by promotion [ the dancing-zenki "dance" itself:
longest-working feeder replaced by earliest-arrived ring zenki ] — a
cleaner match to `dancing_kittens_formation.md`'s actual mechanics [ ring
zenki descend and feed, feeding zenki ascend and take ring duty, on a
staggered T/2T rhythm ] than either "malicious-tolerant peer" or
"permanent control caste" would be.

`topic-node-group-geometry.md` states directly: **"5-of-7 and 2×13 are the
same harmonic structure at different scales"** — which folds back into
section 4's `bmw-L13` / 26-char [ 2×13 ] sizing note above: the 5-of-7
formation count and the doubled-checksum-length observation are not two
separate resonances, they are the **same harmonic ratio applied at the
node-coordinate scale and the checksum-length scale respectively**.

---

## 7. status summary

| section | status |
|---|---|
| 1. `-nest` truth-harmonization fix | **landed, tested 34/34, not yet committed** |
| 2. order asymmetry (parent = context) | **verified against running code** |
| 3. mutual/2nd-level harmonization | open — design riff, cost/termination unresolved |
| 4. third-checksum fast-reject | open — design-only, matches landed BMW384 precedent |
| 5. epoch_v7 layered resolution | open — design-only, composes 1 + 4 + already-landed epoch-join mechanism |
| 6. C25519 lambda / dancing-zenki / 5-of-7 | **cross-connection verified** across independently-documented sources; one sub-question [ 6b's forward/reverse-to-ring-role mapping ] still open |

no task files are being written from sections 3-5 of this doc. section 1
is already a closed, tested task
[ `data/yaml/coding-tasks/amos-chksum-nest-truth-harmonization.yaml` ]. a
future pass turning sections 3 or 4 into task files would need to resolve
the open cost/termination and encapsulation questions first.

#,,.,,,,.,.,,,,,.,.,.,,..,,,,,,,,,..,,,,.,,,.,..,,...,...,...,,,.,,..,...,...,
#4FMAMNODJWUYWLOX5LGKHKPRT4ZPZ6YJPECWXZM6FO6IJES3UNQFUJ4OPMNKNHHP7MNYWI43XWSQK
#\\\|TNSCCJH6PASZCZUWGMEUK5W53KWD5IERIFOIQEBVBZ5WCWL7CUN \ / AMOS7 \ YOURUM ::
#\[7]CJ6IB26KT4RD3VZJDBDNQQ2SJH5EA5KF2PO4OVDOUQD7KJ4VM4BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
