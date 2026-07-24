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

**How to apply:** always target `data/ai-mem/claude/<name>.md` with
Read/Edit/Write when saving or updating memory in this project, never the
`~/.claude/projects/.../memory/...` path — same file, fewer prompts. The
`MEMORY.md` index lives at `data/ai-mem/claude/MEMORY.md` the same way.

#,,..,,,,,,,.,,..,,,,,,.,,,.,,.,.,,,.,.,.,,..,..,,...,.,.,...,,..,...,.,,,,..,
#V4YU7EWOALQ62FZ7GCCTXAQIAFCGQAZQVH4HCQWKFB6Q344HRPKI73RBLL7CUBVUKRTGHYYQDGPJA
#\\\|7YUHBK2HZD457KRZ6RJHVNUPLPJDJNBYDSRRBHTIZSCYHR4YEKB \ / AMOS7 \ YOURUM ::
#\[7]DC6IQLB577UGE4G7WAPBFHQK564TIN4MSOPRXEHQYGZHPQSJAQBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
