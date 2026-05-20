# task: index zenka — harmonic trie storage (phase 2 continuation)

## context

see `data/md/documentation/harmonic-storage-architecture.md` for the full
architecture vision and `data/md/documentation/entropy-at-deduplication-root.md`
for the mathematical foundation.

see also `data/yaml/coding-tasks/phase-2-indexer-checksum-filesystem.yaml`
for the prior phase-2 plan — this task continues and refines that work.

## what already exists

**do not re-implement these — build on top of them:**

- `index.gen_path` — already computes AMOS checksum path using modes 5 and 7,
  builds a checksum character matrix across offsets 0-6, truth-filters
  directory names with elf modes 7 and 9, reseeds if below minimum subdir
  count. this is the core path generation — **already done**.

- `index.cmd.gen-path` — p7c-accessible wrapper for gen_path. **done**.

- `index.cmd.add-wordlist` — imports wordlists with 3-letter language codes
  via idle event loop, uses ELF checksum for job deduplication. **done**.

- `index.cmd.add-path` — adds filesystem paths to the index. **done**.

- `storage.map-dirs.init_code` — XFS mmap'd virtual filesystem with depth 7,
  dir-max-len 7, `/data/amos-fs-mount` root, reindex cycle 13m. the storage
  layer for the trie is **already designed and partially implemented**.

- `storage.unix.handler.amos-chksum` — unix socket server for AMOS checksum
  requests with mode selection protocol. **done**.

- `storage.cmd.lookup-checksum` — lookup by checksum via plugin.storage.*
  mapping types. **done**.

- `storage.9p.*` — full 9P filesystem protocol implementation for remote
  mounting the storage. **done**.

## what to build — the missing connections

### 1. wire index.gen_path output into storage.map-dirs

currently `index.gen_path` generates a path string but doesn't write to the
XFS store. `storage.map-dirs` manages the XFS filesystem but doesn't know
about harmonic addresses.

add `index.cmd.write` — stores content at its gen_path address:

```perl
# name  = index.cmd.write
# descr = store content reference at harmonic address

my $input = $call->{'args'} // '';
return { mode => 'false', data => 'expected input' } unless length $input;

my $path    = <[index.gen_path]>->(\$input);
my $bmw_sum = <[chk-sum.bmw]>->(\$input);  ## BMW checksum as filename ##

## ensure XFS store path exists ##
my $store_root = <index.path.index-files>;
<[file.make_path]>->( "$store_root/$path", 0755, <system.amos-zenka-user> );

## write reference file: path/BMW_CHECKSUM ##
my $ref_file = "$store_root/$path/$bmw_sum";
<[file.write]>->( $ref_file, { p7ref => <base.p7ref>, input => $input,
                                timestamp => time(), path => $path } );

return { mode => 'true', data => "$path/$bmw_sum" };
```

### 2. add index.cmd.lookup

retrieve by raw input (computes gen_path, lists BMW references):

```perl
# name  = index.cmd.lookup
# descr = look up index entries by input string or address prefix

my $args  = $call->{'args'} // '';
my $path  = <[index.gen_path]>->(\$args);
my $store = <index.path.index-files> . '/' . $path;

return { mode => 'false', data => 'not found' } unless -d $store;

my @refs  = <[file.list]>->($store);
return { mode => 'size', data => join("\n", @refs) };
```

### 3. add index.cmd.cluster

return density info for an address prefix — how many references share it:

```perl
# name  = index.cmd.cluster
# descr = return density stats for a harmonic address prefix
```

input: partial path (e.g. first 2 levels). output: count, child paths,
density flag if above threshold.

### 4. wordlist cross-language correlation report

add `index.cmd.correlate` — given two language codes already imported,
find words from each that share the same gen_path prefix at depth N:

```bash
p7c index.correlate ENG DEU 3   # find words sharing path to depth 3
```

this makes the cross-language harmonic correlations already observed
in the index zenka navigable and queryable.

### 5. connect summarization threshold to coding zenka

in `index.callback.wordlist-import` (or a new `index.cmd.cluster`),
when a cluster exceeds `index.cfg.cluster_summarize_threshold` (default 42):

```perl
<[protocol-7.route-send]>->(
    {   command   => 'coding.submit',
        call_args => { args => "summarize harmonic cluster: $path\n"
                             . join("\n", @cluster_members) },
        reply     => { handler => 'index.handler.summarize-reply' }
    }
);
```

store the summary via `index.cmd.write` — the summary's own gen_path
will be near the cluster it summarizes.

## testing

```bash
# basic write and lookup
p7c index.write "LOVES"
p7c index.write "AMOR"
p7c index.write "LIEBE"
p7c index.write "AMOUR"
p7c index.lookup "LOVES"

# check gen_path consistency
p7c index.gen-path "LOVES"
p7c index.gen-path "AMOR"   # observe shared prefix depth

# wordlist import (already works)
p7c index.add-wordlist /usr/share/dict/words ENG
p7c index.add-wordlist /path/to/german/wordlist DEU

# cross-language correlation
p7c index.correlate ENG DEU 3

# cluster density
p7c index.cluster "$(p7c index.gen-path LOVES | cut -d/ -f1-2)"
```

## signatures note

do NOT add stub signature line to new files.

## reference

- `modules/index.gen_path` — existing path generation (modes 5,7, offsets 0-6)
- `modules/index.cmd.add-wordlist` — existing wordlist import
- `modules/storage.map-dirs.*` — existing XFS mmap'd storage layer
- `data/yaml/coding-tasks/phase-2-indexer-checksum-filesystem.yaml` — prior plan
- `data/md/documentation/harmonic-storage-architecture.md`
- `data/md/documentation/entropy-at-deduplication-root.md`

#,,.,,,,,,.,,,.,.,..,,,,,,.,.,...,..,,,,.,,.,,..,,...,...,..,,.,,,,.,,.,.,,.,,
#62JGSANF4BLT7AMFQQVGZFRJDJKJW7TZWFMNZ5GIATUTMWNRHKHTMP27JTZX2YBOQXXHUOC3GBTNQ
#\\\|4KUCYH76N43WFFXCE6XEOB6JY2SI6MXMFZIVTMGTGONRCAGGOLH \ / AMOS7 \ YOURUM ::
#\[7]36MNOYJKXNNWCWQZNQKI34MVZOWV2VE4KXYUJ7QCXR2EV6RD44AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
