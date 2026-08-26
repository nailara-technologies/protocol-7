## [:< ##

# task: index zenka — schema v3 cube reader

implement `index.restore.cube` — detect schema v3 by magic bytes, mmap the
file, validate the header checksum, and load compartments on demand. ring 0
and ring 1 are eager-loaded; outer rings are lazy. fall back to schema v2
(`.zxps`) if no cube file exists.

design reference: `data/md/design/INDEX-CUBE-STORAGE.md`

signatures_note: do NOT attempt to sign any files — only the repo owner can
sign via `v7.sourcecode update-signatures`.

---

## module: index.restore.cube (new)

### schema detection

on startup, check for the cube file first:

```perl
my $cube_path = <[path.zenka_dir]>->('numerical/numerical-index_state.zxpc');
my $v2_path   = <[path.zenka_dir]>->('numerical/numerical-index_state.zxps');

if ( -f $cube_path ) {
    return <[index.restore.cube]>->($cube_path);
} elsif ( -f $v2_path ) {
    return <[index.restore.v2]>->($v2_path);   ## existing path
} else {
    <[base.log]>->( 1, 'index.restore: no state file found' );
    return;
}
```

schema detection is by file presence; the first 4 bytes `'P7IC'` are validated
after mmap to reject corrupted or misnamed files.

### mmap and header validation

```perl
use POSIX qw( mmap PROT_READ MAP_SHARED );

my $fh;
open( $fh, '<:raw', $path ) or return;
my $size = -s $path;

my $mmap = mmap( undef, $size, PROT_READ, MAP_SHARED, fileno($fh), 0 );
close($fh);

my $magic = substr( $mmap, 0, 4 );
return unless $magic eq 'P7IC';

## parse 256-byte header ##
my $header = <[index.cube.parse_header]>->($mmap);
return unless defined $header;

## validate header checksum ##
my $hdr_chksum_ok = <[base.checksum.amos7.verify]>->(
    substr( $mmap, 0, $header->{'checksum_offset'} ),
    $header->{'header_checksum'}
);
return unless $hdr_chksum_ok;
```

### data structures

```perl
<index.cube.mmap>    = \$mmap;           ## scalar ref to mmap'd region
<index.cube.header>  = $header;          ## parsed header hashref
<index.cube.loaded>  = {};               ## {$depth}{$rank} => $compartment_struct
```

### eager load: ring 0 and ring 1

```perl
for my $depth ( 0, 1 ) {
    my $count = $header->{'ring_count'}[$depth] // 0;
    next unless $count;

    for my $rank ( 0 .. $count - 1 ) {
        my $comp = <[index.cube.load_compartment]>->( $depth, $rank );
        <index.cube.loaded>->{$depth}{$rank} = $comp if defined $comp;
    }
}
```

ring 0 is ~100-200 compartments, each a few hundred bytes — total < 64KB,
cheaper than parsing a config file. these are the inner ring, always hot.
ring 1 is the most common 2-character sequences — thousands of compartments,
loaded immediately after ring 0.

### lazy load: ring 2+

outer ring compartments are deserialized on first access:

```perl
sub index.cube.get_compartment {
    my ( $depth, $rank ) = @ARG;

    return <index.cube.loaded>->{$depth}{$rank}
        if exists <index.cube.loaded>->{$depth}{$rank};

    my $comp = <[index.cube.load_compartment]>->( $depth, $rank );
    return unless defined $comp;

    <index.cube.loaded>->{$depth}{$rank} = $comp;
    return $comp;
}
```

each deserialized compartment is inserted into `<index.cube.loaded>` and the
cache LRU. eviction removes only the perl structure — the mmap'd bytes remain.

### compartment deserialization

```perl
sub index.cube.load_compartment {
    my ( $depth, $rank ) = @ARG;

    my $hdr   = <index.cube.header>;
    my $base  = $hdr->{'dir_base'}[$depth];
    my $stride = $hdr->{'dir_stride'}[$depth];
    my $offset = $base + $rank * $stride;

    ## read directory entry from mmap ##
    my $entry = substr( ${ <index.cube.mmap> }, $offset, $stride );
    my ( $data_offset, $data_size, $child_count, $flags, $chksum7 )
        = unpack( 'Q L S S a8', $entry );

    return if $data_size == 0;   ## void compartment

    ## read compartment checksum frame and payload ##
    my $comp_bytes = substr( ${ <index.cube.mmap> }, $data_offset, $data_size );

    ## verify checksum frame (optional in fast mode, mandatory in strict mode) ##
    ## ... see index-cube-storage-verify task ...

    ## deserialize payload ##
    my $payload = substr( $comp_bytes, $checksum_frame_len );
    my $struct = <[index.cube.parse_payload]>->($payload);

    return $struct;
}
```

---

## module: index.init_code (modify)

replace the existing restore call with the v3-first fallback:

```perl
## was: <[index.restore]>->();
## now:
<[index.restore.cube]>->();
```

or, if `index.restore.cube` is designed as a drop-in replacement that handles
its own v2 fallback internally, simply swap the module name in `init_code`.

---

## notes

- prerequisite: `index-cube-storage-format` task
- `mmap()` + `madvise()` on startup reduces zenka boot time from seconds
  (xz decompress + storable thaw) to milliseconds
- `index.cube.loaded` is the working set; `<index.cube.mmap>` is the eternal
  backing store. this mirrors the harmonic tree property: valid presence cannot
  be evicted from the structure, only from working memory.
- the root concept `''` does not have a compartment — it is the header itself,
  the 0 that generates the address space without occupying it.

#,,,,,,.,,...,,..,,..,...,...,,.,,,,,,.,,,.,.,..,,...,...,...,.,,,...,,,,,,.,,
#BYWO7E33P6VJG6M3PF3TCB5QK7PUFDAGISYFRSQAR6LE5N7ZFHO2DDBICUCPORNNDPM5N3TSX6346
#\\\|VUY6U4U6R7YZF5OLIYD6RLNC45CNJ7OWLKXSW6AXS2GIMUEBMH2 \ / AMOS7 \ YOURUM ::
#\[7]4KN6PPQVHHKJ7DIC7I3BTTR3NLR4FENWO6PVB34OY25K7KSM4ACY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
