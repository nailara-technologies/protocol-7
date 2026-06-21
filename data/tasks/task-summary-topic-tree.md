# task: task-zenka semantic topic tree for self-improving summaries

## signatures note

do NOT add the single-line `#,,.,,,...` stub at end of new files.
leave files clean — signatures are added by the signing system automatically.

## objective

give the **task zenka** ownership of a persistent, self-improving **semantic
topic tree** of summaries. the tree is fed from two sources:

  1. MCP-triggered session/memory summaries — `bin/mcp-server-p7`'s
     `session_catchup` (and the other memory/summary tools) dispatch
     summarization to the **coding zenka**, which runs an llm and returns text
  2. the coding zenka's own top-level task summaries

today source [1] is one-shot and stateless — every `session_catchup` call
re-summarizes from scratch, nothing is cached, and repeated catch-ups on the
same session never accumulate precision. the goal is a tree of small,
subtopic-bound summary files that absorb only the deltas relevant to each
subtopic, with **lazy deduplication**, so repeated catch-ups stop regenerating
from scratch and precision rises over time without unbounded linear growth.

## why a tree, not one merged summary

an earlier draft of this design used a single combined "main" summary that
absorbed all deltas via periodic merge passes. rejected: repeatedly merging
into one summary degrades precision over many iterations [ each pass risks
losing detail or drifting ] and the file grows without bound.

the revised design is a **semantic tree of small, subtopic-bound files**. each
subtopic file only absorbs deltas relevant to its own topic, so per-topic
growth is bounded and merges stay high-precision [ small focused inputs to each
merge, never one ever-growing blob ]. this mirrors the topic-file + index
pattern this project already runs for its own ai memory
[ `data/ai-mem/kimi/MEMORY.md` + per-topic `.md` files ] — give the task/coding
zenka pair the architecture that already works, rather than inventing a new one.

## what to read first

```bash
sed -n '1,104p' data/tasks/valued-tree-task-zenka-integration.md  ## format + tone twin
grep -n 'session_catchup\|store_summary_focus' bin/mcp-server-p7  ## summarize dispatch + task_id return
head -60 modules/task.init_code                                   ## task data layout to match
ls modules/task.cmd.*                                             ## existing .cmd. command shape
ls modules/coding.tools.handler.note_*                            ## note_write/read/list to reuse
ls modules/coding.self_test.*                                     ## tier-0/tier-1 escalation to mirror
```

## context

### what exists

- MCP server: `bin/mcp-server-p7` — `session_catchup`, `store_summary_focus`,
  and the memory/summary tools dispatch to the coding zenka and get a
  `task_id` back synchronously on submit
- coding zenka note tools [ already listed in CLAUDE.md, on disk as
  `modules/coding.tools.handler.note_write` / `note_read` / `note_list` ] —
  per-`task_id` note storage; reuse these, do NOT build a new registry
- task zenka: `configuration/zenki/task/`, `modules/task.init_code`,
  `modules/task.cmd.*` [ create/claim/complete/result/... already present ]
- coding self-test tiered escalation: `modules/coding.self_test.*`
  [ tier-0 local / tier-1 / tier-2 ] — the classification step below mirrors
  this escalation shape
- ai-mem precedent: `data/ai-mem/kimi/MEMORY.md` + per-topic files — the exact
  index + small-topic-file pattern this tree reproduces
- design precedents to follow rather than re-derive:
  `topic-checksum-addressing.md`, `topic-checksum-tree-wire.md`
  [ content-addressed, not sequential ids ],
  `topic-checksum-parenting-namespace-trees.md` [ collision-protected
  classification / parenting ]

### what is needed

  1. `modules/task.cmd.summary-reference` — correlation-note recorder
  2. topic-tree on-disk structure + routing/classification of a delta to a
     subtopic
  3. checksum-indexed focus-variant deltas
  4. idle-detection + integration-pass merge

## namespace

topic files are addressed via a **dot-separated semantic namespace**,
mirroring the project's module dot-notation [ e.g. `modules/base.init_code` ]
— but purely as a *semantic topic subtree*, never a literal module/file path.
proposed scheme:

```
  task.summary.<area>.<subtopic>        ## task-zenka-native task summaries
  coding.session.<session-key>.<topic>  ## mcp-triggered session catch-ups
```

`<area>` / `<topic>` are semantic labels chosen by the classifier [ phase 2 ],
not filenames typed by a caller. on disk these map under a tree root, e.g.:

```
  data/topic-tree/<namespace-as-path>/<subtopic>.md   ## the merged subtopic file
  data/topic-tree/<namespace-as-path>/deltas/<chksum>.md  ## raw focus-variant deltas
  data/topic-tree/INDEX.md                             ## tree index, ai-mem style
```

the namespace is the addressing key; the path is one rendering of it. keep them
consistent so the index can list a subtopic by its dotted name.

## the correlation problem and its solution

the coding zenka knows its own `task_id`, but when a summarize task originates
from the MCP server the **originating context** [ session_id, client, focus
instruction, or memory-file path ] is known only to `bin/mcp-server-p7` at
request time. it is not passed into the coding-zenka task content, and the
coding zenka has no reason to know it.

solution — reuse the existing task-note mechanism, no new registry:

  1. MCP server submits the summarize job to the coding zenka and gets
     `task_id` back synchronously
  2. immediately after, it calls the **new task-zenka command**
     `task.summary-reference`, passing `task_id` plus the correlation context
     [ session_id / client / focus / memory-path, whichever applies ]
  3. `task.summary-reference`'s only job is to record "task `<task_id>`'s
     output is a summary input destined for the topic tree, here is its origin
     context." it does NOT fetch or process the coding-zenka output
  4. later, lazily, on its own schedule [ see idle pass, phase 4 ] the task
     zenka reads the completed coding-zenka output by `task_id`, recovers the
     correlation context recorded in step [3], and uses both together to route
     the content into the correct subtopic file [ creating the subtopic if none
     fits yet ]

correlation notes are stored via `note_write` under a **reserved note key /
prefix** [ e.g. `summary-ref:` ] so they do not collide with user-facing or
llm-facing notes already living under the same `task_id`. the task zenka finds
pending references by scanning that prefix [ via `note_list` / `note_read` ].

## task.cmd.summary-reference module

```
my $params  = shift // {};
my $task_id = $params->{'id'}        // return undef;
my $origin  = $params->{'origin'}    // {};   ## session_id / client / focus / memory_path
my $source  = $params->{'source'}    // 'mcp';  ## 'mcp' | 'coding-native'
```

- validates `task_id` is a known coding-zenka task id
- writes a correlation note under the reserved prefix:
  `summary-ref:<task_id>` → `{ origin => $origin, source => $source,
  state => 'pending', time => ntime() }`
- does NOT block on, fetch, or summarize the coding-zenka output
- returns `{ mode => true, data => "<task_id> referenced for topic tree" }`
  [ `.cmd.` reply must be a string — split any raw-hash helper into a separate
  non-`.cmd.` routine + thin wrapper ]

## notification default policy [ asymmetric ]

- **mcp-server-triggered tasks** [ `session_catchup` etc. dispatching to the
  coding zenka ]: `task.summary-reference` is sent **by default, automatically**
  for every newly-dispatched summarize task. exceptions [ no notification ]:
    - the call was served from an already-cached / already-integrated
      topic-tree summary, with no new coding-zenka task dispatched at all
    - the caller explicitly passed a parameter disabling it
- **coding-zenka-native tasks** [ the zenka's own internal task tree — subtasks,
  tool-call loops, self-test polling, vastly outnumbering anything worth
  indexing ]: default is **off**. only an explicit opt-in flag on submission of
  a *top-level*, user-meaningful task enables the notification.
  rationale: auto-notifying on every internal subtask floods the tree with
  noise; only whoever creates a top-level task can judge whether its outcome is
  summary-worthy.

## focus-variant indexing

when a different summarization focus / instruction is requested for what is
otherwise the same session/topic, store it as an **additional indexed delta**,
never an overwrite. index each delta via the project's existing **AMOS / BMW-L13
checksum-addressing** scheme [ `topic-checksum-addressing.md`,
`topic-checksum-tree-wire.md` — content-addressed, not sequential ids ] over
`focus + content`, so:

