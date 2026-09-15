## [:< ##

# name  = task: LoRA fine-tune for protocol-7 coding idioms
# descr = train a small LoRA adapter on the coding zenka's model so it
#         reliably emits P7's structural idioms, since prompt fixes and
#         a control vector both failed to move them

## context

raised 2026-09-09, direct follow-on from `data/tasks/coding-control-
vector-p7-idioms.md` (see its 2026-09-09 addendum). that task fixed two
real bugs in the actual production system prompt (`data/yaml/context-
templates/system-base.yaml` / `system-tools.yaml`) and confirmed, via a
real production-prompt rerun of the same held-out-prompt harness, that
**prompt content alone -- even correct, bug-free prompt content -- does
not move the four structural P7 idioms**: `<[module.name]>->(` invocation
sugar, bare `<config.key>` access, `TRUE`/`FALSE` named constants, and
the `mode`/`data` reply shape. all four sat at 0-1 hits out of 9
generations in every condition tested, including the fixed real prompt.
the control vector itself (mean-diff over 46 contrastive pairs) also
failed to move these four specifically -- it steered surface register
(lowercase comment style, bracket punctuation density) instead, which is
plausibly the dominant direction in a mean over pairs whose most
consistent difference IS surface register, with the low-frequency
structural tokens getting washed out of the average.

this task is the next thing on the list from that addendum: a real
gradient-trained LoRA adapter, which can in principle learn a
low-frequency, syntactically-precise pattern that a linear steering
vector cannot.

## confirmed mechanism [ read directly from this checkout's source ]

- this project's `ik_llama.cpp` build (`/data/source/ik_llama.cpp`)
  supports `--lora` / `--lora-scaled FNAME S` (repeatable, user-defined
  scale) -- confirmed in `common/common.cpp:1699-1712`, `common/
  common.h:57-63,386-387,714,726`. loading and application:
  `common/common.cpp:4113-4127,4175` (`llama_lora_adapter_init`,
  `llama_lora_adapters_apply`). **this is a load-time adapter, applied on
  top of the existing GGUF weights -- no merge into the base model and no
  requantization needed**, structurally identical in spirit to how the
  control vector task wired `--control-vector-scaled` into `coding.spawn_
  inference_server` (config-gated, backend-agnostic, commented out by
  default).
- the repo vendors `convert_lora_to_gguf.py` and `requirements/
  requirements-convert_lora_to_gguf.txt` at the ik_llama.cpp root --
  confirmed present. this converts a PEFT-trained adapter (safetensors +
  adapter_config.json, the standard HF/PEFT output format) into the GGUF
  LoRA format `--lora-scaled` expects. **not yet run or tested in this
  repo -- confirm its exact invocation and output shape against a real
  trained adapter before assuming the flag names/behavior match any
  online tutorial.**
- the live model is `OFSQC4I:QDBKEXY` = Qwen3.8 9B Heretic Uncensored,
  served as a **Q4_K_M GGUF quantization**
  (`/mnt/ext-xfs-data/models-lmstudio/mradermacher/Qwen3.8-9B-heretic-
  uncensored-i1-GGUF/`, 5.6GB). **this file cannot be used for gradient
  training directly** -- PEFT/transformers-based LoRA training needs the
  original HF-format checkpoint (safetensors, fp16/bf16) of the SAME
  fine-tune, not a from-scratch Qwen3 base, or the adapter is trained
  against a different weight distribution than what it will be applied
  to at inference. `src/fetch.file.huggingface.*` exists in this repo
  (search/list/download handlers) and is the established way to pull an
  HF repo locally -- use it to fetch the "heretic uncensored" HF repo
  matching this exact quant's source model, not a substitute.
- response parsing already separates reasoning from content: `content`
  and `reasoning_content` are distinct fields in the server's completion
  JSON (confirmed live, `data/control-vectors/results/real-system-
  prompt-v2/A.seed13.json`).

  **CONFIRMED 2026-09-10, read directly from `data/jinja/templates/
  qwen3.5-fixed.jinja`**: for the turn currently being generated
  (`add_generation_prompt`, lines 180-186), the template always injects
  `<|im_start|>assistant\n<think>\n` into the PROMPT before generation
  starts (when thinking is enabled, the default) -- so the model's own
  raw generated tokens continue from inside an already-open `<think>`
  block and must emit a literal `</think>\n\n` closer before the answer
  content (lines 114-129 show this is exactly how a completed assistant
  turn gets re-serialized: `<think>\n{reasoning_content}\n</think>\n\n
  {content}`). Earlier assistant turns in the same conversation's history
  (`loop.index0 <= ns.last_query_index`) render with NO think tags at
  all -- just `{content}` -- think-wrapping is specific to the turn being
  trained/generated, not a per-turn-always thing.

  **what this means for training data**: build target (assistant) turns
  through `apply_chat_template()` against this exact jinja (or replicate
  its logic), wrapping the target turn as `<think>\n{reasoning}\n
  </think>\n\n{content}` -- an intentionally short/empty `reasoning` is
  fine and template-consistent (matches the `enable_thinking=false`
  branch's shape even when thinking is nominally on), but training on
  bare `{content}` with no think-wrapper at all for the turn being
  learned would create a real train/inference distribution mismatch,
  since the runtime always opens `<think>` before the model ever
  generates a token for that turn.
  side-note, **RESOLVED 2026-09-13** (`data/tasks/coding-chat-template-
  sharp-eval.md`): the live coding zenka's server invocation passes
  `--chat-template-kwargs {"reasoning_effort":"medium"}`, but the jinja
  file used throughout every attempt in this task (`qwen3.5-fixed.jinja`)
  had no reference to `reasoning_effort` anywhere -- confirmed a genuine
  no-op for that specific template, not a hidden ik_llama.cpp-side
  consumer. `qwen3.5-fixed.jinja` has since been replaced with a newer
  same-lineage unified template (`qwen3.8-sharp.jinja`) that DOES consume
  the kwarg -- irrelevant to training-format correctness above (loss
  masking only cares about the `<think>...</think>` boundary, which both
  templates render identically), but the reasoning_effort kwarg is no
  longer a no-op going forward.

## hazards that waste a run [ read before doing anything ]

0. **[added 2026-09-10, do not skip] loss must be masked to the
   post-`</think>` content span, not computed over the full assistant
   turn.** the confirmed mechanism above means every training target
   turn gets serialized as `<think>\n{reasoning}\n</think>\n\n{content}`.
   this dataset's `reasoning` is going to be synthetic/empty (see scope
   item 1 -- there is no real chain-of-thought to teach, and fabricating
   one risks baking in more surface-register drift, the exact failure
   mode that sank the control vector). **if the trainer computes loss
   over the ENTIRE assistant span** (including the empty `<think>\n\n
   </think>\n\n` prefix), the adapter learns "always immediately close
   think with nothing in it" -- which directly fights the live server's
   `reasoning_effort=medium` config and could suppress or destabilize
   the model's actual reasoning behavior in production, independent of
   whether the four structural idioms move at all. **fix: mask the loss
   to only the tokens after `</think>\n\n`** (a standard completion-only
   / response-template loss mask, supported by `trl`'s
   `DataCollatorForCompletionOnlyLM` or equivalent manual masking against
   the tokenized `</think>\n\n` boundary) -- confirm whatever training
   script is used actually does this, don't assume a default SFT
   trainer does it for you.

1. **no training stack is installed at all.** `python3 -c "import
   torch"` / `peft` / `transformers` all fail with `ModuleNotFoundError`
   on this host, confirmed 2026-09-09. budget real setup time for this,
   verify CUDA toolkit / driver version compatibility with whatever
   torch build gets installed before writing any training code against
   it.

2. **GPU is not free.** `nvidia-smi` showed 240MB free of 12288MB total
   (RTX 3060) while the coding zenka's own inference server was running
   the 9B Q4_K_M model at `-ngl 33` -- confirmed 2026-09-09, same host.
   even 4-bit QLoRA training of a 9B model needs several GB of headroom.
   **training will require stopping or reducing the live coding zenka's
   GPU inference server for the duration of the run** -- this is a real
   operational interruption to the zenka's own working capability, not
   something to do silently. either schedule an explicit maintenance
   window with the user, or investigate whether a smaller/cpu-offloaded
   training configuration can coexist with a reduced-ngl live server --
   don't assume either is fine without asking first.

3. **the existing 46-pair contrastive dataset
   (`data/control-vectors/dataset/{positive,negative}.txt`) is far too
   small for gradient fine-tuning.** it was sized for a mean-diff
   activation vector, where every pair contributes independently to an
   average; a LoRA adapter needs enough examples per idiom pattern to
   generalize rather than memorize 46 verbatim strings. build a properly
   sized dataset (order of hundreds, likely generated programmatically by
   varying surface context around the same 8 idiom categories the rubric
   in `data/control-vectors/score.py` measures) before training.
   **do not include the 3 canonical held-out prompts** (`P_A`/`P_B`/`P_C`
   in `run_gens.sh`, reused across every experiment in this thread so
   far) in the training set, or the validation numbers from here on are
   meaningless -- consider adding a SECOND, never-before-used held-out
   set as well, since a large enough LoRA dataset increases genuine risk
   of the model having implicitly seen close paraphrases of `P_A`/`P_B`/
   `P_C` during training even if not verbatim.

