# n7fs place : profile and parallelisation plan

2026-11-25. analysis only, no code changed. trigger : `n7fs place -dry-run`
with -only-category \ -only-holder, ~370 k nodes, > 60 minutes at 100 % of one
core [ azurum, alder lake-n, 4 cores ].

result : the time is very likely a cache thrash in `_copies`
[ AMOS7/N7FS/Placement.pm ], not placement work. fix that first. forking before
the fix splits the waste over 4 cores and still takes more than an hour.

## how it was measured

- Devel::NYTProf is not installed : subs wrapped from a scratch script with
  Time::HiRes [ inclusive times, nested rows overlap ].
- synthetic store : real assimilate, 40 trees, 4 local holders in 4 domains,
  each filled by a real place + holder-check [ sampled receipts with covered
  digest ]. then only the dry run, -only-category default -only-holder h1,
  nothing missing. sandbox dirs only.
- measuring box : 16 threads, not azurum. JSON::XS, Digest::BMW, local holders.
- end to end at 1 k and 4 k nodes only [ assimilate took 237 s for 4 k ].
  370 k figures are extrapolated from per-operation timings, not measured.
- not in the store : releases, ssh holders, partial or legacy receipts,
  untagged nodes, batches.

## profile : dry run

| phase [ inclusive ]               | 4 k nodes | 1 k nodes |
|---                                |---        |---        |
| total, wrapped                    | 11.14 s   | 3.10 s    |
| `_copies`                         | 10.60 s   | 2.71 s    |
|  of it `LazyNodes::_load`         |  9.96 s   | 2.50 s    |
|   `_map_plain`                    |  7.93 s   |           |
|    `open_sealed_bytes`            |  4.55 s   |           |
|    `_read_blob`                   |  2.43 s   |           |
|  `receipt_digest`                 |  4.67 s   |           |
|  `receipt_covered` [ 8 calls ]    |  5.14 s   |           |
| `_disk_context`                   |  0.42 s   | 0.35 s    |
|  of it journal replay             |  0.27 s   |           |
| node walk [ total less the above ]| ~0.12 s   |           |
| shard misses, 4 holders           | 78 969    | 25 497    |
| shards decoded once each would be | ~4 000    | ~2 470    |

`_load` counts calls, hits included [ 79 984 at 4 k ].

## hot spot 1 : the 16 shard cache against random lookups

- a map has up to 1024 shards, keyed by address characters 16-17 [ the start of
  the bmw part ]. `LazyNodes::_load` keeps 16 and evicts an arbitrary one.
- full addresses sort by epoch, then amos, then bmw : walking them in sorted
  order hits shards at random. past 16 shards nearly every lookup is a miss :
  read, bmw of the blob, decrypt, bmw of the plain text, json decode of the
  whole shard.
- `_copies` does about 4 such lookups per node per holder :
  1. `receipt_digest` -> `receipt_covered` : grep over `keys`, reads `added`
  2. `receipt_digest` : loop over the sorted covered addresses
  3. `receipt_covered` again, to build `covered_set`
  4. the `used` loop : `$map->{'nodes'}{$address}{'length'}`
- on top, about 5 full passes of all shards : one per tied `keys` [ FIRSTKEY
  loads every shard ], including `scalar keys` for `count` [ checked : a full
  pass, it does not use SCALAR ].
- misses per holder ~ 4 N [ 1 - 16 \ S ] + 5 S. against the measurement :
  27.9 k predicted \ 25.5 k at 1 k, 83.0 k \ 79.0 k at 4 k.
- -only-holder does not reduce it : copies count on every holder, so all maps
  are read [ intended ].

one shard at the 370 k size [ 361 entries, 237 kB ], entries copied from a real
map :

| step                        | ms   |
|---                          |---   |
| file read                   | 0.06 |
| bmw, blob + plain           | 0.40 |
| decrypt                     | 2.26 |
| json decode [ JSON::XS ]    | 0.91 |
| one miss                    | 3.62 |

370 k nodes, all mapped and covered : ~1.46 M misses per holder = ~88 minutes
per holder, ~5.9 h for 4, on this box. azurum is probably slower per core
[ not measured ]. this fits "> 60 minutes at one core" ; the real run was not
profiled.

