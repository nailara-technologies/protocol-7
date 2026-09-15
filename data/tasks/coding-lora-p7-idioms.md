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

**a second calling-convention trap, found kicking off attempt 5, same
shape as the fifth pass's `spawn_inference_server` bare-hash mistake**:
`coding.lora_train_spawn` (like every `.cmd.`-style module in this
codebase) does `my $call = shift; my $args = $call->{'args'} // {};` --
calling it as `<[coding.lora_train_spawn]>->({dataset=>..., out_dir=>...,
epochs=>...})` (a bare hash of the actual params) silently resolves
`$args` to `{}` and every param falls through to its default, including
`out_dir` defaulting to the stale, permission-blocked `lora-out/
p7-idioms` from attempt 1 -- with NO error about the missing `args`
wrapper, just a confusing-looking "output directory not writable"
failure pointing at a directory nobody asked for. **Correct form:
`<[coding.lora_train_spawn]>->({'args' => {dataset=>..., out_dir=>...,
epochs=>...}})`.** Cost several silent retries (both by Kimi and by the
task author) before the actual bug was found by directly reading the
module's own argument-unpacking code rather than guessing from the
error text.

## seventh pass [ REAL attempt 5, 2026-09-15 -- retrain against the
## hash-verified INTACT checkpoint, the first genuinely valid test this
## thread has produced. result: invoke learning is real and strong in
## HF/PEFT space -- and STILL does not transfer to live GGUF serving.
## the checkpoint is now eliminated as an explanation entirely; the
## discrepancy localizes to the GGUF/ik_llama.cpp LoRA-application path
## itself -- the fifth pass's pre-registered branch (b) ]

**what was run**: attempt 2's exact configuration, unchanged -- real
git-mined data (`data/idioms/corpus/mined.curated.sft.txt`, 308 lines),
rank 16 / alpha 32 / dropout 0.05, the standard 248-module attn/mlp/ssm
target list, no oversampling, no lm_head targeting, 3 epochs = 114
steps. the ONE difference from attempt 2: the base checkpoint
`/mnt/ext-xfs-data/models-lmstudio/petruhonk/Qwen3.8-9B-Distill-
uncensored-heretic/` is now intact (shard 4 sha256 d5e4084c... == the
published HF LFS hash, re-verified at kickoff before spawning). loss
descended cleanly 2.61 -> 0.3678, no NaN/divergence, ~3.5h wall time
(slower per-step than the corrupt-shard runs -- reference kernels plus
host load; not concerning). adapter at `data/control-vectors/lora-out/
p7-idioms-real-attempt5/adapter/` (173MB safetensors + configs).

**kickoff infra notes, recorded so they aren't re-derived**: (a)
`coding.lora_train_spawn` -- and likely every `coding.*` module called
directly via eval-code -- expects its parameters wrapped,
`->({'args' => {dataset=>..., out_dir=>..., epochs=>...}})`; a bare
hash is accepted SILENTLY, resolves to empty args, and falls through to
the default out_dir, surfacing as a misleading "output directory not
writable" error. (b) pre-creating out_dir group-writable
(taeki:protocol-7 2775) was needed -- the spawn's own make_path error
check reads `$EVAL_ERROR` without `use English`, so a mkdir failure is
invisible to it (cosmetic, not worth a fix now). (c) after training,
`<coding.lora_training_in_progress>` was found stuck truthy (value 5,
status=complete, pid long dead), which correctly-but-surprisingly
SUPPRESSED the inference crash-restart guard when a later respawn
crashed -- check and clear that flag as part of any post-training
restore.

**conversion**: the existing, unchanged `data/control-vectors/lora/
lora_to_gguf.py` ran clean -- 248 lora pairs, rank 16, alpha 32.0, same
shape as attempts 1/2, written to `data/control-vectors/lora/
p7-idioms-real-attempt5-lora.LR7NW7A-XT57X3Y.gguf` (named for the
serving base it was validated against).

**HF/PEFT probes** (unchanged scripts, one-line ADAPTERS entry added
to each; base = the intact checkpoint, 4-bit bnb, same teacher-forced
methodology as the fifth pass):
- in-corpus (`lora_invoke_probe.py`, 8 invoke matches): baseline
  mean-avg-logprob/token -4.298, top1 50.7%. **attempt5: -0.2466,
  top1 95.7%.** large, real confidence boost on the invoke idiom.
