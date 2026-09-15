## [:< ##

# name  = task: quantize petruhonk's checkpoint to GGUF, serve it, re-validate LoRA
# descr = self-contained follow-on from coding-lora-p7-idioms.md's fifth
#         diagnostic pass: build a working GGUF from the SAME checkpoint the
#         LoRA adapters were trained against, swap it in, re-run validation

## context

`data/tasks/coding-lora-p7-idioms.md`'s "fifth diagnostic pass" section
(read that in full before starting) found and confirmed, via the
production GGUF's own embedded metadata, that all four prior LoRA
training attempts trained against the wrong base checkpoint:

- production serves `mradermacher/Qwen3.8-9B-heretic-uncensored-i1-GGUF`,
  whose embedded `general.source.url` = `https://huggingface.co/rohit267/
  Qwen3.8-9B-heretic-uncensored` -- confirmed via direct GGUF metadata
  read (`gguf.GGUFReader`), not guessed.
- all four LoRA attempts trained against
  `petruhonk/Qwen3.8-9B-Distill-uncensored-heretic` (fetched 2026-09-10 as
  a stand-in after rohit267's repo 404'd) -- a different HF repo, tagged
  `empero-ai` / `Qwen3_5ForConditionalGeneration` (a VLM-capable class),
  looking like a different lineage rather than a re-upload of rohit267's
  weights.
- rohit267's original repo is genuinely deleted (confirmed 404 "Repository
  not found" using a valid HF auth token, not a gating/auth artifact).
- a token-level logprob probe (`data/control-vectors/lora_invoke_probe.py`
  + `lora_invoke_generalization_probe.py`) showed the trained adapters
  produce a dramatic, real, GENERALIZING confidence boost on the invoke
  idiom in HF/PEFT space (against petruhonk) -- the training mechanism
  itself works. But the live GGUF-deployed server (built from rohit267's
  weights) never reproduces this, and raising the runtime lora scale
  entrenches the wrong answer rather than approaching the trained
  direction -- inconsistent with underscaling, consistent with a real
  base-weight mismatch between what was trained and what is served.

**the fix this task implements**: rather than chase down rohit267's
deleted weights (one confirmed derivative exists,
`Foresee/Qwen3.8-9B-heretic-uncensored-4bit-MTPLX`, but only as a
quantized Apple-Silicon MLX artifact, not full-precision, not directly
usable for further gradient work or GGUF conversion) -- self-quantize the
checkpoint already in hand (petruhonk, already fetched, already the
checkpoint the existing LoRA adapters were trained against and already
proven to work on) into a real, working GGUF, and switch the coding
zenka to serve THAT instead. This makes train-time and serve-time weights
identical, sidestepping the missing-checkpoint problem entirely, and
requires **no retraining** -- the already-trained attempt2 and attempt4
adapters (`data/control-vectors/lora-out/p7-idioms-real/adapter/`,
`data/control-vectors/lora-out/p7-idioms-invoke-oversampled/adapter/`)
get re-validated against the new base as-is.

## what already exists, reuse it

