---
name: install-via-debian-zenka
description: missing commands on a host [ lvm2, xxd .. ] are installed through the debian zenka, not plain apt-get over ssh
metadata:
  type: feedback
---

install a needed package on a protocol-7 host through the debian zenka, not with a direct
`apt-get install` over ssh.

**Why:** owner 2026-11-22, after I installed lvm2 on azurum with plain apt to read the old W520 disk.
the zenka keeps installs tracked and consistent with the profile system [ see [[sweep-src-with-remote-perl]] for host differences ].
**How to apply:** check the debian zenka's commands [ `p7c debian.commands` on the host ] and install
through it ; only fall back to apt with the owner's ok.

#,,,.,,,.,,,,,,.,,,..,...,.,,,...,.,.,,..,.,,,..,,...,..,,.,,,,.,,,.,,...,,..,
#ISBVFJTHUID4X2I3C7ZFZ7E6ARS5YWTY67U5SBVQ6EDUAS33Z54VISXWVVXDVWJPOYGA3DMRXHPAG
#\\\|VVD2ZY2GAW5XSDX4D46ZGPZYAE6G5T4AH2DC3CDYXNMJDSXFRL4 \ / AMOS7 \ YOURUM ::
#\[7]5VBKCSPGK3NX2TC6SVE6DKNTYGWLJ2JZH3FN3BRZSATE3Q4GYOCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
