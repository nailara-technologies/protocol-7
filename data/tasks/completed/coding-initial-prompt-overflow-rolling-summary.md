# task: rolling-window summarization fallback for initial-prompt overflow

## relation

`modules/coding.task.execute` (around line 103-115) currently fails a task
immediately and unconditionally if the *initial* prompt (before any
inference round has happened) already exceeds `n_ctx - 500` tokens:

```perl
if ( $max_tokens_safe <= 0 ) {
    my $overflow = $est_tokens - $n_ctx;
    my $err = sprintf(
        'initial prompt overflow: estimated %d tokens exceeds n_ctx=%d '
            . 'by %d : reduce task description or tool output size',
        $est_tokens, $n_ctx, $overflow > 0 ? $overflow : 0 );
    <[base.logs]>->( 0, "coding.task.execute: %s [%s]", $err, $task_id );
    $task->{'execution'}->{'status'} = 'failed';
    $task->{'execution'}->{'error'}  = $err;
    <[jobqueue.move_job]>->( $job_id, 'error' );
    <[coding.task.fail]>->( $task_id, $err );
    return { success => FALSE, error => $err };
}
```

this is the right guard for genuinely-too-big prompts, but it is the
*only* path for tasks like `coding_summarize` / `session_catchup` whose
job IS to summarize a large blob of text — those tasks should instead be
processed via rolling-window map-reduce summarization, the same way
`modules/coding.async.compact_context` already does for *mid-conversation*
context compaction (it enqueues a no-tools, single-round "compaction"
sub-task and resumes the parent with the summary spliced in — see that
module for the pattern: child task via `<[coding.task.enqueue]>`,
`metadata.is_compaction`, `<coding.task.parent>`, `state => 'subtask'`).

`compact_context` only fires for `$round >= 3 && @messages >= 6` — i.e.
mid-conversation. there is currently NO equivalent for round-0 / initial-
prompt overflow, so any task whose initial prompt alone overflows just
fails with `7001174 initial prompt overflow`. recent example:
`3TJIHG6UAGWNSJA` failed this way during `coding_summarize` /
`session_catchup`.

## scope

add a round-0 rolling-window summarization fallback, triggered ONLY when:
- `$max_tokens_safe <= 0` (the existing overflow condition), AND
- the task is summarization-shaped — check `$task->{'metadata'}->{'is_compaction'}`
  is NOT already set (avoid recursing on compaction sub-tasks themselves),
  and either `$task->{'type'}` or a new `$task->{'metadata'}->{'allow_chunking'}`
  flag marks it eligible. `coding_summarize` / `session_catchup` callers
  (in `bin/mcp-server-p7` or wherever they enqueue tasks — locate via
  `grep -rn coding_summarize modules/ bin/`) should set this flag.

### `coding.task.chunk_and_summarize`

```
# name  = coding.task.chunk_and_summarize
# param = $task_id, $task, $est_tokens, $n_ctx, $job_id
# descr = map-reduce rolling summarization for initial-prompt overflow
```

contract:

- split the raw prompt text (`$task->{'request'}->{'description'}` /
  `$task->{'metadata'}->{'raw_request'}->{'description'}` — whichever
  `coding.prompt.assemble` reads, see lines 10/20) into N sequential
  chunks, each sized to fit comfortably under `n_ctx` (reuse the
  `chars_per_token = 3.2` estimate convention from `compact_context`,
  leave headroom for the running-summary + system prompt + max_tokens
  reply)
- chunk boundaries should prefer paragraph/line breaks near the target
  size — do not split mid-line if avoidable
- process chunks as a fold: `summary[0] = ''`; for each chunk,
  enqueue a no-tools, single-round (`max_rounds => 1`) child task via
  `<[coding.task.enqueue]>` whose prompt is
  `"running summary so far:\n$summary[i]\n\nnew text to fold in:\n$chunk[i]\n\n"
  . "produce an updated running summary that preserves information from "
  . "both, information-dense, no preamble."`
  — same `is_compaction`-style metadata pattern as `compact_context`
  (`metadata.is_chunked_summary`, `parent_task_id`, etc.) so child tasks
  don't re-trigger this same chunking path
