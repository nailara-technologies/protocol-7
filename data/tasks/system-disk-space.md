# system zenka : disk space awareness

status : brief [ owner 2026-11-23 ] -- not dispatched.

## why

2026-11-22 \ 23 on azurum : the tier B n7fs import filled /data to 256 KB free [ 659 G ]. the
import stopped cleanly [ n7fs refused on ENOSPC ], but everything else writing to /data failed
at the same moment, and nobody was warned before. the system zenka already watches memory
[ mem.max_used, acceleration, oom handling ] -- disk space has no watcher at all.

## shape

- the system zenka polls every mounted local file system [ statvfs : bytes AND inodes ], skips
  pseudo fs [ proc, sysfs, tmpfs unless configured, overlay of containers ]
- thresholds per mount, in the house config style, with defaults :
  disk.warn_free = 13 %   disk.critical_free = 5 %   [ and an absolute floor in G for big fs ]
- poll rhythm through base.interval [ a disk type : slow when there is room, faster as free
  space falls -- like the memory acceleration ] ; never a round interval
- a growth estimate : free bytes over the last polls -> time until full [ 'full in ~40 min' ]
- events : a warning and a critical level through the usual notify path [ p7-log, notify zenka,
  nshell ], each once per crossing, again on recovery
- a command : system.disk-status [ every mount : size, used, free, inodes, trend, eta ]

## acting, not only watching

- writers register : a long job [ n7fs import \ place \ restore, downloads, renders ] tells the
  system zenka where it writes and how much it expects ; the zenka answers whether it fits and
  warns or pauses a registered job before the fs is full [ the job decides ; nothing killed
  for disk ]
- n7fs import gets a pre-check : the expected store growth [ what is not in the store yet ]
  against the free space, refused with the numbers before it starts
- never deletes anything on its own ; a cleanup is a suggestion with candidates [ caches,
  temp dirs, old journals ] and a command the owner runs

## follow-ups from the first live run [ 2026-11-23 ]

- a 'recovered' event at the first poll for a mount that was never in warning [ /boot/efi :
  vfat reports 0/0 inodes ] -- recovery only after a real warning, 0/0 inodes = not counted
- read-only mounts [ ro in /proc/self/mounts ] are reported as read-only, never warned about

## fixed share for a store [ owner 2026-11-23 ]

a store [ n7fs disk, download area, render cache ] may need a fixed share of a shared fs, so
it can never fill the disk others write to. two ways :

- xfs project quota on the store directory [ prjquota mount option, xfs_quota project + limit ] :
  a hard size and inode limit for one tree, no extra layer, grown or shrunk at once by a new
  limit -- the preferred way on xfs
- a container file [ sparse file + loop + xfs ] : a movable \ sendable unit with its own fs ;
  grows online [ truncate, losetup -c, xfs_growfs ] but never shrinks ; for stores that must
  travel as one file [ a stick, a holder image ]

the system zenka reports a store against its share as well as the fs ; n7fs refuses an import
that does not fit the share.

- auto-grow with a ceiling [ owner ] : a share starts small and grows in steps as its content
  grows [ a project quota limit raised, or a container file extended + xfs_growfs ], never past
  its configured maximum
- shares on one fs know each other : before a step the system zenka checks the free space of
  the fs against what the OTHER shares may still claim [ their ceilings minus their use ] and
  a reserve for everything else ; a step that would let the promised ceilings exceed the fs is
  refused or made smaller, with the numbers -- the shares are one ledger per fs, owned by the
  system zenka, not by each store
- the step size and the check rhythm come from base.interval [ no fixed steps ]
- shrinking : a project quota limit is lowered at once [ down to the current use ]. a container
  file never shrinks its fs [ xfs ] -- a smaller ceiling means a second, smaller container, a
  copy, a swap [ room for both meanwhile ]. real space still comes back without that : fstrim
  on the mounted container [ or the discard mount option ] punches the freed blocks out of the
  sparse file

## ties

- the power \ host-build tools read the same status [ a build refuses a target fs that is too
  small ] ; the net zenka brief's 'owned state' idea fits : the zenka knows what the space is FOR

#,,,.,.,,,,..,.,.,,.,,,,.,.,.,,,.,,..,..,,,.,,..,,...,..,,.,,,,.,,,,.,,,,,...,
#ZMF44FWEQNJ46T53ZCKP6F5MRIVYBYC63WZZ2YVJY6HGBCRL33RZF3U6Y6FKL7VMQ6IQ3W36KYWZS
#\\\|BL6QUAN4VU5YJCD63ZDZYYLKN2UQSR34D3A3V2MIJHYTOK4BNK7 \ / AMOS7 \ YOURUM ::
#\[7]6CGCH5YRSB2PSJ57NTJJS4JHT7NX26SVKBNB4D3744XGHQJMA2BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