scratch check [ monkeypatch, shards never evicted ], same store, unwrapped :

| nodes | now     | one decode per shard |
|---    |---      |---                   |
| 1 k   | not run unwrapped | 0.72 s     |
| 4 k   | 10.80 s | 1.43 s               |

at 370 k, one decode per shard = 1024 x 3.62 ms = 3.7 s per holder.

## hot spot 2 : release replay is releases x live references

`_operations` [ Journal.pm, `drop releases` loop ] scans every key of
`references` once per released node. compact replay keeps `references`.
measured on `_operations` alone :

| live references | per release |
|---              |---          |
| 50 k            | 64 ms       |
| 370 k           | 408 ms      |

1 000 releases ~ 7 minutes, 10 000 ~ 68 minutes. an upper figure : references
shrink as releases drop them, and a release replayed early sees fewer. the
real journal's release count is unknown, and the synthetic store has none. if
it is large this is a second hour-scale cost, and every `journal_replay` pays
it, `journal_write` included.

## hot spot 3 : AddressSet bulk build is quadratic per bucket

`STORE` calls `_find`, which re-sorts the whole bucket [ regex split, sort,
join ] whenever the last STORE appended. `_address_set` therefore re-sorts on
every insert.

| addresses | build   | 1 probe each | plain hash build |
|---        |---      |---           |---               |
| 46 k      | 0.4 s   | 0.14 s       | 0.02 s           |
| 92 k      | 1.1 s   | 0.29 s       | 0.05 s           |
| 185 k     | 3.6 s   | 0.66 s       | 0.11 s           |
| 370 k     | 13.5 s  | 1.47 s       | 0.31 s           |

one `covered_set` per holder : ~54 s for 4 full holders, plus the tree sets in
`_disk_context`. the utf8 flag is off on map keys, so `substr` is not the cost.

## smaller items

- `_disk_context` : 0.35 s at 1 k, 0.42 s at 4 k, mostly fixed. linear guess
  for 370 k : 10 to 40 s, release and tree set costs not included. depends on
  the journal's shape.
- node walk : ~30 us per node at 4 k [ by subtraction ], ~11 s at 370 k.
  `_content_path` + `-s` was 0.02 s of it. few lookups here : a covered node
  skips the map. uncovered nodes do look up, but a 2048 chunk spans only ~6
  shards at 370 k, so the cache holds them. at small N it spans far more.
- `_tree_name` : sorts all tree names on every call. only nodes without
  categories reach it in the dry run [ none in the synthetic store ] ; a miss
  walks every tree : 38 us at 40 trees, 286 us at 200, 1.6 ms at 1 000. with
  many trees and many untagged nodes it matters [ two walks over the nodes ].
- `holder_room` \ `df` : once per writable holder, nothing.
- `category_definitions` : `record_scan` once per category path ; nothing here.

## single core fixes first [ in this order ]

1. `_copies` : one pass per holder, in shard order.
   - for each shard : load once, take `used`, `count`, the `added` filter and,
     for covered entries, one compact string of the digest fields.
   - then sort those addresses and feed the digest. the digest bytes must stay
     exactly as now [ sorted full address order ], or every receipt is void.
   - one pass serves digest, `covered_set`, `used`, `count`.
   - needs a shard iterator on `LazyNodes` [ no flattening `keys` ].
   - digest strings : roughly 100 to 150 MB per holder while it runs
     [ estimate ] ; free them per holder.
   - not "a bigger cache" : keeping all decoded shards of 4 maps is what the
     bounded cache exists to prevent. test-n7fs-place-memory.pl must hold.
   - `holder_drain` and `placement_report` use `_copies` too and gain the same.
     other callers of `receipt_digest` \ `receipt_covered` keep their
     interface [ search them before changing it ].
2. release loop : index references and metas by node address, kept up to date
   in `_operations`, also for a replay passed in by `journal_write`. do first
   if the real journal has more than a few hundred releases.
3. `_address_set` : bulk constructor, group by shard, sort and dedupe once per
   bucket. keep the packed form. expected under 2 s at 370 k [ estimate ].
4. `_tree_name` : sort the names once per run ; look up only where used.

