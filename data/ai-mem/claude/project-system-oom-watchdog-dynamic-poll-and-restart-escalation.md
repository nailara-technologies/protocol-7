---
name: project-system-oom-watchdog-dynamic-poll-and-restart-escalation
description: task file scoped to add a dynamic/accelerating poll interval and a restart-then-terminate escalation guard to the system zenka's OOM watchdog, motivated by the 2026-09-17 coding-zenka OOM incident
metadata:
  type: project
---

Task file: `data/tasks/completed/system-oom-watchdog-dynamic-poll-and-restart-escalation.md`
-- DONE, live-verified, committed `f138268e4` (2026-09-17, same session).

**Why:** motivated directly by [[bug-coding-cpu-context-oom-forced-wsl-reboot-2026-09-17]]
-- a coding-zenka `llama-server-cpu` child spiked from a few hundred MB
to >12GB RSS in under a minute, well within the watchdog's flat 7s poll
window. User proposed accelerating the poll rate as memory pressure
rises (catches a spike a poll or two earlier, doesn't claim to catch an
instantaneous one) plus remembering a restart so a genuinely
crash-looping child gets terminated instead of restarted forever.

**Important finding while scoping**: the third piece of the user's
original ask -- look the pid up against v7-zenki's managed-process
registry and restart instead of blind-killing -- turned out to **already
be fully built and live** (`system.process.autokill` ->
`v7-zenki.zenka.cmd.pid-instance` -> `system.process.handler.pid-instance_response`,
confirmed by reading all three files). Only the poll-rate and
restart-escalation-memory pieces are real gaps; the task file is scoped
to just those two.

## related

[[bug-coding-cpu-context-oom-forced-wsl-reboot-2026-09-17]]

#,,.,,..,,.,.,...,,,.,.,,,.,,,.,.,,.,,,..,,,.,.,.,...,..,,.,,,..,,,.,,.,,,,.,,
#O4SPJEPV3B5NQJHCGGXSXCA7W7FB6FNVXFZXRGMDRIQNCUHGCZUOTPIOQ3JFTL3RYQXD5YGEQOFPE
#\\\|7JBRZZLL3WTBCTSQBNSMRWUPER3MA5MIZY5A5N7BEN5LJ7QKWFI \ / AMOS7 \ YOURUM ::
#\[7]U26J6TJLOI2XMPZJVJ7PBEZU2GY2GM4DFV2SBPXORLQFLH3ZOKCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
