# host build : from an empty disk to a bootable debian with protocol-7 -- repeatable, in style

status : brief [ 2026-11-22, owner agreed on the idea ] ; open decisions at the end.

first users : the W520 base system on the old intel ssd [ now ], the X220T data disk with a
second boot system [ when the PM871 arrives, 2026-11-25 ], later the recovery partition and
the usb stick of data/tasks/recovery-partition.md [ same layout files ].

## what exists

bin/p7-install covers everything AFTER the os : base packages, checkout, p7-deps profile,
hardware, service unit, boot start. it looks first and acts only on what is missing, has
-dry-run, never restarts the service. the missing part is BEFORE it : disk layout, file
systems, a debian base system and a bootloader.

## shape : bin/p7-host-build

- one layout file per host, p7 config style [ `=` and `:` equal, never json ]. a template in
  the repo [ cfg/host-build/layout.template ] ; real files with disk serials and host names
  outside the tracked tree [ cfg-dir of the zenka data, or ~/.n/host-build/<host>.layout ].

      host.name        = <name>
      disk.serial      = <serial>
      part.efi         = 512M vfat /boot/efi
      part.boot        = 1G ext4 /boot
      part.main        = rest lvm main-vg
      lv.root          = 40G ext4 /
      lv.rescue        = 8G ext4 [ second boot system ]
      lv.data          = rest xfs /data
      system.suite     = trixie
      system.profile   = minimal

- steps, each looks first and acts only on what is missing [ a second run changes nothing ] :
  1. disk : identify by serial, show model \ serial \ size \ current table
  2. partitions [ sgdisk ]
  3. encryption [ luks, if the layout asks for it ]
  4. lvm : pv, vg, lvs
  5. file systems
  6. debian base [ debootstrap the suite into the mounted tree ]
  7. fstab \ crypttab by uuid, hostname, locale, a first user [ no secrets on argv ]
  8. bootloader [ grub-efi unless the layout says otherwise ]
  9. bin/p7-install inside the new system [ chroot ], with the layout's profile
  10. unmount cleanly ; a report of what was done

- safety [ fail closed -- this is protocol verification territory, not a user choice ] :
  - nothing destructive without `-wipe <serial>` matching the disk AND the layout
  - refuse a mounted disk, a disk in use by lvm \ md \ swap, a disk set read-only
    [ blockdev --setro ], or a serial mismatch -- say exactly why
  - -dry-run reads only and prints the full plan
  - every destructive step listed before it runs ; one confirmation for the whole plan

- tests : the whole chain on loop devices and a test root [ like P7_INSTALL_ROOT ], no real
  disk, including the refusals [ wrong serial, mounted, read-only ] and the second run doing
  nothing.

## style [ owner : better than p7-install ; bin/format-code and bin/amos-chksum are the models ]

- the frame output of format-code : `:` margin lines, `::[ text ]::` status lines, the
  shared progress bar [ AMOS7::Console::Progress ] for long steps [ debootstrap, mkfs ]
- colours through AMOS7 %C, -nc \ NO_COLOR \ no terminal removes every escape
- one aligned status row per step [ looked \ done \ skipped \ refused ], lowercase text,
  annotations in [ ]
- prompts through AMOS7::TERM [ the passphrase prompt for luks included ]
- code : lowercase comments with [ ], `qw| |` keys, CORE:: for list-form builtins, perl 5.32
  floor, bin/format-code -c clean ; packages installed through the debian zenka where a
  zenka is running, plain apt only inside the new chroot
- internal checksums BMW \ AMOS, never sha ; no json

## decisions [ owner 2026-11-22 ]

1. encryption : luks is an OPTION of the tool [ layout `crypt.<name> = luks` ], off by default.
   the actual installs stay unencrypted and bootable without a passphrase ; the data itself is
   protected [ n7fs seals, keys in the vault ]
2. suite per system from the layout : trixie for main systems, unstable allowed [ experiment
   slot ]
3. bootloader : grub-efi [ /boot may sit on lvm, legacy fallback, one menu for main \ rescue \
   experiment systems ] ; systemd-boot not needed

## implementation notes [ 2026-11-22, first build -- not signed, not committed ]

files : bin/p7-host-build, cfg/host-build/layout.template, bin/test-scripts/test-p7-host-build.pl

- two passes : pass 1 looks at everything and builds the plan [ refusals happen here, with
  the reason ] ; pass 2 runs the steps, each looks again and acts only on what is missing.
  -dry-run stops after pass 1 and runs read commands only [ lsblk, blockdev --getro,
  sgdisk -p, blkid, pvs \ lvs, findmnt, cryptsetup isLuks \ status ]
- -wipe <serial> is needed for ANY disk write [ an empty disk too : partitioning, luksFormat,
  pv \ vg \ lv, mkfs ]. a run whose plan has no destructive action needs no -wipe and asks
  nothing [ the second run ]. -yes answers the one confirmation, -wipe stays the gate
- a second gate at the moment of writing : a destructive need found only after the plan
  [ behind a closed luks, an inactive vg -- planned as 'look' ] was not confirmed and is
  refused ; the next run shows it planned
