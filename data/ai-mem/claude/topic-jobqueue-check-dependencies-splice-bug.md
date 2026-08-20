---
name: topic-jobqueue-check-dependencies-splice-bug
description: "jobqueue.check_dependencies iterates the same array move_job splices from — resolved jobs randomly stranded in 'depending'; fixed by snapshotting before iterating"
metadata:
  node_type: memory
  type: project
---

## symptom (reported 2026-08-03)

mpv zenka log showed a fast cascade of `moved job 'X' into 'depending' queue`
lines during startup (dozens of buffered `send_command` calls queuing while
`<mpv.socket>` was still undef), described by the user as a race condition —
"adding new job ids to the depending queue, instead of waiting and then
clearing the dependency."

## root cause (confirmed, not the cascade itself)

`src/jobqueue.check_dependencies` iterates the live array reference
`$prio_queue->{$prio}` (the `depending` queue's `by_priority` bucket).
`src/jobqueue.move_job`, called inline for every resolved job, splices
that *exact same array* to relocate the id to `queued`. Perl's `foreach`
holds an internal index into the array being walked — a `splice` mid-loop
shifts every later element down one slot, so the iterator's next fetch skips
the element that just slid into the removed slot.

Verified standalone (not zenka-specific — pure Perl semantics):
```perl
my @arr = (1..10);
foreach my $id (@arr) {
    push @visited, $id;
    splice(@arr, $del_index, 1) if ...;  # same pattern as move_job
}
# visited = 1 3 5 7 9   (2,4,6,8,10 never touched this pass)
```
Repeated passes converge (each pass halves the stragglers) but only if
`check_dependencies` gets re-triggered — which only happens when the
`queued` counter changes again (`jobqueue.handler.queue_counter` calls it
unconditionally at the end of every firing). If no unrelated job touches
`queued` after a resolution burst, the skipped half of `depending` sits
stranded indefinitely — an intermittent race gated entirely on incidental
future traffic, not a deterministic bug. `move_job`'s own count decrement is
NOT desynced from the array (each call removes exactly one matching id), so
the counter itself stays accurate — the count just reflects a queue that
never fully drains on its own.

**This is a bug in the single shared `jobqueue.check_dependencies` module**,
loaded identically by mpv, coding, models, vision-batch, and X-11 — there is
no divergent per-zenka implementation to compare against; all five zenki hit
the identical hazard whenever a dependency resolves with >1 job waiting on
it at the same priority.

## fix (landed)

`src/jobqueue.check_dependencies`: snapshot the priority bucket into a
plain array before the `foreach`, so `move_job`'s splice mutates a
disconnected copy of the `depending` queue, not the array being walked:
```perl
my @pending_ids = @{ $prio_queue->{$prio} };
foreach my $job_id (@pending_ids) { ... }
```

**Why:** minimal, single-file fix in a module loaded by 5 zenki — avoid
restructuring `move_job`/`check_dependencies`'s shared splice-by-value-match
pattern (used correctly elsewhere: `jobqueue.remove_job` isn't called from
inside a foreach over the same array, so it doesn't need the same fix).

**How to apply:** any future loop over a jobqueue queue bucket that also
calls `move_job`/`remove_job` (or anything else that splices that bucket)
mid-loop needs the same snapshot-before-iterate treatment — the bug class is
"iterate live array, mutate live array via shared queue reference," not
specific to `check_dependencies`.

**Live-verified (2026-08-06):** restarted mpv+radio after this fix; the
splice-skip itself is confirmed fixed. But the user's *reported symptom*
("still logs the same issue") turned out to be a **separate, deeper bug**
this fix didn't touch: mpv's own IPC reply routing
(`mpv.handler.pipe_output`) matched command replies to callers by pure
`shift()`-order across `mpv.reply_ids`/`mpv.command.reply`, with no id in
the payload — any dropped/deferred/reordered reply permanently desynced
that FIFO (confirmed live: `mpv.is-idle` hanging, `mpv.get-volume`
returning a boolean value instead of a percentage — a stuck slot from the
pre-fix jobqueue splice bug had likely seeded exactly this kind of
one-off desync). See [[topic-mpv-ipc-reply-request-id-matching]] for the
full fix (request_id tagging, landed same session, commit `ca1370fe9`).

**Lesson:** a correct, verified fix for the *mechanism* a user points at
doesn't guarantee the *symptom* they're describing is explained by it —
the same log noise can have two independent root causes stacked on top of
each other. Live-reproduce the exact reported symptom after a fix lands,
don't just confirm the mechanism you fixed is now correct in isolation.

[[topic-mpv-jobqueue-startup]] [[topic-mpv-ipc-reply-request-id-matching]]
[[topic-jobqueue-queued-drain-starvation]]

#,,..,...,...,...,,.,,.,.,...,,,,,.,.,.,,,...,.,.,...,...,,.,,.,.,.,.,...,.,,,
#G7IAZCNFP72O2LSOXS6F35UVOUQBJYEKN4FQMKZQEOFVCQUA5HAQKMLFQRAHKOFILGTWLN3OGF5QQ
#\\\|VH7HUZN2VBF6G3YDDYXJTY32HYHA66J7IRH25762ON3JKQEY4F4 \ / AMOS7 \ YOURUM ::
#\[7]VK7BEFBL2VC6A3TLRSTEVNCEYY56NEOWBIEK7Z4L36LDYD6JJIBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
