# task: index zenka — ingest + rank + rebalance

## context

part of the `index.*` zenka — numerical language deduplication tree.
this task implements the core ingestion pipeline: feeding raw text in,
counting frequencies, ranking tokens by frequency, rebuilding address maps.

see `data/md/design/NUMERICAL-LANGUAGE-DEDUPLICATION-TREE.md` for full design.
data structures defined in task `index-init-data-structure.md`.

## signatures note

the module files will have 5-line AMOS7 signature footers already present.
do NOT modify, remove, or regenerate signatures. do NOT add stub signatures.
leave the footer exactly as-is. only edit code above the signature block.
the signature block begins with a line matching `^#,,`.

## data structure (already initialized by index.init_code)

```perl
<index.freq>->{$token}   ## frequency count — increment during ingest
<index.addr>->{$token}   ## token -> numerical address (rank, 0-based)
<index.rank>->{$addr}    ## address -> token (reverse map)
<index.meta>->{'total'}  ## total characters ingested
<index.meta>->{'dirty'}  ## set TRUE after ingest, cleared after rebalance
```

## modules to create

### `src/index.ingest`

```
## [:< ##

# name = index.ingest
# descr = stream raw text into frequency counts
```

receives `$ARG` as a scalar reference to raw text (or plain scalar).
splits into individual characters (not words — disk 0 is character level).
increments `<index.freq>->{$char}` for each character.
excludes space `' '` — space is the transport separator, not a token.
updates `<index.meta>->{'total'}`.
sets `<index.meta>->{'dirty'} = TRUE`.

```perl
my $text = ref $ARG ? $ARG->$* : $ARG;

for my $char ( split //, $text ) {
    next if $char eq ' ';    ## space is separator, excluded from index ##
    <index.freq>->{$char}++;
}

<index.meta>->{'total'} += length($text);
<index.meta>->{'dirty'}  = TRUE;
```

### `src/index.rank`

```
## [:< ##

# name = index.rank
# descr = assign numerical addresses by frequency rank
```

sorts all tokens in `<index.freq>` by frequency descending.
assigns address 0 to most frequent, 1 to next, etc.
rebuilds `<index.addr>` and `<index.rank>` maps completely.
`.` gets address 0 and `,` gets address 1 if corpus is empty or they are
most frequent — they are the baseline encoding from the signature footer.

```perl
my %freq = %{ <index.freq> };

## sort by frequency descending, then lexically for stable ordering ##
my @ranked = sort {
    $freq{$b} <=> $freq{$a} || $a cmp $b
} keys %freq;

<index.addr> = {};
<index.rank> = {};

my $addr = 0;
for my $token ( @ranked ) {
    <index.addr>->{$token} = $addr;
    <index.rank>->{$addr}  = $token;
    $addr++;
}

## update disk 0 with current rankings ##
<index.level>->{0} = { %{ <index.addr> } };
```

### `src/index.rebalance`

```
## [:< ##

# name = index.rebalance
# descr = rebalance address space after ingest
```

called after one or more ingest operations to rebuild the ranked address
space. only acts if `<index.meta>->{'dirty'}` is TRUE.

```perl
return if not <index.meta>->{'dirty'};

<[index.rank]>->();

<index.meta>->{'dirty'} = FALSE;

my $total = scalar keys %{ <index.freq> };
<[base.log]>->( 2, "index rebalanced [ $total unique tokens ]" );
```

## success criteria

- [ ] `index.ingest` splits text to characters, skips space, increments freq
- [ ] `index.ingest` accepts both scalar and scalar-ref
- [ ] `index.ingest` sets dirty flag after update
- [ ] `index.rank` sorts by frequency descending with stable lexical tiebreak
- [ ] `index.rank` rebuilds both `<index.addr>` and `<index.rank>` fully
- [ ] `index.rank` updates `<index.level>->{0}`
- [ ] `index.rebalance` is a no-op when dirty is FALSE
- [ ] `index.rebalance` clears dirty flag after rank
- [ ] uses `$ARG` not `$_`
- [ ] uses FALSE/TRUE constants not 0/1
- [ ] no stub signatures
- [ ] all modules pass ptd

#,,,,,,,,,.,,,,,.,,..,,..,,,.,..,,,,.,...,,..,..,,...,...,.,,,,..,,,.,,,,,,..,
#7A4PJUV44MVH4HPNDDSNFAXXT6OLNFFV2L7ZRER52AH6EOKP3WJAI6E76OKLP7JUDEAGL3XIAYXF6
#\\\|RHFO6PW4RFVK6HPMEYIPGA4LQHXZHP2A466PYUH3CUSGYIPWC3V \ / AMOS7 \ YOURUM ::
#\[7]D4V62VBGMEXVDMILHTMEOT73LFYLNX25MMFFOL6CJKKWJ6LQSCDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
