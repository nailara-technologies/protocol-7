## task: memory-cmd-search

## dispatch
create `modules/memory.cmd.search` and add `search` to the memory zenka
access list. read first:
`modules/memory.cmd.focus` (task memory-cmd-focus, may be in progress),
`modules/memory.tree.render`,
`modules/memory.render.term`,
`modules/memory.focus.set`,
`modules/memory.focus.apply`,
`modules/memory.tree.flow`,
`modules/memory.tree.score`,
`modules/memory.tree.zoom`,
`modules/memory.source.index`,
`configuration/zenki/memory/start`.
do NOT touch signatures or unrelated logic.

## context: how focus + index wiring works

`memory.focus.apply` (called inside `memory.tree.render`) does two things:
1. pulls active tasks / recent commands into the focus vector
2. calls `memory.source.index` when the focus vector has changed keys —
   which sends async `index-mem.lookup` route-sends; replies come back via
   `memory.source.index.lookup_reply`, which boosts related tokens in
   `<memory.focus>` and caches them in `<memory.focus_index_cache>`

so the pipeline is: set focus → render → apply fires → index lookups sent
→ replies arrive asynchronously → focus expands → next render reflects them.

the search command follows this pipeline directly:

## implementation

### `modules/memory.cmd.search` (NEW)

```
## [:< ##

# name = memory.cmd.search
# descr = set focus to query terms, re-score tree, render top-N results
```

**args:** one or more query terms (space-separated). each becomes a focus
topic with a transient high boost (use 5.0 so results are clearly lifted).

**flow:**

```perl
my @terms = split /\s+/, ($ARG // '');
@terms = grep { length $_ >= 2 } @terms;
return FALSE if not @terms;

## [ set transient focus boost for each query term ]##
for my $term (@terms) {
    <[memory.focus.set]>->( lc($term), 5.0 );
}

## [ apply: triggers async index lookups if focus changed ]##
## [ index replies arrive later and expand focus further  ]##
<[memory.focus.apply]>;

## [ re-score with current (sync) focus — index expansion is async ]##
<[memory.tree.flow]>->( { node => <memory.tree> } );
<[memory.tree.score]>->( { node => <memory.tree> } );

## [ render and return top-N branches ]##
my $output = <[memory.tree.render]>->( { variant => 'compact' } );
return { 'mode' => 'size', 'data' => $output // "[ no results ]\n" };
```

note: the immediate render reflects direct substring matches and any cached
index relations from prior lookups. async index replies (which arrive within
~1s) update `<memory.focus>` for subsequent `memory.show` calls — no second
render needed in this command.

### `configuration/zenki/memory/start`

add `search` to the `access.cmd.usr.cube` list alongside the other commands:

```
access.cmd.usr.cube   = verify-instance commands heart reload \
                        show-buffer src-age src-ver list \
                        show render tree focus search init startup \
                        dedup summarize zoom \
                        ...
```

## acceptance
- `p7c memory.search nshell` → SIZE reply with tree ranked by nshell relevance
- `p7c memory.search stream transport` → SIZE reply with both terms boosted
- after search, `p7c memory.show` → tree still reflects the boosted focus
- async index lookups fire for each term (visible in logs at level 1)
- no manual AMOS7 signature stubs in new or edited files

#,,,.,..,,,,.,.,,,.,,,,,.,,,.,,,,,...,,,,,...,..,,...,...,.,.,..,,,.,,.,,,,,.,
#2RMYFNJMQPLZSZD7HQULNMSIOCOXMCBNPAWUPIVOLGMDRF4XDYKI2P23FE5UBIVFX6SUQ3CVDQERQ
#\\\|RFYXBQNTMCPQOEXGXGY46NWJ5ELES6EKTT4R3RV6L6SQYFSLYLT \ / AMOS7 \ YOURUM ::
#\[7]47BVWYGHRIJB5YJWRFRJAYKH2OU3IDQISQVPRKJJBDJHNWPDAGDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
