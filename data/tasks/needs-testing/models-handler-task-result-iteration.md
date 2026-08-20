# task: wire iteration loop into models.handler.task-result

## objective
modify `src/models.handler.task-result` so that when a task has
`iteration: true`, the backend reply is fed into `iteration.loop`
instead of directly completing the task.

## read first
- `src/models.handler.task-result` — the handler to modify
- `src/models.task.execute` — shows how iteration params are stored
- `src/iteration.loop` — params: {task_id, result, criteria,
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

#,,,.,,,.,..,,.,.,,.,,...,,..,,.,,,,,,.,.,,..,..,,...,...,...,..,,,..,,,.,,,.,
#FTJZO3BKDIGSQSI5YMN6U4BS6PVRDKC6V2NONBLBAWOEMKNABFGNTWJKPYT5V7LDEYKWMBCCXLNC6
#\\\|DDCZJTUSONHBBQ2F3IOLZSCRPSOR3NIIYAAYCGY2PN67BJMHFKI \ / AMOS7 \ YOURUM ::
#\[7]SXOM2OZ7BPSG4HIGVY256FMJ5VHLSR45CZUVZPTM4WK5M7Q77UCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
