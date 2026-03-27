## [:< ##

# plugin.storage.inference — checksum-addressed inference cache
# descr = content-addressed disk cache for LLM inference using existing storage plugin architecture

---

## purpose

add inference result caching as a storage plugin, reusing existing checksum,
cluster, and P7REF infrastructure. questions map to branch directories via
bmw-L13 checksums. responses become cluster members via bmw-224 checksums.
cache hits short-circuit the inference state machine and free tokens for
self-refinement at high-traffic branches.

### design principles

1. **plugin.storage pattern** — register in `$data{'storage'}{'mapping'}{'inference'}`,
   same shape as checksum/p7ref/visual plugins
2. **no reinvention** — use `plugin.storage.checksum.cluster.*` for grouping,
   `plugin.storage.checksum.map-file` patterns for content dedup,
   `plugin.storage.p7ref` for addressing
3. **awareness tree integration** — cache hits/misses emit events to
   `context.tree.summary.add-event` for relevance tracking
4. **self-similar structure** — every checksum is a branch address;
   patterns reappear at similar scale intervals; popular branches
   get proportional attention for self-refinement

---

## storage layout

```
var/inference-cache/
  <L13-question>/                     # 13-char bmw-L13 of question text
    .meta                             # question text, created, hit_count, tags, model_hints
    results/
      <B32-224-response-A>            # base32 bmw-224 of response content
      <B32-224-response-B>            # alternative (different model, temperature)
      ...
    refs/                             # symlinks to related question branches
      <L13-related> -> ../../<L13>/   # cross-references
    meta/
      <B32-224-response-A>.meta       # model_id, timestamp, confidence, finish_reason,
                                      #   token_count, temperature, response_L13
      <B32-224-response-B>.meta
```

### key properties

- **L13 parent** = question identity = branch address = cluster ID
- **B32-224 children** = specific responses = cluster members = leaf nodes
- same question from different models → same parent, different children
- identical response content from different questions → same B32-224,
  discoverable via reverse index (content deduplication)
- `.meta` hit counter drives attention allocation
- symlink refs create graph structure (reuses cluster traverse patterns)

### entropy divergence

when a new inference arrives for an existing question:
1. compute L13 of new response
2. compare to L13 of cached responses (`.meta` has `response_L13`)
3. if entropy divergence is below threshold → cache hit, skip store
4. if divergence is significant → store as new cluster member
5. multiple divergent responses at same branch = rich perspective = higher value

---

## modules

### plugin.storage.inference.init_code

initialize inference cache registry in `$data{'storage'}{'mapping'}{'inference'}`.

```perl
$data{'storage'}{'mapping'}{'inference'} = {
    'enabled'    => 1,
    'version'    => '0.1',
    'root_path'  => <system.root_path> . '/var/inference-cache',

    ## registry: L13 → branch metadata (in-memory hot index) ##
    'branches' => {},    # L13 => { hit_count, created, last_hit, result_count }

    ## config ##
    'config' => {
        'entropy_threshold'  => 0.15,   # L13 hamming distance for "same" response
        'max_results_branch' => 20,     # max responses per question branch
        'hit_attention_mult' => 1.5,    # attention multiplier per cache hit
        'prune_min_age_days' => 30,     # minimum age before pruning candidates
        'prune_min_hits'     => 0,      # branches with 0 hits after min_age
    },

    ## stats ##
    'stats' => {
        'hits'          => 0,
        'misses'        => 0,
        'stores'        => 0,
        'dedup_skips'   => 0,    # entropy too similar, skipped store
        'branches'      => 0,
        'total_results' => 0,
    },
};
```

register P7REF type handler:

```perl
## register with p7ref system if available ##
if ( exists $data{'storage'}{'mapping'}{'p7ref'} ) {
    $data{'storage'}{'mapping'}{'p7ref'}{'types'}{'inference'} = {
        'handler'  => 'plugin.storage.inference',
        'priority' => 7,
    };
}
```

create var/inference-cache/ directory if missing.

