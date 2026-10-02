---
name: feedback-check-filesystem-before-large-files-on-windows-drives
description: before putting a large or growing file [ swap vhdx, model, image ] on a Windows drive, check its file system AND whether the drive is itself a virtual disk -- a WSL swap on D: [ FAT32 inside a vhdx on C: ] crashed the zenki twice on 2026-10-02
metadata:
  type: feedback
---

I suggested `swapFile=D:\\wsl\\swap.vhdx` in .wslconfig because D: looked
empty and unused. I never checked the drive : D: was `C:\DISKS\projects.vhdx`
[ a 7 GB virtual disk on C: ] formatted FAT32. the swap image grew past
FAT32's 4 GiB file limit, the host refused the writes [ hv_storvsc
0xc0000001 ], Linux offlined the swap device and every process with
swapped-out pages died -- WSL \ all zenki down twice [ 06:40, 08:26 ].
it also gave no benefit : the space was C: space anyway, under two layers
of virtualization.

**Why:** a drive letter says nothing about the storage behind it. FAT32
limits, a vhdx-in-vhdx, a USB disk mounted by hand [ the ext xfs disk needs
a manual `wsl --mount` ] all break a large growing file late and badly --
not at setup, but hours later under load.

**How to apply:** before placing such a file on a Windows drive, run
`Get-Volume -DriveLetter X` [ FileSystemType ] and `Get-Disk` [ BusType
'File Backed Virtual', Location ] and say what they show. a swap or VM disk
belongs on a real NTFS volume that exists at WSL start ; the default WSL
location is fine. an offlined swap device cannot be swapoff'd [ it must
read the pages back ] -- a higher priority swap file in front of it
[ `swapon -p 10` ] covers until `wsl --shutdown`.

#,,..,,,,,..,,,..,,.,,,..,..,,,..,,..,,.,,.,,,..,,...,...,,..,...,.,,,,,,,,,.,
#S77PR3WKW4AYBDI5RXG6F6PPOCUDYGKWDMZPOJRFHN7O3HTXFEIUXGPOETL7ED4SPZUSGW2ADT3CS
#\\\|U3HD4ZTP6CHG6YXJMZMZ3PTFAY522IF3WFIN6AM7UYW5L6XRLTH \ / AMOS7 \ YOURUM ::
#\[7]5N6GUYGVN77BIMPJ75DMKZVGCWQMJU4AU4MYZTN4XKJAZ36JOSBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
