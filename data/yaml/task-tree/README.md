# task tree — seed structure

the task tree is the intelligence substrate of protocol-7. it is not a
task list — it is a gradient field where reference weight accumulates
upward toward the eternal root attractor.

## files

- `root.yaml` — eternal root node, the attractor
- `branches.yaml` — layer 1: top-level category branches
- `branches-intelligence.yaml` — layer 2: intelligence sub-branches
- `branches-meta-workflow.yaml` — layer 2: meta-workflow nodes (parallel, non-blocking)
- `session-state.yaml` — written by meta.session-summary on session end (auto-generated)

## how priority works

priority is never declared. it emerges from `value.refs` — how many
independent paths converge on a node. `task.next` follows the gradient:
highest `value.refs + value.weight` among nodes whose dependencies are met.

bootstrap weights (`value.weight`) seed the gradient before any activity
accumulates refs. they are initial estimates, not permanent assignments.
once the tree is live, accumulated refs dominate.

## how meta-workflow nodes work

meta-workflow nodes are not tasks. they fire as side-effects of outcomes
in the main task branches. they run in parallel, never block task execution,
and route their results back into the tree as:
- reference weight adjustments on branch nodes
- new observations (suggestions, questions) in the observations stash
- new child tasks spawned into the self-improvement branch
- session handover documents for next-session pickup

## valued tree format

each node carries:
```yaml
value:
  refs: N      # integer — how many other nodes reference this one
  weight: f    # float [0.0, 1.0) — applicability/confidence/bootstrap priority
```

effective priority = refs + weight. this is the N+f composite value
from the valued-trees design (data/md/coding-tasks/next-steps-plan.md §2.1).

## adding task items

leaf tasks go one level below branch nodes, following the same format.
they should reference their parent branch and list any `depends_on` nodes.
the task zenka loads these on startup and holds the live view.

#,,..,,,.,.,,,,,.,,,.,...,...,...,,..,.,,,,,.,..,,...,...,,..,.,.,,,.,,.,,...,
#4D5VVG34XG2DVQJNZY4DUDRYU7G6OSK4KQA4FQI4ATHBWHXZYHNFBOEMNQ34R5EQGUP7ABETYMJO6
#\\\|TVV2CQZR23QF4KOPXHLFNZ5HXA36KEPMJLHFOKQWKU7SRP554CP \ / AMOS7 \ YOURUM ::
#\[7]3EI5WXOZOXOI4MY3MMQTGPBO4H5BS3L2DQS65GPORFDHH3REFMCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
