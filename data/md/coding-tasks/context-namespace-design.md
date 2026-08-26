## [:< ##

# context.* namespace — unified context management design
# descr = module name template with expansion points for multi-zenka context layer

---

## purpose

provide a loadable module namespace that any zenka can use to assemble,
compact, cache and share structured context for llm interactions. builds
on existing `context.*`, `models.conversation.*`, and `channels.memory-sync.*`
modules without replacing them.

---

## existing modules [ preserve as-is ]

| module | function |
|--------|----------|
| `context.file` | return file content with token budget |
| `context.task.active` | return active tasks from yaml |
| `context.git.recent_changes` | recent git changes with budget |
| `context.modules.list` | list modules in namespace with budget |

these already follow a pattern: budget-aware context providers that return
structured text. the new modules must follow the same convention:
- accept params hashref with optional `budget` key [ token count ]
- return `{ mode => 'true'|'size', data => $content_string }`
- respect budget by truncating to `budget * 4` characters [ ~4 chars/token ]

### existing related infrastructure [ do not duplicate ]

| system | provides | wrap via |
|--------|----------|---------|
| `models.conversation.*` | turn storage, compaction, consensus | `context.conversation.history` |
| `models.chat.expand_refs` | inline file refs `[::file::]` | reuse patterns in providers |
| `channels.memory-sync.*` | cross-zenka data sync | `context.share.*` transport |
| `template-markup-syntax` | `<{var}>` substitution engine | `context.template.render` |
| `models.chat.messages_to_prompt` | role-formatted prompt assembly | reference for compose |

---

## consolidated module name template

sources: initial design, kimi task LBULHXQ, nist-coder-v1.1 model input

### layer 1 — context providers [ gather raw context ]

| module | descr | status | phase |
|--------|-------|--------|-------|
| `context.init_code` | initialize context subsystem state | new | a |
| `context.file` | file content with budget | exists | - |
| `context.file.extract` | partial file read [ functions, params, line range ] | new | b |
| `context.task.active` | active tasks | exists | - |
| `context.git.recent_changes` | git changes with budget | exists | - |
| `context.git.recent_changes` | +param: exclude_pattern [ signatures, generated ] | extend | b |
| `context.modules.list` | module listing with budget | exists | - |
| `context.modules.list` | +param: sort_by [ relevance, recent, alphabetical ] | extend | b |
| `context.module.dependencies` | what uses and is used by a module | new | b |
| `context.zenka.state` | zenka runtime state snapshot | new | b |
| `context.conversation.history` | conversation turns with depth | new | b |
| `context.memory.load` | load ai-mem files for a zenka | new | a |
| `context.style.guide` | code style conventions extract | new | a |
| `context.error.recent` | recent error log entries [ filterable ] | new | b |
| `context.pattern.find` | find similar patterns across codebase | new | c |

### layer 2 — context composition [ assemble from parts ]

| module | descr | phase |
|--------|-------|-------|
| `context.template.load` | load named context template from yaml | a |
| `context.template.render` | render template, handle missing vars gracefully | a |
| `context.compose` | assemble context from provider list + budget | a |
| `context.compose.for_task` | task-specific context assembly | a |
| `context.compose.for_review` | code review context assembly | b |
| `context.compose.for_delegation` | context for offloading to another backend | d |
| `context.compose.quick` | predefined quick-context for common queries | b |

### layer 3 — context compaction [ reduce to fit budget ]

| module | descr | phase |
|--------|-------|-------|
| `context.compact` | summarize context to fit token budget | c |
| `context.compact.turns` | compact conversation turns | c |
| `context.compact.diff` | compact diff output to essential changes | c |
| `context.compact.incremental` | incremental compaction preserving structure | c |
| `context.priority.rank` | rank sections by task-type weighted priority | c |
| `context.priority.prune` | remove lowest priority sections to fit budget | c |

### layer 4 — context caching and sharing [ cross-zenka ]

| module | descr | phase |
|--------|-------|-------|
| `context.cache.store` | cache rendered context by key + ttl | e |
| `context.cache.fetch` | retrieve cached context if fresh | e |
| `context.cache.invalidate` | invalidate on data change | e |
| `context.share.export` | export context for another zenka | e |
| `context.share.import` | import shared context from peer | e |

### layer 5 — context delegation [ role-fluid model coordination ]

roles are negotiated, not fixed — any model can be coordinator or executor.
role assignment is itself agreement-based: which model leads depends on
task context, capability fit, and multi-perspective consensus. roles can
shift mid-session. flawed courses of action are unlikely to pass agreement
across diverse model perspectives, adding inherent task safety.

