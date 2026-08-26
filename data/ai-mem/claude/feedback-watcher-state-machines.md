---
name: watcher-based state machines are the preferred pattern
description: IO::Async variable watchers proven more reliable than polling timers; apply everywhere
type: feedback
originSessionId: 327ba945-ac12-456a-985f-690320d1550f
---
use `<[event.add_var]>` (Event.pm variable watchers) for all state machines, not polling timers or sleep loops.

**Why:** arbitrary polling (sleep loops, timer-based checks) has proven fragile in P7 —
timers fire at wrong times, overlap, or fail to re-arm after state transitions.
variable watchers fire exactly when state changes, have no polling overhead, and compose
cleanly with the event loop. the coding zenka moved from timer-based backend polling
to watcher-based locks and became significantly more reliable. the kimi zenka's
reconnect hang is a direct consequence of not using watchers.

**How to apply:** when designing any new state machine in P7:
- use `<[event.add_var]>` — Event.pm variable watcher, not IO::Async
- use `repeat => 1` and watch mode `'w'` — watcher is persistent, fires on every write, no re-arming needed
- state lives under a named namespace e.g. `<zenka.state.thing.status>`
- watcher fires on every state variable update → drives next state transition
- reconnect bugs are usually the state variable not being updated, not a lost watcher
- timers are acceptable only for: inference timeout, stale cleanup, buffer save/drop
- never use a sleep loop or repeated timer to poll a condition that could be watched
- reference implementation: coding zenka backend lock (`coding.state.backend.gpu.lock`)
- task file for kimi upgrade: `data/yaml/coding-tasks/kimi-state-machine-upgrade.yaml`

#,,,.,,..,..,,,,,,,,.,,.,,.,.,,,.,.,.,..,,,.,,..,,...,...,...,,.,,,,.,.,,,.,,,
#HCRD5VHBTD27H5IKQBZFMT3L4FJ32L4XBF34EJ2XDKHVUECUBXPHUWYKWUSOB23VAC5QB4DY7HMTO
#\\\|24Z652KA6XIE5FYXVRBYXORBIAWA4UTSMW6TE4QPNOXPK7HD6ZM \ / AMOS7 \ YOURUM ::
#\[7]PPBRXCTHVOZAYXMOB6CCV73OJTAFCTPPYPU56BVPQJWNUGC2YKBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
