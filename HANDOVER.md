# Session Handover — 2026-09-11

**Read this before touching anything called "loadable memory," "module-catalog
embedding," "fasttext," "LoRA," or "control vector" for the coding zenka.**
These names have been getting conflated across sessions/compactions, and it
has repeatedly cost real momentum — see "the mistake to not repeat" below.

## the actual goal, stated precisely

**loadable project memory** = giving a model (any zenka's model, not just
coding) ambient structural/behavioral intuition about this codebase that
costs **zero extra context tokens and zero extra reasoning rounds per use** —
loaded once (weights/adapter), not queried at inference time. Explicitly
**not** retrieve-and-stuff RAG. Quote from the authoritative design doc:

> "Current approach: retrieve-and-stuff (RAG)... burns tokens, adds latency,
> retrieval quality bounds answer quality. Alternative: encode the codebase
> structure into embedding weights directly... zero retrieval overhead."

Authoritative design: `data/md/design/INDEX-FASTTEXT-SOURCECODE-EMBEDDINGS.md`
(+ siblings `FASTTEXT-MEMORY-PIPELINE.md`, `FASTTEXT-LOG-AWARENESS.md`,
`FASTTEXT-CATEGORICAL-MEMORY.md` — all in the same `data/md/design/` /
`data/tasks/` neighborhood). This is deliberately foundational/generic — the
long-term intent is many zenki benefiting from this, not a coding-zenka-only
feature. **Go as slow and strategic as needed to keep it clean, generic, and
elegant — there is no deadline pressure here, only a direction to not lose.**

## the mistake to not repeat

`data/tasks/coding-catalog-retrieval-phase2.md` (module-catalog embedding /
`src/coding.tools.handler.embedding_search`) is a **different, narrower,
legitimately valuable feature** — a callable search tool for the coding
zenka, fasttext-token-sum-cosine based. It has now collected **four honest
negative results** (descr-only corpus, source-mined density, review prose,
synthetic query-shape) plus a BM25 comparison showing the real bottleneck is
corpus thinness (~4.5k modules, 24-55 char descr lines), not any single
fixable input. All of that is real, valid, worth keeping — **but it is a
verdict on the retrieval-tool feature, not on the loadable-memory vision
above.** Every session so far that touched "embeddings" has drifted into
testing/re-testing this retrieval tool and then reported the vision itself
as stalled when it failed. Don't do that again. The two threads share a
noun ("embedding") and a training method (fasttext) and are otherwise
unrelated projects with unrelated success criteria.

The 276-module review corpus (`data/src-review/*/review.md`) and the
descr-accuracy pass are shared upstream assets feeding **both** directions —
better source text helps whichever mechanism eventually gets built. Keep
building/maintaining that corpus regardless of which memory-loading approach
moves forward.

## the LoRA thread's actual current state, 2026-09-11 — this section fully
## replaces everything the 2026-09-10 handover said was "the concrete next
## step"; that work happened and concluded

**attempt 1 (synthetic dataset) ran to completion and is a fourth honest
negative.** Full account in `data/tasks/coding-lora-p7-idioms.md`. Trained a
real rank-16 LoRA adapter (loss 0.336) against a genuine fetched HF
checkpoint (`petruhonk/Qwen3.8-9B-Distill-uncensored-heretic` — the original
`rohit267` repo the 2026-09-10 handover referenced is gone, 404), converted
to GGUF (had to extend `lora_to_gguf.py` for this architecture's SSM tensor
names — the vendored converter has no `qwen35` support at all), found and
fixed a real deployment bug along the way (this `ik_llama.cpp` fork silently
no-ops LoRA under flash attention — `coding.spawn_inference_server` now
disables it automatically whenever a lora_adapter is configured), then
validated against the same held-out-prompt harness the control-vector task
used. **Result: `invoke` (the idiom this whole thread most needs to move)
stayed at 0/18 either condition** — the adapter's only measurable effect was
pushing generation toward generic Perl conventions, not P7's bespoke syntax.
Also corrected a real project-memory gap while investigating: a prior
session (2026-09-09, `12271bf2c`) had already tried this LoRA path once,
via a dequantized checkpoint that hit unrecoverable corruption, before
pivoting to the shipped idiom conformance gate (`coding.cfg.idiom_gate`) —
the 2026-09-10 handover's "never actually attempted" was wrong, now fixed.

