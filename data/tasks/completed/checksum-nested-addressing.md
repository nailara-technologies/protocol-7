## [:< ##

# name  = task: collision-free nested checksum addressing [CHKSUM:NAME]
# descr = formalize the [OUTER:INNER] checksum nesting convention as a
#         first-class addressing primitive. the name itself provides the
#         entropy for collision exclusion of its children. arbitrary depth,
#         no lookup table required for ancestry reconstruction.

## the convention already works — formalize it

`amos-chksum` already produces the building blocks:

```bash
$ amos-chksum litter-7
JC762WY

$ amos-chksum JC762WY.litter-7
GGL6ANA
```

written as `[GGL6ANA:JC762WY]`:
- outer `GGL6ANA` = checksum of `<parent_checksum>.<name>` = collision-excluding child identity
- inner `JC762WY` = parent's own checksum = implicit parentage proof

properties:
- the parent's checksum participates in the child's entropy → no two children
  of different parents can produce the same outer checksum even if names match
- given the algorithm, the full ancestry chain reconstructs from any node
  without a lookup table
- recursive to arbitrary depth: `[D:C:B:A]` = nested four levels deep
- pure-checksum chains (no human-readable name) work identically

design doc: `data/md/design/CHECKSUM-CLUSTER-MAP.md`
relates to: [[topic-checksum-addressing]], [[topic-addressing-trinity]]

## what needs implementing

### 1. `amos-chksum` nesting mode

extend `bin/amos-chksum` (or `AMOS7::CHKSUM`) to accept a `--nest`
flag or `parent:name` syntax:

```bash
# current:
amos-chksum name          → CHKSUM

# new nested form:
amos-chksum --nest parent-chksum name
# → computes amos-chksum(parent-chksum . '.' . name)
# → outputs [CHILD_CHKSUM:PARENT_CHKSUM]

# recursive:
amos-chksum --nest PARENT_CHKSUM CHILD_NAME --nest GRANDPARENT PARENT_NAME
# → full chain
```

### 2. `AMOS7::CHKSUM::Nested` module

```perl
package AMOS7::CHKSUM::Nested;

# compute child checksum given parent checksum + child name
sub child_chksum {
    my ( $parent_chksum, $child_name ) = @_;
    return amos_chksum( $parent_chksum . '.' . $child_name );
}

# format as [outer:inner] notation
sub format_nested {
    my ( $child_chksum, $parent_chksum ) = @_;
    return "[$child_chksum:$parent_chksum]";
}

# parse [outer:inner] notation → { child, parent }
sub parse_nested {
    my ($notation) = @_;
    return undef unless $notation =~ /^\[([A-Z0-9]+):([A-Z0-9]+)\]$/;
    return { child => $1, parent => $2 };
}

# verify: given parent_chksum + child_name, does outer match?
sub verify_nesting {
    my ( $notation, $parent_chksum, $child_name ) = @_;
    my $parsed = parse_nested($notation) or return FALSE;
    my $expected = child_chksum( $parent_chksum, $child_name );
    return $expected eq $parsed->{child} ? TRUE : FALSE;
}

# reconstruct ancestry chain from a series of [outer:inner] pairs
sub reconstruct_chain {
    my (@notations) = @_;   # ordered from root to leaf
    # verify each link connects to the next, return chain array or undef
    ...
}
```

### 3. network addressing integration

the `[CHKSUM:PARENT]` format becomes a valid address format in:
- namespace tree nodes
- route headers (as compact node identity)
- index keys (checksum-based search integration)
- epoch directories (epoch-checksum as directory prefix)

add to the addressing parser in `base.chk-sum.*` or create
`base.chk-sum.nested.*` as the parsing layer.

### 4. `p7c` commands

```bash
# compute nested checksum
p7c amos.chksum.nest PARENT_CHKSUM CHILD_NAME

# verify a [OUTER:INNER] pair given parent+name
p7c amos.chksum.verify "[GGL6ANA:JC762WY]" JC762WY litter-7

# parse [OUTER:INNER] → human readable
p7c amos.chksum.parse "[GGL6ANA:JC762WY]"
# → child: GGL6ANA, parent: JC762WY
```

## validation

```bash
# round-trip: nest, then verify
PARENT=$(amos-chksum "litter-7")
NESTED=$(p7c amos.chksum.nest $PARENT "child-name")
p7c amos.chksum.verify "$NESTED" "$PARENT" "child-name"
# → TRUE

# collision exclusion: same child name, different parents → different outer
PARENT_A=$(amos-chksum "node-a")
PARENT_B=$(amos-chksum "node-b")
NESTED_A=$(p7c amos.chksum.nest $PARENT_A "same-name")
NESTED_B=$(p7c amos.chksum.nest $PARENT_B "same-name")
# → NESTED_A != NESTED_B  (collision excluded by parent entropy)
```

## dispatch prompt

implement the collision-free nested checksum addressing primitive.

1. add `AMOS7::CHKSUM::Nested` to `data/lib-path/pm/AMOS7/CHKSUM/Nested.pm`
   with `child_chksum`, `format_nested`, `parse_nested`, `verify_nesting`,
   `reconstruct_chain`

2. extend `bin/amos-chksum` with `--nest <parent_chksum> <name>` flag

3. add zenka modules:
   `src/amos.chksum.cmd.nest`
   `src/amos.chksum.cmd.verify-nested`
   `src/amos.chksum.cmd.parse-nested`

4. validate round-trip and collision exclusion as described above

check existing AMOS7::CHKSUM modules in `data/lib-path/pm/AMOS7/CHKSUM/`
for the correct primitive to build on — do not re-implement the base
amos checksum, only the nesting convention layer.

#,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,

#,,.,,.,.,.,.,.,.,.,.,,..,.,,,...,,,.,,..,...,..,,...,...,.,.,,..,.,.,,,,,.,.,
#KRAWP4FTKNT3MTZEHPH3BZBKGLWGULIJSCZX7H2BF375OHRQC7XNDQAHZWV2CMY3ZMTXHK7YJBU2Y
#\\\|TINPXRDRBHGE6KWFVWSAZZUWFAWBTJXMRDBC6K2XWV4KDS3ZQ5Q \ / AMOS7 \ YOURUM ::
#\[7]UE7LF7Y3XG7FIFC7GQUGI3SNGPOXVVN3MDY7F6QF62IYP3DQMWAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
