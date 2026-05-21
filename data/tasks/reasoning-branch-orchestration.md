## [:< ##

# name  = task: reasoning.branch.* — generic parallel reasoning orchestration
# descr = implement branch orchestration primitives for any reasoning agent

## kimi memory

if in doubt about P7 patterns, coding style, or project context — read first:
```bash
cat data/ai-mem/kimi/MEMORY.md
cat data/ai-mem/kimi/coding-style.md
cat data/ai-mem/kimi/topic-zenki-creation-guide.md
```

## context

design doc: `data/md/development/PARALLEL-REASONING-ORCHESTRATION.md`

kimi-cli instances, coding zenka inference tasks, and task zenka subtasks
all share the same problem: parallel reasoning with dependencies, stuck
branches, and rescue needs. implement a generic `reasoning.branch.*`
module namespace that any agent plugs into.

this extends the existing task zenka into a universal execution engine
for agents — not just tracking human tasks but coordinating parallel
reasoning flows with dependency resolution and stuck-branch recovery.

## signatures note

do not add signature stubs. do not run `bin/Protocol-7 sourcecode update-signatures`.
do not add or modify subroutine whitelists — these are managed separately.

---

## what to read first

```bash
cat data/md/development/PARALLEL-REASONING-ORCHESTRATION.md  ## full design
cat modules/task.init_code                  ## existing task zenka state
cat modules/coding.handler.process-queued-task  ## existing coding zenka queue
cat modules/letsencr.parent.handler_renewal_check  ## timer-based branch example
## check how task zenka currently tracks subtasks:
ls modules/task.*
```

---

## modules to implement

### reasoning.branch.register

registers a branch with the orchestrator. stores in task zenka's branch
registry with initial state `running`:

```perl
## [:< ##
# name  = reasoning.branch.register
# param = { id, agent, task_id, deps, context_path }

## deps: list of branch IDs this branch waits for
## context_path: path to session cache file (context.jsonl) if applicable
## agent: 'kimi-cli' | 'coding' | 'task' | custom
```

### reasoning.branch.checkpoint

saves current branch state snapshot. for kimi-cli: records session cache
path. for coding zenka: records task progress. for any agent: timestamp +
activity summary:

```perl
## [:< ##
# name  = reasoning.branch.checkpoint
# param = { id, activity_summary, output_so_far }
```

### reasoning.branch.stuck_score

computes stuck score from recent checkpoint history:
- rounds since last new file written
- rounds since last unique module/file read  
- semantic similarity of last N activity summaries (high = looping)
- returns 0.0 (active) to 1.0 (completely stuck)

```perl
## [:< ##
# name  = reasoning.branch.stuck_score
# param = $branch_id
# return = $score (0.0..1.0)
```

### reasoning.branch.spawn_rescue

spawns a rescue branch when stuck_score exceeds threshold.
distills context from stuck branch, creates new branch with alt entry:

```perl
## [:< ##
# name  = reasoning.branch.spawn_rescue
# param = { id, strategy }
## strategy: hint for rescue entry point
## reads context from stuck branch session cache
## creates new branch with distilled context + alt approach instruction
```

### reasoning.branch.resolve

marks branch as resolved, stores output, notifies waiting dependents:

```perl
## [:< ##
# name  = reasoning.branch.resolve
# param = { id, output }
## output stored in branch registry
## dependents with this id in their deps list → resume
```

### reasoning.branch.inject

appends context to a paused branch (dependency resolved):

```perl
## [:< ##
# name  = reasoning.branch.inject
# param = { id, context, source_branch_id }
## appends to branch's context file at pause point
## sets branch state: paused → running
```

### reasoning.branch.status

returns current state of all branches as an ASCII tree visualization.
this is the primary monitoring interface — must be immediately readable
at a glance. follow the P7 lowercase narrative style, base.sort order,
framed output:

```
.: reasoning branches :.─────────────────────────────────────────

  ▶  letsencr-debug       [running  ] ████░░ 0.67 stuck
  │  └─ routing-alt       [running  ] ██░░░░ 0.23 stuck  ← rescue
  │
  ⏸  kimi-web-sessions    [paused   ] waiting: letsencr-debug
  │
  ✓  diff-modified        [resolved ] → '--no-color flag added'
  ✓  evaluate-javascript  [resolved ] → 'throw hack replaced'

──────────────── 2 running · 1 paused · 2 resolved ─────────────
```

