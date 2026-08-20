# fasttext memory pipeline — tasks

## context

design: [[FASTTEXT-CATEGORICAL-MEMORY]], [[LLM-EXOSKELETON-INTEGRATION]]
reasoning: [[categorical-compartmentalization]], [[syntax-as-technology]]

the goal is a working pipeline that:
1. assembles domain-specific corpora from existing codebase content
2. trains FastText embedding models per category
3. maintains rolling triple-window (prior/current/next) per category
4. loads the appropriate category combination at model instantiation
5. retrains automatically when trigger conditions are met

---

## phase 1 — corpus assembler

### task 1.1 — codebase corpus
```
## dispatch + prompt
collect all src/* files, cfg/zenki/** configs,
data/md/documentation/**, data/md/architecture/** into a flat text corpus.
strip AMOS7 signature blocks (last 5 lines of each file).
output: /etc/protocol-7/embeddings/codebase/corpus.txt
```

### task 1.2 — interaction-history corpus
```
## dispatch + prompt
collect all files from memory/ directory (*.md files matching user/feedback/
project/reference types), data/md/tasks/**, session summaries from
data/md/handover/**. concatenate with section headers preserved.
output: /etc/protocol-7/embeddings/interaction-history/corpus.txt
```

### task 1.3 — philosophical corpus
```
## dispatch + prompt
collect data/yaml/reasoning-templates/*.yaml,
data/md/design/*.md, data/md/vision/**, data/md/concepts/**.
output: /etc/protocol-7/embeddings/philosophical/corpus.txt
```

### task 1.4 — network-topology corpus
```
## dispatch + prompt
collect all cfg/zenki/*/access.zenki,
cfg/zenki/*/start, cfg/zenki/*/zenka-startup.v7.
focus on access control patterns, module load lists, routing structure.
output: /etc/protocol-7/embeddings/network-topology/corpus.txt
```

---

## phase 2 — FastText training wrapper

### task 2.1 — training script
```
## dispatch + prompt
write bin/dev/train-embedding:
  args: --category <name> --corpus <path> --output <dir>
  runs: fasttext skipgram -input <corpus> -output <dir>/next
         (or cbow depending on category — skipgram for sparse philosophical,
          cbow for dense codebase)
  on completion: compute drift score against current.bin if it exists
  drift metric: cosine similarity of top-1000 nearest neighbor lists
  if drift < threshold: auto-promote (next→current, current→prior)
  if drift >= threshold: write flag file, keep current active
  metadata.json: retrain timestamp, corpus line count, drift score, vector dim
```

### task 2.2 — drift threshold configuration
```
per-category drift thresholds (configurable in cfg/shared-params):
  codebase:           0.15  (structural, slow — low tolerance)
  interaction-history: 0.30  (biographical, medium — moderate tolerance)
  philosophical:      0.20  (foundational, slow — low-medium tolerance)
  network-topology:   0.10  (structural, very slow — very low tolerance)
```

---

## phase 3 — retrain trigger zenka

### task 3.1 — trigger detection module
```
## dispatch + prompt
write src/embeddings.check-retrain-triggers:
  watches for:
    - new file committed to data/yaml/reasoning-templates/ → trigger philosophical
    - new session summary in memory/ → trigger interaction-history
    - significant module count change in src/ → trigger codebase
    - access.zenki modification → trigger network-topology
  for each trigger: queue embeddings.retrain-category <category>
```

### task 3.2 — retrain command
```
write src/embeddings.cmd.retrain-category:
  args: category name
  runs corpus assembler for that category
  calls train-embedding script
  logs result (promoted / flagged / no change)
  accessible via: p7c embeddings.retrain-category <name>
```

### task 3.3 — access control
```
add to cfg/zenki/cube/access.zenki:
  access.cmd.usr.* = embeddings.retrain-category
  access.cmd.usr.embeddings = v7.notify_online v7.register_child
```

---

