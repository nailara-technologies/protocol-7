## task: memory-index-integration

## dispatch
stand up a focused `index.*` instance fed only `data/ai-mem/`, write the
`memory.source.index` adapter, and wire index lookup results into the focus
vector + cross edges. read first: `data/md/design/MEMORY-TREE-SYSTEM.md`
sections G and H; the index zenka commands (`index.cmd.lookup`,
`index.cmd.correlate`, `index.cmd.cluster`, `index.cmd.feed-dir`); the
cross-zenka feedback (route-send + SIZE reply only; FS access across zenki
forbidden). NOTE: the current shared index was overloaded with millions of chars
from design+task files — back it up before creating the focused instance.
depends on the focus system (`memory.focus.boost`) and tree core being present.

## prompt
add the semantic-search layer over the memory tree.

1. focused index instance — set up an `index.*` instance scoped to
   `data/ai-mem/` only:
   - back up the current index instance first (its config under
     `cfg/zenki/index*/` and its data dir) so nothing is lost.
   - create a focused instance (either a new `index-mem` zenka config or a
     scoped data dir for the existing one — choose based on how index configs
     are structured; document the choice in the task notes).
   - feed it: `index.cmd.feed-dir data/ai-mem/`. confirm it stays small/fast
     (it should index only memory files, not the whole repo).

2. `memory.source.index` — UNLIKE the other adapters, this does NOT emit leaves;
   it emits focus boosts and cross edges. params `{ topic => $t }` or operate
   over the current `<memory.focus>` topics:
   - route `index.cmd.lookup` for active focus topics (cross-zenka: route-send +
     SIZE reply only — no direct FS reads into the index data). for each related
     token the index returns, call `<[memory.focus.boost]>` with a DERIVED
     (lower) boost so attention spreads from a topic to its semantic neighbors.
   - route `index.cmd.correlate` to surface hidden connections between branches;
     store the resulting pairs as cross edges at `<memory.tree.edges>` (a list of
     `{ from => $id, to => $id, weight => $w }`). the renderer may show these as
     a "see also" hint on a card (optional in this task; storing them is the
     contract).

3. boost integration in scoring — `memory.focus.matches` (or pass 2 of
   `memory.tree.score`) should, when the focused index is available, treat a node
   as matching a topic if `index.cmd.lookup` associates them, not only on
   substring. keep substring match as the fallback when the index is absent.

4. dedup hook (optional, if time) — expose the `index.cmd.correlate` clusters to
   `memory.tree.dedup` as candidate near-duplicate groups for the coding zenka
   summarization wave (design section H). just provide the cluster list; the
   coding-zenka call itself is the dedup task's concern.

module headers `## [:< ##`, `# name = ...`, `# descr =` lowercase under 55
chars. lowercase narrative comments, `[ word ]` annotations, NO manual signature
stubs.

## acceptance
- the previous index instance is backed up (config + data) before any change.
- a focused index fed only `data/ai-mem/` exists and answers `index.cmd.lookup`
  over memory content; it is materially smaller than the old overloaded index.
- `memory.source.index` routes lookup/correlate via cross-zenka route-send +
  SIZE reply (no direct FS access into index data) and produces derived focus
  boosts + a `<memory.tree.edges>` cross-edge list.
- setting a focus topic and running the index adapter visibly boosts
  semantically-related nodes (not just substring matches) in the rendered tree.
- the system degrades gracefully to substring matching when the focused index is
  unavailable.
- no manual AMOS7 signature stubs in any new file.

#,,.,,,,,,..,,..,,...,,,.,,,,,.,,,.,,,,,,,,,.,..,,...,...,.,.,,,,,,,,,...,...,
#2HXPSWOKKPF6VLBWVKFOZ3DTN5TLGLZA557MMZMDZAFDWHYBPKCVL4G5KSH75IN5BB5BZZO3EET2Q
#\\\|7NMZJRCUWDIFSTLRUYCRSDPGW6H2WHSFUBFLHUDLCVVSC3PJJBM \ / AMOS7 \ YOURUM ::
#\[7]BFZ435XICQVJAUE5TEEZIC26BOPLG7GVTZ476AWO7T2GSY6HG6BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
