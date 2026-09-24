# Session Handover — 2026-09-14

**Read this before touching anything called "loadable memory," "module-catalog
embedding," "fasttext," "LoRA," or "control vector" for the coding zenka.**
These names have been getting conflated across sessions/compactions, and it
has repeatedly cost real momentum — see "the mistake to not repeat" below.

## FOLLOW-UP IDEAS, 2026-09-24 — coding backend lock & log tooling [ temporary, clear when done ]

Came out of the backend-lock session [ e8bb6b5b7, c12fe7d54, 484ea4bb9,
1f6d5aadd ]. Agreed in principle ; priority : 1, then 6.

1. **token-based backend lock** [ brief : data/tasks/coding-backend-lock-tokens.md ] — `backend_acquire` returns a token [ request
   seq ], `backend_release` only accepts the matching token, explicit `force`
   for unconditional callers [ stop-task, sweeps ]. Replaces the `lock_seq`
   patch ; reentrancy becomes "same token", the question the reverted
   task_state check was really asking. Three of four fixes that session were
   this one bug class [ task_id-only identity ].
2. **exact resume round in task-append** [ DONE 2026-09-24 ] — `round = scalar @messages` is a
   rough estimate [ 40 -> 63 jump in the task-5JXMWYY incident ] ; take the
   real last round from round_chain / task_state. Also removes false
   "duplicate round" hits in log scans.
3. **one structured log line per lock handoff** [ DONE 2026-09-24 ] —
   `lock <backend>: task-X#seq -> task-Y#seq [reason]` for acquire / release /
   queue / drop, so one grep reconstructs backend ownership over time.
4. **count automatic aborts by reason / matched-unit class** — a
   `coding.stats` counter [ whitespace / structural / phrase ] would have
   surfaced the 68 blank-line false positives in the repetition detector
   long before.
5. **offline fixture harness for stream detectors** [ DONE : bin/test-scripts/test-stream-repetition ] — keep real inputs [ box
   lines, tables, mojibake, phrase loops ] under `bin/test-scripts/`, run
   against the module source with `<coding.cfg.*>` stubbed ; the ad-hoc
   version caught an `@-`/`@+` clobber bug immediately.
6. **`coding.lock-status` command** — read-only view of each backend's
   holder, seq, queue, and each queued task's status ; optional
   `--drop-stale` doing the 484ea4bb9 cleanup on demand. Today a stuck lock is
   only inferable from the log, recovery is a zenka restart.
7. **log reading wrapper** [ DONE : bin/log-read ] — resolve `[L:…]` tokens [ `p7-log.anon.resolve` ]
   and add local time [ `p7c localtime` ] in-line, so raw zenka logs read in
   one pass ; also useful for local models pointed at logs.

## UPDATE, 2026-09-15 even later still still still — eleventh pass done
## AND self-corrected with a second prompt, live-only, no retrain.
## Reframed the tenth pass's stalled absolute-activation comparison as a
## DELTA comparison (adapter-on minus adapter-off, per side, since HF/
## GGUF use different base quantizations -- see the ninth pass). First
## prompt suggested a specific culprit, SSM layer 16 (+39.85% HF vs
## +1.83% GGUF); a second, unrelated prompt immediately run as the
## planned reproducibility check moved the biggest-mover layer to 19
## instead (+42.16% HF vs +23.21% GGUF that time) -- "layer 16
## specifically" does NOT survive and is corrected in the task file, not
## left standing. What DOES survive, better-evidenced by the second data
## point: GGUF's response to the adapter is real but attenuated, and the
## attenuation is content-dependent and inconsistent (roughly half-
## strength in one prompt, indistinguishable from noise in the other),
## not a fixed broken layer or a fixed ratio. Also caught a real bug
## along the way, same shape as the very first attempt in this whole
## thread: `eval-callback` has no automatic flash-attn/lora guard the
## way the production server does -- first off/on comparison came back
## byte-identical until `--flash-attn off` was added explicitly. Read
## the "eleventh pass" section (including its own correction addendum)
## in `data/tasks/coding-lora-p7-idioms.md`. Reusable tooling: `data/
## control-vectors/run_activation_delta_sweep.sh` (GGUF side, takes a
## prompt arg) + `data/control-vectors/hf_activation_delta_probe.py`
## (HF side, same).

