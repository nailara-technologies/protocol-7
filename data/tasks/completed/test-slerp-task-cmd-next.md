# task: implement task.cmd.next — highest-priority executable task

## signatures note

do NOT add the single-line `#,,.,,,...` stub at end of new files.
leave files clean — the signing system adds the real footer automatically.

## objective

create `modules/task.cmd.next` — returns the highest-priority task from
the queue that is ready to execute. this is the key command for autonomous
operation: a model calls `task.next` to get its next unit of work without
needing user input.

## what already exists — read these first

- `modules/task.init_code` — shows queue structure:
  - `<task.queue>` — hashref { task_id => task_record }
  - `<task.queue.order>` — arrayref of task_ids in insertion order
- `modules/task.cmd.show` — shows how to read a task record and format reply
- `modules/task.cmd.create` — shows task record field names:
  - `status`: 'pending' | 'claimed' | 'done' | 'failed'
  - `description`, `context`, `node_id`, `created_at`, `updated_at`
- `modules/valued.resolve` — takes a node_id, returns refs + weight (effective priority)
  - returns undef if node not in valued tree — treat as priority 0.0

## what to implement

`modules/task.cmd.next` should:

1. accept optional `assignee` filter from args (e.g. `task.next coding`)
2. iterate `<task.queue.order>` to preserve deterministic ordering as tiebreak
3. skip tasks where status is not 'pending'
4. skip tasks where assignee filter is set and task's `assignee` field doesn't match
5. for each candidate: compute priority via `<[valued.resolve]>` on
   `$task->{'node_id'}` — fall back to 0.0 if undef
6. return the candidate with highest priority
7. if no executable task found, return `{ mode => 'false', data => 'nothing executable' }`
8. on success return `{ mode => 'true', data => $formatted_summary }` where
   the summary includes: task_id, description (first 120 chars), priority score,
   node_id if set — enough for a model to decide whether to claim it

## style

- `$ARG` not `$_` in map/grep blocks
- `<task.queue>->{}` not `$data{'task.queue'}{}` for dotted data keys
- `<[base.logs]>->( N, fmt, args )` for logging
- lowercase comments, `[ word ]` bracket annotations

## acceptance

- `p7c task.next` returns the pending task with highest valued tree priority
- `p7c task.next coding` filters to tasks with assignee 'coding'
- returns 'nothing executable' when queue is empty or all tasks claimed/done
- ties broken by insertion order [ first in queue wins ]

#,,.,,.,,,,,,,,,.,..,,.,.,.,.,.,,,...,,,.,,..,..,,...,...,..,,..,,.,,,,.,,.,,,
#M7T6KOVIJVSXQIB3MLSLI5BHV6HMQHLMZ5Z2MVPT76GLBVSGP3XZ3MLFYEAPHLZSETTSZZBSCZOME
#\\\|OP67AFVWB6GTHSEXETGDPOORE74PIQFBOIP2M3NOIA43Q6SA4ZX \ / AMOS7 \ YOURUM ::
#\[7]TFLFLM3YDD7NTZZHUFNNKKVTG5BW56PUUEMKFW4UUU7ETM56P4BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