- refusals : serial not found, serial on two disks, -wipe \ layout mismatch, read-only [ lsblk
  RO or blockdev --getro ], mounted outside the target, swap, md, an active vg that is not the
  layout's, a dm-crypt mapping that is not ours, the layout's vg on another disk, a half-done
  debootstrap tree. mounts under the target and the layout's own vg \ mapping are accepted
  [ an interrupted run ]
- a test root [ P7_HOST_BUILD_ROOT ] accepts loop devices only. loop devices have no serial :
  with P7_HOST_BUILD_TEST_SERIALS=1 a loop backed by <serial>.img INSIDE the test root takes
  that serial [ decided differently from 'env names the serial' : the file name ties the
  serial to one backing file, an env value could have named any loop ]
- debootstrap is stubbed through PATH [ a fake binary first in PATH ], not a special switch in
  the tool. the stub test puts ONLY the fake directory in PATH, so no real disk tool can run
- grub-efi installs with --removable --no-nvram : the building machine's nvram is never
  touched, the disk boots wherever it is put. legacy fallback when the layout has a bios_grub
  partition [ grub-pc-bin, grub-install --target=i386-pc ]. NOT done yet : the one menu for
  main \ rescue \ experiment systems [ the rescue lv gets a file system, no system in it ]
- missing host tools are refused with their package list ; -install-tools installs them
  through the debian zenka [ p7c debian.install-packages ], never plain apt on the host.
  plain apt runs only inside the chroot [ kernel, grub, lvm2 \ xfsprogs \ cryptsetup-initramfs
  as the layout needs ]
- secrets : the luks passphrase goes to cryptsetup --key-file=- on stdin, the user password to
  chpasswd on stdin, both through AMOS7::TERM prompts. without a terminal [ and always in a
  test root ] the user is created locked. AMOS7::TERM is loaded only for a prompt [ it needs
  Event, not core perl ] ; P7_HOST_BUILD_TEST_PASSPHRASE works in a test root only
- layout keys beyond the brief : part.<n> = 1M bios_grub, system.arch \ mirror \ locale
  [ defaults amd64, deb.debian.org, C.UTF-8 ], system.bootloader = grub-efi | none,
  system.service = enable | no [ p7-install -enable, default no ], user.name. unknown keys
  are refused
- an lv whose size differs from the layout is reported [ 'differs' ] and left as it is, never
  resized
- probes fail closed : blockdev --getro [ must say 0 or 1 ], lsblk of the disk, sgdisk -p,
  pvs and findmnt without an answer refuse before anything is written. a table to be
  replaced while our own vg \ mapping \ mount under the target is active is refused
  [ 'unmount \ deactivate first' ] ; after the reread every partition node's size is held
  against the new table before wipefs \ mkfs. an existing non-empty -target that is not a
  mount is refused. a child killed by a signal counts as failed [ 128 + n ]
- p7-install runs in the chroot with -no-hw [ the chroot sees the building machine's
  hardware and host name ] ; the 'perl' package is installed first when the tree has only
  perl-base [ FindBin, Getopt::Long live in perl-modules ]
- open : later grub upgrades inside the new system do not refresh EFI/BOOT/BOOTX64.EFI by
  themselves -- a debconf preseed for the removable path [ key name to verify ] would fix it
- prompts need AMOS7::TERM, which needs Event [ libevent-perl ] on the build host ; without
  it the confirmation asks for -yes and the luks passphrase cannot be read
- not done : network configuration, timezone, os-prober \ multi-system menu
- tests : the stub-world checks pass as a normal user [ parser, template, every refusal with
  'nothing written', dry run, whole chain, second run unchanged, -nc \ NO_COLOR, table
  replace, luks chain, each probe without an answer, busy table, live target ] ; read_table
  and the partition math are checked against the real sgdisk on an image file [ no root ].
  the embedded fake keeps bareword hash keys [ test fixture code, not tool code ].
  the root loop-device part [ real sgdisk \ lvm \ mkfs \ mount,
  read-only and mounted refusals ] is written but NOT run yet [ needs root ] ; a real
  debootstrap behind P7_HOST_BUILD_SLOW_TEST=1. untested so far : kernel rereads, real lsblk \
  pvs \ lvs \ blkid \ findmnt output against the parsers, a real chroot

## implementation notes [ 2026-11-23, several systems per disk -- not signed, not committed ]

- layout : `system.<name>.lv | suite | profile | hostname` declares a further system ; the
  single-system keys are unchanged and mean the main system [ `system.main.suite \ .profile`
  are the same keys, both forms together are 'key twice' ]. the lv must exist, be ext4 \ xfs,
  have no mount point, hold one system only ; suite \ profile default to the main system's,
  hostname to <host>-<name> [ '_' -> '-' ]. further systems need system.bootloader = grub-efi
