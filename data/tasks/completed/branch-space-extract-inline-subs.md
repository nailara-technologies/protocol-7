# task: extract inline helper subs from branch.space.* modules

## relation

continues the inline-`sub _foo {}` cleanup series [ prior landings:
`base.stdio.frame.decode` -> `eff1ee210`, `base.stdio.frame.encode` +
`base.stdio.transport.emit` -> `4c5d518b9`, `tree.sort.trunk.*` -> this
session ]. found via:

```
ncode s src:branch.space 'sub _'
```

## the gap

four `branch.space.*` modules define 7 inline helper subs total, with
significant duplication across files:

- `modules/branch.space.balance`:
  - `_collect_subtree_balance( $root_id )` [ ~line 105 ]
- `modules/branch.space.magnetic_force`:
  - `_position_for( $id, $scope )` [ ~line 60 ]
- `modules/branch.space.rank`:
  - `_ref_count( $id )` [ ~line 100 ]
  - `_collect_subtree( $root_id )` [ ~line 115 ]
- `modules/branch.space.visible`:
  - `_build_visible_result( $observer_node, $node_set_aref, $scope )`
    [ ~line 105 ]
  - `_ref_count_visible( $id )` [ ~line 155 ]
  - `_collect_subtree_visible( $root_id )` [ ~line 170 ]

**duplication**:
- `_collect_subtree_balance` [ balance ], `_collect_subtree` [ rank ],
  and `_collect_subtree_visible` [ visible ] are functionally
  identical BFS-over-`branch.children` collectors [ the "skip root
  after first" check in `_collect_subtree_visible` never triggers in a
  normal tree, since root is only ever dequeued once ] — all three
  return the full subtree node-id list including the root.
- `_ref_count` [ rank ] and `_ref_count_visible` [ visible ] are
  byte-for-byte identical.

## scope

create 4 new sibling modules under `branch.space.util.*`:

### `branch.space.util.collect_subtree`
- `# param = $root_id`
- body = the shared BFS [ use the `_collect_subtree` /
  `_collect_subtree_balance` version — plain BFS, no root-skip check ]:
  ```perl
  my ($root_id) = @ARG;
  my @result    = ($root_id);
  my @queue     = ($root_id);
  while (@queue) {
      my $cur      = shift @queue;
      my $children = $data{'branch.children'}{$cur} // {};
      for my $name ( keys %$children ) {
          my $child_id = $children->{$name};
          push @result, $child_id;
          push @queue,  $child_id;
      }
  }
  return @result;
  ```
- replaces all 3 call sites:
  - `branch.space.balance`: `_collect_subtree_balance($root)` ->
    `<[branch.space.util.collect_subtree]>->($root)`
  - `branch.space.rank`: both `_collect_subtree($parent)` and
    `_collect_subtree($node_id)` ->
    `<[branch.space.util.collect_subtree]>->(...)`
  - `branch.space.visible`: both `_collect_subtree_visible($parent)`
    and `_collect_subtree_visible($observer_node)` ->
    `<[branch.space.util.collect_subtree]>->(...)`
- remove `_collect_subtree_balance`, `_collect_subtree`,
  `_collect_subtree_visible` and their `##[ ... ]##` divider comments
  from all 3 source files.

### `branch.space.util.ref_count`
- `# param = $id`
- body = the shared logic [ identical in both `_ref_count` and
  `_ref_count_visible` ]:
  ```perl
  my ($id) = @ARG;
  my $n = $data{'branch.nodes'}{$id} // {};
  return $n->{'ref_count'} if defined $n->{'ref_count'};

  my $root = $data{'branch.root'} // '';
  if ( length $root and exists $data{'branch.interest'}{$root}{$id} ) {
      return $data{'branch.interest'}{$root}{$id};
  }
  my $children = scalar keys %{ $data{'branch.children'}{$id} // {} };
  my $groups   = scalar @{ $n->{'groups'}                     // [] };
  return $children + $groups;
  ```
- replaces all call sites of `_ref_count(...)` in `branch.space.rank`
  and `_ref_count_visible(...)` in `branch.space.visible` [ including
  inside `_build_visible_result`, see below ] with
  `<[branch.space.util.ref_count]>->(...)`.
- remove `_ref_count` and `_ref_count_visible` definitions [ and their
  `##[ ... ]##` divider comments ] from `branch.space.rank` and
  `branch.space.visible`.

