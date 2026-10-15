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

**open** : cube route leak [ 7N3, also hit atom after 2.5 days ] -- routes
of a dead zenka are never released ; v7-zenki has no backoff for a zenka
that dies right after every restart [ a loop runs silently for days ].
see [[project-2026-10-11-servers-dns01-host-config]].

#,,.,,,,.,.,,,..,,.,.,,.,,...,,.,,.,,,,,.,,,.,..,,...,...,,..,.,,,,..,,.,,,.,,
#7P3MZP7W75VOJME4DC3UPEUJBTOA6Z6LVHTDL2IAJRRBKF7X7Z6ZNM4AZL65NNR3CE2GTQ2LCDIES
#\\\|QZ2L6BDTLY6VU2TCVUGKWDVG32NXOYGCYA3GY4TRSMUAGPMFWC2 \ / AMOS7 \ YOURUM ::
#\[7]SCAHDPRXXSHQA6GDZA6AF3A42SAT56MHRW3B5Y23FVNQM5WMWWAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