- the same focus+content combination dedupes naturally [ same checksum = same
  file, write is idempotent ]
- lookups stay consistent with how the rest of the project addresses content

deltas live at `data/topic-tree/<ns-path>/deltas/<chksum>.md` and carry a small
header [ source, origin context, focus, ntime, integrated-flag ].

## idle-triggered integration pass

when **both** the task zenka and the coding zenka have been idle for a
configurable threshold, an integration pass runs:

- it walks pending, not-yet-integrated focus-variant deltas grouped by topic
- for each topic, it merges that topic's pending deltas into the topic's
  subtopic file via an **actual llm synthesis call** — NOT naive concatenation
  [ concatenation is exactly the precision-degrading failure mode being
  avoided ]
- because each merge is scoped to one small subtopic file at a time, growth
  stays bounded and precision *increases* per pass instead of degrading
- raw focus-variant deltas are **retained** [ checksum-indexed ] even after
  integration — mark them `integrated`, do not delete — so nothing is lost if a
  later pass needs to re-derive or audit

idle detection should reuse whatever idle/heartbeat signal the task and coding
zenki already expose; the threshold is a config value [ `<system.root_path>/...`
relative if file-backed ]. guard any timer with a fallback interval [ undef
interval = max-rate loop ].

## topic routing / classification

deciding which existing subtopic a new delta belongs to [ or whether it warrants
a brand-new subtopic file ] reuses the classification / parenting approach from
`topic-checksum-parenting-namespace-trees.md`:

- **tier-0**: a cheap local-model [ coding-zenka locally-loaded model ]
  classification step — given the delta plus the current INDEX of subtopic names
  + one-line descriptors, pick the best-fit subtopic, or signal "new subtopic"
- **escalate** to a stronger model only when the tier-0 result is ambiguous
  [ low confidence / tie ], mirroring the existing tier-0/tier-1 self-test
  escalation in `modules/coding.self_test.*`
- a brand-new subtopic gets a checksum-parented name under its parent namespace
  to avoid collisions [ per the checksum-parenting design ]

## model assignment for actual file writes

the final subtopic-file synthesis/write — both **initial creation** and
**idle-pass integration merges** — is performed by the **Opus model** [ or
whichever the project's strongest configured model is ] so quality and style
best match project requirements. the cheaper routing/classification decision
[ above ] uses the coding zenka's locally-loaded model. route the write through
the coding zenka's model-pinning path [ tier-1.5 model-pinning is already
landed ] so the strong model is selected deterministically for the write step.

## phased implementation

### phase 1 — correlation: task.cmd.summary-reference + reserved notes

- `modules/task.cmd.summary-reference` per the module sketch above
- reserved note prefix `summary-ref:` written via the existing coding-zenka
  note tools; task zenka scans the prefix to find pending references
- `bin/mcp-server-p7`: after a summarize dispatch returns `task_id`, call
  `task.summary-reference` by default, honoring the two exceptions
  [ cache-hit, caller-disabled ]
- coding-zenka-native opt-in flag on top-level task submission [ default off ]

acceptance:
- dispatching `session_catchup` records a `summary-ref:<task_id>` note with the
  session origin context
- a cache-hit `session_catchup` records no note
- `task.summary-reference` returns a string reply, never a raw hash

### phase 2 — tree structure + routing/classification

- on-disk layout under `data/topic-tree/` [ subtopic file, deltas/, INDEX.md ]
- `task.*` routine that, given a completed `task_id` + recovered origin,
  classifies the content [ tier-0 local, escalate on ambiguity ] to an existing
  subtopic or a new checksum-parented one
- INDEX.md maintained ai-mem style [ dotted subtopic name + one-line descriptor ]

acceptance:
- a routed delta lands under the correct dotted namespace
- an unrelated delta opens a new subtopic without colliding names
- INDEX lists every subtopic by its dotted name

### phase 3 — checksum-indexed focus-variant deltas