### `branch.space.util.position_for`
- `# param = $id, $scope`
- body = verbatim `_position_for` from `branch.space.magnetic_force`
  [ including its `<[branch.space.rank]>->(...)` call — keep the
  `<[...]>` invocation syntax as-is ].
- replace the 2 call sites of `_position_for(...)` in
  `branch.space.magnetic_force` with
  `<[branch.space.util.position_for]>->(...)`.
- remove `_position_for` definition and its `##[ ... ]##` divider
  comment from `branch.space.magnetic_force`.

### `branch.space.util.build_visible_result`
- `# param = $observer_node, $node_set_aref, $scope`
- body = verbatim `_build_visible_result` from `branch.space.visible`,
  with its internal `_ref_count_visible(...)` calls rewritten to
  `<[branch.space.util.ref_count]>->(...)`.
- replace the 1 call site in `branch.space.visible` [ omni-mode
  branch ] with `<[branch.space.util.build_visible_result]>->(...)`.
- remove `_build_visible_result` definition and its `##[ ... ]##`
  divider comment from `branch.space.visible`.

### registration

after all 4 new modules are created and source files updated:
- add all 4 new module names to `modules/base.list.subroutines`
  [ insert near other `branch.space.*` / `branch.*` entries, no
  strict alphabetical ordering required — follow existing local
  pattern ].
- add dependency-graph entries to
  `data/md/documentation/module-dependency-graph.asc`:
  - `branch.space.balance : ... branch.space.util.collect_subtree`
    [ append to existing deps line ]
  - `branch.space.magnetic_force : ... branch.space.util.position_for`
  - `branch.space.rank : ... branch.space.util.collect_subtree
    branch.space.util.ref_count`
  - `branch.space.visible : ... branch.space.util.collect_subtree
    branch.space.util.build_visible_result`
  - `branch.space.util.position_for : branch.space.rank`
  - `branch.space.util.build_visible_result :
    branch.space.util.ref_count`
  - `branch.space.util.collect_subtree` and
    `branch.space.util.ref_count` have no module deps [ leaf modules
    -- do NOT add an entry with empty deps, leaf modules are omitted
    entirely from this graph, matching existing convention ].

## non-goals

- no behavior change — pure refactor, same logic moved to sibling
  files.
- no changes to `branch.space.effective_position` or
  `branch.space.shell` [ not in scope, no inline subs ].
- `_build_visible_result`'s internal duplication of the
  rank/sort/shell-assignment logic [ also present inline in
  `branch.space.visible`'s main body ] is NOT to be further
  deduplicated in this task — only the 7 named inline subs listed
  above are in scope.

## acceptance criteria

- `ncode s src:branch.space 'sub _'` returns no matches.
- all 4 source modules [ `branch.space.balance`,
  `branch.space.magnetic_force`, `branch.space.rank`,
  `branch.space.visible` ] and all 4 new
  `branch.space.util.*` modules pass `perl -c` / syntax check.
- `p7c <zenka>.reload` [ whichever zenka loads `branch.*` modules —
  check `cfg/zenki/*/start` for `branch.space` in
  `modules.load` ] completes with no load errors.

## signatures note

no `#,,..` stubs. do NOT run update-signatures. lowercase comments,
`[ word ]` annotations, `$ARG` not `$_`, one-sub-per-file [ no inline
`sub {}` helpers ]. keep `# descr =` lines under 55 chars.

#,,.,,.,,,,,,,.,.,.,,,.,,,.,,,,,.,,,,,.,.,.,.,.,.,...,...,...,,.,,,,.,,.,,,,,,

#,,.,,,,,,,,,,..,,..,,,..,...,,,,,...,.,,,,.,,..,,...,..,,..,,,..,,..,,.,,.,,,
#Q5ZN7CX7IGMKRGRE62VPYDKUFVBBMA2ZX7DMJT7DCE2CJANNBZN7T6XH6F2AN45TMHQEIZW5YOVRC
#\\\|TU7V7T5GT7F7PTZKGFMVW5VMVVO2DORTU3IMIH44KQKPH6T5MVR \ / AMOS7 \ YOURUM ::
#\[7]N2GGFYKBVTPT5X3LXITHAG3HAQQ2MPFHJP3WO54WTMVP4WNGYOCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