**files to read**: `plugin.storage.checksum.init_code`, `plugin.storage.visual.init_code`

**pitfalls**: use `<system.root_path>` for path construction. `base.logs` not `base.log`.

---

### plugin.storage.inference.store

store inference result to disk and register in cluster.

**input**:
```perl
{
    'question'    => $question_text,      # raw question/prompt
    'response'    => $response_text,      # LLM response
    'model'       => $model_id,           # amos checksum or name
    'temperature' => $temp,               # generation temperature
    'finish_reason' => $reason,           # stop, length, etc
    'tags'        => [],                  # optional categorization
    'refs'        => [],                  # optional related L13 checksums
}
```

**flow**:
1. compute question L13: `<[chk-sum.bmw.L13-str]>->($question_text)`
2. compute response B32-224: `<[chk-sum.bmw.224.B32]>->($response_text)`
3. compute response L13: `<[chk-sum.bmw.L13-str]>->($response_text)`
4. check entropy divergence against existing responses at this branch
5. if below threshold → increment hit, return cached, skip disk write
6. create branch directory if new: `var/inference-cache/<L13-question>/`
7. write result file: `results/<B32-224-response>`
8. write meta file: `meta/<B32-224-response>.meta`
9. update `.meta` (question text, hit_count++)
10. create cluster entry via `plugin.storage.checksum.cluster.add` if cluster module available
11. create symlink refs if `refs` provided
12. emit awareness event via `context.tree.summary.add-event` if available

**return**: `{ mode => 'true', data => { branch => $L13, result => $B32, cached => 0|1 } }`

**files to read**: `plugin.storage.checksum.map-file`, `plugin.storage.checksum.cluster.add`

**pitfalls**:
- use `base.chk-sum.bmw.*` not raw Digest::BMW (swap boundary safety)
- use `$code{'chk-sum.bmw.L13-str'}` if called during init (before swap)
- file permissions 0664, directory 0775
- no `my $call` in non-cmd modules
- newlines in response: safe on disk, collapse for protocol framing only

---

### plugin.storage.inference.lookup

find cached response for a question.

**input**:
```perl
{
    'question'    => $question_text,    # OR:
    'checksum'    => $L13_checksum,     # direct lookup by branch address
    'max_results' => 5,                 # how many responses to return
    'prefer'      => 'recent',          # recent | hits | model:$id
}
```

**flow**:
1. resolve L13 from question text or use provided checksum
2. check in-memory `branches` hot index first
3. check disk: `var/inference-cache/<L13>/` exists?
4. read `.meta` for branch metadata, increment hit_count
5. scan `results/` directory, read corresponding `meta/*.meta` files
6. rank by preference (recency, hit count, specific model)
7. return best result(s)
8. emit awareness event (cache hit or miss)

**return**:
```perl
{
    'mode' => 'true',       # or 'false' for cache miss
    'data' => {
        'branch'    => $L13,
        'hit_count' => $count,
        'results'   => [
            {
                'checksum'      => $B32_224,
                'content'       => $response_text,
                'model'         => $model_id,
                'timestamp'     => $epoch,
                'response_L13'  => $resp_L13,
            },
            ...
        ],
    },
}
```

**files to read**: `plugin.storage.checksum.lookup`, `context.cache.fetch`

---

### plugin.storage.inference.entropy

compare response divergence to decide if re-generation is warranted.

**input**:
```perl
{
    'branch'       => $L13,              # question branch
    'new_response' => $response_text,    # candidate response
    'threshold'    => 0.15,              # override default
}
```

**flow**:
1. compute L13 of new response
2. load existing response L13 values from branch meta files
3. compute hamming distance between new L13 and each existing L13
4. if min distance < threshold → responses are equivalent, return `converged`
5. if all distances > threshold → genuinely new perspective, return `divergent`
6. return divergence scores for all comparisons

**purpose**: avoid storing redundant near-identical responses while preserving
genuinely different perspectives (different model, different approach).

**files to read**: `plugin.storage.visual.proximity-calc` (hamming/distance patterns)

---

### plugin.storage.inference.attention