- chunks are processed sequentially (each depends on the previous
  summary) — use the same parent/child suspend-and-resume mechanism
  `compact_context` uses (`state => 'subtask'`, `pending_subtask`,
  resume in whatever handler watches `coding.task.parent` /
  `compaction_pending` — find it via
  `grep -rn compaction_pending modules/`)
- when the last chunk's child task completes, the parent task's result
  IS that final running summary — set
  `$task->{'execution'}->{'status'} = 'completed'` and the result field
  the original caller expects (check what `coding_summarize` /
  `session_catchup` read back from a completed task)
- log progress: `<[base.logs]>->( 1, "chunk_and_summarize: chunk %d/%d, "
  . "%d tokens", ... )`

### wiring into `coding.task.execute`

replace the unconditional fail at line ~104-115 with:

```perl
if ( $max_tokens_safe <= 0 ) {
    if ( <[coding.task.chunked_summary_eligible]>->($task) ) {
        return <[coding.task.chunk_and_summarize]>->(
            $task_id, $task, $est_tokens, $n_ctx, $job_id );
    }
    ## ... existing fail path, unchanged, as the non-eligible fallback ##
}
```

`coding.task.chunked_summary_eligible` is a tiny helper — keep the
eligibility logic in one place so it's easy to extend later.

## acceptance

- a `coding_summarize` / `session_catchup` task whose input text alone
  exceeds `n_ctx - 500` tokens no longer fails with
  `initial prompt overflow`; instead it completes with a single
  information-dense summary covering the whole input
- a normal task (non-summarization, `is_compaction` unset, not flagged
  `allow_chunking`) that overflows still fails exactly as before —
  identical error message and `task.fail` behavior — NO behavioral
  change to the existing guard for that case
- chunk children never themselves trigger chunking (verify the
  `is_chunked_summary` / `is_compaction`-equivalent guard prevents
  infinite recursion even if a single chunk is still too big — in that
  edge case, fall back to hard-truncating that chunk with a logged
  warning rather than recursing)
- test with a synthetic oversized `description` (e.g. repeat a paragraph
  enough times to exceed a small test `n_ctx`) and confirm: multiple
  child tasks are enqueued in sequence, each completes, and the parent
  task ends up `completed` with a non-empty summary result

## non-goals

- no change to `compact_context` (mid-conversation compaction) — this is
  a separate, round-0-only path
- no change to chunk-size tuning beyond the `chars_per_token = 3.2`
  convention already used elsewhere
- do not touch `bin/mcp-server-p7` summarization prompt construction
  itself beyond adding the `allow_chunking` / equivalent flag to the
  task metadata it enqueues with

## signatures note

no `#,,..` stubs. do NOT run update-signatures. do NOT modify
subroutine whitelists. lowercase comments, `[ word ]` annotations,
`$ARG` not `$_`. add any new modules to
`configuration/zenki/coding/subroutine.white-list` if the existing
deferred-compile mechanism requires it (check how `compact_context`
itself is whitelisted and follow the same pattern).

## harmony checks

```
harmony coding.task.chunk_and_summarize
harmony coding.task.chunked_summary_eligible
harmony coding.task.execute
```

#,,.,,,,,,,.,,,..,,..,,.,,,.,,,..,,..,...,..,,..,,...,...,..,,,.,,.,.,.,,,,.,,
#5L64JIIXNMHAYTKMGC2FLL6B2K3BT3ID677ZSIXM5A55SUZBQPOLXIUU7JSWF4K7W7J2RMQJSI42E
#\\\|ZY62F4BUK3Q5GPAWA3LUD77UCRN3POELLJ4DCRVADB6GOW2VC6S \ / AMOS7 \ YOURUM ::
#\[7]3ONR6LP2IXDT4X2RCF6LGNYVIPKI7XT3Q444RG3YOXUKRCTF3YDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
