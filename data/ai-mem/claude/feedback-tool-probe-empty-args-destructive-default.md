---
name: feedback-tool-probe-empty-args-destructive-default
description: calling an unfamiliar tool with empty/guessed args "to see what it needs" is not a safe probe — a missing-required-param path is not guaranteed to error, it can silently fall through to a destructive default; coding zenka's note_delete({}) wiped 38 unrelated note sections this way
metadata:
  type: feedback
---

2026-09-16: while investigating the coding zenka's `note_delete` tool
(no parameter schema shown by `coding.list-tools`, only a name + one-line
description), called `note_delete({})` purely to observe what error it
would return for a missing required param — a pattern that has worked
safely on ordinary APIs before. Instead of erroring, `note.delete`
treated the omitted `section` as "no section specified = delete
everything for this task" and immediately wiped all 38 sections of the
`unknown` task tree, no confirmation, no trash, no backup mechanism at
the time. Root cause and full incident: see
[[project-note-trash-ntime-tools-landed-2026-09-16]] (the fix — explicit
`confirm_all` flag + xz-trash on every note.* destructive op — landed
the same session).

This is the same failure *shape* as
[[feedback-deleted-manually-tuned-captures-without-confirming]] (117
files deleted from filename-pattern inference) but a different root
cause: that one was a wrong inference about content safety, this one was
trusting an unfamiliar tool's default behavior to be conservative on
missing input, which is not a property any tool actually guarantees.

**The actual lesson is not "be more careful next time"** — that's a
documentation-based compensation for a defect that lives in the tool
itself, and the user explicitly corrected this framing when the memory
was first drafted. A tool that silently does something irreversible on
a missing/guessed param is the bug, not the caller's insufficient
caution. Same principle as
[[feedback-upgrade-substrate-not-revert-on-tool-limits]]: when a tool
mishandles a case, fix the tool, don't just work around it or remember
to tread carefully around the landmine forever. That is why this
incident's actual resolution was landing `confirm_all` + xz-trash on
every note.* destructive op the same session (see
[[project-note-trash-ntime-tools-landed-2026-09-16]]), not a caution
note telling future sessions to read source before calling note_delete.

**How to apply**: when a tool (in this codebase, one you can fix) turns
out to have a destructive/irreversible default on missing or guessed
input, the correct response is to close that gap in the tool itself —
require explicit confirmation for the destructive path, and/or make the
destructive path non-destructive (trash instead of delete, stash before
overwrite) — not to add a reminder to be more careful around it. Reserve
"read source before probing live" for tools you genuinely cannot change
(third-party, another project, something out of scope this session) —
there, it remains the right fallback.

#,,,,,..,,,..,,,,,.,.,.,,,,,.,.,.,,,.,.,.,...,..,,...,...,...,.,,,,..,..,,.,.,
#TA3HS6KVV2OYVPDNIESCFVOBHNBRV3RM7M43NEO3LRW4NVK3LD667VSTI6Z63SBWZTVUGUQTVLI2U
#\\\|6QZRPCHEWSOPNNNX5Z6MTNW3H2OAULNBAUADONV3Y43NA75PGPX \ / AMOS7 \ YOURUM ::
#\[7]DP5RRPO3EHMP6GIQWSS26E6MPLYC2MTHOI4ACJMJ25FEF4S662BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
