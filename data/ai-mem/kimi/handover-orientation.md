# Kimi Handover Orientation — March 25 2026

## understanding summary

the context.* namespace is a unified context management layer for budget-aware llm context assembly, compaction, delegation, and caching. it was built across 5 phases (A-E) plus review pipeline and ncode foundation. the context zenka is live and running.

## what exists now (49 modules)

### context.* — 5-phase implementation (33 modules)
- **phase A**: init, template.load/render, compose, compose.for_task, memory.load, style.guide
- **phase B**: file.extract, module.dependencies, zenka.state, conversation.history, error.recent, compose.for_review, compose.quick
- **phase C**: compact (turns/diff/incremental), priority.rank/prune, pattern.find
- **phase D**: delegate.role/prepare/dispatch/collect/verify/handler.result, compose.for_delegation
- **phase E**: cache.store/fetch/invalidate, share.export/import

### review pipeline (8 modules)
- context.module.dep_graph — Kosaraju SCC algorithm
- context.module.dep_order — topological sort
- context.module.dep_pack — bin-pack into budget pages
- context.review.plan/page/iterate/consolidate — paginated review with rolling summaries
- context.review.handler.page_result — async callback

### ncode foundation (4 modules)
- ncode.init_code — loads patterns from data/yaml/ncode-patterns/*.yaml
- ncode.regex.load — parses yaml, compiles with qr//
- ncode.regex.apply — applicability filtering, confidence thresholds, scan/apply modes
- ncode.regex.save — persists patterns back to yaml

### context zenka configuration
- configuration/zenki/context/start — loads auth, net, protocol, io.unix, format.yaml, channels, context, ncode

## key design principles to preserve

1. **role fluidity** — any model can be coordinator or executor, negotiated per task
2. **everything is a group of size 1** — single models are groups, scaling is membership change
3. **checksum-based universal addressing** — P7REF format `TYPE:CHKSUM7:ADDR_B32`
4. **budget-aware providers** — all modules accept `budget` param, return `{ mode, data }`

## coding style essentials

- `qw| word |` is correct for single scalar strings — it IS P7 style
- `m{}` when pattern contains pipes, `m||` otherwise
- lowercase comments, `[ bracket ]` annotations, `$ARG` not `$_`
- never add AMOS signature stubs — leave clean for signing system
- use `ptd` for formatting and syntax checking
- `TRUE=5, FALSE=0, UNKNOWN=2` — not 1/0
- `<[module.name]>->()` — closing `]>` BEFORE `->`

## ncode seed patterns (12 in p7-style.yaml)

1. regex-pipe-alternation-m-bar — flag m|| with alternation pipes
2. regex-pipe-alternation-split — flag split m|| with alternation
3. comment-uppercase-start — flag uppercase comment starts
4. single-quote-to-qw-scalar — convert 'word' to qw| word |
5. double-quote-to-qw-scalar — convert "word" to qw| word |
6. module-call-missing-bracket — flag <[mod]-> syntax errors
7. sub-declaration-in-module — flag sub {} in modules
8. dollar-underscore-to-arg — replace $_ with $ARG
9. return-one-to-true — flag return 1 vs return TRUE
10. log-missing-format-wrapper — flag interpolation in logs
11. paren-annotation-to-bracket — flag ( word ) vs [ word ]

## next implementation targets

### priority 1: ncode expansion (learning loop)
- `ncode.regex.assess` — check if a transformation diff can become regex
- `ncode.regex.expand` — add new pattern with confidence tracking
- `ncode.transform.wave` — single regex + LLM refinement cycle
- `ncode.cmd.transform` — command interface for other zenki
- `ncode.cmd.tool_list` — self-describing capabilities for models

### priority 2: runtime testing
- test `context.compose.for_task` with known task types
- test `context.cache.store` → `context.cache.fetch` round-trip
- test `context.delegate.role` with various task types
- verify full pipeline: `review.plan` → `review.iterate` → `review.consolidate`

### priority 3: integration
- wire `models.task.execute` to optionally use `context.delegate.prepare`
- test model→model delegation via task system

## questions/concerns

1. **testing approach**: need to understand how to run nshell commands against the context zenka to verify functionality
2. **ncode assess logic**: the design doc mentions "diff extraction" and "generalizability assessment" — need to understand what makes a pattern suitable for regex capture
3. **confidence tracking**: how are confidence scores initially set when extracting from LLM diffs? need to review the expansion logic

## immediate next steps

1. start with `ncode.regex.assess` — foundational for the learning loop
2. test context zenka via `v7.start context` and nshell commands
3. read existing context.* modules to understand the provider pattern deeply

#,,.,,,,,,,..,,,,,..,,,..,..,,.,,,..,,..,,.,,,.,.,...,...,...,,,,,,..,.,,,,..,
#MAODZYEVF6EPYF5CQEWAZDVQYGERESPPRVFR3HLYIPPKHKATMDQHSS2CQQCYWBBJUBYAJKUGKJEBY
#\\\|765BFYI37N5GEENPWMUQDL33WGNPLG7QE5EI3NDUKVCNNSN5M5A \ / AMOS7 \ YOURUM ::
#\[7]SS4YT42U6QGWO3W5RYCXD7NLAPNYG3S3AFAWVLFSPLTJ557OJQCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
