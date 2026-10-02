# osf-cache — operating system file cache

design [ 2026-10-03 ]. todo `AT5` [ new-zenki ]. companion :
`data/md/design/OS-PKG-GENERIC-PACKAGE-ZENKA.md`.

## role [ user ]

a deduplication backend for operating system files : distribution-
agnostic but configurable, protocol-7 as storage and transport, files
replicated efficiently from the many locations that already have them.
in a larger debian network every node that holds a package [ or more
precisely its files ] holds something interesting to the others, and
earns network credits for sharing them as desired workload. the pool
equalizes ; incentive curves match expectable acceleration patterns.

## the key : hashes are already there

the feature is easy because trustworthy hashes are cheap to acquire :

- **debian archive** : `InRelease` is signed by the archive key ; it lists
  the sha256 of each `Packages` index ; each `Packages` entry lists the
  sha256 of its `.deb`. one signature anchors every package file.
- **installed files** : dpkg keeps per-file md5 sums of every installed
  package [ `/var/lib/dpkg/info/<pkg>.md5sums` ] -> a node can prove what
  it holds without reading the archive again [ md5 only for lookup, the
  .deb sha256 for trust ]
- other distributions have the same shape [ rpm repodata, alpine apkindex ]
  -> distribution-agnostic through a per-type index reader, configurable

validity : a file's hash is accepted when it is anchored in a signed
distribution index, OR confirmed by 5-of-7 consensus of independent
nodes [ for files outside any signed index ]. once valid, holding it is
safe to distribute -> it gets routed ; otherwise the space would be
wasted and usefulness stall.

## components

```
index readers     per distribution type [ debian first ] : signed index
                  -> { file hash, size, package, version }
holdings          what this node has : scan of the local apt cache
                  [ /var/cache/apt/archives ] + dpkg md5sums, announced
                  as hashes only
store             content-addressed, chunked [ base.chunk.rolling_mod
                  family with min \ max guards, or whole files first ]
transport         protocol-7 routes ; fetch from several holders at once
                  [ segments in parallel, like bittorrent pieces ]
verify            every received file \ chunk checked against the anchored
                  hash before use or onward sharing
credits           bytes served vs bytes received per node ; curves
                  [ below ]
eviction          least-useful first : rarely requested, widely held
```

## passive supply [ user ]

nobody has to keep apt files on purpose : many nodes still have an apt
cache they never cleared [ `/var/cache/apt/archives` ]. those `.deb`s
already match the signed index hashes exactly -> free supply, announced
by hash, available at whatever bandwidth the node has. many low-bandwidth
holders together saturate a download the way bittorrent swarms do.
installed files alone do not reproduce an identical `.deb` [ packaging
metadata, modified conffiles ] -> exact-hash sharing relies on cached
`.deb`s ; installed files only help at the file level later.

**seeding on purpose** [ user ] : pin a file in the regular cache location
so cleanups do not remove it. mechanics :
- plain write protection does not stop root : apt runs as root and
  deletion depends on the directory, not the file's mode bits
- `chattr +i` [ immutable ] does stop root on ext4, but apt clean then
  reports errors on every run
- cleanest : **hardlink** the `.deb` into osf-cache's own store [ same
  filesystem ]. apt may delete its link ; the data stays as long as osf
  holds a link, and osf keeps serving it. no fight with apt, no errors
- apt can also be told to keep downloads [ `APT::Keep-Downloaded-Packages
  "true"` ] -> fewer files disappear in the first place

**virtual cache via fuse** [ user ] : osf-cache can present the cache
location as a fuse filesystem. every `.deb` that is anchored in a signed
index and held somewhere in the field "exists" there ; reading it fetches
segments lazily, verified, from the nearest holders. apt sees a normal
cache, finds the file with the right size and hash, and skips the
download. deleting from it only unpins locally.
- closest precedent : **cvmfs** [ cern vm filesystem ] — read-only fuse,
  content-addressed, lazily fetched, signed catalogs, used to distribute
  software to large computing grids
- careful : apt may stat \ size-check files before reading -> size must
  come from the index, never guessed ; a read that cannot be satisfied
  must fail cleanly so apt falls back to the mirror
- **reuse** : the data zenka already mounts its hash tree via fuse
  [ `data.mount.fuse.*` : `spawn` forks the fuse child [ Filesys::Fuse3 ],
  `getattr` \ `readdir` \ `open` \ `read` \ `release` \ `statfs`
  callbacks map fuse paths to hash paths ]. osf-cache needs the same
  callbacks with a different resolver [ index entry -> held segments ],
  not a second fuse stack
- **apt writes into its archive dir** [ `partial/`, the `lock` file,
  fresh downloads ] -> the mount must not be read-only there : pass
  writes through to a real directory [ overlay-style ], or point apt at
  the mount with `Dir::Cache::archives` while partial \ lock stay on
  disk. mountpoint ownership : fusermount needs the mounting user to own
  the mountpoint -> a dedicated directory owned by the zenka user, not
  `/var/cache/apt/archives` itself

**taking over /var/cache/apt** [ user ] : mount the whole cache directory
via fuse, so files not downloaded yet are caught and fetched transparently
in the background, serving the first bytes as soon as they arrive.
inside its own mount nothing [ not even root ] can make the serving zenka
behave differently ; root can only unmount it entirely.
- links : symlinks into the fuse files work ; hardlinks do not [ they
  cannot cross filesystems ] -> taking over the whole directory avoids
  needing either
