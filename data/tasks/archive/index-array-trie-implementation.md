## [:< ##

# task: index array trie — efficient ring implementation

implement the ring-trie geometry described in RING-TRIE-GEOMETRY.md as the
storage backend for the index zenka, replacing the current flat hash approach.

signatures_note: signing requires the encrypted source key — only the repository
owner can sign via `p7.sourcecode update-signatures`. do not attempt to sign.

---

## current state

- `<index.seq>` holds full sequence strings as hash keys (redundant prefix storage)
- `<index.level>->{1}` conflates all window sizes — no per-ring separation
- `index.deduplicate` runs windows 2..8 but routes all to one level
- `index.promote` assigns sequential addresses without ring awareness

## target structure

each ring N is an array of nodes, one per unique (N+1)-char sequence in corpus.
each node is an array ref:

```
[ '.',  child1, child2, ... ]   ← complete token, has children
[ '.' ]                         ← complete token, leaf (no children in corpus)
[ child1, child2, ... ]         ← interior prefix only, not a complete token
```

children are ordered by descending corpus frequency (rank = array index - 1
since index 0 is reserved for the sentinel).

---

## implementation steps

### step 1 — per-ring sequence tracking in index.deduplicate

change:
```perl
<index.seq>->{$seq}++;
```
to:
```perl
<index.level>->{$win}{$seq}++;
```

remove `<index.seq>` entirely from `index.init_code` — `<index.level>` now
holds per-ring frequency maps at all depths (ring 0 is chars, ring N is
(N+1)-char seqs).

### step 2 — index.rank rebuilds per-ring sorted arrays

for each ring depth in `<index.level>`:
- sort sequences by frequency descending (lexical tiebreak)
- assign rank (array index) as address within that ring
- store in `<index.addr>` keyed as `"$depth:$seq"` for lookup
- store reverse map in `<index.rank>` keyed as `"$depth:$rank"`

### step 3 — build array trie nodes

after ranking, for each sequence at ring N:
- look up its children at ring N+1 (sequences that extend it by one char)
- sort children by frequency
- build node array: `[ ($is_token ? '.' : ()), @children_ranked ]`
- store in `<index.trie>->{$depth}{$seq}` or as packed array

### step 4 — numerical path encoding

`index.address` returns the path as an array of per-ring ranks:

```perl
my @path;
for my $depth ( 0 .. length($token) - 1 ) {
    my $prefix = substr( $token, 0, $depth + 1 );
    push @path, <index.addr>->{"$depth:$prefix"} // undef;
}
return \@path;
```

undef in path means the prefix does not exist in corpus at that ring.

### step 5 — update index.stats

add per-ring counts to output:

```
ring 0 :   175 tokens
ring 1 :  4821 sequences
ring 2 : 18443 sequences
...
```

### step 6 — update index.export

serialize trie as nested arrays (YAML or msgpack). each node is a list:
first element is '.' or first child, rest are children ranked by freq.

---

## memory note

current `<index.seq>` with 136K entries at window 2..8 stores the full sequence
string as each hash key. the array trie stores each character once per ring depth,
shared across all paths. estimated savings: 60-80% of current seq storage.

---

## utf-8

each array slot holds one perl scalar (one unicode codepoint). no special
handling needed — perl strings are already codepoint sequences. the `.` sentinel
is a literal single-char string, never confused with a multi-char sequence.

---

## related files

- `data/md/design/RING-TRIE-GEOMETRY.md` — geometry and rationale
- `data/yaml/reasoning-templates/ring-trie-tight-packing.yaml` — template 22
- `src/index.deduplicate` — step 1 change here
- `src/index.rank` — step 2 change here
- `src/index.init_code` — remove `<index.seq>`, add `<index.trie>`
- `src/index.address` — step 4 change here
- `src/index.stats` — step 5 change here
- `src/index.export` — step 6 change here

#,,,.,.,.,...,...,.,.,.,.,,..,.,.,,..,.,,,,.,,..,,...,...,,.,,..,,,.,,.,,,..,,
#EXZRURDVCICGDBB5IRWRHVHBCQGAKFSSXKTWVZ7NAY4TXHTQTY3QVE4WBJ3UPXOBNXBKXROBB4VW2
#\\\|BLACU2LSHBHKFYXRDVUXS44BAR7XBJSYDUXIXQ7I662VVUDHB7I \ / AMOS7 \ YOURUM ::
#\[7]BFMV3EPB2E2W4LTAVLVOYUQQTLDKTHLYC2JK7AFBVCLKXDZQWOAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