4. **rank/target-module choice needs to be decided and written down
   before training, not tuned by trial and error against the eval set.**
   structural P7 idioms are a fairly mechanical, low-entropy
   substitution (roughly: "use this token sequence instead of that
   one"), which argues for a small rank (order 8-16) on attention +
   mlp projections rather than a large one -- but this is a starting
   hypothesis, not a confirmed fact; state whatever is chosen and why in
   the results before running, same discipline as the control vector
   task's pre-registered rubric.

   **decided 2026-09-10, then partially INVALIDATED same day (see below)**:
   rank 16, alpha 32 (2x rank, the standard PEFT default), dropout 0.05,
   targeting `q_proj, k_proj, v_proj, o_proj, gate_proj, up_proj,
   down_proj` (the usual Qwen-family attention+mlp projection set) --
   confirm these exact module names exist on the fetched checkpoint
   (`named_modules()`) before writing the `LoraConfig`.

   **correction, same day, from reading the local `config.json` (see
   base-checkpoint blocker below)**: this is NOT a plain dense
   transformer. `model_type: qwen3_5`, hybrid architecture --
   `layer_types` shows only every 4th of 32 layers is `full_attention`,
   the other 24 are `linear_attention` (has `linear_conv_kernel_dim`,
   `linear_key_head_dim`, `mamba_ssm_dtype` -- SSM/mamba-style, not
   standard QKV attention). **the rank/target-module list above almost
   certainly does not apply uniformly** -- `linear_attention` layers
   likely use different projection names entirely (in_proj/conv1d/
   out_proj-style, not q_proj/k_proj/v_proj/o_proj), and targeting only
   the 8 `full_attention` layers' QKVO would touch a small minority of
   the network. **this must be re-derived from the real checkpoint's
   `named_modules()` once/if it's obtained -- do not write a `LoraConfig`
   against the assumption above, it was written before this architecture
   detail was known.** also a real vision tower is present
   (`vision_config`, `image_token_id` etc, and a CLIP mmproj GGUF exists
   locally) -- confirm the LoRA is being applied to the text backbone
   only, not accidentally including vision-tower modules whose naming
   might overlap.

   **RE-DECIDED 2026-09-10, checkpoint now in hand -- read directly from
   `model.safetensors.index.json`'s weight map, not assumed**: confirms
   the hybrid architecture exactly. Per-layer naming:
   - **MLP** (`mlp.gate_proj`, `mlp.up_proj`, `mlp.down_proj`) -- IDENTICAL
     naming on every one of the 32 backbone layers regardless of type,
     plus the separate `mtp.layers.*.mlp.*` head. Safe, uniform target
     across the whole network.
   - **`self_attn.{q,k,v,o}_proj`** (+ `q_norm`/`k_norm`) -- only on the
     8 `full_attention` layers (indices 3, 7, 11, 15, 19, 23, 27, 31 --
     confirmed by grepping which layer indices have `self_attn.*` keys
     vs `linear_attn.*` keys) and the separate `mtp.layers.*.self_attn.*`
     head.
   - **`linear_attn.{in_proj_qkv,in_proj_a,in_proj_b,in_proj_z,out_proj,
     conv1d}`** (+ `A_log`, `dt_bias`, `norm`) -- the other 24 layers'
     SSM/mamba-style projections. Genuinely no overlap with the
     `self_attn.*` names (`out_proj` vs `o_proj` are distinct strings,
     no collision risk in PEFT's substring-match `target_modules`).

   **decision**: target ALL of `q_proj, k_proj, v_proj, o_proj` (8
   full-attention layers), `gate_proj, up_proj, down_proj` (all 32
   layers, both types), AND `in_proj_qkv, in_proj_a, in_proj_b,
   in_proj_z, out_proj` (24 linear-attention layers) -- full-network
   coverage regardless of layer type, rather than leaving 3/4 of the
   network un-adapted by only targeting the classic QKVO names. Rank 16
   / alpha 32 / dropout 0.05 stand from the original decision -- LoRA's
   per-target parameter cost is small enough that adding the extra
   target-name coverage doesn't meaningfully change the rank/alpha
   tradeoff. Do NOT target anything under `mtp.*` or `model.visual.*`
   (confirmed distinct prefix) -- the MTP head and vision tower are out
   of scope for a text-idiom fix.

## base-checkpoint blocker [ found 2026-09-10, needs a decision before scope item 3 can proceed ]

**the exact source HF repo no longer exists.** confirmed via the live
HF API with a valid token: `GET /api/models/rohit267/Qwen3.8-9B-heretic-
uncensored` -> `404 {"error":"Repository not found"}` (not 403/gated --
genuinely gone). `GET /api/models?author=rohit267` -> `[]`, the account
has zero public models now. Cross-checked against both the mradermacher
quant's own `cardData.base_model` and its README's "weighted/imatrix
quants of https://huggingface.co/rohit267/Qwen3.8-9B-heretic-uncensored"
line -- same repo path either way, genuinely unreachable now, not a
naming/case mistake on this session's part.

**no equivalent mirror found.** searched HF broadly for "heretic
uncensored" -- found `Noobito45/Qwen3.8-9B-heretic-uncensored-NVFP4-GGUF`,
same-sounding name, but its own `base_model` is `empero-ai/Qwen3.8-9B`
via a DIFFERENT decensoring pipeline (the "Heretic" abliteration tool
v1.4.0) -- a different fine-tune with plausibly different weights, not a
re-upload of rohit267's actual model. Using it would repeat exactly the
mistake the task already warns against ("training against a different
weight distribution than what it will be applied to at inference").

**what IS available locally**: `/mnt/ext-xfs-data/models-lmstudio/
rohit267/Qwen3.8-9B-heretic-uncensored/` has `qwen3.8-9b-abliterated-
Q4_K_M.gguf`, `qwen3.8-9b-abliterated-Q8_0.gguf` (both GGUF, quantized,
not HF/safetensors), a CLIP-architecture mmproj GGUF (vision tower,
unrelated to this task), and a real `config.json` (the architecture
detail used above). **no safetensors, no fp16/bf16 HF-format weights
anywhere found** -- this is presumably what LM Studio downloaded at the
time, before the source repo disappeared.

**RESOLVED 2026-09-10 -- option 1 above is a KNOWN DEAD END, do not
retry it.** A prior session (2026-09-09, commit `12271bf2c`, "coding:
idiom conformance gate -- scan/repair/harvest, control-vector and LoRA
paths closed out") already took exactly this path: dequantized the
production i1-Q4_K_M GGUF to bf16 safetensors
(`data/control-vectors/lora/dequant_to_hf.py`) and attempted PEFT LoRA
training against it. Full account in `data/control-vectors/lora/
PROGRESS.md`: training loss came back at 14.49 (worse than
`ln(vocab)=12.4`, i.e. worse than random chance), one real mapping bug
was found and fixed (`fix_a_log.py` -- GGUF's precomputed `ssm_a` vs
HF's `A_log` use different sign/transform conventions), loss only
improved to 15.8 (still broken, "multilingual salad" generation). A
three-way ablation (`ablate_probe.py`, zeroing mlp-only / full-attn-only
/ linear-attn-only) localized the corruption to something SHARED across
both mixer types (embed/norm/lm_head/a global dequant scale), not a
single fixable layer -- the diffuse case per this task's own hazard-4
discipline, not "one fix away." That session paused the ML path
entirely and the project shipped a different, non-ML solution instead
(the idiom conformance gate referenced in the commit title, config-
gated via `coding.cfg.idiom_gate` in `cfg/zenki/coding/zenka.v7`,
already live in the repo today). **Neither `HANDOVER.md` nor this task
file reflected any of this before 2026-09-10** (`HANDOVER.md` incorrectly
stated the LoRA path was "never actually attempted") -- corrected now
in both places.

what actually happened instead, same day: a DIFFERENT alternate HF repo
was found and fetched -- `petruhonk/Qwen3.8-9B-Distill-uncensored-
heretic`, a genuine multi-shard safetensors release (own tokenizer,
processor_config, chat_template.jinja; not a same-session hand-rolled
dequantization) -- now at `/mnt/ext-xfs-data/models-lmstudio/petruhonk/
Qwen3.8-9B-Distill-uncensored-heretic/`. Since this sidesteps the
specific dequantizer that produced the corruption above, it needed its
own soundness check before spending hours training against it:
**pre-training sanity check, 2026-09-10** (`sanity_gen.py`-style
coherence + masked-loss probe, same methodology the prior session used
to catch its own corruption): two generic (non-p7) prompts produced
coherent, on-topic, English-requested-but-code-switched-CoT output (a
known Qwen-distill trait, confined to the `<think>` span this task's
own loss-masking excludes from training regardless) -- NOT the prior
session's incoherent, off-topic "salad." Masked-content loss (post-
`</think>`, matching this task's actual training-loss shape) over 8 real
dataset examples from `positive-expanded.txt`: **[9.0, 8.76, 9.16, 7.71,
9.56, 8.34, 8.78, 10.01], mean 8.914** -- roughly 3.5 nats BELOW the
`ln(248320)=12.4` random-chance floor, tightly clustered (no outliers),
vs. the prior attempt's 14.5-15.8 (ABOVE random chance). This is the
expected zero-shot signature of an intact base model that has simply
never seen p7 idioms before (exactly the gap this task exists to
close), not corruption -- record this number as the pre-training
baseline: **training that ends up at or above ~8.9 means something went
wrong.**

target-module count independently confirmed via a fast meta-device
instantiation (no weight loading needed): exactly 248 `nn.Linear`
leaves collected (32 q/k/v/o attn-proj across 8 full-attention layers,
96 mlp gate/up/down across all 32 layers, 120 SSM in_proj_qkv/a/b/z +
out_proj across the 24 linear-attention layers), zero non-Linear
surprises, zero `mtp`/`visual` leakage -- matches the RE-DECIDED target-
module list above exactly.

remaining known gap, NOT blocking training, blocks the later conversion
step (scope item 5): this repo's vendored `convert_lora_to_gguf.py`
(`ik_llama.cpp`) has no `qwen35` support (`gguf-py` lacks
`MODEL_ARCH.QWEN35`, confirmed by the prior session). `data/control-
vectors/lora/lora_to_gguf.py` is that session's custom GGUF LoRA
writer for exactly this gap -- read and reuse it once a real adapter
exists, rather than re-deriving from scratch.

5. **validate with the same fixed rubric (`score.py`), but apply the
   2026-09-09 addendum's lessons**: report length-normalized (idiom per
   1000 chars) numbers alongside raw counts, and call out separately
   which idiom categories moved -- a raw-count win driven by `comment`/
   `bracket` mimicry again would repeat the exact confound found and
   caught this session, not a genuine result.

## training run log [ 2026-09-10 ]

- training stack: `.venv-lora` (torch 2.14.0+cu126, transformers 5.17.0,
  peft 0.20.0, bnb 0.50.2, accelerate 1.15.0)
- pipeline: `data/control-vectors/train_lora.py` (python, unavoidable --
  torch/transformers/peft have no perl bindings) spawned + monitored via
  a proper P7 zenka orchestration layer, mirroring this session's
  `fetch.file.huggingface.download` pattern exactly: `src/coding.
  lora_train_spawn` (IPC::Open3 spawn, `pause_ondemand_timeout`,
  `report_child_pid`), `src/coding.handler.lora_train_stdout` (parses
  the python side's single-line JSON progress events), `src/coding.
  handler.lora_train_stderr` (raw diagnostic drain, EOF-cancel fixed the
  same way this session's download-stderr CPU-loop bug was), `src/
  coding.handler.lora_train_watch` (5s timer, `kill(0,$pid)` liveness
  check + `resume_ondemand_timeout` pairing, same as `download_progress`).
- config-gated lock: `<coding.lora_training_in_progress>` (mirrors
  `coding.spawning_in_progress`), refuses to spawn if the live inference
  server is still running (checked via `<coding.inference_servers>`,
  not a bare pid guess) -- stopped it via `kill(-pid)` run from inside
  the coding zenka's own `eval-code` (runs as the `protocol-7` unix user,
  which owns the child; a direct `kill` from an interactive shell as a
  different user is refused, confirmed live).
- launch command: rank 16 / alpha 32 / dropout 0.05, target_modules =
  the 248-module list decided above, batch 1 x grad_accum 8, lr 2e-4,
  3 epochs over 378 examples (`positive-expanded.txt`) -> 144 total
  steps.
- **loss trajectory, steps 1-10**: 8.49, 7.24, 6.61, 6.64, 6.43, 4.57,
  4.90, 4.68, 4.55, 4.43 -- steady descent from the pre-training baseline
  (8.914 mean, see above), no NaN/explosion, normal step-to-step noise.
  GPU near VRAM capacity throughout (12066/12288 MiB, single-digit MiB
  free) but stable -- no OOM.
- known slow path, not a bug: `causal_conv1d` / `flash-linear-attention`
  are not installed, so the SSM linear-attention layers fall back to
  reference PyTorch kernels (~30-40s/step observed with gradient
  checkpointing) -- full 144-step run projects to roughly 1-1.5 hours,
  not the worst-case "multi-hour" this task originally budgeted for.
- **conversion (scope item 5), done**: `data/control-vectors/lora/
  lora_to_gguf.py` only mapped the 7 classic dense-transformer projection
  names -- crashes on this adapter's SSM tensors. Extended its `HF_TO_
  GGUF` dict with 5 more entries for the linear-attention layers,
  confirmed by exact tensor-SHAPE match (not name-similarity guessing)
  against the real, already-working production GGUF: `in_proj_qkv` ->
  `attn_qkv`, `in_proj_z` -> `attn_gate`, `in_proj_a` -> `ssm_alpha`,
  `in_proj_b` -> `ssm_beta`, `out_proj` -> `ssm_out`. Ran clean: 248 lora
  pairs (496 tensors) written to `data/control-vectors/lora/p7-idioms-
  lora.OFSQC4I-QDBKEXY.gguf`, `general.architecture=qwen35` /
  `adapter.type=lora` / `adapter.lora.alpha=32.0` confirmed via a direct
  GGUF read.

- **REAL BUG found deploying it, 2026-09-10: this fork's LoRA application
  silently no-ops under flash attention.** `llama_lora_adapter_set:
  flash_attn is not compatible with LoRA` (only visible with
  `--verbose` -- the live server's `--log-disable` hides it entirely).
  The adapter still loads without error (496 tensors logged, correct
  buffer size), so the only symptom is a scale=0 vs scale=1.0 output
  that is **byte-for-byte identical on the same seed/prompt** -- caught
  via exactly that differential test before trusting any qualitative
  read of the output. `--flash-attn off` (a supported runtime flag on
  the same `-cuda-fa` binary, no separate build needed) fixes it --
  confirmed via the same differential test showing a real, different
  output once off. Fixed in `src/coding.spawn_inference_server`: now
  appends `--flash-attn off` automatically whenever `coding.cfg.
  lora_adapter` is configured. **Real, measurable cost**: flash
  attention is a genuine speed optimization, not a quality-affecting
  one -- disabling it does not itself explain or fix any coding-quality
  issue, it was only ever gating whether the adapter's deltas get
  applied at all. Cost observed live: one of the coding zenka's own
  self-test prompts took 403.9s time-to-first-token with it off, vs.
  the normal sub-30s. This is why the fix is scoped to fire only when
  a lora adapter is actually configured, not globally.

## validation result [ scope item 7, 2026-09-10 -- FOURTH HONEST NEGATIVE
## on the `invoke` idiom specifically, same discipline as the addendum's
## and the catalog-retrieval thread's prior honest negatives ]

condition `baseline` (no lora, flash-attn on, normal startup) vs.
`lora-on-scale1` (rank-16 adapter, scale 1.0, flash-attn off out of
necessity) -- both held-out sets (`P_A/B/C` via `run_gens.sh`, `P_D/E/F`
via `run_gens_lora.sh`, 3 seeds each, `score.py`'s fixed pre-registered
rubric), length-normalized per the 2026-09-09 addendum's discipline:

```
                 chars   idiom(raw)  idiom/1k   anti(raw)  anti/1k
baseline         22847   21          0.92       50         2.19
lora-on-scale1   12558    9          0.72       47         3.74
```

structural-only subcategory (`invoke`+`cfgaccess`+`truefalse`+
`modedata` -- the number this task exists to move, per hazard 5):
baseline 4 (0.18/1k) -> lora-on 5 (0.40/1k). **This is NOT a real gain,
say so plainly**: the absolute count moved by exactly one occurrence
(a single `cfgaccess` hit in `F.seed7777`); the /1k figure roughly
doubling is a denominator effect (total chars nearly halved), not
increased idiom density. Length normalization corrects for verbosity
confounds -- it cannot rescue n=1, and reporting the ratio alone here
would manufacture a win out of a length collapse. Per-idiom breakdown,
combined across both held-out sets:

- **`invoke`: 0 -> 0.** The single largest weighted training category
  (~120/378 examples), trained to a final loss of 0.336, produced ZERO
  `<[module.name]>->(` hits in 18 novel-prompt zero-shot generations.
  **Fourth independent null on this specific idiom** across this
  multi-session thread: the system-prompt fix, the mean-diff control
  vector, and now a real gradient-trained LoRA adapter all failed to
  move it.
- `cfgaccess`: 0 -> 1. First nonzero result for this idiom anywhere in
  the thread's history. One occurrence -- a genuinely novel data point,
  explicitly NOT a result; not distinguishable from noise at n=1.
- `truefalse`: 4 -> 4. Flat.
- `modedata`: 0 -> 0.

**the direction that should worry more than the flat structural
number**: anti-idiom density (generic-style markers expected to move
the OTHER way) rose 2.19 -> 3.74/1k. `coloncolon` (`Foo::Bar`-style
package refs) went 0 -> 6, `barebool` (`return 0`/`return 1`) went
0 -> 4, both appearing ONLY in the adapter-on condition. Matches what a
manual read of one adapter-on generation already showed directly: full,
syntactically valid, on-topic Perl (`package coding::helper::
enforce_quota; ... use Protocol7::Conf; ... return 0;`) -- a real
behavior change, just toward **generic Perl module conventions**, not
toward P7's bespoke syntax. The adapter learned "Perl-shaped" from the
dataset's surface form (real code, real syntax) without learning the
specific bespoke substitution the dataset's `<[...]>->()` /`<config.key>`
/`TRUE`/`FALSE` examples were meant to teach.

**second confound, root-caused via `finish_reason`+`completion_tokens`
on every response file (not guessed)**: adapter-on responses are ~45%
shorter in aggregate (12558 vs 22847 chars). Cause: 14/18 adapter-on
responses hit `finish_reason=stop` (natural EOS) vs. only 8/18 under
baseline (the rest hit the 700-token cap). **The adapter learned to
terminate generation early** -- a direct, traceable artifact of
training on `positive-expanded.txt`'s short, single-snippet targets
(no elaboration, no multi-paragraph discussion in the training data),
not a sign of the model "getting to the point" faster. Less generated
text per response mechanically reduces the opportunity for any idiom
(target or anti) to appear at all, independent of whether the adapter
changed idiom PREFERENCE — this is exactly the kind of confound hazard
5 was written to catch, and the honest-negative culture already
established by `embedding_search`'s four negatives and this task's own
two prior null results.

**verdict**: honest negative on `invoke`, the idiom this task most
needed to move. No scale sweep run -- hazard 4's own discipline (decide
before training, don't tune against the eval set) applies equally to
tuning scale after seeing results; a sweep now would be exactly that.
If a follow-up is warranted, the more promising premise is dataset
construction, not hyperparameters: `data/idioms/corpus/` (the shipped
conformance gate's harvested draft->corrected pairs, `coding.cfg.
idiom_gate = scan`) is real in-distribution training data this
attempt's synthetic 378-example set lacked and had to approximate --
exactly what the closure commit (`12271bf2c`) already named as the
missing ingredient every prior ML attempt (control vector, this LoRA
run) had to synthesize instead of harvest. Needs the gate to have run
for a while first to accumulate a real corpus.

**what stays**: the flash-attn incompatibility fix in `coding.
spawn_inference_server` is a genuine, independent bug fix (kept); the
extended `lora_to_gguf.py` SSM tensor mapping is genuine, reusable
infrastructure for any future qwen3_5 LoRA (kept); the project-memory
correction (HANDOVER.md / this file's dequantization-dead-end section)
stands regardless of this result.

## restore state [ scope item 8, 2026-09-10 ]

`coding.cfg.lora_adapter`/`_scale` re-commented out in `cfg/zenki/
coding/zenka.v7` (back to the disabled-by-default state), live gpu
server respawned with no lora flags and flash-attn back on (normal
startup, verified via process args + a fresh self-test pass). VRAM
confirmed free beforehand. The trained adapter (`data/control-vectors/
lora-out/p7-idioms/adapter/`, PEFT format) and converted GGUF (`data/
control-vectors/lora/p7-idioms-lora.OFSQC4I-QDBKEXY.gguf`) are left in
place, not deleted -- real artifacts from a real run, useful reference
for the dataset-construction follow-up above even though this specific
config isn't deployed.

## second attempt [ real git-mined data, 2026-09-12 -- FIFTH HONEST NEGATIVE
## on `invoke` ]

follow-on from the dataset-construction lead the 2026-09-10 verdict named:
`data/idioms/corpus/` (the idiom conformance gate's harvested draft-
>corrected pairs) had accumulated real in-distribution examples since
that gate went live -- this attempt trained against `data/idioms/corpus/
mined.curated.sft.txt`, real p7 code, not another synthetic set.

- training : same rank 16 / alpha 32 / dropout 0.05 / full target-module
  list as the first attempt, 3 epochs over the mined corpus -> 114 steps.
  clean run once a real, unrelated permission bug (`out_dir` pre-existing
  with the wrong uid, see `src/coding.lora_train_spawn`'s `-w $out_dir`
  pre-flight check, committed separately) stopped costing a full re-run
  on the final save. final loss 1.37.
- conversion : `lora_to_gguf.py` ran clean against this adapter unchanged
  -- 248 pairs / 496 tensors, same architecture as the first run confirms
  the converter generalizes. **found + fixed in the process**: this
  project's source-signing pass appends an AMOS7 footer to any tracked
  file it signs, including this adapter's `adapter_config.json` /
  `tokenizer_config.json` / `tokenizer.json` (breaks strict JSON parsing)
  and, worse, `adapter_model.safetensors` itself (a strict length-checked
  format -- the appended footer made it fail to load at all, "incomplete
  metadata, file not fully covered"). fixed by reading the safetensors
  file's own header to recompute its correct declared size and truncating
  the appended bytes off; `base.source.collect_file_list` now filters the
  sign-candidate list through `git check-ignore` so a gitignored artifact
  never gets signed in the first place -- but that fix is only
  prospective, doesn't undo a file a PRIOR run already mutated. lesson:
  convert BEFORE signing/committing artifact files, same order the first
  run used, not after.
- differential test : scale=0 vs scale=1 same-seed comparison confirmed
  the adapter is genuinely applied (`reasoning_content` diverges from the
  first token; `content` alone looked byte-identical only because
  `max_tokens=200` never escaped the `<think>` span in either condition
  -- diff the right field before trusting a byte-identical verdict).
- validation : same discipline as the first attempt, fresh baseline (not
  reused numbers), `run_gens.sh` + `run_gens_lora.sh`, 3 seeds each:

```
                 chars   idiom(raw)  idiom/1k   anti(raw)  anti/1k
baseline         22847   21          0.92       50         2.19
lora-on-real     21509   23          1.07       57         2.65
```

  structural-only subcategory (`invoke`+`cfgaccess`+`truefalse`+
  `modedata`): baseline 4 (0.18/1k) -> lora-on 12 (0.56/1k). unlike the
  first attempt, this is NOT primarily a length-collapse or early-EOS
  artifact -- total chars are within 6% of baseline (vs. the first
  attempt's ~45% collapse), and `finish_reason=stop` is actually HIGHER
  under lora-on (13/18 vs 8/18 baseline), the opposite direction from the
  first attempt's confound. per-idiom:
  - **`invoke`: 0 -> 0.** the fifth independent null on this specific
    idiom (system-prompt fix, mean-diff control vector, the first
    synthetic-dataset LoRA, and now a real-git-mined-data LoRA all
    produced zero `<[module.name]>->(` hits in held-out generation). real
    training data did not succeed where synthetic data failed.
  - `cfgaccess`: 0 -> 0. flat, still no second occurrence anywhere.
  - `truefalse`: 4 -> 12. the only real movement, entirely concentrated
    in the `P_D` (`enforce_quota`) responses. flagged, not claimed clean:
    `P_D`'s own prompt text says "...returning FALSE in that case", so
    some of this is plausibly prompt-echo rather than idiom adoption --
    but baseline received the identical prompt and only scored 4 there
    vs. lora-on's 12, so it is not PURELY an echo artifact either.
  - `modedata`: 0 -> 0. flat.
  - anti-idiom density rose again (2.19 -> 2.65/1k), same direction as
    the first attempt -- some generic-style drift persists alongside
    whatever real signal `truefalse` represents.

- restore state : `coding.cfg.lora_adapter`/`_scale` cleared (in-memory,
  not written to `zenka.v7` -- this attempt was tested via `coding.eval-
  code` + `coding.switch-model` respawns, never made the default-on
  config), live gpu server respawned with no lora flags / flash-attn back
  on, verified via process args. new adapter/gguf left in place: `data/
  control-vectors/lora-out/p7-idioms-real/adapter/`, `data/control-
  vectors/lora/p7-idioms-real-lora.OFSQC4I-QDBKEXY.gguf`.

**verdict**: second honest negative on `invoke` specifically, real data
this time -- confirms the 2026-09-10 verdict's premise (synthetic data
was the missing ingredient) was at best incomplete. real in-distribution
data moved `truefalse` some and moved nothing else. **not a reason to
abandon load-time adapters as a mechanism** -- see the next-steps
discussion this addendum's own follow-on conversation raised: the current
recipe never targets `lm_head`/`embed_tokens`, so if `invoke`'s bracket-
arrow token sequence has a near-zero base-model output-layer prior, no
amount of attention/MLP adaptation could move it regardless of dataset
quality -- a different, still-untried lever, not evidence the mechanism
itself is exhausted.

## third attempt [ lm_head + embed_tokens targeting, 2026-09-12 -- SIXTH
## HONEST NEGATIVE on `invoke` ]

direct follow-on from the second attempt's verdict: the recipe so far only
ever adapted attention/mlp/ssm projections, never the final hidden-state
-> token-logit projection (`lm_head`) or the token -> embedding lookup
(`embed_tokens`). hypothesis: if `invoke`'s bracket-arrow token sequence
has a near-zero base-model output-layer prior, no amount of attention/mlp
adaptation could move it regardless of dataset quality -- this attempt
tests that directly by adapting the output layer itself.

- training : same rank 16 / alpha 32 / dropout 0.05, same mined dataset as
  the second attempt, target_modules extended with `lm_head` and
  `embed_tokens` (`tie_word_embeddings` confirmed FALSE on this checkpoint,
  so these are two independent, separately-adaptable weight matrices, no
  tied-weight complication). 114 steps, final loss 1.29. clean run, no
  permission error -- the `-w $out_dir`/self-stopping-server fixes from
  this session held.

- **found before conversion, worth knowing generally**: the saved
  `adapter_model.safetensors` was 8.3GB, not the expected ~170MB. PEFT
  saves a full fp32 copy of each target module's frozen BASE weight
  (`*.base_layer.weight`) alongside the LoRA delta whenever that module
  was NOT loaded in 4-bit -- `lm_head`/`embed_tokens` are the only two
  unquantized target modules here (bitsandbytes doesn't quantize the
  vocab-sized input/output layers by default), so their ~4GB-each base
  copies got written into the checkpoint for no reason (ik_llama.cpp
  already has the real weights from the production GGUF). `lora_to_gguf.py`
  now skips any `.base_layer.` tensor.

- **found before conversion, changes the scope of this lever**: read
  this fork's `llama-build-context.cpp` directly (same discipline as the
  flash-attn discovery) -- `build_output()` routes the lm_head/output
  projection through `llm_build_lora_mm` (the lora-aware matmul, same path
  every attention/mlp/ssm projection already uses), but
  `llm_build_inp_embd()` reads the token embedding table via a bare
  `ggml_get_rows(tok_embd, ...)`, never touching `llm_build_lora_mm`
  anywhere. an `embed_tokens` LoRA would load without error and then
  silently never apply -- same failure shape as the flash-attn bug this
  task already found once, caught this time before spending a validation
  cycle on it. `lora_to_gguf.py`'s `TOP_LEVEL_HF_TO_GGUF` map deliberately
  excludes `embed_tokens`; only `lm_head` (`output.weight` in GGUF) was
  actually converted and tested.

- conversion : extended `lora_to_gguf.py` for top-level (non-per-layer)
  target modules -- confirmed via a direct GGUF read: `general.
  architecture=qwen35`, `adapter.type=lora`, `adapter.lora.alpha=32.0`,
  249 lora pairs (498 tensors, one more pair than the second attempt's
  248 -- exactly the added `output.weight` pair), `output.weight.lora_a`
  shape `[4096,16]` / `lora_b` shape `[16,248320]` matching the expected
  ggml `ne=[in,r]`/`ne=[r,out]` convention.

- differential test : scale=0 vs scale=1, same seed/prompt, `max_tokens=
  600` this time (learned from the second attempt's own methodology note
  -- diff the right field, and use enough tokens to actually reach
  `content`, not just `reasoning_content`). both `content` (1668 vs 813
  chars) and `reasoning_content` differ substantially -- adapter
  genuinely applied, not a repeat of the flash-attn no-op.

- validation : same discipline, fresh baseline, `run_gens.sh` +
  `run_gens_lora.sh`, 3 seeds each. baseline numbers are IDENTICAL to the
  second attempt's baseline (same model, same seeds, deterministic decode
  -- a clean cross-run consistency check, not a new run needed each time
  in principle, though still generated fresh per this task's own
  discipline):

```
                 chars   idiom(raw)  idiom/1k   anti(raw)  anti/1k
baseline         22847   21          0.92       50         2.19
lora-on-lmhead   23953   36          1.50       42         1.75
```

  structural-only subcategory: baseline 4 (0.18/1k) -> lora-on 18
  (0.75/1k). confounds checked clean -- chars are within 5% of baseline
  (23953 vs 22847), and `finish_reason=stop` is IDENTICAL between
  conditions (8/18 both), so neither the second attempt's length-collapse
  confound nor its early-EOS confound apply here.
  - **`invoke`: 0 -> 0.** the sixth independent null on this specific
    idiom, and the first one that directly adapted the exact layer
    (`lm_head`) that projects hidden state to token logits -- the
    "near-zero output-layer prior" hypothesis this attempt was built to
    test came back negative too. adapting the projection that assigns
    `invoke`'s literal token probability still produced zero occurrences
    across 18 novel-prompt generations.
  - `cfgaccess`: 0 -> 0. flat, still no second occurrence anywhere across
    three attempts now.
  - `truefalse`: 4 -> 18, the largest movement yet (vs. 4->12 in the
    second attempt), still concentrated in `P_D` responses, still carries
    the same prompt-echo caveat.
  - `modedata`: 0 -> 0. flat.
  - anti-idiom density actually FELL this time (2.19 -> 1.75/1k), the
    opposite direction from both prior attempts -- worth noting, not
    over-interpreting at n=1 condition.

- restore state : `coding.cfg.lora_adapter`/`_scale` cleared (in-memory
  only, same as the second attempt), live gpu server respawned with no
  lora flags / flash-attn back on, verified via process args. adapter/
  gguf left in place: `data/control-vectors/lora-out/p7-idioms-real-
  lmhead/adapter/`, `data/control-vectors/lora/p7-idioms-real-lmhead-
  lora.OFSQC4I-QDBKEXY.gguf`.

**verdict**: third honest negative on `invoke`, and the most targeted one
yet -- directly adapting the output projection still didn't move it. this
narrows the remaining hypothesis space meaningfully: it is not simply
"the output layer never learned this token sequence in isolation" (that
lever existed this time and still failed), which argues the bottleneck is
more likely upstream -- the hidden-state representation feeding into
`lm_head` may never come to represent "emit invoke syntax now" at all,
regardless of which weight matrices get adapted, OR the training signal
for this one specific low-frequency multi-token sequence (however it's
represented) is still too weak relative to the model's overwhelming
prior toward conventional call syntax. **still not a reason to abandon
load-time adapters as a mechanism** -- untried levers remain (higher rank
specifically on `lm_head`, oversampling `invoke` examples much more
heavily, or a complementary retrieval/few-shot injection of real corpus
examples at generation time rather than asking any adapter to memorize
the pattern into weights) -- but three attempts spanning dataset quality,
target-module scope, and now the output layer itself, all landing at
exactly zero, is a strong enough pattern that the NEXT attempt should
change what's being learned (or add retrieval instead of more training),
not just tune hyperparameters within the same recipe again.

## fourth attempt [ 3x invoke oversampling, 2026-09-13 -- SEVENTH HONEST
## NEGATIVE on `invoke` ]

follow-on from the third attempt's own conclusion: three attempts had
varied WHAT was adapted (synthetic vs. real-mined data, then the output
layer itself) but never simply increased how much `invoke`-specific
signal the model sees per training step. This attempt isolates that one
variable.

- dataset : identified the 97 lines in `mined.curated.sft.txt` whose
  target content already matches the invoke regex (`<\[[\w.]+\]>->\(`)
  directly -- not the jsonl's `category` tag (a looser, dominant-category
  classification used for corpus curation; 53 rows tagged `invoke` there,
  but 97 lines actually CONTAIN the pattern once co-occurrence with other
  tagged categories is counted). tripled those 97 lines' representation
  (205 other lines kept once + 97 invoke lines x3 = 496 total), pushing
  invoke's share of training examples from ~32% to ~59%. 2 epochs (not 3)
  to keep step count (~124) comparable to attempts 2/3 despite the larger
  corpus.
- target_modules : reverted to the second attempt's set (attn/mlp/ssm
  only, dropped `lm_head`/`embed_tokens`) -- isolates oversampling as the
  ONLY variable changing from attempt 2, rather than stacking it on top
  of the third attempt's already-tested (and also null) lever.
- training : rank 16 / alpha 32 / dropout 0.05, 124 steps, final loss
  0.62. ran ~2x slower per step than attempts 2/3 (~3.5-4min/step vs
  ~2min/step) -- GPU pegged at 100%, VRAM near capacity (12046/12288MB),
  no external contention found; best guess is the tripled invoke examples
  average longer than the rest of the corpus, not confirmed further.
  clean run, no permission error, correct adapter size (173MB, matching
  attempt 2's target-module footprint, not attempt 3's 8GB lm_head bloat).
- conversion : `lora_to_gguf.py` ran clean, 0 skipped tensors (no
  base_layer/embedding entries this time since lm_head/embed_tokens
  weren't targeted) -- 248 pairs / 496 tensors, same shape as attempt 2.
- differential test : scale=0 vs scale=1, real `content` diverges (1321
  vs 1391 chars, different finish_reason) -- adapter genuinely applied.
- **validation methodology failure, caught and fixed before trusting any
  result**: the first validation attempt's self-test wait hit a fixed
  450s cap and "proceeded anyway" right as the coding zenka's own
  seed-retry respawn was mid-flight -- 16 of 18 lora-on generation
  requests landed on a dead server (`http=000`, sub-20ms connection
  failures) and only 2 real responses exist from that pass. **this is not
  a result, it never validated anything** -- caught by inspecting the raw
  `run_gens.sh`/`run_gens_lora.sh` http-code output, not just the
  aggregate scores, which would have silently looked like "no idiom
  categories moved" from too little real data rather than "the harness
  itself broke". redone with a health-CONFIRMED wait (polls actual
  `/health` status until genuinely idle, no fixed timeout that gives up
  and proceeds regardless) -- full valid 18/18 dataset the second time.
- validation (redone, valid) : fresh baseline, `run_gens.sh` +
  `run_gens_lora.sh`, 3 seeds each:

```
                     chars   idiom(raw)  idiom/1k   anti(raw)  anti/1k
baseline             22847   21          0.92       50         2.19
lora-on-oversampled  18449   24          1.30       63         3.42
```

  structural-only subcategory: baseline 4 (0.18/1k) -> lora-on 14
  (0.76/1k).
  - **`invoke`: 0 -> 0.** the seventh independent null on this idiom.
    tripling its training-data share (to ~59% of the corpus) did not
    move it either -- this rules out "not enough exposure" as cleanly as
    the third attempt ruled out "the output layer never learned it":
    both specific, targeted fixes for two different plausible mechanisms
    came back negative.
  - `cfgaccess`/`modedata`: 0 -> 0, flat across all four LoRA attempts
    now, no exception ever recorded.
  - `truefalse`: 4 -> 14, in the same range as attempts 2/3 (12, 18) --
    the recipe reliably moves this idiom regardless of which specific
    variable changes; `invoke` never budges under any of them.
  - responses are ~19% shorter overall (18449 vs 22847 chars) while
    completing MORE naturally (`finish_reason=stop` 15/18 vs baseline's
    8/18) -- a real conciseness shift, not a truncation confound (fewer
    responses are being cut off, not more), but it doesn't rescue
    `invoke`. anti-idiom density rose again (2.19 -> 3.42/1k).
- restore state : confirmed via process args, no lora flags / flash-attn
  back on.

**verdict**: fourth honest negative in this thread's LoRA-specific
sub-series (seventh overall counting the pre-LoRA system-prompt and
control-vector attempts). Four attempts have now independently varied
dataset source, target-module scope, and data density -- all landing at
exactly zero on `invoke`, while every attempt reliably moves `truefalse`.
This is a strong, consistent pattern: whatever `invoke` needs, it is not
more data, not more repetition, and not adapting the output layer itself
via the recipe used so far. The remaining untried levers (much higher
rank specifically on `lm_head`, or abandoning weight-training for this
one idiom in favor of retrieval/few-shot injection of real corpus
examples at generation time) are a bigger step than another parameter
tweak -- worth deciding deliberately rather than running a fifth
same-shape attempt.

## fifth diagnostic pass [ token-level logprob probe, 2026-09-14 -- REFRAMES
## the four "honest negative" verdicts above: probable cause found, not yet
## confirmed as the sole cause. addendum, not a retraction of the numbers
## above -- those measurements of deployed behavior are still correct ]

before spending a fifth attempt on more data/rank/target-module tuning
(the "remaining untried levers" note directly above), built a cheap,
training-free diagnostic per an explicit ask: does the trained adapter's
actual token-level probability on the `invoke` idiom move AT ALL, measured
directly rather than inferred from 0/18 generation counts? scripts:
`data/control-vectors/lora_invoke_probe.py` (in-corpus + generalization) and
the same file's sibling `lora_invoke_generalization_probe.py`. no training
was run in this pass -- forward passes and live-server queries only.

**tokenization check**: `<[module.name]>->(` splits into 6 tokens under
this tokenizer -- `<[`, `module`, `.name`, `]>`, `->`, `(` -- and neither
bracket token is a byte-fallback/rare token (both are ordinary learned
vocab entries). the idiom is not fighting a character-level tokenization
handicap.

**test 1, in-corpus teacher-forced logprob** (HF + PEFT, bnb-4bit, the
exact base checkpoint training used, `petruhonk/Qwen3.8-9B-Distill-
uncensored-heretic`): 6 real curated-corpus examples containing an invoke
call in the target span, teacher-forced with the exact training-time
context assembly (`prefix + "<think>\n" + "\n</think>\n\n"`). baseline
mean-avg-logprob/token = -9.34, top1_rate = 14.5%. **attempt2-real adapter:
-0.84, top1_rate = 84.1%. attempt4-invoke-oversampled adapter: -0.44,
top1_rate = 89.9%.** (attempt3-lmhead's `adapter_model.safetensors` is
missing from disk -- only its GGUF conversion survives -- so it was
skipped in this pass, not tested.) this is a dramatic, unambiguous
confidence boost on the exact idiom tokens, directly contradicting
"training never moved this at all."

**test 2, generalization to never-seen-verbatim idioms** (rules out
memorization of the 6 example lines above): mined 9094 real invoke call
sites from current `src/*` whose exact idiom string (module name +
`->(` ) appears nowhere in the training corpus, picked 6 with distinct
module names, wrapped in the identical training-style instruction
scaffold (reusing the two real training prefixes verbatim, only the
held-out content differs). baseline mean-avg-logprob/token = -8.19,
top1_rate = 13.1%. **attempt2-real: -0.48, top1_rate = 88.1%. attempt4:
-0.40, top1_rate = 91.7%.** same dramatic boost on genuinely novel module
names never seen in training -- this is real generalization of the
syntactic pattern, not memorization.

**conclusion from tests 1+2, safe to treat as established**: the LoRA
training mechanism itself works. Gradient descent on this rank/target-
module recipe against this real corpus does teach the model to strongly
prefer the invoke idiom's tokens, in a way that transfers to unseen
module names -- measured directly in HF/PEFT space. The four "honest
negative" verdicts above are NOT evidence that the technique failed to
learn anything.

**test 3, the live deployed path** (real generation test, not inferred):
switched the live coding-zenka GPU server (`coding.switch-model
OFSQC4I:QDBKEXY backend=gpu`, `<coding.cfg.lora_adapter>` pointed at
attempt4's GGUF) to reproduce the exact training-style edit prompt
("Update this Perl fragment to match how the rest of protocol-7 writes
this kind of code.\n\nreturn 'error: cannot write file';") via the raw
`/completion` endpoint with the identical immediate-think-close context
used in tests 1/2. **3 seeds, 0/3 invoke.** Queried the live server's own
`n_probs` top-15 next-token distribution at that exact position: top1 =
`return` at 53%, `<` does not appear anywhere in the top 15. **Scale
sensitivity, the key discriminator**: raised `coding.cfg.lora_adapter_
scale` from 1.0 to 5.0 and re-queried -- `return`'s probability
*increased* to 83%, `<` still absent from top-15. An underscaled-but-
correctly-signed delta would move TOWARD the trained direction as scale
increases; this moved further away. Built a dense-only variant of
attempt4's already-trained adapter (filtered to just the 7 standard
attn/mlp projections, no SSM/lm_head tensors, no retraining -- see the
inline script run this session, not yet saved as a standalone tool) to
rule out the custom SSM tensor mapping specifically: **identical
symptom** (`return` 48%, `<` absent from top-15). The live deployment
path does not reproduce what tests 1+2 show happening in HF/PEFT space,
and this is NOT explained by scale or by the SSM-specific tensor mapping.

**the actual suspect, found via one more check, NOT yet fully closed
out**: compared the TRUE BASELINE (no adapter at all) distribution
between HF and the live server, at the identical position, to check
whether the two are even measuring the same base model. Live server
(GGUF, `mradermacher/Qwen3.8-9B-heretic-uncensored-i1-GGUF` Q4_K_M, a
quant of **rohit267**'s fine-tune per this file's own base-checkpoint-
blocker section above): top1 = `` ``` `` at 50.8%, clean, low-entropy,
English-only top-15. HF baseline (`petruhonk/Qwen3.8-9B-Distill-
uncensored-heretic`, the checkpoint ALL FOUR training attempts used):
top1 = also `` ``` `` but at only 11.7%, with a much flatter, higher-
entropy distribution that includes garbage entries (`根据`, `按照`, a raw
`�` byte) in the top-15. **These two baseline distributions look
meaningfully different**, which is consistent with -- though not yet
airtight proof of -- the base-checkpoint blocker's original, pre-
registered hazard: petruhonk was fetched as a stand-in for the 404'd
rohit267 original specifically because it "sidesteps" the missing-
checkpoint problem, but its identity as literally the SAME fine-tune the
production GGUF quantizes was never independently verified. If it is
in fact a different fine-tune (or a substantially different training
run of a similarly-named one), every LoRA trained so far was trained
against the wrong base weights relative to what actually gets served --
which would fully explain a huge, generalizing, real effect in HF space
and zero transfer to the live GGUF server, independent of any conversion
bug in `lora_to_gguf.py`.

**next step, not yet done**: this baseline-divergence check used one
example at one position -- suggestive, not conclusive. Before scoping a
fifth training attempt, confirm or rule out the checkpoint-identity
mismatch directly: either (a) obtain/confirm a safetensors checkpoint
verified to be the exact fine-tune `mradermacher`'s GGUF quantizes (may
require quantizing petruhonk to GGUF independently and diffing against
the production quant's tensors, or finding rohit267's weights via another
mirror), or (b) run several more baseline-vs-baseline distribution
comparisons across varied prompts to see if the divergence is systematic
or was an unlucky single sample. **If the mismatch is confirmed real**:
attempt 5 is "retrain (or re-serve) against a checkpoint verified
identical to production," not "debug the GGUF conversion path" -- a
materially different, much cheaper fix than anything scoped in the
"remaining untried levers" note above. **If baselines turn out to agree
on a larger sample**: the live-deployment discrepancy is a genuine
ik_llama.cpp/GGUF LoRA-application finding affecting even standard
attn/mlp projections on this architecture, and IS worth escalating as a
fork-level bug report.

**operational note**: this pass required stopping/restarting the live
GPU inference server five times (standing permission, see `data/ai-mem/
claude/feedback-coding-zenka-gpu-interrupt-standing-permission.md`) and
included one real mistake -- calling `coding.spawn_inference_server`
directly with a bare `{backend=>"gpu"}` hash instead of going through
`coding.switch-model`, which skipped model-path resolution and crashed
against a placeholder path. The `task_buffer_drop: dropped 9 buffers`
log line seen right after was initially misread as fallout from that
crash; it's actually `coding.handler.task_buffer_drop`, a routine timer
that only ever frees buffers for tasks `coding.handler.task_buffer_save`
already persisted earlier -- unrelated to the crash, no data lost. Fixed
by always using `coding.switch-model OFSQC4I:QDBKEXY backend=gpu` for
every subsequent respawn in this pass, which correctly resolves the path
from the model registry. Server restored to its normal unmodified
startup (no lora flags) and `<coding.lora_training_in_progress>` cleared
at the end of this pass. **worth noting as a positive**: only the child
inference-server process crashed -- the coding zenka itself never went
down, and `coding.switch-model` kept working flawlessly for every
respawn afterward (including the deliberate scale-sweep and dense-only-
adapter respawns), no zenka restart ever needed across the whole pass.

## sixth pass [ qwen35 GGUF self-conversion + three-way numerical
## verification, 2026-09-15 -- ROOT CAUSE FOUND, and it is NOT the base-
## checkpoint mismatch the fifth pass named as its prime suspect: the
## local petruhonk checkout had a CORRUPT shard 4 [ layers 25[attn-out
## side]..31 + final norm unread-but-wrong ] sitting on disk since the 2026-09-10
## fetch, BEFORE any training ran. production's base weights were right
## all along; the four trained adapters are the poisoned artifacts.
## this is a RETRACTION of the fifth pass's stated suspect [ its
## measured symptoms were and remain correct observations ]. not an
## invoke attempt -- no invoke numbers in this pass ]

task `data/tasks/coding-lora-p7-idioms-checkpoint-quantize.md` scoped:
self-quantize the petruhonk checkpoint into a working qwen35 GGUF [ the
fork's gguf-py has no qwen35 registration, so the vendored converter
refuses it ], serve it, re-validate the existing adapters -- on the
theory [ fifth pass's prime suspect ] that petruhonk is a different
fine-tune than the rohit267 weights production serves. the conversion
+ verification work ran; the serve-and-revalidate step was then taken
over by the task author directly [ see crash note below ]. what the
numerical work found changed the entire diagnosis.

**the converter [ works, verified exact ]**: `data/control-vectors/
lora/qwen35_hf_to_gguf.py` -- streaming, memory-bounded full-model HF->
GGUF writer for this architecture. every transform was established
NUMERICALLY against ge525's pre-existing Q4_K_M of the same checkpoint
and against the fork's graph source, not guessed: zero-centered
RMSNorms stored as (1+w) F32 [ ssm_norm stays raw -- it is ones-
centered ], ssm_a = -exp(A_log), a v-head permutation [0,2,..,30,
1,3,..,31] applied to every 32-v-head-indexed dimension [ ssm_a,
ssm_dt, in_proj_a/b rows, in_proj_z rows, v-rows of in_proj_qkv,
conv1d v-channels, out_proj columns ], full-attn q_proj copied directly
[ HF already stores the output gate per-head-interleaved exactly as the
fork's gated view expects ], conv1d squeezed [8192,1,4]->[8192,4],
vision tower and MTP tensors skipped [ loader treats both as absent /
optional ]. tokenizer KV copied verbatim from the production GGUF
after all 33 added/special tokens checked id+content-identical to
petruhonk's tokenizer.json. verification (a): the written F16 GGUF
matches its HF source EXACTLY on all 427 tensors [ f32 bit-exact, f16
lossless-from-bf16 ] -- see `data/control-vectors/lora/
verify_qwen35_gguf.py`, which is strictly read-only and memory-bounded.

**host crash during this task [ postmortem by the task author ]**: the
host OOM-crashed overnight [ whole VM, not just the zenka; rebooted
since ]. root cause per the task author: the quantize task's own
acceptance criterion #1 asked for the 18.4GB F16 file to be served and
self-tested ON THIS 15GB-RAM HOST -- a criterion now withdrawn as the
author's mistake. DO NOT ever serve the F16 here; it exists only as an
llama-quantize input [ quantize streams file-to-file ]. related hazard,
recorded for honesty: the first version of the verification script
used float64 full-tensor cosine on the two 248320x4096 tensors [ ~16GB
transient ]; the repo version was rewritten strictly bounded [ chunked,
float32, no full dequant of the giants ] before any further run.

**the verification surprise that inverted the diagnosis**: cross-
checking the fresh F16 against ge525's GGUF showed layers 0..25
matching exactly, then TOTAL disagreement from blk.25.ssm_out onward
[ 2D row-cosine 0.00, F32 norms off by ~1 ]. initially read as a
defect in ge525's file. hash checks flipped it: ge525's local file
sha256 == its published HF LFS hash [ intact ]. the local petruhonk
shards 1-3 + mtp-extra == their published hashes [ intact ]. the local
shard 4 sha256 = fac711b4... vs published d5e4084c... -- MISMATCH, same
byte size, byte-identical safetensors header [ 49160 bytes, 421
entries ], wrong data section. petruhonk's repo has exactly one
revision [ all uploads 2026-08-20, HF commit API ], so the published
shard 4 never changed: **the local shard 4 was corrupted at fetch time
2026-09-10 [ mtime sits inside that fetch window ] -- right size, right
header, wrong data, the classic shape of a chunked-download stitching
or bad-resume bug in whatever fetched it [ fetch.file.huggingface.*
suspect; not yet root-caused, needs a bug hunt before the next big
download ]**.

**the re-fetch and the full inversion**: re-downloaded shard 4 from HF
[ sha256 == published d5e4084c..., verified ], quarantined the corrupt
file as `model-00004-of-00004.safetensors.CORRUPT-20260910-do-not-use`,
installed the intact one. the intact shard's tensors match ge525 AND
the production mradermacher GGUF EXACTLY on every F32 anchor tested
across all layer quartiles [ max|diff| 0.000000 ] and at quant-error
cosine on 2D [ 0.9948+ ]. since ge525 converted petruhonk's published
checkpoint and reproduces production's rohit267-derived weights bit-
for-bit on those anchors, **petruhonk's published language-model
weights ARE rohit267's fine-tune** [ the fifth pass's "different
lineage" read of the VLM packaging/tags was wrong -- the LM weights
are the same ]. production was NEVER serving a different base than
what petruhonk's repo contains.

**what actually happened to the four attempts, then**: the corrupt
local shard 4 [ layers 25-attn-out..31 + final norm garbage ] was on
disk BEFORE attempt 1 and was loaded by `train_lora.py` for ALL FOUR
training runs AND by the fifth pass's HF/PEFT probes. the adapters'
layer 25[attn-out side]..31 deltas [ and everything downstream of them, including the
final-norm/logit path ] were fit against garbage weights. the fifth
pass's measured effect -- huge, generalizing invoke-idiom confidence
boost in HF space -- was real INSIDE that franken-model [ probe and
training shared the same corrupt base, so they agreed with each other
]; the zero transfer to the intact production server, the scale-
entrenchment of wrong answers, the divergent no-adapter baselines, and
even petruhonk's noisy/garbage raw-baseline top-k entries [ 根据, 按照,
raw replacement byte ] all follow from the corruption alone. **the
four adapters are poisoned artifacts.**

**consequences, stated plainly**:
- ge525's Q4_K_M == production weights [ plain quant vs mradermacher's
  imatrix quant of the same source ]. serving ge525 is equivalent to
  serving current production for base-identity purposes -- it CANNOT
  fix anything by itself.
- re-validating the EXISTING adapters against ge525 [ the task
  author's current plan, run separately ] most likely reproduces an
  honest negative -- but pre-registering the interpretation: a zero
  there is a measurement of POISONED adapters against correct weights,
  NOT a fifth negative on the LoRA technique itself, and NOT evidence
  the base is still wrong.
- the real attempt 5 is a RETRAIN against the now-intact local
  checkpoint [ intact shard 4 in place since 2026-09-15 ] -- nothing
  trained before that date can be trusted, and no serve-side change
  substitutes for it.
- cheap optional probe first: re-run the fifth pass's HF logprob
  probes against the intact checkpoint with the existing adapters to
  see how much of the measured boost was early-layer real vs franken
  artifact [ layers 0..25 were intact during training ].
- the franken-tail F16 GGUF was renamed `...-f16.FRANKEN-TAIL-do-not-
  use.gguf`; a fresh F16 was rebuilt from the intact checkpoint [ same
  streaming converter, re-verified exact ] as the quantize-only
  intermediate. the converter itself needed no changes -- it was
  correct; its INPUT was corrupt.

**serve + re-validate, run separately by the task author, same day**:
against ge525's GGUF, at a properly position-matched prompt [ teacher-
forced prefix cut exactly at the token before the invoke idiom, cross-
checked with a raw token-ID prompt to rule out any string-retokenization
artifact -- two earlier attempts at this comparison were themselves
methodologically flawed and corrected before this one, see the
transcript if the detail matters ]: **`invoke` did not transfer.**
HF/PEFT gives `' <'` 60.4% top1 on the poisoned attempt4 adapter at this
position; the live ge525-served model gives `' my'` ~59-60% top1 both
WITH and WITHOUT the adapter loaded -- i.e. no measurable adapter effect
at all once the base is correct. Exactly the pre-registered outcome
above: a measurement of the poisoned adapter, not a new negative on the
technique. Also directly confirmed, reading the actual loader validation
in `src/llama.cpp:7828-7841` (`model_tensor->ne[0]==w.a->ne[0]`,
`model_tensor->ne[1]==w.b->ne[1]`, `w.a->ne[1]==w.b->ne[0]`), that the
LoRA tensor shapes and orientation in the existing GGUF conversion are
correct -- rules out a conversion-side bug as an alternative explanation
for the zero-transfer result.

**a dead end worth recording so it isn't repeated**: before the shard
corruption was found, a naive `Qwen3_5ForCausalLM` + meta-device
state-dict key-set comparison appeared to show 426/427 tensors failing
to load entirely (a different, more severe "wrong model class" theory,
briefly believed). This was wrong -- `output_loading_info=True` on the
real `from_pretrained()` call shows zero missing/unexpected/mismatched
keys, because transformers' internal checkpoint-conversion mapping
correctly strips the checkpoint's `language_model.` prefix; the naive
meta-device comparison doesn't go through that mapping and gives a
false positive. Trust `output_loading_info` over a raw key-set diff for
this kind of check.

**file cleanup, same day**: deleted the four now-confirmed-poisoned
adapter directories and their three GGUF conversions, plus the two
franken-tail F16 GGUFs superseded by the fresh rebuild. Kept: the fresh
F16 rebuild, ge525's Q4_K_M, the pre-existing unrelated Q8_0 quant, and
the quarantined corrupt shard 4 (kept deliberately as evidence for the
still-open fetch.file.huggingface.* corruption-bug hunt).

## scope

1. **dataset**: expand the P7-idiom instruction set. **decided
   2026-09-10** (recording per hazard 4's discipline, not tuned against
   eval):
   - ~350-400 total examples, SFT-shaped (instruction -> correct P7
     answer) like the existing `positive.txt` 46 -- no negative/
     contrastive side needed, that was specific to the mean-diff method,
     not to gradient SFT.
   - weighted toward the four **structural** categories that sat at
     floor in every prior condition: `invoke` (~120 examples),
     `cfgaccess` (~100), `truefalse` (~100), `modedata` (~90) -- counts
     overlap (most real P7 snippets naturally combine 2+ idioms, same as
     the existing 46), not additive to 410 distinct examples.
   - include ~60-80 examples that legitimately do NOT need a structural
     idiom (pure prose explanation, a case with no config read, no reply
     hash) so the adapter learns contextual use, not blind injection of
     `TRUE`/`FALSE`/`mode`/`data` into every response regardless of fit.
   - exclude `P_A`/`P_B`/`P_C` (`run_gens.sh`) verbatim, including close
     paraphrases. add a SECOND held-out set, `P_D`/`P_E`/`P_F`, same
     surface shapes as `P_A`/`P_B`/`P_C` (a config-default-plus-log
     prompt, a `p7c` command-display prompt, an explain-in-prose
     prompt) -- written once, never touched by the dataset-generation
     step, used only at validation time.
   - **`<think>` span: use an empty/minimal `reasoning_content` per
     example** (real chain-of-thought would be synthetic and risks
     teaching more surface-register drift) -- but see hazard 0, this
     requires masking the loss to the post-`</think>` span, not a reason
     to skip the `<think>` wrapper itself (the runtime always renders
     one for the target turn regardless of its content).

2. **environment**: install a training stack (torch + transformers +
   peft, bitsandbytes or equivalent for 4-bit QLoRA given the VRAM
   constraint) and confirm it runs against this host's CUDA/driver
   before writing training code around it.

3. **base checkpoint**: fetch the original HF safetensors checkpoint
   for the exact "Qwen3.8 9B Heretic Uncensored" fine-tune this GGUF was
   quantized from, via `fetch.file.huggingface.*` -- not a generic Qwen3
   base.

4. **training**: run LoRA fine-tuning (rank/target-modules decided and
   recorded up front, per hazard 4) against the expanded dataset.

5. **conversion**: convert the resulting PEFT adapter to GGUF via `ik_
   llama.cpp/convert_lora_to_gguf.py`; confirm its actual invocation and
   output against this specific adapter rather than assuming from
   docs/tutorials.

6. **wiring**: config-gated `coding.cfg.lora_adapter` / `_scale` in
   `cfg/zenki/coding/zenka.v7`, mirroring the control vector's pattern in
   `src/coding.spawn_inference_server` -- commented out by default,
   backend-agnostic, loud failure on a configured-but-missing file.

7. **validation**: same 4-condition discipline as the control vector
   task (baseline / adapter-on / a scale sweep if the format supports
   one) against `score.py`, reported length-normalized, with the
   structural-idiom subcategory (invoke/cfgaccess/truefalse/modedata)
   broken out explicitly as the number that actually answers whether
   this worked -- that is the number the control vector and the prompt
   fix both failed to move, and the number this whole task exists to
   move.

8. **restore state**: after validation, confirm the live zenka's GPU
   inference server is back to its normal unmodified startup (no lora
   flags) and VRAM is free again, same as the control vector task's
   restore-state step.

#,,.,,.,,,,..,.,,,..,,,,,,,..,,,,,,..,...,,,.,..,,...,..,,.,.,,,,,,,,,,,.,,..,
#Q3EB5CZ6PU5JULTMIT2YKCVJTV6L4B6ZXN75JKMGMCEYKBIMBTJY7JKRKEYQ2UVYCUKMO5RILPJTU
#\\\|4NWY3NC4LO6LJHPVRPBBHEXRYQXMMWNDGBIZF3OCRKANGVHBCVJ \ / AMOS7 \ YOURUM ::
#\[7]CJSVXZAMBZSULYCC75ZKPKQHEE4BWHEHQ3HWELVHHCR4A3335CAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
