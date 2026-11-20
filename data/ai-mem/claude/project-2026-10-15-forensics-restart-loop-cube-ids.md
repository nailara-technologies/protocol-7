---
name: project-2026-10-15-forensics-restart-loop-cube-ids
description: srv-U 2026-10-11..15 : forensics' boot sweep blocked past the heartbeat -> killed + restarted ~7300x [ 1 core busy, unnoticed 5 days ] -> leaked routes exhausted cube ids [ base.gen_id -1, '(-1)cmd' rejected, routed p7c commands hang ]. sweep fixed e5870a61a ; cube route leak 7N3 still open
metadata:
  type: project
---

**found 2026-10-15 on srv-U** [ while rolling out AMOS7-v6.30.7 ] :

- forensics.init_code arms the nightly sweep 7 s after boot. the sweep read
  every *.zenka.log from the START and decoded each line's ntime until the
  24 h window -- srv-U has 351 MB of logs -> blocked > the ~26 s heartbeat ->
  v7-zenki `response timeout` -> signal 9 -> restart -> sweep again. first
  start = the events 04:07 slot on 2026-10-11 ; 7319 restarts in 5 days.
  srv-V \ srv-A [ ~4 MB logs ] unaffected ; srv-F [ 582 MB ] has no forensics.
- every killed instance left cube routes behind [ notify_online,
  verification ] -> `cube : element count exceeded max_ids [base.gen_id:74]`
  -> ids -1 -> `command id syntax not valid ['-1'] line=['(-1)...']` ->
  any routed command [ `p7c v7-zenki.start pull-git` ] waits forever.
  recovery : `systemctl restart Protocol-7` [ empties cube's table ].
- I first blamed the user's `::  ` [ two spaces ] -- wrong, p7c strips them.
  the journal line right above had the real cause : read the log context
  before naming one.

**fixed** `e5870a61a` : forensics.sweep.window_offset [ binary search, ~11
decodes per file ] + forensics.sweep.step [ ~0.2 s slices per loop turn ] ;
sweep-run replies deferred. local 454 MB : 8.95 s -> 0.11 s.

**verified live on srv-U 2026-10-15 20:20** : events.trigger_event forensics ->
online, sweep record after 7 s [ 11 files, < 1 s ], still online 61 s later.

**v7-zenki** `c62cc8d3c` : start-up heartbeat probe before 'online' [ no
reply \ FALSE = start-up error ] + restart delay resets only after
restart.stable_after [ 77 s, was 4.2 s ] -- a zenka that keeps failing now
reaches max_delay 300 s [ the user's intended interval ]. NO give-up was
added : the user declined changing overall restart behaviour.

**7N3 status** : with current code, restarts [ system x5, forensics x5,
local cube + devmod dump ] leave no routes. srv-U's cube most likely ran
pre-ca304a02f code [ started 2026-10-12 ~09:05, fix pulled later, never
restarted ]. latent defect CONFIRMED offline : base.route.add keys the
source side by cmd_id, id-less commands [ 0 ] overwrite each other ->
on source close only the last route is cancelled [ scenario 11 in
test-cube-route-stream-cleanup.pl, 2 FAILs, kept out of commits until
fixed ]. leaks only if the target never answers an id-less command.
see [[project-2026-10-11-servers-dns01-host-config]].

#,,,,,,,.,,.,,,.,,.,,,...,..,,.,,,,,.,,..,...,..,,...,...,.,,,..,,,,.,.,,,.,.,
#KZDLFAMF45WR5ESGVJI4B3LHU2SGXQW7WGKB3UEFFABGZTDCMXW7DBR7KJPV4Y3ESIHHH3UAURHZG
#\\\|PY2M3MKX6ZY2YO7C7CIN2JIT4EY2KCGME2YKQ4EMWCGUHN2BSUX \ / AMOS7 \ YOURUM ::
#\[7]TK26RU7CTSO753AFH2RAXJALNFXLNHGNWCAOPQSUBSYV4PINFKCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
