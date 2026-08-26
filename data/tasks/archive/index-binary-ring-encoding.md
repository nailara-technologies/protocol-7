## [:< ##

# task: index binary ring encoding — packed storage for outer rings

replace perl hash-per-entry storage with packed binary strings for the
rank→sequence direction and integer-packed child lists in trie nodes.
goal: reduce memory from ~800MB/million chars to a fraction of that.

signatures_note: do NOT attempt to sign any files — signing requires the
encrypted source key, only the repo owner can sign via
`p7.sourcecode update-signatures`.

---

## current structures (memory problem)

- `<index.rank>->{"$depth:$rank"}` — hash with string keys + string values
  261K+ entries at ring 7 alone, ~150 bytes overhead each = ~40MB just ring 7
- `<index.trie>->{$depth}{$seq}` — nested hash of array refs, children as
  string sequences repeated at every node
- `<index.level>->{$win}{$seq}` — raw frequency counts, should be freed after
  ranking completes (index.rank already uses them, then they're dead weight)

## target structures

### packed rank decode (rank → sequence)

replace `<index.rank>->{"$depth:$rank"}` with:

```perl
<index.packed_rank>->{$depth}
```

a single flat scalar string. all sequences at ring depth D are exactly D+1
characters long (ring 0 = 1 char, ring 1 = 2 chars, etc.). pack them in rank
order, concatenated:

```
rank 0 seq | rank 1 seq | rank 2 seq | ...
each entry is exactly ($depth + 1) chars wide — fixed stride, no separator needed
```

decode lookup:
```perl
substr( <index.packed_rank>->{$depth}, $rank * ($depth + 1), $depth + 1 )
```

encode (build during index.rank):
```perl
<index.packed_rank>->{$depth} = join '', @seqs_sorted_by_rank;
```

### packed trie children

replace child arrays of string sequences with packed uint32 rank lists:

```perl
## current: <index.trie>->{$depth}{$seq} = [ '.', 'lo', 'la', 'li', ... ]
## new:     <index.trie>->{$depth}{$seq} = { term => 1/0, children => $packed }
```

where `$packed = pack( 'N*', @child_ranks )` — each child is its rank at
depth+1, 4 bytes each. to decode a child: look up rank in
`<index.packed_rank>->{$depth+1}`.

alternatively keep the '.' sentinel at position 0 but pack remaining children:

```perl
<index.trie>->{$depth}{$seq} = [ $terminates, pack('N*', @child_ranks) ]
```

where `$terminates` is 1 or 0.

### free level data after ranking

in `index.rank`, after building addr/packed_rank structures, free the raw
frequency data:

```perl
delete <index.level>->{$depth};  ## no longer needed after ranking
```

this recovers the largest chunk — the per-ring frequency hashes are only
needed during the ranking pass.

---

## files to modify

- `src/index.rank` — build `<index.packed_rank>` instead of
  `<index.rank>` hash; pack child arrays; delete `<index.level>` entries
  after processing each depth
- `src/index.decode` — use `substr(<index.packed_rank>->{$depth}, ...)`
  instead of hash lookup
- `src/index.address` — unchanged (still uses `<index.addr>` hash)
- `src/index.stats` — unchanged (reads ring sizes from packed_rank length)
  note: ring N size = `length(<index.packed_rank>->{$depth}) / ($depth + 1)`
- `src/index.init_code` — add `<index.packed_rank> //= {}`; remove
  `<index.rank>` initialization if present
- `src/index.export` — update to read from packed_rank for serialization

## ring size from packed_rank

```perl
my $size = length( <index.packed_rank>->{$depth} // '' ) / ( $depth + 1 );
```

integer division — always exact since entries are fixed-width.

---

## expected gains

ring 7 (7-char sequences, 261K entries):
- current:  261K hash entries × ~150 bytes = ~39MB for rank→seq direction alone
- packed:   261K × 7 bytes = ~1.8MB  (22× reduction for that ring)
- children: packed uint32 lists vs array refs of strings — similar ratio

total expected: from ~2GB for 2.5M chars → well under 500MB

---

## notes

- `<index.addr>->{"$depth:$seq"}` (seq→rank) stays as a hash — it needs O(1)
  lookup by arbitrary string key, no packed equivalent
- utf-8: perl's substr is character-based when string has utf8 flag set.
  if sequences contain non-ascii, ensure consistent utf8 handling.
  safest: use `use bytes` scope around pack/substr operations, or store
  sequences as unicode-normalized before packing.
- `index.rebalance` calls `index.rank` — verify it still triggers correctly
  after these changes

#,,,,,,..,.,.,..,,,,,,..,,,..,.,,,,,.,,,,,...,..,,...,...,.,.,,,.,,..,...,,..,
#W2PYTCBGSPLOUDGVK7AFH42VDWRRJNEVWWC7RJXVYTVSNZHU34DDG3B743UPUDY3EFQSHQSTS4WCE
#\\\|IKRR5KWUAJO3RELEFDZTQQAGB2FXKVXFX67XBLOYOQTJ43YW5K2 \ / AMOS7 \ YOURUM ::
#\[7]5AXCJ4M34Q2QY665EMAWMP7AZLV7HGNSVV2UAKSWYELNPNVPXGAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
