## [:< ##

# name  = task: diagnose http_complete silent death on reasoning-only stream
# descr = a task that streamed 421KB of reasoning with no finish_reason
#         went permanently silent -- find the actual failure point live,
#         don't fix from a guess

## background

Read `data/ai-mem/claude/
project-coding-round-timeout-no-autorestart-observed-2026-07-26.md` in
full first — it documents two rounds of investigation, the second of
which disproved the first. Do not repeat the disproven theory.

**What's confirmed, from the real log** (`/var/log/protocol-7/
DESKTOP-FP4OP26.coding.zenka.log`, task `9340727`, timestamps decoded via
`base.ntime.B32_2_unix` — pass the FULL b32 token from the log line, a
truncated substring fails validation harmlessly and will mislead you):

```
t+0.0s    connecting to local backend
t+68.9s   async.request: inference complete for 9340727 [421559 bytes, 1397 chunks]
t+68.9s   http_complete: 9340727 sm_state=streaming seq=1/1 finish=undef tools=0 bytes=421559 chunks=1397
t+1394.9s async.complete: task 9340727 failed: abort requested   (manual, ~1326s of total silence later)
```

**What's confirmed NOT the explanation**: `coding.callback.http_complete`'s
`sm_state eq 'streaming'` branch has several sub-paths, each with its own
distinct log message (`"clean close after %d bytes processed"`,
`"non-sse response"`, `"connection closed without finish_reason"`,
`"...enqueuing another round..."`). Grepped the *entire* log file for all
of these: **zero hits, ever, for any task** — while a different,
unrelated branch's message (`"connection closed with no data"`) appears
4939 times, proving logging at this verbosity generally works and these
strings would appear if that code ran. So **none of `http_complete`'s
documented sub-branches actually executed** for this task. The log jumps
directly from the `sm_state=streaming` summary log line to the manual
abort with zero lines in between (from any task — the whole log goes
quiet for that window, not just this task).

**Working theory, unconfirmed**: something throws or otherwise dies
inside `coding.callback.http_complete`'s streaming block, after the
summary log statement (~line 57-69) but before reaching any of the
`if (@{$tool_calls}) / elsif (length($content)) / else` sub-branches.
`coding.handler.http_io` (lines 55-56) invokes the `on_complete` callback
(which calls into `http_complete`) with **no `eval` wrapper** — worth
checking what happens to an uncaught exception there: does the base
event loop catch and swallow it silently, log it elsewhere, or something
else? That's exactly the kind of question static reading won't answer
reliably — this task's first pass already produced one plausible-but-
wrong theory from code reading alone, refuted by the log. Don't repeat
that mistake: confirm live.

## what to actually do

1. **Reproduce a reasoning-only, no-finish-reason completion live.**
   Check `coding.inference_servers` for what's currently running and
   whether any configured model is prone to long reasoning traces
   (`reasoning_content` deltas). If reproducing naturally is impractical
   (depends on model behavior you can't force), use `coding.eval-code` to
   construct the state directly: a task with `chunk_context->{reasoning}`
   populated with a large string, `chunk_context->{content}` and
   `chunk_context->{tool_calls}` empty, `finish_reason` never set, then
   invoke the actual `on_complete` path (or `coding.callback.http_complete`
   directly with a realistic `$http_state`) the way the real event loop
   would, not just calling the function bypassing however errors would
   normally propagate.
2. **Find out what actually happens.** Does it throw? Where exactly
   (line number, error message)? Is the exception caught anywhere and
   logged somewhere you haven't checked yet (a different log file,
   verbosity level, or destination)? Or does execution genuinely reach
   one of the sub-branches but its log call itself is what's failing
   (e.g. a `sprintf` format mismatch throwing before the log line
   completes)? Instrument if you need to — temporary `warn`/logging
   additions during investigation are fine, just don't leave debug
   cruft in the final diff.
3. **Only once you know the actual failure point**, decide the fix.
   Likely shape (not prescriptive — confirm this is right before
   committing to it): a reasoning-only completion with no finish_reason
   should not silently orphan the task. Whatever the mechanism, the goal
   is the task either retries/continues (bounded by
   `coding.async.max_rounds`, which already exists) or fails visibly —
   not vanish. If your fix involves promoting `chunk_context->{'reasoning'}`
   into `content` (mirroring `coding.async.chunk_handler`'s own
   finish-time fallback, which does exist for a different trigger
   condition), first confirm whether `$content` in the branch you're
   fixing ever gets pushed into `$state->{'messages'}` as an assistant
   turn, or whether it's only used to decide "retry vs. not" and then
   discarded (this differs by branch — check the specific one you're
   actually fixing, don't assume). Injecting a truncated 421KB thinking
   trace into the next round's prompt as if it were a real assistant
   answer would plausibly be worse than the original hang — verify
   before choosing that shape.

## acceptance checks

1. Report the actual, confirmed failure point (file, line, mechanism) —
   quote real evidence (log output, eval-code output, whatever you used
   to confirm it), not a plausible-sounding guess.
2. `ptd -c` clean on every touched file.
3. Live-verify the fix closes the gap: reproduce the same reasoning-only
   scenario post-fix and confirm the task no longer goes silent — quote
   real command/log output showing it now retries, completes, or fails
   visibly instead of vanishing.
4. Confirm no regression on the normal path: a task with real `content`
   and a proper `finish_reason` behaves identically to before.
5. Don't stage/sign/commit — leave for human review.

## notes

- Read `data/ai-mem/kimi/MEMORY.md` and `data/ai-mem/kimi/coding-style.md`
  first per this project's convention.
- This is explicitly a diagnose-then-fix task, not a fix-and-verify task
  — if you can't pin the exact failure point with confidence, report
  what you found and why it's still unclear, rather than shipping a fix
  for a mechanism you haven't confirmed.
- If you need to restart the coding zenka mid-task for a clean state,
  that's fine.

#,,.,,,.,,,,.,,,.,,,,,,,.,..,,,,.,,,.,,.,,.,.,.,.,...,...,.,,,.,,,,,.,.,,,...,
#6V5L4NBF4MMVS66RZIIZFMEXRTBDFGQTRLRPEHVIWLHZUF66DU4W54I3GHQ42LC2UQKD4N574PMAA
#\\\|WKGABQJ5ADKEEBYEZWFM6KU2PUJV2KJ4OPXHNWX5LHRJHOWQEG5 \ / AMOS7 \ YOURUM ::
#\[7]6MPCGRXCRZIE7OE5E6VNFP5H4BVWK5XRWFJAQUAQXAO6E7PVRQCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