**attempt 2 (real git-history data) is running as of this handover — check
its result before doing anything else.** Diagnosis from attempt 1: the
input was the problem, not the method — synthetic single-snippet examples
taught "Perl-shaped," not "P7-shaped." `data/tasks/coding-git-history-idiom-
mining.md` covers the full approach: `data/idioms/mine_git_history.pl`
mines real (before→after) corrections from this repo's own commit history
(6381 commits across three historical directory names — `src/`→
`base-code/`→`modules/`→back to `src/` — scored with the *same* frozen
`score.py` rubric the validation harness uses), `dedup_corpus.pl` collapses
duplicates and caps category skew, `corpus_to_sft.pl` converts the curated
302-row corpus into the same SFT format `train_lora.py` already parses
(real code, only a generic instruction wrapper is synthesized). Training
launched against `data/idioms/corpus/mined.curated.sft.txt` — **if this
session ended before it finished, check `data/control-vectors/lora-out/
p7-idioms-real/adapter/` for a completed adapter and the coding zenka's log
for `[lora_train] python side reported complete` or `training failed`
before assuming anything about the outcome.** If it finished: convert to
GGUF (`lora_to_gguf.py`, same recipe as attempt 1), validate against the
same harness, and only invest further in corpus refinement (Kimi sweeps for
correctness-checking mined pairs at scale, coding-zenka background tasks for
continuous mining) if this run actually shows real movement on `invoke` —
that decision is explicitly deferred until the result is in, not assumed.

**a real quality hazard was found in the mining approach itself, worth
knowing before trusting its output uncritically**: the idiom-density
admission filter has no semantic-correctness check. One mined hunk
(`87b5c3a27`) substituted a real-but-wrong-context P7 module call
(`<[base.ntime]>->(0) // time`, mixing an incompatible harmonic-encoded
epoch value with a raw unix timestamp) from a botched mid-migration commit
— caught by hand-inspection, not automatically, and removed. Any future
mining run needs at least a spot-check pass, not just the mechanical
dedup/cap.

**a real infrastructure byproduct, independent of whether attempt 2 works**:
`src/torch.*` is now a planned, empirically-validated primitive for future
zenki needing real torch/CUDA compute in a forked child (not `base.*` — too
heavy/optional for a namespace loaded broadly; not `py.*` — names a family
with no second consumer yet). `Inline::Python` + torch works end to end
including real GPU compute, and the fork-before-CUDA discipline a true P7
child zenka would need (matching `weather.base.fork_weather_child`'s
pattern, not the `IPC::Open3` fork+exec this session's own training
orchestration used) is proven safe, not just assumed. See `data/tasks/
torch-worker-zenka-foundation.md` — an invoke.ai-replacement zenka is the
planned first consumer, not the definition of the primitive.

## other open items, unrelated to the above

- **`vault-edit` zenka**: the 2026-09-06 entry this replaces said "never once
  executed" — that was already stale by 2026-09-07, when plumbing was
  verified end-to-end (6 real bugs fixed, 2 pre-existing framework defects)
  and a UX pass landed (title bar/footer/key-hints chrome, collapsed
  subscriber preview, an `o`-overview escape). It exists and does something.
  **What it still doesn't do is the actually-required functionality: adding
  or editing credentials.** That's the real open item, not "run it for the
  first time." See `data/ai-mem/claude/project-cred-mesh-console-ui-
  architecture.md` and `data/tasks/credential-fabric-ui-interactive.md`.
- three small follow-on task files, filed but not started: `data/tasks/
  models-scan-paths-reunite.md` (`models.scan_paths` hash vs `models.
  storage.search_paths` array desync), `data/tasks/sig-warn-blacklist-
  arrayify.md` (`bin/Protocol-7`'s central `$SIG{__WARN__}` blacklist is a
  single scalar slot, not an array), `data/tasks/clients-https-native-async-
  file-download.md` (replace the wget/aria2c child-process download
  approach with a native async `clients.https` stream — needs streaming-to-
  disk support in `clients.https.handler.io` first, a real prerequisite gap).
- a real, minor tool bug found and deferred this session: `src/work.
  console.purge-paths` (the `p7-work purge-paths` command used this session
  to strip ~350MB of accidentally-committed LoRA adapter/GGUF binaries from
  local git history) unconditionally prints "History rewritten - see
  warnings above" even when `git-filter-repo` emitted no warnings at all —
  cosmetic, not urgent, fix whenever convenient.

## verified live

Both LoRA attempts this session were real, live, GPU-trained runs against
the coding zenka's actual GPU (not simulated) — attempt 1 fully validated
end to end (baseline vs adapter-on, both held-out prompt sets), attempt 2's
outcome depends on what this session left it at, see above. The idiom
conformance gate (`coding.cfg.idiom_gate`) remains commented out /
unactivated in production either way — turning it on at `scan` (log-only)
to start accumulating a second, independently-sourced real corpus was
proposed and never actually flipped on this session, still open. The
retrieval-tool side (`embedding_search`) is unchanged from before — real
measurements, nothing installed/shipped.
