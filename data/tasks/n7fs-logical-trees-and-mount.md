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
measured after the change [ 2026-11-21, ~338,000 references ] : ~270 references \
second, ~21 minutes for the whole disk [ the old code ran > 9 hours unfinished ]

## requirement : every mobile holder is a full recovery point [ owner 2026-11-21 ]

- each mobile holder alone can recreate the whole set-up : it carries the complete
  critical set [ important documents, the key trees, the private notes ], the
  checkout with the n7fs tool, and the host configurations as n7fs trees -- not just
  a share of the copies
- the root key travels only inside the passphrase-protected vault, never in plain
  text : a lost device yields nothing, the owner restores everything with the
  passphrase
- network boot : one mobile holder can boot the other over a cable [ pxe : dnsmasq as
  dhcp \ tftp on that link ], serving a small rescue system that restores the other
  machine's os tree and host configuration from n7fs -- partitions from the saved
  layout, the original configuration back, the bootloader installed. two devices and
  a cable are enough for a bare-metal restore
- a phone node [ a linux vm or termux on the phone ] can do the same over wlan, with
  one limit : pxe firmware boots over cable only. so the phone either presents itself
  as a usb boot medium [ needs root on the phone ] or as a usb network card [ uefi
  http boot on newer firmware ] ; the booted rescue system then fetches the trees
  from the phone over wlan or usb tethering. what boots is chosen on the phone : the
  generic android app shows a selection in the house style [ amnesic session, install
  the user desktop, restore a given host, rescue only ]. needs a real data cable --
  many phone cables only charge. while the system runs, the same app is its
  dashboard [ state, load, what is mounted, sync progress ] and remote control :
  hibernate the session TO the phone [ the session image, encrypted with the context
  key, stored on the phone node -- input-and-window-forwarding.md part c ], then power
  the machine off ; resume later on this or another machine. on a headless machine
  [ a server, a board without a screen ] the phone app is the console : it drives
  installation and operation, and offers an optional shell [ nshell or a plain shell,
  over the authenticated link -- never an open port ]. it also guides disk
  replacement : identify the disk [ model, full serial from hdparm, not a truncated
  sysfs string ], show smart and firmware, walk the steps [ power off, insert,
  hot-plug ] with confirmation on the phone, show copy progress live, and start
  `n7fs place` afterwards to refill the copies
- amnesic boot : the rescue system runs from ram, the user desktop comes in through
  the n7fs mount [ read-only or add-only ], nothing is written to the local disk and
  nothing remains after shutdown -- for a borrowed or unknown machine, the
  prepared-and-locked session of input-and-window-forwarding.md
- proven, not assumed : a regular `n7fs drill` from each mobile holder with no other
  host involved, and occasionally the network boot itself
- the rarely changing critical data [ document masters ] syncs once and then only
  adds redundancy ; fast-changing working data stays on the fixed hosts

## follow-up : a progress bar for long n7fs runs

- set-category [ and assimilate, place, restore ] show a progress bar on a terminal :
  percentage, rate, estimated time left -- following bin/format-code's console bar
  [ reuse its code or move it into a shared module, no second implementation ]
- when output is not a terminal [ a file, a log, a pipe ], the plain progress lines
  stay as they are now
- colours for the n7fs console output in general [ bars, ok \ refused \ warnings,
  tree and disk names ], following bin/amos-chksum's colourised command output --
  the same palette rules as the other surfaces [ background on the element only,
  calm colours, the theme tokens where the console adapter reads them ], plain text
  when not on a terminal or when -nc [ -no-color ] is given

implemented [ 2026-11-21 ] : `tree-name:` and address targets resolve node paths
directly ; `tree:` \ `path:` build a replay-backed holder index and read only
candidate nodes. reference records stream instead of accumulating per-node scan
results. each call writes one existing `batch-assignment` record and one journal
entry ; journal and batch formats did not change, and old per-reference journals
still replay into the same current assignments. stderr reports progress at
five-second checks and completion.

synthetic temporary-store measurement, 3000 references and all three selectors :
legacy 39.428 s, new 8.532 s total [ tree-name 14.930 -> 4.961 s ; tree 11.501
-> 1.771 s ; path 12.996 -> 1.800 s ]. the timers cover the set-category calls,
not fixture creation or final verification. all 13 equivalence, selective-read,
old-journal, batch-replay and full-verification checks passed. command :
`N7FS_TREE_CATEGORY_SCALE=3000 perl
bin/test-scripts/test-n7fs-tree-category-performance.pl`.

## rules

- p7 config style, no json ; internal checksums BMW \ AMOS, no sha ; perl floor 5.32
- timers \ retries through <[base.interval.next]>
- never touch the live n7fs tree in place during development [ it broke twice ] --
  a copy or a test store
- no host names, disks or personal data in repo files

#,,,,,,..,..,,,,.,..,,,..,,..,,.,,,.,,,,,,..,,..,,...,...,...,...,...,,.,,...,
#H6D36DN2MUKSPERHTZV2CIJALT5KYMWHIQCLFMYNH7FRP2T3E4TSCYFIID2B4VAT4XQ7RUGY65GAQ
#\\\|R6XOIRIXJXOF2EHDUAEEUBIBA6YSIWL5D7HZM4HISESVV4VSTM5 \ / AMOS7 \ YOURUM ::
#\[7]BYGVUQJNVJHFO2IEJ22S4KFK4QHEWZMPVLOWLJ4PBLJKFAKQ3GDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
