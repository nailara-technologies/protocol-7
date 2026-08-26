## next steps plan — post context.* + ncode phases 1+2

prioritized implementation plan following completion of 5-phase context namespace
and ncode phases 1+2. covers delegation wiring, valued trees, step groups,
and checksum-addressed endpoints.

mark checklist items as completed alongside corresponding commits.

---

## part 1: immediate [ can do now ]

### 1.1 runtime bug fixes from verification

status: verification passed — no bugs found.

- [x] verified: no compile warnings in context zenka
- [x] verified: ncode.init loads 11 patterns successfully
- [x] verified: all 4 fix categories applied correctly

if new bugs surface during testing, document here and prioritize above all else.

---

### 1.2 wire models.task.execute to context.delegate.prepare

create optional delegation path in task execution flow.

#### purpose
allow task system to use context delegation for model-to-model coordination
instead of direct single-model dispatch.

#### modules to modify

- `models.task.execute` [ existing ]
  - add `delegate` parameter to task config
  - when `delegate => true`, call `context.delegate.prepare` before execution
  - route through `delegate.dispatch` → `collect` → `verify` chain
  - fall back to direct execution if delegation fails

#### new modules

- `models.task.delegate_bridge`
  - adapter between task system and context delegation
  - converts task params to delegation format
  - handles result conversion back to task result structure

#### dependencies
- requires `context.delegate.*` modules [ complete ]
- requires `models.task.execute` [ existing ]

#### estimated complexity: small

#### acceptance criteria
- [x] task with `delegate => true` routes through delegation pipeline
- [x] task result contains delegation metadata when delegated
- [x] fallback to direct execution on delegation failure
- [x] no regression in existing non-delegated task execution

---

### 1.3 test model→model delegation via task system

end-to-end verification of delegation wiring.

#### test scenario
simple code review task delegated from kimi to coding zenka:
```
kimi [coordinator] → analyze task → delegate to coding [executor]
                                         ↓
coding → execute review → return structured result
                                         ↓
kimi → collect → verify → present to user
```

#### modules involved
- `models.task.execute` [ modified in 1.2 ]
- `models.task.delegate_bridge` [ new in 1.2 ]
- `context.delegate.role`, `.prepare`, `.dispatch`, `.collect`, `.verify`
- `context.delegate.handler.result` [ async callback ]

#### dependencies
- blocked until 1.2 complete

#### estimated complexity: small

#### acceptance criteria
- [ ] successful delegation round-trip via task system
- [ ] result correctly propagated back to original caller
- [ ] async handler chains through all verification steps
- [ ] cache stores delegation result for reuse

---

## part 2: short term

### 2.1 valued trees — floating-point factor nodes

tree nodes carry composite values: integer part = reference count,
fractional part = priority/applicability/weight factor.

#### purpose
unify reference counting with weighted decision making across:
- ncode pattern confidence/coverage scores
- task dependency priority ordering
- consensus voting weights
- branch node group membership strength

#### concept
```
node value = N + f  where:
  N = integer = reference count [ how many parents point here ]
  f = fraction ∈ [0,1) = weight [ priority, confidence, applicability ]

self-similar nesting: each node value can itself be a decision tree
```

#### new modules

- `valued.init_code`
  - define composite value structure
  - define operations: add_ref, remove_ref, set_weight, get_effective

- `valued.node.create`, `.destroy`, `.update`
  - lifecycle management with automatic ref-counting

- `valued.tree.balance`
  - rebalance tree when weights shift significantly
  - preserve structural invariants during updates

- `valued.resolve`
  - traverse tree to resolve effective value at any node
  - handles nested tree values [ recursive resolution ]

#### modules to modify

- `ncode.regex.expand` [ existing ]
  - store pattern confidence as valued tree node
  - coverage score becomes weight fraction

- `context.priority.rank` [ existing ]
  - use valued trees for priority ordering
  - dependency strength = weight factor

- `llm.service.consensus_vote` [ existing ]
  - member votes as valued tree weights
  - threshold checking uses effective values

