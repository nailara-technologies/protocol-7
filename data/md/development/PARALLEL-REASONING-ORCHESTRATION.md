# parallel reasoning orchestration

## overview

kimi-cli instances as branches in a managed task tree. not a flat queue —
a DAG with dependencies, auto-pause on blocked branches, context injection
on resolution, and on-demand rescue spawning for stuck branches.

the terminal buffer IS the reasoning state. pause = snapshot. inject =
append context. resume = continue from snapshot. the kimi-cli session
cache (context.jsonl) is the persistence layer for paused branches.

---

## task tree model

```
task tree (DAG)
  ├── letsencr-debug           [branch-1, kimi-cli]
  │   └── output: reply-routing-root-cause
  │       └── if stuck N rounds → spawn: routing-alt-approach [branch-3]
  │
  ├── kimi-web-sessions        [branch-2, kimi-cli]
  │   └── depends: letsencr-debug.reply-routing-root-cause
  │   └── status: PAUSED — waiting for dependency
  │       (terminal buffer snapshot preserved)
  │
  ├── diff-modified-nocolor    [branch-4, kimi-zenka]  — independent
  └── evaluate-javascript      [branch-5, kimi-zenka]  — independent
```

### branch states

| state | meaning | terminal buffer |
|---|---|---|
| `running` | active, consuming rounds | live |
| `paused` | waiting for dependency | snapshotted |
| `blocked` | stuck N rounds, no progress | snapshotted, rescue pending |
| `rescue` | alt-approach branch spawned | new instance |
| `resolved` | produced output | archived to context.jsonl |
| `terminated` | superseded by rescue | discarded |

---

## dependency resolution + context injection

when a dependency resolves, paused branches receive the output as injected
context and resume — not from scratch, but from exactly where they paused:

```
letsencr-debug resolves:
  output: "root cause: reply route registered in child %code context,
           not parent. fix: use route-send to parent session instead
           of send.local with reply handler."

kimi-web-sessions resumes:
  terminal buffer: [everything up to the pause point]
  injected: "[DEPENDENCY RESOLVED] letsencr-debug found: <output>"
  continues: "given that finding, the inject-context-to-coding command
              should route the reply back through the parent session..."
```

the injection point matters — it's not prepended as a system message but
appended at the exact conversation position where the branch paused. the
reasoning thread continues naturally.

---

## stuck branch detection + rescue spawning

stuck = N consecutive rounds with no new code written, no conclusion
reached, repeated re-reading of the same modules.

```
detector monitors each branch:
  - rounds since last file write
  - rounds since last unique module read
  - rounds since last hypothesis formed
  - semantic similarity of last N outputs (high similarity = looping)

if stuck_score > threshold:
  → snapshot current branch (context.jsonl)
  → spawn rescue branch with:
      - distilled context from stuck branch (what it found so far)
      - alternative entry point (different module, different hypothesis)
      - explicit instruction: "the main branch is stuck on X, approach
        from Y instead"
  → main branch enters BLOCKED state, waits
  → first branch to resolve injects conclusion into dependents
  → other branch terminated
```

### rescue branch strategies

when main branch is stuck, rescue tries different angles:

| main approach | rescue approach |
|---|---|
| reading base.handler.command | reading the enrollment (working) path instead |
| tracing forward from send.local | tracing backward from the error message |
| looking at parent process | looking at child process routing |
| reading P7 source | reading similar working pattern in other zenka |

the rescue branch doesn't re-read what the main already read — it gets
the distilled conclusions from the stuck branch and approaches the gap
from a different direction.

---

## speed management

overall throughput is NOT maximized by raw parallelism — it's managed by
dependency graph progress:

```
stage 1: all independent branches run in parallel
  letsencr-debug, diff-modified, evaluate-javascript

stage 2: resolved outputs unlock waiting branches
  letsencr-debug resolves → kimi-web-sessions resumes

stage 3: compound outputs unlock further dependencies
  kimi-web-sessions resolves → inject-into-coding pipeline ready
  → credentials-keyhold design could use session management findings
```

adding more parallel instances beyond the current dependency frontier
gives diminishing returns. the bottleneck is always the critical path
through the dependency graph, not raw instance count.

---

## terminal buffer as reasoning state

the terminal buffer is not just display — it's the full reasoning context:

```
buffer contents:
  [task file content]          ← initial context
  [modules read]               ← accumulated knowledge
  [hypotheses formed]          ← reasoning state
  [tool results]               ← evidence
  [conclusions reached]        ← output so far
  → [PAUSE POINT]
  [injected dependency output] ← when resumed
  [continued reasoning]        ← from pause point
```

the kimi-cli session cache (context.jsonl from llm-session-management.md)
persists this state across system restarts and process respawns.

`distill-session` on a paused branch produces a compact summary that
rescue branches can use as starting context — the reasoning state is
portable between instances.

---

## the rescue zenki satellite pattern

