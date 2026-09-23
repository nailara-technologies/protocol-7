---
name: project-coding-async-backend-acquire-reentrancy-race
description: REVERTED 2026-09-24 -- the 2026-09-23 fix (d3c07acee) broke EVERY normal multi-round coding task, not just the race it targeted. Root race still open and unfixed; see the correction at the top of this file before touching backend_acquire again
metadata:
  type: project
---

**ORIGINAL INCIDENT LOCATED 2026-09-24 -- there was NO duplicate-dispatch
race in it**: task-5JXMWYY, Sep 23 03:48:12 resumed by task-append [ round
63 ], 03:48:27 aborted by `degenerate repetition [âââ]` -- a FALSE POSITIVE
[ per the user : the model was legitimately demonstrating something with
drawn lines, which showed as mojibake while the utf8 bugs were still in
place ; coding.detect_stream_repetition only exempted SINGLE-char units, so
a multi-char structural unit was killed after ~45 chars ]. Every round in
the window dispatched exactly once. The "confirmed live duplicate
enqueue_round" root cause below was never real; the misdiagnosis session
[ task-PYYJCJY, 04:08-05:07 ] followed. Detector widened same day : units
with no letters/digits or <= 3 distinct chars count as structural and get
the long [ 200 char ] threshold [ also covers the 68 blank-line-run aborts
in the log ]. The seq fix [ e8bb6b5b7 ] stands on its own -- real
stale-callback holes, just not this incident.

**UPDATE 2026-09-24 [ later same day ]**: re-analysis found the
"live socket" signal suggested below would ALSO fail -- coding.async.request
deliberately leaves the previous connection streaming while the next round
is sent. The log had no clean repro of the original race [ every duplicate
send_request found was a legit timeout/no-data retry ]. The real gap found:
`request_seq` stale-filtering covered on_chunk/on_complete/on_abort but NOT
`on_error` [ incl. http_complete's no-data forward ] or
`coding.handler.http_timeout` -- an old connection's error/timeout could retry
a round already in flight, free a newer request's lock [ backend_release
only compared task_id ], or fail the task mid-flight [ making the next
task-append take the resume branch ]. Also: http_complete's trailing release
after a state_machine-driven reentrant continuation freed the NEW round's
lock, letting a queued task run concurrently on single-llm. Fixed by
threading req_seq into http_error/http_timeout [ stale -> ignore ] and an
optional seq guard in backend_release [ `lock_seq`, stamped by
async.request ; callers without a seq release unconditionally ].
backend_acquire deliberately untouched. Verified live: multi-round task
[ 3 rounds ] + follow-up task both clean. Still unverified: that this was
the ORIGINAL incident's mechanism.

**CORRECTION 2026-09-24**: the fix described below
(checking `not exists <coding.async.task_state>->{$task_id}` before
allowing reentrant reacquisition) was REVERTED the next day. It conflated
two different things: `task_state` exists for a task's ENTIRE lifecycle
(every round, not just while a request is actively in flight), so the
check refused the reentrancy shortcut for the completely normal,
expected, single-task round-to-round continuation — `coding.async.
state_machine`/`coding.async.chunk_handler` never call `backend_release`
between a task's own rounds, by design, relying entirely on that
shortcut. Confirmed live: every multi-round coding task got stuck queued
behind its own lock at round 2, the very first internal transition after
a tool call, for an entire session until traced back to this fix.