visual conventions:
- `▶` running, `⏸` paused, `⚡` blocked/rescue pending, `✓` resolved
- stuck bar: `████░░` (filled = stuck ratio 0.0..1.0), score as float
- `← rescue` marker on rescue branches
- dependency arrows with `waiting:` label
- resolved branches show short output excerpt after `→`
- tree lines connect parent/child/rescue relationships
- footer: running · paused · resolved counts
- ANSI color when TTY: running=amber, paused=dim, resolved=green, rescue=violet

```perl
## [:< ##
# name  = reasoning.branch.status
# param = [$branch_id]  ## optional, all if omitted
## returns { mode => 'size', data => $ascii_tree }
```

---

## data structures

in task zenka's data namespace:

```perl
<reasoning.branch.registry> = {
    $id => {
        agent       => 'kimi-cli',
        task_id     => 'letsencr-debug',
        state       => 'running',    ## running|paused|blocked|rescue|resolved
        deps        => [],           ## branch IDs this waits for
        context_path => '~/.kimi/sessions/<uuid>/context.jsonl',
        checkpoints => [],           ## recent activity summaries
        stuck_score  => 0.0,
        output       => undef,       ## set on resolve
        rescue_of    => undef,       ## parent branch id if rescue
        spawned_at   => <ntime>,
    }
}
```

---

## integration with existing zenki

### task zenka integration

add to `task.init_code`:
```perl
<reasoning.branch.registry> //= {};
<reasoning.branch.stuck_threshold> //= 0.75;
<reasoning.branch.check_interval>  //= 300;  ## seconds
```

add a timer in task post-init that calls `reasoning.branch.stuck_score`
for all running branches and triggers rescue when threshold exceeded.

### coding zenka integration

in `coding.handler.process-queued-task`, wrap each task as a branch:
```perl
<[reasoning.branch.register]>->({
    id       => $task_id,
    agent    => 'coding',
    task_id  => $task_id,
    deps     => $task->{dependencies} // [],
});
```

on task complete: `<[reasoning.branch.resolve]>->({ id => $task_id, output => $result })`.

### kimi-web integration

when dispatching to kimi-cli instance, register as branch. monitor
via STRM for activity. checkpoint on each tool use. inject on dependency
resolution via terminal buffer append.

---

## test sequence

```bash
## register two branches, second depends on first
p7c reasoning.branch.register '{ "id": "b1", "agent": "test", "task_id": "t1", "deps": [] }'
p7c reasoning.branch.register '{ "id": "b2", "agent": "test", "task_id": "t2", "deps": ["b1"] }'

## check status — b2 should be paused waiting for b1
p7c reasoning.branch.status

## resolve b1 with output
p7c reasoning.branch.resolve '{ "id": "b1", "output": "found the answer" }'

## check status — b2 should now be running with b1 output injected
p7c reasoning.branch.status

## simulate stuck branch
p7c reasoning.branch.checkpoint '{ "id": "b2", "activity_summary": "re-reading same module" }'
p7c reasoning.branch.checkpoint '{ "id": "b2", "activity_summary": "re-reading same module" }'
p7c reasoning.branch.stuck_score 'b2'
## expected: high score

## trigger rescue
p7c reasoning.branch.spawn_rescue '{ "id": "b2", "strategy": "try different entry point" }'
p7c reasoning.branch.status
## expected: b2=blocked, b2-rescue=running
```

## success criteria

- [ ] `reasoning.branch.register` stores branch in task zenka registry
- [ ] `reasoning.branch.resolve` unlocks and resumes paused dependents
- [ ] `reasoning.branch.stuck_score` detects looping activity
- [ ] `reasoning.branch.spawn_rescue` creates alt branch with distilled context
- [ ] `reasoning.branch.inject` appends to paused branch context
- [ ] task zenka timer checks stuck scores periodically
- [ ] coding zenka wraps inference tasks as branches
- [ ] `status` output is an ASCII tree with visual stuck bars, state markers,
      dependency arrows, rescue labeling — readable at a glance
- [ ] ANSI color when TTY (running=amber, paused=dim, resolved=green, rescue=violet)
- [ ] no signature stubs, no whitelist changes

#,,,.,..,,...,.,,,...,,..,...,,..,.,,,,,.,.,.,..,,...,...,..,,,..,.,.,,.,,..,,
#YDZU2D7OOO5JP2VW332DLXIEBA3KDGIMLDN5CMTUXZSR24JGEGJIZTNF3EDW4ZIFOZGK7ID3PFXUE
#\\\|XAWJLX5KQN45HIWJGFTC7XRWBGUHE55B7ZSI3XZQ5VWWMWPFA6O \ / AMOS7 \ YOURUM ::
#\[7]QJLNB6ALHZOMRNASV5HSUIOBR2D7ZQUCNLGMD7B6WAKDSXHYF6BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