expected dry run at 370 k after 1 + 3, few releases, this box : about 1 minute
to 1.5 minutes [ replay 10-40 s, 4 holders x ~6-10 s, walk ~11 s ]. today's
model : ~6 h. these are extrapolations.

new tests : shard misses per holder in `_copies` <= shard count [ counting
wrapper ] ; digest equal to the old function on a fixture ; release replay
state equal before and after ; AddressSet equal for duplicate and unsorted
input.

## real place [ not dry run ] : read from the code, not measured

- `_tree_inventory`, in `seal_nodes` : `exists` in the lazy map for every file
  of each selected tree. each tree's set iterates in shard order, but every
  tree starts over : up to trees x 1024 loads per call [ 40 trees x 1024 x
  3.6 ms ~ 147 s on a full map ].
  - one call before the node loop, one after it, one more per commit inside it.
  - place calls `seal_nodes` per chunk and holder with a planned seal, and each
    `_context` builds a new lazy map : the cache starts cold every time.
  - a replay-order chunk has few shards but may have files of nearly every tree,
    so `tree_manifests` can list nearly all trees on every call.
  - rough upper estimate : 2-3 calls x ~181 chunks x 147 s = 15 to 22 hours per
    holder, with many missing nodes spread over all chunks, a full map and 40
    trees. an empty or small map costs less ; dirty shards, never evicted,
    lower it too. possibly worse than the dry run. profile this next : a fast
    dry run does not make a fast place.
  - fix : one pass per call in shard order, checking every tree's files of a
    shard together [ at most 1024 loads per call ], or count `held`
    incrementally from `@new`.
- `_select_addresses`, per chunk and holder : copies all of `_cats`, walks all
  trees.
- `holder_check` [ Seal.pm ], run after the seals and by the holder-check
  command, has the same pattern : a loop over `sort keys` of the map, then
  `receipt_covered`, then `receipt_digest` [ which calls `receipt_covered`
  again ] : about 4 random lookups per node, ~88 minutes per full 370 k holder
  by the same model, in every coverage mode. let the one-pass helper of fix 1
  serve it too.

## parallel plan [ after fixes 1 and 3 ]

### unit of work : one forked worker per holder

holders are independent in `_copies` and there are 4 of them. this is where the
decrypt time is. node ranges are not needed for it.

- fork early : after `holders_load`, `head_survey` [ needs all holders for the
  stale floors ] and `n7fs_now`, before `_disk_context` and `upload_start`.
  the parent replays the journal while the workers decode maps. `_copies` takes
  nothing from the replay or `_cats` [ read from the code ] ; this means moving
  its call ahead in `place_missing`, and `run_filter` still needs the
  definitions : filter refusals then come after the fork, and must reap the
  workers.
- today `upload_start` runs before `_copies` : forking first keeps the holder
  workers clear of the upload pipes and of the `END` upload stop. close each
  child-side pipe end in the parent right after its fork, or later forks \
  workers hold it open, a dead worker never gives EOF, and fail closed turns
  into a hang. upload workers forked later must also close the parent's
  holder-worker pipes.
- worker : `_context( root, spec, TRUE )`, `receipt_fresh`, the one pass, the
  state decision. `_context` with recover = TRUE skips `_state_write` ; keep it
  that way, and check that nothing else in the worker writes.
- result : state, coverage, receipt version and age, used, covered, count,
  pending, warnings, covered set, and the set of mapped but not covered
  addresses. the walk only asks `nodes` whether an address is mapped, so with
  `_stream` that second set plus the covered set can replace the lazy map.
  `holder_drain` reads entries [ disk ids ] and stays serial unless it gets its
  own result form.
- transport : no json. length prefixed frames [ reuse `_pipe_write` \
  `_pipe_read` in Seal.pm ], address sets as their packed 93 byte buckets, loaded
  without re-insert. 370 k addresses ~ 34 MB per set and holder. the parent
  drains the pipes while workers run [ IO::Select ].
- failure : fail closed. a worker that dies, sends a short or unfinished frame,
  or exits non-zero refuses the run. it never becomes "no copies" or
  "unreachable". refusals [ rolled back head ] reach the parent unchanged ;
  "unreachable" stays the worker's own state decision as now.
