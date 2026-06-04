---
name: topic-memory-tree-zenka
description: memory zenka focus-weighted tree — now LIVE; step 2 is flow-weighting
metadata: 
  node_type: memory
  type: project
  originSessionId: 4d1cd39b-4703-4113-9ed7-a5f1d54c7cff
---

the `memory` zenka builds a focus-weighted tree over `data/ai-mem/*.md` and renders it via `ascii.frame.*`. design doc: `data/md/design/MEMORY-TREE-SYSTEM.md`.

**status (2026-06-03): the tree BUILD is now LIVE.** it was disabled (`memory.startup` set `<memory.ready>` on an empty tree "for stability testing"). re-enabled: `memory.startup` now resolves an absolute ai-mem dir via `<system.root_path>`, runs `memory.source.file`, inserts via `memory.tree.insert` with a per-leaf path from `memory.cfg.group_by` (file|section-class|source-type|flat, default file), then `memory.tree.score`. result: 162 file branches / 1139 nodes. `p7c memory.show 1` renders it. **to rebuild you must `v7.restart memory`** — `memory.startup` is idempotent on `<memory.ready>`, which survives source reload.

**focus steering WORKS at the branch-title level** — `focus={stream=>5}` + re-score lifts the 4 `topic-stream-*` branches to the top. drive it manually via `eval-code` (`$data{memory}{focus}={...}; $code{"memory.tree.score"}->({node=>$data{memory}{tree}})`); the `focus.set`/`boost` commands are NOT in the zenka access list yet.

**THE UNIFYING ABSTRACTION [ user, 2026-06-03 ]: a per-node RE-WEIGHTING / RE-SORT engine.** the major feature base is the ability to re-weight/re-sort the entries within each tree node by composable ATTRIBUTES — uniqueness, occurrence count, recency, focus-match, flow-count, and others — each producing a weight component, blended (curve module) into the final per-node ordering. `memory.tree.score` is ALREADY this engine (3 passes: recency × focus × rank-falloff); the generalization is to make the attributes pluggable/composable. step-2 flow-weighting and search-by-uniqueness are both just NEW attributes in this engine, not separate systems.

**STEP 2 = flow-weighting — IMPLEMENTED + VERIFIED LIVE 2026-06-04.** proof: `focus={sentinel=>5}` (a token only in leaf BODIES of `feedback-true-false-constants` + `topic-strm-unbounded-gap`, in no branch title) lifted BOTH branches to ranks 1-2 with `flow_focus=4.0` (→ w_focus=5, score 1.00); recency-only branches stayed below at flow_focus=0. up-propagation confirmed. new `memory.tree.flow` (bottom-up post-order): leaf `flow_focus = (product of matching focus boosts) − 1`, `flow_count = 1`; branch sums children's. `memory.tree.score` pass-2 now sources `w_focus = 1 + min(4, flow_focus)` (fallback to direct-match if flow not run). `memory.tree.flow` is called before `memory.tree.score` in both `memory.startup` and `memory.tree.render`. effect: a focus token living only in LEAF BODIES now lifts its ancestor branch (focus propagates UP). VERIFY after sign: set focus to a leaf-body-only token, check the branch climbs. general `flow_count` stored for future use. this is the FIRST attribute of the per-node re-weighting engine; grouping stays a separate configurable knob.

**search attribute — inverse wordcount [ later ]:** build a wordcount table (term→count, counting UPWARD, inverse to the index zenka), then re-sort entries by word uniqueness (lowest count = rarest first) so distinctive terms win when the result limit is small (N=5-7 per branch). IDF/term-rarity ranking; valuable exactly when the cut is tight. one attribute among many in the re-weighting engine. ties to [[checksum-addressing]] / index zenka but simpler.

**re-sorted result tree → summarization → present [ user, 2026-06-03 ]:** a re-weighted result subtree can feed a SUMMARIZATION step (reuse `memory.tree.summarize.*` → coding zenka) before the zenka/model/user sees it, so they get a digested view, not raw entries — drill-down stays available. this is the original "summary inheritance" concern realized as a pipeline stage (summaries as a presentation layer over re-weighted subtrees). offered as a COMPLEMENT command type: e.g. raw `memory.search <q>` (re-weighted tree) alongside a summarizing variant that runs the digest pass on the result tree. full pipeline: select → re-weight(attributes) → top-N subtree → summarize → present.

**cosmetic frame bugs — FIXED 2026-06-04 (pending sign + `v7.restart memory`):** (1) right padding: added `padding: {right: 2}` to `memory-tree-root.yaml` + `ascii.frame.load` now applies YAML padding overrides. (2) stray `:`: the reverse-parser leaves a border `:` in the blank static-row content (double-`::` mockups); fixed in `ascii.frame.render` static-row path (~line 207) by stripping leading/trailing border chars before fill — chosen over a parser fix to avoid regressing memory-composite. 3 files edited, unsigned.

**render quirks still noted:** every top branch shows the same `█` glyph (score banding not differentiating at the top). KNOWN minor cosmetic: the frame's OWN static blank row (mockup row 3) renders 1 char too wide. REAL cause (verified by reading): in `ascii.frame.render` static-row branch, the parsed double-`::` static content after border+pad stripping is 1 longer than `frame_width - borders - lpad - rpad`, so `fill_width` = −1 → clamped to 0 → line is +1 over frame_width. PROPER LOCUS [ user 2026-06-04 ]: border width was DESIGNED to be variable in the reverse parser (`ascii.frame.parse`) — `:` vs `::` vs wider. the +1 is a variable-border-width inconsistency: the parser's stored static content and the renderer's `len(border left/right)` accounting disagree for the double-`::` case, leaving one border-width of extra content in the static row. correct fix = make `ascii.frame.parse` variable-border-width detection consistent (parser layer), NOT a render-side strip. kimi's attempt invented a non-existent "double-border post-processing" regex and stripped less (wrong layer AND wrong direction) — REVERTED. low priority, purely visual; needs a precise parser-side spec (do NOT let kimi guess here).

related: [[topic-ascii-frame-system]], [[namespace-tree-intelligence]], [[feedback-perltidy-sil0]].

#,,..,.,,,.,,,,,,,,..,,..,...,,,,,...,,,.,.,.,..,,...,...,...,,,,,,,,,,.,,..,,
#ABUJ2MHDMYSC333NCZ36652GHAI6I7FSGIG4YA6D6WZUP4TZF6IHBFK3PI7WJTKRVAWXEPSWZDYSA
#\\\|FN7NEHKJULCNHW4QNCN3ZWNNIHFIYP3EDAYN3PEKVN5ZOOJ4OQH \ / AMOS7 \ YOURUM ::
#\[7]B7JTSOWIP62S7VJT4XFZMQUL6WYQVXDMHYHQ3VELRZH5TFBEF4AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
