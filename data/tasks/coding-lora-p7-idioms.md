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
  side-note, not yet resolved: the live coding zenka's server invocation
  passes `--chat-template-kwargs {"reasoning_effort":"medium"}`, but
  this jinja file has no reference to `reasoning_effort` anywhere --
  either ik_llama.cpp consumes that kwarg outside the template (sampling/
  verbosity control) or it's presently a no-op. irrelevant to training-
  format correctness above, just noted as an open loose end if it
  matters later.

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

#,,.,,..,,,..,,..,,.,,,,,,.,.,,,,,,,,,,.,,,.,,..,,...,...,..,,.,,,,.,,..,,,,,,
#KGPBB66Y7UVOHCTB7PF26FK7KUBGSFO3IM2CSLIVRMQYZ5P2F7PORHLOIYZSHI2B4UCLK4BEBLDN6
#\\\|LWWG3ZY4YJQPKIOXGSWHQ7LBARMBGOOIXBTSMS2O26MYMMWPR5I \ / AMOS7 \ YOURUM ::
#\[7]DX4CVF4RF4B4IWQTVGBFOJ3PU5HJXL2RKV2QITNLT5CO2DZTRGBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