- compute AMOS/BMW-L13 checksum over `focus + content`; write delta at
  `deltas/<chksum>.md` with header [ source, origin, focus, ntime, integrated:0 ]
- identical focus+content re-writes are idempotent [ same checksum ]

acceptance:
- two different foci on the same session produce two distinct delta files
- the same focus+content twice produces exactly one delta file

### phase 4 — idle detection + integration-pass merge

- detect both-zenki-idle over a configurable threshold [ reuse existing idle
  signals, fallback-guarded timer ]
- group pending deltas by topic; per topic, llm-synthesize them into the
  subtopic file using the strong [ Opus ] model
- mark merged deltas `integrated:1`, retain them; update INDEX
- never concatenate; never delete a delta

acceptance:
- after a pass, each touched subtopic file is a coherent synthesis [ not a
  concatenation ] and its pending deltas are marked integrated, not removed
- a second `session_catchup` on the same session reuses the integrated subtopic
  instead of regenerating from scratch
- repeated passes do not grow a subtopic file without bound

## style

- lowercase comments, `[ word ]` bracket annotations [ never `( word )` ]
- `$ARG` / `@ARG`, not `$_` / `@_`, where used implicitly
- `<task.summary.tree>->{}` for dotted data keys, not `$data{'...'}{}`
- `.cmd.` / whitelisted routines return `{ mode => true|false, data => STRING }`
  — split raw-hash helpers into separate non-`.cmd.` routines + thin wrapper
- use `<[base.logs]>->( N, fmt, args )` for logging, not warn/print
- config paths via `<system.root_path>/...`; never bare relative
- TRUE/FALSE constants, never literal 0/1
- check `modules/task.init_code` for the existing task data layout before
  writing — match the keys it already uses

## acceptance [ overall ]

- [ ] `session_catchup` auto-records a correlation reference by default; cache
      hits and explicit opt-out do not
- [ ] coding-zenka-native tasks record nothing unless top-level opt-in is set
- [ ] deltas are checksum-addressed and dedupe on identical focus+content
- [ ] routing places deltas under correct dotted semantic subtopics; new topics
      get collision-safe checksum-parented names
- [ ] idle pass merges per-subtopic via the strong model [ synthesis, not
      concatenation ], retains raw deltas, and bounds per-topic growth
- [ ] a repeated catch-up on the same session reuses the integrated subtopic
      rather than re-summarizing from scratch
- [ ] no regression in `task.init_code` loading or existing `task.cmd.*` / note
      tools

### dispatch

model: opus
reasoning: high

prompt: |
  Implement the task at data/tasks/task-summary-topic-tree.md

  Read the two reference task files in data/tasks/ for format, then read
  modules/task.init_code, the existing modules/task.cmd.* commands, and the
  coding-zenka note tools (modules/coding.tools.handler.note_*) before writing
  anything. Also read modules/coding.self_test.* for the tier-0/tier-1
  escalation shape this design reuses for classification.

  Build it in the four phases described, in order. Phase 1 (the new
  task.cmd.summary-reference command + reserved summary-ref: notes + the
  mcp-server-p7 default notification) is the unblocking piece — land and verify
  it before the tree structure. Reuse existing mechanisms: the note tools for
  correlation (no new registry), AMOS/BMW-L13 checksum addressing for deltas,
  the self-test escalation pattern for classification, model-pinning for the
  strong-model write. Follow the project's lowercase-comment, dot-notation
  style exactly. No signature stubs — the signing system adds them.

#,,,.,,,.,,,.,,.,,,..,..,,...,,.,,..,,..,,..,,..,,...,...,...,,.,,,,.,.,,,.,,,
#KUN3SCSV2A7T7IRMYXDZGRGP5AYRJQ5JTXXSSPHL6X7RPEYQUSK2CSJJWTMCFJ63FU2PHJ4PSETDM
#\\\|QQPOQLNJYC56KJDAWVLYHY2734AP7AGBL523NYWLWBMAB44O2W7 \ / AMOS7 \ YOURUM ::
#\[7]JJYVCKKK2WCPAKPO6Z5HCN3BUYOFULVX7Q2QVQV3LJDJISIIX2DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
