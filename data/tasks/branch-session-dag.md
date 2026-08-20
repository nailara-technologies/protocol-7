# task: branch.session.* — session dag, jump semantics, hop policy

## context

each llm session round is content-addressed by its checksum. the chain
of checksums forms a verifiable dag. jumping to any prior checksum creates
a new branch node with two parents. subtasks are registered jumps with
return slots. the task zenka schedules open nodes for parallel dispatch.

design reference: `data/md/design/BRANCH-OPEN-CAPACITY-SESSION-DAG.md`
design reference: `data/md/design/CONTEXT-TREE-UNIFIED-ARCHITECTURE.md`

## signatures note

do not modify or regenerate AMOS7 signature lines. leave them untouched.

## checksum chain

```perl
## each round checksum:
my $round_checksum = bmw384( $prior_checksum . $round_content );

## genesis node:
my $genesis = bmw384( 'branch.session.genesis' . $session_id );
```

the checksum replaces the opaque session uuid. `kimi -r <checksum>` resumes
from the exact content-addressed state. chain verification walks from
genesis to current node confirming each link.

## dag node structure

```perl
<branch.session.dag.$checksum> = {
    parents  => [ $resumed_state, $decision_point ],  ## two parents for jump nodes
                                                       ## one parent for add-round nodes
    content  => \$round_content,
    intent   => $intent_vector,    ## bound at branch creation
    state    => 'open',            ## open | closed | awaiting_return
    children => [],                ## checksums of nodes that branched from here
    return_slot => undef,          ## set if this node spawned a subtask
}
```

## hop scoring

all candidate next hops share the same key type:

```perl
{
    target  => $checksum,       ## content-addressed target node
    intent  => $intent_vector,  ## purpose of the hop
}
```

intent vectors:
- `complete-current` — add next round, stay in branch
- `explore-alternative` — jump to different branch
- `resolve-stuck` — jump back to last known-good checkpoint
- `return-subtask` — deliver result to awaiting parent
- `fork-new` — permanent jump, new intent, no return

## modules to create

### checksum chain
- `src/branch.session.round.checksum` — bmw384(prev_hash + content)
- `src/branch.session.chain.verify` — walk from genesis, confirm each link

### jump mechanics
- `src/branch.session.jump` — load context at checksum, create dag node
  with two parents (resumed_state + decision_point); update children list
  of both parents
- `src/branch.session.return_slot.register` — attach return handler to
  current node; set node state to `awaiting_return`
- `src/branch.session.return_slot.resolve` — deliver result to return
  handler; set node state to closed; trigger caller to resume
- `src/branch.session.fork` — jump with no return slot; bind new intent;
  node state open on new branch, caller never resumes

### dag management
- `src/branch.session.dag.node_add` — add node, record parent pair,
  append to parents' children lists
- `src/branch.session.dag.edges_from` — list all child checksums from
  a given node
- `src/branch.session.dag.open_list` — all nodes with state `open`
  (continuation capacity available)
- `src/branch.session.dag.parallel_dispatch` — for each open node above
  score threshold, dispatch to kimi session via `<[mcp.kimi_dispatch]>`

### hop policy
- `src/branch.session.policy.score` — query valued tree for
  `f(target_checksum, intent_vector)`; return numeric score
- `src/branch.session.policy.intent_bind` — bind intent vector to branch
  node; stored in dag node `intent` field
- `src/branch.session.policy.next_hop` — for a node, enumerate candidate
  hops, score all, return highest-scoring above threshold
- `src/branch.session.policy.threshold` — configurable minimum score
  for dispatch; below = branch demoted (equivalent to transport demotion)

## integration with task zenka

the task zenka's scheduling loop:

```perl
## each tick:
my @open = <[branch.session.dag.open_list]>->();
for my $node (@open) {
    my $hop = <[branch.session.policy.next_hop]>->($node);
    next unless defined $hop;
    <[branch.session.dag.parallel_dispatch]>->($hop)
        if <[branch.session.policy.threshold]>->($hop->{'score'});
}
```

a task IS a branch node with a bound intent vector. task state transitions
(open → in_progress → completed | blocked) are a subset of hop decisions.

## style

- `$ARG` not `$_`
- `<branch.session.dag.$checksum>->{}` for dag node access
- bmw384 via `AMOS7::Digest::BMW::bmw384`; encode to b32r for storage keys
- lowercase comments, `[ word ]` bracket annotations

## acceptance

- `p7c branch.session.round.checksum <prev> <content>` returns consistent checksum
- chain verify catches any tampered link
- jump creates node with two parents, both parent children lists updated
- registered return slot fires correctly when subtask resolves
- parallel dispatch calls kimi_dispatch for each open node above threshold

#,,.,,,..,.,,,.,.,,..,,.,,,,.,,,.,,,.,.,.,,,,,..,,...,...,.,.,..,,,,.,...,,.,,
#MZLUGKNZVBDPZQZSMJJFX7TTKSXZC4PDYG2UYPFOKEWOFQW2HKC6IO5LZIX2QXHQ4TY4X6IV6RLXK
#\\\|JLAYV7MYEXT4WJSPKDX7XASQL42UR7ZYKAKTSLWMO7TTVI6MVYY \ / AMOS7 \ YOURUM ::
#\[7]N5NS5ZA3GO4VJKINWWOY34GAZ23YILG4XFTZFKHRXTDMT4EYUWAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
