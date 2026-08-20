# archive-completed-task-files — evaluate and classify task files

**Priority:** Medium
**Type:** Audit + Classification
**Model:** EMQFUAA:VWI5WKQ
**Component:** data/md/coding-tasks/, data/tasks/

## Overview

Evaluate all task files in `data/md/coding-tasks/` and `data/tasks/` to determine
which are complete and ready to archive. Produce a classified list with reasoning.

## Instructions

Use `list_files` to enumerate both directories. Then use `subtask_spawn` to evaluate
files in parallel batches of 5-8 files each. Each subtask should:

1. Read the file with `read_file` to understand what feature it describes
2. Extract the module name(s) or command(s) the feature would create
3. Check if those modules exist using `list_modules` or `search_code` on the
   module name — existence of the module = feature implemented
4. Cross-reference with `recent_changes` for recent commits mentioning the feature
5. Classify as one of:
   - `done` — module/feature exists in codebase, file can be archived
   - `partial` — some parts exist, work ongoing
   - `pending` — no evidence of implementation found

There are NO completion markers in these files — do NOT look for `# [DONE]` or
similar. Classification must be based on whether the described code actually
exists in the `src/` directory or recent git commits.

After all subtasks complete, use `summarize_context` with `focus=archive-candidates`
to produce a dense summary of the done/partial/pending breakdown — this is useful
for the session handover.

## Output Format

Produce a final report structured as:

```
## done — ready to archive
- filename.md : <one-line reason>
...

## partial — keep
- filename.md : <what remains>
...

## pending — keep
- filename.md : <why not started>
...

## summary
<summarize_context output focused on archive-candidates>
```

## Notes

- signatures_note: leave signing to the system, no stub lines
- task files in data/tasks/ are shorter iteration-loop style tasks — check if the
  referenced modules exist rather than reading full implementation
- data/md/coding-tasks/ files are longer feature specs — check module existence +
  recent git commits for evidence of completion
- do not modify any task files — read-only audit
- subtask_spawn is available and preferred for parallel evaluation
- summarize_context tool accepts: content, focus, model, backend, max_len, store, node_id

#,,.,,.,.,,..,,,,,,.,,,..,.,,,,..,...,.,.,...,.,.,...,...,..,,...,,,,,..,,..,,
#SQF4RBBLFEK5FQA27NYHDIAKABAO2CXSXNI4AROCBJ4MWSMUST75GG3YNWVSV2R4MJR4T24GDPBY6
#\\\|IJKQXJ3JTXQW3FPKVGDXS32IFPNJPSWRX746L47EJ4IL5E4QLS5 \ / AMOS7 \ YOURUM ::
#\[7]ALXGXH7BKCX4N3R7QR6MJ7QYLSLRP3JZUEEK5FRNGQH4255Y7CAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
