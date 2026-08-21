# task: wire valued tree into task zenka state transitions

## relation to CONSOLE-FOLD-TREE-PHILOSOPHY

the valued tree is one of the canonical *foldable* substrates per
`data/md/design/CONSOLE-FOLD-TREE-PHILOSOPHY.md` — task nodes
collapse into one-line handles when not focused, and the same
addressing trinity (named tree + checksums + timestamps) underwrites
both task-state persistence and console fold-back. state transitions
recorded here become summary cells the fold handle can surface
without extra plumbing.

## objective

implement task zenka step 3 (state transitions + persistence) with valued
tree integration from the start. when a task transitions to `completed` or
`blocked`, call `valued.tree.record_outcome` on the task's valued tree node
id. this closes the feedback loop — task outcomes automatically update the
gradient.

## signatures note

do NOT add the single-line `#,,.,,,...` stub at end of new files.
leave files clean — signatures are added by the signing system automatically.

## context

### what exists

- task zenka scaffold: `cfg/zenki/task/` — start, start.cfg
- task zenka init: `src/task.init_code` — loads yaml files from
  `data/yaml/coding-tasks/` via `format.yaml.load_file`
- valued tree: `src/valued.*` — node create/add_ref/remove_ref/resolve,
  tree load/register_node/record_outcome
- task tree seed: `data/yaml/task-tree/` — root, branches, branches-intelligence,
  branches-meta-workflow
- existing task commands (partial): `src/task.cmd.*` if present

### what is needed

1. `src/task.transition` — state machine transitions
2. `src/task.cmd.start` — transition open → in_progress
3. `src/task.cmd.complete` — transition → completed + record_outcome
4. `src/task.cmd.block` — transition → blocked + record_outcome

## state machine

valid states: open → in_progress → completed | blocked | review
blocked → open (reset)
each transition appends to task's `history` list with timestamp + actor

## valued tree node id convention

task node ids in the valued tree follow the branch path from the task tree
seed files. examples:
  `intel.task-tree.state-machine`
  `intel.valued-trees.node-lifecycle`
  `infra.httpd`

for tasks loaded from `data/yaml/coding-tasks/` that have no explicit
valued tree node, use `task.<yaml-filename-without-extension>` as the
node id. create the node if it does not exist (weight: 0.0, parent: ROOT).

## task.transition module

```
my $params  = shift // {};
my $task_id = $params->{'id'}     // return undef;
my $to      = $params->{'to'}     // return undef;
my $actor   = $params->{'actor'}  // 'system';
my $note    = $params->{'note'}   // '';
```

- validates the transition is legal for current state
- updates task hashref in memory
- appends history entry: `{ time => ntime(), to => $to, actor => $actor, note => $note }`
- persists updated task back to yaml file via `format.yaml.write_file` (or
  equivalent — check what exists in `src/format.yaml.*`)
- calls `valued.tree.record_outcome` with outcome mapped from state:
  completed → 'completed', blocked → 'blocked', all others → no call

## style

- lowercase comments, `[ word ]` bracket annotations
- `$ARG` not `$_`, `@ARG` not `@_` where used implicitly
- `<valued.index>->{}` not `$data{'valued.index'}{}` for dotted data keys
- use `<[base.logs]>->( N, fmt, args )` for logging, not warn/print
- check `src/task.init_code` for existing data structure layout before
  writing — match whatever keys it already uses for task storage

## acceptance

- `p7c task.start <id>` transitions a loaded task to in_progress
- `p7c task.complete <id>` transitions to completed, yaml updated,
  valued tree node refs incremented
- `p7c task.block <id> <reason>` transitions to blocked, refs decremented
- history section present in yaml after each transition
- no regression in task.init_code yaml loading

#,,,.,.,.,,,.,,,.,.,,,,,.,.,,,...,...,..,,..,,..,,...,..,,,.,,,,.,.,,,..,,,,,,
#IFTDWTPC5XONJKN64AGKZM6XMF7XRRQBDW3CWKI7E6Z6LDP7JWGXTEDJIOQOBTUZTXWUW7BP5AQGS
#\\\|OHSQR4CDUIP7EBO6JVK3BEOLQEGE4EJMFKZTCYLPEVMUH6OU7XH \ / AMOS7 \ YOURUM ::
#\[7]CW7DRYFRCNC4XG5HOPXYY52AWWFPCB5UDKBRAMXLX3F4NUHX62CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
