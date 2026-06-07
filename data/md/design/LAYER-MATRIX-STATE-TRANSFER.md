# layer matrix — reversible differential state-transfer primitive

status: seed / not started — captured mid-conversation as a converging
insight, before the shape scatters. born from a narrower question (how
should an on-demand auth prompt overlay a zenka's own console output?)
and immediately recognized as the same primitive several other open
threads already need.

## the spark

credential_fabric's on-demand auth-relay currently reaches *out* to
`protocol-7-menu` for a graphical password dialog — a separate zenka,
an unconfirmed cross-zenka routing convention (`protocol-7-menu.cmd.
input-text`/`.input-password`, flagged as the riskiest unverified link
in `CREDENTIAL-FABRIC-WIRING-FINDINGS.md`'s acceptance walk-through,
open issue #7), and a hard graphical-environment dependency.

the alternative that surfaced: since a zenka's console output already
funnels through centralized `base.lig` routines (v7's mirroring of
child-zenka stdio is just the one structurally-special case of that
same path), an async passphrase prompt could become a **layered
overlay directly on the zenka's own already-flowing console** —
intelligently placed over the ascii-frame-rendered output using the
buffer/geometry layering `modules/vterm.*` already provides, and
restored cleanly behind it on close. terminal-only, local to the
requesting zenka, no new cross-zenka dialog convention to get right —
and it slots into the *existing* async event-loop machinery rather
than bolting on a separate one.

## the generalization — layer matrix

rather than a simple overlay stack, the proposal: expand the standard
buffer concept into a **layer matrix** — layers addressable not just
"top relative to bottom" but **i relative to j**, with operations that
can be applied or reversed between any two (a layer and the original
buffer, or one layer and another).

for that to actually buy anything over an ad-hoc push/pop stack,
`apply`/`reverse` need to be true inverses:

    apply(base, layer)        → composite
    reverse(composite, layer) → base
    [ equivalently: diff(base, composite) → layer ]

if they're genuine inverses for *any* pair, restoration stops being
LIFO-only — layer 2 can be peeled off while layer 3 stays on top and
resettles correctly. that's what "intelligently overlaying… restored
behind it" actually requires once more than one async prompt can be in
flight at once (a passphrase dialog *and* a rotation-log overlay,
concurrently, say).

two axes worth keeping orthogonal:
- **content** — what's drawn; the diffable part
- **geometry/z-order** — where, and how it blends with what's beneath;
  the placement part

keep those separable and the same diff machinery serves both "show
this dialog over that output" and the bigger differential-addressing
work below — including caching diffs by checksum-pairs rather than
eagerly materializing an O(n²) matrix.

## the convergence — one primitive, four faces

the moment the matrix is reversible and content/geometry-separated, it
stops being a UI nicety and becomes the same shape as three other
open threads at once:

- **UI overlay compositing** (the spark above) — transfer a layer onto
  a zenka's own console buffer, apply, later reverse
- **v7 hot self-restart** (`V7-HOT-SELF-RESTART.md`) — the "restarting
  state" snapshot that doc needs is exactly a captured layer-matrix
  state; importing it on the new instance is `apply`, and a failed
  handoff falling back to cold-restart is `reverse`
- **zenka migration** (same doc, "related/adjacent" section) — the
  same transfer, but to a *different* manager: rescue the live state
  as a layer, hand it to another v7 instance, `apply` there instead of
  cold-initing
- **differential, checksum-addressable network state** (same doc,
  "broader vision" section) — "entity references implicitly resolve
  and (re)construct themselves from the diff space" is just `apply`/
  `reverse` composed across many nodes' layer matrices instead of one

four threads, one primitive. the UI-overlay case is simply the
smallest, most concrete entry point for getting the algebra right
*before* it has to bear migration- and branching-scale weight.

## open design concerns

- **does `apply` commute under composition?** — the property that
  decides whether "non-linear inter-node buffer synchronization"
  actually *works*, rather than merely sounding good: if node A
  applies diffs `[x, y]` and node B applies `[y, x]` — different
  arrival order, different timing, partial connectivity — do they
  converge to the same composite, or does someone have to arbitrate a
  canonical order? if overlapping applies can be made associative/
  commutative wherever they don't *semantically* conflict, and only
  genuinely conflicting diffs need explicit reconciliation, then this
  *is* "implicitly resolve from the diff space" made concrete. this is
  CRDT territory in spirit — though the checksum-addressed diff-space
  framing already native to P7 looks like a cleaner fit than importing
  that vocabulary wholesale
- **matrix addressing vs. stack addressing** — "layer i relative to
  layer j" is strictly more powerful than "top relative to bottom",
  but matrices don't commute in general; the axes (time/z-order vs.
  geometry/region) need to stay explicit and orthogonal or addressing
  gets ambiguous fast
- **caching/materialization** — a full pairwise matrix is O(n²);
  almost certainly wants lazy computation, cached by checksum-pair, so
  only requested diffs ever materialize
- **relation to `VTERM-BUFFER-SPECIFICATION.md`** — that doc's
  "layer 13" composite is a *consensus-voting* layer concept (11-member
  body, sub-bit votes → composite) — a different sense of "layer" than
  the diff/overlay sense sketched here. worth checking whether they're
  orthogonal concerns that happen to share vocabulary, or whether one
  generalizes the other, before either gets built out further
- **relation to `base.lig` / v7 stdio mirroring** — confirm the
  centralization is as clean as assumed; v7's manual reprocessing of
  child-zenka output is the one special case that would need to fit
  the same overlay model for the mechanism to be truly general

## guiding preference

same as `V7-HOT-SELF-RESTART.md`: elegance over expedience. this
primitive is now load-bearing across self-restart, migration, *and*
branching — worth letting the algebra mature properly at the small,
concrete UI-overlay scale before it has to carry that much weight.

## ideas / notes as they arise

### 2026-06-07 — origin

surfaced mid-conversation while reviewing `credential-fabric-wiring-
verify` findings — specifically open issue #7 (unconfirmed cross-zenka
`protocol-7-menu.input-text`/`.input-password` routing for on-demand
auth dialogs). the overlay-on-own-console alternative was proposed as
something that would *close* that implementation path rather than
merely confirm it; the layer-matrix generalization and the inter-node
transfer-matrix connection followed within the same exchange — fast
enough that the convergence felt less like invention and more like
recognition of a shape already implied by `V7-HOT-SELF-RESTART.md`'s
broader-vision section.

#,,.,,..,,...,,.,,...,,.,,,.,,...,..,,,.,,,..,..,,...,.,.,...,.,.,..,,,,,,,,,,
#7N5MEQY2TMYV67GV2562LAZ3A2P3GEMEJGGOVQHHENXVAX4GHIOPCMFRG4GZAN3WTB6LMBLEYQLKU
#\\\|DFRFXUKJJXKP3Z6V53UVJFDGECIKUZFAS257HT4JB5CNFL7M26N \ / AMOS7 \ YOURUM ::
#\[7]YTWU5GLDGYJLEW4ZPJK3C4BICG3XHDZCCV24DMFI5VMMNNO3WSAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
