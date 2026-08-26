## [:< ##

# coding zenka change accounting — planned expansion

status: PLANNED, GATED — do not dispatch until the prerequisite stability
milestone below is met. session: 2026-06-20.

prerequisites (must be stable in production first):
- `data/tasks/coding-model-self-test-cycle.md` — calibration self-test
- `data/tasks/coding-self-error-processing-cycle.md` — runtime error
  classification, pattern library, upstream promotion

stability gate: both prerequisite cycles running in production with a
non-trivial confirmed-pattern library (i.e. the self-error-processing
pattern library has actually promoted at least one fix upstream and
confirmed non-recurrence) — not a fixed time period, a demonstrated
capability threshold.

## the gap this fills

the self-error-processing cycle tracks *error patterns* — what went
wrong and how it was fixed. it does not track *which specific statement,
in which specific file, for which specific reason* a given change
corresponds to. without that, two real risks compound over many
iteration cycles:

```
forgotten intent:    a later pass reverts or "simplifies" a line whose
                     correction reason was never recorded anywhere
                     specific to that line — the fix silently regresses
                     and the regression isn't even recognized as one

repeated cycles:     verification work already done for a given change
                     gets redone from scratch in a later task, because
                     there's no granular record that this exact
                     statement was already validated for this exact
                     reason
```

the fix is accounting at the granularity of a single changed statement,
not the file or task level — with deferred success resolution (you don't
always know immediately whether a change "worked"; the record needs to
support a verdict arriving later) and the ability for validation to
happen from multiple independent perspectives in parallel, all freely
cross-referenceable rather than siloed per-perspective.

## core mechanism

### per-statement change record

```
each individually changed statement gets its own tracked record:
  - location: file + line range (or AST-node id if available — line
    numbers shift under later edits, a more stable anchor is preferable
    if the codebase already has one; if not, this itself may be a
    prerequisite worth flagging separately)
  - intent: why the change was made, in the change-author's own words
    (human or model) — this is the field that prevents "forgotten
    change or correction intent"
  - status: pending | verified | reverted | superseded
  - group / subgroup membership (see below)
  - links to: the error pattern it addresses (if any, from
    self-error-processing's pattern library), the task that produced it,
    any validation records (see below)
```

### deferred success accounting

```
a change record's status does not need to resolve at commit time.
"pending" is a first-class, expected state — verification may depend on:
  - N subsequent task runs not re-triggering the original error
  - a later self-test cycle passing where it previously failed
  - a human or model review that hasn't happened yet

the record stays open until something actually resolves it. this is
the same resolution-test shape as self-error-processing's "re-run from
the round that caused it" — just applied per-statement instead of
per-error-pattern, and allowed to stay open indefinitely rather than
resolving in the same session.
```

**correction (2026-06-20, same session): completeness is a property of
the map, not of any individual record.** the actual compensation this
architecture makes is: defer resolution rather than demand instant
verification at full present complexity. what must NOT be deferred is
*tracking that the question exists at all* — every changed statement
gets entered into the map the moment it's changed, full stop, even
before anything is known about whether it's correct. the map is what
"allows no forgetting"; individual entries can stay open indefinitely
and get filled in gaplessly over time through whatever method becomes
available later (a review, a categorization pass, a later self-test
run) — none of which need to happen promptly, because the map already
guarantees the question won't be lost in the meantime. losing a pending
record from the map is the actual failure mode this exists to prevent;
a record staying pending for a long time is not a failure at all.

### two-stage representation: graphical map, then extracted topology

```
stage 1 (immediate): a graphical/visual map — the raw tracking
  structure, captured as changes happen, no extraction overhead

stage 2 (delayed, by design): mathematical topology extracted FROM the
  graphical map — arrives later, but once extracted is highly
  compressible and far better distributable than the raw graphical form

the delay in stage 2 is intentional, not a limitation — it's the same
deferred-resolution principle applied to the map's own representation,
not just to individual change records. the visual map is not a future
presentation layer over already-built data; it IS the primary
completeness-tracking structure. the math extraction is the
compression/distribution step that becomes possible once the visual
map has accumulated enough structure to extract from.

visual mapping and visual processing are naturally complemented by
visual memory — the same structure that does the mapping is also where
state actually persists, not a separate store with a visual view
bolted on.
```

### the LLM-specific value here (and why it doesn't need special trust)