## UPDATE, 2026-09-15 even later still still — tenth pass STARTED, NOT
## finished: an HF-vs-llama.cpp base-model activation comparison
## (embedding + layer0/layer3 hidden states, position 0, "The quick
## brown fox"). Inconclusive at the sample size reached (8 of 4096 dims,
## one position, two layers) -- needs full-vector norm/cosine comparison
## across more layers to be decisive, not done. REAL MISTAKE along the
## way, now fixed and documented: the first attempt loaded the HF side
## as fp32 on CPU (~36GB) on this 15GB-RAM host, and was interrupted
## mid-load by a genuine WSL shutdown loop that forced a full host
## restart -- likely memory pressure per the user, compounded by
## Firefox. No data lost (git was clean/pushed through the ninth pass
## already). Fixed to match every other HF probe in this thread (4-bit
## on GPU). A separate follow-up task was filed from the same incident:
## `data/tasks/powershell-host-memory-commands.md` (Windows-host-side
## memory visibility gap -- system zenka's mem-used is WSL/Linux-side
## only). Read the "tenth pass" section of `data/tasks/coding-lora-
## p7-idioms.md` before resuming this specific comparison -- and ALWAYS
## use the 4-bit-on-GPU HF loading pattern (`data/control-vectors/
## hf_activation_probe.py` or `lora_invoke_probe.py`) on this host,
## never fp32/CPU for a model this size.

## UPDATE, 2026-09-15 even later still — ninth pass done, live-only, no
## retrain: tested the eighth pass's own proposed next diagnostic
## (Q4_K_M quantization noise diluting the delta) by re-running the same
## 0/1/4x scale sweep against a newly-registered, correct-checkpoint Q8_0
## quant (`amos: P27KMTQ:X6B34JQ`, `petruhonk/...-Q8_0.gguf` -- NOT the
## "unrelated" rohit267 Q8_0 the task file warns about elsewhere, a real
## naming trap re-hit and caught this session). Result REFUTES the
## quantization hypothesis: higher precision made live transfer WEAKER,
## not stronger (`' <'` at scale 4.0: 6.84% Q4_K_M vs 1.76% Q8_0). Routing,
## alpha, rank/shape, and now base quantization are ALL ruled out by
## direct test or inspection. What's left needs a base-model (no adapter)
## HF-vs-llama.cpp activation-level comparison through the gated-delta-net
## layers -- a materially bigger diagnostic step, not started. Read the
## "ninth pass" section of `data/tasks/coding-lora-p7-idioms.md`.

## UPDATE, 2026-09-15 even later — eighth pass done, live-only, no
## retrain: closed the seventh pass's flash-attn confound question (NOT
## a confound, scale=0 control reproduces the FA-on baseline almost
## exactly) and found the first-ever real, scale-responsive live signal
## in this whole thread -- `' <'` goes 0% -> 0% -> 6.84% (rank 2!) as
## `--lora-scaled` goes 0 -> 1 -> 4, then peaks and the output degrades
## into garbage by scale 16 rather than converging toward HF's 83%. Also
## directly ruled out (by gguf_dump + shape inspection, not just
## reasoning) both remaining candidate mechanisms from the seventh pass:
## alpha is present and correct (32.0), and every lora_b tensor's rank
## dim is uniformly 16 across dense AND ssm tensor types. Read the
## "eighth pass" section of `data/tasks/coding-lora-p7-idioms.md` before
## touching this thread further -- next diagnostic proposed there is an
## F16-vs-Q4_K_M scale-matched comparison via the existing Q8_0 quant
## (NOT the 18GB F16 GGUF, unsafe to serve on this host, see below).
## Reusable sweep tool: `data/control-vectors/run_lora_scale_sweep.sh`.

