---
name: feedback-edit-memory-via-ai-mem-path
description: "always Edit/Write memory files via data/ai-mem/claude/<file> not the ~/.claude/projects/.../memory/ symlink path -- avoids permission prompts"
metadata:
  type: feedback
---

`~/.claude/projects/-data-projects-protocol-7/memory` is a symlink straight to
`/data/projects/protocol-7/data/ai-mem/claude` (confirmed same inode target,
set up 2026-03-25) — they are the same files, not two copies needing a sync
step.

**Why:** editing through the symlink path triggers permission-request
prompts since it resolves outside the recognized project tree at request
time; editing via the real in-repo path `data/ai-mem/claude/<file>.md`
does not, since it's a normal path inside the project directory.

Root cause is sharper than "outside path = prompts every time": the
permission dialog offers a "remember this decision" option, but selecting
it does not actually persist for the `~/.claude/...` path — it re-prompts
on the very next edit anyway (confirmed by the user, 2026-08-01). So this
isn't an inherent property of out-of-project paths, it's the harness's
remember-choice mechanism silently failing to stick for this specific
path. Don't assume "allow once" or "always allow" will hold across calls
for `~/.claude/...` — it won't, regardless of what's selected.

**How to apply:** always target `data/ai-mem/claude/<name>.md` with
Read/Edit/Write when saving or updating memory in this project, never the
`~/.claude/projects/.../memory/...` path — same file, fewer prompts. The
`MEMORY.md` index lives at `data/ai-mem/claude/MEMORY.md` the same way.

#,,,,,,..,,,.,,.,,,.,,,,.,...,.,.,,.,,.,.,,,.,..,,...,...,.,,,,..,,,.,.,,,..,,
#FLQEOAAS2MD7Q566377LWVHBTHXDTVN66CT6V3XGMQMMEMP6OTAMBHAQLCMA6GHP4OP6S4XH2TDP4
#\\\|PA2AOLRC5V33W6P472XVZSKVG7E3DOXFCENXKIBFVZDV33SQE7F \ / AMOS7 \ YOURUM ::
#\[7]4IQ6FF4D4UNMAMHXPGNR6L5GYOBAYS5G5LTBANNBCSKTYHFP66CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
