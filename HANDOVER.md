# Session Handover — Mar 25 2026 (updated)

## context.* namespace — complete 5-phase implementation + runtime zenka

all 5 phases committed on `base` branch. context zenka running and tested.
this is the unified context management layer for budget-aware llm context
assembly, compaction, delegation, and caching.

### commit history

| commit | phase | modules |
|--------|-------|---------|
| `ceb4b5cc3` | A — foundation | init_code, template.load/render, compose, compose.for_task, memory.load, style.guide |
| `7f7e19daf` | B — providers | file.extract, module.dependencies, zenka.state, conversation.history, error.recent, compose.for_review, compose.quick |
| `4b347ef75` | C — compaction | compact, compact.turns/diff/incremental, priority.rank/prune, pattern.find |
| `fbc2bb9fa` | D — delegation | delegate.role/prepare/dispatch/collect/verify, compose.for_delegation |
| `9be6c7978` | E — caching | cache.store/fetch/invalidate, share.export/import |
| `f481c82a8` | D+ — handler | delegate.handler.result (async reply callback) |
| `7d6432406` | dep-graph | module.dep_graph (Kosaraju SCC), dep_order, dep_pack |
| `f05d01317` | review pipeline | review.plan/page/iterate/consolidate, review.handler.page_result |
| `caede9bb9` | ncode foundation | ncode.init_code, regex.load/apply/save + seed patterns |
| `98efcd1a5` | context zenka | zenka config, v7.cmd.start fix, channels.memory-sync.fetch/publish |
| `5ed7db030` | ncode assess | regex.assess — diff-to-pattern extraction, confidence [0.27,0.97] |
| `a339d9a93` | ncode expand | regex.expand — library growth with capacity management |
| `14d1da0be` | ncode wave | transform.wave + kimi base32r decode fix |
| `7c93b750a` | ncode handler | transform.handler.wave_reply — closes self-refinement loop |
| `225e7fcb1` | ncode commands | cmd.transform + cmd.tool_list — complete phase 1+2 |

---

## ncode — self-refining regex transformation engine

**11 modules — phases 1+2 complete**, running in context zenka:

core engine:
- `ncode.init_code` — loads patterns from `data/yaml/ncode-patterns/*.yaml`
- `ncode.regex.load` — parses yaml definitions, compiles with `qr//`
- `ncode.regex.apply` — applicability filtering, confidence thresholds, scan/apply modes
- `ncode.regex.save` — persist patterns back to yaml (uses `format.yaml.write_file`)

learning loop (kimi-implemented):
- `ncode.regex.assess` — diff-to-pattern extraction, confidence range [0.27, 0.97]
- `ncode.regex.expand` — add to library with weighted confidence merge, capacity eviction

orchestration:
- `ncode.transform.wave` — single refinement cycle: regex pre-pass → LLM dispatch
- `ncode.transform.handler.wave_reply` — async: LLM result → assess → expand → save

command interface:
- `ncode.cmd.transform` — multi-wave command interface with deferred LLM support
- `ncode.cmd.tool_list` — self-describing capabilities (5 tools with param specs)

seed patterns in `data/yaml/ncode-patterns/p7-style.yaml` — 12 patterns covering:
pipe-delimiter `m||` conflicts, comment style, `qw|` quoting, `$ARG` convention,
module call syntax, sub declarations, `return TRUE` constants, log formatting

also: `bin/kimi-task` helper script for base32r-encoded prompt dispatch to kimi

design doc: `data/md/coding-tasks/ncode-zenka-self-refining-regex.md`
- decision tree escalation: regex → callback → LLM → user preference
- three-layer optimization: syntax, high-confidence file ops, meta-compaction
- reference count tree compaction via LLM generalization
- design-phase advising: ncode surfaces suggestions before code generation

---

## design documents

- `data/md/coding-tasks/context-namespace-design.md` — master design, all 5 layers, templates, phasing
- `data/md/coding-tasks/context-batch-review-pipeline.md` — paginated review with dep-graph packing, step groups
- `data/md/coding-tasks/ncode-zenka-self-refining-regex.md` — ncode design, decision trees, tree compaction
- `data/md/coding-tasks/checksum-route-binary-framing.md` — B32R binary framing with 0/1 delimiters
- `data/md/coding-tasks/checksum-route-binary-framing-harmonic-foundations.md` — kimi synthesis, 1001 cube
- `data/yaml/context-templates/` — code-review.yaml, bug-fix.yaml, feature-impl.yaml, delegation.yaml

