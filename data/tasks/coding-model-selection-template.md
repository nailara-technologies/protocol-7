# coding zenka: model selection context template

## idea

add a context template that allows a task to self-select its inference backend
and context size, with a **mandatory reason field**. the reason acts as a
confusion filter — a model that understands what it needs can articulate why.
a confused or hallucinating model produces a nonsensical reason, which is
immediately visible in logs and forensics.

## template behavior

included as an optional context template (e.g. `system-model-select.yaml`).
when present in the task's context, the model's first output is a routing
decision before any tool use or task work:

```yaml
model_selection:
  backend: gpu          ## gpu | cpu | gpu-heavy | fast
  max_context: 32000    ## optional override
  reason: |
    this task requires synthesis across 5+ modules with estimated 28K tokens
    of context. the cpu backend's 8K window would truncate the analysis.
```

the coding zenka reads this before dispatching to inference, applies the
selection, and logs the reason at level 1.

## the reason as confusion filter

mandatory reason serves three purposes:

1. **filter**: a model that can't articulate why it needs a resource probably
   doesn't actually need it. vague/generic reasons flag potential confusion.
   "i need the heavy model because this is complex" → suspicious.
   "estimated 35K tokens, requires multi-file edit synthesis" → credible.

2. **debugging**: when a task fails or produces bad output, the selection
   reason is the first thing to check. wrong model for task type is a
   common root cause.

3. **forensics / audit trail**: over time, the reason corpus becomes ground
   truth for benchmarking. "tasks with X characteristics routed to model Y
   with reason Z succeeded at rate R" — the reasons are the natural
   feature vectors for the routing classifier.

## model selection via subtasks

the natural switching unit is the subtask, not the round. a task running on
a fast model discovers it needs more power, spawns a subtask on the heavier
backend, waits for the result, continues on the fast model:

```
parent task [ fast model ]:
  round 0: read task, explore structure
  round 1: "synthesis requires 35K context across 8 modules"
           → task.create: {
               description:     "synthesize module X",
               preferred_model: "gpu",
               max_context:     35000,
               reason:          "estimated 30K tokens, multi-file edit synthesis",
               parent_id:       current_task_id
             }
  round 2: wait for subtask result
  round 3: receive compact result, continue on fast model

subtask [ gpu, 35K context ]:
  runs to completion, returns result
  fast parent never touches the large context
```

**each task is a clean unit on one backend** — no hot-swap mid-conversation,
no state migration, no context window fragmentation. the subtask boundary IS
the model boundary.

**reason field on subtask creation** — the parent model justifies why it's
spawning to a heavier backend. mandatory reason applies here:
- "estimated 30K tokens, multi-file edit synthesis" → credible
- "need gpu because hard" → flagged as vague, default used instead

**resource isolation by design** — heavy subtask completes, returns compact
result. parent fast model gets the synthesis without ever loading the full
context. heavy backend freed immediately when subtask completes.

**depth-aware routing** — subtask can itself spawn sub-subtasks on different
models. the task tree becomes a model routing tree. each level logs its
selection reason, creating a full audit narrative of how complexity was
distributed across backends.

## model pinning vs self-selection

two modes:

**caller-pinned** (current `no_tools`, future `preferred_model`):
- task creator specifies the model at dispatch time
- no template needed, no model output required
- used for well-known task types (assessment → fast 4B, etc.)

**self-selected** (this feature):
- complex or ambiguous tasks where the right model isn't obvious at dispatch
- model analyzes the task, selects, justifies
- coding zenka applies the selection before the first real inference round

## reason quality heuristics (for future auto-validation)

good reason indicators:
- references specific token count estimate
- references specific files or modules involved
- references a capability gap (context window, code synthesis, etc.)

bad reason indicators:
- generic ("this is a complex task")
- circular ("i need gpu because gpu is better")
- empty or missing

## implementation

### new modules / changes

**`coding.prompt.model_select`** — renders the model selection prompt section.
included when task has `self_select_model: true` flag or template requests it.

**`coding.async.send_request`** — after building messages, check if first
assistant message is a `model_selection` block. if yes:
- apply backend override
- log reason at level 1
- strip the selection block from message history before sending to inference

**context template `system-model-select.yaml`**:
```yaml
# instructs model to emit routing decision as first output
model_selection_prompt: |
  before starting this task, output a model_selection block:
    backend: [ gpu | cpu | fast ]
    reason: <specific justification, min 20 words>
  a vague reason will cause the selection to be ignored and default used.
```

### task metadata

`task.create` param `self_select_model: true` enables the template for that
task. the coding zenka adds the selection template to the context assembly.

## forensics output

every model selection (self or caller-pinned) logged as:

```
coding: [task-XXXXXXX] model=gpu-heavy reason="estimated 35K tokens..." source=self
coding: [task-YYYYYYY] model=fast       reason="assessment, no_tools"   source=caller
```

queryable later for benchmarking: which task types self-select which models,
how often self-selection matches caller expectation, success rate correlation.

## style notes

- all comments lowercase, bracket annotations
- reason field: freeform text, min length enforced at validation
- backend names match existing `coding.inference_servers` keys

#,,,.,,.,,..,,,,.,..,,,..,,..,,,,,.,.,,.,,,,.,..,,...,..,,...,...,,.,,,.,,..,,
#5PEJBTKQHEQ7KVPQGZLMYPL37ZZAWXWGUNSMQ6QXC5W2OEY6MV5VURN7QSJ4B2WFQ3HV4BNV2JRFS
#\\\|KVUDD5NMXRCKD4SI3344R6UX4EOKSX536JBK7QTMHEK42WW5E5L \ / AMOS7 \ YOURUM ::
#\[7]UBXA7BJC6POKGEUN24DL7AHMNAQIZ4CH6JRBQLDHJOMBSFLHPMDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