- `petruhonk/Qwen3.8-9B-Distill-uncensored-heretic` HF checkpoint already
  fetched at `/mnt/ext-xfs-data/models-lmstudio/petruhonk/Qwen3.8-9B-
  Distill-uncensored-heretic/` (safetensors, config.json, tokenizer.json
  all present -- this is what training used, see `data/control-vectors/
  train_lora.py`'s `--base-checkpoint` argument).
- this fork's `gguf-py` (`/data/source/ik_llama.cpp/gguf-py`) has **no
  qwen35/qwen3_5 architecture registered** in `convert_hf_to_gguf.py` or
  `gguf/constants.py` (confirmed via grep, 2026-09-14) -- the vendored
  full-model converter will refuse this checkpoint outright. Do not
  assume upstream/mainline llama.cpp has since gained support without
  checking first; if it has, strongly prefer reusing that over a
  hand-rolled converter.
- **the hard part is already solved once**: `data/control-vectors/lora/
  lora_to_gguf.py` (written for the LoRA-adapter-only conversion, not
  full models) already contains a verified, shape-confirmed HF-tensor-
  name -> ggml-tensor-name mapping for every tensor type this
  architecture has, including the 24 linear-attention/SSM layers that
  have no analog in a plain dense transformer:
  ```
  self_attn.q_proj -> attn_q          mlp.gate_proj -> ffn_gate
  self_attn.k_proj -> attn_k          mlp.up_proj   -> ffn_up
  self_attn.v_proj -> attn_v          mlp.down_proj -> ffn_down
  self_attn.o_proj -> attn_output
  linear_attn.in_proj_qkv -> attn_qkv     linear_attn.in_proj_a -> ssm_alpha
  linear_attn.in_proj_z   -> attn_gate    linear_attn.in_proj_b -> ssm_beta
  linear_attn.out_proj    -> ssm_out
  lm_head -> output (top-level, no blk.N. prefix)
  ```
  these were confirmed by exact tensor-SHAPE match against the real,
  already-working production GGUF (not guessed from name similarity) --
  reuse this mapping directly, don't re-derive it. A full-model converter
  additionally needs: embedding table (`model.embed_tokens.weight` ->
  `token_embd.weight`), final norm, per-layer norms, and any
  architecture-specific buffers/scalars (SSM has extra per-layer scalar/
  vector parameters beyond the 5 mapped weight matrices above -- inspect
  the checkpoint's full `model.safetensors.index.json` and enumerate
  every unmapped key before assuming the 12-entry map above is complete
  for a full model; the LoRA-only version only needed tensors that PEFT
  targets, which is a strict subset).
- `/usr/bin/llama-quantize` is already installed (built from this same
  ik_llama.cpp fork, since it already serves qwen35 GGUFs at inference)
  -- **do not hand-roll K-quant bit-packing**. Write the converter to
  produce a correctly-named/shaped F16 (or F32) GGUF, then invoke this
  existing binary to produce the final quantized file (Q4_K_M to match
  the current production quant, or another type if a specific reason
  favors it -- record the reason if so).
- `data/control-vectors/run_validation_sweep.sh` is the existing,
  reusable validation harness (baseline vs lora-on, health-confirmed
  server wait, no fixed-timeout hazard) -- use it unmodified for the
  final validation step, don't write a new one.
- `coding.cfg.lora_adapter` / `coding.switch-model <checksum> backend=gpu`
  is the existing, correct way to point the live server at a different
  model/adapter combination -- see `src/coding.spawn_inference_server`
  and `src/coding.cmd.switch-model`. The new petruhonk-based GGUF needs
  to be registered in whatever registry `coding.switch-model` reads
  model paths from (`<coding.model_metadata>`, populated by the models
  zenka) before `switch-model` can target it by checksum -- find and use
  the existing registration mechanism (`fetch.file.huggingface.*` /
  the models zenka's own scan-path config), don't bypass it with a raw
  `coding.eval-code` config-tree write except for throwaway local
  testing (that pattern was used for the diagnostic pass's cheap
  experiments, but is explicitly not the durable way to wire in a new
  production-candidate model).

## hazards, read before starting

1. **standing permission to stop/restart the live coding-zenka GPU
   server exists** (`data/ai-mem/claude/feedback-coding-zenka-gpu-
   interrupt-standing-permission.md`) -- use it, but always respawn via
   `coding.switch-model <checksum> backend=gpu`, never a direct
   `coding.spawn_inference_server` call with a bare params hash (this
   skips model-path resolution and crashes against a placeholder path --
   a real mistake made and fixed during the diagnostic pass, see
   `coding-lora-p7-idioms.md`'s fifth-pass operational note). Set
   `<coding.lora_training_in_progress> = TRUE` before stopping the live
   server and clear it after restoring, so the crash-restart handlers
   don't fight you (same guard the training spawn path already uses).
2. **never fixed-timeout-and-proceed on a server health check** -- reuse
   `run_validation_sweep.sh`'s `wait_confirmed_healthy()` (polls `/health`
   for `slots_idle:1`, generous ceiling, no early give-up) for every
   respawn, including ones this task adds that aren't already inside that
   script.
3. **verify the new GGUF actually works before wiring in any LoRA on top
   of it**: load it plain (no adapter), run the coding zenka's self-test,
   and sanity-check a few plain generations for coherence (petruhonk's
   raw HF-space baseline showed some noisy/garbage top-k entries in one
   probe sample during the diagnostic pass -- confirm this isn't a real
   quality problem with the quantized result before spending time
   re-validating LoRA against a broken base).
4. **restore state when done**: same convention as every other pass in
   this thread -- if the new GGUF does NOT end up promoted to the
   permanently-configured production model, leave the live server back on
   its original `mradermacher` quant with no lora flags, config
   uncommented/unmodified, exactly as `coding-lora-p7-idioms.md`'s
   existing "restore state" scope item describes.

## acceptance criteria

1. A working F16-or-better GGUF built from petruhonk's checkpoint that
   the live `ik_llama.cpp` fork loads and serves without error, self-test
   passing, coherent plain-generation output (confirm via a handful of
   varied prompts, not just self-test).
2. `llama-quantize`-produced Q4_K_M (or documented alternative) version
   of the same, also verified loading/serving/self-test/coherence.
3. `run_validation_sweep.sh` re-run against this new base with attempt2's
   and attempt4's existing GGUF adapters (`data/control-vectors/lora/
   p7-idioms-real-lora.OFSQC4I-QDBKEXY.gguf`, `p7-idioms-invoke-
   oversampled-lora.OFSQC4I-QDBKEXY.gguf`) -- **no retraining, no new
   adapter conversion needed**, reuse the existing GGUF adapter files
   as-is against the new base.
4. Report the `invoke` idiom count from `score.py`'s structural
   subcategory, baseline vs lora-on, same discipline as every prior
   attempt in `coding-lora-p7-idioms.md`. **If `invoke` moves off zero**:
   the checkpoint-mismatch hypothesis is fully confirmed and this becomes
   the path to a real fix (promote this base to production, or at least
   to how the coding zenka's LoRA-enabled mode is served). **If `invoke`
   still doesn't move**: the mismatch either wasn't the (sole) cause, or
   something else in this new conversion path has its own bug -- write
   up which, don't just report a bare negative.
5. Write up the full result as a new dated section appended to
   `data/tasks/coding-lora-p7-idioms.md` (not a separate file merged in
   later), following the existing section-per-attempt convention exactly
   (see the "fourth attempt" and "fifth diagnostic pass" sections for the
   expected level of detail and honesty about confounds/caveats). Update
   `HANDOVER.md` and `data/ai-mem/claude/MEMORY-active.md`'s existing
   coding-lora-p7-idioms pointer to match. Commit through the normal
   signed-commit flow (`bin/Protocol-7 sourcecode update-signatures`
   before each commit that touches signed paths).

## resolution [ 2026-09-15 -- SUPERSEDED BY FINDINGS, see the "sixth
## pass" section of data/tasks/coding-lora-p7-idioms.md for the full
## account; that section is the canonical write-up this task's
## acceptance criterion 5 asked for ]

what ran in this task, in short:

1. **converter built and verified**: `data/control-vectors/lora/
   qwen35_hf_to_gguf.py` [ streaming, memory-bounded ] converts the
   petruhonk checkpoint to a 427-tensor qwen35 F16 GGUF. verification
   (a): every tensor bit-exact vs its HF source [ f16 lossless from
   bf16, f32 exact ]. all non-obvious transforms [ (1+w) RMSNorms,
   ssm_a=-exp(A_log), v-head permutation, per-head-interleaved q/gate,
   conv1d squeeze ] were established numerically against ge525's
   pre-existing GGUF + the fork's graph source, not guessed.
2. **acceptance criterion 1 was WITHDRAWN BY THE TASK AUTHOR after a
   host OOM crash**: serving the 18.4GB F16 on this 15GB host must
   never be attempted; the F16 exists only as llama-quantize input.
   the crash's root cause was that criterion, not the conversion code.
3. **the checkpoint-mismatch hypothesis this task was built on is
   REFUTED**: the local petruhonk checkout had a corrupt shard 4
   [ right size, right header, wrong data; sha256 mismatch vs the
   published HF LFS hash ] since the 2026-09-10 fetch -- BEFORE any
   training. petruhonk's PUBLISHED weights are identical to rohit267's
   [ ge525's independent conversion of petruhonk reproduces the
   production mradermacher GGUF bit-exactly on every F32 anchor tested,
   all 32 layers ]. production was never mismatched; the four LoRA
   adapters were trained against a franken-checkpoint [ intact layers
   0..25-attn-side, garbage 25-attn-out..31 + final norm ] and are the poisoned artifacts.
4. **shard repaired 2026-09-15**: intact shard 4 re-fetched from HF
   [ hash-verified ], corrupt file quarantined as
   `model-00004-of-00004.safetensors.CORRUPT-20260910-do-not-use`.
   the franken-tail F16 GGUF renamed `...-f16.FRANKEN-TAIL-do-not-use
   .gguf`; a fresh F16 rebuilt from the intact checkpoint [ verified
   exact again ] sits at the original path as quantize-only input.
5. **serve + re-validate is being run by the task author separately,
   using ge525's pre-made Q4_K_M** [ == production weights, so it
   cannot by itself fix anything; a negative there measures the
   poisoned adapters, not the technique -- see the pre-registered
   interpretation in the sixth-pass section ]. the real attempt 5 is a
   RETRAIN against the intact checkpoint.

acceptance criteria status: 1 [ working F16 GGUF ] -- MET as a
conversion+verification artifact [ never served, per the withdrawn
criterion ]. 2 [ llama-quantize Q4_K_M of it ] -- NOT RUN in-session;
ge525's pre-made quant [ == same source weights ] is being used for
the serve step instead. 3-4 [ sweep re-run, invoke metric ] -- NOT RUN
in-session; taken over by the task author. 5 [ write-up ] -- DONE
[ sixth-pass section + this resolution + HANDOVER/MEMORY updates ].

#,,..,,,.,,,.,.,.,,..,...,..,,.,.,.,.,,,.,.,,,..,,...,.,,,,,,,,..,.,.,.,,,,,,,
#IRCC22XXCPF2EFQDPKSEUF43P7GTR5C2ZJQC3DTKRYJLLCZJR27A4KXEFOJUUHEEHBEHB7MLCHORE
#\\\|PQ5URQ3GPHRDPTX55SWNHUETZ6ZCJ5EO2AWRL7LOXX6Q6DUOQUT \ / AMOS7 \ YOURUM ::
#\[7]OVQFXISYGNLKCUECZ3OHZ7Y2EI22IGCGONCZNLEBE7WOGFD47OBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
