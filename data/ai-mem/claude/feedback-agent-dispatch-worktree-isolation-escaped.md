---
name: feedback-agent-dispatch-worktree-isolation-escaped
description: "a nested Agent dispatch with isolation:worktree still modified the main repo working tree, not just its isolated worktree copy -- root cause was the dispatched agent's own 'cd /data/projects/protocol-7' before running the task, then a self-inflicted wrong-commit revert to fix its own mistake. main repo was fully recoverable via git checkout HEAD since only the working tree was ever affected, no commits were touched. don't trust isolation:worktree to fully contain a dispatched agent without verifying afterward"
metadata:
  type: feedback
---

Landed/discovered 2026-07-24, during the `bin/*` format-code reflow batch.

## What happened

Dispatched a `general-purpose` Agent with `isolation: worktree` to run
`bin/format-code` across `bin/*` and verify the result — a mechanical,
well-established task by that point in the session (12 namespaces
already done directly). Expected the isolation to keep all of its
actions confined to `.claude/worktrees/agent-<id>`, leaving the main
working tree untouched until the result was reviewed and manually merged
back.

Instead, the user reported `bin/Protocol-7` and `bin/format-code` in the
**main working tree** had been corrupted — `bin/format-code` lost ~400
net lines (reverted to a much earlier state), and `bin/Protocol-7` showed
duplicated content (the already-fixed 2-hash box AND the old broken
3-hash version both present).

## Root cause (confirmed via `session_catchup` with `subagents=2`,
## `subagent_id=<agent-id>` against the failed agent's own transcript)

The dispatched agent ran `cd /data/projects/protocol-7 && bin/format-code
bin/*` — literally `cd`-ing into the shared main repo instead of trusting
its cwd was already the isolated worktree — contaminating the shared
checkout directly. When it noticed the contamination (checking git status
divergence between its worktree HEAD and the shared checkout), it tried
to self-correct with `git checkout 31b7e737c -- bin/` to restore what it
believed was the "pristine original tip" — but `31b7e737c` was a stale
commit hash from very early in the session, predating nearly every
`format-code` fix and every namespace reflow that had landed since. That
wrong-reference revert is what produced the actual damage reported.

After that self-inflicted detour, the agent correctly did the rest of
the real task entirely inside its worktree (no further `cd` needed once
cwd was already correct) and found genuine content in `bin/harmony` and
`bin/terminal` that needed exempting (same "hand-aligned notation resists
detection" class as `source.AMOS-center-bit.desc`) — it was mid-revert of
those two, blocked by a checkout lock, when the orchestrating session
killed it after the user reported the main-tree corruption.

## Recovery

Since only the **working tree** was ever affected — no commits were
touched, and `HEAD` was confirmed intact/correct throughout — recovery
was a plain `git checkout HEAD -- bin/Protocol-7 bin/format-code`,
verified via `ptd -c` and content spot-checks. Full `git status` sweep
confirmed nothing else in the repo was touched. The stray worktree and
its branch were then removed via `git worktree remove --force` +
`git branch -D` — **before** running the `session_catchup` trace, which
meant the agent's own verified work on the ~43 other, undamaged files was
lost too (not harmful, just wasted effort — redone directly afterward in
~4 more commands). In hindsight, tracing root cause *before* deleting the
worktree would have let the ~90% of already-good work be salvaged instead
of redone.

## Takeaway

`isolation: worktree` isolates the agent's *own* working directory
default, but does not prevent it from executing shell commands against
absolute paths or explicit `cd` targets outside that worktree — the
agent has to respect the isolation itself, and this one didn't, on its
very first command. Don't treat `isolation: worktree` as a hard
guarantee for a dispatched agent touching a shared repo; verify
`git status` / `git diff --stat` against the main tree immediately after
a dispatched agent reports back, before trusting its "isolated" claim.
If damage is found, check whether commits were touched (usually not,
since agents mostly modify the working tree) before assuming anything is
unrecoverable — a plain `git checkout HEAD --` was sufficient here.

## related

[[topic-format-code-bugs-fixed]]

#,,,,,...,,,.,,,.,.,.,,.,,,..,...,.,.,.,,,,..,.,.,...,...,,..,.,,,,,.,,,.,,,.,
#3OUHDU47NXBV4JQLQVZFV73VFB6DWGRFVJF7NWBMNUNWQ2TXWSVBD2KCVB5WPYTY342PVJBXFDW6M
#\\\|FOFUEWNUD4UZMJILLVWOA33XIDLCNGTBNDI3JI2C66W6G522KH6 \ / AMOS7 \ YOURUM ::
#\[7]RIXR2NOHLLJVUF4E5SPPBLCXB3R4AHULX3JKW6DR7M7YZ2A75WCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
