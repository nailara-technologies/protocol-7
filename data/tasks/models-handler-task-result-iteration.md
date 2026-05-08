# task: wire iteration loop into models.handler.task-result

## objective
modify `modules/models.handler.task-result` so that when a task has
`iteration: true`, the backend reply is fed into `iteration.loop`
instead of directly completing the task.

## read first
- `modules/models.handler.task-result` — the handler to modify
- `modules/models.task.execute` — shows how iteration params are stored
- `modules/iteration.loop` — params: {task_id, result, criteria,
  node_id, max_attempts}; returns {mode=>'retry'|'escalate'|'true'}

## where to add

after `$response` is extracted (after the if/elsif/else block),
and before the final task completion logic, insert:

1. look up the task: `<task.queue>->{$task_id}`
2. check `$task->{'iteration'}` — if truthy, route through iteration
3. call `<[iteration.loop]>->({task_id, result=>$response, criteria,
   node_id, max_attempts})` — get criteria/node_id/max_attempts from
   `$task` hashref fields
4. on mode='retry':
   - update the task prompt with issues appended
   - re-enqueue via `<[models.task.enqueue]>` with updated prompt
   - return without completing
5. on mode='escalate':
   - call task.fail via route-send
   - return
6. on mode='true' or non-iteration: fall through to existing completion

## important
- do NOT change existing non-iteration task flow
- read the full module before modifying — check how task completion
  and job_outcome are currently handled at the bottom
- $task from <task.queue> may have different field names than $params —
  check what fields task.create stores vs what execute passes

## style
- $ARG not $_ in map/grep/foreach
- <[base.logs]>->( N, fmt, args ) for logging
- lowercase comments, [ word ] bracket annotations
- no use statements, no pragmas

#,,.,,,,.,.,.,,,,,,.,,.,,,,..,.,.,,,,,...,...,..,,...,...,.,,,.,,,.,,,,..,,,,,
#3SCRB4SNGSSHDGWBMVHL2ELCXUUR7HIDCYMM2IISUVFPS7IL5GRNXHXLXOI3VJ5ABE4XJFTKGVNWU
#\\\|KWFB7EA6SSTUOXZSOGUYSPEVEZX6MOMFJDDPPJLAFA322E4ESFZ \ / AMOS7 \ YOURUM ::
#\[7]6R5RWBHDSPGHFJNYSXGNYYOZLQ54G3U3FX4HO6RC7JQECZ6ME6DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
