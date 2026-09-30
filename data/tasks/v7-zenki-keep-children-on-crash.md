# v7-zenki : keep and reattach child processes when a zenka crashes

brief [ 2026-09-29 ]. not built. read `CLAUDE.md` first, then
`data/ai-mem/claude/reference-invoke-web-run-user-and-invokeai-facts.md`
[ "never block invoke-web's event loop" ].

## why

invoke-web crashed [ v7 response timeouts -> `error` -> signal 9 ] and took
invoke.ai with it, mid-render : invoke.ai is a registered child, and v7
kills children when it ends an instance. that protection is right for a
clean terminate \ restart [ no orphaned 9 GB process holding the GPU ] --
but a CRASH restart should be able to keep an expensive child and let the
new instance reattach it. generic : any zenka with a long-running,
expensive child [ inference servers, renderers, downloads ] benefits.

## the hook

a crash goes `online -> error -> starting` [ v7 log : `online --> error`,
`preparing instance .. :: restart ::` ]. only that path keeps children ; a
clean `terminate` \ `restart` \ idle-term kills them as today.

## design

1. opt-in per zenka [ zenka.v7 ] : e.g. `restart.keep_children = yes`.
   without it nothing changes
2. `base.zenki.report_child_pid <pid> [ <name> ]` : optional name \ role
   [ e.g. `invokeai` ] -> `register_child` stores, per child :
   - name \ role -- which child it is, for the new instance to claim
   - process name \ cmdline pattern -- plausibility : still the same
     program [ /proc/<pid>/cmdline ]
   - START TIME [ /proc/<pid>/stat field 22 ] -- the only reliable guard
     against pid reuse ; register_child's own `todo` already asks for it
3. on `error` with keep_children : v7 does NOT kill the registered children
   of that instance, and skips them in `terminate_process`'s process-tree
   sweep [ `v7-zenki.sub-process.get_children` -- invoke.ai is a direct
   child in the tree too, both paths must honour the mark ]. they move into
   a `kept children` table : instance id, name, pid, start time, cmdline,
   kept since
4. the new instance claims them : e.g. `v7-zenki.claim-children` [ or a
   push with the start-up init-code ] -> list of { name, pid } for its zenka
   name ; it adopts by name [ invoke-web : the existing orphan adoption in
   init_code, fed from here instead of its pid file ] and re-registers
5. protection stays : an unclaimed kept child is terminated by v7 after a
   grace period [ e.g. 120s, configurable ], and before ANY kill or claim
   v7 re-checks pid + start time + cmdline -- a mismatch means the pid was
   reused : forget the entry, never signal that process

## correlation [ user question : name parameter or process name match ? ]

both, plus the start time -- each covers something the others do not :
- name \ role : the ASSIGNMENT [ which kept child is this instance's
  invoke.ai ]
- process name \ cmdline : PLAUSIBILITY [ still the same program ]
- start time : IDENTITY [ pid reuse gives a new process, possibly with the
  same name, but never the same start time ]

## invoke-web as the first user

- report `invokeai` as the child name ; keep_children = yes
- the drain \ memory guard \ status logic already handles an adopted
  running invoke.ai [ adoption path in init_code, `invoke-web.is_alive` ]
- the output pipes die with the old instance : an adopted invoke.ai keeps
  running but its stdout \ stderr go nowhere [ SIGPIPE risk on write ! ] --
  must be solved first : e.g. spawn invoke.ai with its output going to a
  fifo \ file the new instance can reopen, or ignore SIGPIPE in the child.
  without that a kept invoke.ai may die at its next log line anyway

## X-11 as the second main user [ user, 2026-09-29 ]

- the same need : an X-11 crash must not terminate the user's desktop
  session [ the X server + everything running on that display ]
- X-11 already has the REATTACH half : `X-11.reconnect` [ display reconnect
  with exponential backoff after a protocol error ] and
  `X-11.reconnect.replay_registrations` [ re-issue the per-connection X11
  registrations ]. missing is only v7 NOT killing the X server \ session on
  a crash, and the new instance claiming the display by name [ e.g.
  `xvfb-0000` ] before reconnecting
- same output question as invoke.ai : what the X server's stdout \ stderr
  are connected to [ SIGPIPE on a dead pipe ]
- history : `data/ai-mem/claude/project-x11-xvfb-crash-loop-and-cleanup-
  2026-09-06.md` [ crash loop + cleanup, orphaned process handling ]

## further candidate users

- coding : the inference servers [ large models in VRAM, minutes to reload ]
- mpv : playback continues instead of breaking off
- fetch-files : long model downloads continue
- povray : long renders
- general rule : worth it where a child is expensive to recreate and holds
  no state that only lived in the crashed zenka

## open

- the SIGPIPE \ output problem above -- decides whether keeping works at
  all for output-heavy children
- grace period default, and what the log \ notification says on expiry
- claim via command or via the start-up init-code push

#,,,,,...,,.,,,,,,,..,...,,..,,.,,...,,..,...,..,,...,...,...,...,.,,,,,,,..,,
#S7LGCGMXY6CZD6RUAB5N37PRF52EO364AFU44M2VTILTHEKBLIEL37OY3GHOMHUWEYMGVW6LJSNIO
#\\\|EYWV43DXXVLY75B2KZ3YOU22BRRLB6FHH62R36R3V5465XU5MPK \ / AMOS7 \ YOURUM ::
#\[7]55YVNYWD7343W3LOWCIHW2BEV4MLQ5RFZH6UC7DCX2VNVTYEVUDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

## state 2026-09-30 [ stage 1 done, code locations for stage 2 ]