#### dependencies
- none — builds on existing data structures

#### estimated complexity: medium

#### acceptance criteria
- [ ] valued tree operations unit tested
- [ ] ncode patterns store confidence/coverage as valued nodes
- [ ] priority ranking uses weighted tree traversal
- [ ] consensus voting uses weighted member resolution
- [ ] nested tree values resolve recursively without cycles

---

### 2.2 step group expansion — compliance-driven iteration

evolve linear pipeline iteration to step-group-based compliance checking.

#### purpose
current `review.iterate` processes fixed pages. evolve to:
- each pipeline node = step group [ list of assessor steps ]
- parallel perspectives from multiple models per step
- summarize into one compliance result per step
- iterate based on attribute compliance, not fixed count

#### concept
```
step group = {
  name       => "security.boundary-check",
  assessors  => [ model_a, model_b, model_c ],  # parallel
  attributes => [ "completeness", "accuracy", "actionability" ],
  threshold  => 0.85,  # min compliance to pass
  max_rounds => 3      # max iterations before escalation
}

iteration stops when all attributes comply or max_rounds reached
```

#### new modules

- `context.step_group.init_code`
  - define step group structure
  - compliance scoring algorithm

- `context.step_group.assess`
  - dispatch to multiple assessors in parallel
  - collect and summarize results
  - calculate compliance per attribute

- `context.step_group.iterate`
  - iterate step groups until compliance or limit
  - track round count per group
  - escalate non-compliant groups

- `context.compliance.calculate`
  - aggregate assessor outputs into compliance scores
  - weighted by assessor reliability [ from valued trees ]

#### modules to modify

- `context.review.plan` [ existing ]
  - create step groups instead of flat pages
  - map review type to default assessor sets

- `context.review.iterate` [ existing ]
  - iterate step groups, not pages
  - compliance check after each round

- `context.review.consolidate` [ existing ]
  - merge step group results with compliance metadata

#### dependencies
- soft dependency on 2.1 [ valued trees for assessor weights ]
- can use simple weights initially, migrate to valued trees after

#### estimated complexity: medium [ larger if done with 2.1 ]

#### acceptance criteria
- [ ] step groups define assessor lists and attribute thresholds
- [ ] parallel assessor dispatch collects multiple perspectives
- [ ] compliance calculated per attribute per step group
- [ ] iteration continues until compliance or max_rounds
- [ ] results include compliance scores and iteration counts

---

## part 3: medium term

### 3.1 checksum-addressed model endpoints via amos lookup

evolve `context.delegate.role` from zenka string names to amos checksum lookup.

#### purpose
universal addressing via 7-char amos checksums:
- token efficient
- structurally uniform
- distributed-ready
- single models treated as groups from the start

#### current state
- `context.delegate.role` resolves to zenka string names [ `kimi`, `coding`, etc ]
- `models.registry.lookup` exists [ can query by checksum ]
- `models.decision.recommendation_engine` exists [ scores by context fit ]

#### new modules

- `models.resolve.amos_checksum`
  - lookup model by 7-char amos checksum
  - return model entry from registry

- `context.delegate.resolve_checksum`
  - integrate checksum lookup into delegation flow
  - resolve coordinator + executor by checksum, not name

- `models.group.expand_checksum`
  - treat checksum as group of size 1 or more
  - expand to member models if group checksum

#### modules to modify

- `context.delegate.role` [ existing ]
  - accept checksum in addition to zenka names
  - route to `models.resolve.amos_checksum` for lookup

- `context.delegate.prepare` [ existing ]
  - handle checksum-resolved models same as name-resolved
  - include checksum in routing metadata

#### dependencies
- requires 1.2 [ delegation wiring ] for testing
- requires `models.registry` [ complete ]

#### estimated complexity: medium

#### acceptance criteria
- [ ] delegation can specify models by 7-char amos checksum
- [ ] checksum lookup returns correct model from registry
- [ ] single models treated as groups of size 1
- [ ] group checksums expand to member models
- [ ] fallback to name-based resolution if checksum not found

