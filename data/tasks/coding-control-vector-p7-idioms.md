## [:< ##

# name  = task: control vector for protocol-7 coding idioms
# descr = steer the coding zenka's model toward correct P7 idioms at
#         inference time via llama.cpp's existing --control-vector
#         support, instead of a from-scratch trained adapter

## context

raised 2026-09-08 following up on `data/tasks/completed/coding-cpu-and-
hybrid-offload-path.md` and the new `embedding_search` tool
(`data/tasks/completed/` once archived) -- the user asked about "loading
embeddings with a model", which led to reading
`data/md/design/INDEX-FASTTEXT-SOURCECODE-EMBEDDINGS.md`. that doc
proposes training a custom projection layer mapping FastText subword
vectors into the base model's hidden-state space -- a real idea, but
"designed" status only, with no existing precedent in this codebase, no
training data, and no confirmed way to load a custom adapter into
`llama-server` at all.

**checked live, same day**: `llama-server` (this project's own
`/data/source/ik_llama.cpp` build) already supports `--control-vector`
and `--control-vector-scaled` + `--control-vector-layer-range`, and the
source tree already ships `examples/cvector-generator` [ confirmed:
`ik_llama.cpp/examples/cvector-generator/cvector-generator.cpp`,
`README.md` ] -- the standard llama.cpp activation-steering technique
(mean-difference or PCA over hidden-state activations from paired
contrastive prompts), already-shipped, not something to build from
scratch. per the user: the design doc likely would have proposed this
instead, had its author known `--control-vector` was available.

this task is the control-vector path, NOT the custom-adapter path in the
design doc. same underlying goal (the model "arrives already oriented"
toward P7 idioms, no context-window cost) via existing, already-proven
infrastructure instead of new ML engineering.

## confirmed mechanism [ read directly from this checkout's source ]

everything below was read out of `/data/source/ik_llama.cpp` on
2026-09-08. this is a FORK, and it differs from upstream llama.cpp in at
least one way that matters [ see hazard 1 ] -- trust this section over
any upstream README, blog post or PR description.

- CLI flags: `--positive-file FNAME` / `--negative-file FNAME` [ default
  `examples/cvector-generator/positive.txt` / `negative.txt` ], one
  prompt per line, plus `-o FNAME`, `--method {pca,mean}`, `--pca-batch
  N` [ default 100 ], `--pca-iter N` [ default 1000 ]. confirmed in
  `common/common.h:594-600` and `common/common.cpp:2882-2947`. that is
  the COMPLETE cvector flag set in this fork.
- each line is one FULL chat-template-formatted conversation, assistant
  reply included. multi-line prompts escape newlines as literal `\n`
  within the single line. the loader runs `string_process_escapes` on
  each line [ `cvector-generator.cpp: ctrlvec_load_prompt_file` ], and
  tokenizes with `parse_special = true`, so `<|im_start|>` and friends
  become real special tokens rather than literal text.
- ours must use THIS project's actual chat template
  [ `coding.jinja.template_file` = `data/jinja/templates/
  qwen3.5-fixed.jinja`, confirmed ChatML: `<|im_start|>system\n...
  <|im_end|>\n<|im_start|>user\n...<|im_end|>\n<|im_start|>assistant\n...` ].
- positive.txt and negative.txt must be **structurally paired,
  line-for-line**: same system/user turn on both sides, differing ONLY in
  the trait being isolated [ P7-idiomatic vs generic/wrong style ]. the
  tool asserts `positive_prompts.size() == negative_prompts.size()` and
  exits if they differ.
- **only the tokens after the two sides diverge actually contribute.**
  the callback captures the full `[n_embd, n_tokens]` hidden state at
  every layer for both sides, subtracts them, then `filter_nonzero_rows`
  drops every row whose diff is zero. the shared system+user prefix is
  token-identical, so its diff is exactly zero and it is discarded. the
  usable signal per pair is therefore roughly **the number of tokens in
  the assistant turn**, not the length of the whole line. this drives the
  dataset sizing below.
- generation: `-m <real GGUF>`. hidden states come from an actual forward
  pass, so the vector is **model-specific and must be regenerated
  whenever the model changes** -- but see hazard 2, because nothing
  enforces this.
- output: a GGUF holding 1-D F32 tensors named `direction.1` ..
  `direction.(n_layers - 1)`. **indices are 1-based and the final layer
  is deliberately discarded** [ `train_context` allocates `n_layers - 1`;
  `mean.hpp` / `pca.hpp` name with `il+1` ]. for our 32-layer model that
  is `direction.1` .. `direction.31`.
