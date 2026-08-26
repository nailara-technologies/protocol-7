# task: implement task.cmd.handover

## objective
create `src/task.cmd.handover` — packages current task queue state
into a structured handover document for next-session pickup.

## read first
- `src/task.init_code` — queue structure: <task.queue>, <task.queue.order>
- `src/task.cmd.show` — how to read and format a task record
- `src/task.cmd.next` — how to use <[valued.resolve]> for priority

## what to implement

optional param: task id [ show handover for one task ]
if no param: show handover for all non-done tasks

output sections in order:

  ## in progress ##
  tasks with status 'claimed' — id, description, assignee, priority

  ## next executable ##
  top 3 pending tasks by valued tree priority [ use valued.resolve ]

  ## blocked ##
  tasks with status 'blocked' or 'failed' — id, description, reason

  ## recent completions ##
  last 3 tasks with status 'done' — id, description, result [ first 80 chars ]

format each task as one line:
  "ID  [assignee]  description [ first 60 chars ]  (priority: X.XX)"

return: { 'mode' => 'true', 'data' => $handover_str }
empty queue: return 'no tasks in queue'

## style
- $ARG not $_ in map/grep/foreach
- <[base.logs]>->( N, fmt, args ) for logging
- lowercase comments, [ word ] bracket annotations
- no use statements, no pragmas

#,,,.,..,,,.,,..,,.,.,,.,,,,,,..,,...,,.,,..,,..,,...,..,,.,.,...,,,,,...,,..,
#2SVMLYLWLILV7HNBAKTJNZCQDGMBF4TWGDAJPUK5JMINGLCI6YWNWI4ESQ5IO5KM36ILQMIW34PFC
#\\\|7I5524IBQNP22YBJ5RE5Q7K2FHM5BZ4BUKINOGIGAL5EYZQYDZN \ / AMOS7 \ YOURUM ::
#\[7]W5DXIKNWF7JJ2VS6WOZ6XJOHK36KAUR4OG3XCY6HMVTMBKRQ4YDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
