## [:< ##

# task: index zenka — boundary-terminal tracking

track which N-gram sequences end at a true word boundary (space or end-of-string)
in a parallel `<index.terminal>` hash. currently ALL trie nodes have `terminates=1`
hardcoded in `index.rank`, so `index.cmd.search` cannot distinguish interior
N-gram fragments from true terminals.

signatures_note: do NOT attempt to sign any files — only the repo owner can
sign via `v7.sourcecode update-signatures`.

kimi session bdd0dfe4 has the full analysis — dispatch there for review if needed.

---

## the problem

`index.rank` builds every trie node as `[ 1, pack('N*', @child_ranks) ]` —
the leading `1` is `terminates`, hardcoded for all nodes regardless of whether
the sequence actually appears at a word boundary.

result: `index.cmd.search` shows `[ exact ]` for any sequence that exists as
a trie node, including interior fragments like `zenk` (which never ends a word).

---

## the fix: `<index.terminal>` parallel hash

### module: index.deduplicate

in the inner loop, after recording `<index.level>->{$win}{$seq}++`, check if
the sequence ends at a word boundary:

```perl
for my $win ( $min_win .. $max_win ) {
    for ( my $pos = 0; $pos + $win <= length $text; $pos++ ) {
        my $seq = substr( $text, $pos, $win );
        next if $seq =~ m| |;
        <index.level>->{$win}{$seq}++;

        ## boundary check: true terminal if followed by space or EOS ##
        my $end = $pos + $win;
        if ( $end == length($text)
                or substr( $text, $end, 1 ) =~ m|[ \n\r\t]| ) {
            <index.terminal>->{$seq} = 1;
        }
    }
}
```

ring-0 single chars: track separately in `index.ingest` or `index.freq`
ingestion — a character is a terminal if it appears at EOS or before whitespace.
simplest: track via the same boundary check in deduplicate by treating $win=1
separately, or add a ring-0 pass in `index.ingest`.

### module: index.rank (lines 73, 90)

replace hardcoded `1` with terminal lookup:

```perl
## ring 0 ##
my $term = <index.terminal>->{ $char_ranked[$r] } ? 1 : 0;
push @ring0_nodes, [ $term, pack( 'N*', @child_ranks ) ];

## sequence rings ##
my $term = <index.terminal>->{$seq} ? 1 : 0;
push @nodes, [ $term, pack( 'N*', @child_ranks ) ];
```

### module: index.init_code

add initialization alongside the other hash inits:

```perl
<index.terminal> //= {};
```

### module: index.persist

add `terminal` to the saved state hash:

```perl
my $state = {
    'meta'     => { %{ <index.meta>     // {} } },
    'freq'     => { %{ <index.freq>     // {} } },
    'level'    => { ... },
    'terminal' => { %{ <index.terminal> // {} } },
};
```

### module: index.restore

restore terminal alongside the other hashes:

```perl
<index.terminal> = $state->{'terminal'} // {};
```

### module: index.cmd.search

use the trie node `terminates` flag (now accurate) to label the exact match:

```perl
if ($self_match) {
    my $is_terminal = $self_node->[0] ? 1 : 0;
    my $label = $is_terminal ? 'exact, terminal' : 'exact';
    push @lines,
        sprintf "  %6d  %s  [ %s, rank %s ]",
        $self_freq, $disp, $label, $self_rank;
}
```

---

## notes

- `<index.terminal>` is keyed by the raw sequence string, same key space as
  `<index.level>`; ring-0 chars are also valid keys
- a sequence is marked terminal on FIRST boundary occurrence; flag is sticky
  (never cleared by subsequent non-boundary occurrences)
- after implementing, re-run `index.rank` to rebuild trie with accurate flags;
  `.zxps` restore will need a one-time re-feed or manual `terminal` rebuild
  for the existing corpus
- `index.cmd.lookup` already reads `terminates` correctly from the trie node —
  no change needed there once `index.rank` is fixed

#,,,.,,,,,..,,,..,.,,,.,.,.,.,,,.,.,,,,.,,..,,.,.,...,...,.,.,..,,..,,,..,..,,
#7H3OSBJUIKRK2XQF66BKLMVMTL7HTXBJQIWS5L2ZAUQ7Z6MWMDDL3H2NYSH5RH2FQK6VC5IV3PMLA
#\\\|V27ADEH7A6GFYFBKBLUGIMBQFU3WHOICHLVB47DP5BZ6SDSKEAD \ / AMOS7 \ YOURUM ::
#\[7]VGRXVGF64UWUZG4E3YAQKCFMF5UVU7ARKHONFKFSJAX2DDK26UAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
