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

## ties

- the power \ host-build tools read the same status [ a build refuses a target fs that is too
  small ] ; the net zenka brief's 'owned state' idea fits : the zenka knows what the space is FOR

#,,,.,,..,,,,,.,,,...,,.,,,,.,...,.,.,,,.,,,,,..,,...,...,..,,.,.,.,,,..,,,.,,
#NVXWNDGWBCHZALXNW2N24FKH7BLCNAP42Q6APQDMBADQUMYO4JIX255GJBKFNEOIVVDYSFZCFZWIO
#\\\|A2UEU4GS7DDIG7BER2DE4DMQJJWE4EBKJZHWV3XMMWAYDKEJNEF \ / AMOS7 \ YOURUM ::
#\[7]EIKOE4NTXWQP5NHQLTM2KVJ7ZV4MXPPQZVVGAPUXTFVXCNOISMBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
