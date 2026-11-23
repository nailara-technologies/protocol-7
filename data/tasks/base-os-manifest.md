# base os manifest : signed bmw manifests of the base system, checked nightly and at level transitions

status : brief [ owner 2026-11-23 ] -- not dispatched. ties into data/tasks/host-memory.md
[ genesis, awareness levels, pins ], data/tasks/host-build.md [ the first manifest ], the
forensics zenka [ src/forensics.* : nightly sweep ], bin/bmw-manifest [ -o, --verify ].

## why

the base system is preferred unencrypted now. root on it can change files, manifests and the
checking code alike -- so a check on the base is an early warning, and the real check runs
from the next security level, which holds the process until the base is verified.

## what is covered

- content [ bmw-512 ] : /boot [ kernel, initrd, grub config, /etc/grub.d/41_p7-systems ],
  /lib/modules/<version>, the loader and libc, sshd, sudo, su, login, pam modules, systemd
  units and their drop-ins, /etc/ssh, sudoers[.d], pam.d, the p7c \ p-7-r binaries
- metadata only [ owner, mode, type, no content ] : files meant to change [ shadow, logs ]
- running state : loaded kernel modules against the manifest, /proc/sys/kernel/tainted,
  secure boot state where available -- clean on disk is not clean in memory
- the list itself is config [ p7 config style ], versioned ; the manifest names the list
  checksum it was made under [ rules bound to data, as in host-memory.md ]

## baseline and legitimate change

- p7-host-build writes the first manifest ; its checksum goes into the host memory genesis
- a dist-upgrade through the debian zenka [ p7-dist-upgrade ] writes a new manifest after it,
  with the changed package list, as a host memory entry -- only that makes it the baseline
- a changed file without such an entry is a finding, not an update
- dpkg --verify as an independent second source [ debian's md5sums : weak, external format,
  useful exactly as a cross-check ]
- the manifest checksum is pinned off the host too [ installer, peers ], like the memory's
  first line

## two checks

1. nightly, on the base : a second sweep kind in the forensics zenka next to the log sweep,
   in bounded slices [ forensics.sweep.step style ], rhythm by base.interval.next around the
   04:07 entry. an early warning only -- it runs on what it checks
2. at the security level transition [ owner : the perfect place, it can still hold the
   process ] : the next level [ unlocked by the owner, with the verifier and the reference
   manifest on its encrypted part ] verifies the base from outside BEFORE trusting it -- and
   holds the transition until the result is known :
   - clean : the transition goes on, a record entry
   - changed with a recorded upgrade : goes on, record
   - changed without one : the transition stops at a decision point, the owner sees what
     differs ; going on anyway is possible but recorded as such
   - the next level never runs code from the base it has not verified

## nested levels [ owner ]

- levels are as many as there are security context differentials [ owner ] -- not a fixed
  ladder : progressive [ 1 <- 2 <- 3 ] or in parallel [ a work context and a private context
  beside each other on the same base ], each with inclusive components [ shared, checked by
  every context that includes them ] and exclusive ones [ seen and checked by one context
  only ]. a level is a node in a graph, 'below' means 'what this context relies on'
- each level verifies what it relies on before trusting it : 1 <- 2 <- 3 <- 4 ...
- parallel contexts do not see each other's references ; a component both include is checked
  by both, independently -- a mismatch seen by one is its own finding, not shared by default
- checksums only point inward : a level holds the reference manifests of the levels below,
  never the other way round. a compromised level 2 never sees what level 4 holds about it,
  so it cannot tailor its tampering to pass -- it does not know what will be compared
- inward checksums are safe to keep in the network, also of local systems : a checksum says
  nothing about content [ privacy ], it only lets a higher level recognise the same bytes.
  peers \ n7fs replicas can hold them for a host without learning anything about it
- each level's reference is sealed to that level's key ; the outer pins [ installer, peers ]
  hold only checksums of the references, not the references
- a level that finds a mismatch below stops there : it does not unlock the levels above it

## entry levels [ host-memory.md awareness ladder ]

- change with a recorded upgrade : record
- change without one, found nightly : security-alert
- mismatch found at a level transition : forensics-alert
- dpkg \ manifest disagreement : security-review

## open

- where the verifier lives per set-up [ recovery partition, the encrypted data part, a stick ]
- kernel module signatures and secure boot : use where present, never required
- manifest size and speed on slow disks [ slices, a quick mode on metadata + boot only ]

#,,.,,,.,,,.,,,,,,...,.,.,,..,..,,.,.,,.,,.,,,..,,...,...,.,,,.,,,,.,,.,.,.,,,
#D5YQ26F2GMPGPTENC57VY5MQGKDSEQFQ65WD2MDLP3HVVWXQQXO5NRKM764MO2MHLUZLG6DC7XYPC
#\\\|SJS4S3XZ5RIQI24WUYYPCZIES6QCX5KY2SXLBSJEY5O52OCPEM7 \ / AMOS7 \ YOURUM ::
#\[7]3TY67SXCUPP4FOQNDDJNPA6A2A76AK2QYSEI4AO4TNNM3QR2DGDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
