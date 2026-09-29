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