from the X-11 window registry design: when a node has an error, recovery
zenki orbit it — smaller processes trying alternative recovery paths while
the main process waits. the same pattern applies to reasoning branches:

```
main branch (stuck)
    ↕ context.jsonl
rescue branch A [alt approach 1] ←→ rescue branch B [alt approach 2]
    ↓ first to resolve
resolution injected into main + dependents
losing rescue branch terminated
```

multiple rescue branches can run simultaneously for severe blockages.
each tries a genuinely different angle (not just a retry).

---

## implementation in p7

### task tree zenka extension

extends the existing task zenka (`task-coordination.md`) with:
- branch state tracking (running/paused/blocked/rescue/resolved)
- dependency edges between tasks
- stuck detection (round counter + semantic similarity)
- rescue spawn trigger
- context injection on resolution
- terminal buffer snapshot management

### kimi-cli instance management

the kimi-web zenka (from `kimi-zenka-multiplexer.md`) manages instances:
- spawns new kimi-cli instances for new branches
- routes context injections to correct terminal buffers
- monitors stuck scores per instance
- triggers rescue spawns
- terminates superseded branches

### context flow protocol

```
p7c task.branch.pause   <id> <reason>     ## snapshot + wait
p7c task.branch.resume  <id> <context>    ## inject + continue
p7c task.branch.rescue  <id>              ## spawn alt approach
p7c task.branch.resolve <id> <output>     ## mark done, unlock dependents
p7c task.branch.status  [id]              ## show branch states
```

---

## generic module extraction

the branch orchestration primitives are not kimi-specific — they are
generic base modules any reasoning agent plugs into:

```perl
## reasoning.branch.*  — generic orchestration namespace

reasoning.branch.register    ## register branch with orchestrator
reasoning.branch.checkpoint  ## save current reasoning state
reasoning.branch.stuck_score ## compute from recent activity patterns
reasoning.branch.spawn_rescue ## trigger alt approach branch
reasoning.branch.resolve     ## mark done, unlock dependents
reasoning.branch.inject      ## append context to paused branch
reasoning.branch.status      ## query branch state
```

### agents that plug in

**coding zenka** — each inference task becomes a branch:
- stuck detection: tokens spent vs output produced
- rescue: try different model, different prompt angle, or smaller subtask
- existing `handler.process-queued-task` becomes a managed branch

**task zenka** — becomes the universal orchestration coordinator:
- holds the full DAG across all agent types
- calls `reasoning.branch.*` regardless of which agent handles each branch
- replaces ad-hoc "task status tracking" with proper branch state machine

**kimi-web** — manages kimi-cli instances as branches:
- terminal buffer = branch context
- STRM channel = branch output stream
- session cache = paused branch persistence

**any future agent** — implement `reasoning.branch.register` and receive
full orchestration: dependency management, stuck detection, rescue spawning.

the task zenka stops being a "task manager for humans" and becomes an
"execution engine for agents" — the DAG coordinator for all parallel
reasoning across the entire P7 network.

---

## connection to existing designs

| design | role |
|---|---|
| task-coordination.md | base task zenka, extend with branch states |
| kimi-zenka-multiplexer.md | instance management, STRM dispatch |
| llm-session-management.md | context.jsonl persistence for paused branches |
| x11-window-registry.md | rescue satellite pattern origin |
| reasoning templates 4+6 | seed sentence compression for stuck detection |

---

## example: letsencr debug session

```
branch-1: letsencr-debug
  round 1-20:  reads base.handler.command, enrollment path, renewal path
  round 21-40: stuck — re-reading same modules, no new hypothesis
  stuck_score: HIGH
  rescue spawned: branch-3 (approach from child routing, not parent)

branch-3: routing-alt-approach  
  context: distilled findings from branch-1 (what it already knows)
  entry: "the child process handles the renew-certificate command.
         trace how the child sends the reply back. don't re-read
         base.handler.command — branch-1 already mapped that."
  round 1-8: traces child → parent pipe → reply registration
  round 9:   CONCLUSION: "reply route registered against child session
             sid, not parent. parent's base.handler.command checks
             $code{handler} in the context of the child session."
  resolves → injects into branch-2 (kimi-web-sessions) which resumes
```

this is the same analysis that took 200K tokens in one branch, potentially
resolved in 50K by a rescue branch with a better entry point.

#,,..,,..,.,,,,.,,.,.,.,.,,.,,,,,,.,.,,..,.,.,..,,...,...,.,,,.,.,,,,,.,.,...,
#MVXTHEKJG43DJUG5J3SQJULKNLJFJYISLUZA65N43O6QCWZOXBWMI4IS2WUXDQUQNL3LOWWF6JCGS
#\\\|34U4BUPZXDQGUTDBUQ5QUWS3LQY4FK6ZLO6VODT7DLO4REAMM7U \ / AMOS7 \ YOURUM ::
#\[7]QFPCDJMYXY3GTJZL5LANJ2OAWBYXTXR7SJBPC2TFM5PCJADSDOAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
