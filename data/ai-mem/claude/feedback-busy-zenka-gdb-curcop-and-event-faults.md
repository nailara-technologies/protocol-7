---
name: busy-zenka-gdb-curcop-and-event-faults
description: a spinning \ silent busy zenka : sample PL_curcop with gdb [ root script ] ; Event watchers on SEGV looped for ever [ fixed fbd58a42de ] ; reply handlers that re-ask on UNKNOWN loop silently [ f89cde7816 ]
metadata:
  type: feedback
---

2026-11-26 : two incidents, one technique.

- **where is a busy perl zenka** : zenki run as protocol-7, no ptrace for me.
  a root script attaches gdb and prints
  `((PerlInterpreter*)PL_curinterp)->Icurcop->cop_file` + `cop_line`, ~15
  samples per pid -- cop_file is the p7 module name. found a loop that wrote
  no log line in one run. `strings core | grep "^Can't"` found the croak in a
  gcore dump.
- **SEGV loop** : every signal got an Event watcher ; Event's handler returns,
  the fault repeats for ever [ v7-zenki 9 h at full cpu, children zombies ].
  now base.sig_fault [ plain %SIG, default dispositions first, base.sig_term
  with exit 2 ].
- **Event fact, tested on 1.28** : cancelling the RUNNING watcher in its own
  callback and then touching `$event->w` again corrupts memory ; a plain
  `$e->w->cancel ; return` is safe ; a fired one-shot reports is_active 0 in
  its own callback.
- **silent re-ask loop** : a reply handler re-ran a check that asked again on
  UNKNOWN [ models.task.pin-accepted with a fresh status ] -- models, coding
  and cube at full cpu, no log. load looked like memory pressure because it
  only happened while an invoke render held the gpu.

**Why:** busy-but-silent zenki were blamed on memory pressure ; the real
causes were loops no log showed.

**How to apply:** a zenka busy with quiet logs : sample cop_file first, do
not guess from logs. a reply handler that re-sends its request needs an
`asked` marker or a base.interval.next delay. claim handling rework still
open [ owner 2026-11-26 : "needs refinement anyway" ].

#,,,.,.,,,,,.,..,,,.,,,..,,..,...,,.,,..,,,,.,..,,...,...,,,,,,.,,,..,,,.,.,,,
#7C4UXH47FPDNKRACCBJBUEXWXNPYYA7WMPNV2EV5FWPQER3UL5ZMIOFOLURFWVMQ3I357YK4I5R6Q
#\\\|CLVJTAVKYFXTK3J6IP33OSF7U4RY7WOR2VJWSWW4OU4HOX2W7HE \ / AMOS7 \ YOURUM ::
#\[7]JI7G3FGXK4DBKX6B5G2GFAQLBGZQP65QZIL7MKJPWKBPGCA73UDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