---

## what to do next — priority order

### 1. runtime testing — context zenka is live

the context zenka is running (`v7.start context`). test:
- `context.compose.for_task` with a known task type (e.g., `code-review`)
- `context.cache.store` → `context.cache.fetch` round-trip
- `context.delegate.role` with various task types
- full pipeline: `review.plan` → `review.iterate` → `review.consolidate`
- verify result directory structure in `data/review/<type>/`
- ncode pattern loading: check `ncode.patterns` data key after init

### 2. ncode expansion — remaining modules

build out the ncode learning loop:
- `ncode.regex.assess` — check if a transformation diff can become regex
- `ncode.regex.expand` — add new pattern with confidence tracking
- `ncode.transform.wave` — single regex + LLM refinement cycle
- `ncode.cmd.transform` — command interface for other zenki
- `ncode.cmd.tool_list` — self-describing capabilities for models

### 3. wire delegation into task system

- wire `models.task.execute` to optionally use `context.delegate.prepare`
- test model→model delegation via task system with a simple review task
- verify `delegate.handler.result` chains correctly through collect → verify → cache

### 4. valued trees — floating-point factor nodes

tree nodes carry floating-point factors: integer = reference count,
fraction = implicit priority/applicability weight. each node value can itself
be a decision tree in the same format — self-similar nesting. applies to:
- ncode regex confidence/coverage scores
- task dependency priority ordering
- consensus voting weights
- branch node group elements

### 5. step group expansion — compliance-driven iteration

current pipeline iterates linearly through pages. evolve to:
- each pipeline node becomes a step group [ list of assessor steps ]
- parallel perspectives from multiple models per step
- summarize into one compliance result per step
- iterate based on attribute compliance, not fixed page count
- see "pipeline nodes as step groups" in batch review pipeline design doc

### 6. checksum-addressed model endpoints

current `context.delegate.role` resolves to zenka string names.
future: resolve via AMOS checksum lookup through models registry.
`models.registry.lookup` and `models.decision.recommendation_engine` already
score models by context — wire into `delegate.role` for checksum resolution.
single models treated as groups from the start — same summarization path.

---

## key design principles — preserve these

### role fluidity
delegation is NOT hardcoded as kimi→coding. any model can be coordinator or
executor. roles are negotiated per task based on capability fit. this can
shift mid-session. agreement-based dispatch adds inherent safety through
perspective diversity.

### everything is a group of size 1
every addressable entity (model, task, consensus group) is a group defaulting
to size 1. scaling from single-model to multi-model consensus is a membership
change, not a code change. `llm.service.consensus_vote` handles N-of-M agreement.

### checksum-based universal addressing
AMOS 7-char checksums as routing primitive for all entities. token efficient,
structurally uniform, distributed-ready. P7REF format `TYPE:CHKSUM7:ADDR_B32`
is the universal coordinate system. mnemonic short names as human-friendly aliases.

### budget-aware providers
all context.* modules accept `budget` param (token count), truncate to
`budget * <context.cfg.chars_per_token>` characters. providers return formatted
text, not raw data. this convention must be preserved in all new modules.

---

## architecture reference

### module dispatch patterns
```perl
## static call [ compile-time resolved ] ##
<[context.compose]>->({ 'template' => qw| code-review |, 'budget' => 4000 })

## dynamic call [ runtime resolved, safe across swap boundaries ] ##
my $fn = $code{'context.compose'};
$fn->($params) if defined $fn;
```

### delegation flow
```
caller → delegate.role   [ resolve coordinator + executor ]
       → delegate.prepare [ assemble context + prompt ]
       → delegate.dispatch [ base32r encode + route-send ]
       → ... async ...
       → delegate.collect  [ decode + structure result ]
       → delegate.verify   [ validate completeness + format ]
```

### context composition flow
```
compose.for_task(task_type)
  → template.load(template_name)
  → template.render(template, variables)
    → for each provider section:
      → $code{provider}->({ budget => section_budget })
  → priority.rank(sections, task_type)
  → join within budget
```

---