`coding.async.backend_acquire` is now back to the plain, pre-session
check: `if (defined $bs->{lock} and $bs->{lock} eq $task_id) { return
acquired => TRUE }`, no task_state involved. This is deliberately the
ORIGINAL, previously-stable behavior — do not re-add a task_state-existence
check as the distinguishing signal; it does not distinguish "this task's
own synchronous continuation" from "a second, independent, concurrent
caller" (task_state looks identical in both cases). The narrower original
race described below is REOPENED and genuinely unfixed as of 2026-09-24.
Two real, harmless side effects of chasing this down remain, not worth
reverting on their own: `coding.callback.http_complete` now explicitly
calls `backend_release` before its two `enqueue_round` calls (a
correctness improvement even under the plain check — was previously
relying entirely on the reentrancy shortcut with no explicit release at
all, matching state_machine's own pattern), and `coding.cmd.abort-inference`
was found to be able to leak a backend lock permanently when combined
with a stale self-queued entry — not yet root-caused, a lock could
still get stuck if a task is aborted while queued behind its own lock;
watch for `coding.state.backend.<name>.lock` pointing at an already-
`failed`/`completed` task_id as the symptom, `p7c v7-zenki.restart coding`
is the safe recovery until this is understood properly.

If this race needs fixing again: the actual distinguishing signal has to
be "is a request genuinely, actively in flight over the wire right now"
(e.g. a live io_watcher/socket reference), not merely "does some
bookkeeping entry exist" — task_state's existence spans a task's whole
life and can't tell the two cases apart.

---

**Symptom, as originally reported**: `write_new_file`/`write_append` double-
encoding em-dashes, duplicate content in a written file (garbled prefix +
correct text), and — per the user's own repro hint — triggerable by sending
a follow-up message to the coding zenka while a previous response was still
streaming. A prior session (using the local Qwen3.8 model, not this one)
misdiagnosed this as a UTF-8 encoding bug and "fixed" it by flipping
`base.file.slurp`'s and `base.file.zenka_dir.write`'s DEFAULT encoding from
raw bytes to `:encoding(UTF-8)` — a 190+ and 90+ call-site blast-radius
change that would have silently corrupted `cred-mesh.store.local`'s
encrypted credential blobs (write default relied on for that call, read
side stays explicit `:raw`) the next time anything wrote one. Confirmed no
actual corruption occurred (no cred-mesh write since 2026-07-19) before
reverting all of it — see [[feedback-verify-symptom-shape-before-hypothesis]]
for the general principle this violates.

**Actual root cause**: `src/coding.async.backend_acquire`'s "already holds
the lock" reentrancy branch returned `acquired => TRUE` for ANY caller
whose task_id matched the current lock holder, with no check for whether a
round was genuinely still in flight. `coding.cmd.task-append`'s resume
branch and `coding.async.complete`'s own injected-messages recovery are two
independent code paths that can both legitimately try to (re-)enqueue a
round for the same task_id in quick succession; the second one to fire hit
this reentrancy shortcut instead of queueing behind the first, producing
two concurrent `send_request` calls for one task. Confirmed live via the
merged stdout log (`/dev/shm/.7/STDOUT/<id>`, plain-text alternative:
`/var/log/protocol-7/<hostname>.coding.zenka.log`): duplicate
`enqueue_round: task-X round=N [backend single-llm: acquired]` lines for
the identical round number, immediately following a burst of `task-append :
resumed task-X from completed with N messages` lines, with only one
`send_request` line following (the second's round content diverging in
message count from the first) — this is what produced duplicated tokens,
duplicate tool-call messages in the model's own context, and genuine
duplicate writes, all without any encoding layer involved at all.

**Fix**: the reentrancy shortcut now also checks
`not exists <coding.async.task_state>->{$task_id}` — a task_state entry
exists exactly while a round is genuinely in flight (deleted by
`coding.async.state_machine`/`state_manager` on completion/error). If one
exists, a second acquire attempt for the same task_id queues normally
instead of barging in.

**Related, NOT the same bug**:
[[bug-coding-async-send-request-enqueue-round-timer-mismatch]] (fixed
2026-08-19) is a different defect in the same subsystem — a mis-wired timer
handler silently dropping a queued retry, not a reentrancy race. Two
separate coding.async bugs in the same area; don't conflate them if a
future "task got dropped/duplicated" report shows up here again.

**A second, independently confirmed effect of the SAME race**:
`coding.cmd.subscribe-session` also pushed a new viewer listener
unconditionally with no dedup, so the same race (task-append's resume
re-subscribing while the state machine's own STATE_COMPLETE cleanup hadn't
run yet) doubled every subsequent stream chunk delivered to nshell. Fixed
in the same commit by closing+replacing any existing listener for the same
session id — deliberately NOT a skip-if-exists check, since escape/ctrl-c
never clear that array on their own and a skip would have reintroduced a
2026-09-14 "resubscribe permanently blocked" regression.

**How to apply**: if a future "duplicate output" or "double-write" report
in the coding zenka surfaces again, check `coding.async.backend_acquire`
and `coding.session.listeners` dedup FIRST, before assuming an encoding
problem — this exact symptom shape (duplication, not corruption-in-place)
already fooled one full session into the wrong subsystem once.

#,,,.,,.,,,,,,,,.,.,,,,,,,,.,,.,,,.,.,...,,.,,.,.,...,...,..,,...,,,.,..,,...,
#VYLNMRRVX345DOPCXQRY6AW5XY3BYJTDMMYI6YBVXUPNJVCOK2V7QEQN5B7QLAFB2KDSU6JTPZCFQ
#\\\|HKMU2XMMNQUCFDVLUO3VP47TOKFB3GE6CJ4XNVYKBTU35EGEYTF \ / AMOS7 \ YOURUM ::
#\[7]Y6LORP4XXFYIAY6IL4ELPWLTCPNIRQEA2HEY7O3DOOHEWV7JVYAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
