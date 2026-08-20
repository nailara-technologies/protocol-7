## [:< ##

# context batch review pipeline — dependency-aware paginated review
# descr = batch-process large file sets through budget-constrained review pages with rolling summaries

---

## problem

reviewing a topic across all matching `src/*` files often exceeds any
single context window. a security audit, style review, or refactor analysis
touching 50+ modules cannot be done in one pass. manually splitting is
error-prone — it misses cross-file dependencies and loses context between
batches.

---

## vision

a paginated review pipeline that:

1. accepts a pattern or topic and resolves matching files
2. builds a dependency graph to determine inclusion order
3. packs files into context-budget-sized pages
4. submits each page as a review task with system prompt + iteration history
5. compacts each review result into a descriptive summary
6. feeds the compacted summary into the next page as orientation context
7. produces a final consolidated review from all page summaries

---

## architecture

```
  pattern match         dep-graph sort        budget packing
  src/topic.*  -->  ordered file list -->  page 1 [ files A B C ]
                                               page 2 [ files D E F ]
                                               page 3 [ files G H ]

  per page:
  ┌─────────────────────────────────────────────────┐
  │ system prompt  [ task type, review guidelines ]  │
  │ iteration summary  [ compacted prior reviews ]   │
  │ file contents  [ budget-fitted from dep graph ]  │
  └──────────────────────┬──────────────────────────┘
                         │
                    model review
                         │
                    ┌────▼────┐
                    │ review  │──> compact ──> iteration summary for next page
                    │ result  │──> store   ──> page results accumulator
                    └─────────┘

  after all pages:
  ┌──────────────────────────────────────────┐
  │ all page summaries  -->  final review    │
  └──────────────────────────────────────────┘
```

---

## module candidates

### core pipeline

| module | phase | description |
|--------|-------|-------------|
| `context.review.plan` | D+ | accept pattern, resolve files, build page plan |
| `context.review.page` | D+ | assemble single page context within budget |
| `context.review.iterate` | D+ | drive page-by-page review with summary carry |
| `context.review.consolidate` | D+ | merge page reviews into final output |

### dependency resolution

| module | phase | description |
|--------|-------|-------------|
| `context.module.dep_graph` | D+ | full bidirectional dep graph for file set |
| `context.module.dep_order` | D+ | topological sort with cluster grouping |
| `context.module.dep_pack` | D+ | bin-pack ordered files into budget pages |

### context helpers [ already exist or in phase C ]

| module | status | role in pipeline |
|--------|--------|------------------|
| `context.module.dependencies` | phase B | single-file dependency extraction |
| `context.pattern.find` | phase C | pattern matching across modules |
| `context.compact` | phase C | section-based text compaction |
| `context.compact.diff` | phase C | diff-specific compaction |
| `context.priority.rank` | phase C | task-weighted priority scoring |
| `context.file.extract` | phase B | partial file reads |
| `context.compose` | phase A | provider orchestration with budget |

---

## page assembly logic

### file ordering

1. resolve pattern to file list [ glob or regex over src/ ]
2. extract dependency edges per file [ via context.module.dependencies ]
3. build directed graph [ module A calls module B → edge A→B ]
4. topological sort with strongly-connected component grouping
5. files in same SCC cluster stay on the same page when possible

### budget packing

```
given: ordered file list, page_budget [ tokens ]

page = []
page_used = 0

for each file in order:
    file_tokens = estimate_tokens(file_content)
    if page_used + file_tokens > page_budget and page not empty:
        emit page
        page = []
        page_used = iteration_summary_tokens  ## reserve for summary
    push file to page
    page_used += file_tokens

emit final page
```

### iteration summary budget

each page reserves a portion of its budget for the iteration summary:
- page 1: no summary needed [ full budget for files ]
- page 2+: reserve `min(summary_size, page_budget * 0.2)` for summary
- summary grows but gets compacted — stays bounded

---

## review task flow

### per-page task creation

```perl
## pseudocode — actual implementation via task system ##

my $task_params = {
    'type'      => $review_type,        ## security, style, refactor, etc.
    'context'   => $page_context,       ## assembled page content
    'summary'   => $iteration_summary,  ## compacted prior reviews
    'page'      => $page_num,
    'total'     => $total_pages,
    'guidelines' => $review_guidelines
};
```

### summary compaction between pages

