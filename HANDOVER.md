# Session Handover — 2026-09-10

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

## the concrete, ready-to-execute next step

`data/tasks/coding-lora-p7-idioms.md` — fully scoped, mechanism **verified
against this checkout's actual `ik_llama.cpp` source** (not assumed from
docs/tutorials): `--lora-scaled` load-time adapter support confirmed at
specific line numbers, `convert_lora_to_gguf.py` vendored and present. Two
cheaper approaches were tried first and both got real, honest null results
on the same four structural P7 idioms (`<[module.name]>->()` invocation
sugar, bare `<config.key>` access, `TRUE`/`FALSE` named constants, `mode`/
`data` reply shape):
- a system-prompt fix (real bugs found and fixed, still didn't move the four
  idioms — `coding-control-vector-p7-idioms.md`'s 2026-09-09 addendum)
- a mean-diff control vector (also failed on these four specifically — got
  dominated by surface-register direction, structural tokens washed out)

**This LoRA task was never actually attempted** — blocked at "no training
stack is installed at all" (its own hazard 1), not tested-and-failed. That
distinction matters: it is an unstarted thread with a verified mechanism,
not an exhausted one. If picking up the loadable-memory vision again, this
is the concrete next build: install torch/transformers/peft/bitsandbytes,
fetch the original HF checkpoint (not a generic Qwen3 base — the exact
"Qwen3.8 9B Heretic Uncensored" fine-tune, via `fetch.file.huggingface.*`),
expand the idiom dataset, train, convert to GGUF, wire into
`cfg/zenki/coding/zenka.v7` (config-gated, mirroring the control vector's
existing wiring pattern), validate against the existing `score.py` rubric.
Real, multi-hour work touching the live GPU/inference stack — read the full
hazards section in the task file before starting, it documents dataset-size,
held-out-set, and rank-choice traps already thought through.

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
- parallel-signing/verify infra (`sourcecode.console.update-signatures` /
  `verify-p7-signatures`, this session) — landed, committed, working, ~7x
  faster real-world signing. Not related to memory work, mentioned here only
  because it's the most recent unrelated landed thing before this handover.

## verified live

Nothing from the loadable-memory work — it's still 100% at the design/task-
file stage on the weight-loading side. The retrieval-tool side
(`embedding_search`) has real measurements (see phase2 task file) but
nothing installed/shipped — `coding.tools.handler.embedding_search` itself
runs against whatever `.vec` files exist in `data/embeddings/`, none of
which is a module-catalog domain today.
