# assimilation : categories and depths

draft 2026-10-21 [ user + claude ]. 'assimilate' names the whole process of
taking something outside into protocol-7 -- from one file into the N7FS
store up to a whole host into the resource pool. it builds on
[ N7FS-SPEC.md ] [ section 7 ], [ N7FS-FORMAT-1.md ] [ 'assimilate' ], the
managed-abstraction principle [ data/ai-mem/claude/vision-managed-abstraction.md ]
and the hints.* detection layer [ todo Q7O ].

## categories : what is taken in

| category | takes in | identity | trust | layer |
|---|---|---|---|---|
| file-import | content | its checksum [ amos \ BMW ] | verified by its own checksum | `n7fs assimilate` |
| setup-import | statements [ ssh config, hosts, known_hosts, pins ] | its source [ file, line, context ] | sanity filter, ranking, the user confirms | `hints.*`, host-edit |
| key-import | secret material | its key id | ciphertext only, never plain | the keystore |

routing between them is part of the contract : file-import flags known
secret locations [ `~/.ssh`, key files ] and hands them to key-import
instead of storing them as plain content [ format 1 still stores them as
they are -- see N7FS-FORMAT-1.md ]. setup-import never touches key
material at all.

shared contract : every assimilated item records where it came from, and
nothing leaves its source before its new form is verified.

## depths : how far it goes

| depth | what happens | the source afterwards | allowed as default when |
|---|---|---|---|
| 0 observe | read only -- setup-import, candidates | untouched | always |
| 1 reproduce | an equal copy \ setup next to the original | stays authoritative | always |
| 2a move | the content lives at its checksum location only [ the original assimilate script, no double storage ] | removed | the stored copy is verified and nothing else uses the source path |
| 2b move + link back | the content lives in the store, the path stays as a link | a link | see 'hybrid links' below |
| 3 replace | a service becomes a native zenka [ postfix -> smtpd zenka ] through a full feature + value mapping | kept as 'previous' until confirmed | the mapping reports NO loss and the re-export gives a working original setup [ checked ] |
| 4 host | a whole host joins the resource pool | -- | composed of 0 .. 3 per service |

### the rule

**a source may go away by default only when getting it back is proven.**
the default is the deepest depth whose condition holds ; `-keep` \
`-remove` stay explicit overrides. the context decides by what the source
IS : a downloaded image may move, `~/.ssh/config` never moves [ ssh reads
it ], a postfix setup is replaced only through depth 3's proof.

because every step is reversible with one command, an automatic decision
is defendable : nothing is locked in [ same line as warn-dont-restrict ].

### depth 3 : replace, with a way back

- import -> map -> re-export -> compare with the original [ byte-equal
  where possible, otherwise semantic : e.g. `postconf -n` on both sides ]
- any mismatch or unmapped feature : stay at depth 1, with a loss report
  naming exactly what is missing
- switching uses the N7FS epoch window `{ previous, current, next }` :
  write into next, switch when confirmed, the original stays 'previous'
  until it leaves the window -- rollback is switching back while it is
  open
- the mapping is the real cost : most services will first stop at depth
  1, which is correct and shows the gap

### hybrid links [ depth 2b ]

three questions decide, per path :

1. who READS it -- readers only : a link is fine
2. who WRITES it -- a path its owner writes [ ssh appends to
   `known_hosts` ] stays at depth 1
3. who INTERPRETS the path type -- git, tar, rsync without `-L`, backup
   tools treat a symlink as a link, not as its content

| form | storage | reach | under git |
|---|---|---|---|
| reflink [ `cp --reflink` : btrfs, xfs, bcachefs ] | shared blocks, copy on write | same filesystem | invisible, writes split by themselves |
| hardlink | one inode | same filesystem | invisible ; a checkout replaces the file [ unlink + create ] and silently detaches the link -- no harm, dedup lost |
| symlink | one copy in the store | anywhere | committed AS a link -- not usable in a work tree |

order : reflink where the filesystem can, a hardlink where the path's
tools only replace files, a symlink only where nothing interprets
symlinks, else depth 1.

immutability : store nodes are immutable by definition -- enforce it
[ `chattr +i` with CAP_LINUX_IMMUTABLE, else 0444 + verify on read ] so a
write through a link fails visibly instead of changing the store. a
hardlink shares the inode : `+i` then also locks the work-tree side, and
an immutable file in a git work tree makes checkout \ pull fail -- there
the store node is protected by verify-on-read only.

re-runs are harmless : `n7fs assimilate` skips symlinks and opens with
O_NOFOLLOW. rollback is one command : replace the link with a copy of the
node.

## history : the sourcecode checksum symlinks [ removed 2026-10-21 ]

`sourcecode.console.regen-checksum-symlinks` \ `.undo-checksum-symlinks`
[ experimental, never in use ] were depth 2b with symlinks : work-tree
files replaced by links into a version path `<version>/<checksum>`,
duplicate content stored once, one command back. the last commit holding
them is `50aaec5ae` [ `git show 50aaec5ae:src/<name>` ].

removed instead of fixed [ todo TNJ ] : they could not run any more
[ `version_root` defined nowhere, stale dir lists ], undo found links one
level deep only, both directions unlinked before creating. what they
taught is kept here :

- git commits a symlink AS a link -- the 'who interprets the path type'
  question above
- they stored FULL per-version snapshots, not diffs : large redundant git
  diffs. the real requirement : diff BACKWARD from the clean current
  state, complexity only on the history-access path
  [ ai-mem vision-tree-based-module-storage-and-namespace-manifests ]
- the dual version they used [ protocol-7.src-ver + rel-ver ] stays

a native N7FS feature with version-control coverage takes the place
[ todo base.yaml : 'version control as the completing element',
2026-10-11 ].

## open

- the secret-location list for file-import -> key-import routing
- loss-report format for depth 3, and where mappings live
- which depth a host-level assimilation [ 4 ] starts from per service

#,,.,,,.,,..,,,..,,,,,...,,..,,,,,...,,,,,,.,,..,,...,...,.,.,,..,,..,.,,,.,.,
#U2L4X7LCOUKHTXAACLF6P5GPLXBME2432QMWOYYTDDUTTCYGELWFNTBSE6JDT4VACG23ONMLGQ27E
#\\\|KO523KUF7Q4IB5TI2CT6FQEXBATMLPJNI4HZKXNCLP32WY2ZRSO \ / AMOS7 \ YOURUM ::
#\[7]DK6KA77W45AIETAMM4WJ5OZ7LQCP5IBJ35YNRIZKPNU5SESDGSBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
