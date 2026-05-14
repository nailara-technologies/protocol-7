---
name: kimi zenka state machine upgrade
description: kimi zenka has same overlapping-reconnect hang as coding zenka had before watcher upgrade
type: project
originSessionId: 327ba945-ac12-456a-985f-690320d1550f
---
kimi zenka suffers from approval timeout + overlapping reconnect state bug — same class
of issue that was fixed in the coding zenka by replacing polling timers with a
variable-watcher based state machine.

**Why:** when approval request times out and kimi reconnects, the old reconnect state
is not cleaned up. subsequent commands block waiting on a state that never resolves.
symptom: `kimi not ready [ status=busy ]` with no forward progress.

**How to apply:** when scheduling kimi zenka work, plan a state machine upgrade task
modeled on the coding zenka watcher refactor (see topic-coding-state-machine.md).
the fix is to replace timer-based reconnect polling with IO::Async variable watchers
so overlapping reconnects are detected and resolved cleanly.

#,,..,,.,,,..,.,.,.,.,,,.,,,,,,,.,...,,..,...,..,,...,...,.,,,.,.,,..,,.,,,..,
#5JAC7GZO5GQ74LN456ISCAHD5WJIXP6A2BDZWPSIZO5IWAOH5QG35UTF3I4FLNTG5M5BCO7VZUT32
#\\\|NIYQXFPVKQMKVG3AZLTSZFWUCXU3CKI67KZYI2X2O53GWOQP3O3 \ / AMOS7 \ YOURUM ::
#\[7]AEVEHWHACXNNLSYFW3SHLYKCJKJRW4H7ZCHG7VMHKQXWXNXYJIDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
