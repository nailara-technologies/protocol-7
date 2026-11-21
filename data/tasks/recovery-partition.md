# recovery partition : a small rescue os on every machine -- fast, guided, always abortable

status : brief, not dispatched [ owner 2026-11-22 ]. complements the requirement
'every mobile holder is a full recovery point' in data/tasks/n7fs-logical-trees-and-mount.md
[ network \ phone boot, amnesic sessions, the phone as console ] and the disk rescue
experience of 2026-11 [ a disk rejecting flushes and writes, link drops under load ].

## shape

- a small partition [ a few hundred MB ] with a minimal linux, perl and the protocol-7
  tools needed for recovery [ n7fs, the rescue helpers ] ; boots in seconds, read-only
  root, runs from ram
- entered from the boot menu, a key at boot, or automatically when the main os fails
  to come up several times in a row
- a menu in the house style [ console, readable at any dpi, fully keyboard driven ] :
  check disks [ smart, firmware, error counters ], rescue a failing disk, restore from
  n7fs, restore the original configuration, open a shell
- progress bars for every long step [ the shared bar of the n7fs follow-up ] with
  rate and estimated time

## on a usb stick [ owner 2026-11-22 ] -- independent of the main disk

- the whole stick is the recovery medium, so the main disk can be freed, repartitioned
  or worked on without the machine ever becoming unbootable
- two slots [ a \ b ] : the system writes a new version of itself into the other slot
  and keeps the running one as fallback ; a failed update never leaves an unbootable
  stick
- the rest of the stick is cache space [ n7fs chunks, packages, the user's most
  needed trees ] for working offline
- it carries full knowledge of the machines it serves : disk layouts, partition
  tables, the important locations [ which tree restores where ], host configurations
  -- read from n7fs and kept current at each sync
- boots the rescue system by default ; a full desktop [ the amnesic session or the
  user desktop from n7fs ] and a full installer are one menu entry away

## move out, repartition, move back in [ owner 2026-11-22 ]

when the lan has enough space, the rescue system offers a full move to the network :

1. move out : the whole disk content goes into n7fs on lan holders [ the content and
   the host configuration ]
2. the disk is wiped ONLY after every copy is confirmed by receipts [ the same rule as
   for any disk retirement ]
3. repartition : the new layout, on the same disk or a new one
4. move back in : restore everything, check every file against its content address,
   adjust fstab \ uuids \ bootloader to the new layout

until step 2 everything is resumable and abortable without loss ; after it, the
copies on the holders are the safety net. this makes repartitioning a convenience,
not a risk

## forensic reinstall : as it should be, not as it was [ owner 2026-11-22 ]

- the system is rebuilt from known-good sources only : packages from the signed
  distribution repositories, protocol-7 from the signed checkout, the configuration
  from the signed host configuration in n7fs -- no system file comes from the old disk
- the old installation is compared against what it should have been : every system
  file against its package [ dpkg --verify ] or its signature. deviations form a
  report : changed system binaries, unknown setuid files, foreign cron jobs \ systemd
  units, added ssh keys, unexpected kernel modules
- user data comes back checked : documents and media as they are ; executables in the
  home, autostart scripts and browser extensions are flagged and restored only after
  the user confirms each
- the suspicious parts are kept as evidence in an inert, quarantined n7fs tree
  [ never served, never executed -- like the scanner samples of httpd-signed-files.md ]
  with the report, for later analysis
- routine, not an emergency : comfortable and safe enough to run without any
  suspicion -- e.g. after a trip, when a device was out of sight [ border controls,
  hotels ]. one menu entry, it runs unattended, the user's data and desktop are back
  as before, and an empty deviation report is the normal, reassuring result
- the same run imports the trip's data : new files [ photos, documents, downloads,
  notes ] go into the n7fs incoming pool, checked [ the release checks of
  work-and-private-contexts.md ], categorised and placed -- with a report of what came
  in, in one process, no extra work
- with two os partitions [ a \ b ] one is always operational : the reinstall builds
  the clean system into the inactive one while the user keeps working on the other,
  then switches at the next boot ; the old one stays as fallback until the new one is
  confirmed