## UPDATE, 2026-09-15 — LoRA thread ROOT CAUSE FOUND: corrupt local
## checkpoint shard, NOT a base mismatch. Read the "sixth pass" section
## of `data/tasks/coding-lora-p7-idioms.md` before acting on anything
## LoRA-related below; every earlier section's framing is superseded.

Numerical verification work for `data/tasks/coding-lora-p7-idioms-
checkpoint-quantize.md` found that the local petruhonk checkout (used
for ALL four LoRA training runs and the fifth-pass probes) had a
**corrupt shard 4** on disk since its 2026-09-10 fetch — right size,
right safetensors header, wrong data section (sha256 mismatch vs the
published HF LFS hash; suspected chunked-download stitching/resume bug
in the fetcher, not yet root-caused — hunt it before the next big
download). Layers 25[attn-out side]–31 + final norm were garbage in every training
run. Meanwhile petruhonk's PUBLISHED weights turn out to be identical
to rohit267's (ge525's independent GGUF conversion of petruhonk
reproduces the production mradermacher GGUF bit-exactly on every F32
anchor across all 32 layers) — **production was never mismatched; the
four adapters are the poisoned artifacts**, which fully explains the
fifth pass's real-in-HF/zero-transfer-live findings. The intact shard
4 was re-fetched (hash-verified) and installed 2026-09-15; the corrupt
file is quarantined (`...CORRUPT-20260910-do-not-use`). The task
author is running the serve+revalidate step separately with ge525's
pre-made GGUF (== production weights) — a negative there measures the
poisoned adapters, not the technique. **Real attempt 5 = retrain
against the now-intact checkpoint.** Also: the 18.4GB F16 GGUF at
`/mnt/ext-xfs-data/models-lmstudio/petruhonk/Qwen3.8-9B-Distill-
uncensored-heretic-GGUF/` is quantize-input ONLY — never serve it on
this 15GB host (that acceptance criterion caused an overnight VM OOM
crash and was withdrawn by the task author). A working, verified
qwen35 HF→GGUF converter now exists at `data/control-vectors/lora/
qwen35_hf_to_gguf.py` (+ read-only verifier `verify_qwen35_gguf.py`).

**addendum, same day**: ran the serve+revalidate step against ge525's
GGUF as planned, at a properly position-matched prompt (teacher-forced
prefix up to the token right before the invoke idiom, verified via raw
token-ID prompts to rule out any string-retokenization artifact) —
`invoke` did not transfer (HF/PEFT gave `' <'` 60% top1 on the poisoned
adapter; the live ge525-served server gave `' my'` ~59-60% both with
and without the adapter loaded, i.e. no measurable adapter effect at
all). This is exactly the pre-registered outcome for testing a poisoned
adapter against correct weights — not a new negative on the technique,
not further evidence of any base mismatch (there is none). Also
confirmed via the actual C++ loader validation logic
(`llama.cpp:7828-7841`) that the LoRA tensor shapes/orientation are
correct, ruling out a conversion-side bug as an alternative explanation.
One dead-end worth recording so a future session doesn't repeat it: a
naive `Qwen3_5ForCausalLM` + meta-device state-dict key comparison
looked like it showed 426/427 tensors failing to load at all (a
totally different, more severe "wrong model class" theory) — this was
wrong; `output_loading_info=True` on the real `from_pretrained()` call
shows zero missing/unexpected/mismatched keys, because transformers'
internal checkpoint-conversion mapping correctly strips the
`language_model.` prefix. The meta-device comparison doesn't go through
that mapping, so it gives a false positive. Trust `output_loading_info`
over a raw key-set diff for this kind of check.

