# osf-cache stage 2b : zenka wiring [ local node ]

follows `osf-cache-stage2-hash-lookup.md` [ committed `01edae6b8` ].
design : `data/md/design/OSF-CACHE-ZENKA.md` [ read `## hash layers` ].

this task = turn the offline modules into a running zenka that answers
for its OWN holdings. NOT in scope : asking other nodes [ the fan-out
needs a node-addressing decision with the user first ], fetching,
fuse. do NOT start the zenka, do NOT touch any running zenka, no sudo,
no commit -- the first live start happens in the main session with the
user.

## reference zenka : os-pkg [ mirror its shape ]

`cfg/zenki/os-pkg/` [ zenka.v7, start.cfg, deps/, subroutines.load-early ]
and `src/os-pkg.*`. post-drop startup pattern : `cfg/zenki/usage/zenka.v7`
+ `src/usage.startup` [ read its note ].

## 1. `cfg/zenki/osf-cache/`

- `zenka.v7` : shared-params, `modules.load = net protocol io.unix ui
  auth format.yaml osf-cache` [ add whatever else os-pkg needs for the
  same features ; base.chk-sum is part of base -- verify bmw.ctx \
  encode_digest are reachable ], explicit `access.cmd.usr.cube` list
  [ no wildcard : the os-pkg list minus install, plus `has status
  rescan` ], `[init_modules]`, `[root.drop_privs:<system.amos-zenka-user>]`,
  connect, session id, then `[osf-cache.startup]`, then `[zenka.loop]`
- `start.cfg` : like os-pkg [ on-demand, restart \ heartbeat disabled ]
- `deps/` and `subroutines.load-early` : produce them the way the repo
  produces them for os-pkg [ find the generator, do not hand-invent ;
  if it needs a running system, say so in the report and leave a
  clearly marked todo instead ]
- cube access for users : check how os-pkg is made reachable for users
  in `cfg/zenki/cube/access.*` and mirror it for read-only commands
  [ has, status, rescan ]

## 2. `osf-cache.init_code` [ param : reinit ]

runs BEFORE the privilege drop -> config defaults only, no filesystem
scan, no timers :
- `<osf-cache.cfg.cache_dir>` //= `/var/cache/apt/archives`
- `<osf-cache.cfg.lists_dir>` //= `/var/lib/apt/lists`
- `<osf-cache.cfg.state_path>` //= `<[file.zenka_dir.data_path]> .
  '/holdings.yaml'`
- `<osf-cache.cfg.scan_slice>` //= 4 [ files hashed per timer tick ]
- on reinit : keep `<osf-cache.holdings>` and any running scan as they
  are [ reinit guarding is a hard invariant in this repo : a reload must
  never break or duplicate state ]

## 3. `osf-cache.index.build` [ new, pure ]

move the index-combining logic out of `bin/dev/osf-holdings` into this
module : `{ lists_dir }` -> `{ anchors, algos, sources => [ { inrelease,
signature, signer, packages, anchored, entries } ] }`. only Packages
files that are anchored in an InRelease with signature `good` contribute
anchors [ same trust rule as osf-holdings today ]. `bin/dev/osf-holdings`
then calls it -- output unchanged. test it on the fixtures.

## 4. split the scan

- `osf-cache.holdings.scan_file` [ new ] : one `.deb` -> one entry
  [ the per-file body of scan_apt_cache, same reuse + anchoring rules ]
- `scan_apt_cache` keeps its API and result, now looping over scan_file
- existing tests must still pass unchanged

## 5. `osf-cache.startup` [ post-drop, called from zenka.v7 ]

- load state [ `state_load` ] -> previous files
- build the index [ `index.build` ; it blocks while parsing Packages --
  acceptable for now, log how long it took ]
- start a sliced rescan : `osf-cache.holdings.rescan_step` as a timer
  handler, `scan_slice` files per tick, building a NEW holdings result ;
  when done : swap it into `<osf-cache.holdings>`, `state_save`, log
  counts [ files, anchored, rehashed, bytes ]. never block the loop on
  hashing the whole cache in one go. find how other zenki run a
  repeating \ re-armed timer [ grep `event.add_timer` ; check the
  repo memory note on timer intervals ] and follow that
- `<osf-cache.scan>` holds progress [ running, done, total, started ]

## 6. commands [ `.cmd.` reply contract : `{ mode, data => STRING }` ]

- `osf-cache.cmd.has <algo>:<hex> [ ... ]` : `query_local` on
  `<osf-cache.holdings>` -> `format_has_reply`. before the first rescan
  finished : mode false, data `holdings not ready`. invalid token \
  over the cap : mode false with query_local's message
- `osf-cache.cmd.status` : human-readable lines [ files, anchored,
  bytes, rehashed, index sources with signature state, scan progress,
  state path ]
- `osf-cache.cmd.rescan` : start a rescan unless one runs [ then say so ]

## done when

- tests pass [ existing suite + index.build + scan_file split ],
  `bin/format-code -c` clean on every touched src file [ never plain
  `perl -c` ]
- module headers `## [:< ##` \ `# name` \ `# descr` \ `# param`,
  lowercase comments, `[ ]` not `( )`, `$ARG` not `$_`, calls without the
  `base.` prefix where a swap_subs alias exists
- report : files touched, test output, how deps \ load-early were
  produced, which timer pattern you followed and why, anything you
  could not verify without a running zenka

#,,,,,.,.,.,,,..,,.,.,...,,,,,..,,.,,,,..,.,.,..,,...,.,.,,..,,..,,,.,,..,..,,
#ORSRKXZYUY666LNV2BZDTXXL6J6DAUXVBHMASIYQLCX4KGPIOXSQREZKCLU4TZNI5HRYWH56JEEBM
#\\\|QYEY3N2632ZQE5PLHLYK5P7GJAFZTHZP6WQTZO3ZSBMEG6P34UZ \ / AMOS7 \ YOURUM ::
#\[7]MAUKRKAASOR4M3SWCEQIXUJDW6TZQUXPOYWCXTAGTGGSUJ6FP4CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
