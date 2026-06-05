## task: memory-cmd-focus

## dispatch
create `modules/memory.cmd.focus` — a command dispatcher that exposes
the existing `memory.focus.*` modules as callable zenka commands. read first:
`modules/memory.focus.set`,
`modules/memory.focus.boost`,
`modules/memory.focus.apply`,
`modules/memory.focus.decay`,
`modules/memory.cmd.show`,
`modules/memory.startup`,
`configuration/zenki/memory/start`.
do NOT touch signatures or unrelated logic.

## problem
`memory.focus.set` and `memory.focus.boost` are implemented but unreachable
as commands — there is no `memory.cmd.focus` dispatch module. users must
resort to `eval-code` to set focus. `focus` is already in the access list
(`configuration/zenki/memory/start` line 13), so it will route correctly
once the module exists.

## implementation

### `modules/memory.cmd.focus` (NEW)

first arg is the sub-command: `set | boost | get | clear | apply`.

```
## [:< ##

# name = memory.cmd.focus
# descr = dispatch focus sub-commands: set | boost | get | clear | apply
```

**sub-commands:**

`set <topic> <score>` — call `memory.focus.set`, then re-flow + re-score:
```perl
my $ok = <[memory.focus.set]>->( $topic, $score );
return FALSE if not $ok;
<[memory.tree.flow]>->( { node => <memory.tree> } );
<[memory.tree.score]>->( { node => <memory.tree> } );
return TRUE;
```

`boost <topic> [multiplier]` — call `memory.focus.boost`, then re-flow + re-score:
```perl
my $ok = <[memory.focus.boost]>->( $topic, $mult );
return FALSE if not $ok;
<[memory.tree.flow]>->( { node => <memory.tree> } );
<[memory.tree.score]>->( { node => <memory.tree> } );
return TRUE;
```

`apply` — call `memory.focus.apply` then re-flow + re-score:
```perl
<[memory.focus.apply]>;
<[memory.tree.flow]>->( { node => <memory.tree> } );
<[memory.tree.score]>->( { node => <memory.tree> } );
return TRUE;
```

`clear [topic]` — with topic: delete `<memory.focus>->{$topic}` and
`<memory.focus_floor>->{$topic}`. without topic: clear entire
`<memory.focus>` and `<memory.focus_floor>` hashes. then re-flow + re-score.

`get` (or no sub-command) — return a SIZE reply listing current focus state,
one `topic = score` pair per line, sorted by score descending. if focus is
empty, return a single-line TRUE reply `[ no focus set ]`.

### return style

mutations return TRUE/FALSE (no payload). `get` returns SIZE reply via the
standard `{ mode => 'size', data => $string }` pattern (see `memory.cmd.show`
for the dispatch pattern, or `memory.render.term` for SIZE reply format).

## acceptance
- `p7c memory.focus set nshell 5` → TRUE, tree re-scored
- `p7c memory.focus boost stream` → TRUE, tree re-scored
- `p7c memory.focus get` → SIZE listing current focus vector
- `p7c memory.focus clear` → TRUE, all focus cleared, tree re-scored
- `p7c memory.focus apply` → TRUE (triggers index lookup if focus changed)
- no manual AMOS7 signature stubs in new or edited files

#,,.,,..,,.,.,.,.,,.,,...,.,,,,,,,..,,...,.,,,..,,...,...,.,.,..,,.,.,,,,,.,,,
#6PTC7LS5AXOPU2SLXPKEQUMDWCJWU6E75LRDLEIS22VUWTRM4EFEBXOE5WUGZCUYXPMB2QAJABWKM
#\\\|EOU4X2WFQLPECEDKSVYNP7A3JRXGIVG3MWU5LV4C7KHZWFLHHSO \ / AMOS7 \ YOURUM ::
#\[7]NQUVGQBZ3XIXNYGULCZABNBP3CC55WZ6RFVNI5ZRUILV3AMTAWDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