---

### 3.2 ncode phase 3 — self-improvement loop with automated pattern learning

close the loop: ncode learns from its own transformations and user feedback.

#### purpose
- regex → callback → llm → user preference escalation
- automated pattern learning from successful transformations
- meta-compaction via llm generalization

#### new modules

- `ncode.meta.assess_confidence`
  - analyze pattern success/failure rates
  - identify underperforming patterns for review

- `ncode.meta.generalize`
  - llm-based pattern compaction
  - merge similar patterns into more general forms

- `ncode.feedback.record`
  - capture user accept/reject on transformations
  - update pattern confidence based on feedback

- `ncode.learn.schedule`
  - periodic learning passes over transformation history
  - trigger generalization when pattern count exceeds threshold

#### modules to modify

- `ncode.transform.wave` [ existing ]
  - record transformation outcomes for learning
  - flag patterns for confidence adjustment

- `ncode.regex.expand` [ existing ]
  - merge similar patterns during expansion
  - use valued trees for pattern weights [ 2.1 ]

- `ncode.cmd.transform` [ existing ]
  - add feedback capture to command interface
  - `accept`, `reject`, `modify` outcomes

#### dependencies
- soft dependency on 2.1 [ valued trees for pattern weights ]
- soft dependency on 2.2 [ step groups for learning assessment ]

#### estimated complexity: large

#### acceptance criteria
- [ ] transformation outcomes recorded with pattern associations
- [ ] user feedback updates pattern confidence scores
- [ ] automated generalization merges similar patterns
- [ ] learning schedule runs without blocking main operations
- [ ] pattern count growth rate slows with effective learning

---

## constraints

### design principles [ from handover.md ]

1. **role fluidity**
   - delegation is not hardcoded kimi→coding
   - any model can be coordinator or executor
   - roles negotiated per task based on capability fit
   - [ check ] all delegation modules preserve this

2. **everything is a group of size 1**
   - single models treated as groups from the start
   - scaling from 1 to n is membership change, not code change
   - [ check ] 3.1 implements checksum group expansion
   - [ check ] 2.2 assessors use group dispatch

3. **checksum-based universal addressing**
   - amos 7-char checksums as routing primitive
   - p7ref format `type:chksum7:addr_b32`
   - [ check ] 3.1 implements checksum resolution
   - [ check ] delegation uses p7ref for routing metadata

4. **budget-aware providers**
   - all context.* modules accept `budget` param
   - truncate to `budget * <context.cfg.chars_per_token>`
   - [ check ] new modules follow this convention
   - [ check ] valued trees do not break budget calculations

### ordering rationale

```
1.2 → 1.3 → 2.1 → 2.2 → 3.1 → 3.2
  │     │     │     │     │     │
  │     │     │     │     │     └─ builds on valued trees [2.1]
  │     │     │     │     │        and delegation [1.2]
  │     │     │     │     └─ requires delegation [1.2]
  │     │     │     │        and registry [complete]
  │     │     │     └─ soft dep on valued trees [2.1]
  │     │     └─ foundation for weighted decisions
  │     └─ tests delegation wiring
  └─ enables delegation pipeline
```

### hidden dependencies identified

1. **2.2 step groups ↔ 2.1 valued trees**
   - assessor weights in step groups should use valued trees
   - compliance scores benefit from weighted aggregation
   - mitigation: implement 2.2 with simple weights, migrate after 2.1

2. **3.1 checksum lookup ↔ 3.2 self-improvement**
   - learning loop should use checksum-addressed patterns
   - pattern identity via checksum, not name
   - mitigation: ensure 3.1 p7ref format supports pattern references

3. **all items → context.cfg.chars_per_token**
   - budget calculations depend on this config
   - changes affect all provider modules
   - mitigation: cache config value, recalculate on config update

---

## self-review notes

### architectural consistency

