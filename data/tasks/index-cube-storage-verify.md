## [:< ##

# task: index zenka — compartment verification and tamper-evidence chain

implement per-compartment checksum verification on load and a tamper-evidence
chain that links each compartment to its parent. graceful degradation: a
corrupt compartment marks itself unavailable without breaking the rest of the
trie.

design reference: `data/md/design/INDEX-CUBE-STORAGE.md`

signatures_note: do NOT attempt to sign any files — only the repo owner can
sign via `p7.sourcecode update-signatures`.

---

## per-compartment verification on load

when a compartment is loaded (in `index.cube.load_compartment`):

```perl
## 1. read compartment checksum frame from head of compartment bytes ##
my ( $frame_len, $stored_chksum )
    = <[base.checksum.amos7.parse_frame]>->($comp_bytes);

## 2. compute AMOS7 over payload bytes (size declared by frame) ##
my $payload = substr( $comp_bytes, $frame_len );
my $computed_chksum = <[base.checksum.amos7]>->($payload);

## 3. compare ##
if ( $stored_chksum ne $computed_chksum ) {
    ## mismatch: log, mark corrupt, return undef ##
    <[base.log]>->(
        0,
        "index.cube.verify: compartment corrupt [ depth=$depth rank=$rank ]"
    );
    <index.cube.corrupt>->{$depth}{$rank} = TRUE;
    return;
}

## match: mark verified, deserialize payload ##
$compartment->{'verified'} = TRUE;
```

a corrupt compartment degrades gracefully: the branch rooted at that prefix
becomes unreachable, but the rest of the trie continues to serve queries. the
failure is localized to one cell.

---

## tamper-evidence chain

each compartment at depth D stores `parent_chksum7` = the AMOS7 checksum of
its parent compartment at depth D-1. depth-0 compartments chain to the header
checksum.

### chain verification: fast mode (default)

verify only the compartment being loaded:

```perl
## verify compartment's own checksum frame (payload integrity) ##
## parent_chksum7 is present in payload but NOT verified against parent
## unless deep-verify is enabled
```

this is the default for query-time loading: cheap, local, sufficient to detect
corruption of the compartment's own bytes.

### chain verification: deep-verify mode

traverse from leaf to root, checking the nested checksum chain:

```perl
sub index.cube.verify_chain {
    my ( $depth, $rank ) = @ARG;

    my $comp = <[index.cube.get_compartment]>->( $depth, $rank );
    return FALSE unless defined $comp;

    my $expected_parent = $comp->{'parent_chksum7'};

    if ( $depth == 0 ) {
        ## root of chain: must match header checksum ##
        my $hdr_chksum = <index.cube.header>{'header_checksum'};
        return $expected_parent eq $hdr_chksum;
    }

    ## find parent: the compartment at depth-1 whose child list contains us ##
    ## this requires a reverse lookup or maintaining a parent index ##
    my $parent = <[index.cube.find_parent]>->( $depth, $rank );
    return FALSE unless defined $parent;

    my $parent_chksum = <[base.checksum.amos7]>->(
        <[index.cube.serialize_payload]>->($parent)
    );

    return FALSE unless $parent_chksum eq $expected_parent;

    ## recurse upward ##
    return <[index.cube.verify_chain]>->( $depth - 1, $parent->{'rank'} );
}
```

deep-verify is expensive and used only for:
- explicit `index.cmd.verify-cube` diagnostic runs
- first load of a newly migrated cube
- paranoid mode toggled by configuration

### graceful degradation

corrupt compartments are tracked in `<index.cube.corrupt>`:

```perl
<index.cube.corrupt> = {
    $depth => { $rank => TRUE, ... },
    ...
};
```

on query traversal, a corrupt compartment short-circuits the branch:

```perl
if ( <index.cube.corrupt>->{$depth}{$rank} ) {
    return { 'mode' => 'false', 'data' => 'branch unavailable (corrupt)' };
}
```

parent compartments and siblings continue serving normally.

---

## module: index.cmd.verify-cube (new)

diagnostic command: verify all currently loaded compartments and report corrupt
branches.

```perl
# name  = index.cmd.verify-cube
# descr = verify all loaded compartments and report corrupt branches
```

```perl
my @lines;
push @lines, 'cube verification report :';

my $total = 0;
my $verified = 0;
my @corrupt_list;

for my $depth ( keys %{ <index.cube.loaded> // {} } ) {
    for my $rank ( keys %{ <index.cube.loaded>->{$depth} } ) {
        $total++;
        my $comp = <index.cube.loaded>->{$depth}{$rank};

        if ( $comp->{'verified'} ) {
            $verified++;
        } else {
            push @corrupt_list, "  [ depth=$depth rank=$rank ]";
        }
    }
}

push @lines, "  compartments checked : $total";
push @lines, "  verified             : $verified";
push @lines, "  corrupt              : " . scalar(@corrupt_list);

if ( @corrupt_list ) {
    push @lines, '  corrupt branches :';
    push @lines, @corrupt_list;
}

return { 'mode' => 'size', 'data' => join("\n", @lines) . "\n" };
```

---

## notes

- prerequisite: `index-cube-storage-reader` task
- the per-compartment checksum is a 1D frame. the tamper-evidence chain turns
  it into a linked structure: any splice or reordering of compartments breaks
  the leaf verification.
- for stronger integrity, future work may add ring-level directory checksums
  (2D column frames) and a full-file integrity checksum (3D outer ring). these
  are not required for the initial implementation.
- the `parent_chksum7` field is part of the compartment payload, so it is
  covered by the compartment's own checksum frame. this means the chain link
  cannot be altered without invalidating the compartment.

#,,.,,.,,,,,,,.,.,,..,,,.,,.,,,..,.,.,,,,,..,,..,,...,...,..,,,..,,.,,...,,,,,
#WAPDF6PHCNKUTWXWAO3MIZBXFCE7GNVESYJWFXT7Z2HX2T5I736OYDMRFNI5RXPSF7X63KIQ3PSDQ
#\\\|6KW26EJJYIKMKBMFJQ2PZTFPPHNGRWXSAGBEDGD6CULUWVAYSYT \ / AMOS7 \ YOURUM ::
#\[7]BILNJPV3EJXQCJ7D6RKC4OND6VRUSZBZBVYJNBKSBW56OKSMRUBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
