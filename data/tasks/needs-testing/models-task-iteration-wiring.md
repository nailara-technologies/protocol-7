# task: wire iteration loop into models.task.execute

## objective
modify `src/models.task.execute` to check for `iteration: true`
in the task config and route through `iteration.loop` instead of
direct single-shot dispatch.

## read first
- `src/models.task.execute` — existing dispatch flow
- `src/iteration.loop` — params: {task_id, result, criteria,
  node_id, max_attempts}; returns {mode=>'retry'|'escalate'|'true'}
- `src/iteration.score_result` — shows criteria/score structure
- `src/task.cmd.complete` — how task completion is recorded

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

#,,.,,,,,,,,.,.,,,...,,,.,,,,,.,.,,,.,..,,,,.,..,,...,...,,..,,.,,...,...,.,.,
#FGOWLNBWMBU6DGRKZIEQ7KPDGYCNUZATFYGFSVZUSWE36SXYYN35IXLZJVBOD2YMNZARVRWSFTEUC
#\\\|IM7IX5TDXIAUMZ72JDZPFXCNDOCSPZJRVTDO4XK6GPOEFUTQ53J \ / AMOS7 \ YOURUM ::
#\[7]K6GTOAMTSDRKN4YQY4LDU56V2H5N4EJ7FTWV7FXBYXY2Q6VFKOBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
