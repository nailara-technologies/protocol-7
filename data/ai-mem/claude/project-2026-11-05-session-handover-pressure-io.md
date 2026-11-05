---
name: project-2026-11-05-session-handover-pressure-io
description: START HERE 2026-11-05 [ 6e805b179, live on srv-U F V A + azurum ] : devmod-ack removed, editor \ locale \ font fixes, start timeout + io pressure ; next : VWF, then FKS
metadata:
  type: project
---

session 2026-11-05 [ follows [[project-2026-11-05-session-handover-headless-design]] ]. all commits pushed
to `hub` ; srv-U F V A and azurum on 6e805b179, v7-zenki `reload all` success everywhere.

**done**
- 5a228d20a powershell `max_concurrency = 1`.
- a396fee51 devmod-ack REMOVED : states are absolute, the handler only sets a flag [ last wins ] -- v7-zenki
  records the state at send time again. see [[feedback-no-ack-for-absolute-state-signals]].
- f78e38386 nodes.orbital.init_code guard `return TRUE` [ reinit reported error on srv-U \ A ].
- 0f67fb7c5 IO::Pty in zenka-common [ azurum : apt ] ; test-vault-tty-restore follows the reworked keys bar.
- bc14eaab5 Editor.pm : the ' ·' end mark after the last keys-bar cell was outside the fit check -- at
  124 \ 125 cols the row wrapped, frame one line too high [ ned, p7-vault ]. login-screen-session reads
  /etc/default/locale : xterm ran in the C locale [ utf-8 bytes = cells, todo rows too wide ].
- aa0756f19 bin/terminal faceSize1..6 around the face size : shift + keypad plus \ minus [ never ctrl ].
- 3d9eb2a33 design data/md/design/GLOBAL-COMMAND-LINKS.md : `# launch = user|root` header, signed file +
  no PATH shadowing + root-owned target \ dirs \ link dir, never replace foreign entries. waits on VWF.
- 469913425 start timeout waits again under pressure [ heartbeat_ext.* limits ].
- 6e805b179 [ kimi K3.1 low, reviewed ] v7-zenki.pressure.update_io_level : io level from io_full_avg10 \
  avg60 ; heartbeat + start timeout use the more severe of memory and io ; start gate stays memory-only.
- powershell exit 0110 [ 11-04 23:29 .. 00:11 ] : NOT display, NOT overlap -- 0fd160c6a non-blocking cube
  socket broke its blocking whoami read, 70a02805e fixed it. resolve log stamps with `:: localtime <stamp>`.

**lessons**
- sub lists [ base.list.subroutines, subroutines.load-early ] are generated : p7_sign with plan=true, never
  hand-edit [ kimi did ].
- a filtered `git commit | grep error` hid a hook refusal [ descr > 55 chars ] -- check the new hash before
  deploying.
- copy the p7_sign job id, never retype it [ twice waited on a wrong id ].

**open, in order**
1. VWF [ signature_valid truth map ] -- unblocks the command links.
2. FKS [ shm permission forgeable, high ].
3. todo 5FI : a zenka dying before its log link leaves no reason -- keep early stderr \ start lines.
4. todo QMH : system zenka per-disk stats from /proc/diskstats.
5. login-screen image mode : unlock clears at once ; real-display check open.
- servers : motd \ console plan apply ; watch delta link heartbeat timeouts, srv-A 'subscribe refused'.

#,,..,,.,,,,.,.,.,,..,.,,,.,.,..,,.,.,,,,,,,,,..,,...,..,,,,,,..,,.,.,.,,,.,.,
#FX54KTW45VBQCLUOL6TTFO57ERJ2T7CU4VHAO6DJD36TU6WR4KGQHXLK26RKMU47VEJN7TYGPXDTA
#\\\|6NGVPA3JGQHSYDGMQPAW6GEZ6ALVSRHOMS4H2Y4W2VF2SNKYYC2 \ / AMOS7 \ YOURUM ::
#\[7]T2MVKM3S2OHYUGSYLU5HAIO235KL7RT7ZNIC7P6Q4VNYAM2ZDKBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
