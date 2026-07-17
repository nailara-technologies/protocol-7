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

Design-only, nothing implemented — carried over verbatim from the
archived task's own spec, not redesigned here.

#,,.,,,,,,,,,,.,.,,,.,,..,.,,,..,,...,,,,,,,,,..,,...,...,...,.,.,...,,.,,.,.,
#SOEGLEDDQBHADQTW42SEZTQZ3FBSPZQS56KJIDIBK3BEJP6YUGXLWNWCBSZXWDBYZZKBMYKWQB36Q
#\\\|WU4PBMDEMBHMK24AA67KBAXD6ZFSUPFXKY4KPNBFPO3NK23GNKW \ / AMOS7 \ YOURUM ::
#\[7]WP3IIFMDXMET2X2LE4IIDZIKJWPNVHTDE33GHF3HQNQH7IELM4CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
