## [:< ##

# name  = task: implement route.bmw384 signature indexer + namespace coordinate test
# descr = walk a directory of signed P7 module files, extract the stored BMW384
#         digest from the signature footer (line 2, B32-encoded), register each
#         file into the route.bmw384 field index using its normalized dot-path name,
#         and wire into plugin.storage.checksum.cluster (type: harmonic).
#         also implement a coordinate verification command that compares the stored
#         digest (from file content) against a freshly computed one (from dot-path
#         name string) to test geometric coherence of the naming convention.

## important note on existing code

the following modules exist but are FRESH AND UNTESTED — do not assume they work
correctly. read them for reference and understanding only. if they look incomplete
or incorrect, implement the needed functionality independently rather than calling
them and hoping they work:

  plugin.storage.checksum.cluster.*  — checksum cluster registry (untested)
  plugin.storage.util.visual.*       — distance/proximity utilities (untested)
  plugin.storage.p7ref.*             — P7REF resolution (untested)
  base.file.path.chksum.BMW-L13      — BMW path checksum links (untested)

the route.bmw384.index.* modules ARE the verified foundation — use those.

## background

every signed P7 module file has a 4-line signature footer. the relevant lines:

  line 1: #,,...  (octal-encoded AMOS checksum of file content)
  line 2: #XXXXX  (B32-encoded raw BMW384 digest of file content, 77 B32 chars)
  line 3: #\\\|.. (AMOS7 YOURUM signature)
  line 4: #\[7].. (DATA SIGNATURE)

the B32 on line 2 is a direct encoding of the 48-byte raw BMW384-384 digest.
decoding it gives the raw binary digest that `bmw384_color`, `bmw384_angle_bits`
etc. operate on.

the normalized dot-path name of a module is derived from its filename:
  modules/base.chk-sum.init_code  →  base.chk-sum.init_code
  (strip leading directory prefix, keep the rest as-is)
future: modules/ → code/, cfg/ → conf/ but use current names for now.

## modules to create

### modules/route.bmw384.index.from-file

index a single file. params: ( $filepath )

  1. read last 6 lines of file — use file.slurp or open/readline
  2. find line matching m{^#[2-9A-Z]{70,80}$} — that is the B32 BMW384 line
     [ line 2 of the 4-line footer, starts with # followed by B32 chars ]
  3. strip leading '#' to get the B32 string
  4. decode B32 to raw bytes:
       <[base.perlmod.autoload]>->('Crypt::Misc');
       my $raw_digest = Crypt::Misc::decode_b32r( $b32_str );
     if decode fails or length != 48, log warning and return undef
  5. derive normalized dot-path name from filepath:
       $name = $filepath;
       $name =~ s{.*/modules/}{};   ## strip path prefix up to modules/
       $name =~ s{^modules/}{};     ## or just modules/ at start
  6. register in route.bmw384 index with stored digest:
       <[route.bmw384.index.register]>->( $name, $raw_digest )
       [ note: index.register currently hashes its $input arg — we need a variant
         that accepts a pre-computed raw digest directly ]
  7. also register in harmonic cluster if plugin.storage.checksum.cluster
     is loaded — check with exists $code{'plugin.storage.checksum.cluster.add'}
     before calling, do not load it or depend on it
  8. return { name => $name, color => $coord->{'color'},
              arc => $coord->{'arc'}, digest_len => length($raw_digest) }

### modules/route.bmw384.index.register-digest

variant of index.register that accepts a pre-computed raw 48-byte digest
instead of hashing an input string. params: ( $name, $raw_digest )

  1. call bmw384_color, bmw384_arc_segment, bmw384_angle_bits on $raw_digest
  2. build coordinate hashref same as bmw384_coordinate but skip the hashing step
  3. store in <route.bmw384.index> same as index.register
  4. return $coord

### modules/route.bmw384.index.from-path

walk a directory and index all signed files. params: ( $path )
default path: <system.root_path> . '/modules'

  1. opendir, readdir, filter files only (no dirs, no dotfiles)
  2. for each file call <[route.bmw384.index.from-file]>->( $filepath )
     skip files that return undef (unsigned or unreadable)
  3. log progress every 100 files at level 2
  4. return { indexed => $count, skipped => $skip_count, path => $path }

### modules/route.bmw384.cmd.index-path

command handler: p7c <zenka>.index-path [path]
calls route.bmw384.index.from-path with optional path arg.
logs result summary. returns { mode => 'size', data => $summary_line }

  format: "indexed N modules from [path] — arcs: A:12 B:8 C:15 ..."
  show top 5 arcs by count

### modules/route.bmw384.cmd.verify-coordinate

command handler: p7c <zenka>.verify-coordinate <module-name>

given a normalized dot-path name (e.g. 'base.chk-sum.init_code'):

  1. look up stored coordinate from index (registered from signature)
  2. compute fresh coordinate from the name string itself:
       <[base.chk-sum.bmw384.coordinate]>->( $name ) → $name_coord
  3. compute color distance between stored and name-derived coordinates:
       <[base.chk-sum.bmw384.color-dist]>->(
           $stored_coord->{'color'}, $name_coord->{'color'} )
  4. compute hamming distance between angle_bits
  5. report:
       module:        base.chk-sum.init_code
       stored arc:    B  color: 1A3F2C
       name arc:      B  color: 2D8F11
       color dist:    142331  (0.85% of wheel)
       angle hamming: 87 / 360 bits
       verdict:       resonant [ same arc ] / divergent [ arc A vs C ]

the verdict is 'resonant' if stored and name-derived are in the same arc,
'near-resonant' if within 2 arcs, 'divergent' otherwise.

returns { mode => 'size', data => $report }

## read first (for context, not as trusted working code)

- modules/plugin.storage.checksum.cluster.init-code
- modules/plugin.storage.checksum.cluster.add
- modules/plugin.storage.util.visual.checksum_distance
- modules/route.bmw384.index.register
- modules/route.bmw384.index.init
- modules/base.chk-sum.bmw384.coordinate

## notes on signatures

- new files: leave clean, no stub footer
- Crypt::Misc::decode_b32r decodes the B32R (base32 with custom alphabet) used
  in P7 signatures — this is the correct decoder for footer line 2
- the B32 string on line 2 is ~77 chars and decodes to exactly 48 bytes
- do not confuse with AMOS 7-char checksums — those are on line 3/4

## style
- $ARG not $_ in loops
- <[base.logs]>->( N, fmt, args ) for logging
- lowercase comments, [ word ] bracket annotations
- no use statements or pragmas in zenka modules

#,,..,..,,.,,,,,.,,,,,..,,.,.,...,,.,,,..,,,,,..,,...,...,,,.,,,,,,,.,..,,...,
#W5U4OUEZDFFB6KOLNWTJ4Q2W4OXK6XUHOTUPURFFEBH4FFHZM7IOTMIGLIQFFJOINJOWRP4XBYFU2
#\\\|YSTCS2NB4THXMM5BBTATKTEI4TZQ5VFM323C26IZEXBLUNRTE7N \ / AMOS7 \ YOURUM ::
#\[7]UYM4CVIXEWUHWJTFKWG4Y5VPOCTRUWILU3VKXG6LYV3FUVTHIQBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