- access : by default a fuse mount is visible only to the user who
  mounted it, even root is denied -> needs `allow_other` [ mount as root
  before the privilege drop, like `debian.start.apt_child`, or
  `user_allow_other` in /etc/fuse.conf ]
- apt keeps more than archives there : `pkgcache.bin` \ `srcpkgcache.bin`
  [ mmap'd ], `archives/partial/`, `archives/lock` [ fcntl lock ] -> the
  fuse layer passes everything except anchored `.deb` reads through to a
  real backing directory [ overlay-style ], including locks and mmap
- streaming : apt and dpkg read a `.deb` sequentially, so a read blocks
  only on the next missing segment -> delay stays bounded. but the signed
  index anchors only the WHOLE-file hash -> per-segment authentication
  needs a merkle tree per file : computed once from a fully verified copy,
  its root bound to the anchored file hash, distributed with the file
  [ 5-of-7 confirmed ] ; then every segment verifies on arrival

## acquisition flow [ debian ]

1. os-pkg \ apt wants `foo_1.2-3_amd64.deb` with sha256 `H` [ from the
   signed index ]
2. osf-cache asks the field : who holds `H` ? [ hash lookup, no file names ]
3. parallel segment fetch from the nearest holders ; each segment verified
4. whole-file sha256 == `H` -> hand to apt [ e.g. place in its archive
   cache ], else drop and fetch the failed segments elsewhere
5. this node now holds `H` too and announces it

the mirror stays the fallback : if no holder answers in time, fetch from
the distribution mirror as today.

## credits [ incentive curves ]

- serving earns, receiving costs ; scarce files [ few holders ] earn more
  than widely held ones -> the pool equalizes toward even replication
- curves shaped to the expected acceleration pattern : a new release
  starts scarce [ high reward for early sharers ], becomes common
  [ reward falls ] -> matches how popularity grows
- the water-filling \ max-min fairness principle from the philosophical
  foundation : no node accumulates disproportionately
- credits are resource accounting inside the network [ bandwidth and
  storage contributed vs used ], not money

## roadmap : four virtual layers [ user, 2026-10-03 ]

the same mechanism [ content-addressed, verified, fuse-served, locally
cached, network-pooled ] applied layer by layer, each one only after the
previous one runs clean. ultimate recreatability : a node is its keys
plus its templates ; everything else is fetched, verified, cached.

```
1  package cache   /var/cache/apt      read-mostly, mirror as fallback
2  /etc            from contextualized templates [ nixos-like, live ]
3  home dirs       overlay, incoming writes classified [ xdg dirs ]
4  /data           any structure, files larger than the local disk
```

**2 — /etc** : needed before any zenka runs [ fstab, passwd, init ] ->
always keep a materialized snapshot of the last good state to boot from.
secrets [ shadow, host keys ] never from shared templates : node-local,
encrypted with its own keys. local writes [ password changes,
resolv.conf ] go to a local overlay or back into the node's own template
parameters.

**3 — home** : `~/.config` template-backed per known app ; `~/.cache`
never replicated ; `~/.local/share` \ `state` replicated, encrypted ;
personal files replicated, deduplicated ; unknown writes to a quarantine
overlay until a rule decides. hard cases : sqlite \ browser profiles
[ locks, constant small writes ] and very large files -> snapshots
instead of live replication. precedents : home-manager [ nix ],
systemd-homed.

**4 — /data** : any directory structure distributed, files may be larger
than the local filesystem -- pooled across the network, looking local,
cached and evicted like layer 1. precedents : cvmfs, rclone mount with vfs
cache, files-on-demand sync clients. the hard part is shared MUTABLE data :
keep chunks immutable and content-addressed, make only the pointers
mutable [ git-like versions ], so concurrent writers produce versions,
not corruption.

## prior art to compare against

- **apt-cacher-ng** : one local caching proxy for a site [ no p2p ]
- **apt-p2p**, **debtorrent** [ debian gsoc 2007 ] : bittorrent-style
  debian package distribution — closest predecessors
- **ipfs** : content-addressed p2p storage in general
- **nix binary caches** : content-addressed, signature-anchored packages

## stages

1. debian index reader + holdings scan [ read-only, hashes only ]
2. hash lookup across nodes [ who holds H ], no transfer yet
3. single-source fetch + verify, apt archive-cache placement
4. multi-source segment fetch
5. credits accounting
6. second distribution type

#,,,,,..,,...,,..,,.,,.,,,,..,.,.,...,.,,,.,.,..,,...,..,,,,,,.,,,,..,,,.,,,,,
#3E2OMHKOZRCG6OOS4CZ7HCEOG737GQQYOSCNFYPGCOM76AFJJ5BA7UO3J6AME3H77G7IHJZLM2PHQ
#\\\|L3DLS7FIYPY6RLSAWKN4ECWRHBGIOLJFIDM3L4HSTW2S6YUMZUY \ / AMOS7 \ YOURUM ::
#\[7]2ZEFZ2N6SDRHNQJ5HPZQSQ2RW33V6ZXZCCT46CT33Q5J2RDLQICY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
