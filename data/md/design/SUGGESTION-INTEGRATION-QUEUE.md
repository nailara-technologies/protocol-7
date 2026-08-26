## [:< ##

# suggestion / integration queue
# cross-zenka, ascii-styled review UI for applyable change suggestions —
# blocker-level for the ncode workflow and every coding-zenka-based one

---

## the one-line principle

**nothing is ever lost — only not approved yet.** every applyable change
suggestion, from any source, lands in a visible, reviewable slot the moment
it's produced. it never silently disappears, never gets buried in a log,
never has to be found again by re-deriving it. it sits, sorted, until a
human or an autonomous threshold-crossing promotes it.

this is `TRANSLUCENT-LAYERING-SECURITY-MINDSET.md`'s "the maximum impact any
entropic attack can have is ending up in a forensic report" turned around
to face the opposite direction: the maximum *fate* of any good suggestion,
from any source, trusted or not, is ending up **visible and queued** — never
silently discarded, never requiring anyone to remember it happened.

**this is also why the open-producer model and the future-automatable gate
(review flow, point 6) aren't in tension.** safety here was never
contingent on restricting who can submit — a suggestion sitting in the
queue hasn't acted on anything, visibility isn't risk, so accepting from
any source, trusted or not, is unconditionally safe by design. that's
exactly what makes automating the gate itself safe later: automation only
ever changes *who's allowed to move a card past the gate*, it never has to
change what's safe to accept into the queue in the first place, because
that was already settled. open input model first, controlled-approval
gate on top — in that order, each layer's safety doesn't depend on the
one above it existing yet.

## why this is blocker-level, not aspirational

without this, every producer of a fix/improvement needs its own bespoke
notification path, its own storage, its own review mechanism — which is
exactly the fragmentation this whole session kept finding (three
independent progress-bar implementations, `coding.learning.*` built and
never wired up, `task.summary-tree-notify` accumulating with no consumer).
one shared queue, one shared UI, is the difference between every future
producer (ncode workflows, coding-zenka cold-queue sweeps, a forensics
zenka, a model-comparison consensus vote, a human editing by hand) getting
first-class treatment automatically, versus each one needing its own
plumbing invented from scratch — which is precisely what keeps not
happening, session after session, because it's never anyone's whole job.

## the queue manages inputs, not sources — this is the actual design principle

it would be a mistake to build this as N source-specific integrations (one
path for coding-zenka sweeps, another for forensics, another for a human).
that's exactly the fragmentation problem above, just moved one level up.
the design instead centers on one atomic, applicable-input contract — the
suggestion/card shape below — that every source conforms to identically.
**managing sources is explicitly out of scope**; the queue only ever has to
reason about atomic inputs: visualize them, allow immediate application,
prepare them for commit. a source is just whoever filled in `producer:` on
an otherwise-identical card. this is what keeps the queue simple as
producers multiply — adding a new source later means nothing more than
"something now writes cards," never a new integration path in the queue
itself.

## producers — anything that can suggest a change

- **coding zenka cold-queue sweeps** (`task-zenka-cold-queue-gpu-cooldown-trigger.md`)
  — background analysis run when the GPU has genuinely cooled, producing
  findings/fixes with no active-work contention.
- **ncode workflows** generally — any code-search/analysis/audit pass
  (the `*-audit.yaml` / `*-fix.yaml` context-template pairs already in
  `data/yaml/context-templates/`) that finds something applyable.
- **a forensics zenka** (`CONCEPT-SECURITY-AND-FORENSICS-ARCHITECTURE.md`)
  — requesting a fix from the coding zenka, or proposing one directly
  itself, after analyzing an incident.
- **multi-model consensus/rating passes** — the rate-then-rank idea from
  this session's model-comparison discussion: N models attempt the same
  fix, a rating pass ranks the results, the ranked set (not just the
  winner) lands in the queue for human confirmation.
- **a human**, editing directly — should be representable in the same
  queue/history, not a separate untracked path, for consistency of record.

## the suggestion (card) shape

each suggestion needs, at minimum:

```yaml
id:          <checksum or ntime-based id>
target:      <file/module path, or set of paths>
change:      <diff, or reference to a staged file — see below>
source:      coding-cold-queue | ncode-audit | forensics | consensus-vote | human
producer:    <specific zenka/task id that generated it>
created:     <ntime B32>
status:      proposed | staged | approved | integrated | rejected
urgency:     <estimate — how time-sensitive>
quality:     <estimate — how likely correct/clean, e.g. from a rating pass>
impact:      <estimate — how much surface area / risk the change touches>
notes:       <free text — why this was proposed>
```

