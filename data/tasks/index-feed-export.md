# task: index zenka — feed.file + feed.dir + export

## context

part of the `index.*` zenka — numerical language deduplication tree.
this task implements corpus feeding (file + directory) and YAML export.
feeding the entire `data/md/` knowledge base is the primary use case.

see `data/md/design/NUMERICAL-LANGUAGE-DEDUPLICATION-TREE.md` for full design.
data structures defined in task `index-init-data-structure.md`.
ingest/rank/rebalance pipeline in task `index-ingest-rank-rebalance.md`.
deduplication in task `index-deduplicate.md`.

## signatures note

the module files will have 5-line AMOS7 signature footers already present.
do NOT modify, remove, or regenerate signatures. do NOT add stub signatures.
leave the footer exactly as-is. only edit code above the signature block.
the signature block begins with a line matching `^#,,`.

## modules to create

### `modules/index.feed.file`

```
## [:< ##

# name = index.feed.file
# descr = ingest a single file into the index
```

`$ARG` is the file path (scalar). reads file content, calls ingest,
deduplicate, then rebalance. logs the file path at level 2.
returns TRUE on success, FALSE if file not readable.

```perl
my $path = $ARG;

return FALSE if not defined $path or not -r $path;

my $content = <[base.file.slurp]>->($path);

return FALSE if not defined $content;

<[index.ingest]>->($content);
<[index.deduplicate]>->($content);
<[index.rebalance]>->();

<[base.log]>->( 2, "index fed [ $path ]" );

return TRUE;
```

### `modules/index.feed.dir`

```
## [:< ##

# name = index.feed.dir
# descr = walk a directory and feed all text files into the index
```

`$ARG` is the directory path. recursively finds all `.md`, `.yaml`,
`.yml`, `.txt`, `.pm`, `.pl` files. feeds each via `index.feed.file`.
skips binary files and files larger than 10MB.
logs summary at level 1.

```perl
my $dir = $ARG;

return FALSE if not defined $dir or not -d $dir;

my @files;
<[base.file.find_recursive]>->( $dir, \@files,
    { extensions => [qw( md yaml yml txt pm pl )] } );

## fallback: use find if base.file.find_recursive unavailable ##
if ( not @files ) {
    @files = grep { -f $ARG and -r $ARG and -s $ARG < 10_000_000 }
             map  { chomp; $ARG }
             qx| find \Q$dir\E -type f \\( -name '*.md' -o -name '*.yaml'
                 -o -name '*.yml' -o -name '*.txt' -o -name '*.pm'
                 -o -name '*.pl' \\) 2>/dev/null |;
}

my $count = 0;
for my $file ( @files ) {
    next if -s $file > 10_000_000;
    <[index.feed.file]>->($file) and $count++;
}

<[base.log]>->( 1, "index feed.dir complete [ $count files from $dir ]" );

return $count;
```

### `modules/index.export`

```
## [:< ##

# name = index.export
# descr = serialize current index tree to YAML
```

exports the current disk geometry as a YAML structure. `$ARG` is optional
output path — if provided, writes to file; otherwise returns YAML string.

structure exported:
```yaml
index:
  meta:
    total: 12345
    tokens: 67
    sequences: 23
  disk_0:
    - addr: 0
      token: "."
      freq: 4521
    - addr: 1
      token: ","
      freq: 3210
    ...
  disk_1:
    - addr: 0
      sequence: "the"
      freq: 89
    ...
```

use `<[base.encode_yaml]>` for YAML serialization if available,
otherwise format manually.

## success criteria

- [ ] `index.feed.file` reads file and calls ingest + deduplicate + rebalance
- [ ] `index.feed.file` returns FALSE gracefully for unreadable files
- [ ] `index.feed.dir` finds .md/.yaml/.yml/.txt/.pm/.pl recursively
- [ ] `index.feed.dir` skips files over 10MB
- [ ] `index.feed.dir` returns count of successfully fed files
- [ ] `index.export` produces valid YAML with disk_0 and disk_1 sections
- [ ] `index.export` writes to file if path given, returns string otherwise
- [ ] uses `$ARG` not `$_`
- [ ] uses FALSE/TRUE constants not 0/1
- [ ] no stub signatures
- [ ] all modules pass ptd

## integration test

after all tasks complete, feeding `data/md/` should:
1. `p7c index.feed.dir data/md` — feed entire knowledge base
2. `p7c index.stats` — show inner ring with P7 vocabulary dominating
3. `p7c index.address .` — should return 0 or low address
4. `p7c index.decode 0` — should return most frequent character

#,,,,,,..,,,.,,,,,,,.,.,,,.,.,,,.,,.,,,.,,.,,,..,,...,.,.,...,.,,,,.,,,,,,..,,
#52KKHGR3HUQUDLUJQCVTTNVTKP3Y7VDJMNSG6GRAUCDJSEDI3JR4ZG75UERDYODM2THHRSBMZ3CT6
#\\\|OF4EQ3V55CSA7X7CEU5TMEYJ2DFUPDRLNQMISICPYRYFDOP65R3 \ / AMOS7 \ YOURUM ::
#\[7]U3AYVVZISL756SS2D6U7IXQ7EHXHYJGQHSNSKZ4NPVF2R42QCYCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
