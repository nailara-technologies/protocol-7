# N7FS stage 2 : incoming pool as built

2026-11-08. this is an additive store-format-3 extension following
`N7FS-TREE-CATEGORIES.md`. it adds no encryption, sync, network or placement
enforcement.

## pool semantics

the built-in `incoming` category always exists beside `default`. its initial
policy is copies 2, priority 50 and otherwise the default values. `category set
incoming` writes ordinary versioned category records and can change it.

a reference belongs to the pool exactly while its CURRENT category is
`incoming`. a later individual or batch assignment supersedes earlier ones and
moves it out. deduplicated nodes can therefore have one incoming reference and
other references in other categories. pool membership is per reference, never
per content node.

`assimilate -incoming` excludes `-tree`, `-category` and `-index`. each
directory argument gets a separate tree named
`incoming:<ntime14>:<basename>`, the basename of the absolute path reduced to
`A-Za-z0-9._-` and 64 octets because it is only a label; several roots are processed independently and
one failure does not stop later roots. single files get references only. every
new reference is assigned `incoming`, as is an existing reference with no
assignment at all. re-import never moves a sorted reference back into the pool
and writes no new assignment for one already there. stage-1 skipped-source and verified-source-removal semantics
are unchanged, including `-remove` and `-prune`.

## batch assignment record

| kind | magic | record format | label | location below `.n7fs/` |
|---|---|---|---|---|
| category batch | `P7FI` | 3 | `p7 n7fs category batch:0001` | `batch-assignments/<ntime14>.<tail8>.batch-assignment` |

the signed payload is `{ disk, ntime, category, bytes, references }`. each
reference entry is `{ node, reference }`. entries and duplicate reference IDs
are validated; magic, label, format, disk, ntime, store signer and signature are
all checked. `bytes` is the signed byte total used for the report.

journal `add.batches` contains one `{ path, category }` operation per tag.
replay reads and authenticates that batch record and applies every entry in
journal order, so individual and batch assignments have one latest-wins history.
a tag writes one record file and one journal operation, not one per reference.
pool reads join one meta scan with the replay reference and assignment hashes;
they do not use the older per-reference meta join.

unjournaled batch records fail `verify`. `repair` moves them to
`.n7fs/quarantine/batch-assignments/`, reports each name and adopts none of
them. retry after quarantine creates a fresh batch. tampered records and
unknown references fail replay.

## commands

```
n7fs assimilate -disk <disk> -incoming [ -keep | -remove ] [ -prune ] <paths..>
n7fs incoming <disk> list [ -under <path-prefix> ] [ -depth <n> ] [ -limit <n> ]
n7fs incoming <disk> tag <path-prefix|glob|address> <category>
n7fs incoming <disk> done
```

`list` groups by original directory, showing reference count and total bytes,
largest first. `-under` filters by raw path prefix, ending at a path component :
`/a/foo` never selects `/a/foobar`. `-depth` truncates groups
relative to that prefix, or from the root without one. `-limit` caps groups,
not the summary. paths are raw octets; list output deliberately uses a raw
stream so non-UTF-8 names are not double encoded.

`tag` accepts a canonical address, a glob containing `*` or `?` [ which crosses
`/` ], or a literal holder-path prefix with the same component rule. an empty
selector, unknown categories and zero matches refuse before writing.
it reports reference count, bytes and journal sequence. `done` prints remaining
count and bytes, exits 1 while nonempty and exits 0 with `[ empty ]` when done.
`status` prints the same current totals.

## performance notes

startup profiling used `strace -c` and repeated `Time::HiRes` wall-clock
measurements. on this host a cold trivial `list` invocation took about 0.48 s;
warm invocations were about 0.09 s. module lookup and loading dominated startup,
not signing or fsync. conversion, release and tree modules are now loaded only
by their commands, reducing warm trivial `list` to about 0.08 s. the reported
15-20 s fixed cost did not reproduce here; cold module/filesystem cache costs
are the likely multiplier on slower storage.

per-file assimilation work includes source hashing, copying and syncing the
content node, hashing the stored node, hashing the source again, signed meta and
reference creation, read-back checks and directory syncs. large files therefore
take several passes over their bytes, not one BMW384 pass. no fsync, signature
or verification step was removed. possible future work is a durable group-sync
design and fewer redundant reads, but either needs a separate crash-consistency
proof.

unloaded measurements on this host : 100 distinct small files took 1.368 s
[ 13.7 ms per file ], and one 1 GiB file took 7.090 s. the reported 50 ms per
file and 35 s large-file times did not reproduce; the same mandatory hashing,
record and sync work accounts for the scaling, with storage performance setting
the multiplier.

scale measurement uses a directly generated, fully signed fixture of 20000
references, metas and two batch assignments. fixture creation is not timed.
list and tag commands are real CLI invocations on that fixture. results are
recorded below after the run:

observed : list 63.136 s, batch tag 140.114 s, empty list 60.608 s. one batch
record and one journal operation handled the tag. the dominant remaining cost
is authenticated record and directory I/O, not per-tag record creation; runtime
is linear in references rather than quadratic.

#,,,.,,,,,,.,,.,.,...,,,,,,,.,.,,,,,,,,,,,.,,,..,,...,...,,..,...,,.,,,.,,.,.,
#JNWW5ETWTH5DHRB7YJBBI3VKMQWYGP3SFRNLOUG374LMW76BFUKDMXZVWQHEXCLXGWPNI76A7YYWU
#\\\|WGEH6ID7CFMJOCU23MAQKX4DVAIGFPMDIXZWNG5HVVNFK2TRUZQ \ / AMOS7 \ YOURUM ::
#\[7]CZVE5VCOPEGLSWAENDHA4MTN7GY7L4FHBKYPOTO55SI3DRSYHGCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
