---
name: feedback-nested-dispatch-session-tracking
description: "claude_dispatch/claude_continue auto_summarize output is unreliable; nested kimi session IDs don't survive a claude_continue resume"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 7c17eae7-f6c4-401f-9fec-c5f3fdcd8849
---

When using the [[feedback-claude-dispatch-strategy]] nested pattern (parent →
claude_dispatch → kimi_dispatch), two reliability gaps showed up in practice
(2026-07-02, jobs UI export-sync task):

1. **auto_summarize output is lossy/garbled.** The terse JSON-ish status block
   (`status/files_created/files_modified/issues/resume_uuid`) it returns is
   condensed by a local 9B model and can come back with empty fields, vague
   prose, or misleading "issues" even when the actual work succeeded. Do not
   treat it as ground truth — always verify via `git diff`/`git status`
   directly against the working tree before reporting success or failure to
   the user.

2. **Nested kimi session IDs don't reliably survive `claude_continue`.** When
   resuming an outer claude_dispatch session via claude_continue and asking
   it to continue the *inner* kimi session it previously dispatched, the
   outer session sometimes can't find/preserve that kimi session UUID and
   silently falls back to a fresh `kimi_dispatch` instead of `kimi_continue`.
   This isn't necessarily wrong (a fresh dispatch with the current diff as
   context can still produce a correct fix), but it means the "resume with
   full prior context" guarantee doesn't hold at the second nesting level.

**Why:** taeki caught this by noticing the garbled first-round summary
("No session ID was preserved from previous dispatch") and asking about it
directly — the underlying code change was still correct both rounds, so this
is a reporting/session-continuity gap, not a correctness gap, but it means
the parent-context-savings promise of nested dispatch (trust the summary,
skip re-reading the diff) doesn't fully hold yet.

**How to apply:** when using nested claude_dispatch → kimi_dispatch, always
verify the actual working-tree diff yourself after each round rather than
relying solely on the returned summary text. Don't assume `claude_continue`
resumed the exact same inner kimi session unless the summary explicitly
confirms a kimi_continue (not kimi_dispatch) call happened.

#,,,.,,.,,..,,..,,..,,,,.,..,,,.,,...,,..,.,.,..,,...,...,...,,,,,.,.,.,.,.,.,

#,,,.,,,.,.,,,,,.,.,.,,..,,.,,,,.,,,.,,,,,.,,,..,,...,...,.,,,..,,.,,,,,,,..,,
#AH5LOUEJHGQI6IAWDP2Q3CVJUY74FC6JAAG745D3K2HSQMHQTRNBN4NU7EGKQJSUQYBTCMYXIITYW
#\\\|RWHEQ2FE7QG53ZHQF7MICQQ3Z6VY4F2KXE4NWN776ZNG5MTHIIS \ / AMOS7 \ YOURUM ::
#\[7]QHQAZCWZ2L3D5SNXIZ4JO6ITLFPRKPLPKHFUTEM65WCV5VX57SCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