**file cleanup, same day**: deleted the four poisoned adapter
directories (`data/control-vectors/lora-out/{p7-idioms,p7-idioms-real,
p7-idioms-real-lmhead,p7-idioms-invoke-oversampled}/adapter/`, git-
tracked config/tokenizer files removed via `git rm`-equivalent, gitignored
safetensors just deleted) and their three GGUF conversions in
`data/control-vectors/lora/`, plus two franken-tail F16 GGUFs (~18GB
each) superseded by the fresh rebuild. Kept: the fresh F16 rebuild
(valid, matches the intact checkpoint), ge525's Q4_K_M (valid,
confirmed == production weights), the pre-existing Q8_0 quant (predates
this whole thread, unrelated to the corruption, left alone per the
user's explicit call), and the quarantined corrupt shard 4 (kept
deliberately as the only physical evidence for the still-open
fetch.file.huggingface.* corruption-bug hunt. Fully wrapped up and
committed as of `7543bb958` — working tree clean.

**DONE, 2026-09-15 — real attempt 5 ran and is fully written up in
`data/tasks/coding-lora-p7-idioms.md`'s "seventh pass" section (read
that, not this summary). Short version: retrain against the
hash-verified intact checkpoint (attempt 2's exact config) produces
REAL, strong invoke-idiom learning in HF/PEFT space (in-corpus top1
50.7%→95.7%; position-matched `' <'` 83.2% top1, flipping baseline's
`' my'` 60.1%) — and it STILL does not transfer to live GGUF serving
(`invoke` 0→0 in the held-out sweep, eighth independent null; at the
position-matched live check `' my'` 59.1%→66.2% lora-on, `' <'` below
0.14% either way, while the HF/GGUF baselines agree almost exactly).
The checkpoint is now eliminated as an explanation; the discrepancy
localizes to ik_llama.cpp's LoRA-application semantics on qwen35 — a
serving-side bug hunt (candidate mechanisms listed in the write-up),
not a training-recipe one. Side effects live were real and positive:
truefalse 0→7, modedata 0→1, anti-idiom density dropped for the first
time (1.41→0.61/1k). Production server restored (OFSQC4I:QDBKEXY, no
lora flags, confirmed healthy). Operational notes for the next run:
`coding.lora_train_spawn` needs `->({'args' => {...}})` not a bare
hash; ge525's GGUF is durably in the models registry as checksum
LR7NW7A:XT57X3Y.

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

## UPDATE, 2026-09-14 later same session — the LoRA probe below was run,
## and it found something real. Read this before the "URGENT RESUME NOTE"
## section further down, which is now historical (its plan was executed).

Built and ran the agreed token-level logprob probe (no training). Full
numbers and methodology are in `data/tasks/coding-lora-p7-idioms.md`'s new
"fifth diagnostic pass" section — read that, not this summary, before
acting further. Short version: **the LoRA training itself works and
generalizes** (huge, real confidence boost on the invoke idiom, including
on module names never seen in training, measured directly in HF/PEFT
space) — but **the live GGUF-deployed server does not reproduce this at
all**, and raising the runtime lora scale makes the wrong answer more
confident rather than less, which isn't consistent with simple
underscaling. The prime suspect, found via one more check: the base
HF checkpoint all four training attempts used (`petruhonk/Qwen3.8-9B-
Distill-uncensored-heretic`) may not actually be the same fine-tune the
live production GGUF quantizes (`mradermacher`'s quant of `rohit267`'s
model, `rohit267` itself being 404'd back on 2026-09-10 when petruhonk
was substituted in as a stand-in) — their true baseline (no-adapter)
output distributions look meaningfully different on the one example
checked. **Not yet fully confirmed** — needs either an independent
checkpoint-identity verification or more baseline-vs-baseline samples
before committing to "retrain against the right checkpoint" as attempt 5.
This reframes, but does not retract, the four prior "honest negative"
write-ups: those are still correct as measurements of deployed behavior.

Also: this pass required stopping/restarting the live GPU server 5 times;
one real mistake happened along the way (a direct `coding.spawn_
inference_server` call bypassing model-path resolution, crashed) — fixed
immediately by switching to `coding.switch-model` for every subsequent
respawn. The `task_buffer_drop: dropped 9 buffers` log line seen right
after was initially misattributed to this crash; it's actually a routine
timer that only frees buffers for tasks already saved earlier by
`coding.handler.task_buffer_save` — unrelated, no data lost. Also worth
noting: only the child inference-server process crashed — the coding
zenka itself never went down, and `coding.switch-model` kept working
flawlessly for every respawn afterward, no zenka restart ever needed.
Server is restored to normal, guard cleared, verified via live `ps`
output before ending the session.

## URGENT RESUME NOTE — appended pre-compaction, 2026-09-14, uncommitted

**next agreed action, in order:**
1. LoRA `invoke` diagnostic (cheap, no training): probe whether the model's
   actual token-level probability for `<[module.name]>->(` moved AT ALL
   during any of attempts 2/3/4's training, using the existing checkpoints/
   GGUFs already on disk (`data/control-vectors/lora-out/p7-idioms-real*`,
   `data/control-vectors/lora/*.gguf`) — forward passes only, no new
   training. Also check how many tokens `<[module.name]>->(` splits into
   under this model's tokenizer, and whether any are rare/fallback tokens.
   This directly answers "not saturating the technique" vs "genuine ceiling"
   for `data/tasks/coding-lora-p7-idioms.md` — read that file's "fourth
   attempt" section for full context before doing anything else with LoRA.
2. THEN: scope a proper task file for mining real Claude/Kimi session
   transcripts to feed `data/tasks/coding-module-catalog-embedding.md`'s
   own stated next step (harvest real task_summary-shaped queries paired
   with actually-touched modules, re-run gate A against that distribution
   instead of waiting a week to passively collect it). Data already exists,
   confirmed live 2026-09-14 via reading `bin/mcp-server-p7` directly:
   - claude: `~/.claude/projects/-data-projects-protocol-7/<uuid>.jsonl`
     (one file per conversation), subagents at
     `<session-dir>/<uuid>/subagents/agent-<id>.jsonl`
   - kimi: `~/.kimi/sessions/<hash>/<uuid>/context.jsonl` (role=user/
     assistant), subagents at `<session-dir>/subagents/<agent-id>/
     context.jsonl`, plus a 109.5MB archive `/data/backup/kimi/kimi-
     sessions.full_dir.0000.tar.xz`
   - `bin/mcp-server-p7` already has a full reader/parser for both formats
     (`_kimi_session_dir`, `_list_kimi_sessions`, the claude `.claude/
     projects/...` path resolver, an existing "list or summarize recent
     claude/kimi sessions" MCP tool) — reuse this, don't write a fresh
     JSONL parser from scratch.

**unresolved side-thread, NOT solved, do not assume fixed**: user found
`task.persist.summary_tree.save` never actually lands `summary-tree.yaml`
anywhere under `/var/protocol-7/`. My first hypothesis (wrong module name,
missing `base.` prefix on `<[file.zenka_dir.write]>`) was WRONG and
retracted live — user corrected: `base.file.*` modules get aliased to
`file.*` at init time, so the call as written is actually correct
convention, not a bug. The real root cause is still unknown. It IS called
from two real call sites (`task.handler.cold-queue-sweep` gated on
`if $flipped`, and `task.cmd.summary-tree-notify`), so it's not dead code
either. Next diagnostic step not yet taken: check what `<task.summary_tree.
entries>` actually contains at the point of the call, and whether
`$flipped` in `cold-queue-sweep` is ever actually true in practice, before
assuming the write call itself is the problem.

**session state**: at the point this was appended, HANDOVER.md's own git
diff (this section) is UNCOMMITTED — check `git status` on `HANDOVER.md`
after any compaction/resume and commit it (with the user's signing pass)
before trusting anything else in this file as "landed."
