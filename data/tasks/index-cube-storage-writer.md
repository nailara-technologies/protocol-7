## [:< ##

# task: index zenka — schema v3 cube writer

implement `index.persist.cube` — write schema v3 `.zxpc` from the current
in-memory trie state. this replaces the monolithic `.zxps` storable dump with
a structured header + directory + compartment layout that supports mmap and
demand-loading.

design reference: `data/md/design/INDEX-CUBE-STORAGE.md`

signatures_note: do NOT attempt to sign any files — only the repo owner can
sign via `v7.sourcecode update-signatures`.

---

## module: index.persist.cube (new)

### what it does

1. walks the in-memory trie (`<index.trie>`) and computes a compartment for
each node (addr / packed_rank / trie)
2. builds the compartment directory ring by ring
3. constructs the 256-byte header with `dir_base`, `dir_stride`, and
`ring_count` computed from the directory layout
4. writes header + directory + compartment data to a new `.zxpc` file
5. uses atomic write via `<[file.zenka_dir.write]>`

### output path

```
numerical/numerical-index_state.zxpc
```

### compartment building

for each trie node at `(depth, rank)`:

```perl
my $compartment = {
    'terminal'       => $node->{'terminal'} ? 1 : 0,
    'frequency'      => $node->{'frequency'},
    'child_count'    => scalar keys %{ $node->{'children'} // {} },
    'children'       => [                  ## sorted by rank descending
        map { { 'char' => $_, 'rank' => $child_rank{$_} } }
        sort { $child_rank{$b} <=> $child_rank{$a} }
        keys %{ $node->{'children'} // {} }
    ],
    'parent_chksum7' => $parent_chksum,    ## see tamper-evidence chain below
};
```

the compartment payload is serialized as flat binary per the format spec.
the self-delimiting AMOS7 checksum frame is computed over the payload bytes
and prepended to form the on-disk compartment.

### tamper-evidence chain in writer

each compartment payload includes `parent_chksum7`:

- depth-0 compartments: `parent_chksum7` = the header checksum
- depth-D compartments (D > 0): `parent_chksum7` = the compartment checksum
  of the parent node at depth D-1

this means compartments must be written in depth order (root-ward to leaf-ward)
so that the parent's checksum is available when computing the child's payload.
the writer processes rings sequentially: ring 0, then ring 1, then ring 2, etc.

### directory construction

for each ring D:

```perl
my $ring_count = scalar @{ $ring_compartments[$D] };
my $dir_stride = 24;        ## fixed entry size from format spec
my $dir_base   = $next_offset;
$dir_base += (16 - $dir_base % 16) % 16;   ## 16-byte alignment

## write directory entries for this ring ##
for my $R ( 0 .. $ring_count - 1 ) {
    my $comp = $ring_compartments[$D][$R];
    my $entry = pack(
        'Q L S S a8',
        $comp->{'data_offset'},
        $comp->{'data_size'},
        $comp->{'child_count'},
        $comp->{'flags'},
        $comp->{'compartment_chksum7'},
    );
    ## entry written at dir_base + R * dir_stride
}
```

### header construction

```perl
my $header = pack(
    'a4 S S L S',
    'P7IC', 3, 3, $flags, $max_depth
);
## append ring_count[], dir_base[], dir_stride[]
## append data_base, data_size
## compute header_checksum as self-delimiting AMOS7 over header bytes
## pad to exactly 256 bytes
```

### atomic write

```perl
<[file.zenka_dir.write]>->(
    'numerical/numerical-index_state.zxpc',
    $header . $directory . $compartment_data
);
```

---

## module: index.persist (modify)

add a dispatch branch or wrapper that calls `index.persist.cube` when schema
v3 output is desired. the existing `.zxps` (schema v2) path remains available
as fallback until migration is complete.

---

## notes

- prerequisite: `index-cube-storage-format` task
- compartments are written depth-first by ring to ensure parent checksums are
  available before children are serialized
- the total directory size and compartment data size must be pre-computed so
  that `data_base` and `dir_base` offsets are correct before any bytes hit disk
- `data_size == 0` directory entries represent void compartments — prefixes
  with no corpus presence. these are still written to the directory to preserve
  the arithmetic address space

#,,,.,,.,,,.,,..,,,..,,,,,,,,,,.,,,..,,.,,.,.,..,,...,...,,..,..,,..,,...,.,,,
#D4KWPKOLGYTO2KVAIPIRP4M4Z6GVE7M4MEWD5EGIHD4VUIZVSFHUMG7BKZSQCGJK4ZEJ7VKIMQATG
#\\\|6WDIV7AVQIUQWLFPHYJZ3BJZ3KPNKHKZUHJCWFVFZRZMYUDIR7G \ / AMOS7 \ YOURUM ::
#\[7]WHGFKACMJUT5566PEMENFMKJBZYRNRCFG4DND4I5MXPIPB3E2WBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