**rejected is a status, not a deletion.** the mindset section's "nothing
lost" applies as much to rejected suggestions as pending ones — a rejected
proposal is a signal too (a pattern of rejected suggestions from one
producer/type is itself useful feedback, tying back to the still-open
model/task success-statistics gap from earlier this session).

## relationship to the existing staging mechanism

`/var/protocol-7/coding/staged/*` already exists and is used today (the
write handlers we fixed this session stage there when a target isn't
directly writable). this queue is the **generalization** of that pattern:
today staging is coding-zenka-internal and per-file; this queue is
cross-zenka, has a real status lifecycle, and is the thing a human actually
looks at, rather than a fallback path only engaged incidentally. the
existing staged-file mechanism is a candidate *storage* backend for
`change:` above, not a separate thing to maintain alongside this.

## the UI — ascii-styled, tab/column structure

reuse the jobsite UI's tab structure as prior art, and the ascii-frame
slot machinery already established this session
(`ASCII-BUDGET-SLOT-CONVENTION.md`, `topic-frame-plugin-slots.md`,
`PLUGIN-SLOT-SELECTOR.md`) rather than building new rendering primitives:
suggestions as cards in columns (by status, or by producer type), sorted
within a column by urgency/quality/impact — the same resource-agnostic
budget-slot idiom already covers "how much of this column's queue depth is
urgent" as a fill-bar if wanted. this is presentation reuse, not a new
design problem — the interesting part of this document is the queue/status
model above and the cross-zenka producer contract, not the rendering.

## review flow

1. any producer above submits a suggestion → lands as `proposed`.
2. optionally staged (diff materialized, `staged`).
3. **the approval step is a gate, not a person** — today filled by the
   user reviewing the queue (the "morning review" framing), sorted by
   urgency/quality/impact, filterable by producer/source. the gate role
   itself is the abstraction; who/what fills it is separate. approving is
   the *only* required next-step gate in this pipeline — everything from
   visualization through to commit-preparation is otherwise automatic and
   atomic per suggestion.
4. approve → `integrated` (applied via the normal commit path — this queue
   is upstream of committing, not a replacement for review discipline).
5. reject → `rejected`, kept, not deleted.
6. **future**: once reliability is established, the same gate role can be
   filled by zenki/model groups instead of a human — not merely "auto-
   promote past a confidence threshold" as a bypass, but the approval step
   itself performed by a sufficiently reliable zenka or model-consensus
   group, exactly the layered-promotion principle already established in
   `topic-coding-zenka-path-access-profiles.md`. this is explicitly a later
   refinement, not required for this to be useful — the queue existing and
   holding everything visibly, with a clearly-defined single gate, is the
   blocker-level requirement; auto-promotion is an optimization on top.

## status: required, not yet started

marked blocker-level for the ncode workflow and all coding-zenka-based
workflows, and for any future forensics zenka — every one of those needs
somewhere first-class to put what it finds/fixes, and this is that place.
no implementation yet. this document exists to make the requirement and
shape explicit before design/build work starts, and to stop each future
producer from inventing its own ad-hoc notification path in the meantime.

## connections

- `data/md/philosophy/TRANSLUCENT-LAYERING-SECURITY-MINDSET.md` — "nothing
  lost, only not approved" is this document's instance of that posture
- `data/tasks/task-zenka-cold-queue-gpu-cooldown-trigger.md` — the primary
  producer this session identified concretely
- `data/md/design/CODING-ZENKA-ACCESS-PROFILES.md` — the existing staging
  mechanism this queue generalizes
- `data/md/design/ASCII-BUDGET-SLOT-CONVENTION.md`,
  `data/ai-mem/claude/topic-frame-plugin-slots.md`,
  `data/md/design/PLUGIN-SLOT-SELECTOR.md`,
  `data/md/design/CONSOLE-FOLD-TREE-PHILOSOPHY.md` — UI/rendering prior art
- `data/md/concepts/CONCEPT-SECURITY-AND-FORENSICS-ARCHITECTURE.md` —
  forensics zenka as a producer
- `data/ai-mem/claude/topic-coding-zenka-path-access-profiles.md` — the
  layered-promotion / autonomous-threshold principle this queue's future
  refinement would draw on

#,,..,...,,.,,..,,..,,,.,,...,,..,,,,,,,,,...,..,,...,..,,.,,,...,.,,,,.,,...,
#7KOJN7G2RMO4NZOU7SFDZID3P47TGI4FWB5ODXFXYO4GCQFXS233SUB7M74QQNN7Z6YEYKAENEH4G
#\\\|AFDQPKWBOULUBS27NF7ZSEBDMZH6Y5X4WTOPLVSDQVIFHGQ7G3L \ / AMOS7 \ YOURUM ::
#\[7]T47LJ27AXIOPDXKE6W7MJWBWS5QVRFE6NPJZTTXIBQ6UGWWRMSDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