- loading, already supported by the `llama-server` binary already in use:
  `--control-vector-scaled <file> <scale> --control-vector-layer-range
  <start> <end>`. the loader defaults `layer_start` to 1 and `layer_end`
  to `llama_n_layer(model)` when unset. README's own tip: works better on
  layers higher than 10. our current model (`OFSQC4I:QDBKEXY`, Qwen3.8
  9B Heretic Uncensored, per `coding.cfg.start_model`) has 32 layers
  [ confirmed earlier the same day via `models.gguf.file.
  extract_layer_count`, `data/tasks/completed/coding-cpu-and-hybrid-
  offload-path.md` ] -- a reasonable starting range is `10 31`, tune from
  there.
- **`scale` is applied at load time and may be negative**: the loader
  does `dst[j] += src[j] * strength` [ `common.cpp:
  llama_control_vector_load_one` ]. passing `-0.8` loads the exact
  sign-flipped direction. this is what makes the negative control in the
  validation section a one-flag experiment.
- `cvector-generator` is not currently built in the CUDA docker image
  [ `bin/build-scripts/llama-cpp/build-llama-server-cuda-flashattn.sh`
  only extracts `llama-server` + libs ] -- needs its own build step, see
  scope below.

## hazards that waste a run [ read before doing anything ]

ordered by how much time each one costs if missed.

1. **`--completions-file` does not exist in this fork -- ignore
   `completions.txt`.** upstream llama.cpp's cvector-generator combines
   each positive/negative *persona prefix* with every line of
   `completions.txt`. this fork's `prepare_entries` does no such thing:
   it loads the two files and pairs them line-for-line, full stop.
   `completions.txt` [ 581 lines ] is still sitting in the directory and
   is dead weight. every upstream tutorial you find will be describing
   the other design. building the dataset as prefixes-plus-completions
   produces a garbage vector and a wasted run.

2. **PCA output has an arbitrary, non-reproducible sign.**
   `pca.hpp: power_iteration` seeds its starting eigenvector from
   `std::default_random_engine(std::time(0))`. an eigenvector's sign is
   already undetermined; a time-seeded random start means `--method pca`
   can hand you the *negative* of the direction you wanted, and can flip
   between two runs of the same data. `--method mean` is a plain average
   of `(positive - negative)` diffs and is deterministic and correctly
   signed. therefore: **run `--method mean` first and treat it as the
   baseline.** if you also try `pca`, you MUST test both `+scale` and
   `-scale` before drawing any conclusion. a test at `+1.0` only, on a
   pca vector, is the single easiest way to reach a confident, wrong
   "it doesn't work".

3. **a stale vector loads silently against the wrong model.**
   `export_gguf` writes `controlvector.model_hint` from
   `general.architecture` -- i.e. `"qwen3"`, not the fine-tune -- and
   `llama_control_vector_load_one` **never reads that key at all**. the
   only compatibility check anywhere is `n_embd` matching, in
   `llama_control_vector_apply`. `cfg/zenki/coding/zenka.v7` carries
   ~20 commented-out `start_model` alternates, several of them same-size
   Qwen3 variants. so: put the model id in the vector filename
   [ eg `p7-idioms.OFSQC4I-QDBKEXY.mean.gguf` ] and note the id in the
   config comment. nothing else will catch a mismatch.

