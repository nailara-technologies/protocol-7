## [:< ##

# task: index zenka — source map and active set

implement `<index.sources>` and `<index.active_checksums>` — the source-tracking
layer (L3) that sits above the index engine (L2). this layer owns the activation
policy (delta vs snapshot) and knows which content version is current for each
source.

design reference: `data/md/design/INDEX-CORPUS-VERSIONING.md`
prerequisite: `data/tasks/index-contribution-vector-store.md`

signatures_note: do NOT attempt to sign any files — only the repo owner can
sign via `p7.sourcecode update-signatures`.

---

## data structures

```perl
## source map: source_id → HEAD checksum ##
<index.sources>  = {};    ## { $source_id => $head_checksum }

## active set: which checksums are summed into the live trie ##
<index.active_checksums> = {};    ## { $checksum => 1 }

## per-chain policy: 'delta' or 'snapshot' ##
<index.chain_policy> = {};    ## { $source_id => 'snapshot' }
```

`source_id` is typically a file path (e.g. `data/md/design/INDEX-CORPUS-VERSIONING.md`)
but can be any stable string identifier.

---

## policy semantics

**snapshot policy** (recommended default):
- `<index.active_checksums>` contains only the HEAD checksum per source
- replacement: deactivate old HEAD, activate new HEAD
- active set size: O(1) per source

**delta policy** (for edit-history retention):
- active set contains the full chain root→HEAD
- each contribution vector is a diff, not a full snapshot
- active set size: O(chain length) per source
- enables partial rewind by deactivating tail of chain

for the current use case (file corpus, full-file granularity), snapshot policy
is correct. delta policy becomes relevant when feeding diff streams.

---

## module: index.init_code

add:

```perl
<index.sources>          //= {};
<index.active_checksums> //= {};
<index.chain_policy>     //= {};
```

---

## module: index.activate (new)

add a checksum to the active set — its contribution vector is now counted
in the live trie.

```perl
# name  = index.activate
# descr = mark a content checksum as active in the index
```

```perl
my $chk = shift // $ARG;
return FALSE unless defined $chk and exists <index.contributions>->{$chk};
<index.active_checksums>->{$chk} = 1;
<index.meta>->{'dirty'} = 1;
return TRUE;
```

---

## module: index.deactivate (new)

remove a checksum from the active set AND subtract its contribution vector
from the live trie.

```perl
# name  = index.deactivate
# descr = remove a checksum from the active set and subtract its contributions
```

```perl
my $chk = shift // $ARG;
return FALSE unless defined $chk;
return FALSE unless delete <index.active_checksums>->{$chk};

my $cv = <index.contributions>->{$chk} // return FALSE;

## subtract ring-0 deltas ##
for my $char ( keys %{ $cv->{'freq'} // {} } ) {
    <index.freq>->{$char} -= $cv->{'freq'}{$char};
    delete <index.freq>->{$char}
        if ( <index.freq>->{$char} // 0 ) <= 0;
}

## subtract ring N-gram deltas ##
for my $win ( keys %{ $cv->{'level'} // {} } ) {
    for my $seq ( keys %{ $cv->{'level'}{$win} } ) {
        <index.level>->{$win}{$seq} -= $cv->{'level'}{$win}{$seq};
        delete <index.level>->{$win}{$seq}
            if ( <index.level>->{$win}{$seq} // 0 ) <= 0;
    }
    delete <index.level>->{$win}
        unless keys %{ <index.level>->{$win} // {} };
}

<index.meta>->{'dirty'} = 1;
return TRUE;
```

note: after deactivation, `index.rank` must be called to rebuild the trie
from the updated `freq` / `level`. this is handled by `index.cmd.replace`
and `index.cmd.remove` after the pointer operations.

---

## module: index.source.register (new)

register a source and its initial HEAD checksum after first ingest:

```perl
# name  = index.source.register
# descr = register source_id with its HEAD checksum and activate
```

```perl
my ( $source_id, $chk, $policy ) = @ARG;
$policy //= 'snapshot';

<index.sources>->{$source_id}      = $chk;
<index.chain_policy>->{$source_id} = $policy;
<[index.activate]>->($chk);
return TRUE;
```

---

## module: index.persist / index.restore

add to saved state:

```perl
'sources'          => { %{ <index.sources>          // {} } },
'active_checksums' => { %{ <index.active_checksums> // {} } },
'chain_policy'     => { %{ <index.chain_policy>     // {} } },
```

restore:

```perl
<index.sources>          = $state->{'sources'}          // {};
<index.active_checksums> = $state->{'active_checksums'} // {};
<index.chain_policy>     = $state->{'chain_policy'}     // {};
```

---

## notes

- `<index.sources>` is the authoritative pointer for what is "current" per
  source; the active set follows from it via the activation policy
- deactivation rebuilds the trie from modified freq/level; this is O(corpus)
  but only happens on replace/remove, not on read operations
- for large corpora, defer trie rebuild with a dirty flag and rebuild lazily
  before next query (same pattern as `index.cmd.feed-dir :rebalance-later:`)
- existing corpus (7.2M chars) has no source map; populate incrementally as
  files are re-fed with the new instrumented ingest

#,,..,,,.,,,.,..,,,,.,,..,,,,,..,,,,,,.,,,,.,,.,.,...,...,..,,,..,.,.,,,.,,..,
#XKRB6HY3JVZN5XQRWC7LJATTBPATN7REMJTYTHYU2G6EZFEOFPYEJAEAFZQJCQKHWVEJDVX5ITKW6
#\\\|4HNI42JE7UEFTK6EZPOADNUVGWDDZQORGQ2ZMYSPPOSMRPNLW66 \ / AMOS7 \ YOURUM ::
#\[7]YYV5FVZ4A6F3DZC3OGYXQ4DVPRO3RVL4VLD33Q2UZGK6UVNNTABY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
