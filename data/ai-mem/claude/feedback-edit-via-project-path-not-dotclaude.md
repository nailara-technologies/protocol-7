---
name: edit-via-project-path-not-dotclaude
description: "edit memory files via data/ai-mem/claude/ (the project-checkout path), not ~/.claude/projects/.../memory/ — the latter re-prompts for permission on every single edit"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3c264315-73af-4677-a8b4-23ce085cb5a8
---

`~/.claude/projects/-data-projects-protocol-7/memory/` is a **symlink**
to `/data/projects/protocol-7/data/ai-mem/claude/` — same inode, same
files, either path edits the identical content. But the two paths are
NOT equivalent for tool-permission purposes: editing through the
`~/.claude/...` path re-triggers a permission prompt on every single
edit (it isn't remembered/allow-listed across calls), while editing
through `data/ai-mem/claude/...` — the project-checkout path — is
treated as an ordinary in-repo file and doesn't re-prompt.

**Why:** permission allow-listing appears to key off the literal path
argument passed to the tool, not the resolved symlink target. The
`~/.claude/...` path lives outside the project checkout (in the user's
home dotfiles), so it never accumulates the same standing trust a
regular project-tree path does, even though it's the identical file.

**How to apply:** when reading or editing this memory system's files,
default to the `data/ai-mem/claude/...` path
(`/data/projects/protocol-7/data/ai-mem/claude/<file>.md`), not the
`~/.claude/projects/-data-projects-protocol-7/memory/...` path — same
content, no repeated permission friction. Only use the `~/.claude/...`
path if something specifically requires addressing it by that name
(e.g. a tool that hardcodes the memory-directory location and won't
accept a project-relative path).

#,,,.,..,,.,.,.,.,.,,,...,,.,,...,.,.,,..,,.,,..,,...,...,...,,,.,.,.,...,...,
#HEKIDMOIX5DB4JQ3HOZCLCY2UEOY4E5R5RKHAUHPDL3O7X4D2IKJPWURU4B5XHBIA7BRLXQ5MIKGK
#\\\|YAH6Z564NGBTEPDYLHQ2GY44SV5FHWI3EOMIMXAVRGNLPMDUXWD \ / AMOS7 \ YOURUM ::
#\[7]5BLPOBSF4Q3LTRYMGPFJ4CSMT7YZHIY5YYACLNCXEVYL7WGKWCCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