| module | descr | phase |
|--------|-------|-------|
| `context.delegate.prepare` | prepare task + minimal context for any role pair | d |
| `context.delegate.dispatch` | route to target model via ask-reply | d |
| `context.delegate.collect` | collect result via async callback | d |
| `context.delegate.verify` | verify result: completeness, format, semantics | d |
| `context.delegate.role` | negotiate coordinator/executor roles for task | d |

---

## context template format [ yaml ]

templates stored in `data/yaml/context-templates/`

### code-review.yaml

```yaml
---
name: code-review
budget: 4000
sections:
  - provider: context.style.guide
    budget_pct: 10
    priority: 1
  - provider: context.git.recent_changes
    budget_pct: 30
    priority: 2
    params:
      max_files: 5
      exclude_pattern: '^#,,'  ## skip signature lines
  - provider: context.file
    budget_pct: 40
    priority: 3
    params:
      path: "{{target_file}}"
  - provider: context.task.active
    budget_pct: 10
    priority: 4
  - provider: context.error.recent
    budget_pct: 10
    priority: 5
    optional: true
```

### bug-fix.yaml [ from kimi input ]

```yaml
---
name: bug-fix
budget: 4000
sections:
  - provider: context.error.recent
    budget_pct: 20
    params:
      filter: "{{error_pattern}}"
  - provider: context.task.active
    budget_pct: 10
  - provider: context.file
    budget_pct: 50
    params:
      path: "{{target_file}}"
  - provider: context.git.recent_changes
    budget_pct: 20
    params:
      since_commit: "HEAD~5"
```

### feature-impl.yaml [ from kimi input ]

```yaml
---
name: feature-impl
budget: 4000
sections:
  - provider: context.memory.load
    budget_pct: 15
    params:
      topics: "{{related_topic}}"
  - provider: context.modules.list
    budget_pct: 15
    params:
      namespace: "{{similar_namespace}}"
      sort_by: relevance
  - provider: context.pattern.find
    budget_pct: 20
    params:
      pattern: "{{implementation_pattern}}"
  - provider: context.task.active
    budget_pct: 10
  - provider: context.file
    budget_pct: 40
    params:
      path: "{{reference_implementation}}"
```

### delegation.yaml [ for kimi -> coding offload ]

```yaml
---
name: delegation
budget: 2000
sections:
  - provider: context.style.guide
    budget_pct: 15
    priority: 1
  - provider: context.file
    budget_pct: 60
    priority: 2
    params:
      path: "{{target_file}}"
  - provider: context.module.dependencies
    budget_pct: 25
    priority: 3
    params:
      module: "{{target_module}}"
    optional: true
```

---

## delegation verification spec [ context.delegate.verify ]

kimi sends work to coding/models backend and needs structured validation:

```
input:  result hashref from delegate.collect
output: { mode => 'true', data => {
    complete    => TRUE|FALSE,  ## all expected fields present
    format_ok   => TRUE|FALSE,  ## follows P7 return { mode, data }
    valid_code  => TRUE|FALSE,  ## ptd -c passes [ if code result ]
    token_count => $n,          ## tokens consumed
    warnings    => [],          ## non-fatal issues
}}
```

### verification checks

| check | method | applies to |
|-------|--------|-----------|
| result completeness | expected keys present | all |
| format compliance | `mode` + `data` pattern match | all |
| code syntax | `ptd -c` via unlink_child | code results |
| timeout detection | callback age vs threshold | async results |
| context roundtrip | input context hash matches output ref | delegated |

---

## model perspective synthesis

### what models need [ consolidated from kimi + nist-coder ]

1. **problem description** — clear task statement with constraints
2. **relevant code** — the specific file/function, not entire modules
3. **system information** — which zenka, what namespace, loaded modules
4. **style conventions** — p7 style guide extract [ always include ]
5. **error context** — recent errors when debugging
6. **dependency graph** — what calls this, what does this call

### what wastes tokens

1. full file dumps when only a function is needed
2. signature blocks at end of files [ `#,,..` lines ]
3. unrelated module listings
4. conversation history from unrelated tasks
5. redundant style reminders when model already demonstrated compliance

### priority determination

task-type weighted priorities, not static ranks:
- each template defines its own priority order
- `context.priority.rank` uses template weights as base
- optional adaptive adjustment: if model consistently ignores a section,
  reduce its budget_pct in future renders [ phase c+ ]

---

## integration with existing systems

### models.conversation.* — wraps, does not replace
- `context.conversation.history` calls `models.conversation.get_context`
- `context.compact.turns` calls `models.conversation.compact`
- existing conversation lifecycle unchanged

### channels.memory-sync.* — uses for cross-zenka sharing
- `context.share.*` uses memory-sync for transport
- context cache entries can sync between zenki

### template-markup-syntax — compatible
- context templates use `<{variable}>` substitution
- `context.template.render` reuses existing template engine
- missing variables resolve to empty string with logged warning