- stage 1 DONE [ cf4864498 ] : invoke.ai's stdout \ stderr go to
  /var/run/.7/invoke-web/invokeai.out [ O_APPEND, PYTHONUNBUFFERED ], read by
  inotify from a saved offset [ invoke-web.output.* ] -- no pipe, no SIGPIPE ;
  a new instance reads on [ invoke-web.handler.output_adopt ]
- the pid file stays on an error restart [ v7-zenki report-pid-file, only
  removed on teardown \ manual terminate \ restart ] ; invoke-web's
  init_code already adopts a running invoke.ai from it [ process alive +
  'invokeai-web' in /proc/<pid>/cmdline ]
- where v7-zenki ends children : `v7-zenki.handler.zenka_status` [ ~l.137 :
  any status except starting \ online \ extbin -- error included ] calls
  `v7-zenki.terminate_process` for [ a ] the zenka pid, [ b ]
  `v7-zenki.instance_child_pids`, [ c ] `v7-zenki.sub-process.orphan_pids`.
  `terminate_process` itself sweeps the /proc tree of each pid
  [ `v7-zenki.sub-process.get_children` ] -> SIGTERM, later SIGKILL via
  `v7-zenki.handler.process_kill_list`. also called from
  process_zenka_end, zenka.instance.restart, handler.drain_timeout
- registration : `v7-zenki.zenka.cmd.register_child` [ from
  base.zenki.report_child_pid ]

## stage 2 scope

1. `base.zenki.report_child_pid <pid> [ <name> ]` + register_child : name,
   start time [ /proc/<pid>/stat field 22 ], cmdline pattern, per child
2. zenka.v7 opt-in `restart.keep_children = yes` [ invoke-web first ]
3. on status `error` only : kept children excluded at all three places
   [ a : the tree sweep of the zenka pid, b : instance_child_pids, c :
   orphan_pids ] -- every other status and every other caller unchanged
4. kept children table + grace timer [ default 120s, config ] ; before ANY
   signal or claim : pid + start time + cmdline re-checked, a mismatch =
   pid reused -> forget, never signal
5. claim : the new instance [ same zenka name ] claims by name -> v7 moves
   the entry back to the instance's children, cancels the grace timer.
   invoke-web : adoption in init_code [ existing ] + start time check
   against the value recorded in its pid file + claim call
6. an unclaimed kept child after the grace period : terminated as today


## state 2026-09-30 [ stage 2 implemented, unsigned ]

- opt-in : `restart.keep_children = yes` + `restart.keep_children_grace`
  [ default 120 ] in `cfg/zenki/invoke-web/start.cfg` -> lands in
  `<v7-zenki.start_setup.zenki.config>` like `restart.disabled`
- registration : `base.zenki.report_child_pid <pid> [ <name> ]` ->
  `v7-zenki.zenka.cmd.register_child` stores `child_name` +
  `proc_start_time` + `proc_cmdline` in `<v7-zenki.child>->{pid}`
  [ identity : `v7-zenki.sub-process.proc_identity`, /proc stat field 22 ]
- error path : `v7-zenki.handler.zenka_status` status `error` only [ guarded
  against `zenka.instance.shutdown` \ `stopping` ] calls
  `v7-zenki.keep_children_on_error` BEFORE the terminate map : kept children
  are removed from `<v7-zenki.child>` + the instance child registry [ that
  excludes them from the terminate_process tree sweep = a, and from
  instance_child_pids = b ] and `v7-zenki.sub-process.orphan_pids` skips
  kept pids explicitly [ c ]. children already signalled [ drain \
  force-kill : `<v7-zenki.terminating.pid>` ] are NOT kept
- kept table : `<v7-zenki.kept_children>->{zenka_name}->{pid}` +
  one-shot grace timer per child [ `v7-zenki.handler.kept_child_grace` ] ;
  identity re-checked before ANY signal \ claim [
  `v7-zenki.sub-process.identity_match` ] : mismatch = pid reuse -> forget,
  never signal
- planned end : `v7-zenki.kept_children_reabsorb` moves kept children back
  before the usual sweep -- called from zenka_status on `shutdown` \ manual
  `restart` [ same condition as the pid-file clean-up ] and from
  `v7-zenki.teardown` [ all ] : terminate \ restart \ idle-term \ drain \
  teardown end children exactly as before
- claim : `v7-zenki.zenka.cmd.claim-children <child-name>` [ cube injects
  zenka name + sid, `source_zenka_sid` alias ] -> identity re-check, move
  back to the claiming instance, cancel grace timer, reply with the pid.
  access : `access.cmd.usr.invoke-web` in cfg/zenki/cube/access.zenki
- invoke-web : `cmd.start` records the /proc start time as 3rd pid-file
  line + reports the child as `invokeai` ; `init_code` adoption re-checks
  the start time [ `invoke-web.proc_start_time`, /proc only -- still root ]
  and arms a post-drop timer [ `invoke-web.handler.claim_child` + reply
  handler ] for the claim
- known limit : a zenka process dying by itself [ sig_chld ->
  process_zenka_end ] terminates children BEFORE any error status -- that
  path is unchanged by design [ only the status 'error' path keeps ]

#,,,.,..,,.,,,.,,,,,.,,,,,...,..,,,.,,,..,...,..,,...,...,,.,,..,,..,,.,.,,..,
#PNR3CS5VA6BLUBRMC4NNDD4I57JDSHQLFBB3ECKDBXF32FSZ46KPKS66T36BC7MI7V5TXFDCXXG3W
#\\\|G7PIOFHYVBVMIZKFNNBLEWS6EWXUYLARFVICAZTUV5HPFNQXCQG \ / AMOS7 \ YOURUM ::
#\[7]JCFJ6HKNTQYTPNK5WAYPGJWKFBHFSL2TMLLK376QNALIY3R4GOCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
