# mcp-server-p7: checklist/tasklist routing expansion for coding_summarize

## what this is

Carved out of `mcp-coding-summarize.md` (archived to `completed/`
2026-07-17) — everything else in that task landed, but this specific
piece was never built and would otherwise have been silently lost on
archive. Flagged during an independent re-verification pass (kimi):
genuinely absent, zero matches for `DISPATCH_NEEDED`/`needs_followup`
anywhere in `bin/mcp-server-p7`.

## the gap

Expand `coding_summarize` to operate as a **task completion verifier**
when given a checklist-style instruction:

```
instruction: "check the following acceptance criteria against the output.
  for each criterion, output PASS or FAIL with a brief reason:
  1. module X was created
  2. function Y handles edge case Z
  3. no signature stubs in new files
  if any FAIL: output DISPATCH_NEEDED: <what to fix>"
```

When the summary contains `DISPATCH_NEEDED:`, the MCP tool should:
1. return the summary with a `needs_followup: true` flag
2. optionally auto-dispatch a follow-up to kimi with the failure items

This creates a self-healing dispatch loop:

```
dispatch → summarize → verify checklist → if FAIL → re-dispatch with failures
```

Acceptance criteria come from the task file itself — parse the task file
for a `## acceptance criteria` or `## verification` section and use
those as the checklist items.

## status

Implemented 2026-07-17 in `bin/mcp-server-p7`:

- `coding_summarize` gained two opt-in params: `task_file` (parses the
  task file's `## acceptance criteria` / `## verification` section and
  auto-builds the checklist instruction, overriding `instruction`) and
  `auto_followup` (default off).
- checklist mode activates on `task_file`, on a checklist-style
  `instruction` (matches `DISPATCH_NEEDED` / `acceptance criteria`), or
  on `auto_followup`.
- when the summary contains `DISPATCH_NEEDED:`, the tool returns
  `needs_followup: true` both as a structured field in the tool result
  (`send_tool_result` gained an optional extra-fields hashref) and as a
  trailer line in the result text.
- with `auto_followup` true, the text after `DISPATCH_NEEDED:` is
  background-dispatched to `kimi-legacy -y --afk -p <prompt> --model
  kimi-code/k3` via fork/exec (detached stdio, never blocks the MCP
  loop; child output appends to `data/state/auto-followup.log`).
- new subs: `_task_criteria_from_file`, `_checklist_instruction`,
  `_dispatch_followup`.
- verified live: schema registration, section-missing error path,
  task_file checklist build against `inline-subs-batch-misc.md`, marker
  detection with structured flag, and stubbed auto-followup arg/log
  wiring.

#,,,,,.,.,,..,.,.,,,.,,,.,,..,,.,,,.,,.,,,,,.,..,,...,...,...,...,,,.,,,,,.,.,
#HUXRU4GU3AGNCAF5Z6FBXYJ5MEVCKXA2HVNNFQUYEIGWQ65UFWMJ27BXVYW4BMTEQZCF2BQFEXCF6
#\\\|4ASRLMV65UZFPJYYMKGXCG2VIXIFUSQ7DDP3ATG6OR3WJXWXGXI \ / AMOS7 \ YOURUM ::
#\[7]EOGLSPGKMOTUVUKEI4RLS7DJJTIIVNY437YLPP3W6Y75PPMWGQDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