```
the implicit threshold/proportion-factor tree logic (dynamic buffers,
below) will eventually recognize a desirable change on its own, once
enough statistical signal accumulates. an LLM's value isn't safety-
related — the deterministic intent->requirements->code compilation
already handles that (see [[project-zenka-macro-language-postponement]])
— it's TEMPORAL: recognizing the same desirable change earlier than the
implicit logic's own threshold would trigger, often because the LLM (or
any zenka, LLM or not) has genuinely additional context the structural
network never sees — a user-announced upcoming intent change, an
expected event, an explicit adjustment request communicated out of
band, not just sharper pattern-matching over the same data.

this requires no special privilege or trust elevation: an LLM
participates through the same safe zenka interface any other (LLM or
non-LLM) zenka would use to flag/propose a priority change. safety is
preserved because the TARGET decides how to process its own stacks and
prioritize conflicting requests from separate sources — not because the
source making the request is specially trusted. early recognition is
just one more input into prioritization logic the target already has
to run regardless of who's asking.

reuse, not new infrastructure: curve-mapping-based prioritization
already has generic design files and modules started (`base.curve.*`,
see [[topic-base-curve-system]]) — the same mechanism already used for
volume/visual fades is the natural fit for this too, not a new
primitive to invent.

the closing principle this generalizes to: every layer in this whole
pipeline is optional — LLMs included — but all layers overlap
perfectly, so they fade in and out seamlessly rather than handing off
at a hard cutover. "translucency" is the literal generalization of the
curve-mapping weight above: not binary present/absent, a continuously
dynamically-calculated value per layer. that's what makes "optional"
and "load-bearing whenever actually present" compatible without
contradiction — the same property that makes the no-stale-reference
guarantee and the completeness-via-bounded-nesting property hold
together as one coherent structure rather than a stack of independent
patches.

"translucency" should not stay a metaphor for a scalar weight. its
logical implementation destination, consistent with this project's own
visualization-is-implementation stance (the graphical map IS the data,
not a view over it — see two-stage representation above), is literal
2D and 3D bit matrices where translucency is a real rendered property
of the structure itself. the visual map's translucency and the layer's
actual current weight should end up being the same number read two
ways, not two numbers kept in sync.

taken to its conclusion, this unites intent (per
[[project-zenka-macro-language-postponement]]'s intent->requirements->
code chain), state (the change-accounting map's tracked records), and
implementation (the generated code itself) into one mapping with the
exact same geometry — three readings of one object, not three layers
requiring separate representations kept in sync with each other. this
is the identical structural claim `VORTEX-LAYER-IRIS-CONNECTION.md`
already makes for the iris / layer-stack / vortex (one object, three
simultaneous views) — recognized here again from a different starting
point, which is itself the kind of convergent confirmation
[[topic-synchronous-multi-legged-pattern-extraction]] describes: not
borrowed, independently arrived-at and structurally identical.
```

### self-calibrating complexity via dynamic buffers (precedented pattern)

```
importing this system has a fixed minimum complexity cost, but that
cost does NOT grow linearly with the density/total volume of layered
data integrated into it. instead, the system tracks its own statistics:
  - how parallelizable the current complexity actually is
  - average number of cycles until a successful (resolved) result
    historically arrives

from those self-observed statistics, it calculates dynamic buffers —
adaptive thresholds enabling fine-grained process control, instead of
fixed/manual limits.

this is NOT a new mechanism to invent — it is the exact same shape as
`coding.self_test.multiplier` (already implemented this session):
percentile_95(TTFT samples) × 1.5 → adaptive timeout multiplier. apply
the identical pattern here with "cycles until resolution" in place of
TTFT: percentile_95(resolution_cycle_counts) × safety_factor →
dynamic buffer threshold for how long a pending record may reasonably
take before it's flagged for attention (NOT auto-failed — see
completeness-of-the-map note above; flagging for attention is not the
same as forcing resolution).
```

### locality during processing, atomicity after resolution

```
while a change record is actively being processed (any validation
perspective working on it), it is pinned in a local buffer near its
point of work — zero-travel proximity, no need to distribute it
elsewhere in the system while it's still in flux. storage during this
phase is explicitly a buffer awaiting integration, not a final record.

once integration completes and the result has demonstrated applicable
usefulness, the record transitions: it becomes free-travel-prioritized
and atomic — freely referenceable elsewhere by its target pattern alone,
with no requirement to carry its auxiliary processing context along.
delivery from that point is semi-synchronous or fully deferred,
whichever the consumer needs — the record no longer cares, because it's
already complete and self-contained.
```

### grouping and subgrouping

```
group:     typically one task/fix — all statements changed to address
           one identified problem
subgroup:  finer subdivision within a group — e.g. by file, by
           function, or by which specific error-pattern (if a single
           task fixed multiple distinct patterns at once, as happened
           tonight: bracket-syntax bugs, hashref-access bugs, and the
           closure/factory mismatch were three distinct subgroups
           within one task's changes)

grouping is for navigation and rollup status (did this whole group
verify?) — it is not exclusive; a statement can belong to a group
without that group owning exclusive interpretation rights over it (see
free referencing, below).
```

