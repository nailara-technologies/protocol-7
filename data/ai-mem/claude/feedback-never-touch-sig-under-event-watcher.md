---
name: never-touch-sig-under-event-watcher
description: assigning or restoring $SIG{X} in a zenka resets the kernel disposition under an Event.pm watcher ; with a second watcher on the same number [ alias CLD\IOT\POLL ] add_signal can't repair it -- 2026-10-07 v7-zenki lost SIGCHLD
metadata:
  type: feedback
---

never write `$SIG{SIGNAL}` [ set, `local`, or save\restore ] in code that runs inside a zenka with an Event signal watcher. under Event, `$SIG{CHLD}` reads undef, so `$SIG{CHLD} = $orig` installs SIG_DFL beneath the watcher. Event only calls sigaction when its per-signal count goes 0 -> 1, so while a second watcher on the same number exists, `event.add_signal` cannot repair it.

2026-10-07 : `v7-zenki.compile_bin_p7c\_p7r` [ IGNORE during gcc, then restore ] + `base.init_zenka.install_signal_handlers` also registering the `CLD` alias from `keys %SIG` => v7-zenki never saw SIGCHLD again after any compile [ at start or on reload ]. symptom : `<KILL>ed children` on every idle stop [ a zombie, so kill 9 "succeeds" ] then `liveness : ... gone without a processed SIGCHLD`. fixed `07e19f5a2` : gcc pid -> `<v7-zenki.sig_chld.ignore_child_pid>`, one watcher per signal number.

**Why:** the loss is silent. stops still completed through the cube shutdown status, so it only surfaced once the liveness sweep logged at level 0.

**How to apply:** to skip one child's SIGCHLD in v7-zenki, register it in `ignore_child_pid`. quick live check : `/proc/<pid>/status` SigCgt, bit 16 [ signal 17 ] must be 1. related : [[never-feed-command-substitution-into-destructive-cmds]] [ its "dead pids listed online" hypotheses -- this was likely one ]

#,,,.,,..,.,.,,,,,...,..,,...,,,.,..,,.,.,,,,,..,,...,...,.,,,..,,,.,,.,.,,,.,
#5YIEOOLT54DGHV2CI6EVRIPSSNBY77F6QVGKW7QB5HXVBQTJTJJ6RCDOLKFMV5FW7TEEWW7ZZ7NOM
#\\\|A5HU3FD64C25VW5JBKDIA775US7G4QJQLE3XMNIH2SB4PGRY5SE \ / AMOS7 \ YOURUM ::
#\[7]6FEBJIMEW4TT7KVQ3KMBHWBJ42YSJO4PLIADFFDTYPWMYWVJGKCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