| principle | 1.2 | 1.3 | 2.1 | 2.2 | 3.1 | 3.2 |
|-----------|-----|-----|-----|-----|-----|-----|
| role fluidity | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| group of 1 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| checksum addr | — | — | — | — | ✅ | — |
| budget aware | ✅ | ✅ | n/a | ✅ | ✅ | n/a |

### ordering confidence

- 1.2 before 1.3: required [ cannot test without wiring ]
- 2.1 before 2.2: recommended [ weights inform compliance ]
- 2.x before 3.x: recommended [ delegation stable before extensions ]
- 3.1 before 3.2: recommended [ addressing stable before learning ]

### risk areas

1. **valued tree nesting**: recursive resolution needs cycle detection
2. **step group parallelism**: multiple assessors may overload backends
3. **checksum migration**: backward compatibility with name-based configs

### completion criteria for this plan

this plan is complete when:
- [ ] all immediate items implemented and tested
- [ ] all short-term items implemented and tested
- [ ] at least one medium-term item started
- [ ] plan updated to reflect actual implementation order

---

## file references

- `data/ai-mem/kimi/coding-style.md` — syntax conventions
- `data/md/coding-tasks/context-namespace-design.md` — 5-phase design
- `data/md/coding-tasks/context-batch-review-pipeline.md` — step groups design
- `data/md/coding-tasks/ncode-zenka-self-refining-regex.md` — ncode design
- `HANDOVER.md` — session state, what to do next

---

## log

- 2026-03-25: plan created, compile fixes verified
- patterns loaded: 11 [ from ncode.init ]
- compile warnings: 0 [ verified ]
- 2026-03-25: 1.2 delegation wiring implemented
  - modules:
    - models.task.delegate_bridge [ entry point ]
    - models.handler.delegate-online-reply [ async online check handler ]
    - models.task.do-delegation [ prepare + dispatch ]
    - models.task.fallback-direct [ direct dispatch fallback ]
    - models.handler.delegate_result [ async result handler ]
  - modified: models.task.execute (delegation path with async flow)
  - access: models zenka granted context.delegate.* access
- 2026-03-25: context tree checksum addressing design ✅
  - design docs:
    - context-tree-checksum-addressing.md [ resumable checksum architecture ]
    - context-tree-checksum-templates.md [ validation templates ]
    - context-tree-checksum-inspiration.md [ lessons from source.signature_valid ]
    - context-tree-octal-encoding.md [ compact encoding from amos7.encode_octal_header ]
  - modules:
    - context.tree.checksum.init_code [ infra initialization ]
    - context.tree.checksum.state [ resumable AMOS/ELF/BMW state ]
    - context.tree.checksum.stream [ position-aware streams ]
    - context.tree.checksum.template [ validation template management ]
  - concept: resumable incremental checksums for eternal storage
  - ELF: natively resumable via start_checksum (confirmed in AMOS7::CHKSUM::ELF)
  - BMW: requires XS patch for getstate/setstate/clone (test plan exists)
  - integrates with: storage zenka, index zenka, sourcecode symlinks (45+ modules)
  - templates: entropic exclusion + contextual constraints (AMOS7::TEMPLATE + Truth.pm)
  - validation patterns: RQ/OP constants, multi-layer truth assertion, repair mode (from source.signature_valid)
  - octal encoding: 19 octal digits = 57 bits (checksum + state + iterations) in comma/dot visual pattern (from amos7.encode_octal_header)

---

#,,.,,,,,,.,,,,..,,,.,,,.,,,,,,..,,.,,...,..,,..,,...,..,,,..,.,,,..,,...,,.,,
#7TPRHYIE6GJCHDIXOUTG5CA2XHQWUGJP5FGASC2AKMZPBH3BJMDYDRC7XCQOPLFZFAQVSEGZNOFKA
#\\\|7QVBWBEUPCS6MWS5QM6RVEQ2SANOX6TJHV6GU5UJ2APMTBAM57D \ / AMOS7 \ YOURUM ::
#\[7]CZUAZQTPT35JGKDK2BJQGTV6VQGX7AUXPWOHN7BD2Z7IHPGE2YBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
