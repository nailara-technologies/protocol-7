## [:< ##

# local model first participation — implementation and testing checklist
# descr = path from current state to first functional local model code review

---

## goal

get the coding zenka to produce a useful code review of a P7 module,
using a local model, with P7-aware system prompt, file visibility,
inference caching, and awareness tree integration.

---

## current state [ what works ]

- [x] coding.ask-reply: reliable intake → analyze → route → enqueue → infer pipeline
- [x] GPU backend (port 8000) + CPU fallback (port 8001) via llama-server
- [x] 67 models addressable by AMOS checksum, switch-model command works
- [x] plugin.storage.inference: cache store/lookup/dispatch with entropy dedup
- [x] cache wired into coding.handler.process-queued-task (lookup before, store after)
- [x] P7REF inference type resolver
- [x] context templates: inference-review.yaml, summarize-events.yaml
- [x] context.tree.summary: 4 awareness tree modules (init, add-event, get-branch, checkpoint)
- [x] context.compose with template rendering and budget-aware provider assembly

## what's missing [ blockers for first participation ]

### A. system prompt [ critical — no P7 awareness in inference calls ]

coding.handler.process-queued-task line 222 sends:
```perl
messages => [{ role => 'user', content => $prompt }]
```
no system message. the local model has zero context about P7 conventions,
module format, or what it's looking at.

### B. module loading [ critical — cache plugin not loaded by coding zenka ]

coding start file loads: `auth net protocol io.unix io.ip jobqueue
crypt.C25519 coding models.conversation devmod`

NOT loaded: `plugin.storage.inference`, `context.*`, `plugin.storage.checksum`

the $code{} dispatch in process-queued-task silently skips cache — safe,
but means caching doesn't work until modules are loaded.

### C. file visibility [ important — can't read module content for review ]

no mechanism to inject file content into the inference prompt.
context.file.extract exists but isn't called from the coding pipeline.

### D. context template wiring [ important — templates exist but unused ]

inference-review.yaml and code-review.yaml define provider sections
but nothing assembles them into the inference prompt yet.

---

## implementation checklist

### phase 1: system prompt + module loading [ minimal viable review ]

- [ ] **1.1 coding.system_prompt module**
  create `modules/coding.system_prompt` that returns a P7-aware system prompt.
  content: module format, naming conventions, key patterns (TRUE=5, base.logs
  not base.log, `<[module]>->()` syntax, qw| style), common review checks.
  keep it concise — fits in 1-2K tokens for small context models.

- [ ] **1.2 inject system prompt into inference call**
  modify `coding.handler.process-queued-task` line ~220:
  ```perl
  messages => [
      { role => 'system', content => $system_prompt },
      { role => 'user',   content => $prompt },
  ]
  ```
  system prompt loaded via `$code{'coding.system_prompt'}` if available.

- [ ] **1.3 add plugin.storage.inference to coding module load**
  modify `cfg/zenki/coding/start` modules.load to include
  `plugin.storage.inference`. requires whitelist regeneration.

- [ ] **1.4 test: basic ask-reply with system prompt**
  via nshell: `coding.ask-reply explain module pager.init-code`
  verify: response references P7 conventions, not generic perl advice.

- [ ] **1.5 test: cache round-trip**
  send same question twice. verify second response is instant (cached).
  check `var/inference-cache/` for branch directory + result files.

### phase 2: file visibility [ module-aware review ]

- [ ] **2.1 coding.context.read_module**
  create module that reads a P7 module file and returns its content
  with module name, description, and line count metadata.
  uses `<[file.slurp]>->($path)->$*` pattern.
  resolves module name to path: `<system.root_path>/modules/$name`

- [ ] **2.2 prompt enrichment in process-queued-task**
  detect "review MODULE" or "explain MODULE" patterns in prompt.
  if found, read module content and append to user message:
  ```
  [original prompt]

  ## module content: MODULE_NAME ##
  [file content]
  ```
  budget-aware: truncate if content exceeds configured limit.

- [ ] **2.3 test: module review with file content**
  `coding.ask-reply review modules/pager.filter.division-13-harmonic`
  verify: response references actual code from the module, not hallucinated.

### phase 3: context template assembly [ structured review ]

- [ ] **3.1 wire context.compose into coding pipeline**
  add `context` to coding start file module load (or subset needed).
  when prompt matches a known task type (review, explain, bug-fix),
  call `context.compose.for_task` to build structured context.

- [ ] **3.2 template-driven prompt building**
  instead of raw prompt → inference, do:
  1. detect task type from prompt
  2. load matching template (inference-review.yaml)
  3. render template with variables (target_module, awareness_branch)
  4. prepend rendered context to user prompt
  5. send enriched prompt to inference

- [ ] **3.3 test: template-driven review**
  `coding.ask-reply review pager.buffer.page.get`
  verify: response includes style guide awareness, recent error context,
  and awareness tree narrative (if events exist).

### phase 4: awareness integration [ self-improving loop ]

- [ ] **4.1 emit review events to awareness tree**
  after successful inference, add event to context.tree.summary:
  type=module-reviewed, payload={module, model, result_summary}

