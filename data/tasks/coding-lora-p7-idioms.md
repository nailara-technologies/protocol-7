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
  prompt-v2/A.seed13.json`). **not yet confirmed**: whether the model's
  *raw* generated text (before the server's parsing) includes a literal
  `<think>...</think>` span that the chat template (`data/jinja/
  templates/qwen3.5-fixed.jinja`) expects training assistant-turns to
  also contain. get this right before generating training data -- if the
  raw format includes think-tags and training pairs omit them, the
  adapter learns a token distribution that never matches the reasoning-
  enabled runtime and either destabilizes generation or gets silently
  ignored by the model reverting to its stronger pretrained prior.

## hazards that waste a run [ read before doing anything ]

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

5. **validate with the same fixed rubric (`score.py`), but apply the
   2026-09-09 addendum's lessons**: report length-normalized (idiom per
   1000 chars) numbers alongside raw counts, and call out separately
   which idiom categories moved -- a raw-count win driven by `comment`/
   `bracket` mimicry again would repeat the exact confound found and
   caught this session, not a genuine result.

## scope

1. **dataset**: expand the P7-idiom contrastive/instruction set to a
   size suited for gradient training (order of hundreds of examples),
   covering the same categories `score.py` measures. exclude the 3
   canonical held-out prompts; consider a second never-touched held-out
   set. decide and record whether assistant-turn training targets
   include a `<think>` span (see mechanism section, open question).

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

#,,.,,,,.,,.,,..,,,,.,,..,,..,...,,,,,.,,,,,.,..,,...,...,...,,,,,.,.,.,.,,..,
#HQKUIFEUCGXB6NKASMRW47XBXD7IVTHM5UESPR5K7BZBID6ZQUJXMULDADGXBYJKENNA2VFKMTBSA
#\\\|TJO6BFHCB6LJOZL64QDC4WOXSPMBAFHJDJLUUEX6VQCQOINZO7F \ / AMOS7 \ YOURUM ::
#\[7]Q5HWP43DCGRETB7RTQPZXSRJYBEXPLMVP4PVPKGM2KDO4WESX4AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
