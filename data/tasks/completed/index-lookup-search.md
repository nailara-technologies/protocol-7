## [:< ##

# task: index zenka — lookup and search interface

implement hop-by-hop trie traversal and prefix search. these are the primary
query interfaces into the ring-trie geometry.

signatures_note: do NOT attempt to sign any files — signing requires the
encrypted source key, only the repo owner can sign via
`v7.sourcecode update-signatures`.

---

## current data structures (read these modules first)

- `src/index.rank` — builds all structures
- `src/index.address` — seq→rank lookup via `<index.addr>->{"$depth:$seq"}`
- `src/index.decode` — rank→seq via `substr(<index.packed_rank>->{$depth}, ...)`

key structures:
- `<index.addr>->{"$depth:$seq"}` — address (rank) of sequence at ring depth
- `<index.packed_rank>->{$depth}` — flat string, stride ($depth+1) chars per entry
- `<index.trie>->{$depth}` — arrayref of nodes indexed by rank
  each node: `[ $terminates, $packed_children ]`
  where $terminates = 1/0, $packed_children = pack('N*', @child_ranks_at_depth+1)
- `<index.freq>->{$char}` — character frequency (ring 0)
- `<index.level>->{$win}{$seq}` — sequence frequency (ring $win-1, win=2..8)

---

## module: index.lookup

```
# name  = index.lookup
# descr = hop-by-hop trie traversal — return trie node for a token path
```

input: a string token (any length). returns the trie node at the depth
corresponding to the token length, or undef if path doesn't exist.

```perl
my $token = @ARG ? shift : $ARG;
return undef if not defined $token or not length $token;

my $depth = length($token) - 1;    ## ring depth = length - 1

## verify path exists at each ring ##
for my $d ( 0 .. $depth ) {
    my $prefix = substr( $token, 0, $d + 1 );
    return undef if not defined <index.addr>->{"$d:$prefix"};
}

my $rank = <index.addr>->{"$depth:$token"};
return undef if not defined $rank;

my $node = <index.trie>->{$depth}[$rank];
return $node;
```

---

## module: index.search

```
# name  = index.search
# descr = prefix search — return ranked candidates extending a prefix
```

input: a prefix string. returns arrayref of [ $seq, $rank, $freq ] for all
sequences at the next ring depth that extend this prefix, ordered by frequency.

```perl
my $prefix = @ARG ? shift : $ARG;
return [] if not defined $prefix;

my $depth = length($prefix) - 1;    ## ring depth of prefix

## look up the trie node for this prefix ##
my $rank = <index.addr>->{"$depth:$prefix"};
return [] if not defined $rank;

my $node = <index.trie>->{$depth}[$rank];
return [] if not defined $node or not defined $node->[1];

## unpack child ranks at depth+1 ##
my $next_depth    = $depth + 1;
my @child_ranks   = unpack( 'N*', $node->[1] );
my $stride        = $next_depth + 1;
my $packed        = <index.packed_rank>->{$next_depth} // '';

my @results;
for my $cr (@child_ranks) {
    my $child_seq = substr( $packed, $cr * $stride, $stride );
    next if not length $child_seq;
    my $freq = <index.level>->{ $stride }{ $child_seq }
            // <index.freq>->{$child_seq}
            // 0;
    push @results, [ $child_seq, $cr, $freq ];
}

## already ordered by frequency (child_ranks are freq-sorted) ##
return \@results;
```

---

## module: index.cmd.lookup

```
# name  = index.cmd.lookup
# descr = command handler for index.lookup
```

```perl
my $token = $call->{'args'} // '';
return { 'mode' => 'false', 'data' => 'expected token' } unless length $token;

my $node = <[index.lookup]>->($token);
return { 'mode' => 'false', 'data' => 'not found' } unless defined $node;

my ( $terminates, $packed ) = @{$node};
my @child_ranks = defined $packed ? unpack( 'N*', $packed ) : ();
my $depth       = length($token) - 1;
my $next_depth  = $depth + 1;
my $stride      = $next_depth + 1;
my $packed_rank = <index.packed_rank>->{$next_depth} // '';

my @child_seqs = map {
    substr( $packed_rank, $ARG * $stride, $stride )
} @child_ranks;

my @lines;
push @lines, "token   : $token";
push @lines, "depth   : $depth";
push @lines, "address : " . ( <index.addr>->{"$depth:$token"} // '?' );
push @lines, "terminal: " . ( $terminates ? 'yes' : 'no' );
push @lines, "children: " . scalar(@child_seqs);
for my $child (@child_seqs) {
    my $child_rank = <index.addr>->{"$next_depth:$child"} // '?';
    push @lines, sprintf "  %4s  %s", $child_rank, $child;
}

return { 'mode' => 'size', 'data' => join( "\n", @lines ) };
```

---

## module: index.cmd.search

```
# name  = index.cmd.search
# descr = command handler for index.search
```

```perl
my $prefix = $call->{'args'} // '';
return { 'mode' => 'false', 'data' => 'expected prefix' } unless length $prefix;

my $results = <[index.search]>->($prefix);
return { 'mode' => 'false', 'data' => 'no results' } unless @{$results};

my @lines;
push @lines, sprintf "search [ %s ] — %d results :", $prefix, scalar @{$results};
for my $r ( @{$results} ) {
    push @lines, sprintf "  %6d  %s  [ rank %d ]", $r->[2], $r->[0], $r->[1];
}

return { 'mode' => 'size', 'data' => join( "\n", @lines ) };
```

---

## access list update

add `lookup search` to `access.cmd.usr.cube` in
`cfg/zenki/index/zenka.v7`

---

## notes

- both modules use `@ARG ? shift : $ARG` pattern — works in both calling
  conventions (explicit arg and $_ context)
- index.search returns results already frequency-ordered since child_ranks
  are stored in freq-descending order by index.rank
- for ring 0 tokens (single chars), depth=0 and children are at depth=1
- if `<index.level>` is empty (future: after explicit finalize), freq lookup
  falls back to `<index.freq>` for ring 0 chars

#,,.,,,,,,,.,,...,,..,,,.,.,,,.,.,,,.,,,,,,.,,..,,...,...,.,.,...,,,.,,..,,,,,
#FOQW3MTMENYJWDZVNFC34JZ4IRFPGEJQGMW7W4CKYWI3XJL2APBBFXH3C3LZXVID4ZSKGGKNMVO7E
#\\\|H5RFTZWJIVG6TOPTHTWLXNMUCWYGIGI5BNZJAXLCDHTXBYS66PR \ / AMOS7 \ YOURUM ::
#\[7]RDXF52OBNUM24QMHMRSE3STRTUIF7PHKKES2CNYX2R6XZSCJYCBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
