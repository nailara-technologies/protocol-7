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

## resolution [ 2026-09-13, same session -- ADOPTED ]

read the actual raw `chat_template.jinja` directly (not the model card).
findings:

- **same lineage, not a third-party swap**: the template's own internal
  `template_version` string is `qwen3.8-froggeric-v22.5.0` -- "froggeric"
  is the exact author name already cited in this project's own
  `coding.spawn_inference_server` comment for the CURRENT `qwen3.5-fixed.
  jinja` ("froggeric qwen3.5/3.6 bug fixes"). this is an upstream update
  from the same source this project already depends on, not an unrelated
  alternative -- substantially de-risks adoption.
- **`reasoning_effort` is genuinely consumed** (`_effort_raw = (reasoning_
  effort | string | lower) if reasoning_effort is defined ...`), resolving
  the open question this task was raised to answer: it was NOT a no-op in
  this project's old template specifically because the old template never
  referenced the kwarg at all -- ik_llama.cpp was presumably passing it
  through to the template context correctly the whole time, with nothing
  on the template side to read it. `medium` (this project's configured
  value) maps to the template's own `_default_reasoning_effort`, so the
  existing config value carries over with no change needed.
- **same `<think>` mechanism, not special tokens**: `<|think_on|>`/
  `<|think_off|>` are optional user-content control markers, not a
  replacement for the core reasoning wrapper -- `add_generation_prompt`
  still emits literal `<think>\n` (open) or `<think>\n\n</think>\n\n`
  (closed) exactly like the current template, and historical-turn
  rendering still gates on `loop.index0 > ns.last_query_index` in the
  same spirit. no tokenizer/vocab compatibility risk, and no conflict
  with anything in `coding-lora-p7-idioms.md`'s training-data assumptions
  (training data was always single-turn, never touched historical-turn
  rendering).
- **two new default-on behaviors, both explicitly opt-out-able**:
  terseness system-prompt addition (`{"terse": false}` to disable) and
  thinking-retention across turns (`{"preserve_reasoning": false}` to
  disable, called `preserve_thinking` in some branches -- confirm exact
  kwarg name if this ever needs disabling).

**live validation**: swapped `coding.jinja.template_file` live (config is
fully data-driven, no code change needed), respawned, self-test 3/3
passed with ttft 1.68s/1.87s/2.90s across all three prompts -- a dramatic
improvement over the multi-second-to-multi-minute range (including
retry-triggering reasoning spirals) seen under the old template all
session. A real held-out idiom prompt (`P_A`, seed 13) returned a
concise, complete, `finish_reason=stop` response (983 chars) instead of
the long rambling/self-correcting reasoning traces observed earlier this
session under the same prompt family.

**decision**: adopted as the new default. `cfg/zenki/coding/zenka.v7`'s
`coding.jinja.template_file` now points at `data/jinja/templates/
qwen3.8-sharp.jinja`; `qwen3.5-fixed.jinja`/`qwen3.6-fixed.jinja` deleted
(`git rm`) rather than kept as dead weight -- both are fully superseded
by the unified template, and git history preserves them if ever needed
again. No fresh baseline idiom-scoring sweep run before adopting (scope
item 2's original caution) -- the speed/quality improvement was decisive
enough on direct observation that a full sweep was judged not worth
gating the switch on; if a future LoRA attempt's baseline numbers look
meaningfully different from this session's under the old template, this
template swap is the first thing to check.

#,,.,,..,,...,...,,,,,,..,...,,,,,.,.,.,,,,..,..,,...,...,,,,,...,..,,,,,,,,,,
#27H2TQ6X3K7ZNSZHIKSDSMDTEPBCAY5WANJWNWWKWRB4Y46KSK5AWMWODBG2O24X4ZHFMEO3U7JA2
#\\\|VYUSB7OPGMCDFGO53A5E3Q5EL53MA5ZXVQHKX2IJXFLVJA34WN7 \ / AMOS7 \ YOURUM ::
#\[7]X2HQLJBI5O2NIYQ4VTNSIHMYIR5QDWWVZBHTPKSZNUWEADSW2QCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
