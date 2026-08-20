# Memory Tree System — Design

> a living, weighted memory tree that renders itself at any density.
> same data, different focus. the tree IS the intelligence.

## status

design. drives implementation dispatches (see `data/tasks/memory-tree-*.md`).
nothing here is built yet — this document is the contract the task files satisfy.

---

## 0. the problem with flat memory

`context.memory.load` reads `data/ai-mem/*.md` and returns one flat markdown
string, sorted only by file size, truncated to a char budget. it has no notion
of *what matters right now*. every load looks the same regardless of what the
user is doing. the MEMORY.md file itself is a hand-curated tree of links that a
human re-balances by hand each session — that curation is exactly the work a
machine should do continuously.

the memory tree replaces flat-string loading with a **dynamic weighted tree**:
each branch shows only its top-N weighted children; the whole tree compacts or
expands by tuning N per node; weighting responds to a focus vector that the
user, the active task, and recent commands all push on. it renders on-demand
through `ascii.frame.*`, so the same structure drives the terminal, GTK3, the
web, and LLM context injection.

the harmonic constant is 13 (`base.curve.eval('quantized')` snaps to 13 steps).
the default top-N is 7 — the reference-bubble formation size (5+2). these are
not arbitrary; they are the project's native numbers.

---

## A. architecture overview

the memory tree is a single in-memory structure anchored at `<memory.tree>`
inside the memory zenka's `%data`. it is built from **source adapters**, scored
in **three passes**, rendered through **ascii frames**, and periodically
**deduplicated/summarized** by the coding zenka.

```
                          source adapters
   file ─┐  session ─┐  git ─┐  chat ─┐  task ─┐  index ─┐
         └──────────┴───────┴────────┴────────┴─────────┘
                              │  normalize → universal leaf
                              ▼
                       <[memory.tree.insert]>          ── lifecycle ──
                              │
                              ▼
                    <[memory.tree.score]>   (three-pass weight)
                       1. base.sort        baseline entropy/recency
                       2. focus re-sort    <memory.focus> boost vector
                       3. base.curve.eval  rank-position falloff
                              │
                              ▼
                    <[memory.tree.render]>  → top-N per node
                              │
            ┌─────────────────┼──────────────────┬───────────────┐
            ▼                 ▼                  ▼               ▼
   ascii.frame.render  .render.color     .render.html    .render.data
      (LLM context)      (ANSI term)        (web)          (GTK3)
                              │
                              ▼
                  coding zenka dedup/summarize wave
                   (N-threshold | timer | explicit)
                              │
                              ▼ summary nodes replace leaf clusters
                       back into <memory.tree>
```

**lifecycle of a node:** insert → sort → curve-weight → render → (eventually)
dedup wave folds it into a summary node or evicts it to the ghost layer.

the tree does not know git from chat. every leaf is the same shape. that
uniformity is the whole point — adapters do the source-specific work once, at
the edge, and everything downstream is generic.

---

## B. node schema

one hashref shape for all three node types, discriminated by `type`. stored as a
nested tree under `<memory.tree>`; children are an arrayref (ordered after
scoring) so render can take the top-N by slicing.

```perl
## universal node — every node has these ##
{
    type         => 'root' | 'branch' | 'leaf',
    id           => $content_hash,     ## content-addressed identity
    title        => 'CRITICAL',        ## short label for the title bar
    ntime        => $ntime_b32,        ## creation / last-touch ntime (BASE32)
    content_hash => $amos_chksum,      ## AMOS checksum of canonical body
    score        => 0.0 .. 1.0,        ## last computed weight [ pass 3 output ]
    curve_type   => 'gaussian_pulse',  ## falloff shape for this node's children

    ## branch / root only ##
    children     => [ \%node, \%node, ... ],   ## scored-ordered
    n_visible    => 7,                 ## top-N to render at this node
    n_inherit    => FALSE,             ## children inherit my n_visible ?
    n_max_cap    => 13,                ## hard cap on n_visible at this depth
    subtree_hash => $merkle_chksum,    ## content.tree.checksum of children

    ## leaf only ##
    source_type  => 'file'|'session'|'git'|'chat'|'task'|'index',
    body         => $text,             ## the actual content fragment
    source_ref   => 'data/ai-mem/claude/feedback-ntime.md#CRITICAL',
}
```

design choices:

- **content-addressed at every level.** `id` is the content hash; `subtree_hash`
  is a merkle roll-up via `context.tree.checksum.*`. this is what makes
  `memory.tree.diff` and checkpointing cheap — two trees are equal iff their root
  `subtree_hash` matches, and divergence localizes by walking where hashes
  differ. dedup at the leaf level is just hash-equality.
- **ntime is BASE32 but NOT lexically sortable in `encode_b32r` form.** per the
  ntime feedback, recency comparison must go through
  `<[base.ntime_BASE32_to_numerical]>` before any numeric ordering. adapters
  store the b32 string; the scorer converts on read.
- **`curve_type` lives on the node, not globally.** a branch decides how weight
  falls off across *its* children. `CRITICAL` uses `gaussian_pulse` (sharp — only
  the very top survives, via the peak-half mapping in pass 3); `Active Topics`
  uses `quantized` (13 harmonic bands); an archive / git / session branch uses
  `exponential` (recency decay, old stuff fades). NOTE the falloff orientation is
  curve-family-specific — see pass 3 in section C; the prose intent here ("top
  matters", "old fades") is only correct once the `rank_falloff` helper orients
  each family.
- **`n_inherit` + `n_max_cap` break the N-tuning cascade.** setting root
  `n_visible = 5` for a compact overview must NOT silently force every descendant
  to 5 leaves — that would amputate deep detail. inheritance is opt-in per node,
  and each depth caps its own N so a global zoom-out degrades gracefully instead
  of collapsing.

`%data` anchors (consistent with `<base.curve.compose>->{$id} = {...}` syntax):

```
<memory.tree>           ## the root node hashref
<memory.tree.index>     ## id → node ref, flat lookup for O(1) touch/dedup
<memory.focus>          ## focus vector { topic => boost }
<memory.cfg>            ## defaults: n_visible, curve_type, decay rate
<memory.ghosts>         ## evicted nodes, faded via exponential curve
```

---

## C. three-pass weight algorithm

scoring is per-branch: each branch scores its own children, then orders them.
score is the product of three passes, each in [0,1].

### pass 1 — baseline (entropy / recency)

`<[base.sort]>` / `<[base.sort-num]>` give the deterministic baseline. recency
dominates: newer ntime → higher base weight. ties broken by `content_hash` so
ordering is stable and dedup-detectable.

```perl
## convert b32 ntimes to numbers, normalize to [0,1] over the sibling set ##
my @num = map { <[base.ntime_BASE32_to_numerical]>->( $_->{'ntime'} ) } @kids;
my ( $min, $max ) = ( min(@num), max(@num) );
$_->{'w_base'} = $max > $min ? ( $num[$i] - $min ) / ( $max - $min ) : 1
    for ...;
```

### pass 2 — focus re-sort (dynamic, externally influencable)

the focus vector `<memory.focus>` is a small hashref `{ topic => boost_factor }`.
a node matches a focus topic when its `title`/`body`/`source_ref` contains the
topic token (and, when the index integration is live, when
`index.cmd.lookup` returns it for that topic — see section G). matching nodes
get their weight multiplied by the boost.

```perl
my $w_focus = 1.0;
while ( my ( $topic, $boost ) = each %{ <memory.focus> } ) {
    $w_focus *= $boost if <[memory.focus.matches]>->( $node, $topic );
}
## focus is multiplicative and bounded so a single topic can't dominate ##
$w_focus = 5 if $w_focus > 5;
$node->{'w_focus'} = $w_focus;
```

this is the pass that makes memory *responsive*. it is dynamic — recomputed each
render — and externally driven (section D).

### pass 3 — curve falloff across rank position

after passes 1+2 combine, sort the children, then modulate by **rank position**
using the branch's `curve_type`. this is where 13-harmonic snapping, sharp focus,
and recency decay shape the visible band. the curve is evaluated on-demand with
the pure `<[base.curve.eval]>` — NOT `base.curve.compose`, which is the animation
registry (it keys a config and starts the 50ms tick timer; using it here would
register phantom animations every render). per kimi's decision, render-time
weighting is pure evaluation.

**orientation matters — `base.curve.eval` is NOT monotonic across types.** the
falloff MUST satisfy one invariant: *strongest at rank 0 (`p=0`), monotonically
weaker toward rank N (`p=1`)*. but `base.curve.eval` mixes three families:
- **increasing** (`sigmoid`, `linear`, `quantized`, `ease-*`): 0 at input 0, 1 at
  input 1. to get rank-0-strongest, feed `1-p`.
- **decaying** (`exponential`): 1.0 at input 0, ~0 at input 1. feed `p` directly.
- **humped** (`gaussian_pulse`, `heartbeat`): peak at input ~0.5, near-0 at both
  ends — NOT monotonic. these are only meaningful as a half. for sharp top-focus,
  feed `0.5 + p/2` so rank 0 sits at the peak (input 0.5) and decays toward the
  tail (input 1.0).

so the design assignments shift accordingly: `CRITICAL` uses `gaussian_pulse`
(sharp — only the very top survives, via the peak-half mapping); recency-decay
branches (git, sessions, archive) use `exponential` fed `p` directly; harmonic
banding uses `quantized`. wrap this in a small pure helper rather than scattering
the orientation logic:

```perl
## rank_falloff: 1.0 at p=0 (top rank), decaying toward p=1, per curve family ##
sub rank_falloff {
    my ( $curve, $p ) = @_;                ## p = normalized rank [0,1]
    if    ( $curve eq 'exponential' )                  { return <[base.curve.eval]>->( $curve, $p ); }
    elsif ( $curve =~ m|^(gaussian_pulse|heartbeat)$| ){ return <[base.curve.eval]>->( $curve, 0.5 + $p / 2 ); }
    else                                               { return <[base.curve.eval]>->( $curve, 1 - $p ); }
}

my @sorted = sort { $b->{'w_combined'} <=> $a->{'w_combined'} } @kids;
my $count  = scalar @sorted;
for my $rank ( 0 .. $#sorted ) {
    my $p = $count > 1 ? $rank / ( $count - 1 ) : 0;   ## normalized rank
    $sorted[$rank]{'score'} = $sorted[$rank]{'w_combined'} * rank_falloff( $branch->{'curve_type'}, $p );
}
```

note: `base.curve.eval.position` is NOT used here — that module maps t to SVG
iris coordinates (orbital_arc / vortex_spiral). pass-3 needs the scalar
evaluator `base.curve.eval` only.

**recency × relevance composition.** when a branch wants recency and relevance
blended rather than relevance alone, multiply two `base.curve.eval` calls —
recency via `exponential` over age, relevance via the branch curve over rank —
inside `memory.tree.score`. there is no need for `base.curve.compose`; that
module is reserved exclusively for the ghost-layer fade animation (section E),
where a real timer-driven curve is wanted.

**decay over time.** `memory.focus.decay` (a repeating timer) multiplies every
focus boost toward 1.0 each interval, so attention fades unless reinforced.
nodes whose `score` falls below an eviction threshold across N renders move to
`<memory.ghosts>`.

---

## D. focus vector system

the focus vector is how the system's attention is steered. it lives at
`<memory.focus>` as `{ topic => boost_factor }` and is shaped from three inputs:

1. **active task** — the current `task.show` name contributes a strong boost.
2. **recent commands** — the last K p7c commands routed through this zenka;
   their command namespaces become low-boost topics (ambient attention).
3. **explicit hints** — `memory.focus.set` / `memory.focus.boost` from a user or
   a trusted zenka.

commands (`memory.focus.*` namespace):

- `memory.focus.set topic boost` — set a persistent boost. survives decay floor.
- `memory.focus.boost topic [boost]` — temporary spike; decays back to 1.0.
- `memory.focus.decay` — timer body; multiplies every boost toward 1.0 by the
  configured rate (`<memory.cfg.focus_decay>`, default 0.85 per tick). needs the
  timer-module arg guard: timer modules receive the event as `$ARG[0]`, so guard
  with `@ARG > 1` before treating args as topic input.
- `memory.focus.apply` — fold active-task + recent-commands into the vector
  (called at render time so the vector reflects *now*).
- `memory.focus.matches node topic` — predicate used by pass 2.

**rate-limiting / poisoning policy.** focus is influence over what memory
surfaces, so it must not be writable by arbitrary zenki. the real gate is
`cfg/zenki/cube/access.zenki` — only zenki whitelisted there can route
`memory.focus.set`/`boost`, and cross-zenka calls are route-send + SIZE-reply
only (no shared-FS path). a per-source cap (`max boost contribution per topic per
interval`) prevents a chatty trusted zenka from pinning the vector. that single
access-control line is the enforcement; do not over-engineer a separate trust
layer.

---

## E. ascii frame rendering pipeline

three new frame YAMLs (in `data/yaml/ascii-frames/`) give the tree three
densities. they follow the exact structure of `user-profile.yaml` /
`memory-composite.yaml`: `name`, `title`, `descr`, `border_style`, `modes`, a
`mockup` with `{{SLOT}}` placeholders, and a `slots:` map. **do not append AMOS7
signature stubs** — the signing process adds them; a manual `#,,..` stub blocks
signing.

### memory-tree-compact.yaml — single-line dense node

one line per node for the zoomed-out whole-tree view. shows a score glyph, the
title, and an N/total counter.

```
  {{GLYPH}} {{TITLE}}  [{{N}}/{{TOTAL}}] {{PREVIEW}}
```

`GLYPH` is a score band (e.g. `█ ▓ ▒ ░` mapped from `score` via 13-step
quantize). this variant is what fills a branch's children region when the parent
is rendered compact.

### memory-tree-node.yaml — expanded card

the single-node card: title bar, score indicator row, N/total counter, and a
children-preview block. `border_style: single`.

```
  ..[..................]..[ {{TITLE}} ]:.
  :  score: {{SCORE_BAR}}   [{{N}}/{{TOTAL}}]  :
  :  curve: {{CURVE}}                          :
  :  {{CHILDREN...}}                           :
  #:::::::::::::::::::::::::::::::::::::::::::::
```

### memory-tree-root.yaml — root container

double `::` border container (like `memory-composite` expanded), enclosing the
top-level branches. this is the outer shell the whole tree composes into.

```
  ..[............................]..[ memory tree ]:.
  ::  {{BRANCHES...}}                              ::
  #:::::::::::::::::::::::::::::::::::::::::::::::::::
```

### assembly

`memory.tree.node.render` renders one node into the appropriate variant
(compact when the parent is compact / deep, expanded when it is the focus node).
`memory.tree.render` walks the tree, renders each visible child, and uses
`<[ascii.frame.compose]>` to nest child frames into the parent's children slot,
reconciling width as that module already does. the full tree view is then nested
into `memory-composite.yaml`'s **expanded mode** as a composed slot — the
existing standalone frames (profile, feedback, project, tasks) stay exactly as
they are; the tree is an *additional* composed block, honoring kimi's "existing
frames remain standalone" decision.

**ghost layer.** evicted nodes from `<memory.ghosts>` render faded. this is the
one place `base.curve.compose` belongs: register a fade animation
(`base.curve.eval('exponential')` over time) so ghosts visibly decay in the
animated frontends. in static LLM/HTML output they render once at their current
faded score or are omitted.

---

## F. source adapters

`memory.source.*` — one module per source type. each reads its source and emits
a list of **universal leaf** hashrefs. that is their entire job; they never touch
the tree directly (the tree calls them and inserts the results), keeping the
adapter boundary clean.

universal leaf fields every adapter must populate:

```perl
{
    ntime        => $ntime_b32,   ## via <[base.ntime]> or source timestamp → b32
    content_hash => $chksum,      ## AMOS checksum of the body
    source_type  => 'file',       ## adapter identity
    title        => $short_label,
    body         => $text,
    score        => 0,            ## filled by scorer, adapters leave 0
    curve_type   => $default,     ## adapter's suggestion; branch may override
}
```

adapters:

- **`memory.source.file`** — parse `data/ai-mem/*/*.md`. each `##`/`###` section
  becomes a leaf; the file becomes a branch; `CRITICAL`/`Active Topics`/`Feedback`
  etc. become top-level branch groupings. strips the AMOS7 signature block before
  hashing (same regex `context.memory.load` already uses).
- **`memory.source.session`** — `session-catchup` summaries → leaves under a
  `sessions` branch, ntime from the session archive.
- **`memory.source.git`** — `git log` commits → leaves; subject = title, body =
  message; ntime from commit date. high recency decay (exponential curve).
- **`memory.source.chat`** — `data/development/chat/channel/*/history` messages → leaves
  under per-channel branches.
- **`memory.source.task`** — `data/tasks/*.md` → leaves; the `## task:` line is
  the title, `## dispatch` the preview.
- **`memory.source.index`** — see section G; emits correlation edges, not leaves.

---

## G. index zenka integration

a **focused** `index.*` instance fed only `data/ai-mem/` is the semantic search
layer over the tree's content. the current shared index was overloaded with
millions of chars from design+task files; a memory-only index stays small and
fast.

migration path:
1. back up the current index instance (config + data dir).
2. create a focused instance (`index-mem` zenka or a scoped data dir) and
   `index.cmd.feed-dir data/ai-mem/`.
3. point `memory.source.index` at the focused instance via route-send.

how it feeds the tree:
- **`index.cmd.lookup`** results boost the focus vector — when a topic is active,
  lookup expands it to semantically-related tokens, and those tokens get a
  derived (lower) boost in pass 2. this is how attention spreads from one topic
  to its neighbors without manual linking.
- **`index.cmd.correlate`** surfaces hidden connections between branches; these
  become *cross edges* the renderer can hint (e.g. a "see also" line on a card)
  without restructuring the tree.
- **`index.cmd.cluster`** can suggest branch groupings for the dedup wave.

the index complements — does not replace — the tree's recency/focus structure.
structure = "what is recent and in-focus"; index = "what is semantically near".

---

## H. coding zenka dedup / summarization waves

because each branch holds only its top-N small leaves, a wave operates on a small
working set and is fast.

triggers:
- **N-threshold crossing** — a branch's child count exceeds `n_max_cap × 2`.
- **scheduled timer** — periodic background tidy.
- **explicit** — `memory.tree.dedup` command.

two-stage dedup:
1. **content-hash dedup** (free, local) — collapse leaves with identical
   `content_hash`. keep the newest ntime, increment a `seen` count.
2. **semantic dedup** (coding zenka) — for near-duplicate clusters (surfaced via
   `index.cmd.correlate`), submit to the coding zenka for summarization.

input to coding zenka — a JSON array of the cluster's leaf bodies + titles.
output schema:

```json
{ "summary_title": "...", "summary_body": "...",
  "replaces": ["id1","id2","id3"], "keep_separate": ["id4"] }
```

the summary becomes a new leaf (its own `content_hash`); the `replaces` ids move
to `<memory.ghosts>` (not deleted — the ghost layer preserves the fade trace and
keeps `memory.tree.diff` honest). free 9B summarization is the default model per
the coding-zenka feedback; `from_json` (not `decode_json`) for parsing.

---

## I. multi-frontend rendering

the same `<memory.tree>` drives four outputs because `ascii.frame.*` already
emits four ways. render once to the structured form, fan out:

- **LLM context injection** — `<[ascii.frame.render]>` plain text, composed into
  the context pipeline via `context.provider.frame`. compact variant, modest N.
- **ANSI terminal** — `<[ascii.frame.render.color]>` with phosphor palette;
  score glyphs colorized by band; ghost layer dimmed.
- **web** — `<[ascii.frame.render.html]>`; score bars → styled spans; cross
  edges → anchor links.
- **GTK3** — `<[ascii.frame.render.data]>` returns the structured hashref;
  amos-term / GTK consumer maps slot regions → Pango TextTags, score → weight/
  color, ghosts → faded tags. the GTK frontend does not re-render text; it reads
  the structured data and styles natively.

`n_visible` is the universal zoom control across all four — and it maps to
**terminal resize**: a wider/taller terminal raises N (subject to `n_max_cap`),
a narrower one lowers it. the same lever the LLM uses to fit a token budget the
terminal uses to fit the window.

---

## J. memory zenka startup sequence

the "unfold moment" from `memory-composite.yaml`, made literal:

1. **progress animation** — render `memory-composite` *progress* mode in a `\r`
   loop; PROGRESS bar grows and STATUS cycles as adapters load
   (`loading profile.. loading sessions.. indexing.. ready`). driven by the
   shared 50ms `base.curve` tick.
2. **structured load** — each `memory.source.*` adapter runs, emitting leaves;
   `memory.tree.insert` builds the tree; this is deferred init (push onto
   `system.callbacks.initialized`) so the zenka comes up fast.
3. **focus initialization** — `memory.focus.apply` folds active task + recent
   commands into `<memory.focus>`.
4. **score** — `memory.tree.score` runs the three passes.
5. **tree render** — `memory.tree.render` produces the composed tree frame.
6. **expanded composite** — commit the progress line with `\n`, then render
   `memory-composite` *expanded* mode with the tree nested as a composed slot.
   terminal scroll handles the reveal — the tree unfolds beneath the bar.

`memory.init_code` wires this: register sources, set config defaults, schedule
the focus-decay timer, and defer the first build+render.

---

## K. module namespace plan

new modules, grouped by namespace. one line each.

### memory.* — zenka core
- `memory.init_code` — register sources, config defaults, decay timer, deferred build
- `memory.cfg.defaults` — n_visible(7), curve_type, focus_decay(0.85), eviction threshold

### memory.tree.* — the structure
- `memory.tree.init` — construct empty root node at `<memory.tree>` + flat index
- `memory.tree.insert` — insert a universal leaf, create branch path, content-hash dedup
- `memory.tree.score` — three-pass weighting over a branch's children
- `memory.tree.render` — walk tree, render visible children, compose into parent
- `memory.tree.node.render` — render one node into compact/expanded/root variant
- `memory.tree.dedup` — content-hash dedup + dispatch semantic clusters to coding zenka
- `memory.tree.diff` — subtree-hash diff between two tree states (checkpointing)
- `memory.tree.checkpoint` — snapshot current tree by root subtree_hash

### memory.source.* — adapters
- `memory.source.file` — markdown sections → leaves; files → branches
- `memory.source.session` — session-catchup summaries → leaves
- `memory.source.git` — git commits → leaves (exponential recency)
- `memory.source.chat` — channel history → per-channel leaves
- `memory.source.task` — task files → leaves
- `memory.source.index` — index lookup/correlate → focus boosts + cross edges

### memory.focus.* — attention
- `memory.focus.set` — persistent boost for a topic
- `memory.focus.boost` — temporary boost spike
- `memory.focus.decay` — timer body; multiply boosts toward 1.0
- `memory.focus.apply` — fold active task + recent commands into the vector
- `memory.focus.matches` — predicate: does node match topic ?

### memory.render.* — frontend fan-out
- `memory.render.context` — compose tree for LLM context injection (plain)
- `memory.render.term` — ANSI color render for terminal / nshell
- `memory.render.web` — HTML render for web frontends
- `memory.render.data` — structured hashref for GTK3 consumer

new frame YAMLs (`data/yaml/ascii-frames/`):
- `memory-tree-compact.yaml`, `memory-tree-node.yaml`, `memory-tree-root.yaml`

---

## appendix — key constants & gotchas

- **13** — harmonic fundamental; `quantized` curve = 13 steps; `n_max_cap` default 13.
- **7** — default `n_visible` (reference-bubble 5+2 formation).
- **ntime** — `encode_b32r` is reverse-byte-order, NOT sortable; always convert
  via `<[base.ntime_BASE32_to_numerical]>` before numeric compare.
- **curve.compose vs curve.eval** — `eval` is pure (type×t→[0,1]); `compose`
  REGISTERS an animation and starts the tick timer. weighting uses `eval`;
  only the ghost fade uses `compose`.
- **curve orientation** — `base.curve.eval` is non-monotonic across families
  (increasing: sigmoid/linear/quantized/ease; decaying: exponential; humped:
  gaussian_pulse/heartbeat). rank falloff must orient per family via
  `rank_falloff` (section C) to keep rank-0 strongest; a flat `1-p` inverts half.
- **curve.eval.position** — SVG iris geometry (orbital_arc/vortex_spiral); NOT
  used for rank weighting.
- **signatures** — never append a manual `#,,..` AMOS7 stub to new files; it
  blocks signing. leave new files unsigned.
- **timer modules** — receive the event as `$ARG[0]`; guard real args with
  `@ARG > 1`. timers need after + interval + repeat:TRUE.
- **cross-zenka** — route-send + SIZE reply only; `cube/access.zenki` is the
  real gate for who may push the focus vector.
- **deferred init** — push the first tree build onto `system.callbacks.initialized`.
- **json** — `from_json`, not `decode_json`, for coding-zenka summary output.

#,,,.,.,.,,,.,,,,,,,.,.,.,...,...,.,,,,,,,...,..,,...,..,,...,,..,,,,,,,.,,,.,
#ET4MBXVDTP2IROYNC6KBTKCY5LX27DXR7TSXHIPMUFJZ37ENPHVR55MZ754VWSRZOFE6GUHMHUASK
#\\\|NEDCYEZA235SVCBN5ZZGI2R7PIHYEHG4CIJUJQYTYUGMBQ25T3Q \ / AMOS7 \ YOURUM ::
#\[7]AIHWRUBM4OPUA24EJ6DC7I3JWAW7TLNHU6ONBSP7KJLDBDE6UMDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
