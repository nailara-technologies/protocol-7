## [:< ##

# name  = task: fix kimi.cmd.task-file — dispatch not triggered when status already ready
# descr = when kimi.task-file enqueues a task via ask-reply and kimi.ws.status is
#         already 'ready', the watcher never fires (no status change) and the task
#         sits in the queue indefinitely. fix: call dispatch_next_task explicitly
#         after enqueuing when status is already ready.

## bug description

kimi.task-file calls kimi.cmd.ask-reply which enqueues the task into kimi.task.pending.
the dispatch mechanism relies on kimi.watcher.ws_status firing when status changes to
'ready'. but if kimi is already in 'ready' state when the task is enqueued, no status
change occurs, the watcher never fires, and the task is never dispatched.

confirmed: kimi.dump shows task in queue with full prompt, kimi.ws.status = ready,
kimi.wire.pending = {} — task just sits there.

## fix location

file: src/kimi.cmd.ask-reply

the relevant code path is the "ready — submit directly" block near the end of the
module (after the 'if busy, defer' block). this block already handles the case where
status is ready and submits directly via kimi.wire.prompt. but when called from
task-file, the task is being enqueued via kimi.intake.process and then... the code
falls through to kimi.wire.prompt correctly.

## read first

- src/kimi.cmd.ask-reply  — full module, understand the flow
- src/kimi.cmd.task-file  — how it calls ask-reply
- src/kimi.handler.dispatch_next_task  — what dispatches queued tasks

## actual root cause investigation

read kimi.cmd.ask-reply carefully. the bug may be:
1. task-file passes { args => $content } but ask-reply's ready path calls
   kimi.wire.prompt directly — check if reply_id is missing/wrong causing
   wire.prompt to fail silently
2. or kimi.wire.prompt returns undef causing rollback
3. or the 'if busy' check fires incorrectly

check kimi logs for '[ask-reply] submitted' vs silent failure.

## fix

once root cause is identified, implement the minimal fix. likely options:
- if wire.prompt fails: log the error clearly so it's visible
- if reply_id is wrong: ensure task-file passes reply_id correctly through fwd_call
- if dispatch isn't triggered: after enqueuing, call
  <[kimi.handler.dispatch_next_task]> explicitly when <kimi.ws.status> eq 'ready'
  and kimi.wire.pending is empty

## notes on signatures

- modifying existing files: the signing system will re-sign on commit
- no new files needed unless the fix requires a new helper module

## style
- $ARG not $_ in loops
- <[base.logs]>->( N, fmt, args ) for logging
- lowercase comments, [ word ] bracket annotations
- no use statements or pragmas

#,,,,,..,,,..,,.,,,..,..,,,.,,.,,,.,,,.,.,...,..,,...,...,,,.,,,.,,..,..,,,.,,
#6ZB3GFT54RB4XNZV2SU4Y4WWN7NLG3YOLNSYC4STJYOY5NJ2AJDUIRT7R4ZM6AOTLQ7AUGCTSOWPM
#\\\|3U6XT5KILLOUCDNEID7BOXSACPHGHINJDZ2YCDEA6A7FPD2C4R2 \ / AMOS7 \ YOURUM ::
#\[7]AAX774XT3HW6LOLZV6TARZGLTIGTYZRAQZHFVVK7LOW35TDBFEDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
