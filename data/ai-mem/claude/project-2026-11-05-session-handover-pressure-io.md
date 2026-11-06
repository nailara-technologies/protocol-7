---
name: project-2026-11-05-session-handover-pressure-io
description: START HERE 2026-11-05 [ 6dd74e736, live on srv-U F V A + srv-16 ] : io pressure, VWF, nshell EIO fix, route collapse + per-session liveness ; next : shm A [ kimi ]
metadata:
  type: project
---

session 2026-11-05 [ follows [[project-2026-11-05-session-handover-headless-design]] ]. all commits pushed
to `hub` ; srv-U F V A and srv-16 on 6e805b179, v7-zenki `reload all` success everywhere.

**done**
- 5a228d20a powershell `max_concurrency = 1`.
- a396fee51 devmod-ack REMOVED : states are absolute, the handler only sets a flag [ last wins ] -- v7-zenki
  records the state at send time again. see [[feedback-no-ack-for-absolute-state-signals]].
- f78e38386 nodes.orbital.init_code guard `return TRUE` [ reinit reported error on srv-U \ A ].
- 0f67fb7c5 IO::Pty in zenka-common [ srv-16 : apt ] ; test-vault-tty-restore follows the reworked keys bar.
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

**later the same session**
- 66f759706 VWF fixed : signature_valid honours a caller truth map [ truth checks only ; binding checks
  never ] ; non-default map untested until the form footer type uses one.
- c93391a75 nshell.read_from_buffer : exit on any stdin read error but EAGAIN \ EINTR [ a hung-up pty
  answers EIO, not eof ] and on piped eof. pri.nshell had spun 12 h, `::: pri taeki.name` hung on it.
- 1c9c7a379 design data/md/design/ROUTE-COLLAPSE-AND-LIVENESS.md : no default \ global reply timeout ;
  timeouts per hop, opt-in by caller \ target zone \ a per-zenka map [ cubes \ filter zenki may enforce
  one at a network boundary ] ; later : max hops, no longer completable, derived values [ observe \ auto ].
- c68fb26d9 cube liveness probe + cube.cmd.zenka-heartbeat [ v7-zenki only : registers its managed zenki,
  cube never probes them ]. RELAPSE : shipped active with 30 s x 3 -- corrected 0cac3267b, then
  6dd74e736 per-session `declare-liveness <interval> <misses> | off` [ for the caller only ], nshell
  declares only with nshell.cfg.liveness.* set [ none are ]. tested : frozen nshell without declaration
  left alone, with `10 2` closed after 27 s. see [[feedback-no-default-reply-timeouts]].
- heartbeats need a v7-managed instance : a shell-started nshell has none -- cube owns session liveness.
- benchmarks [ seal = vault twofish-gcm in chacha20-poly1305 ] : keys once per segment 5 us \ 64 B, 43 us
  \ 4 KB on desktop + srv-16 ; ed25519 verify 100-220 us. srv-U slow only from llama-server
  7 threads on 8 cores.

**shm plan [ FKS ]**
- derive_pubkey is a placeholder too [ first 32 chars of the private key ] ; protocol-7-menu passes its
  PUBLIC key as the private one. B [ refuse grants ] would break the pointer stream -> do A.
- A [ kimi next ] : real Ed25519 derive + grant signatures over a labelled message bound to the segment
  owner key ; menu passes its private key ; tests for forged \ replayed grants.
- then : seal \ open moved from AMOS7::Vault into AMOS7::Twofish [ vault format byte-identical, vault
  tests prove it ] ; then encrypted shm pages [ per-segment keys, nonce per write, ad = owner key + page
  + write counter ; default only once readers can get the key ].

**lessons**
- a liveness check that closes things IS a timeout : no default activation, no default values.
- new cube code goes in cube.* [ base.* is loaded by every zenka -- the sign plan lists showed it ].
- multi-word `qw| a b |` in a hash = shifted keys [ the probe timer had no handler ].
- routes are stored on BOTH sessions : a caller waiting for a reply must never be probed.

**open, in order**
1. shm A [ FKS ] -- see the shm plan above. command links [ GLOBAL-COMMAND-LINKS.md ] are unblocked by VWF.
2. pri.nshell : check that the fixed nshell runs there [ new sessions get c93391a75 ].
3. todo 5FI : a zenka dying before its log link leaves no reason -- keep early stderr \ start lines.
4. todo QMH : system zenka per-disk stats from /proc/diskstats.
5. login-screen image mode : unlock clears at once ; real-display check open.
- servers : motd \ console plan apply ; watch delta link heartbeat timeouts, srv-A 'subscribe refused'.

#,,..,...,.,.,.,.,..,,..,,...,..,,...,,,,,,,.,..,,...,...,,.,,,,,,,.,,.,,,,..,
#S4G47J27OMFFQ4FNT53GUHECPMYMH23S3SP2Y5HK7F5W6VC4XYYODFGH34H23WCK3QY4ZURFGLRGK
#\\\|F5VBKUONWTMKG7P62QW6MUGUZUJ7DDT3XCJIZGVMBHY5YHDOBZZ \ / AMOS7 \ YOURUM ::
#\[7]6NJBENELSDOMPXHMCSCEDGXPH4Z4SCIABB2AMWVJO3HQXEDJKSCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
