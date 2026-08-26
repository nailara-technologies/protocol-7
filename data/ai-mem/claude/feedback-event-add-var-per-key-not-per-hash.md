---
name: feedback-event-add-var-per-key-not-per-hash
description: base.event.add_var's poll=>'w' fires on reassigning the watched scalar itself, not on mutating a hash key inside what it points to -- need one watcher per key, never one shared watcher over a whole hash
metadata:
  type: feedback
---

`<[event.add_var]>->({ 'var' => \$scalar_ref, 'poll' => 'w', ... })` fires
when the WATCHED SCALAR ITSELF is reassigned. If `\$scalar_ref` points at
a hashref, writing to a KEY inside that hash (`$scalar_ref->{$key} = X`)
does NOT fire the watcher -- only replacing the scalar's own value would
(`$scalar_ref = {...}`).

**Why:** found 2026-08-26 auditing a plan to convert a single global
scalar guard (`<coding.self_test_probe_in_flight>`) into a per-backend
hash for a self-test parallelization task. The naive design kept ONE
watcher on the hash's own top-level scalar slot, expecting it to fire
whenever any backend's key inside it changed. It would never fire again
once the guard became a hash — caught before any code was written, via
first-principles Perl semantics plus comparison against the one CORRECT
precedent already in this codebase: `jobqueue.event.register_job_queues`
registers ONE `event.add_var` watcher PER QUEUE NAME
(`\$counters->{$queue_name}`, a reference into one specific hash VALUE
slot), never one shared watcher over the whole `<jobqueue.joblist.count>`
hash. A reference to one hash value's own scalar slot IS a real scalar
reference — writes through it do fire — but a reference to the
container hash's own scalar slot does not fire on key mutations within
it.

**How to apply:** any time per-key-in-a-hash "wake me when this changes"
behavior is needed via `event.add_var`, register one watcher per key
(`\$data{'ns'}{'thing'}{$key}`), tracked in a per-key registry hash
(mirror `jobqueue.event.register_job_queues`'s `$watchers->{$queue_name}`
+ cancel-if-still-active-before-reregistering guard), never a single
watcher over the parent hash's own scalar slot. See
[[topic-coding-self-test-true-parallelization]] for the specific case
this was caught in.

#,,..,,,.,,.,,,,.,,..,.,,,,,,,,.,,,,,,,,,,..,,..,,...,...,,..,..,,..,,,,.,,,.,
#DUBDDYVWOEUMQ7CETLJBRWDRSVLGTGIF643Z4WQTYN54FT7OFFWJUBQXT2J2VSZANJPHRU6K4JNOI
#\\\|U56S4W2V2YCWHJNY4NVDM2EVSE4CKQFEAXYQ77NGVJG7WOKU5GF \ / AMOS7 \ YOURUM ::
#\[7]2MV7MGKWXSBOSY47Q5SRIL7QOIJMJU4WDXX4QFMDIUDYSKRUCICQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