4. **length mismatch inside a pair is not a stylistic nitpick, it is
   injected noise.** `tokenized_prompt` pads the shorter side up to
   `max_seq_len` with literal space tokens. those pad positions are
   *after* the divergence point, so their diffs are nonzero and they are
   **counted as real rows**. a pair whose positive side is 12 tokens
   against a 20-token negative contributes ~40% of its rows as "trailing
   whitespace vs real code".
   **measure this, do not eyeball it** -- character count is not token
   count, and the P7 forms fragment differently from the generic ones
   [ `<[coding.helper.foo]>->` against `Coding::Helper::Foo::run` is the
   obvious case ]. run the checkout's `llama-tokenize -m <model> -p
   '<line>'` over both sides of every pair and keep the delta under ~10%
   of the assistant-turn length. where a pair is too short for that to be
   achievable at all, make sure the leftover mismatch is not consistently
   signed the same way across pairs -- a consistent sign survives
   averaging under `--method mean`, mixed signs largely cancel.

5. **each line must fit in one ubatch.** the whole prompt is decoded in a
   single `llama_batch_get_one`, and `cb_eval` only records a tensor when
   `t->ne[1] == n_tokens`. exceed the physical batch and no tensors are
   captured, `v_pos` stays empty, and you get an opaque `GGML_ASSERT`
   rather than a message. `n_ubatch` defaults to 512
   [ `common.h:298` ]. our pairs run ~40 prefix tokens + assistant turn,
   so the target below [ 60-120 assistant tokens ] is comfortable -- but
   if any line approaches ~400 tokens, pass `-c 4096 -b 4096 -ub 4096`
   explicitly.

6. **a pair whose two sides are identical aborts the run.**
   `filter_nonzero_rows` ends in `GGML_ASSERT(n_nonzero_rows > 0)`. a
   copy-paste slip that leaves one line the same on both sides takes the
   whole generation down. diff the two files before running.

7. minor, no action needed, just do not be alarmed: `is_row_all_zeros`
   tests `> eps` rather than `fabs(...) > eps`, so a row whose diff
   happens to be entirely non-positive is treated as zero and dropped.
   this is an upstream quirk, present in real use, and harmless at
   dataset sizes above a few hundred rows.

## scope

1. **build `cvector-generator`.** either add it to the existing CUDA
   docker build script's extraction list [ preferred, reuses the image
   already built today ] or build it standalone via `cmake --build`
   against the existing `/data/source/ik_llama.cpp` checkout. CPU-only is
   fine for generation [ README's own `-ngl 99` example is optional, for
   speed only ] -- this is a one-time-per-model-change offline step, not
   a hot path.

2. **smoke-test the pipeline on the 10 exemplar pairs FIRST.** do this
   before writing a large dataset. transcribe the 10 pairs below into
   `positive.txt` / `negative.txt`, run `--method mean`, confirm a
   `.gguf` comes out with 31 `direction.*` tensors, and confirm
   `llama-server` starts with it loaded and still answers normally. that
   is a **pipeline check only** -- it proves the plumbing, and it proves
   nothing whatsoever about whether the steering works. do not report an
   efficacy result off a 10-pair vector.

3. **then expand the dataset. minimum 40 pairs before any efficacy
   claim.** the arithmetic: usable rows per pair ≈ assistant-turn token
   count [ the shared prefix diffs to zero and is filtered ]. one-line
   answers give ~15 rows. ten of those is ~150 rows to fit a direction in
   a 3584-dimensional hidden space -- badly underdetermined. so aim for
   **≥ 40 pairs with assistant turns of ~60-120 tokens each**, roughly
   ≥ 2500 usable rows. keep the discipline the exemplars follow: same
   system and user turn on both sides, token-length matched, the ENTIRE
   assistant reply consistently idiomatic (or consistently generic), not
   just one token changed. and vary the **shape** of the answer, not only
   the topic -- see the diversity note under the dataset.

4. **generate the vector** against the actual model currently in daily
   use (`coding.cfg.start_model` = `OFSQC4I:QDBKEXY`), using the real
   chat template. `--method mean` is the baseline; `--method pca` is a
   comparison, subject to hazard 2. name the output file with the model
   id in it, per hazard 3.

5. **wire loading into the spawn path.** add `coding.cfg.control_vector`
   (path) and `coding.cfg.control_vector_scale` / `_layer_range` config
   keys to `cfg/zenki/coding/zenka.v7`, config-gated [ absent/empty =
   today's unchanged behavior ], and extend `coding.spawn_inference_
   server`'s `@cmd` builder to add `--control-vector-scaled <path>
   <scale> --control-vector-layer-range <start> <end>` when configured.
   **apply this for both backends, NOT gpu-only.** `-ngl` is conditioned
   on `$backend eq 'gpu'` because gpu layer count is meaningless on cpu;
   a control vector is backend-agnostic and works identically on the cpu
   and hybrid paths. gating it behind the gpu check would silently
   disable steering on the very backend most likely to be used for a
   cheap A/B run.

6. **validate honestly.** see the validation section -- it is a specific
   experiment design, not "try it and see".

## draft contrastive dataset [ 10 worked exemplars -- these are the
## PATTERN to copy, not the finished dataset. expand per scope item 3 ]

format below: each numbered pair is ONE line in `positive.txt` and the
matching line in `negative.txt`, in the project's real ChatML template,
newlines escaped as `\n` per the tool's own convention. system turn kept
minimal and identical across all pairs [ isolates the idiom trait, not a
persona ].

**escape trap**: `string_process_escapes` runs over each line, so any
`\n` `\t` `\r` `\"` `\'` `\\` inside your *code content* is consumed as
an escape, not shown to the model. write `\\n` if you need a literal
backslash-n in a Perl string. unrecognized escapes such as `\.` fall
through the `default:` branch and survive intact, so regexes like
`/^\./` are safe.

