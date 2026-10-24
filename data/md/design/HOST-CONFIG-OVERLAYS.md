# host config overlays

2026-10-24 [ owner + claude ]. the per-host layer that replaces the
local-modifications commit on top of `base` : what one host decides
[ a dns bind, an acme provider, a model, a link grant ] lives outside
the tree, the tree stays the same on every host.

## where

| path | owner | what |
|---|---|---|
| `/etc/protocol-7/` | root:protocol-7 0755 | top level [ base.path-set-up : root owned since this change ] |
| `/etc/protocol-7/host-config/` | root:root 0755 | the overlays [ base.host.config_dir ] |
| `/etc/protocol-7/host-config/<zenka>.cfg` | root, 0644 \ 0640 with the zenka group for secrets | 'key = value' over that zenka's config [ base.load_host_config ] |
| `/etc/protocol-7/host-config/host.detected` | root 0644 | detected facts [ base.host.detect : ram, cpus, ipv6 ] |
| `/etc/protocol-7/<zenka>/` | the zenka user | the zenka's own state [ keys, tokens, records ] -- never an overlay |

`host-config` is no zenka name : the loader and check-zenka-paths refuse
it, a zenka of that name would own the overlays.

## the trust rule

an overlay sets keys of zenki that may run as root [ v7-zenki ] or decide
access [ cube ]. it is applied only when `base.host.trusted_file` accepts
it : a regular file, no symlink, and the file and every directory up to
`/` owned by root or by the tree owner [ a dev checkout's user -- never
the zenka user ], no group \ other write. else : one level 0 line
`host overlay ... REFUSED : <why>`, nothing applied. the same rule holds
for `[load_config_file_if_present:...]` layers.

the reason : the zenka user owns `/etc/protocol-7/<zenka>/` by design.
an overlay there [ the old `<zenka>/host.cfg` ] could be replaced by any
zenka running as that user -- a protocol-7 zenka could rewrite root
v7-zenki's settings or cube's grants. a root-owned file in a writable
directory is not enough : the directory entry can be renamed away.

an old `/etc/protocol-7/<zenka>/host.cfg` is never read and never moved
by the code [ moving it would make a possibly zenka-written file
trusted ] : it is logged at level 0 until the admin reviews and moves it.

## cube : host-local grants

cube loads its overlay after `access.users` : `access.cmd.usr.<label>`
for one host's link goes into `host-config/cube.cfg` of the receiving
host, not into the tree. `external.authorize-link` reads the same two
places [ tree, then the overlay, the overlay's line wins ]. a first cube
overlay needs a cube restart : `reload config` re-applies an overlay
only once one was applied at start.

## moving a host [ once, as root ]

1. review every `/etc/protocol-7/*/host.cfg` [ content, owner ]
2. copy each to `host-config/<zenka>.cfg`, root owned, mode kept [ a
   root 0600 file is read at start only, before the privilege drop --
   as before ]
3. pull, restart the zenki ; check each zenka's `host overlay : <path>`
   line and that no `REFUSED` \ `NOT applied` line is left
4. then remove the old files

## open

- `[load_host_config]` is in 12 of 127 zenka.v7 files : applying it in
  the loader for every zenka would make any zenka host-customizable
- `/etc/protocol-7/protocol-7.proto-version` is protocol-7 owned and
  read by root zenki [ nodes.cmd.update-protocol-elf writes it ]
- the zenki that share the protocol-7 user can still write each other's
  `/etc/protocol-7/<zenka>/` state -- a per-zenka user would separate it

#,,.,,,.,,,..,.,.,.,.,..,,,..,,.,,,,.,,,.,...,..,,...,..,,.,.,,,.,,..,.,,,,,,,
#AC7S3DHOCOYSJSYZG3YCQPT4CCQA7ZFUAG2RCWJK2HKC3FUXDGGAIOMVV3CLNLNYT76YPDBD2W26S
#\\\|D6226SOGJLVJPI2ADTENYP4F7SUF2QGOWQJQDCPYF2EQGVKUQR2 \ / AMOS7 \ YOURUM ::
#\[7]RBPCSUFONKUSFM3VLKGLLOTISOE34GMKPY3OGWJQDLOYH2HIEWCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
