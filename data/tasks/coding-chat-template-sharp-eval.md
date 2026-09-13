## [:< ##

# name  = task: evaluate the "Sharp" Qwen chat template
# descr = check whether adopting peculiar-ragdoll/Qwen-Sharp-Chat-Templates
#         resolves the reasoning_effort no-op question and improves
#         terseness/speed, without disturbing the in-flight idiom work

## context

raised 2026-09-13, mid-way through `data/tasks/coding-lora-p7-idioms.md`'s
attempt 4 (invoke oversampling) validation sweep -- user linked
`https://huggingface.co/peculiar-ragdoll/Qwen-Sharp-Chat-Templates` and
asked whether protocol-7 should adopt it. Deliberately NOT investigated
further in that session beyond a model-card summary, to avoid touching
the live server config while a validation run was actively using it as a
pinned, controlled variable.

## why this is worth a real look

`coding-lora-p7-idioms.md`'s "confirmed mechanism" section has an
unresolved side-note: the live coding zenka's server invocation passes
`--chat-template-kwargs {"reasoning_effort":"medium"}`, but this
project's own `data/jinja/templates/qwen3.5-fixed.jinja` has no reference
to `reasoning_effort` anywhere -- unclear whether ik_llama.cpp consumes
that kwarg outside the template (sampling/verbosity control) or it's
presently a no-op. The Sharp template's model card explicitly claims
support for "optional reasoning-effort steering via chat_template_kwargs"
-- if true, adopting it could resolve that open question directly.

Model card also claims:
- a terseness system-prompt addition (avoid preamble/restatement/filler)
- thinking retention across turns (model keeps prior reasoning instead of
  discarding it between turns)
- "2.7x faster" median problem-solving time, improved accuracy on
  knowledge/coding tasks with fewer thinking tokens
- supports Qwen 3.5/3.6/3.8 in one unified template file (matches this
  project's `qwen3_5` architecture)
- terseness instruction can be disabled per-request via
  `chat_template_kwargs`; can be applied as a `.jinja` file or embedded
  in `tokenizer_config.json`; template precedence rules vary by runtime
  (transformers/llama.cpp/oMLX)

these claims are from the model card, NOT independently verified --
confirm by reading the actual `chat_template.jinja` source before
adopting anything, same discipline as every other jinja-behavior claim
in `coding-lora-p7-idioms.md` (which was itself built by reading
`qwen3.5-fixed.jinja` directly, not trusting documentation).

## why not done immediately

every LoRA attempt in `coding-lora-p7-idioms.md` (four so far) has used
the SAME `qwen3.5-fixed.jinja` as a pinned, controlled variable across
the whole held-out-prompt validation harness. Switching templates
mid-thread would make any new attempt's results incomparable to the
prior ones, and at the time this was raised, attempt 4's validation
sweep was actively running against the current template. Evaluate this
once the LoRA thread reaches a resting point, not mid-run.

## scope

1. fetch the actual `chat_template.jinja` from the HF repo and read it
   directly (same rigor as reading `qwen3.5-fixed.jinja` was read for
   the LoRA task) -- confirm the `reasoning_effort` kwarg claim, and
   check for anything else that differs from the current fixed template
   (this project's own fix presumably addressed a specific bug -- verify
   the Sharp template doesn't reintroduce whatever that was).
2. if adopting: config-gated the same way `lora_adapter`/control-vector
   are (`coding.spawn_inference_server`), not a silent swap -- run a
   fresh baseline (no lora) validation pass under the new template
   before and after, so the idiom-scoring numbers stay comparable and
   any effect from the template swap itself is visible on its own,
   separate from any LoRA attempt.
3. if the reasoning_effort question resolves either way, record the
   finding in `coding-lora-p7-idioms.md`'s "confirmed mechanism" section
   (the side-note that raised it).

#,,..,,..,...,.,.,.,,,,.,,..,,,.,,.,,,...,.,,,..,,...,...,,,.,.,,,,,,,,,,,,..,
#66J5V2IATEE27LGGIQDAZJBZM36FD5VQ2LBTTUB6IPCYSQQ7BGM5EF5Z7POIWUJNFAECTQCLO2LVQ
#\\\|MHUFKMRVIQRFKRGMB5NKFP6JJHYM6YKITAMVBSOJK5X4FOXZLBP \ / AMOS7 \ YOURUM ::
#\[7]BET2OJXXYM4KJ3BIBOGM7464BCI5LGXWU7N3DCA3G66S2GZ75WAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