- generalization (`lora_invoke_generalization_probe.py`, 9 never-seen-
  verbatim module names): baseline -0.0618 / top1 98.8%, attempt5
  -0.0551 / top1 97.6% -- **no measurable difference, because the
  INTACT base is already at ceiling** on these held-out real src/*
  lines (teacher-forced continuation of a line already containing the
  idiom in strong p7-code context). contrast with the fifth pass's
  "huge generalizing boost" (baseline -8.19/13.1% -> adapter ~88-92%):
  that baseline was the corrupt franken-model -- the fifth pass's
  generalization finding was largely an artifact of a broken baseline.
  honest read now: the adapter's in-corpus boost is real; the
  ceiling-limited held-out probe can neither confirm nor deny transfer
  of the pattern to novel module names.

**live validation sweep** (`run_validation_sweep.sh attempt5 <gguf>`,
`MODEL_ID=LR7NW7A:XT57X3Y` -- ge525's Q4_K_M, already durably present
in the models registry under that checksum [ display name "Raw Model"
], path verified via `models.get_path_by_amos`; no eval-code path hacks
needed. adapter confirmed genuinely loaded: `--lora-scaled ... --flash-
attn off` in process args, and the measured distributions shift):

```
                 chars   idiom(raw)  idiom/1k   anti(raw)  anti/1k
baseline         16309   7           0.43       23         1.41
lora-on          11498   14          1.22       7          0.61
```

  structural-only subcategory (invoke+cfgaccess+truefalse+modedata):
  baseline 0 (0.00/1k) -> lora-on 8 (0.70/1k). finish_reason=stop
  18/18 baseline vs 17/18 lora-on -- no truncation confound; lora-on
  responses ~30% shorter. per-idiom:
  - **`invoke`: 0 -> 0.** the EIGHTH independent null on this idiom in
    held-out generation -- now including a run where the training
    checkpoint is hash-verified intact and the serving base is verified
    bit-exact-equivalent to production weights.
  - `cfgaccess`: 0 -> 0. still no second occurrence anywhere, ever.
  - `truefalse`: 0 -> 7 (concentrated in P_D as before). the recipe
    reliably moves this idiom -- poisoned checkpoint or not.
  - `modedata`: 0 -> 1. first non-zero anywhere in the thread.
  - anti-idiom density DROPPED (1.41 -> 0.61/1k) -- the first attempt
    where it didn't rise. the correct-checkpoint adapter produces less
    generic-style drift, not more.

**the decisive position-matched teacher-forced check** (exact sixth-
pass methodology: 105-token RAW TOKEN-ID prefix -- never a string
prompt, the two retokenization mistakes are not repeated -- cut at the
token boundary right before the invoke idiom's leading ` <` [ id 361 ];
same corpus example whose first invoke call is `<[file.zenka_dir.
write]>->(`. HF half and live half both run by the task author in
parallel with this session, artifacts preserved at /tmp/attempt5_
posmatch_*; the previously-inline methodology is now committed as two
standalone tools: `data/control-vectors/lora_invoke_posmatch.py` [ HF
half ] and `data/control-vectors/lora_invoke_live_position_probe.py` [
live half ] ):

```
                         top1              ' <' probability
HF baseline (intact)     ' my' 60.06%      not in top-15 (<0.30%)
HF + attempt5 adapter    ' <' 83.18%  <--  83.18%, top1 FLIPS
live ge525 baseline      ' my' 59.10%      not in top-15 (<0.14%)
live ge525 + attempt5    ' my' 66.18%      not in top-15 (<0.14%)
live ge525 + attempt5    ' my' 64.99%      not in top-15 (<0.14%)
  @ adapter_scale=4.0
```

**interpretation, stated plainly**: the two baselines agree almost
exactly across HF and GGUF serving (' my' 60.06% vs 59.10%) -- the
base weights are right on BOTH sides, finally beyond doubt. the adapter
is genuinely applied on both sides (HF flips top1 to the trained token;
the live distribution measurably shifts AND the sweep shows real
behavioral change). and yet the DELTA's effect diverges: in HF space
the same adapter boosts ` <` to 83.18% top1; live, it slightly
ENTRENCHES ` my` (59.1% -> 66.2%) and ` <` stays below 0.14%. with
checkpoint identity (sixth pass), conversion tensor shape/orientation
(sixth pass, llama.cpp:7828-7841), flash-attn gating (first attempt),
scale (fifth pass's 1.0->5.0 sweep on the POISONED adapter, now
re-confirmed on the valid one: quadrupling the applied delta moves ' my'
66.2% -> 65.0% and ' <' stays absent -- the live-applied delta is
orthogonal to the HF delta, not underscaled), and now training-
checkpoint integrity ALL independently eliminated, the discrepancy localizes to
the GGUF LoRA-application semantics on this architecture itself -- the
fifth pass's pre-registered branch (b): a genuine ik_llama.cpp/qwen35
finding, worth escalating as a fork-level bug report rather than
another training-recipe change. candidate mechanisms to check first,
in rough order of cost: (1) whether the runtime actually applies
user_scale*alpha/rank inside llm_build_lora_mm for the SSM projections
[ a --verbose-level assertion, cheap ]; (2) application-order /
precision differences for lora deltas on the gated-delta SSM tensors
[ attn_qkv / attn_gate / ssm_alpha / ssm_beta / ssm_out ] vs the dense
projections -- possibly via a dense-only adapter variant like the fifth
pass built inline; (3) whether all 248 pairs are actually wired into
the built graph, or a subset silently attaches to unused tensors.

**restore state**: production model respawned via `coding.switch-model
OFSQC4I:QDBKEXY backend=gpu`, confirmed healthy by open-ended poll,
process args verified -- no lora flags, flash-attn back on, VRAM free.
`<coding.cfg.lora_adapter>` cleared, stale training flag cleared.

**verdict**: the invoke idiom CAN be taught by this recipe -- attempt 5
proves it in weight space, against a verified-correct base, with a
measured 83% top1 at the exact decision position. it STILL never
survives the trip to live GGUF serving (0 -> 0 in generation, eighth
null; no top-15 presence at the matched position). the thread's
question is no longer "does the training work" but "why does
ik_llama.cpp's LoRA application on qwen35 not reproduce in deployment
what PEFT demonstrably computes" -- a serving-side bug hunt, not a
training-side one.

## eighth pass [ live-only, no retrain -- isolates and closes the seventh
## pass's flash-attn confound question, then finds and characterizes a
## real, non-monotonic scale response on the live server for the first
## time in this thread. still a null on transfer, but a materially
## different kind of null than passes 1-7: the delta is now confirmed to
## genuinely reach the live computation and move the right direction, it
## just saturates around ~7% and degrades rather than converging further ]

**motivation**: reviewing the seventh pass fresh, `coding.spawn_
inference_server` only pushes `--flash-attn off` when `<coding.cfg.
lora_adapter>` is non-empty (`src/coding.spawn_inference_server:565-591`)
-- so every "baseline vs lora-on" sweep in this thread, seventh pass
included, compares FA-on/no-adapter against FA-off/adapter, two
variables at once, not one. Before trusting attempt 5's live numbers,
needed a same-condition sweep: adapter path always set (so FA is off in
every condition, including the control), varying only `--lora-scaled`.

**method**: `data/control-vectors/lora_invoke_live_position_probe.py`
(unchanged, the sixth/seventh-pass raw-token-id position-matched
methodology) run against `LR7NW7A:XT57X3Y` (ge525's Q4_K_M, == production
weights) with the attempt5 adapter loaded at five scales: 0.0 (true
control -- same code path/FA state as every other condition, zero
delta), 1.0, 4.0, 8.0, 16.0. One respawn per scale via `coding.
switch-model`, health-confirmed before firing. Orchestration script kept
at `data/control-vectors/run_lora_scale_sweep.sh` (adapted from `run_
validation_sweep.sh`'s wait/respawn discipline).

**operational notes, recorded so they aren't re-derived**: (a) the probe
needs `transformers`, which is NOT on the bare system python -- use
`.venv-lora/bin/python3`. (b) this host has `http_proxy`/`https_proxy`/
`ALL_PROXY` set in the environment; `curl` sidesteps it with `--noproxy
'*'` (already in every wait/health check in this thread's scripts), but
bare `urllib.request` in the probe does NOT -- it silently routes the
`127.0.0.1:8000` request through the proxy and gets back a live-but-
useless `HTTP 502 Bad Gateway` that looks like a server problem, not a
client one. Fix: `NO_PROXY='*' no_proxy='*'` in the probe's environment.
Cost one wasted respawn+probe cycle before catching it.

**results**:

```
scale   ' my' top1   ' <' prob   ' <' rank   notes
0.0      58.99%      <0.16%      --          control -- matches FA-ON baseline (59.10%) almost exactly
1.0      66.18%      <0.14%      --          matches seventh pass's (confounded) lora-on number exactly
4.0      85.85%       6.84%      #2          FIRST-EVER live top-15 appearance of the target token, this whole thread
8.0      61.70%       6.40%      #3          off-distribution tokens (' \\\\', ' ...') entering top-15 -- early degeneration
16.0     -- ('\n' 26.81% top1)    3.45%      #4          distribution collapsed into garbage (debian, LLL, http) -- general breakdown
```

**the flash-attn question is closed, in the direction of "not a
confound"**: scale=0.0 (58.99%) and the original FA-on baseline (59.10%)
agree to a tenth of a percent; scale=1.0 (66.18%) reproduces the
seventh pass's FA-off lora-on number exactly. FA state is not driving
the previously-observed shift. The seventh pass's "side effects were
real and positive" write-up (truefalse 0->7, modedata 0->1, anti-idiom
density drop) stands as originally written -- no retraction needed.

**the scale response is real, genuinely adapter-driven, and NOT the
simple underscaling story the seventh pass proposed**: the seventh
pass's own scale probe (1.0->5.0 on the POISONED attempt4 adapter,
' my' 66.2%->65.0%, ' <' absent throughout) was read as "orthogonal to
the HF delta, not underscaled" -- that conclusion doesn't survive
contact with the valid adapter. Here, `' <'` genuinely climbs (absent ->
absent -> 6.84% -> 6.40%) as scale rises from 0 to 8 -- a real, monotonic-
enough, correctly-DIRECTED response the poisoned-adapter probe never
showed. But it doesn't converge toward HF's 83.18% top1 the way a pure
scale deficit would predict: it peaks around 4-8x nominal scale at ~7%,
then scale 16 doesn't push `' <'` any higher (3.45%, actually lower) --
instead the ENTIRE output distribution degrades into off-distribution
noise (`debian`, `LLL`, `http`, bare newlines dominating). This is the
signature of the delta becoming a source of general numerical damage at
high scale, not of a correction converging on its target. Whatever gap
remains between the live server and HF/PEFT is not closeable by simply
turning the scale dial further.

**why this doesn't point back at (1) scale-formula or (3) SSM-routing
bugs**: both were re-checked directly against the data before running
this sweep, not just reasoned about. `gguf_dump.py` on the attempt5
adapter GGUF confirms `adapter.lora.alpha = 32.0` is present and
correctly read (ruling out the `alpha ? ... : it.second` fallback path
at `llama-build-context.cpp:983` silently dropping to a no-alpha/rank
scale). Per-tensor shapes for `blk.0`/`blk.1` show every `lora_b`
tensor's rank dimension is uniformly 16 -- dense (`attn_qkv`, `ffn_up/
gate/down`) and SSM (`ssm_alpha`, `ssm_beta`, `ssm_out`) tensors alike,
including the small `[16,32]`-shaped `ssm_alpha`/`ssm_beta` pairs --  so
`scale = user_scale * alpha/rank` computes identically (`user_scale *
2.0`) for every targeted tensor, no type-specific misread. Combined with
the seventh pass's routing confirmation (every SSM projection goes
through `llm_build_lora_mm`, no bare `ggml_mul_mat` bypass), the "silent
bug" theory across all three original candidate mechanisms is now
closed by direct inspection, not inference. What's left is some kind of
precision/numerics interaction specific to the live compute path (Q4_K_M
base quantization and/or the gated-delta-net's chunked recurrent math
diluting or partially cancelling the low-rank correction) -- real, but
not yet isolated to a single fixable line the way the flash-attn and
lm_head/embed_tokens bugs earlier in this thread were.

**restore state**: production respawned via `coding.switch-model
OFSQC4I:QDBKEXY backend=gpu`, confirmed healthy, no lora/FA flags in
process args -- verified via `ps aux` after every stage of this pass,
not just at the end.

**verdict**: `invoke` is still 0/1 at the decisive live position -- the
ninth null on generation-level transfer. But it is a qualitatively
different null than passes 1-7: this is the first time the live server
has shown ANY measurable, correctly-directed, scale-responsive movement
toward the target token. The open question narrows from "does the
adapter do anything live" (now answered: yes) to "why does its effect
cap around ~7% and degrade rather than converge, when the same delta
reaches 83% cleanly in HF/PEFT space" -- most likely a quantization- or
numerics-precision question specific to Q4_K_M + the gated-delta-net
architecture, worth an F16-vs-Q4_K_M comparison at matched scale as the
next diagnostic (NOT the 18GB F16 GGUF flagged elsewhere as unsafe to
serve on this 15GB host -- the pre-existing Q8_0 quant, much higher
precision than Q4_K_M and already confirmed to fit, is the safe next
rung to test first).

**correction, same session**: "the pre-existing Q8_0 quant" above turned
out to be ambiguous and the wrong one on first read -- the Q8_0 file this
task file elsewhere calls "unrelated" (`rohit267/Qwen3.8-9B-heretic-
uncensored/qwen3.8-9b-abliterated-Q8_0.gguf`) is a DIFFERENT decensoring
pipeline than the checkpoint the adapter was trained against, exactly
the mistake this thread already burned time ruling out once. The correct
Q8_0 -- same source repo as the hash-verified F16 rebuild and ge525's
Q4_K_M -- is `petruhonk/Qwen3.8-9B-Distill-uncensored-heretic-GGUF/
Qwen3.8-9B-Distill-Heretic-Uncensored-Q8_0.gguf` (9.1GB, safely under
the 15GB host limit), previously untouched/unverified in this thread.
See "ninth pass" immediately below for what testing against it found.

## ninth pass [ live-only, no retrain -- tests whether Q4_K_M
## quantization noise is diluting the delta, by re-running the eighth
## pass's exact 0/1/4x scale points against the correct-checkpoint Q8_0
## quant instead. result: REFUTES the quantization-dilution hypothesis
## -- higher precision made live transfer WEAKER, not stronger ]

**setup**: registered the Q8_0 file into the models registry (`p7c
"models.discover :re-scan:"`, previously undiscovered/unregistered in
this thread) -- resolved to `amos: P27KMTQ:X6B34JQ`, path-verified via
`models.get_path_by_amos`. Metadata sanity-checked before serving:
`general.architecture = qwen35`, `qwen35.block_count = 33`, `qwen35.
embedding_length = 4096`, `general.file_type = 7` (Q8_0) -- consistent
with the expected checkpoint family. Re-ran the exact same three scale
points (0.0 control, 1.0, 4.0) from the eighth pass's sweep, same
adapter (`p7-idioms-real-attempt5-lora.LR7NW7A-XT57X3Y.gguf`), same
position-matched probe, FA off throughout (adapter path always set),
via `data/control-vectors/run_lora_scale_sweep.sh` pointed at the new
`MODEL_ID`.

**results, directly comparable to the eighth pass's Q4_K_M numbers**:

```
scale   Q4_K_M ' my'   Q4_K_M ' <'   Q8_0 ' my'   Q8_0 ' <'
0.0      58.99%         <0.16%        64.60%       <0.18%
1.0      66.18%         <0.14%        76.80%       <0.24%
4.0      85.85%          6.84%        94.70%        1.76%
```

**interpretation**: if Q4_K_M's aggressive 4-bit quantization were
diluting or partially cancelling the low-rank delta, the much
higher-precision Q8_0 quant should show a STRONGER target-token response
at matched scale. It shows a WEAKER one instead -- `' <'` at scale 4.0
drops from 6.84% (Q4_K_M) to 1.76% (Q8_0), while `' my'` climbs higher
at every scale (64.6%/76.8%/94.7% vs 58.99%/66.18%/85.85%). This is a
clean, well-controlled refutation, not just a deprioritization: base
quantization precision is not the mechanism, and if anything the
correlation runs backward from the hypothesis (though n=1 quant-pair,
worth remembering before treating "backward" as itself a real trend).
One real side-effect worth recording independent of the LoRA question:
the zero-adapter baseline itself shifts measurably with quantization
(58.99% -> 64.60% `' my'` top1) -- Q4_K_M and Q8_0 are not
behaviorally identical even before any adapter is involved, which is
useful context for any future cross-quant comparison in this thread.

**what this leaves**: routing, alpha, rank/shape, and now base-weight
quantization precision are ALL ruled out by direct inspection or
controlled live test, not reasoning alone. The remaining candidate
space narrows to something in how ik_llama.cpp computes the qwen35/
gated-delta-net forward pass itself -- independent of quantization --
differently enough from HF/PEFT's computation that a correctly-shaped,
correctly-scaled, correctly-routed delta of a given magnitude produces a
much smaller effect live than in HF space, with reduced headroom before
general degeneration (scale 8/16 in the eighth pass). Confirming this
would need a base-model (NO adapter) activation-level comparison between
HF and llama.cpp at the same decision point -- do the two implementations
actually agree on hidden-state values through the SSM/gated-delta layers
before any LoRA is applied -- which is a materially bigger diagnostic
step than anything run so far in this thread (cross-implementation
numerical debugging, not a probe/sweep), not started.

**restore state**: production respawned via `coding.switch-model
OFSQC4I:QDBKEXY backend=gpu`, confirmed healthy, no lora/FA flags in
process args.

## tenth pass [ started, NOT finished -- an initial HF-vs-llama.cpp
## base-model activation comparison, the ninth pass's proposed next
## diagnostic. Inconclusive at the sample size reached; also produced a
## real infrastructure mistake worth recording before the actual result ]

**the mistake, record first so it isn't repeated**: the initial attempt
at the HF side of this comparison loaded the checkpoint as full fp32
**on CPU** (`AutoModelForCausalLM.from_pretrained(..., torch_dtype=
torch.float32, device_map="cpu")`) -- roughly 36GB for a 9B model, on a
host with 15GB total RAM. This was a real deviation from every other HF
probe in this thread (`lora_invoke_probe.py` and siblings all load
4-bit on GPU: `BitsAndBytesConfig(load_in_4bit=True, ...)`, `device_map=
{"": 0}`). The run was interrupted mid-load by a genuine host-stability
incident (a WSL shutdown loop forcing a full host restart, which also
pulled in pending Windows updates) -- per the user, likely memory
pressure, compounded by Firefox's own long-session footprint, and this
fp32-on-CPU load very plausibly tipped it over. No production data was
lost (git state was clean and pushed through the ninth pass before this
happened) and the coding zenka's own GPU server was untouched throughout
(it was already offline for an unrelated reason at the time). **Lesson,
durable**: never deviate from the established 4-bit-on-GPU loading
pattern for this checkpoint on this host -- reuse `lora_invoke_probe.py`'s
exact loading block, don't reinvent it. Filed a separate, more general
follow-up in `data/tasks/powershell-host-memory-commands.md` (Windows-
host-side memory visibility gap, unrelated to this task's own mistake
but surfaced by the same incident).

**redone correctly, real result**: `Qwen3_5ForCausalLM.from_pretrained`
with the standard nf4 4-bit config, `device_map={"": 0}`, bf16 compute
-- matches every other HF probe in this thread. Compared against
`data/source/ik_llama.cpp/build-cpu/bin/llama-eval-callback` (a stock
llama.cpp example, newly built from the existing `build-cpu` CMake
config -- unrelated `build/` dir turned out to have a stale/incomplete
Makefile, left alone rather than repaired since `build-cpu` already
worked) run CPU-only against the Q8_0 GGUF with `-c 128` (explicitly
capped context -- the default 262144 pulled in an 8GB KV cache for a
4-token prompt on the first, uncapped run; harmless in itself but
unnecessary memory pressure, avoid on this host). Prompt: "The quick
brown fox" (4 tokens, ids `[760, 3841, 13477, 37550]`, confirmed
identical tokenization both sides, confirmed no BOS prepended on either
side -- `inp_tokens{4,1,1,1}` on the GGUF side matches the HF token
count exactly). No adapter on either side. Captured: the raw token
embedding for token 760, plus position-0 hidden state after layer 0 (an
SSM/gated-delta-net layer) and after layer 3 (a dense full-attention
layer, `full_attention_interval=4` -- confirmed via the per-layer KV-size
table in eval-callback's own startup log, layers 3/7/11/... are the only
ones with a real KV allocation). Position 0 only, deliberately -- causal
masking means position 0's value is independent of later tokens on the
attention path, minimizing alignment risk between the two
implementations.

```
                          HF (first 3 dims)          GGUF (first 3 dims)
input embedding (tok 760)  0.0061  -0.0150  -0.0022    0.0062  -0.0149  -0.0021   -- near-exact, Q8_0 rounding only
layer0_out (SSM, pos 0)   -0.0562  -0.0383   0.0005   -0.0568  -0.0356  -0.0033   -- small diffs, one near-zero-value outlier
layer3_out (dense, pos 0)  0.0037   0.1543  -0.0283    0.0200   0.1348  -0.0474   -- larger diffs, still same order of magnitude
```

**honest read**: the token embedding itself matches almost exactly (as
expected -- a pure weight-table lookup, and consistent with the
checkpoint-identity verification done earlier in this thread). The two
hidden-state comparisons are NOT decisive either way at this sample
size -- 8 of 4096 dimensions, one position, two layers. If anything, the
dense attention layer (3) shows larger relative differences in this tiny
sample than the SSM layer (0), which would argue against "the SSM path
specifically is where HF and llama.cpp diverge" -- but 8 dimensions is
nowhere near enough to draw that conclusion; it could just as easily be
sampling noise. A real answer needs an aggregate metric (cosine
similarity or relative L2 norm) across the FULL hidden-state vector, at
several layers spanning both SSM and dense positions, ideally at more
than one sequence position -- meaningfully more implementation work than
this pass reached. **Not finished.** Parking here rather than pushing
further this session: three decisive refutations (routing, scale-
formula/shape, base quantization) are already banked from the eighth and
ninth passes, this comparison's payoff is uncertain and open-ended by
comparison, and continuing to load models on this host again the same
session as a real stability incident warranted caution over momentum.

**reusable for next time**: `data/source/ik_llama.cpp/build-cpu/bin/
llama-eval-callback` is now built and available (CPU-only, no GPU/
production contention) -- dumps every named tensor in the graph
(matches the `cb()` call sites already traced in the eighth pass's
routing check) for a given prompt. Always pass `-c <small number>` to
avoid an oversized default-context KV allocation. The HF-side loading
block to reuse is saved as `data/control-vectors/hf_activation_probe.py`
-- captures embedding + layer0/layer3 position-0 hidden states for a
fixed 4-token prompt as a working example; extend it (more layers, full-
vector norms, more positions) rather than rewriting the loading/hook
scaffolding from scratch.

## eleventh pass [ live-only, no retrain -- reframes the tenth pass's
## stalled absolute-activation comparison as a DELTA comparison instead,
## since the tenth pass's own two sides use different base-weight
## quantizations (HF nf4, GGUF Q8_0) and the ninth pass already proved
## quantization alone shifts activations -- absolute values are
## uninterpretable there regardless of sample size. one bounded pass,
## pre-registered stop. Found a real, narrowed lead. ]

**reframe**: instead of comparing HF's and GGUF's absolute hidden-state
values (confounded by quantization, per above), compare each side's own
adapter-ON minus adapter-OFF delta. Quantization noise is largely
common-mode within a side's own pair of runs and cancels in the
difference, so this measures what actually matters -- does the adapter's
effect propagate similarly through the two implementations -- without
needing an unquantized HF reference (not obtainable on this host anyway:
bf16 9B is ~18GB, over both the 15GB RAM and 12GB VRAM ceilings).

**method**: whole-tensor `sum` of the `l_out` tensor (llama.cpp's own
built-in per-tensor reduction, printed by `eval-callback` with zero
patching -- avoids needing a print-format patch for full 4096-dim
vectors) at two SSM layers (0, 16) and two dense/full-attention layers
(3, 19 -- `full_attention_interval=4`, dense = index % 4 == 3, confirmed
against the per-layer KV-size table in eval-callback's own startup log
before picking indices). Same "The quick brown fox" prompt, position-
agnostic (whole-tensor sum spans all 4 token positions, a coarse
first-pass signal by design, not a replication of the real invoke-idiom
decision point). HF side: `data/control-vectors/hf_activation_delta_
probe.py` (new -- reuses `lora_invoke_probe.py`'s 4-bit-on-GPU loading
block, adds a `model.disable_adapter()` context for the off condition
and forward hooks summing each target layer's output). GGUF side:
`data/source/ik_llama.cpp/build-cpu/bin/llama-eval-callback`, off/on via
`--lora-scaled ... 1.0`, `-c 128` (avoid the default-context KV blowup
from the tenth pass), grep the `sum = ` line following each `l_out-N`.

**a real bug caught immediately, same shape as the very first attempt
in this whole thread**: the first on/off comparison came back byte-
identical (to 6 decimal places) at all four layers -- the adapter was
loading (`llama_lora_adapter_init_internal: loaded 496 tensors`) but
having literally zero effect. `eval-callback`'s own stderr explained it:
`llama_lora_adapter_set: flash_attn is not compatible with LoRA` -- the
exact same fork-specific incompatibility the eighth pass's production
fix (`coding.spawn_inference_server:565-591`) already guards against for
the live server, but `eval-callback` is a bare upstream example with no
such guard. Fixed by passing `--flash-attn off` explicitly on both
conditions; re-running produced real, non-identical numbers.

**results**:

```
layer   type    HF delta (rel.)   GGUF delta (rel.)
0       ssm         +2.28%            -0.21%
16      ssm        +39.85%            +1.83%
3       dense       +0.64%            +0.15%
19      dense       -0.96%            -2.12%
```
(relative = (sum_on - sum_off) / |sum_off|, same layer's own two runs;
raw sums themselves are NOT compared across HF/GGUF, only within a side)

**read**: three of four layers sit in a tight, unremarkable ~0.2-2.3%
band on BOTH sides -- HF layer 0, HF layer 3, HF layer 19, and all four
GGUF layers. HF layer 16 is a sharp outlier: ~20x larger than every
other measurement in the table, HF or GGUF. GGUF's own layer 16 shows
nothing unusual -- it sits at 1.83%, squarely inside the same small band
as its other three layers. This is a real, narrowed lead, not a diffuse
"everything's a bit off" finding: something about how PEFT computes the
adapter's effect through THIS SPECIFIC SSM layer produces a dramatically
outsized response that does not carry over to llama.cpp's computation of
the same layer. Consistent with (and sharper than) the ninth pass's
closing hypothesis -- "some kind of precision/numerics interaction
specific to the live compute path" -- now with an actual layer number to
chase instead of "somewhere in the SSM/gated-delta math."

**caveats, honestly**: n=1 prompt (4 tokens), n=1 run per condition, a
coarse whole-tensor-sum metric (could be dominated by one or two
outlier dimensions or one of the four token positions, not necessarily
a broad per-dimension effect) -- this is exactly the kind of result that
needs a second, independent prompt and ideally a per-position (not
whole-tensor) breakdown before treating "layer 16 specifically" as
confirmed rather than suggestive. Per the pre-registered stop for this
pass, not pursued further this session.

**restore state**: n/a -- this pass never touched the live production
GPU server (CPU-only `eval-callback` + a separate HF probe process on
the otherwise-idle GPU while the coding zenka was down for an unrelated
reason). No respawn needed.

**next step, if picked up**: repeat the delta measurement at layer 16
specifically with (a) a second, unrelated prompt, to rule out a prompt-
specific fluke, and (b) a per-position breakdown instead of a whole-
tensor sum (needs a small print-format patch to `eval-callback`, or an
equivalent capture on the HF side restricted to one position at a time)
-- if the spike survives both, that's a strong, specific claim worth a
source-level read of whatever `ssm_alpha`/`ssm_beta`/`ssm_out` computation
is architecturally distinct about layer 16 versus 0.

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

#,,,.,,.,,,..,.,,,,,,,...,.,,,...,,,.,..,,,,,,..,,...,...,..,,.,,,.,.,.,,,.,.,
#YTPPMRXT2OXBZ7QSNGITXYJM5FTFLSPHOF4LTBK6CI5BNRGP2VAJ4FSN76L4CMJ3WWAM4TFDDBTZQ
#\\\|WE66JPNZQALGGCVKSTDRY74XUPXKJQRHOH6LLPI3TLYF2SIFE3B \ / AMOS7 \ YOURUM ::
#\[7]UPVGO37T7MALNOEUIROBW4WU3ZOLKQEE4HCN2GZSFSCPIJIJUECQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