## files changed this session

### new modules (58 total)

#### phases A-E: context management (33)
```
modules/context.init_code
modules/context.template.load
modules/context.template.render
modules/context.compose
modules/context.compose.for_task
modules/context.compose.for_review
modules/context.compose.for_delegation
modules/context.compose.quick
modules/context.memory.load
modules/context.style.guide
modules/context.file.extract
modules/context.module.dependencies
modules/context.zenka.state
modules/context.conversation.history
modules/context.error.recent
modules/context.compact
modules/context.compact.turns
modules/context.compact.diff
modules/context.compact.incremental
modules/context.priority.rank
modules/context.priority.prune
modules/context.pattern.find
modules/context.delegate.role
modules/context.delegate.prepare
modules/context.delegate.dispatch
modules/context.delegate.collect
modules/context.delegate.verify
modules/context.delegate.handler.result
modules/context.cache.store
modules/context.cache.fetch
modules/context.cache.invalidate
modules/context.share.export
modules/context.share.import
```

#### dep-graph + review pipeline (8)
```
modules/context.module.dep_graph
modules/context.module.dep_order
modules/context.module.dep_pack
modules/context.review.plan
modules/context.review.page
modules/context.review.iterate
modules/context.review.consolidate
modules/context.review.handler.page_result
```

#### ncode — complete phases 1+2 (11)
```
modules/ncode.init_code
modules/ncode.regex.load
modules/ncode.regex.apply
modules/ncode.regex.save
modules/ncode.regex.assess             [ kimi: diff-to-pattern extraction ]
modules/ncode.regex.expand             [ kimi: library growth + capacity mgmt ]
modules/ncode.transform.wave           [ kimi: regex + LLM orchestration ]
modules/ncode.transform.handler.wave_reply  [ kimi: async assess → expand → save ]
modules/ncode.cmd.transform            [ kimi: multi-wave command interface ]
modules/ncode.cmd.tool_list            [ kimi: self-describing capabilities ]
```

#### infrastructure (5)
```
modules/channels.memory-sync.fetch
modules/channels.memory-sync.publish
modules/v7.zenka.cmd.start            [ bugfix: undef guard for start-by-name ]
modules/kimi.cmd.ask-reply             [ bugfix: base32r decode order + alphabet ]
configuration/zenki/context/           [ start, zenka-startup.v7, whitelist ]
```

### scripts + data files
```
bin/kimi-task                                                 [ base32r prompt dispatch ]
data/yaml/ncode-patterns/p7-style.yaml                       [ 12 seed patterns ]
data/md/coding-tasks/context-namespace-design.md              [ role fluidity update ]
data/md/coding-tasks/context-batch-review-pipeline.md         [ step group architecture ]
data/md/coding-tasks/ncode-zenka-self-refining-regex.md       [ decision tree design ]
data/md/coding-tasks/checksum-route-binary-framing.md         [ B32R binary framing ]
data/md/coding-tasks/checksum-route-binary-framing-harmonic-foundations.md  [ kimi synthesis ]
data/md/coding-tasks/context-runtime-testing-and-depgraph.md  [ testing task ]
data/gfx/cubic-space-topology/v13.7.1.partial.png             [ 1001 cube topology ]
data/yaml/context-templates/code-review.yaml
data/yaml/context-templates/bug-fix.yaml
data/yaml/context-templates/feature-impl.yaml
data/yaml/context-templates/delegation.yaml
```

---

## kimi coding style reminders

- `qw| word |` is CORRECT for single scalar strings — it IS P7 style, not a bug
- `m{}` when pattern contains pipes, `m||` otherwise, never `//`
- lowercase comments, `[ bracket ]` annotations, `$ARG` not `$_`
- never add AMOS signature stubs — leave clean for signing system
- see `data/ai-mem/kimi/coding-style.md` for full guide

## critical P7 patterns

- `protocol-7.route-send` returns send count (0/1), NOT reply data
- `<[module.name]>->()` — closing `]>` BEFORE `->`
- `base.perlmod.autoload`: one module per call, not a list
- `file.slurp` returns scalar ref — dereference with `->$*`
- `TRUE=5, FALSE=0, UNKNOWN=2` — not 1/0
- event timers: repeating needs BOTH `interval => N` AND `repeat => TRUE`