redistribute freed inference budget to high-value branches.

**concept**: when a cache hit saves an inference call, the saved tokens
become "attention budget" for the branch. branches with high hit counts
accumulate attention that can trigger:

1. **refinement** — re-ask the question with a better model or higher temperature
2. **expansion** — generate related questions and pre-cache responses
3. **summarization** — compress multiple responses into a canonical answer
4. **promotion** — move from disk cache to in-memory hot cache

**input**:
```perl
{
    'branch'       => $L13,
    'saved_tokens' => $count,     # tokens not spent due to cache hit
    'action'       => 'auto',     # auto | refine | expand | summarize | promote
}
```

**integration points**:
- `context.tree.summary.add-event` — log attention allocation as awareness event
- `context.priority.rank` — use existing priority infrastructure for ranking
- `coding.ask-reply` — dispatch refinement inference to local model

**estimated complexity**: medium — depends on how deep the auto-refinement loop goes.
start with simple hit counting and manual refinement trigger, evolve to automatic.

---

### plugin.storage.inference (dispatch)

main dispatch module, same pattern as `plugin.storage.checksum`.

```perl
my $operation = $args->{operation} // 'lookup';

if    ( $operation eq 'store' )   { return <[plugin.storage.inference.store]>->($args)   }
elsif ( $operation eq 'lookup' )  { return <[plugin.storage.inference.lookup]>->($args)  }
elsif ( $operation eq 'entropy' ) { return <[plugin.storage.inference.entropy]>->($args) }
elsif ( $operation eq 'attention' ){ return <[plugin.storage.inference.attention]>->($args) }
else  { return { mode => 'false', data => "unknown operation: $operation" } }
```

---

## integration with coding zenka

### system prompt injection

modify `coding.handler.process-queued-task` to:

1. **before inference**: call `plugin.storage.inference.lookup` with the prompt
2. **on cache hit**: return cached response directly, skip HTTP call
3. **after inference**: call `plugin.storage.inference.store` with question+response
4. **awareness**: emit events for both paths

this is the minimal integration — coding zenka gains caching without
changing its ask-reply interface or task pipeline.

### context template for inference

new template: `data/yaml/context-templates/inference-review.yaml`

```yaml
---
name: inference-review
budget: 2000
sections:
  - provider: context.style.guide
    budget_pct: 15
    priority: 1
  - provider: context.file.extract
    budget_pct: 50
    priority: 2
    params:
      path: "{{target_module}}"
  - provider: context.tree.summary.get-branch
    budget_pct: 20
    priority: 3
    params:
      branch: "{{awareness_branch}}"
      format: narrative
      time_range: ["-1 hour", "now"]
  - provider: context.error.recent
    budget_pct: 15
    priority: 4
    optional: true
```

this gives the local model: style guide + file content + recent awareness + errors.

---

## P7REF integration

new reference type: `p7://inference:<L13-question-checksum>`

resolves to the branch directory. can append segments:

```
p7://inference:ABCDEFGHIJKLM                    # branch (question)
p7://inference:ABCDEFGHIJKLM|best               # highest-ranked response
p7://inference:ABCDEFGHIJKLM|<B32-224>           # specific response
p7://inference:ABCDEFGHIJKLM|meta                # branch metadata
```

---

## implementation order

### phase 1: foundation [ can do now ]

- [ ] `plugin.storage.inference.init_code` — registry, config, directory setup
- [ ] `plugin.storage.inference.store` — question+response → disk
- [ ] `plugin.storage.inference.lookup` — L13 → cached response
- [ ] `plugin.storage.inference` — dispatch module
- [ ] create `var/inference-cache/` directory

### phase 2: intelligence [ after phase 1 verified ]

- [ ] `plugin.storage.inference.entropy` — divergence checking
- [ ] integrate entropy check into store (skip near-duplicates)
- [ ] wire lookup into `coding.handler.process-queued-task` (cache-before-infer)
- [ ] wire store into process-queued-task (cache-after-infer)

### phase 3: awareness [ after phase 2 ]

