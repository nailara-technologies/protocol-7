---
name: feedback-memory-write-path
description: always write memory files via the data/ai-mem/claude/ path, not the ~/.claude/projects/.../memory/ symlink path
metadata:
  type: feedback
---

`~/.claude/projects/-data-projects-protocol-7/memory/` is a symlink to
`/data/projects/protocol-7/data/ai-mem/claude/` — same files, same inode.

**Why:** the permission system checks the literal path string passed to Write/Edit, not the resolved
target. Writing through the `~/.claude/...` symlink path is outside the already-approved project working
directory, so it re-prompts for permission on every memory write. Writing via the `data/ai-mem/claude/...`
path directly is inside the project tree and does not.

**How to apply:** always construct memory file paths as `/data/projects/protocol-7/data/ai-mem/claude/<name>.md`
(and `MEMORY.md` / `MEMORY-*.md` at that same location), never via the `/home/taeki/.claude/projects/...`
form, even though both resolve to the same content.

#,,,.,,.,,..,,..,,...,.,.,..,,,.,,.,,,.,,,,,,,..,,...,...,..,,.,.,,,,,,.,,,,,,
#NWTGUZI6QIM2N7WOUTUOXJ4F6RZYV24LIBCJWGUZNWBESJ5XPZTWMFIMZXLQNJP3KQTCZ5ABN337E
#\\\|TRIOFVTWJSPLH2RE4LAFBKTTA2OBY7SVFDLUVOLCYQSN62654FY \ / AMOS7 \ YOURUM ::
#\[7]KSDXSN3PBL3QP722G6PFD273FPPGMNGOUPOGMCPXUCNM23M4NGCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
