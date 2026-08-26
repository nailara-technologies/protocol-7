## [:< ##

# task: index zenka — contribution vector store

implement `<index.contributions>` — a checksum-keyed store of sparse N-gram
frequency delta maps. this is the foundational layer for corpus versioning:
replacement, removal, and rewind all depend on knowing exactly what each
content version contributed to the trie.

design reference: `data/md/design/INDEX-CORPUS-VERSIONING.md`

signatures_note: do NOT attempt to sign any files — only the repo owner can
sign via `v7.sourcecode update-signatures`.

---

## what it stores

```
<index.contributions>->{$checksum} = {
    'freq'  => { $char => $delta, ... },       ## ring-0 deltas
    'level' => { $win => { $seq => $delta } }, ## ring N-gram deltas
}
```

keyed by AMOS7 checksum of the ingested content. the delta is the count
added by THIS content version — not a cumulative total.

---

## module: index.ingest (or index.deduplicate)

capture deltas during ingest. the cleanest approach is to wrap `index.deduplicate`
with a snapshot diff: take `<index.freq>` / `<index.level>` counts before
and after, and store the difference as the contribution vector.

alternatively, compute inline during the N-gram scan (lower memory, one pass):

```perl
my $chk = <[base.checksum.amos]>->($text);    ## AMOS7 checksum of content

## skip if already contributed (deduplication) ##
return TRUE if exists <index.contributions>->{$chk};

## capture contribution inline during ingest ##
my %freq_delta;
my %level_delta;

## ring-0: character frequencies ##
for my $char ( split //, $text ) {
    my $before = <index.freq>->{$char} // 0;
    <index.freq>->{$char}++;
    $freq_delta{$char}++;
}

## ring N-grams: via deduplicate-style scan ##
for my $win ( $min_win .. $max_win ) {
    for ( my $pos = 0; $pos + $win <= length $text; $pos++ ) {
        my $seq = substr( $text, $pos, $win );
        next if $seq =~ m| |;
        <index.level>->{$win}{$seq}++;
        $level_delta{$win}{$seq}++;
    }
}

<index.contributions>->{$chk} = {
    'freq'  => \%freq_delta,
    'level' => \%level_delta,
};
```

note: the current `index.ingest` calls `index.deduplicate` separately. the
cleanest integration is to either:
(a) add checksum capture to `index.ingest` wrapping the existing calls, or
(b) extend `index.deduplicate` to accept and return delta maps.

option (a) is simpler and non-invasive.

---

## module: index.init_code

add:

```perl
<index.contributions> //= {};
```

---

## module: index.persist

add `contributions` to saved state:

```perl
'contributions' => { %{ <index.contributions> // {} } },
```

note: contributions can be large (one entry per unique content checksum).
for `.zxps` (XZ-compressed Storable) this compresses well — delta maps are
sparse and highly repetitive.

## module: index.restore

```perl
<index.contributions> = $state->{'contributions'} // {};
```

---

## module: index.cmd.contributions (new, optional)

diagnostic command — show stored contribution vector for a checksum:

```perl
# name  = index.cmd.contributions
# descr = show contribution vector for a content checksum
```

```perl
my $chk = $call->{'args'} // '';
return { 'mode' => 'false', 'data' => 'expected checksum' } unless length $chk;

my $cv = <index.contributions>->{$chk};
return { 'mode' => 'false', 'data' => 'not found' } unless defined $cv;

my @lines;
push @lines, "contributions [ $chk ] :";
my $freq_total = 0;
$freq_total += $ARG for values %{ $cv->{'freq'} // {} };
push @lines, "  ring 0 : $freq_total char deltas";
for my $win ( sort { $a <=> $b } keys %{ $cv->{'level'} // {} } ) {
    my $n = scalar keys %{ $cv->{'level'}{$win} };
    push @lines, "  ring ${\($win-1)} : $n sequence deltas";
}
return { 'mode' => 'size', 'data' => join("\n", @lines) . "\n" };
```

---

## notes

- prerequisite for `index-source-map-active-set` and `index-cmd-replace-remove`
- content deduplication is free: if checksum already exists in
  `<index.contributions>`, the content was already ingested — skip re-ingest
  entirely; this replaces the current character-level dedup in `index.ingest`
- delta keys with value 0 need not be stored; sparse representation
- for the existing corpus (7.2M chars, 730 files): contribution vectors can
  be rebuilt from scratch by re-feeding with the new instrumented ingest;
  or populated lazily on next replacement/removal operation

#,,..,,.,,,,.,,,,,.,,,.,,,..,,,.,,,.,,.,.,..,,.,.,...,...,...,.,.,.,.,..,,.,,,
#GVPXNQJEMFWVT362GDWCJ5A5JSAPCIMNUG4AOOGIAC6RFYHMDGBQCFH5UUQ2ZR3QPAFHNYA3ZYMHK
#\\\|RARTXGPTR3LLGTZYZ7VYOQBVAGKAGS6IQ4AVBCTBIOPCI4Q2F6K \ / AMOS7 \ YOURUM ::
#\[7]N7LLC7MRE6CRP2CP2FVT5RXFSFJ3SJXFOSSWXZCPXIXWD4VODIBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
