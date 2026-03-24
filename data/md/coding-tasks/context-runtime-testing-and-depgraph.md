## [:< ##

# context.* runtime testing and dep-graph implementation
# descr = kimi continuation task: test context namespace, build dep-graph modules

---

## phase 1 — runtime verification

test the 33 context.* modules in a live zenka environment.

### setup
- add context.* to a test zenka's module whitelist [ mod-test or similar ]
- verify `context.init_code` creates config defaults in data hash
- check that `<context.cfg.chars_per_token>` and `<context.cfg.default_budget>` resolve

### template loading
- call `context.template.load` with `code-review` template name
- verify yaml parsing returns sections array with provider, budget_pct, priority
- test cache: second load should return cached copy

### composition
- call `context.compose.for_task` with `task_type => 'code-review'`
- verify it loads template, dispatches to available providers, respects budget
- test with a `target_file` variable pointing to a real module

### cache round-trip
- `context.cache.store` with test key and data
- `context.cache.fetch` — verify hit, check age
- `context.cache.invalidate` by tag — verify removal
- test ttl expiry [ store with ttl=1, sleep 2, fetch should miss ]

### delegation role resolution
- `context.delegate.role` with various task_types
- verify security-review prefers coding/nist-coder as executor
- verify self-delegation prevention works
- test explicit strategy override

### known risks
- `context.file.extract` regex fix: verify `m{}` works at runtime [ was `m||` ]
- `context.conversation.history` depends on `models.conversation.get_context`
  existing — verify graceful fallback if not loaded
- `context.share.export/import` memory-sync fallback path needs testing

---

## phase 2 — dep-graph modules

implement the dependency resolution layer for batch review pipeline.
design doc: `data/md/coding-tasks/context-batch-review-pipeline.md`

### module: context.module.dep_graph

build full bidirectional dependency graph for a file set.

```perl
## input ##
my $params = shift // {};
my $files  = $params->{'files'} // [];  ## arrayref of module paths
my $budget = $params->{'budget'} // 2000;

## output ##
return {
    'mode' => qw| true |,
    'data' => {
        'nodes' => \@nodes,      ## [ { module => name, size => tokens } ]
        'edges' => \@edges,      ## [ { from => A, to => B, type => 'calls' } ]
        'clusters' => \@clusters ## strongly connected components
    }
};
```

uses existing `context.module.dependencies` for per-file edge extraction.
add reverse edge detection: for each outgoing call, record incoming edge
on the target.

### module: context.module.dep_order

topological sort with SCC grouping.

- tarjan or kosaraju for SCC detection
- within each SCC: keep files together [ same review page ]
- between SCCs: topological order [ dependencies before dependents ]

### module: context.module.dep_pack

bin-pack ordered files into budget-sized pages.

- input: ordered file list from dep_order, page_budget in tokens
- output: array of pages, each page is array of file paths
- SCC members stay on same page when possible
- reserve 20% of page 2+ budget for iteration summary

---

## phase 3 — wire delegation

create a simple end-to-end test of the delegation flow:

1. kimi receives a code review request
2. calls `context.delegate.prepare` with task description + target file
3. `context.delegate.dispatch` routes to coding zenka
4. coding processes, replies
5. `context.delegate.handler.result` collects + verifies + caches
6. result forwarded back to kimi's handler

### needed
- coding zenka must be online and responsive
- test with a small module [ e.g., context.cache.store itself ]
- verify the full async chain completes

---

## coding style reminders

- `qw| word |` for scalar strings — this IS the style
- `m{}` when pattern contains pipes, `m||` otherwise
- lowercase comments, `[ bracket ]` annotations, `$ARG` not `$_`
- never add signature stubs — leave clean for signing
- see `data/ai-mem/kimi/coding-style.md`

#,,,.,..,,,.,,...,,,.,.,.,...,...,.,,,.,.,,.,,..,,...,...,..,,.,.,..,,,,,,.,,,
#PLLWDDICWGTTWTW2OBQ2PB53BVBNQV4M6MAPZRUAFSEZY4IM3UOXAC5D27OU7PBI64M7BUHCVEHU4
#\\\|WETJNRHU746THLZJYUCWBPNJS47UJOB2JX2L2ZQSCSSTV3NV6C4 \ / AMOS7 \ YOURUM ::
#\[7]DL6KLVSRJ3WB7JT3HA5ETJ3CGWAROESMRIBXPHV7WJIN5R56LWDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