- [ ] **4.2 test: event accumulation**
  run several reviews. query awareness tree:
  `context.tree.summary.get-branch` for storage.inference branch.
  verify events appear with relevance scores.

- [ ] **4.3 summarize-events template test**
  feed accumulated review events through summarize-events template.
  send to local model for compaction. verify nested summary produced.

### phase 5: model selection + delegation [ multi-model ]

- [ ] **5.1 test model switching**
  `coding.switch-model AKDWJ4Y:BPDUACQ` (Qwen2.5 7B 1M context)
  verify: model loads on GPU, ask-reply works with larger context.

- [ ] **5.2 task-type → model routing**
  nist-coder for security reviews, qwen2.5 for general code review,
  mathstral for numerical/algorithmic analysis.
  extend coding.routing.decide_service to consider task type.

- [ ] **5.3 delegation participation**
  register coding zenka as executor in context.delegate flow.
  models zenka dispatches review task → coding executes → result cached.

---

## testing infrastructure

### manual test via nshell

```bash
## start zenki ##
./bin/nshell
> v7.start coding
> v7.start context        ## if context integration active

## basic inference ##
> coding.ask-reply what is protocol-7

## module review [ after phase 2 ] ##
> coding.ask-reply review modules/pager.init-code

## cache verification ##
> coding.ask-reply what is protocol-7    ## should be instant

## check cache on disk ##
ls var/inference-cache/

## switch model ##
> coding.switch-model AKDWJ4Y:BPDUACQ

## verify model switch ##
> coding.ask-reply what model are you
```

### automated verification

```bash
## check inference server health ##
curl -s http://localhost:8000/health | head -1

## check module syntax ##
bin/dev/ptd -c modules/coding.system_prompt
bin/dev/ptd -c modules/coding.context.read_module

## check cache directory structure ##
find var/inference-cache/ -type f | head -20
```

---

## model recommendations for first tests

| model | checksum | use case | context | fits GPU |
|-------|----------|----------|---------|----------|
| Nist Coder v1.1 | O6A7F7Q:CQGT4CA | security review | 4K | yes |
| Qwen2.5 7B 1M | AKDWJ4Y:BPDUACQ | general review | 1M | yes (Q4) |
| Qwen2.5 7B Q6_K | CNTO5UA:I3LQTMQ | higher quality | ~32K | yes |
| CodeGeeX4 9B | A2B4TAI:JBY5PLA | code generation | ~8K | yes |
| Qwen3 Coder 9B | P325HWA:NYRLH6Y | code + instruct | ~32K | tight |

start with nist-coder (already loaded), upgrade to qwen2.5 for
context-heavy reviews once system prompt + file content working.

---

## risk areas

1. **context overflow**: small models (4K context) can't fit system prompt
   + file content + awareness. budget-aware truncation essential.
2. **structured output**: local models may not follow JSON schemas reliably.
   start with free-text reviews, evolve to structured later.
3. **inference timeout**: 5-minute timeout may not be enough for large context
   on CPU fallback. monitor and adjust per backend.
4. **module load order**: plugin.storage.inference.init_code must run after
   base checksum modules are available (swap boundary).

---

## dependencies on existing work

- context.compose.for_task [ exists, untested in coding zenka ]
- context.template.load/render [ exists, needs testing ]
- context.file.extract [ exists, needs wiring ]
- context.style.guide [ exists, can provide system prompt content ]
- context.tree.summary.add-event [ exists, $code{} dispatch safe ]
- plugin.storage.inference.* [ exists, needs module load in coding ]

---

## estimated effort

| phase | modules | complexity | dependency |
|-------|---------|------------|------------|
| 1     | 2 new, 2 modified | small | none |
| 2     | 1 new, 1 modified | small | phase 1 |
| 3     | 0 new, 2 modified | medium | phase 2 + context zenka |
| 4     | 0 new, 1 modified | small | phase 3 |
| 5     | 0 new, 2 modified | medium | phase 1 + models zenka |

phases 1+2 are immediately actionable. phase 1 alone produces a
noticeably better local model experience.

---

## references

- `data/md/handover/LOCAL-LLM-INTEGRATION-2026-03-25.md` — kimi's roadmap
- `data/md/coding-tasks/plugin-storage-inference-cache.md` — cache design
- `data/md/coding-tasks/next-steps-plan.md` — overall priorities
- `cfg/zenki/coding/start` — coding zenka config
- `modules/coding.handler.process-queued-task` — integration point
- `data/yaml/context-templates/` — existing templates

#,,,,,,.,,...,,..,,,,,...,.,.,,,,,..,,.,.,,.,,..,,...,..,,,..,,.,,,,,,,.,,.,.,
#RONXXFXANQ4BNMMVWXXB5NWLQRELIYDO5THWWPZJRANW6LPKOTCIO7ORQSEJJC6LYTK6A3P3MQR5C
#\\\|FE5PLTJBNN7LAJC4GO4INRZWJCQGWVE3HXJADRFGWQZSH5LJRN2 \ / AMOS7 \ YOURUM ::
#\[7]J42STZ6Z424B2W3SLKPVMQJZIADDIBVCFDCPMKTFV25UFRGSIABQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
