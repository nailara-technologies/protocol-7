# task: wire iteration loop into models.task.execute

## objective
modify `modules/models.task.execute` to check for `iteration: true`
in the task config and route through `iteration.loop` instead of
direct single-shot dispatch.

## read first
- `modules/models.task.execute` — existing dispatch flow
- `modules/iteration.loop` — params: {task_id, result, criteria,
  node_id, max_attempts}; returns {mode=>'retry'|'escalate'|'true'}
- `modules/iteration.score_result` — shows criteria/score structure
- `modules/task.cmd.complete` — how task completion is recorded

## what to change in models.task.execute

1. after task result is received from backend, check:
   `$task->{'iteration'}` — if true, route through iteration loop

2. call iteration.loop with:
   {
     task_id      => $task_id,
     result       => $result,      [ the backend reply string ]
     criteria     => $task->{'acceptance_criteria'} // [],
     node_id      => $task->{'node_id'} // '',
     max_attempts => $task->{'max_attempts'} // 5,
   }

3. handle return:
   mode='true'     → task complete, call task.cmd.complete normally
   mode='retry'    → re-dispatch task to backend with iteration context
                     injected into prompt [ append score.issues as
                     "issues to fix: ..." user message ]
   mode='escalate' → mark task blocked, surface to user

4. non-iteration tasks: existing flow unchanged

## style
- $ARG not $_ in map/grep/foreach
- <[base.logs]>->( N, fmt, args ) for logging
- lowercase comments, [ word ] bracket annotations
- no use statements, no pragmas

## cmd module pattern
cmd modules and handler modules receive context differently —
check how models.task.execute currently receives its task_id and result
before modifying [ read the module first ]

#,,,.,...,,.,,,,.,,,,,.,.,,,,,..,,.,,,,,.,,,,,..,,...,...,...,.,.,,,.,,,,,,,.,
#Q5XG7TAKNVSWJ3OQEW2KCJYXEK3PQA2TSSHHABWIRDZTTAWZCJIBSN7A27JQ4JCXLRLBI5ZWQFEZG
#\\\|ME2TKJWK6INN74CSBIN3A45CGQ3WMPRUJLYBAGOKCKP5CSVXRRK \ / AMOS7 \ YOURUM ::
#\[7]DK7SSRCW3H5YPE5XHSCVVVLBHQO3BKQAQIUOFYG3FVHTDUYEOCBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
