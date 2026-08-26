## [:< ##

# name  = task: coding.cmd.task-append backend-lock-leak fix
# descr = task-append resumes with the wrong backend key, so
#         backend_release never matches and the lock leaks forever

## background

Diagnosed live 2026-07-21 (see `data/ai-mem/claude/
project-coding-zenka-resilience-and-model-switch-2026-07-21.md`,
"coding.ask-reply pipeline bugs" section) but never code-fixed. Confirmed
live: a task sat queued 66 minutes behind a backend lock held by a task
that had long since completed. Unstuck by hand that session
(`coding.eval-code` calling `backend_release` directly) — the underlying
bug is still in the code.

## root cause, confirmed 2026-07-31 by reading the actual code

`src/coding.cmd.task-append`, line 82:

```perl
my $prev_backend = $task->{'execution'}->{'backend'} // 'gpu';
```

This reads the **hardware key** (`gpu`/`cpu`, set by `coding.task.execute`
line 111 from `$backend_info->{'backend'}`) — the wrong field. Every other
caller in the codebase that needs "which backend lock does this task's
requests use" reads `$task->{'analysis'}->{'routed_to'}` instead — the
**routing key** (e.g. `single-llm`, a named service, not a hardware
descriptor). Confirmed by grep: `coding.async.request:22`,
`coding.task.enqueue:61`, `coding.task.chunk_and_summarize:75`,
`coding.task.execute:118`, `coding.tools.handler.subtask_spawn:62` all use
`$task->{'analysis'}->{'routed_to'} // 'gpu'` — the same pattern,
consistently, everywhere except this one file.

Confirmed the lock namespace itself is keyed on this routing value:
`coding.async.request` line 22 derives `$backend` from `routed_to`, then
passes it straight into `coding.async.backend_acquire`/`backend_release`
(lines 62, 142) — those key `<coding.state.backend>` by whatever string
they're given. So when `task-append` resumes a task and later that
resumed round completes, the code that eventually calls
`backend_release($task_id, $backend)` derives `$backend` correctly (from
`routed_to`, unaffected by this bug) — but `task-append` itself stored
the WRONG value into `<coding.async.task_state>->{$task_id}->{'backend'}`
at line 98, and whatever downstream code path re-derives the release
backend from that stored task_state (rather than freshly reading
`analysis.routed_to` again) will call `backend_release` with a
hardware-key string like `gpu` when the lock was actually acquired under
a routing-key string like `single-llm` — `backend_release`'s guard at
line 13 (`if (($bs->{'lock'} // '') ne $task_id)` — actually keyed by
which `$backend` bucket you look up, i.e. `<coding.state.backend>->
{$backend}`) then looks in the WRONG bucket, finds no lock held by
`$task_id` there, and silently no-ops — the real lock (under the routing
key) is never released. **Trace exactly which downstream call site reads
the stored `task_state.backend` rather than re-deriving from
`analysis.routed_to` fresh** — that's the actual leak point, and
confirming it precisely is part of this task, not just patching line 82
blind.

## the fix

At minimum, line 82 should read:

```perl
my $prev_backend = $task->{'analysis'}->{'routed_to'} // 'gpu';
```

matching every other caller's pattern exactly. But **before changing it,
trace the actual downstream consumer(s)** of
`<coding.async.task_state>->{$task_id}->{'backend'}` (grep for
`task_state` reads, likely in `coding.async.send_request`/
`coding.async.complete`/wherever the eventual `backend_release` call for
a resumed task happens) to confirm this one-line fix is sufficient and
there isn't a second place that also needs the corrected key. Report what
you find either way — if it's a clean one-line fix, say so and show the
trace; if there's a second site, fix that too and explain why.

## acceptance checks

1. `ptd -c` clean on every touched file.
2. Trace and quote (don't paraphrase) the exact call chain from
   `task-append`'s stored `task_state.backend` through to the
   `backend_release` call that's supposed to free the lock for a resumed
   task — confirm in writing that the fix actually closes the leak, not
   just that the field name now matches other callers.
3. **Live-verify the actual leak is fixed**, not just code-reviewed:
   reproduce the original bug's shape — submit a task routed to a
   non-`gpu` backend (check `coding.routing.decide_service`/existing
   routing config for what routing keys are actually live, e.g.
   `single-llm` or whatever real service name is configured), let it
   complete, use `coding.cmd.task-append` to resume it with a follow-up
   message, let the resumed round complete, then inspect
   `<coding.state.backend>` (via `coding.eval-code` or similar) and
   confirm the lock for that routing key is released (not stuck held by
   a task that's since finished). Quote real command output.
4. Confirm no regression for the common `gpu`-routed case (same live
   test, or a second one, with a `gpu`-routed task).
5. Don't stage/sign/commit — leave for human review.

## notes

- Read `data/ai-mem/kimi/MEMORY.md` and `data/ai-mem/kimi/coding-style.md`
  first per this project's convention.
- Live-verify via real command output per this project's dispatch
  convention — don't trust your own self-summary without it.
- If you need to restart the coding zenka mid-task to get a clean lock
  state for testing, that's fine — it's your own dispatch target, not a
  shared resource other work depends on right now.

#,,,.,,.,,.,.,,,.,...,..,,,,,,.,,,.,,,,..,,,,,.,.,...,.,.,...,,,,,.,.,..,,.,.,
#3WFMPLM554ERLDFJNICLXWXZPAGUWEENUFNC5Z2O3N2N5BXKF2SMD7KW47IHOXYSVQWKQ576K6RTC
#\\\|6IZSXM32X6X7TP2DO42PM465EMPQ7ZIVS6XXXHI5W3CYLYWXAJL \ / AMOS7 \ YOURUM ::
#\[7]6AMI5ORSIPMAMR7Z65OELPWAR3SOVARVKNEXDXP5UEXFUGNPK6AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
