# Session Handover — 2026-09-14

**Read this before touching anything called "loadable memory," "module-catalog
embedding," "fasttext," "LoRA," or "control vector" for the coding zenka.**
These names have been getting conflated across sessions/compactions, and it
has repeatedly cost real momentum — see "the mistake to not repeat" below.

## orientation, 2026-09-14 — two independent threads, both landed/resting

A parallel session sharing this same checkout landed a large body of work
unrelated to the LoRA thread below — **33 commits** (`06d08d0ae..99795a1e1`
in `git log`), not written up here since it wasn't this session's work:
`data/tasks/coding-zenka-session-ui.md` phases 1-3 all DONE+pushed (live
streaming, mcp-server-p7 STRM support, nshell split-screen + coding-session
chat plugin, Esc-abort/round-chain rewind-redo via BMW-L13-checksummed
parent-pointer chaining, `restream`/`round-regen`), plus a separate
STRM-SIZE reliability fix chain and an `AMOS7-v5.90.8` release cut. Full
detail in `data/ai-mem/claude/MEMORY-active.md`'s `project-coding-zenka-
session-ui-plan` pointer and `[[project-round-chain-rewind-redo-landed-
2026-09-14]]` — read those, not this paragraph, for anything beyond "it
landed."

This session's own thread (LoRA `invoke` idiom + a chat-template swap) is
covered in full below — still at the same resting/decision point as of
this date, no attempt 5 started.

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

## the LoRA thread's actual current state, 2026-09-12 — this section fully
## replaces everything the 2026-09-11 handover said was open; attempt 2
## finished (fifth negative) and attempt 3 is running as of this handover

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

**attempt 2 (real git-history-mined data) ran to completion — fifth honest
negative on `invoke`.** Full account in `data/tasks/coding-lora-p7-idioms.md`'s
"second attempt" addendum. `data/idioms/mine_git_history.pl` mined real
before→after corrections from this repo's own commit history (6381 commits,
three historical directory names), `dedup_corpus.pl` + `corpus_to_sft.pl`
curated it into `data/idioms/corpus/mined.curated.sft.txt` — real code, not
another synthetic set. Trained cleanly (loss 1.37, same rank-16 attn/mlp/ssm
target list as attempt 1), converted to GGUF with NO converter changes needed
(`p7-idioms-real-lora.OFSQC4I-QDBKEXY.gguf` — confirms attempt 1's SSM
tensor-mapping extension generalizes), validated with a FRESH baseline (not
attempt 1's numbers) against the full held-out harness. **`invoke` stayed at
0/18 — real, in-distribution training data did not succeed where synthetic
data failed.** The only movement was `truefalse` (4→12 combined raw count),
flagged not claimed clean: one of the two prompts that moved (`P_D`)
literally contains the word "FALSE" in its own instructions, so some of the
count is plausibly prompt-echo rather than idiom adoption — though baseline
(same prompt) scored lower, so it isn't purely that either. Confound checks
came back clean this time (no length-collapse, no early-EOS artifact),
unlike attempt 1's confounded numbers.

**attempt 3 (lm_head/embed_tokens targeting) ran to completion — sixth
honest negative on `invoke`, and the most targeted test yet.** Full account
in `data/tasks/coding-lora-p7-idioms.md`'s "third attempt" addendum. Added
`lm_head`/`embed_tokens` to target_modules (`tie_word_embeddings` FALSE on
this checkpoint, no tied-weight complication) to test whether the final
hidden-state→token-logit projection itself was the bottleneck. Two real
findings before validation: (1) PEFT saves a full ~4GB fp32 copy of each
target module's frozen base weight when that module wasn't loaded in 4-bit
— `lm_head`/`embed_tokens` are the only unquantized targets here, so the
saved adapter was 8.3GB of which only a few MB was real signal;
`lora_to_gguf.py` now skips `.base_layer.` tensors. (2) Read `llama-build-
context.cpp` directly (same discipline as the flash-attn discovery):
`lm_head`/output routes through the lora-aware `llm_build_lora_mm`, but the
token embedding lookup (`llm_build_inp_embd`) is a bare `ggml_get_rows` with
no lora path at all — an `embed_tokens` LoRA would silently never apply on
this fork, so only `lm_head` was actually converted/tested. Differential
test (scale=0 vs 1, diffing real `content` this time, not just
`reasoning_content` — a methodology fix from a mistake earlier this
session) confirmed the adapter genuinely applies. Validated against a fresh
baseline (byte-identical to attempt 2's baseline — same model/seeds,
expected): **`invoke` stayed at 0/18 even with the output projection itself
adapted.** `truefalse` moved further than either prior attempt (4→18) with
the same prompt-echo caveat; `cfgaccess`/`modedata` stayed flat. Confounds
checked clean (chars within 5% of baseline, identical `finish_reason=stop`
rate both conditions).

**attempt 4 (3x invoke oversampling) ran to completion — seventh honest
negative on `invoke`.** Full account in `data/tasks/coding-lora-p7-idioms.
md`'s "fourth attempt" addendum. Isolated the one variable the first three
attempts never changed: identified the 97 real training lines whose target
content already matches the invoke regex and tripled their representation
(invoke's share of the corpus: ~32%→~59%), reverting target_modules back
to attempt 2's set (attn/mlp/ssm only) so this tested oversampling alone,
not stacked on attempt 3's already-null lm_head lever. Ran ~2x slower per
step than attempts 2/3 (GPU pegged at 100%, no external contention found,
best guess is the tripled examples average longer). **`invoke` stayed at
0/18 even with 59% of training examples containing it.** `truefalse` moved
again (4→14, same range as attempts 2/3); `cfgaccess`/`modedata` flat
across all four attempts now, no exception ever recorded. Responses were
~19% shorter while completing MORE naturally (not a truncation confound).

**Real methodology bug caught mid-thread, now fixed as reusable
infrastructure**: the first validation pass for this attempt fired 16 of
18 generation requests at a dead server — the self-test wait had a fixed
timeout that "proceeded anyway" on expiry, right as a seed-retry respawn
was mid-flight. Caught by checking raw HTTP status codes, not just
aggregate scores (which would have looked like an ordinary null result).
Rewrote the wait as a genuinely open-ended health-confirmation poll (no
timeout that gives up and fires anyway) and committed it as `data/
control-vectors/run_validation_sweep.sh` — any future attempt should use
this script rather than re-deriving the same wait logic from scratch.

**where this leaves the thread**: four attempts now — dataset source,
target-module scope (including the output layer), and data density — all
landing at exactly zero on `invoke`, while every single one reliably moves
`truefalse`. This is about as strong a pattern as this method can produce
without changing approach entirely. The remaining levers (much higher rank
specifically on `lm_head`, or retrieval/few-shot injection of real corpus
examples at generation time instead of more weight-training) are a bigger
step than another parameter tweak — worth a deliberate decision, not
another same-shape attempt. No attempt 5 is in progress as of this
handover.

**Unrelated follow-up filed this session, since investigated and
adopted**: user linked `https://huggingface.co/peculiar-ragdoll/Qwen-
Sharp-Chat-Templates`. Deliberately not investigated mid-validation-sweep
(would have confounded attempt comparability), but once the LoRA thread
reached its resting point, read the raw `chat_template.jinja` directly
(not the model card): its own internal `template_version` string is
`qwen3.8-froggeric-v22.5.0` — "froggeric" is the exact author this
project's OLD `qwen3.5-fixed.jinja` already came from (per `coding.
spawn_inference_server`'s own comment), so this is an upstream update to
an already-trusted source, not a third-party swap. `reasoning_effort` is
genuinely consumed by it, resolving that open question directly (the old
template simply never referenced the kwarg — a real no-op). Same core
`<think>` boundary mechanism and historical-turn rendering as before, so
no conflict with anything the LoRA task's training-data assumptions rely
on. Live-verified before adopting: self-test ttft dropped from the usual
multi-second-to-multi-minute range (including retry-triggering reasoning
spirals) to 1.7–2.9s across all 3 prompts, and a real held-out idiom
prompt returned a concise, complete, `finish_reason=stop` response
instead of a rambling reasoning trace. **Adopted as the new default**
(`cfg/zenki/coding/zenka.v7`'s `coding.jinja.template_file` →
`data/jinja/templates/qwen3.8-sharp.jinja`); the old `qwen3.5-fixed.
jinja`/`qwen3.6-fixed.jinja` were deleted (fully superseded, git history
preserves them if ever needed). Full account in `data/tasks/coding-chat-
template-sharp-eval.md`. No fresh idiom-scoring baseline sweep was run
under the new template before adopting — worth checking as the first
suspect if a future LoRA attempt's baseline numbers look different from
this session's.

**four real infrastructure bugs found and fixed getting attempts 2/3
running, independent of whether either moves the needle**:
- `coding.lora_train_spawn` now has a `-w $out_dir` pre-flight check — a
  pre-existing-but-unwritable out_dir (e.g. hand-created before dispatch)
  previously passed the `!-d` check silently, ran a full training to
  completion, and only failed on the final adapter save — losing a whole
  run to a permission error found in the last 30 seconds.
- `coding.lora_train_spawn` now stops the live inference server itself
  (SIGTERM then SIGKILL) instead of refusing when one is running. Needed
  two new guards to be safe: `coding.handler.inference_server_sigchld` /
  `inference_crash_restart` now check `<coding.lora_training_in_progress>`
  the same way they already checked `<coding.draining>` — without this,
  the crash-detector "heals" a deliberate stop with a fresh respawn that
  fights training for the same VRAM (raced twice live before the guards
  existed).
- `base.source.collect_file_list` now filters candidate sign paths through
  `git check-ignore` — the sourcecode signing pass was appending an AMOS7
  footer to gitignored binary artifacts (a trained adapter's
  `.safetensors`), a strict length-checked format that broke outright once
  signed ("incomplete metadata, file not fully covered"). Prospective fix
  only — an already-mutated file needs its footer manually truncated off
  (read the safetensors header's own declared length, truncate to that).
- `lora-out/`'s parent directory itself (not just one run's out_dir) was
  `taeki:taeki` 755, blocking this protocol-7-owned zenka from creating
  any brand-new out_dir under it. Fixed once, durable for any future
  out_dir name.

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
