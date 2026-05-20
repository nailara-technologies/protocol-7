# task: implement task.cmd.handover

## objective
create `modules/task.cmd.handover` — packages current task queue state
into a structured handover document for next-session pickup.

## read first
- `modules/task.init_code` — queue structure: <task.queue>, <task.queue.order>
- `modules/task.cmd.show` — how to read and format a task record
- `modules/task.cmd.next` — how to use <[valued.resolve]> for priority

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

#,,,,,..,,,,,,...,.,.,,.,,.,.,,.,,.,,,.,.,..,,..,,...,..,,..,,.,.,..,,.,,,.,,,
#3PJYJ2JRXUWSXC62HG5BFCNQ23B2P2IB5B6AJBQ3G7I7UYWG2OS6AD4RYKJQ6QQXBT4PKS5YL4NLU
#\\\|6FRZ2CROHUCPYUXULV6FTFSHRCTBMTGAYD6M72KFHEIZLEMH6GE \ / AMOS7 \ YOURUM ::
#\[7]UONMFPKWI5YYM65VU7N444VJT6BLL6AXUOJAQ5CJKWQFATLSVMBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