after each page review completes:
1. extract key findings [ issues, patterns, decisions ]
2. compact via context.compact with descriptive preservation
3. prepend to iteration summary for next page
4. if summary exceeds budget allocation — re-compact older entries

### final consolidation

after all pages complete:
1. collect all page review results
2. assemble with page summaries as section headers
3. submit consolidation task [ or return structured result ]
4. output: per-file findings + cross-cutting themes + priority ranking

---

## review types [ extensible ]

| type | focus | guidelines source |
|------|-------|-------------------|
| `security` | OWASP, injection, auth, crypto | forensics zenka templates |
| `style` | code conventions, naming, structure | CONVENTIONS.yaml |
| `refactor` | duplication, coupling, complexity | context.pattern.find matches |
| `dependency` | circular deps, missing, unused | dep graph analysis |
| `api-surface` | command interface consistency | access.cmd definitions |

---

## integration points

- **task zenka**: page reviews dispatch as tasks via existing task.create flow
- **kimi / coding**: review tasks route to appropriate model by type
- **forensics zenka** [ future ]: nightly security reviews use this pipeline
  with `type => 'security'` at the 04:07 timetable slot
- **context.compose.for_review**: existing module becomes entry point for
  single-page reviews; batch pipeline wraps it for multi-page

---

## phasing

this builds on phases A-C [ context providers and compaction ] and
phase D [ delegation layer ]. implementation sequence:

1. **dep_graph + dep_order + dep_pack** — dependency resolution and packing
   [ can be built and tested standalone ]
2. **review.plan** — pattern to page plan [ uses dep modules ]
3. **review.page** — single page assembly [ uses existing context.compose ]
4. **review.iterate** — page loop with summary carry [ uses context.compact ]
5. **review.consolidate** — final merge [ straightforward after iterate works ]

---

## pipeline nodes as step groups

each pipeline node is NOT a single operation — it is a **list of steps**
that assess all important attributes. a node is a group of size 1 by default,
expandable to parallel assessment from multiple perspectives.

### step group lifecycle

```
step group [ initially size 1 ]
  │
  ├─ expand: add assessors based on attribute requirements
  │   model-A reviews security
  │   model-B reviews style
  │   model-C reviews dependencies
  │
  ├─ parallel execution: each perspective runs independently
  │
  ├─ summarize: merge into one compliance result
  │
  ├─ check: attribute group compliance met?
  │   yes → compact and advance to next node
  │   no  → expand with additional steps for failing attributes
  │
  └─ iterate: count based on compliance, not linear distribution
```

### compliance-driven iteration

iteration count is a function of **attribute group compliance**, not page count.
a page with clean code might need 1 pass. a page with security-sensitive
networking code might need 3 passes — first for correctness, then security,
then style — each adding assessors as needed.

```
while not all_attributes_compliant(result):
    expand step group with assessors for failing attributes
    run parallel perspectives
    summarize into updated result
    check compliance
```

### single models as groups

treating single models as groups from the start means:
- adding another model to a step is a membership change, not a code change
- results always go through summarization [ even for group size 1 ]
- the summarization path is exercised and reliable before it's needed at scale
- any model can be added to any step based on applicable usefulness

### optimization insertion points

optimizations are **additional steps per cycle**, not replacement steps:
- tight cycle groups of related steps compact early
- "into time you can always expand" — temporal budget allows deeper passes
- early compaction prevents error propagation across cycle boundaries

## open questions

- should dep graph include data-hash key dependencies or only code calls?
- consolidation model: same as page reviewer or a separate summarization model?
- how to express attribute compliance thresholds in review plan config?
- should step group membership be static per plan or adaptive per page?

#,,.,,.,,,,,,,,..,,..,..,,.,.,..,,.,.,,.,,,.,,..,,...,...,.,,,.,,,,,.,,,,,.,,,
#B4OMK2SQHQDHOGFV6M7LDZCGIUZXVWPN3M72TW3ST5P44SMJCTDOVO6ZIAT6A3OUTEXWC7NDODQQA
#\\\|2AFJV55ZHGDRTZ7YKVACANBOUHACULTMRNHHXA4CKYTVC4KWRKQ \ / AMOS7 \ YOURUM ::
#\[7]S3VIN632XBUXYDYEDLIXAHRMHJGETQW6HGUQFTKR5JIVUHB2AGDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
