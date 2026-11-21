# n7fs : logical trees above the disks, and an n7fs zenka that mounts them

status : brief, not dispatched [ owner 2026-11-20 ]. builds on
data/md/design/N7FS-TREE-CATEGORIES.md [ trees, categories, stage 1 ],
N7FS-PLACEMENT.md [ stage 5 : placement, receipts, under-replicated ],
N7FS-SEALED-REPLICAS.md [ holders, map ], N7FS-SEALING.md [ disk binding ],
N7FS-SYNC.md. raw mail archive and disk rescues as the first task trees
[ data/tasks/billing-watcher-pattern-first.md, 'a pattern beyond mail' ].

## problem

- a tree belongs to exactly one disk [ `n7fs assimilate -disk <disk> -tree <name>` ] ;
  task stores multiply into many disk-bound trees nobody keeps track of
- category policy [ copies, priority, want, replica choice ] exists as records only --
  'no operational enforcement in stage 1' [ N7FS-TREE-CATEGORIES.md, known limits ]
- data is only usable after a full `restore` to a target : no mount, no partial reads

## part 1 : logical trees and mapping

1. a logical tree is the unit : name, category, policy [ copies, holder set, priority,
   encryption, lifecycle stage ] live on the tree, not on a disk
2. mapping is a table tree -> disks \ holders. remapping changes the table ; placement
   moves only the chunks a new holder lacks [ content addressed : nothing rewritten or
   rehashed ] and drops them from the old one after the receipts arrive
3. `n7fs map` : one overview -- per tree its disks \ holders, size, copies actual vs
   wanted, under-replicated, moves in flight, lifecycle stage
4. lifecycle per tree : active -> archive -> cold. a finished task tree [ a disk rescue ]
   moves to fewer, cheaper holders without being touched
5. views : a named set of trees [ 'all rescues', 'everything from one machine' ] that
   resolves to the trees, never copies them
6. enforcement of the category policy that today is records only [ copies, priority,
   want, replica choice ] -- through the same placement path

## part 2 : the n7fs zenka and its mount

a zenka owns the stores of a host and serves trees \ views as a mount :

- read path : path -> tree manifest -> chunk addresses -> local disk store, else a
  holder fetch -> unseal \ decrypt -> bytes. metadata [ the manifest ] lives in ram once
  a tree is mounted : listings and stat never touch a holder
- caches : a bounded ram lru for hot chunks, a bounded disk cache on a local disk for
  fetched ones. a chunk never changes [ content addressed ], so a cached chunk is valid
  forever -- eviction only, no invalidation
- prefetch : sequential reads ask for the next chunks ahead ; a directory opened for
  reading may warm its small files
- writes, staged : stage 1 read only. stage 2 'add-only' -- new files land in a staging
  tree [ the incoming pool, N7FS-INCOMING.md ], sealed and placed later ; nothing in a
  sealed tree is changed in place [ the add-only log mount idea ]
- the fuse side REUSES the data zenka's mount [ src/data.mount.fuse.* : getattr readdir
  open read release statfs, Filesys::Fuse3 loaded on demand, `data.mount.fuse.spawn`
  forks a child that runs the fuse loop, mount registry + sigchld in the parent ] --
  same child model and callbacks, only the source behind read \ readdir changes
  [ manifest + chunk caches instead of the data hash tree ]. the zenka's event loop never
  blocks on the kernel ; the child gets no sealing keys, it asks the parent for unsealed
  chunks over the socket
- shared, not copied : what both mounts need [ path mapping, attribute building, the
  child lifecycle ] moves into a generic mount.fuse.* layer both zenki load
- mounts are host-signed attach \ detach records like today's `mounts/` entries

## stages

1. `n7fs map` read-only overview over the existing trees + the logical tree table
   [ no behaviour change ]
2. remap one tree between two disks on one host [ placement + receipts ]
3. the n7fs zenka : read-only mount of one tree, ram cache only
4. disk cache + prefetch ; views
5. remap across holders ; lifecycle stages ; category policy enforced
6. add-only writes through the incoming pool

## follow-up : category assignment performance [ 2026-11-21 ]

measured : `set-category` on a disk with ~270,000 references ran > 4 hours at 99 %
cpu and 2.5 GB rss, writing ~12 KiB/s. category_set_reference walks every
reference of every node and tests each one against the target ; `tree-name:` uses
the same loop. fix :
- `tree-name:` resolves through the tree manifest's file list directly [ the node
  set is known ] and reads only those nodes' references, not the whole disk
- `tree:` \ `path:` keep the scan but index references by holder path once
- assignments are written as ONE journal entry per call [ a batch record ], not
  one record per reference
- progress output [ references visited \ total ] so a long run is visibly alive
target : minutes, not hours, for a disk of this size

## rules

- p7 config style, no json ; internal checksums BMW \ AMOS, no sha ; perl floor 5.32
- timers \ retries through <[base.interval.next]>
- never touch the live n7fs tree in place during development [ it broke twice ] --
  a copy or a test store
- no host names, disks or personal data in repo files

#,,,,,,..,.,.,,.,,,,.,,,,,,..,,,.,..,,.,,,,,.,..,,...,...,.,,,,,,,,,.,.,,,,,.,
#SY3OX7BQNGKYJUC7MMU4HRY3SJLZ6JRFJEYG72XZHG5UXIXD4KCA46VTAQA566I6KPP6Y2ANKNEEG
#\\\|37JXLESPZUWDZMLUPMAHLLNSOU5DA7TPYY5TS7AHKU7ATIBWTQ3 \ / AMOS7 \ YOURUM ::
#\[7]LMUGL5QG62SOCY4IZUSYSOCQCSHWO5OOEL2MZWTWEK7MXK5742DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
