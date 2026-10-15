---
name: project-2026-10-15-forensics-restart-loop-cube-ids
description: pri 2026-10-11..15 : forensics' boot sweep blocked past the heartbeat -> killed + restarted ~7300x [ 1 core busy, unnoticed 5 days ] -> leaked routes exhausted cube ids [ base.gen_id -1, '(-1)cmd' rejected, routed p7c commands hang ]. sweep fixed ab0b5bced ; cube route leak 7N3 still open
metadata:
  type: project
---

**found 2026-10-15 on pri** [ while rolling out AMOS7-v6.30.7 ] :

- forensics.init_code arms the nightly sweep 7 s after boot. the sweep read
  every *.zenka.log from the START and decoded each line's ntime until the
  24 h window -- pri has 351 MB of logs -> blocked > the ~26 s heartbeat ->
  v7-zenki `response timeout` -> signal 9 -> restart -> sweep again. first
  start = the events 04:07 slot on 2026-10-11 ; 7319 restarts in 5 days.
  delta \ yourum [ ~4 MB logs ] unaffected ; atom [ 582 MB ] has no forensics.
- every killed instance left cube routes behind [ notify_online,
  verification ] -> `cube : element count exceeded max_ids [base.gen_id:74]`
  -> ids -1 -> `command id syntax not valid ['-1'] line=['(-1)...']` ->
  any routed command [ `p7c v7-zenki.start pull-git` ] waits forever.
  recovery : `systemctl restart Protocol-7` [ empties cube's table ].
- I first blamed the user's `::  ` [ two spaces ] -- wrong, p7c strips them.
  the journal line right above had the real cause : read the log context
  before naming one.

**fixed** `ab0b5bced` : forensics.sweep.window_offset [ binary search, ~11
decodes per file ] + forensics.sweep.step [ ~0.2 s slices per loop turn ] ;
sweep-run replies deferred. local 454 MB : 8.95 s -> 0.11 s.

**verified live on pri 2026-10-15 20:20** : events.trigger_event forensics ->
online, sweep record after 7 s [ 11 files, < 1 s ], still online 61 s later.

**v7-zenki** `062953657` : start-up heartbeat probe before 'online' [ no
reply \ FALSE = start-up error ] + restart delay resets only after
restart.stable_after [ 77 s, was 4.2 s ] -- a zenka that keeps failing now
reaches max_delay 300 s [ the user's intended interval ]. NO give-up was
added : the user declined changing overall restart behaviour.

**7N3 status** : with current code, restarts [ system x5, forensics x5,
local cube + devmod dump ] leave no routes. pri's cube most likely ran
pre-d592b22fc code [ started 2026-10-12 ~09:05, fix pulled later, never
restarted ]. latent defect CONFIRMED offline : base.route.add keys the
source side by cmd_id, id-less commands [ 0 ] overwrite each other ->
on source close only the last route is cancelled [ scenario 11 in
test-cube-route-stream-cleanup.pl, 2 FAILs, kept out of commits until
fixed ]. leaks only if the target never answers an id-less command.
see [[project-2026-10-11-servers-dns01-host-config]].

#,,,.,,,.,..,,,.,,.,.,.,.,.,,,.,.,,..,,,,,,,.,..,,...,.,.,..,,,..,,..,...,,.,,
#DZHL4NFPIC2FQBY7U2HROOQZUZZC4PE4I2UDPPZ4GIKINWX3ZQYA4TVUP2TIJ6M7QY53UDI2GXLXE
#\\\|B2AKOAVAZYYXZ5SU5PADBKHTKEMRU5VTL36ABII45QR4MUZF32O \ / AMOS7 \ YOURUM ::
#\[7]UOKCWOXZ7BXNP2GGVHGU7WFPPJPTRLWJ7SDMEI5IE6TOSCRVDIDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
