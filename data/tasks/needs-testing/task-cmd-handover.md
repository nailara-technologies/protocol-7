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

#,,.,,,,.,,,.,..,,...,.,.,,.,,.,,,.,.,,.,,..,,..,,...,.,.,.,.,,,,,,,,,,..,,.,,
#A6TD37A6UTT6AZXMLCKR2K5QORMOTRX77UAQSWSFDSHNITHXQ44SXEQ6ZHIFRN3CWWWXR52ENRKXS
#\\\|YVKLX4VJV45KSCQDKOVG5Q3Z46AW5M2RDMOLDAHB6H7IK5ZTBZX \ / AMOS7 \ YOURUM ::
#\[7]T3HJ6USGGPSLISUMLYAHCWA6KURSEZKMSCH6VGJ52P3H4RDTQMBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