- the paranoid rebuild trusts nothing on the device : the stick is written on ANOTHER
  trusted host and the device boots only from it. the stick installs one os partition
  [ b, or the least used ] from known-good sources, the device boots into it, runs
  its self-tests [ signatures, package verification, the deviation report against
  the expected state ], and only then the new system installs the other partition
  from itself. no code from the device's old installation runs at any point of the
  chain
- the network can boot it too : a trusted host serves the clean install system over
  bootp \ pxe [ the cable alternative to the stick ]. and the network enforces it :
  after a trip the device is quarantined -- if its OLD os boots [ recognised by its
  keys and its not re-attested state ] it reaches nothing but the rebuild path ; only
  a freshly built system that passed its self-tests is admitted again [ network
  admission by context, work-and-private-contexts.md ]. booting the old system by
  habit then simply leads nowhere

## standard module : firmware check [ owner 2026-11-22 ]

below every os partition lies firmware the rebuild cannot replace ; a standard module
checks it in every run [ routine, after a trip, paranoid ] :

- system firmware : read the bios \ uefi image where the platform allows it [ flashrom,
  fwupd ] and compare it with the vendor's release or the device's recorded baseline ;
  report the versions, the secure boot state and its key databases [ pk, kek, db, dbx ],
  the management engine \ amt state where present
- disk firmware : model, version and serial of every disk [ hdparm -I, nvme id-ctrl ]
  against the recorded baseline -- an unexpected change is a finding [ the 2026-11 disk
  rescue showed how much a disk's firmware decides ]
- other devices with updatable firmware : what fwupd lists, versions against baseline
- the baselines are recorded per device in n7fs [ signed ] at first setup and after each
  intended update ; a deviation joins the deviation report and, in paranoid mode,
  blocks network admission until the owner confirms it
- honest limits : not every firmware can be read back, and a read can be lied to by
  compromised firmware ; the report states what was verifiable and what was not

## always abortable

- every step can be stopped at any moment ; a stopped step leaves the machine in a
  defined state [ no half-written partition table, a resumable copy ]
- one action always available : boot back into the main os [ efibootmgr BootNext
  or kexec of the main kernel ] -- the recovery system never traps the user

## disk power control

- failing disks are power-cycled where the hardware allows : a link reset in software
  [ sysfs delete + host rescan, hdparm -Y ] first ; a real power cut through a
  switchable usb hub port [ uhubctl ] or a relay on the sata power line where present
- the rescue path learned in 2026-11 is built in : write-through instead of flush,
  no unmount that would flush, small partitions read raw [ ddrescue ] and their files
  taken from loop mounts, reads restarted after a drop
- test subject : a known faulty disk [ rejects all writes, drops under load ] kept
  for the automation tests -- labelled, never a holder

## remote

- the phone app [ n7fs brief ] can drive it : the same menu and progress on the
  phone, for headless machines and as the console during disk replacement

## stages

1. the partition and the minimal system ; boot back into the main os
2. menu, disk checks, progress bars
3. the disk rescue path with link reset and power cycle
4. restore from n7fs and the original configuration
5. automatic entry after repeated failed boots ; phone control

## rules

- there is no perfect security, but the best available practice is made convenient
  enough for every day : wherever applicable, the best case in a security context is
  the default case [ owner 2026-11-22 ]
- never writes to a disk the user has not chosen ; read-only by default
- p7 config style, no json ; BMW \ AMOS checksums, no sha ; perl floor 5.32
- no host names or personal data in repo files

#,,..,,,,,,..,.,,,,.,,.,.,.,.,,,.,,..,...,...,..,,...,...,.,,,,..,,,,,,..,,,.,
#PM26HZWYY5SMRNJLGA6XGPIQEYHK5QK7YQNUHEDBAWCGIB44Z7MLYZKF7PIYMCXEYFMZQHTCFDUNI
#\\\|CGYXY22YJLS34GARLRAVXOGFVLTUOWXX5YYGOMQJFEZY3VQMTDQ \ / AMOS7 \ YOURUM ::
#\[7]BK4GEODA2OFXT244QGX6EWXFHC32Q5IUQQ7JPQ5MQMBXWRPXNSAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
