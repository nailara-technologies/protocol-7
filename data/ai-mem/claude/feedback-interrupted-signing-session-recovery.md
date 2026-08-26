---
name: feedback-interrupted-signing-session-recovery
description: "when a session times out mid signing-and-commit (user AFK for the interactive update-signatures password prompt), the git index holds a stale pre-signing snapshot that must be `git reset` before re-staging; the prior session's exact batch/dispatch plan lives in /tmp/claude-*/<session-id>/{scratchpad,tasks}, not just in session_catchup's summary"
metadata:
  type: feedback
---

**2026-08-09.** A prior session ran a large multi-file audit-and-rename
(base.time -> base.ntime across ~277 files, see [[topic-completed]] /
the "ntime rename" work) and staged one file subset for commit before
calling the interactive `bin/Protocol-7 sourcecode update-signatures`
step, which blocks on the user's key passphrase. The user was AFK, the
session timed out, and the next session had to resume from a completely
cold start.

**Two things to check before touching git in a resumed-after-timeout
situation:**

1. **The index may hold a stale pre-signing snapshot.** `git status`
   showed some files as `MM` (staged *and* further modified) — the
   staged copy predated the `update-signatures` re-sign pass that
   apparently did complete on disk before the timeout (confirmed via
   `bin/Protocol-7 sourcecode verify-p7-signatures`, exit 0, silent on
   success — no `-v` needed to just check "all valid"). `git commit`
   commits the whole index, not just newly-`git add`ed files, so any
   commit built on top of that stale index would carry files with
   outdated signature footers. Fix: `git diff --cached --name-only >
   backup.txt` then `git reset` (mixed, no `--hard`) before re-staging
   anything — working tree is untouched, only the index is cleared.

2. **The previous session's batch/grouping plan is not in
   `session_catchup`'s summary — it's in that session's own scratchpad
   files.** `session_catchup` (even with `subagents=2`, `tail_chars`
   trimmed) gave a good high-level summary but not the literal list of
   which files belonged to which of the 13 planned commit batches, and
   a second, more targeted `session_catchup` call asking for exactly
   that **timed out after 590s and failed outright** — the underlying
   9B local-model summarizer choked on reconstructing structured data
   (13 file-group lists) from a long transcript. The actual plan was
   sitting untouched on disk the whole time:
   `/tmp/claude-1000/-data-projects-protocol-7/<prior-session-uuid>/scratchpad/groups/final_*.txt`
   (13 themed dispatch-prompt files, one per commit-batch, each with a
   `## module.name` header per finding) and
   `.../scratchpad/chunk_ab_final.md` / `/tmp/audit_batch_*` (earlier,
   superseded working files from before the grouping was finalized —
   don't try to reconcile these against the final groups, they're dead
   ends). Cross-referencing `git diff --name-only` against the `##`
   headers in the `final_*.txt` files (intersect, don't trust raw
   counts — some listed findings were intentionally left unconverted
   "A-class" sites) reconstructed the exact batch plan with zero
   guessing.

**How to apply:** when resuming any session that references "the
batch"/"the last run" and a prior session id is known (via
`session_catchup` list mode), check
`/tmp/claude-*/<prior-session-id>/scratchpad/` and `/tasks/` directly
with `find`/`ls`/`Read` *before* relying solely on `session_catchup`'s
summarization — it can time out or lose structured detail (exact file
lists, exact groupings) that a text summary was never going to preserve
faithfully. This complements
[[reference-session-catchup-subagent-support]] (that entry covers
recovering *subagent* transcripts through the tool; this one covers
recovering a *prior top-level session's* scratch artifacts by reading
the filesystem directly when the tool's summarization path fails or is
too lossy).

Also reaffirms [[feedback-precommit-signing-version-workflow]]: splitting
one finished batch of work into N commits genuinely requires N rounds of
interactive `update-version && sourcecode update-signatures` — there is
no way to front-load the signing for a multi-commit split. 14 batches
this session meant 14 rounds of the user manually running the sign step
and saying "signed"/"ready"/"done" before each commit could proceed.

#,,..,,,.,..,,,,.,,,.,..,,,..,..,,..,,..,,,..,.,.,...,...,..,,.,.,,,.,,,,,,..,
#6C3T5O4S2QQD47DDV5D4KPZCVYAFBPVIHCSEEPGFFZRZ6W5M6VPWPUUZPUMXQVJO6M24UX3MDAMFO
#\\\|FC6OGLSDVWFHXU22U7ESPAZK2P6CSQ2ZPFT7YGCRBZQTJPDKJII \ / AMOS7 \ YOURUM ::
#\[7]RRVNVNLGXPWJ3RAQMG5TNUSD7OZILCCYVC7EYXN35LUJR3G37KBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
