## [:< ##

# task: index zenka — replace and remove commands

implement `index.cmd.replace` and `index.cmd.remove` — the user-facing commands
that perform source replacement and removal using the contribution vector model.

design reference: `data/md/design/INDEX-CORPUS-VERSIONING.md`
prerequisites:
  - `data/tasks/index-contribution-vector-store.md`
  - `data/tasks/index-source-map-active-set.md`

signatures_note: do NOT attempt to sign any files — only the repo owner can
sign via `v7.sourcecode update-signatures`.

---

## module: index.cmd.replace

replace the current content for a source with new content. updates source map,
deactivates old contribution vector, activates new one.

```perl
# name  = index.cmd.replace
# descr = replace indexed content for a source : deactivate old, activate new
```

```perl
my $args      = $call->{'args'} // '';
my $source_id = '';
my $new_content;

## args format: "source_id\n<content>" or "source_id <filepath>" ##
if ( $args =~ s|^(\S+)\n|| ) {
    $source_id   = $1;
    $new_content = $args;
} else {
    return { 'mode' => 'false', 'data' => 'expected: source_id\ncontent' };
}

return { 'mode' => 'false', 'data' => 'empty content' }
    unless length $new_content;

my $new_chk = <[base.checksum.amos]>->($new_content);
my $old_chk = <index.sources>->{$source_id};

## deactivate old if known ##
if ( defined $old_chk and $old_chk ne $new_chk ) {
    <[index.deactivate]>->($old_chk);
}

## ingest new content if not already contributed ##
unless ( exists <index.contributions>->{$new_chk} ) {
    <[index.ingest]>->($new_content);    ## populates contributions + freq/level ##
}

## activate new and update source map ##
<[index.source.register]>->( $source_id, $new_chk );

## rebuild trie ##
<[index.rank]>->();

my $old_label = defined $old_chk ? substr($old_chk, 0, 12) . '..' : 'none';
my $new_label = substr($new_chk, 0, 12) . '..';
return {
    'mode' => 'size',
    'data' => "replaced [ $source_id ]\n"
            . "  old : $old_label\n"
            . "  new : $new_label\n",
};
```

---

## module: index.cmd.remove

remove a source from the index entirely. deactivates its contribution vector
and removes it from the source map.

```perl
# name  = index.cmd.remove
# descr = remove a source from the index : deactivate its contribution vector
```

```perl
my $source_id = $call->{'args'} // '';
$source_id    =~ s{^\s+|\s+$}{}g;
return { 'mode' => 'false', 'data' => 'expected source_id' }
    unless length $source_id;

my $chk = <index.sources>->{$source_id};
return { 'mode' => 'false', 'data' => "not found [ $source_id ]" }
    unless defined $chk;

<[index.deactivate]>->($chk);
delete <index.sources>->{$source_id};
delete <index.chain_policy>->{$source_id};

## rebuild trie ##
<[index.rank]>->();

my $label = substr($chk, 0, 12) . '..';
return {
    'mode' => 'size',
    'data' => "removed [ $source_id ] [ chk: $label ]\n",
};
```

---

## access list

add to `cfg/zenki/index/zenka.v7` access.cmd entry:

```
replace remove
```

---

## whitelist

add to `cfg/zenki/index/subroutine.white-list`:

```
index.activate index.deactivate index.source.register
```

---

## notes

- `index.cmd.replace` with the same content (checksum unchanged) is a no-op
  at the trie level; source map pointer is updated but no trie rebuild needed
- `index.rank` call after deactivate/activate is expensive for large corpora;
  defer with dirty flag if batching multiple replacements (same :rebalance-later:
  pattern as feed-dir)
- removal is definition-agnostic: works identically for character N-grams,
  base32 tokens, diff-chunk checksums — the contribution vector is always the
  exact inverse of what was added
- for delta-policy chains: `index.cmd.remove` must walk the full chain and
  deactivate all ancestors, not just HEAD; under snapshot policy it is always
  exactly one deactivate call

#,,.,,.,,,,,.,...,.,.,,..,,..,..,,.,.,,,.,,,.,.,.,...,..,,...,,..,,,.,.,.,,.,,
#INA33WX25GBWPOO4C6ODC3NXK6PQLI3DSLKVXA7WGVUST2PUI5C35JSR4CICPS6NOFHEEAOSHQ3VM
#\\\|UK5O4UYIFFLIADBVI7RJIUQAZ4VHRGHAX7WTFHGICHES5AQM62I \ / AMOS7 \ YOURUM ::
#\[7]HCUSAMTLMZK45WBNLJP6RLFNKNDABZQSTBRRPHRYONEGIIMI3WDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
