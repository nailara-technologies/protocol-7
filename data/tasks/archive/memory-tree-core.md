## task: memory-tree-core

## dispatch
implement the tree structure and the three-pass weighting:
`memory.tree.init`, `memory.tree.insert`, `memory.tree.score`,
`memory.tree.render`. read first: `data/md/design/MEMORY-TREE-SYSTEM.md`
sections A, B, C, E; `src/base.curve.eval` (the PURE evaluator — use this,
NOT base.curve.compose); `src/base.sort`, `src/base.sort-num`;
`src/ascii.frame.compose` (frame nesting); the ntime feedback (b32 not
sortable → `base.ntime_BASE32_to_numerical`). depends on
`memory.tree.node.render` (frames task) for rendering and on source adapters for
leaf input, but `init`/`insert`/`score` can be unit-tested with hand-built
leaves before those land.

## prompt
implement the core memory tree. anchor all state under `<memory.tree>` in this
zenka's `%data` (read/write with the project syntax, e.g.
`<memory.tree> = {...}` / `<memory.tree.index>->{$id} = $node`). module headers
`## [:< ##`, `# name = ...`, `# descr =` lowercase under 55 chars. lowercase
narrative comments, `[ word ]` annotations, NO manual signature stubs.

1. `memory.tree.init` — construct an empty root node hashref per the schema
   (`type=>'root'`, empty `children`, `n_visible` from `<memory.cfg.n_visible>`
   default 7, `n_max_cap` default 13) at `<memory.tree>`; create the flat
   `<memory.tree.index>` (id → node ref) for O(1) touch/dedup.

2. `memory.tree.insert` — params `{ leaf => \%leaf, path => ['file','CRITICAL'] }`.
   walk/create the branch path (creating branch nodes as needed, each with its
   own `n_visible`/`curve_type`), then attach the leaf. before attaching, check
   `<memory.tree.index>` for an existing node with the same `content_hash`; if
   found, update its ntime/`seen` count instead of duplicating (content-hash
   dedup). register every new node in the flat index. set/roll the
   `subtree_hash` up the path using `context.tree.checksum.*`.

3. `memory.tree.score` — params `{ node => \%branch }`. score that branch's
   children in three passes (see design section C):
   - pass 1 baseline: convert each child ntime via
     `<[base.ntime_BASE32_to_numerical]>`, normalize to [0,1] over the sibling
     set → `w_base` (newer = higher). stable tie-break by `content_hash`.
   - pass 2 focus: multiply by focus boosts from `<memory.focus>` for matching
     topics (use `<[memory.focus.matches]>` if present; otherwise a simple
     title/body substring match as a stub) → `w_focus`, capped at 5.
   - combine `w_combined = w_base * w_focus`, sort children desc.
   - pass 3 curve falloff: for each child at rank r of count c, normalized
     position `p = c>1 ? r/(c-1) : 0`; `score = w_combined * rank_falloff(curve, p)`.
   recurse into child branches.

   CRITICAL — `base.curve.eval` is NOT monotonic across curve types, so a naive
   `eval(curve, 1-p)` inverts half of them (exponential is 1.0 at input 0 and ~0
   at input 1; gaussian_pulse/heartbeat peak at input ~0.5). implement a small
   pure `rank_falloff(curve, p)` helper that guarantees the invariant *1.0 at
   rank 0 (p=0), monotonically weaker toward rank N (p=1)*:
   - increasing curves (`sigmoid`, `linear`, `quantized`, `ease-*`): feed `1-p`.
   - decaying curve (`exponential`): feed `p` directly.
   - humped curves (`gaussian_pulse`, `heartbeat`): feed `0.5 + p/2` so rank 0
     sits at the peak and the tail decays.
   verify the endpoints empirically before trusting the assignment: for EVERY
   curve_type the branches actually use, assert `rank_falloff(curve,0) >=
   rank_falloff(curve,1)`. IMPORTANT: use `base.curve.eval` (pure) only. do NOT
   call `base.curve.compose` (it registers an animation + starts the tick timer).
   do NOT use `base.curve.eval.position` (that is SVG iris geometry).

4. `memory.tree.render` — params `{ variant => 'compact'|'expanded', n => $N }`.
   ensure scoring is current, then walk from root: for each branch take the top
   `n_visible` children (respecting `n_inherit`/`n_max_cap`), render each via
   `<[memory.tree.node.render]>`, and nest child frames into the parent's
   children slot with `<[ascii.frame.compose]>`. return the composed tree frame
   string. `n` overrides root `n_visible` for zoom control.

## acceptance
- `memory.tree.init` produces a valid empty root + flat index; re-running is
  idempotent.
- `memory.tree.insert` creates branch paths, attaches leaves, and dedups by
  `content_hash` (inserting the same leaf twice yields one node with seen=2).
- `memory.tree.score` produces a `score` in [0,1] on every child, ordered desc,
  with three distinct passes observable (baseline recency, focus boost, curve
  falloff). recency uses `base.ntime_BASE32_to_numerical`, not raw b32 compare.
- the `rank_falloff` helper satisfies `rank_falloff(curve,0) >=
  rank_falloff(curve,1)` for every curve_type used (top rank strongest); an
  exponential branch fades older children, a gaussian_pulse branch concentrates
  weight on the top — neither is inverted.
- scoring uses `base.curve.eval` only — grep confirms no `base.curve.compose`
  or `base.curve.eval.position` call in `memory.tree.score`.
- `memory.tree.render` returns a composed multi-node frame string for both
  compact and expanded variants; passing a smaller `n` visibly shrinks the tree.
- no manual AMOS7 signature stubs in any new file.

#,,..,.,,,.,,,.,,,,..,,.,,.,.,..,,,..,,,.,.,.,..,,...,...,..,,.,.,,,,,,,.,,,,,
#UFNZBXQAQ65QVSZIIAJJ7VJAN3ASEDK2L22ECDXHQE7I4ZFJKESD3C5PI4MCG5VAPQCQDVR5CCF7Q
#\\\|JZ7OPIKKP3B6K4GU6CQUWVVZBIJIK4UY2W7VNDW3U64BT6YQHW3 \ / AMOS7 \ YOURUM ::
#\[7]JZRIAW7BQBYO4C53ROBLZRPNXOCTQUHIVKUDHHK2EN3E5BJS6KAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
