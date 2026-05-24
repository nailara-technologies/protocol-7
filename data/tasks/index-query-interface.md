# task: index zenka — query interface (address, decode, stats)

## context

part of the `index.*` zenka — numerical language deduplication tree.
this task implements the outward-facing query interface: looking up
numerical addresses for tokens, decoding addresses back to tokens,
and reporting the current disk geometry.

see `data/md/design/NUMERICAL-LANGUAGE-DEDUPLICATION-TREE.md` for full design.
data structures defined in task `index-init-data-structure.md`.

## signatures note

the module files will have 5-line AMOS7 signature footers already present.
do NOT modify, remove, or regenerate signatures. do NOT add stub signatures.
leave the footer exactly as-is. only edit code above the signature block.
the signature block begins with a line matching `^#,,`.

## modules to create

### `modules/index.address`

```
## [:< ##

# name = index.address
# descr = return numerical address for a token
```

`$ARG` is the token string. returns its numerical address from
`<index.addr>`. if token is `''` (empty string) returns -1 (the root).
if token not yet in index, returns undef.

```perl
return -1 if defined $ARG and $ARG eq '';    ## '' is -1, the root ##

my $addr = <index.addr>->{$ARG};
return $addr;    ## undef if not found ##
```

### `modules/index.decode`

```
## [:< ##

# name = index.decode
# descr = return token for a numerical address
```

`$ARG` is the numerical address. returns token from `<index.rank>`.
if address is -1, returns `''` (the root). if address not found, undef.

```perl
return '' if defined $ARG and $ARG == -1;    ## -1 is the root '' ##

my $token = <index.rank>->{$ARG};
return $token;
```

### `modules/index.stats`

```
## [:< ##

# name = index.stats
# descr = report current disk geometry as formatted string
```

returns a formatted string showing:
- total unique tokens at disk 0
- top 13 inner ring tokens (most frequent) with their addresses
- total sequences at disk 1 (if any)
- total chars ingested

format should be human-readable, suitable for `p7c index.stats` output.

```perl
my $total_chars  = <index.meta>->{'total'}  // 0;
my $total_tokens = scalar keys %{ <index.freq> // {} };
my $total_seqs   = scalar keys %{ <index.level>->{1} // {} };

my @inner = map  { [ $ARG, <index.addr>->{$ARG}, <index.freq>->{$ARG} ] }
            sort { <index.freq>->{$b} <=> <index.freq>->{$a} }
            keys %{ <index.freq> // {} };

my $top_n = 13;
@inner = @inner[ 0 .. ( $top_n - 1 < $#inner ? $top_n - 1 : $#inner ) ];

my @lines;
push @lines, sprintf "index disk geometry";
push @lines, sprintf "  chars ingested : %d", $total_chars;
push @lines, sprintf "  unique tokens  : %d  [ disk 0 ]", $total_tokens;
push @lines, sprintf "  sequences      : %d  [ disk 1 ]", $total_seqs;
push @lines, sprintf "  inner ring [ top %d ] :", scalar @inner;
for my $entry ( @inner ) {
    push @lines, sprintf "    %4d  %s  [ freq %d ]",
        $entry->[1], $entry->[0], $entry->[2];
}

return join "\n", @lines;
```

the command handler should use `{ mode => 'size', data => $result }` reply
format per standard list reply convention.

## success criteria

- [ ] `index.address` returns -1 for `''`
- [ ] `index.address` returns correct address for known tokens
- [ ] `index.address` returns undef for unknown tokens
- [ ] `index.decode` returns `''` for -1
- [ ] `index.decode` returns correct token for known addresses
- [ ] `index.stats` shows top 13 inner ring tokens with address + freq
- [ ] `index.stats` shows disk 0 total, disk 1 total, chars ingested
- [ ] `index.stats` uses `{ mode => 'size', data => $str }` reply format
- [ ] uses `$ARG` not `$_`
- [ ] uses FALSE/TRUE constants not 0/1
- [ ] no stub signatures
- [ ] all modules pass ptd

#,,,,,..,,..,,,..,.,.,.,.,,.,,.,.,.,.,,..,,,,,..,,...,...,,.,,,,,,,..,.,.,,.,,
#66LFCFYDHMNN7D7IDHIYSDRM7YJYCLCF2HSL3VWO7XYPRUWWKGACMH6AXJMZON3TDZ2ZWDBOIQTMK
#\\\|FMUBMLQFPRHBIA2GIGCRFWASO6I5I3OMIS2O4NUU43JXYE62NAN \ / AMOS7 \ YOURUM ::
#\[7]J4FPNZA3VI4EZQMOWCMNRWKI6J2QCQKVRDJ73SHACI566EHM5ODY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