- merge in sorted holder name order, so output and warnings are stable.
- workers leave with `POSIX::_exit` [ no END blocks, no temp dir cleanup ].
- at most 4 at once ; an env switch for serial, like `N7FS_UPLOAD_ASYNC=0`.

### forked workers over node ranges : only if the walk still matters

workers can compute per node : categories, target, size [ `-s` ], the `have`
domains and which holders accept it. they return only nodes with need > 0, in
fixed ranges merged in the serial walk order. that order is: replay iteration
into chunks of 2048, each chunk sorted. the parent then runs the greedy choice
alone. at ~11 s of walk this is not worth it first.

### stays serial

- greedy assignment : `%left` and its sort decide the next node's holder.
  split over workers it overfills holders and changes the plan.
- journal chain checks and operation order. signature verify and decode could
  run ahead in parallel ; applying cannot. gain unmeasured.
- receipts, receipt records, clock floor, seal state and version counter :
  `_state_write` is read-modify-write without a lock seen in these paths.
- holder writes and commits. parallel seals to different holders share that
  counter and the version reservations : separate design, not part of this.

### expected speedup on 4 cores

estimates : replay 10-40 s [ R ], walk ~11 s, 4 holders x ~6-10 s [ H ]. with
the early fork the wall time is about max( R, slowest H ) + walk.

| case                       | serial run | 4 workers | speedup      |
|---                         |---         |---        |---           |
| without fixes [ per holder]| ~5.9 h     | ~1.5 h    | ~4x, useless |
| after fixes 1 + 3          | ~45-90 s   | ~20-55 s  | ~1.6 to 2.5x |

the second row ignores transfer and merge cost. the single core fix is worth
about two orders of magnitude, workers a small factor after it. with 4
efficiency cores, a parent busy beside 4 workers and shared memory bandwidth,
expect the lower end. unequal holders : wall time follows the slowest map.
fewer than 4 holders : less gain. recommendation : do the fixes, measure on
azurum, then decide.

### risks

- ssh holders : `head_survey` in the parent may leave open sessions
  [ `_session_call` ]. children must not share them : close before the fork or
  open per child. check how the upload workers handle it. ssh runs are bound by
  the network, and the current thrash probably refetches evicted shards in 64
  blob prefetch windows [ read from the code ] : not measured.
- memory : 4 workers each with one pass buffers, beside the parent's replay.
  test-n7fs-place-memory.pl reads VmHWM of the placing process only : measure
  peak rss over the whole process group.
- root keys exist in every child [ same process image ] : no exec, no output of
  them, short lived.
- a head may change between the survey and a worker's read : same window as
  today, wider across processes.
- equality test, required : serial and parallel give the same status fields,
  plan, unplaced and skipped, also with a stale holder, an unreachable holder
  with grace, an excluded one, a legacy and a void receipt, and a killed
  worker [ must refuse ]. fakes only. a dry run skips `upload_start` : include
  a non dry run case with upload workers running [ fake holders ].

## to check on azurum before and after [ operator ]

- release count and tree count in the real journal ; nodes without category.
- mapped, covered and shard count per holder ; holder types [ local \ ssh ].
- backends : JSON::XS [ JSON::PP is warned as ~150x slower to decode ], the
  ed25519 backend [ CryptX ], which code decrypts. the 2.26 ms decrypt is the
  largest part of a miss and is worth its own look.
- a dry run with phase times before and after fix 1.

#,,.,,...,.,.,,,,,.,,,.,.,...,..,,...,,..,,.,,..,,...,..,,,.,,,..,.,,,...,.,.,
#HNXZESE7VVWWUZ6THI7ZWGQAQSIJQKMSY6RCR3M4MZSEJV4HGAG5PYBAXYX5U7U45VS2PQVWDJ5Q6
#\\\|ECCZ3PPJS7OYAEGWLXORQC5KO5HL7VI52G7JE2OIH3QTXB63C5T \ / AMOS7 \ YOURUM ::
#\[7]3EKVMEXSKDH7TJZ33TLL3XQREFBHE5AJ6O7HR52HGEY7QCWAHSAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
