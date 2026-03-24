# Session Handover — Mar 25 2026

## context.* namespace — complete 5-phase implementation

all 5 phases committed on `base` branch. this is the unified context management
layer for budget-aware llm context assembly, compaction, delegation, and caching.

### commit history

| commit | phase | modules |
|--------|-------|---------|
| `ceb4b5cc3` | A — foundation | init_code, template.load/render, compose, compose.for_task, memory.load, style.guide |
| `7f7e19daf` | B — providers | file.extract, module.dependencies, zenka.state, conversation.history, error.recent, compose.for_review, compose.quick |
| `4b347ef75` | C — compaction | compact, compact.turns/diff/incremental, priority.rank/prune, pattern.find |
| `fbc2bb9fa` | D — delegation | delegate.role/prepare/dispatch/collect/verify, compose.for_delegation |
| *unsigned* | E — caching | cache.store/fetch/invalidate, share.export/import |

### phase E status

5 modules written, syntax-clean (perl -c errors are expected P7 data-hash syntax).
**needs**: signing via `bin/Protocol-7 sourcecode update-signatures`, then commit.

files:
- `modules/context.cache.store` — key+ttl storage in `<context.cache>` data hash
- `modules/context.cache.fetch` — freshness-checked retrieval with hit counting
- `modules/context.cache.invalidate` — by key, tag, age, or clear all
- `modules/context.share.export` — serialize + publish via channels.memory-sync or local fallback
- `modules/context.share.import` — fetch + deserialize with ttl/age checks

---

## design documents

- `data/md/coding-tasks/context-namespace-design.md` — master design, all 5 layers, templates, phasing
- `data/md/coding-tasks/context-batch-review-pipeline.md` — paginated review with dep-graph packing and rolling summaries
- `data/yaml/context-templates/` — code-review.yaml, bug-fix.yaml, feature-impl.yaml, delegation.yaml

---

## what to do next — priority order

### 1. sign and commit phase E
```bash
bin/Protocol-7 sourcecode update-signatures
git add modules/context.cache.store modules/context.cache.fetch \
       modules/context.cache.invalidate modules/context.share.export \
       modules/context.share.import
# commit message: "Add context.* phase-E: caching and cross-zenka sharing"
```

### 2. strategic testing — load context namespace in a zenka

the modules are additive and don't break anything, but need runtime verification:
- add `context.*` modules to a test zenka's module whitelist
- verify `context.init_code` sets up config defaults correctly
- test `context.compose.for_task` with a known task type (e.g., `code-review`)
- test `context.cache.store` → `context.cache.fetch` round-trip
- test `context.delegate.role` with various task types
- verify `context.template.load` reads yaml templates from `data/yaml/context-templates/`

### 3. batch review pipeline — dependency graph modules

design doc at `data/md/coding-tasks/context-batch-review-pipeline.md`.
next implementation targets:
- `context.module.dep_graph` — full bidirectional dep graph for file set
- `context.module.dep_order` — topological sort with SCC clustering
- `context.module.dep_pack` — bin-pack ordered files into budget-sized pages

these build on existing `context.module.dependencies` (phase B) and can be
tested standalone. the pipeline modules (review.plan/page/iterate/consolidate)
come after the dep modules work.

### 4. wire delegation into task system

the `context.delegate.*` modules implement role-fluid model coordination.
to make them live:
- create `context.delegate.handler.result` — the reply handler referenced by dispatch
- wire `models.task.execute` to optionally use `context.delegate.prepare` for context assembly
- test kimi→coding delegation via task system with a simple code review task

### 5. checksum-addressed model endpoints

current `context.delegate.role` resolves to zenka string names.
future: resolve via AMOS checksum lookup through models registry.
`models.registry.lookup` and `models.decision.recommendation_engine` already
score models by context — wire into `delegate.role` for capability-based resolution.

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

### new modules (26 total across phases A-E)
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
modules/context.cache.store
modules/context.cache.fetch
modules/context.cache.invalidate
modules/context.share.export
modules/context.share.import
```

### design docs
```
data/md/coding-tasks/context-namespace-design.md    [ updated with role fluidity ]
data/md/coding-tasks/context-batch-review-pipeline.md  [ new — paginated review design ]
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
