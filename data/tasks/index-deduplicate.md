# task: index zenka — deduplicate (sequence promotion)

## context

part of the `index.*` zenka — numerical language deduplication tree.
this task implements the deduplication layer: sliding window over ingested
text to detect repeating sequences, promoting them to higher-order tokens
on the next disk level. compression is gravity toward center.

see `data/md/design/NUMERICAL-LANGUAGE-DEDUPLICATION-TREE.md` for full design.
data structures defined in task `index-init-data-structure.md`.

## signatures note

the module files will have 5-line AMOS7 signature footers already present.
do NOT modify, remove, or regenerate signatures. do NOT add stub signatures.
leave the footer exactly as-is. only edit code above the signature block.
the signature block begins with a line matching `^#,,`.

## data structure

```perl
<index.seq>->{$sequence}    ## sequence -> freq count at disk N
<index.level>->{$n}         ## hashref of token => address at disk N
## disk 0 = characters, disk 1 = sequences, disk N = higher-order
```

## modules to create

### `modules/index.deduplicate`

```
## [:< ##

# name = index.deduplicate
# descr = detect repeating sequences and promote to higher-order tokens
```

sliding window scan over text. window sizes 2..8 characters (configurable,
default max 8). for each window position, extract substring, count
occurrences across the corpus. sequences occurring more than once are
candidates for promotion.

```perl
my $text    = ref $ARG ? $ARG->$* : $ARG;
my $max_win = <index.meta>->{'max_window'} // 8;
my $min_win = 2;
my $min_freq = 2;    ## must occur at least twice to be a sequence token ##

for my $win ( $min_win .. $max_win ) {
    my $pos = 0;
    while ( $pos + $win <= length $text ) {
        my $seq = substr( $text, $pos, $win );
        next if $seq =~ m| |;    ## skip sequences containing space ##
        <index.seq>->{$seq}++;
        $pos++;
    }
}

## promote sequences that exceed threshold to disk 1 ##
<[index.promote]>->();
```

### `modules/index.promote`

```
## [:< ##

# name = index.promote
# descr = move qualifying sequences from seq registry to disk 1+
```

takes all sequences in `<index.seq>` with count >= min_freq,
sorts by frequency descending, assigns addresses at disk 1 level.
sequences already in a higher disk are not re-promoted (check
`<index.level>->{1}` membership).

```perl
my $min_freq = <index.meta>->{'min_seq_freq'} // 2;

my %seq = %{ <index.seq> };

my @candidates = sort {
    $seq{$b} <=> $seq{$a} || $a cmp $b
} grep { $seq{$ARG} >= $min_freq } keys %seq;

<index.level>->{1} //= {};

my $addr = scalar keys %{ <index.level>->{1} };
for my $seq ( @candidates ) {
    next if exists <index.level>->{1}->{$seq};    ## already promoted ##
    <index.level>->{1}->{$seq} = $addr++;
}

my $promoted = scalar keys %{ <index.level>->{1} };
<[base.log]>->( 2, "index promote [ $promoted sequences at disk 1 ]" )
    if $promoted;
```

## integration note

`index.deduplicate` should be called from `index.feed.file` after ingest,
before rebalance. the order is:

1. `index.ingest` — character frequencies
2. `index.deduplicate` — sequence detection and promotion
3. `index.rebalance` — address reassignment

## success criteria

- [ ] `index.deduplicate` uses sliding window sizes 2..8
- [ ] `index.deduplicate` skips sequences containing space
- [ ] `index.deduplicate` increments `<index.seq>->{$seq}` correctly
- [ ] `index.promote` sorts candidates by frequency descending
- [ ] `index.promote` skips already-promoted sequences
- [ ] `index.promote` assigns sequential addresses within disk 1
- [ ] `<index.level>->{1}` populated after promotion
- [ ] uses `$ARG` not `$_`
- [ ] uses FALSE/TRUE constants not 0/1
- [ ] no stub signatures
- [ ] all modules pass ptd

#,,.,,...,,,,,,..,.,.,,..,,,,,.,.,.,.,,,,,,.,,..,,...,...,.,.,...,,,,,,.,,.,,,
#TLRYLXZQE6CGIPHB62GQLYPXCOZ3WUGYHXYXYV2NP427OWBBNQSRYWGCMM7KIPGMJFZL2X2HPFJFY
#\\\|VAYU7B7OUIULSCG4IIW7J2DKDRGT7QHNDB5F4P6B3TXIPQO2F2V \ / AMOS7 \ YOURUM ::
#\[7]5QH3GUFTLKSCJLAQHUIEJ4LN3OOG7RQZ7LMM7PFX6ONESHLAP6CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