## phase 4 — session loader

### task 4.1 — category selection logic
```
## dispatch + prompt
write src/embeddings.select-categories:
  input: task_type, context_window_size, session_purpose
  returns: list of categories to load for this session
  defaults:
    - always: current-session (built fresh from present context)
    - codebase work: + codebase + interaction-history
    - reasoning/design: + philosophical + interaction-history
    - network changes: + network-topology + codebase
    - full context (large window): all categories
```

### task 4.2 — current-session corpus builder
```
write src/embeddings.build-session-corpus:
  called at session start
  assembles corpus from: current task context, open items from memory/,
  active topic files (next-steps, current branch topics)
  trains ephemeral FastText model for current-session category
  no rolling window needed — session-scoped, discarded on session end
```

### task 4.3 — loading interface
```
write src/embeddings.load-for-session:
  calls embeddings.select-categories
  for each selected category: loads current.bin
  for stability-sensitive tasks: also loads prior.bin
  returns: list of loaded geometry references for injection into prompt
```

---

## phase 5 — regex intelligence cache

### task 5.1 — cache structure
```
define tree structure under data/yaml/regex-cache/:
  codebase-patterns/naming.yaml
  codebase-patterns/module-structure.yaml
  codebase-patterns/command-routing.yaml
  reasoning-patterns/anti-entropic.yaml
  reasoning-patterns/holographic.yaml
  network-patterns/access-control.yaml
  network-patterns/session-routing.yaml
```

### task 5.2 — cache query module
```
write src/regex-cache.match:
  input: text string, optional category filter
  walks the tree depth-first, most-specific category first
  returns: matched pattern entry or undef
  entry fields: pattern, derived-from (reasoning chain id), confidence, last-matched
```

### task 5.3 — cache deposit module
```
write src/regex-cache.deposit:
  input: category, pattern string, reasoning chain id
  validates pattern compiles
  checks for existing similar pattern (avoid duplication)
  writes to appropriate category yaml file
  accessible via: p7c regex-cache.deposit <category> <pattern> <chain_id>
```

---

## phase 6 — integration with coding zenka

### task 6.1 — pre-reasoning cache check
```
modify coding.handler.process-queued-task:
  before LLM reasoning: call regex-cache.match on the task description
  if match found with high confidence: include matched pattern in prompt
    as "known pattern — verify applicability before reasoning fresh"
  this reduces redundant re-derivation of already-crystallized patterns
```

### task 6.2 — post-reasoning pattern extraction
```
modify coding.complete-analysis:
  after task completion: scan reasoning chain for crystallizable patterns
  candidate: reasoning step that resolves a class of problems, not just one instance
  if candidate found: prompt LLM to formulate as regex pattern
  call regex-cache.deposit with the result
```

---

## open questions

- which FastText binary / Perl binding to use? Text::FastText on CPAN,
  or shell out to fasttext binary? check sys-deps for availability
- vector dimension per category? (codebase: 100, philosophical: 200?)
- injection mechanism for the base model — prefix embedding vs retrieved
  context vs prompt construction? depends on which base model is active
- should the regex cache be content-addressed (AMOS7 checksum as key)
  to support deduplication and parenting? likely yes — aligns with
  checksum-parenting-namespace-trees design

#,,.,,,..,,,,,,,,,,.,,...,,..,,..,..,,...,..,,..,,...,.,.,,.,,,..,,..,..,,,,,,
#M25J7FE4KC6NVD4HIUXRAMDHC5HTNRHSJ6N7MDRWNBED6NBXH7YPTGCOOWS66PL3TZOA4IMMRDBEA
#\\\|SJ5CBB2KQOBU54U3SODKYJZWAWUODCDLYJBU22FP2TOISYSIDQN \ / AMOS7 \ YOURUM ::
#\[7]H3DGUGDL3LMJKILYUGTMXEFKARKBVF3LH4U6XNMD36XNSQ7ARUCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