- [ ] emit awareness tree events on hit/miss/store
- [ ] `plugin.storage.inference.attention` — basic hit counting + budget tracking
- [ ] register P7REF type handler for `inference://` resolution
- [ ] inference-review.yaml context template

### phase 4: self-refinement [ after phase 3 ]

- [ ] auto-refinement trigger for high-attention branches
- [ ] cross-reference discovery (symlink refs between related questions)
- [ ] summarization — compress multi-response branches into canonical answer
- [ ] visual plugin workflow: `inference-hot-branches`

---

## existing modules to read before implementation

| module | reason |
|--------|--------|
| `plugin.storage.checksum.init_code` | registry pattern to follow |
| `plugin.storage.checksum` | dispatch pattern |
| `plugin.storage.checksum.map-file` | LRU cache + reverse index pattern |
| `plugin.storage.checksum.cluster.create` | cluster creation for grouping |
| `plugin.storage.checksum.cluster.add` | member addition + overflow |
| `plugin.storage.checksum.cluster.lookup` | O(1) lookup pattern |
| `plugin.storage.p7ref.init_code` | type registration |
| `plugin.storage.p7ref.resolve` | type dispatch |
| `plugin.storage.visual.init_code` | workflow definition pattern |
| `context.cache.store` | in-memory cache pattern |
| `context.cache.fetch` | freshness checking |
| `context.tree.summary.add-event` | awareness event emission |
| `coding.handler.process-queued-task` | integration point for cache hook |
| `base.chk-sum.bmw.L13-str` | 13-char checksum |
| `base.chk-sum.bmw.224.B32` | base32 224-bit checksum |

---

## P7 coding conventions reminder

- `base.logs` for logging (NOT `base.log`) — sprintf format strings
- `TRUE=5, FALSE=0, UNKNOWN=2`
- `<[module.name]>->()` — closing `]>` BEFORE `->`
- `$code{'module.name'}->()` for swap-boundary safety
- file permissions 0664, directory 0775
- no `my $call` in non-cmd modules (runtime pre-declares it)
- no fake signature stubs — leave clean for signing
- lowercase comments, `[ bracket ]` annotations

---

## acceptance criteria

- [ ] inference results cached to disk in checksum-addressed directories
- [ ] cache lookup returns results without inference call
- [ ] entropy check prevents near-duplicate storage
- [ ] hit counter tracks branch popularity
- [ ] P7REF `inference:` type resolves to cache locations
- [ ] awareness events emitted on cache operations
- [ ] coding zenka transparently uses cache (no API change)
- [ ] self-refinement budget accumulates from cache hits

---

## references

- `data/md/design/P7REF-STORAGE.md` — unified addressing
- `data/md/design/CHECKSUM-CLUSTER-MAP.md` — cluster architecture
- `data/md/design/FRACTAL-DEDUPLICATION-AWARENESS.md` — unified theory
- `data/md/design/CONTEXT-AWARENESS-TREE.md` — awareness integration
- `data/md/design/CONTEXT-AWARENESS-TREE-TEMPORAL.md` — temporal branches
- `data/md/handover/LOCAL-LLM-INTEGRATION-2026-03-25.md` — local model roadmap
- `data/md/coding-tasks/next-steps-plan.md` — overall priority ordering
- `read-me/documentation/dev/epoch-content-addressable-storage.md` — 3-layer path design

#,,..,.,,,.,.,.,.,,..,,.,,..,,,,.,,.,,,.,,,,.,..,,...,...,,,,,.,.,,,.,,,.,,..,
#6QUH374OJW37KH3ML25ERZ2F7CBDLFMXKCPZUV7NJDNTOVHBEUOQ5IDMPKQI6AR23TL2WPVYS5Z5M
#\\\|6NYVJ3XJNKRCELJICHVV7JFQPXHM3AX4UR7VZR3IKVSEEHZEZYC \ / AMOS7 \ YOURUM ::
#\[7]TSYWS36V4IB53L4MOJRVDIJRBASRKKKV4XPNQBAQPRF442XZNEAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