### queue topology and entry shape (answers "how does attention get
allocated to a flagged-pending record" from the dynamic-buffer section)

```
priority range is self-scaling: with N elements currently in the
queue, priorities run from -N to +N — the range is always exactly as
wide as the current population, not a fixed constant.

-N is the jump-the-queue value: hitting it means immediate processing,
ahead of everything else.

processing order is ascending (lowest existing number next) —
sequential one-at-a-time, or dispatched together when running in
parallel.

high positive numbers are deliberate slack, not low priority: ample
workspace for reference-chained, not-yet-urgent dependencies to sit and
get organized before they compete for attention at all.

queue entries ARE the group/subgroup structure above, concretely:
each entry = a task-file/title reference + an ordered block of subtask
segments (the group's member change-records / subgroups). entries can
expand recursively — a subtask segment can become its own nested
sub-block — and doing so grows that task's body-block, which (via the
self-scaling range above) proportionally widens the whole queue's
priority range rather than needing separate accounting for it.

processing modules sit in rotating rings around the processing core
(same primitive as `TASK-CUBE-CONSENSUS-ARCHITECTURE.md`'s face
rotation), kinetically decoupled from each other — no module blocks
another directly — but freely chainable by reference, so an incoming
urgency change propagates as an exact-offset resource retuning rather
than a full requeue/recompute.

practice (apply immediately, not gated on the rest of this doc): before
a block of subtask segments, a queue entry can reference matching
`data/yaml/reasoning-templates/*.yaml` documents when one exists for
the task's actual shape. this is `relative-direction-of-intent.yaml`'s
own mechanism turned on the dispatch workflow itself — a template name
is a direction vector, pulling in a full reasoning picture for a
fraction of the tokens needed to re-derive the same framing inline.
when dispatching to kimi (or any executor), include the matched
template's content directly in the dispatch prompt rather than just
naming it, so the executor gets the primed perspective without an extra
round-trip to fetch it.

planned implementation shape for the matching itself: a best-of tree
search over candidate contexts, not a flat lookup. each node carries a
top-<n> value that is simultaneously the count of highest-ranked
entries already displayed AND the current display limit — the same
number serves both roles. <n> is dynamically adjustable via pinnable
context tags, but those tags suggest adjustment BY REFERENCE to other
tree positions, never by fixed value — so the resolved number is always
read live from whatever those referenced positions currently hold, not
a cached snapshot. this is what allows the tree to shift and readjust
in parallel without coordination: nothing is ever stale because nothing
absolute was ever stored, only relationships were.
```

### parallel perspective (layered) validation, with free referencing

```
multiple validation perspectives can assess the same change record
independently and in parallel:
  - different models (consistent with self-error-processing's shared
    assertion-criteria rubric, applied here per-statement)
  - different concerns layered over the same code (correctness,
    style/convention adherence, performance, security) — same shape as
    /code-review's low/medium/high/ultra effort tiers, but persisted as
    records instead of one-shot output

"free referencing" = non-exclusive: a validation record from one
perspective does not block or override another perspective's record
for the same statement. they coexist and can reference each other.
this matters specifically because perspectives can legitimately
disagree (e.g. "correct" from a pure-logic perspective but "violates
project style convention" from a style perspective) without either
verdict needing to be discarded — both are valid data about the same
statement from different layers.
```

## relation to existing infrastructure

this is explicitly meant to reuse what's already staged, not invent new
primitives:

```
self-error-processing's pattern library  → the per-statement record's
  "intent" field can directly cite a pattern-library entry when the
  change was a confirmed-pattern fix, avoiding duplicate explanation

self-error-processing's shared assertion-criteria rubric → reused
  directly as the criteria each validation-perspective record is
  scored against, so statement-level and pattern-level verification
  use the same yardstick

self-test cycle's epoch-scoped archival schema
  ($data{coding}{self_test}{$epoch}{$model_id}) → same epoch-scoping
  pattern reused for change records:
  $data{coding}{change_accounting}{$epoch}{$change_id} = { ... }
```

## future presentation framing (not part of the buildable core — vision-stage)

note: the graphical map itself is core infrastructure (see two-stage
representation above), not vision-stage — what's deferred here is
specifically the mandala/rotation *presentation* of that map, not the
map's existence. flagged separately so the concrete spec above doesn't
get tangled with unbuilt presentation ideas. relates to [[topic-cube-tree-dashboard]],
[[topic-ascii-minimap]], `VORTEX-LAYER-IRIS-CONNECTION.md` (rotation as
the same object seen from different angles — directly applicable here:
a "mandala" view rotated 90°/45° per cycle would be showing the same
change-accounting structure from different layered-validation angles,
not different data).

the routing material (shorter parent checksums non-exclusively grouping
longer ones — a routing optimization, not a collision, per existing
[[topic-checksum-parenting-namespace-trees]] / [[topic-key-tree-ring-routing]])
maps onto this system's group/subgroup structure directly: a group's id
could legitimately be a shorter checksum prefix, with member statement-
records addressed by longer checksums under it — same non-exclusive-
grouping principle already established elsewhere in this project, reused
rather than reinvented here too.

ring-becomes-disc-under-minimum-distance-constraint (negotiated
reference topology) is noted as a real structural idea but not yet
connected to a concrete need in this specific system — revisit if/when
the validation-perspective layering above needs an actual spatial
addressing scheme rather than a plain hierarchical group/subgroup tree.

### addressing and the no-stale-reference guarantee

```
each item is addressed by its full BASE32-encoded C25519 public key —
the same addressing primitive already established elsewhere in this
project (see [[topic-key-tree-ring-routing]]). parent keys form a
potentially externally-expanding structure that this system does not
need to know about locally in advance — the addressing scheme is open
by construction, not closed over a fixed known tree.

the mapped structures are actively cross-referencing, not passive, and
every level carries a catch-all branch whose job is reassertion and
rerouting: whenever a reference would otherwise go stale (through
whichever kind of unreferencing — an external rename, a moved parent
key, anything), the catch-all reasserts/reroutes it automatically.

critically: falling through to the catch-all IS itself advancing, not
a failure state requiring recovery. it's guaranteed, and already
triggered the moment staleness would otherwise occur — there is no
separate manual recovery step. the time from fallthrough-detection to
the resulting improvement being applied is bounded only by inference
latency and routing-chain hops, NOT by the full apply → sign → test →
sign formal verification pipeline; the catch-all operates decoupled
from and faster than that slower cycle.

consequence: there is no abyss. no reference can fall into permanent
limbo, defined by simply never arriving, regardless of how unlikely
or outlier the case — the guarantee is universal by construction, not
probabilistic/best-effort.

this guarantee is self-motivating, not externally imposed: an
"unlucky"/undefined item propagates downstream as degraded latency for
everything chained after it — since the system optimizes for lowest
latency across all elements, tolerating even one undefined state is
already against its own objective. preventing the abyss is therefore
in the system's own interest, not a correctness rule bolted on top of
an otherwise indifferent optimizer.

structurally, this is implemented as a multi-ring-deep, dyson-sphere-
like arrangement of satellite-style processing nodes (consistent with
[[topic-orbital-data-space]]'s zenki-as-satellites model) handling
routing, rerouting, and external-accessibility translation — enough
redundant elements at enough depth that there is always a well-defined
next step available for any fallthrough item. self-optimizing, with
overhead kept limited but sufficiently buffered for high-bandwidth
processing cores/clusters, compensating for the vertical (nested) ring
structure's own overhead rather than letting it accumulate unbounded.
```

## open questions before this can become a dispatchable task

```
- stable per-statement anchor: RESOLVED (this session) — addressed by
  full BASE32-encoded C25519 public key, per "addressing and the
  no-stale-reference guarantee" above. still needs an actual
  implementation check: confirm this project's existing key-tree
  infrastructure ([[topic-key-tree-ring-routing]]) can issue keys at
  per-statement granularity without that becoming its own bottleneck.
- where do validation-perspective records actually get triggered from —
  manually invoked, or automatically on every change accounting entry?
  automatic-on-every-change may be expensive; needs a policy.
- does "deferred" success accounting need a cleanup/expiry policy of
  its own (a record pending forever with no resolving event), or is
  "stays open indefinitely" the actually-intended behavior?
```

#,,,,,,,.,,.,,,,.,..,,..,,.,.,,..,,..,..,,..,,..,,...,...,...,,,.,,,,,..,,...,
#IAJ6WVFD3A4WTA52NEG6K7DGQNCGAFOIBV5JPPPVQUQTRNR4MW3FNSZSVDG4MAIREWSKEZH5WBIHW
#\\\|WO3N5DU352QEN56KMWBS5AN7PTJSIUNFMYDXMXLKTCG6KCEYW7H \ / AMOS7 \ YOURUM ::
#\[7]3IZ6YOF55JPGZPCE5T6HQN3XOZBEQOGQIIX4S2MZVTSHULCGTGAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