- each further system gets its own tree beside the main one [ <target>.<name> ], held to the
  same 'empty or a mount' rule ; under_target covers every tree [ busy checks, unmount ].
  steps 6 7 9 run again in it with a layout view [ its lv is '/', fstab lists only that ;
  luks parts kept for crypttab, mapping names stay the main host's ] ; step 8 there is the
  kernel only [ no grub-install of its own ]. the first user is the same user.name
- step 'boot menu' after the systems : the main tree gets /etc/grub.d/41_p7-systems [ 0755,
  one explicit menuentry per further system : search by fs uuid, root=UUID=, /vmlinuz \
  /initrd.img symlinks so kernel upgrades in that system need no new menu ] and
  /etc/default/grub.d/p7-host-build.cfg [ GRUB_DISABLE_OS_PROBER=true ] ; written only
  when the content differs, update-grub in the main chroot only then
- open : the /vmlinuz \ /initrd.img symlinks at the system's root are debian's default
  [ kernel-img.conf do_symlinks ] -- verify on the first real build ; grub on a luks vg
  [ cryptodisk ] is listed but untested
- tests : stub world two further systems [ rescue trixie, exp unstable xfs + own hostname \
  profile ] : dry run lists both systems and the menu, writes nothing ; chain : three
  debootstraps, one grub-install, the menu lists both by uuid, os-prober off, own trees \
  host names \ root-only fstab \ kernel ; second run : no write, state and tree unchanged.
  parser refusals for a mounted lv, a missing lv, no .lv, main suite twice. the root loop
  part now runs the two-system layout [ exp on ext4 : mkfs.xfs refuses 32M ] and reads the
  menu \ host names off the real lvs -- not run yet [ needs root ]

#,,.,,...,.,,,,,.,,..,.,.,,..,.,.,,,,,,,,,,,,,..,,...,...,...,,..,.,,,,.,,,..,
#UVKDEV4UN65PUTAQYGESO2XVBA642MGAVW2WWXS3XDH2ONI6UBFTGKQEPZB45YOZ7Q55AV2J3BQJK
#\\\|7PDNLVFAJBXLZTM2SUCUSMFTHQPC3RJUJ7FJVWEM5LE3OW2EYZL \ / AMOS7 \ YOURUM ::
#\[7]MX4CC4K7UTZ5KQN5ZO724DVPUBSJGE64SQH57XBAV2KT7LHGQGDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

## next stages [ owner 2026-11-23 ]

### stage 1b : vault users and remote access [ after the current follow-ups ]

- user passwords from p7-vault by naming convention : one 'login' entry per account,
  title `host-build:<host>:<user>` [ fields user, password ] ; layout `user.password = vault`
  or `vault:<title>`. read through a pipe from `p7-vault get <title> password`, handed to
  chpasswd in the chroot on stdin -- never argv, file or log. a missing entry : say so, offer
  `p7-vault gen` to create it, else the account stays locked. one vault unlock per run
- access set-up, optional [ `access.from = installer` ] :
  1. the installer's public key [ vault file entry `host-build:<host>:<user>:authorized_keys`,
     else the running user's ~/.ssh/*.pub ] into the new user's authorized_keys ;
     openssh-server, keys only
  2. the new ssh host key is generated during the build : its fingerprint goes straight into
     the installer's known_hosts [ no trust on first use ]
  3. optional Host alias with HostKeyAlias in the installer's ~/.ssh/config [ `:::` works ]
  4. the report names what was set up and the first connection command

### stage 2 : protocol-7 integration

- host-root key of the new host created during the build ; pinned on the installer for p-7-r
  [ ~/.n/remote-keys/servers/ ] and for discover [ the protocol-7 user's pin store :
  discover.read_host_root_pins trusts pinned host-roots only, never writes a pin ] ; the
  installer's host-root pinned on the new host the same way
- an access.users entry for the installing user
- discover needs : the multicast group 239.13.5.42 udp 47 on a broadcast interface
  [ discover.mcast.broadcast_interfaces prefixes : enp wlp eth .. ] -- so a working wired
  \ wlan network first [ stage follow-up 2 ], no firewall drop for it
- wake on lan [ power zenka, power.plugin.wol.* ] needs the target's mac : unknown while the
  disk is built in another machine. ways : a layout key `net.mac` when known, else recorded at
  the first boot [ the new host announces itself through discover, the installer stores its
  mac for the power zenka ]. the target side : WakeOnLan=magic in a systemd .link file for the
  wired interface, and wol enabled in the firmware [ the report reminds of it ]

#,,..,.,.,,..,.,.,,,,,.,.,,..,..,,,,.,.,,,..,,..,,...,...,,.,,.,.,..,,.,.,,,.,
#M2NO2D4FKKNQ3NHLOYDN4HJ45PGBF7W2BT7FXRCZ3KT33JRHJKF2W2UDGCWPVASSQUE3E6XQFHOA2
#\\\|P6VE3W5EOEHNPUWVKA4EDYXZW2DAXYST4NSOHRLF5WL4SJOMMJH \ / AMOS7 \ YOURUM ::
#\[7]DF2LI4CR5BON7M4ZUR5XBLKHFAVZS6M5APDWWSKJLSWPWA563KCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