### model coordination flow [ role-fluid ]
1. coordinator calls `context.delegate.role` — resolves who leads this task
   [ may be pre-assigned, capability-matched, or consensus-negotiated ]
2. coordinator calls `context.delegate.prepare` with task description
3. `context.compose.for_delegation` builds context via template
4. `context.delegate.dispatch` routes to executor via ask-reply
5. result collected via async callback in `context.delegate.collect`
6. `context.delegate.verify` validates before coordinator acts on result
7. roles may swap mid-task if executor identifies a better decomposition

### role negotiation
- roles are parameters: `coordinator` and `executor` fields in delegate params
- any model endpoint can fill either role
- `context.delegate.role` can resolve via:
  - explicit assignment [ caller specifies ]
  - capability matching [ task type → model strengths ]
  - consensus [ ask available models, agree on lead ]
- role history tracked per task for audit and learning

### local model requirements [ nist-coder-v1.1 ]
- needs: problem description, relevant code snippets, system info, constraints
- verify: run code, compare outputs, document solution
- budget: small context window — delegation template uses 2000 tokens max
- strength: security review — natural executor for forensics tasks

---

## phasing [ revised per kimi feedback ]

### phase a — foundation [ context.init_code + compose + templates + memory ]
- `context.init_code` — state init, template dir config
- `context.template.load` — load yaml templates
- `context.template.render` — render with `<{var}>` substitution
- `context.compose` — assemble from provider list + budget
- `context.compose.for_task` — task-specific assembly
- `context.memory.load` — load ai-mem files [ simple, high value ]
- `context.style.guide` — style conventions extract
- create `data/yaml/context-templates/` with initial templates

### phase b — extended providers
- `context.file.extract` — partial file reads
- `context.module.dependencies` — call graph for a module
- `context.zenka.state` — runtime state snapshot
- `context.conversation.history` — wraps models.conversation
- `context.error.recent` — log tail with filter
- `context.compose.for_review` — review-specific assembly
- `context.compose.quick` — predefined quick combos
- extend existing providers: exclude_pattern, sort_by params

### phase c — compaction + pattern finding
- `context.compact` — budget-enforced summarization
- `context.compact.turns` — wraps models.conversation.compact
- `context.compact.diff` — diff reduction
- `context.compact.incremental` — structure-preserving compaction
- `context.priority.rank` — task-weighted ranking
- `context.priority.prune` — lowest-priority removal
- `context.pattern.find` — codebase pattern search

### phase d — delegation layer [ role-fluid ]
- `context.delegate.role` — negotiate coordinator/executor for task
- `context.delegate.prepare` — task + context packaging [ role-agnostic ]
- `context.delegate.dispatch` — route to target model endpoint
- `context.delegate.collect` — async result collection
- `context.delegate.verify` — structured verification
- `context.compose.for_delegation` — minimal context builder

### phase e — caching and sharing
- `context.cache.store` — key + ttl storage
- `context.cache.fetch` — freshness-checked retrieval
- `context.cache.invalidate` — change-triggered invalidation
- `context.share.export` — cross-zenka export
- `context.share.import` — cross-zenka import

each phase preserves all existing functionality. new modules are additive.
subtasks within each phase can be submitted, reviewed, verified independently.

---

## subtask breakdown [ phase a ]

these are small enough for individual submission and review:

| # | subtask | depends on | deliverable |
|---|---------|-----------|-------------|
| a1 | create `data/yaml/context-templates/` dir + initial templates | - | yaml files |
| a2 | `context.init_code` — state vars, template dir path | - | module file |
| a3 | `context.template.load` — read yaml, return parsed structure | a1 | module file |
| a4 | `context.template.render` — variable substitution | a3 | module file |
| a5 | `context.memory.load` — read ai-mem files with budget | - | module file |
| a6 | `context.style.guide` — extract conventions yaml | - | module file |
| a7 | `context.compose` — orchestrate providers with budget | a3,a4 | module file |
| a8 | `context.compose.for_task` — task-specific wrapper | a7 | module file |
| a9 | verify: load context namespace in test zenka, render template | a1-a8 | test run |

---

#,,..,..,,,.,,..,,.,,,,..,.,,,,.,,.,.,..,,,,,,..,,...,...,.,,,...,,..,,,,,.,.,
#KROA7JMN6SGKKZ7HO4MXRRYIGEPHJRNHG6P6RLWZSY23MLSUYB274BGH3QB26QDU5IQG5XMZSUBQO
#\\\|3TDUL4VD3SQGX2KGN6UNHMNLV442SQLC6Q7VYUFC3SYRMZIE6Z6 \ / AMOS7 \ YOURUM ::
#\[7]TUKI2TVKY4PYMPXCIVHU7LRIYON7DVVB2LUFC53LYZDQGZESBQAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
