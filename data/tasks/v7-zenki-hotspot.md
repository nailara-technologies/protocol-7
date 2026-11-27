# v7-zenki.hotspot : where is a busy or stuck zenka [ evidence before action ]

status : OPEN 2026-11-27 -- design agreed with the owner, not built. a prototype script exists
[ below ] and found two real causes on 2026-11-26.

## why

a zenka at full cpu with quiet logs gives no clue from outside. twice on 2026-11-26 sampling
the perl interpreter's current position settled it at once :
- models, coding and cube at full cpu : models.handler.task-poll-step re-asking
  coding.inference-status for ever [ fixed f89cde7816 ]
- events busy after a restart : only its slow start, not the suspected waitpid change
the zenki run as protocol-7 : only root can ptrace them. v7-zenki runs as root.
the v7 anchor draft [ data/tasks/v7-zenki-anchor.md ] names 'record evidence before a restart'
as its core job -- this is that evidence.

## the prototype [ what works ]

per sample : `gdb -p <pid> -batch -nx -ex 'printf "%s:%d\n",
((PerlInterpreter*)PL_curinterp)->Icurcop->cop_file,
((PerlInterpreter*)PL_curinterp)->Icurcop->cop_line'` -- cop_file is the p7 module name
[ eg. models.handler.task-poll-step:197 ], perl and xs files keep their path. ~15 samples,
counted and sorted = a histogram. it worked without perl debug symbols on the desktop
[ perl 5.42, threaded build ]. a core : `gcore <path>` in the same gdb session ;
`strings core | grep "^Can't"` found the croak of the SIGSEGV loop.

## the shape

- command `v7-zenki.hotspot <zenka> [ samples ]` -- the pid comes from v7-zenki's own instance
  table, never from the caller [ a caller-given pid could point at any process ]. a zenka name
  with several instances : all of them, or `<zenka>.<subname>`.
- reply : the histogram, one `count module:line` per row, most frequent first, and the zenka's
  cpu share over the sampling time [ /proc/<pid>/stat utime + stime ].
- mode `:core:` : also a gcore plus `bt` of all threads, written below v7-zenki's state dir
  [ owner protocol-7 or root, 0600 -- a core holds keys ]. the reply names the path. the
  anchor will call this before a restart.
- samples spread on a base.interval.next rhythm [ a type like `hotspot-sample` ], never a fixed
  sleep : a periodic loop must not be caught at the same phase each time.
- non-blocking : gdb runs as a child [ open3 \ stream_child ], v7-zenki's loop keeps running,
  the reply goes out from the handler that collects the last sample. one hotspot run per
  zenka at a time.

## principles [ data/tasks/claim-lease-and-quiet-retries.md ]

- a plugin : `plugin.v7-zenki.hotspot` -- not woven into v7-zenki's core. no gdb : the plugin
  does not load and the command answers 'gdb not installed' ; nothing else changes.
- gdb as a p7-deps profile entry [ bin/p7-deps ; check which profile fits ].
- access : owner only [ cfg/zenki/v7-zenki/access.* ] -- an attach stops the target for a few
  ms per sample, `:core:` for longer.

## open points [ owner ]

- servers' perl builds : does PL_curinterp resolve the same way without debug symbols ? test on
  one server first [ ssh as root is allowed ; a non-threaded perl has no PL_curinterp -- the
  expression differs ].
- where cores go and how long they stay [ size : the v7-zenki core was 110 MB ].
- `:core:` on cube or v7-zenki itself : v7-zenki cannot attach to itself -- the anchor's job.

## rules for the implementer

no sha, no json internally ; lowercase comments with [ ] brackets ; perl floor 5.32 ;
bin/format-code -c for every changed src file ; a new command needs its zenka.v7 list,
gen-sub-whitelist and access entries [ verify with `v7-zenki.commands` ] ; no commit, no sign,
no reload ; never touch files you did not change.

#,,,,,,,,,..,,,..,,..,,.,,,..,,.,,.,,,,..,..,,..,,...,...,,.,,,..,,,,,,.,,,.,,
#HIEZD7V5MUV7LUJYGBROWNNLF3ME2TYGMH37NB2NTPYIPUSJNEYMQA7XF3ZT6PLEIYQQZ7EV5CHPM
#\\\|JYOX4DTGGD3NDV4E2GQUIV6IERMCQWIYJRSMJH6FQGOAZFVKO2Z \ / AMOS7 \ YOURUM ::
#\[7]TFRKNUHKJ4RQ3DJYTO7FQVRNTVPZFQFZTW3AYLYZNXTEGQQ6N4AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