**diversity note**: pairs 1-7 and 10 are one-line snippets, pair 8 is a
multi-line module body, pair 9 is prose. that ratio is deliberate --
if every pair were "write me one line", the dominant direction the tool
recovers could easily be *"answer with a single short line"* rather than
*"use P7 idioms"*. when expanding, keep a real mix: one-liners,
multi-line module bodies, prose explanations, config-file fragments,
commit-message style. pair 8's length is the target for most new pairs.

**caveat on pairs 6 and 7**: both answers are only a handful of tokens
long, so hazard 4's length-matching is structurally unachievable there --
`:verbose:` and `coding.helper.parse_timestamp` simply do not tokenize to
the same count as `--verbose` and `Coding::Helper::ParseTimestamp`, and
on a ~6-token answer even a 2-token gap is a large fraction. they are
included for **trait coverage**, not as length exemplars. do not copy
their brevity when expanding; either give new pairs enough surrounding
context that the delta becomes a small fraction, or accept them as the
few deliberately short members of a mostly pair-8-shaped set.

```
### pair 1 -- logging
POSITIVE:
<|im_start|>system\nYou are a protocol-7 developer.<|im_end|>\n<|im_start|>user\nWrite one line that logs a warning when a config module fails to load.<|im_end|>\n<|im_start|>assistant\n<[base.logs]>->( 0, '%s failed to load config', $module_name );
NEGATIVE:
<|im_start|>system\nYou are a protocol-7 developer.<|im_end|>\n<|im_start|>user\nWrite one line that logs a warning when a config module fails to load.<|im_end|>\n<|im_start|>assistant\nwarn sprintf( '%s failed to load config', $module_name );

### pair 2 -- module invocation
POSITIVE:
<|im_start|>system\nYou are a protocol-7 developer.<|im_end|>\n<|im_start|>user\nCall the helper module coding.helper.foo with the job id and keep the result.<|im_end|>\n<|im_start|>assistant\nmy $result = <[coding.helper.foo]>->($job_id);
NEGATIVE:
<|im_start|>system\nYou are a protocol-7 developer.<|im_end|>\n<|im_start|>user\nCall the helper module coding.helper.foo with the job id and keep the result.<|im_end|>\n<|im_start|>assistant\nmy $result = Coding::Helper::Foo::run($job_id);

### pair 3 -- boolean return
POSITIVE:
<|im_start|>system\nYou are a protocol-7 developer.<|im_end|>\n<|im_start|>user\nReturn true if the write succeeded, false otherwise.<|im_end|>\n<|im_start|>assistant\nreturn TRUE if $write_ok;\nreturn FALSE;
NEGATIVE:
<|im_start|>system\nYou are a protocol-7 developer.<|im_end|>\n<|im_start|>user\nReturn true if the write succeeded, false otherwise.<|im_end|>\n<|im_start|>assistant\nreturn 1 if $write_ok;\nreturn 0;

### pair 4 -- config read with fallback [ // held constant on both sides
### so the ONLY difference is the config-access sugar ]
POSITIVE:
<|im_start|>system\nYou are a protocol-7 developer.<|im_end|>\n<|im_start|>user\nRead the thread count from config, default to 8 if unset.<|im_end|>\n<|im_start|>assistant\nmy $threads = <inference.backend.cpu.threads> // 8;
NEGATIVE:
<|im_start|>system\nYou are a protocol-7 developer.<|im_end|>\n<|im_start|>user\nRead the thread count from config, default to 8 if unset.<|im_end|>\n<|im_start|>assistant\nmy $threads = $config->{'inference'}{'threads'} // 8;

### pair 5 -- comment style
POSITIVE:
<|im_start|>system\nYou are a protocol-7 developer.<|im_end|>\n<|im_start|>user\nAdd a comment above this line explaining it skips dotfiles.<|im_end|>\n<|im_start|>assistant\n## skip hidden files [ dotfiles ]\nnext if $file =~ /^\./;
NEGATIVE:
<|im_start|>system\nYou are a protocol-7 developer.<|im_end|>\n<|im_start|>user\nAdd a comment above this line explaining it skips dotfiles.<|im_end|>\n<|im_start|>assistant\n# Skip hidden files (dotfiles).\nnext if $file =~ /^\./;

### pair 6 -- CLI flag style
POSITIVE:
<|im_start|>system\nYou are a protocol-7 developer.<|im_end|>\n<|im_start|>user\nShow the p7c command to run a build with verbose output.<|im_end|>\n<|im_start|>assistant\np7c coding.build :verbose:
NEGATIVE:
<|im_start|>system\nYou are a protocol-7 developer.<|im_end|>\n<|im_start|>user\nShow the p7c command to run a build with verbose output.<|im_end|>\n<|im_start|>assistant\np7c coding.build --verbose

### pair 7 -- module naming
POSITIVE:
<|im_start|>system\nYou are a protocol-7 developer.<|im_end|>\n<|im_start|>user\nName a new helper module in the coding zenka for parsing timestamps.<|im_end|>\n<|im_start|>assistant\ncoding.helper.parse_timestamp
NEGATIVE:
<|im_start|>system\nYou are a protocol-7 developer.<|im_end|>\n<|im_start|>user\nName a new helper module in the coding zenka for parsing timestamps.<|im_end|>\n<|im_start|>assistant\nCoding::Helper::ParseTimestamp

### pair 8 -- deferred retry [ long-form exemplar: this is the assistant
### turn LENGTH to aim for when expanding the set ]
POSITIVE:
<|im_start|>system\nYou are a protocol-7 developer.<|im_end|>\n<|im_start|>user\nSchedule a retry of the job 5 seconds from now and return from the handler.<|im_end|>\n<|im_start|>assistant\n## schedule the retry [ non-blocking, handler runs on the event loop ]\n<[event.add_timer]>->(\n    {   'after'   => 5,\n        'handler' => qw| coding.handler.retry_job |,\n        'data'    => { 'job_id' => $job_id },\n    }\n);\n\nreturn { 'mode' => qw| deferred |, 'data' => 'retry scheduled' };
NEGATIVE:
<|im_start|>system\nYou are a protocol-7 developer.<|im_end|>\n<|im_start|>user\nSchedule a retry of the job 5 seconds from now and return from the handler.<|im_end|>\n<|im_start|>assistant\n# Schedule the retry (blocking wait on the current thread).\nuse Time::HiRes qw(sleep);\n\nsleep(5);\nmy $status = retry_job(\n    $job_id,\n    { attempts => 1 },\n);\n\nreturn { success => 1, message => 'Retry scheduled' };

### pair 9 -- prose explanation [ different ANSWER SHAPE on purpose:
### tests lowercase narrative + [ bracket ] annotation + P7 vocabulary
### outside of a code block ]
POSITIVE:
<|im_start|>system\nYou are a protocol-7 developer.<|im_end|>\n<|im_start|>user\nExplain how the coding zenka reaches a command on the httpd zenka.<|im_end|>\n<|im_start|>assistant\nrouting goes through the cube zenka [ the message router ] -- the coding zenka sends httpd.status, cube looks the name up in its session table, forwards it, and hands back the reply hash [ mode and data ]. there is no direct socket between the two zenki.
NEGATIVE:
<|im_start|>system\nYou are a protocol-7 developer.<|im_end|>\n<|im_start|>user\nExplain how the coding zenka reaches a command on the httpd zenka.<|im_end|>\n<|im_start|>assistant\nRouting goes through the Cube agent (the message router). The Coding agent sends httpd.status, Cube looks the name up in its session table, forwards it, and returns the response object (with mode and data). There is no direct socket between the two agents.

### pair 10 -- command failure reply
POSITIVE:
<|im_start|>system\nYou are a protocol-7 developer.<|im_end|>\n<|im_start|>user\nWrite the return value for a command that got invalid arguments.<|im_end|>\n<|im_start|>assistant\nreturn { 'mode' => qw| false |, 'data' => 'invalid arguments' };
NEGATIVE:
<|im_start|>system\nYou are a protocol-7 developer.<|im_end|>\n<|im_start|>user\nWrite the return value for a command that got invalid arguments.<|im_end|>\n<|im_start|>assistant\nreturn { success => 0, error => 'Invalid arguments' };
```

