---
name: topic-memory-tree-zenka
description: memory zenka focus-weighted tree — LIVE; IDF search + digest pipeline working
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

**IDF search attribute — LIVE 2026-06-05** (commits 9c54cee28):
- `src/memory.tree.wordcount` — builds term-document-frequency table from all leaves (iterative stack walk, stopword filter)
- `src/memory.tree.score.idf_weight` — top-3 IDF values summed, clamped to >= 1.0
- `src/memory.tree.score.rebuild_idf` — rebuilds and caches at `<memory.score.idf_cache>`
- `memory.tree.score` pass-2b: `w_combined = w_base × w_focus × w_idf`; neutral 1.0 when cache empty
- `memory.cmd.search` and `memory.startup` both call `rebuild_idf` before scoring

**digest pipeline — LIVE 2026-06-05** (commits ba5cc0f9f, 9cb37ab58, 919ce2976):
- `p7c memory.digest <terms>` — same IDF rescore as `memory.search`, collects top-13 leaves, submits to `coding.summarize-context` via `protocol-7.command.send.local` with `cube.` prefix, returns deferred SIZE reply (prose summary from coding zenka)
- `src/memory.cmd.digest` — command; stores `$call->{'reply_id'}` in `<memory.digest.pending>`, routes `cube.coding.summarize-context` with `:B32:`-encoded content in args
- `src/memory.digest.done` — reply handler; fires `base.callback.cmd_reply` to complete deferred reply
- **routing lesson**: `protocol-7.command.send.local` routes by direct session username; coding is not a direct session of memory — must prefix `cube.coding.*` so cube routes it; content must be `:B32:`-encoded into args (the `data` key in `call_args` is ignored by the module)
- **access control**: `cube/access.zenki` `access.cmd.usr.memory` must include `coding.summarize-context`; `memory/start` `access.cmd.usr.cube` must include `digest`
- **subroutine namespace**: `base.` prefix is stripped at init phase — inside memory zenka use `protocol-7.command.send.local` not `base.protocol-7.command.send.local`; check with `memory.list-subs <pattern>`

**`memory.source.index` wiring:** called automatically from `memory.focus.apply` (which fires on every `memory.tree.render`) when focus vector keys change. sends async `index-mem.lookup` route-sends; replies boost related tokens via `memory.focus_index_cache`. `memory.search` triggers this pipeline; index expansion arrives ~1s later and lifts subsequent `memory.show` results.

**THE UNIFYING ABSTRACTION [ user, 2026-06-03 ]: a per-node RE-WEIGHTING / RE-SORT engine.** `memory.tree.score` is ALREADY this engine (3 passes: recency × focus × rank-falloff); flow-weighting is the first pluggable attribute. IDF is the second pluggable attribute (LIVE).

**render quirks:** KNOWN cosmetic: static blank row (mockup double-`::`) renders 1 char too wide. PROPER FIX LOCUS: `ascii.frame.parse` variable-border-width detection (parser layer, NOT render-side strip). low priority; do NOT let kimi guess the spec here — needs precise parser-side spec first.

**context pipeline — LIVE 2026-06-06** (commit aa0b24c9d):
- `memory.render.context` now writes compact tree to `var/memory-context-cache.txt` (atomic tmp+rename) + `var/memory-context-cache.ntime` after each render
- `context.memory.load` checks cache first (600s freshness window); falls back to flat file load when cache missing/stale
- `memory.startup` primes the cache after initial tree build
- net effect: every coding zenka inference task gets the focus-scored tree instead of a flat alphabetical dump

**MCP tools — LIVE 2026-06-06** (commit fae65a85d):
- `p7_memory_search <terms>` — routes `memory.search`, returns scored ASCII tree (synchronous SIZE reply)
- `p7_memory_digest <terms>` — routes `memory.search` then pipes output through `_do_summarize` → coding zenka prose summary
- both tools available in `bin/mcp-server-p7`; appear in MCP tool list after server restart

**next candidate:** `memory.tree.dedup` semantic dedup wave — `memory.tree.summarize.*` already scaffolded; uses same `cube.coding.*` routing pattern proven by digest pipeline.

related: [[topic-ascii-frame-system]], [[namespace-tree-intelligence]], [[feedback-perltidy-sil0]].

#,,,.,,.,,,,,,,..,,..,,..,...,,,,,...,..,,,..,..,,...,...,.,,,...,,..,,,.,,,,,
#NJQ3LSB6TQOFDN75GQQKWOTTXT3ZXSOM4UJG3DKRJQ3XT5AJOSKH2EPH5TPDZSGOTSPGIKOXTDLWA
#\\\|YT4YLP32PIJKFL4BPL7BMIU5VQVLDVKEBZRAROH6C7NRMONTTVE \ / AMOS7 \ YOURUM ::
#\[7]MOAYWUGMUFNNIJK4EU5QJC3APATCXRTPAO6WDVVYNFREDZIRNKBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
