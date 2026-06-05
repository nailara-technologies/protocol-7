---
name: topic-memory-tree-zenka
description: memory zenka focus-weighted tree — LIVE; focus/search commands working
metadata: 
  node_type: memory
  type: project
  originSessionId: 4d1cd39b-4703-4113-9ed7-a5f1d54c7cff
---

the `memory` zenka builds a focus-weighted tree over `data/ai-mem/*.md` and renders it via `ascii.frame.*`. design doc: `data/md/design/MEMORY-TREE-SYSTEM.md`.

**status (2026-06-03): the tree BUILD is now LIVE.** 162 file branches / 1139 nodes. `p7c memory.show 1` renders it. **to rebuild: `v7.restart memory`** — `memory.startup` is idempotent on `<memory.ready>`, which survives source reload.

**STEP 2 = flow-weighting — LIVE 2026-06-04.** focus tokens in leaf BODIES propagate up to ancestor branches via `memory.tree.flow` (bottom-up post-order). `memory.tree.score` pass-2 sources `w_focus = 1 + min(4, flow_focus)`.

**focus + search commands — LIVE 2026-06-05:**
- `p7c memory.focus set <topic> <score>` — set persistent boost floor, re-flow + re-score
- `p7c memory.focus boost <topic> [mult]` — spike focus (default 2×), re-score
- `p7c memory.focus get` — SIZE reply listing topic = score pairs sorted by score
- `p7c memory.focus clear [topic]` — clear one topic or all, re-score
- `p7c memory.focus apply` — trigger async index lookups + re-score
- `p7c memory.search <terms>` — boost terms to 5.0, apply, re-score, render top-N
- all commands return `{ mode => 'size', data => ... }` — plain TRUE/FALSE is rejected by the handler
- args come via `$call->{'args'}` (split into @args), NOT `shift` or `$ARG` — confirmed from bin/Protocol-7 line 1893

**`memory.source.index` wiring:** called automatically from `memory.focus.apply` (which fires on every `memory.tree.render`) when focus vector keys change. sends async `index-mem.lookup` route-sends; replies boost related tokens via `memory.focus_index_cache`. `memory.search` triggers this pipeline; index expansion arrives ~1s later and lifts subsequent `memory.show` results.

**THE UNIFYING ABSTRACTION [ user, 2026-06-03 ]: a per-node RE-WEIGHTING / RE-SORT engine.** `memory.tree.score` is ALREADY this engine (3 passes: recency × focus × rank-falloff); flow-weighting is the first pluggable attribute. next: search-by-uniqueness (IDF/rarity ranking).

**search attribute — inverse wordcount [ later ]:** build a wordcount table (term→count), re-sort entries by word uniqueness (lowest count = rarest first). IDF/term-rarity ranking; valuable when result cut is tight (N=5-7 per branch).

**re-sorted result tree → summarization → present [ user, 2026-06-03 ]:** pipeline: select → re-weight(attributes) → top-N subtree → summarize (coding zenka) → present. raw `memory.search` + summarizing variant as complement commands.

**render quirks:** KNOWN cosmetic: static blank row (mockup double-`::`) renders 1 char too wide. PROPER FIX LOCUS: `ascii.frame.parse` variable-border-width detection (parser layer, NOT render-side strip). low priority; do NOT let kimi guess the spec here — needs precise parser-side spec first.

related: [[topic-ascii-frame-system]], [[namespace-tree-intelligence]], [[feedback-perltidy-sil0]].

#,,,.,,.,,,..,,,,,,..,..,,,..,,,,,.,.,..,,,..,..,,...,...,,.,,.,,,,..,...,...,
#WHLTOESQVKIBUQ5Y2C3NVY7QRRDL7UVHNQZHX5Q6ULJPQPIUXHVZVJ45LEMKCKBLA266TBGFLPC74
#\\\|WRXULSP4BSLDX42BN6ZQ7O6ND2SKME63URN4UMIGQGSQ7XORWYA \ / AMOS7 \ YOURUM ::
#\[7]YOLOOA3O62BACTXJJT74E7LZNGWSEJWTRGIOGPYGOJMZLWTGOYCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
