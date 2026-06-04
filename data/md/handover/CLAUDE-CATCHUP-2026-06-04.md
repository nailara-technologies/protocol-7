# Claude Catchup — 2026-06-04 — memory zenka: from empty shell to useful

handover for resuming the memory-tree work. the durable per-fact memory is in
`data/ai-mem/claude/topic-memory-tree-zenka.md` (read it first); this file is the
session narrative + things not in that note (commit arc, toolchain, lessons).

## one-line state

the `memory` zenka now builds a live focus-weighted tree (162 branches / 1139
nodes from `data/ai-mem/`), and **focus contextualization works end-to-end** —
including up-propagation into branches via leaf content. supporting toolchain
hardened. all committed.

## what shipped this session (commits)

- `216254129` refactor: extract inline subs → standalone modules (15 helpers)
- `128f382a0` feat: memory zenka — focus-weighted tree system (build path)
- `82a1cebac` feat: flow-weighting + frame cosmetics + module/whitelist hardening
- (kimi committed the `source.cmd.get-code-signed` / `source.restore_payload_endline_state`
  signature-endline bug-fix separately; `8313ae358` signature endline state mismatch)

## the memory tree — how it works now

- **build:** `memory.startup` resolves an absolute ai-mem dir via
  `<system.root_path>` (the zenka CWD is `/home/protocol-7`, NOT project root —
  relative paths fail), runs `memory.source.file`, inserts leaves via
  `memory.tree.insert` with a per-leaf path from `memory.cfg.group_by`
  (file|section-class|source-type|flat, default file), then scores.
- **REBUILD = `v7.restart memory`** — `memory.startup` is idempotent on
  `<memory.ready>`, which survives a source reload. a plain `memory.reload` will
  NOT rebuild.
- **render:** `p7c memory.show [n]`. `memory.tree.render` runs flow+score then
  renders via `ascii.frame.render.color`.
- **drive focus by hand** (the `focus.set`/`boost` commands are NOT in the zenka
  access list yet — add them if you want p7c access):
  ```
  p7c memory.eval-code '$data{memory}{focus}={TOPIC=>5}; $code{"memory.tree.flow"}->({node=>$data{memory}{tree}}); $code{"memory.tree.score"}->({node=>$data{memory}{tree}}); return "ok";'
  p7c memory.show 1
  ```
  NOTE: in `eval-code`, `<[...]>` / `<...>` P7 sugar is NOT parsed (runtime) —
  use `$code{"mod"}->()` and `$data{a}{b}`. keep the perl on ONE line (newlines
  break p7c arg parsing).

## flow-weighting (the core win) — step 2, DONE + verified

`memory.tree.flow` is a bottom-up post-order pass: leaf
`flow_focus = (product of matching focus boosts) − 1`, branch = sum of children.
`memory.tree.score` pass-2 sources `w_focus = 1 + min(4, flow_focus)`. effect: a
focus token in LEAF bodies lifts its ancestor branch. proven live —
`focus={sentinel=>5}` lifted `feedback-true-false-constants` +
`topic-strm-unbounded-gap` to ranks 1-2 (flow_focus=4.0), above recency-only
branches at 0.

## the vision (per user) — a per-node RE-WEIGHTING engine

the major feature base is re-sorting entries within each tree node by composable
ATTRIBUTES (uniqueness, occurrence, recency, focus, flow, …), blended by the
curve module. `memory.tree.score` IS this engine already; flow-weighting is its
first new attribute. roadmap attributes/stages:
1. **term-rarity / search:** wordcount table (term→count, counting UPWARD,
   inverse to the index zenka); re-sort by uniqueness (rarest first) so
   distinctive terms win when the result cut is small (N=5-7). IDF-style.
2. **summarize-present stage:** feed a re-weighted result subtree through
   `memory.tree.summarize.*` (→ coding zenka) before showing it — a digested
   view, drill-down preserved. this realizes the original "summary inheritance"
   idea. offered as a COMPLEMENT command (`memory.search` raw vs summarizing).
   full pipeline: select → re-weight(attributes) → top-N → summarize → present.

## toolchain hardening (reusable beyond memory)

- **`bin/format-code` + `bin/ptd` now pass perltidy `-sil=0`** (kept in parity) —
  forces top-level col0 baseline; makes them SELF-HEALING for over-indented
  extractions. background: sub-extraction can leave a whole module uniformly +4
  indented; perltidy reads uniform indent as intentional and preserves it, so it
  never self-fixes WITHOUT `-sil=0`. fix an over-indented module by running
  `bin/format-code modules/<name>` then re-sign. verify whitespace-only with
  `git diff -w`. see `data/ai-mem/claude/feedback-perltidy-sil0.md`.
- over-indented modules also broke `bin/dev/dep-graph` (`extract_module_name`
  wanted `#` at col0) → missing from `gen-sub-whitelist` → lazy-loaded. now:
  dep-graph regex is whitespace-tolerant (defense-in-depth) AND the modules are
  canonicalized, so they preload.

## open items (none blocking)

- **1-char wide static spacer row** (cosmetic). REAL cause: the reverse parser
  `ascii.frame.parse` was designed for VARIABLE border width (`:`/`::`/wider);
  for the double-`::` case the parser's stored static content and the renderer's
  `len(border)` accounting disagree by one, so the static row's `fill_width`
  clamps and the line is +1. correct fix is PARSER-SIDE (consistent
  variable-border-width detection), NOT a render strip. **do NOT let kimi guess
  here** — it already hallucinated a non-existent "double-border post-processing"
  regex and produced a wrong-direction fix that was reverted.
- glyph banding: every top branch shows `█` (score banding not differentiating
  at the top).
- `memory.focus.set` / `.boost` not in `configuration/zenki/memory/start`
  access list (drive via eval-code meanwhile).
- `data/tasks/coding-drain-pipe-restart-robustness.md` — coding-zenka async
  pipe/restart bug captured, ready to dispatch.

## working-with-kimi lessons (this session)

- kimi is effective for well-specced implementation (extraction, build wiring,
  flow-weighting all landed clean), but VERIFY its diagnoses: it fabricated a
  rendering mechanism for the spacer bug. trust empirical specs; check claims
  against the actual code with grep before accepting a fix.
- kimi sometimes leaves a partial `#,,.` signature stub on NEW modules — strip it
  (it blocks signing). other extracted modules end at the last statement, unsigned.

## key references

- design doc: `data/md/design/MEMORY-TREE-SYSTEM.md`
- per-fact memory: `data/ai-mem/claude/topic-memory-tree-zenka.md`,
  `feedback-perltidy-sil0.md`
- modules: `memory.tree.{flow,score,insert,render,node.render}`,
  `memory.source.file`, `memory.startup`, `memory.cfg.defaults`,
  `ascii.frame.{load,render,parse}`

#,,..,...,,,,,,,,,,,.,,,.,...,,,,,,,.,,,,,,,.,..,,...,...,,..,,,,,...,,,.,,,.,
#WL432TVJRDFDWVKNAVY3TS5E7RNBKPHTSIJ2XWM2MSS2DK5ECEFL3CLHMTRHC2DTFWJQLCWFILR3Y
#\\\|ZKDVS7JGMUM5VG7V6PYO7EDLWCDXYC4RSZ5HT2K6TEGZIIW6WVH \ / AMOS7 \ YOURUM ::
#\[7]EXXZ2LUE75DFFC35DFZCZFH2VUYO4EQWXTKEIYVXE62SH4EJ36CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