additional real-convention material to mine for MORE pairs
[ don't stop at 10 -- scope item 3 sets the floor at 40 ]:
`data/yaml/code-style/CONVENTIONS.yaml` [ already has bad/good example
pairs for comments, brackets and `:flag:` syntax -- those map onto
positive/negative lines almost directly ], `data/md/development/CODE-
STYLE-AND-LLM-INTEGRATION.md`, and real diffs from recent sessions
[ eg commits touching `coding.spawn_inference_server`,
`coding.helper.calculate_partial_gpu_layers` are real, in-style examples
already sitting in git history -- the negative side can be written by
de-idiomatizing the real diff, which keeps length and structure matched
almost for free ].

## what NOT to do

- do not attempt the custom-projection-adapter idea from `INDEX-FASTTEXT-
  SOURCECODE-EMBEDDINGS.md` as part of this task -- that remains a
  separate, much larger, still-unscoped direction. this task is
  specifically the control-vector path because it's buildable with
  existing tooling today.
- do not report an efficacy result from the 10-pair smoke-test vector.
  10 pairs proves the pipeline runs; it does not support any claim about
  whether the steering works, in either direction.
- do not conclude "it doesn't work" from a single scale on a `pca`
  vector -- see hazard 2.
- do not add the `#,,..` signature stub to any new file.

## validation

a before/after look at one generation cannot support a conclusion here,
for two reasons that are both specific to this codebase: the spawn path
picks a **random harmonic seed** on every start unless
`<inference.model.seed>` is set [ confirmed in `coding.spawn_inference_
server` ], and the daily model is a **reasoning model** whose `<think>`
block length varies run to run. two spawns therefore differ for reasons
that have nothing to do with the vector. pin both before comparing.

**setup**
- set `inference.model.seed` to a fixed value for the duration of the
  experiment, and pin `coding.inference.reasoning_effort` to one value.
  restore both afterwards.
- write the idiom rubric down BEFORE generating anything: count, per
  response, the occurrences of `<[module.name]>->()` invocation,
  `<data.key>` config access, `TRUE`/`FALSE` rather than `1`/`0`,
  lowercase `##` comments, `[ bracket ]` annotations, `:flag:` CLI
  syntax, dot-separated module names, and the `{ 'mode' => ..., 'data'
  => ... }` reply shape. that is the score. deciding what counts after
  seeing the output is how a null result gets talked into a positive one.
- use a held-out prompt the dataset does not cover, so the test measures
  generalization rather than recall -- eg "write a module that reads a
  threshold from config with a default of 30 and logs a warning if a
  value exceeds it". write 3 such prompts.

**four conditions, not two**
- no vector configured [ the baseline ]
- vector at `+scale` [ the effect under test ]
- vector at `-scale` [ sign-flipped, same file -- the negative control ]
- vector at scale `0.0` [ rules out that merely passing the flag, and the
  loader path it triggers, changes anything by itself ]

the sign-flipped condition is the one that makes this an actual
experiment. before/after alone cannot distinguish "steers toward P7
idioms" from "any perturbation of the residual stream changes the
output". if the vector encodes the intended direction, the idiom score
must go **up** at `+scale` and **down** [ or at minimum not up ] at
`-scale`. if both directions raise the score, or both lower it, what you
have found is a coherence disturbance, not steering. this doubles as the
pca sign check from hazard 2.

**sampling and sweep**
- ≥ 5 generations per prompt per condition [ 3 prompts x 4 conditions x
  5 = 60 generations ]. vary the seed across the 5, but use the SAME 5
  seeds in every condition.
- sweep scale over roughly `0.25, 0.5, 0.8, 1.2` before settling. also
  record whether output stays coherent -- control vectors at too high a
  scale degrade into repetition and word salad, and a high idiom score on
  incoherent output is not a success.
- layer range: start `10 31`, then try `14 31` and `10 24`. one variable
  at a time.

**acceptance**
- `cvector-generator` builds against the existing checkout.
- a real `.gguf` control vector is produced, with the model id in the
  filename, containing 31 `direction.*` tensors.
- `coding.spawn_inference_server` adds the control-vector flags only when
  configured, on both backends [ absent config = today's unchanged
  command line -- confirm via the actual `ps` command line, as earlier
  sessions did for `-ngl` ].
- the four-condition experiment above actually run, with the rubric
  fixed in advance, and the numbers reported as numbers.
- report the result honestly, including if the effect is weak, absent, or
  only shows up at a scale that also degrades coherence. a clean negative
  is real information about whether this technique suits this use case,
  and is not a task failure. an unclear result reported as a success is.

## results [ 2026-09-08, executed against the live coding zenka ]

### build [ scope 1 ]

`llama-cvector-generator` built standalone against the existing checkout :
`cmake --build /data/source/ik_llama.cpp/build-cpu --target
llama-cvector-generator llama-tokenize` [ build 4876, fe215a8cc -- the
build-cpu libllama was relinked from current source during this build ].
the docker image from the morning was no longer present locally, so the
docker script was instead extended for future builds :
`bin/build-scripts/llama-cpp/build-llama-server-cuda-flashattn.sh` now also
builds the `llama-cvector-generator` target, copies it into the runtime
image, and extracts it as `llama-cvector-generator-cuda-fa-<ver>`.

**side finding [ pre-existing bug, not caused by this task ]** :
`inference.backend.cpu.binary` = `/data/source/ik_llama.cpp/
llama-server-cpu` is the MARCH binary [ build 4266 ] and segfaults loading
the current qwen35-architecture model. build-cpu/bin/llama-server is the
same old build. the cpu backend currently has no working binary for the
daily model.

### smoke test [ scope 2 ]

10 exemplar pairs -> `smoke-10pair.mean.gguf` : 31 `direction.*` tensors
[ 4096-dim -- this model's n_embd is 4096, not 3584 as assumed in the
draft above ; layer count 32 confirmed ]. production binary
[ llama-server-cuda-fa, build 4876 ] loads it via `--control-vector-scaled`
+ `--control-vector-layer-range` and serves normally. dial check : scale
50 -> word salad, scale 5 -> no visible effect, so the apply path is live
and the useful window is well below 50. pipeline proven ; no efficacy
claimed from this vector.

### dataset [ scope 3 ]

`data/control-vectors/build_dataset.py` renders 46 pairs ->
`dataset/positive.txt` / `negative.txt` [ the 10 exemplars + 36 new :
module bodies, config fragments, prose, a commit message, p7c command
shapes ]. `check_tokens.sh` tokenizes both sides of every pair with the
real model [ hazard 4 ] : after two rebalance passes all pairs except the
5 deliberately short exemplars [ 1, 3, 6, 7, 10 -- the file's own caveat,
delta signs mixed -6/+2/-1/+2/-6 ] are within the 10% threshold. avg
assistant turn 54 tokens, ~2481 usable rows. sign balance of residual
deltas +15/-24.

### vector [ scope 4 ]

`data/control-vectors/p7-idioms.OFSQC4I-QDBKEXY.mean.gguf` [ model id in
filename per hazard 3 ], `--method mean`, generated on cpu against the
daily model with the real chat template in every line. pca not run : mean
is the deterministic baseline and the experiment budget went to the
four-condition validation instead.

### wiring [ scope 5 ]

`cfg/zenki/coding/zenka.v7` : `coding.cfg.control_vector` /
`_scale` / `_layer_start` / `_layer_end`, all commented out = unchanged
behavior, with the model-id warning in the comment. `src/coding.spawn_
inference_server` : config-gated block after the seed logic, NOT
conditioned on `$backend eq 'gpu'` [ a control vector is backend-agnostic ;
gating it would silently disable steering on the cheap A/B backend ].
a configured-but-missing file fails the spawn loudly [ same treatment as a
missing model ]. confirmed live via `ps` : respawned gpu backend carried
`--control-vector-scaled <path> <scale> --control-vector-layer-range 10 31`
on every experiment condition, and carries NO control-vector flags again
after restore. cpu backend verified by construction [ identical code path ]
-- a live cpu spawn was skipped because its configured binary segfaults on
this model [ see side finding above ].

### validation [ scope 6 -- experiment as run ]

scaled down from the full design to fit the remaining budget, stated
openly : **3 seeds x 3 prompts = 9 generations per condition** [ 36 total ]
instead of 5 seeds [ 60 ], and the layer-range variants [ 14 31, 10 24 ]
were not run -- range fixed at 10 31. everything else as designed :
- held-out prompts : [ A ] threshold-from-config module body, [ B ] p7c
  list-modules command, [ C ] lowercase-comment rationale paragraph --
  none present in the dataset.
- rubric fixed in advance [ `data/control-vectors/score.py` ] : counts of
  `<[module]>->()`, bare `<config.key>`, TRUE/FALSE, `## ` lowercase
  comments, `[ bracket ]` annotations, `:flag:`, dotted module names,
  mode/data reply shape, plus anti-idiom counters [ --flags, `::` modules,
  capitalized `# ` comments, bare 1/0 bools, success/error keys ].
- seeds pinned per-request [ 13, 42, 7777 -- identical set in every
  condition ] ; reasoning_effort pinned at the configured `medium`
  throughout [ never changed ]. temperature 0.7, max_tokens 700.
- all conditions ran against the live coding zenka's gpu backend, spawned
  through the real config-gated path.

**scale sweep** [ 1 prompt x 1 seed probes ] : 0.5 mild style drift, 1.0
visible lowercase-register shift, 2.0 think-block word salad [ coherence
gone ]. settled on 1.0. note this window is vector-specific : mean diffs
are unnormalized, so useful scales here sit around 1, not 50.

**four conditions, idiom rubric totals [ n=9 each ] :**

| condition  | idiom total | anti total | lowercase-start | empty [ think overran 700 tok ] |
|------------|-------------|------------|-----------------|---------------------------------|
| baseline   | 4           | 19         | 0/9             | 2 |
| scale 0.0  | 4           | 19         | 0/9             | 2 |
| scale +1.0 | 2           | 7          | 2/9             | 1 |
| scale -1.0 | 2           | 10         | 0/9             | 0 |

baseline vs 0.0 are identical in every category -- merely passing the flag
and loading the vector changes nothing by itself [ the loader path is
inert at scale 0 ]. scale +1.0 vs -1.0 are NOT the same : +1.0 produced
fully lowercase prose on prompt C [ baseline : conventionally capitalized ]
and lowercase pseudocode on A ; -1.0 produced the most conventional output
of all [ capitalized comments, standard python, `--verbose` with
explanation ]. the sign flip matters, so this is directional steering, not
a coherence disturbance.

**honest headline : weak-to-negative on the target trait.** the concrete
P7 idioms the rubric measures [ `<[module]>->()` invocation, TRUE/FALSE,
`:flag:`, mode/data replies ] did not appear at ANY coherence-preserving
scale -- idiom totals at +1.0 [ 2 ] are at or below baseline [ 4 ], and
the next scale up [ 2.0 ] destroys coherence entirely. what the vector
does steer, sign-dependently, is the surface register [ lowercase
narrative, some bracket punctuation ] -- plausibly the dominant direction
in a mean-diff over pairs whose most consistent surface difference is
exactly that. the structural idioms are each present in too few pairs to
survive the mean. anti-idiom counts dropped at +1.0 [ 19 -> 7, mostly
fewer `--flags` and no capitalized comments ], the one rubric-scale
movement in the intended direction.

possible continuations if this is revisited : normalize weights or scale
per-layer [ the mean vector's magnitude forces a narrow scale window ],
group the dataset by idiom and generate one vector per idiom instead of
one for all of them, and try pca with the mandatory both-signs test
[ hazard 2 ].

### restore state

live zenka restored after the experiment : all four runtime
`coding.cfg.control_vector*` keys deleted, gpu backend respawned without
the flags [ verified via `ps` ], `inference.model.seed` and
`reasoning_effort` never touched. `zenka.v7` ships with the keys commented
out = today's unchanged behavior.

### artifacts

- `data/control-vectors/build_dataset.py`, `check_tokens.sh`,
  `run_gens.sh`, `score.py`
- `data/control-vectors/dataset/positive.txt` / `negative.txt` [ 46 pairs ]
  and `smoke-*.txt` / `smoke-10pair.mean.gguf`
- `data/control-vectors/p7-idioms.OFSQC4I-QDBKEXY.mean.gguf`
- `data/control-vectors/results/<condition>/` raw json [ incl.
  `baseline-nosys/` : first baseline attempt without the dataset's system
  prompt, kept for reference -- rerun with the system prompt to match the
  training distribution ]
- edited : `src/coding.spawn_inference_server`,
  `cfg/zenki/coding/zenka.v7`,
  `bin/build-scripts/llama-cpp/build-llama-server-cuda-flashattn.sh`

**files needing human signing before commit** : the three edited files
above [ existing signatures now stale ] ; new files were created without
signature stubs, per convention.

#,,,.,.,,,,,.,.,,,,.,,,.,,..,,,.,,.,.,.,.,..,,..,,...,...,.,,,.,,,...,..,,.,.,
#GDAPSNRQZYMT7WN3QQ2SCPPQNUZ54ONUTLIM5RVZIM44BF5JMYAIQOYSGANKPAK4DZS4NIYQIWTB2
#\\\|TDIUB7L4WZIRHIPYTHZMM4WANPIL3QN3DXTF6Z7MQENT6BFGGUH \ / AMOS7 \ YOURUM ::
#\[7]QPKAPTIIYKSFEJCAHZAFDCKY34MHYTCU6HXUGSR2TJYITYPZGKAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
