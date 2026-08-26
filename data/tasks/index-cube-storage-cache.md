## [:< ##

# task: index zenka — compartment cache

implement `index.cube.cache` — a ring-frequency-weighted LRU cache above the
mmap layer. inner rings (depth 0-1) are pinned; outer rings evict by a
frequency × recency score. eviction drops only the deserialized perl
structure; the mmap'd bytes remain forever.

design reference: `data/md/design/INDEX-CUBE-STORAGE.md`

signatures_note: do NOT attempt to sign any files — only the repo owner can
sign via `v7.sourcecode update-signatures`.

---

## module: index.cube.cache (new)

### eviction policy

```
weight = base_frequency / (depth + 1)
```

inner-ring compartments have higher weight and stay resident longer.
high-frequency prefixes (small ranks) have higher weight regardless of depth.
cold compartments evaporate back to their mmap'd bytes; the next access
re-deserializes them.

ring 0 and ring 1 are implicitly pinned — they are loaded eagerly on startup
and never evicted. a `pin` flag on directory entries allows explicit retention
of additional rings via configuration if workload patterns warrant it.

### data structures

```perl
<index.cube.cache.max_entries> //= 50_000;   ## configurable cap

<index.cube.cache.lru> = [                   ## ordered list of (depth, rank)
    ## most-recently touched at tail, least-recently at head
];

<index.cube.cache.hits>   //= 0;
<index.cube.cache.misses> //= 0;
```

### cache access

on compartment access (via `index.cube.get_compartment`):

```perl
my $key = [ $depth, $rank ];

## hit ##
if ( exists <index.cube.loaded>->{$depth}{$rank} ) {
    <index.cube.cache.hits>++;
    <[index.cube.cache.touch]>->($key);     ## move to LRU tail
    return <index.cube.loaded>->{$depth}{$rank};
}

## miss ##
<index.cube.cache.misses>++;
my $comp = <[index.cube.load_compartment]>->( $depth, $rank );
return unless defined $comp;

<index.cube.loaded>->{$depth}{$rank} = $comp;
push @{ <index.cube.cache.lru> }, $key;

<[index.cube.cache.evict_if_needed]>->();
return $comp;
```

### touch

move the accessed key to the tail of the LRU list:

```perl
my $key = shift;
<index.cube.cache.lru> = [
    grep { $_->[0] != $key->[0] || $_->[1] != $key->[1] }
    @{ <index.cube.cache.lru> }
];
push @{ <index.cube.cache.lru> }, $key;
```

### eviction

when `scalar keys %{ <index.cube.loaded> }` exceeds `max_entries`:

```perl
while ( scalar keys %{ <index.cube.loaded> } > <index.cube.cache.max_entries> ) {
    my $victim = shift @{ <index.cube.cache.lru> };
    next unless defined $victim;

    my ( $vd, $vr ) = @$victim;

    ## skip pinned rings ##
    next if $vd <= 1;

    ## skip explicitly pinned entries (flag check via directory) ##
    my $entry = <[index.cube.read_dir_entry]>->( $vd, $vr );
    next if $entry->{'flags'} & DIR_FLAG_PINNED;

    ## evaporate: drop perl struct, keep mmap bytes ##
    delete <index.cube.loaded>->{$vd}{$vr};
}
```

---

## module: index.cmd.cache-stats (new)

diagnostic command — show hit/miss counts and loaded compartment count by ring.

```perl
# name  = index.cmd.cache-stats
# descr = show compartment cache statistics
```

```perl
my @lines;
push @lines, 'compartment cache stats :';
push @lines, '  hits   : ' . <index.cube.cache.hits>;
push @lines, '  misses : ' . <index.cube.cache.misses>;

my %by_ring;
for my $depth ( keys %{ <index.cube.loaded> // {} } ) {
    $by_ring{$depth} = scalar keys %{ <index.cube.loaded>->{$depth} };
}
for my $depth ( sort { $a <=> $b } keys %by_ring ) {
    my $label = $depth <= 1 ? "ring $depth (pinned)" : "ring $depth";
    push @lines, "  $label : $by_ring{$depth} loaded";
}

my $total = scalar @{ <index.cube.cache.lru> // [] };
push @lines, "  lru entries : $total";

return { 'mode' => 'size', 'data' => join("\n", @lines) . "\n" };
```

---

## notes

- prerequisite: `index-cube-storage-reader` task
- cache entries are soft references — the perl structures are mortal, but the
  file bytes are permanent. this mirrors the harmonic tree property.
- the default `max_entries` of 50,000 deserialized compartments balances
  memory use against query latency. for a corpus with ~100K compartments,
  this keeps the hot path entirely in RAM while allowing outer rings to cycle.
- the LRU list stores only `(depth, rank)` tuples — the actual compartment
  data lives in `<index.cube.loaded>`. this keeps the eviction metadata small.

#,,.,,,.,,,..,...,,..,.,,,..,,,,,,,..,.,,,...,..,,...,...,..,,..,,,..,..,,,,,,
#SBWX64XTJVKHD4MELSINTHAEE2TPTX646E4FC2UKJR27D3ORKULY4UD4VHKKYY3ZMJMZZW7ZCPJBY
#\\\|NBAI5KUAG6747C3XTZOUOKMF5RPTPI7DZAQOAF2RVNEHT7DKOAY \ / AMOS7 \ YOURUM ::
#\[7]CQ7YLWWAK7PVO6NPJMF53EJKYIH3SGIFTFTHQWJ6VCKACTYPB4AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
